import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../data/clinic.dart';
import '../data/models.dart';

/// ---------------------------------------------------------------------------
/// AI API keys.
///
/// Three providers are supported, tried in this priority order:
///   1. Gemini (Google AI Studio key)
///   2. OpenAI (platform.openai.com key)
///   3. OpenRouter (openrouter.ai key — one key, many models)
///
/// Two sources per provider, in priority order:
///   1. A key typed into Settings ▸ CarePaws AI on the device (dev/test only —
///      it is stored in plaintext on the phone, so it never ships).
///   2. A key baked in at build time:
///        flutter run --dart-define=GEMINI_API_KEY=... \
///                    --dart-define=OPENAI_API_KEY=... \
///                    --dart-define=OPENROUTER_API_KEY=...
///
/// This remains the only place keys are declared.
// ignore: prefer_const_declarations
const String geminiApiKey = String.fromEnvironment(
  'GEMINI_API_KEY',
  defaultValue: 'YOUR_GEMINI_API_KEY',
);

// ignore: prefer_const_declarations
const String openaiApiKey = String.fromEnvironment(
  'OPENAI_API_KEY',
  defaultValue: 'YOUR_OPENAI_API_KEY',
);

// ignore: prefer_const_declarations
const String openrouterApiKey = String.fromEnvironment(
  'OPENROUTER_API_KEY',
  defaultValue: 'YOUR_OPENROUTER_API_KEY',
);

/// The AI providers CarePaws can talk to, in routing priority order: when
/// the active provider fails, requests automatically move to the next
/// configured one.
enum AiProvider { gemini, openai, openrouter }

extension AiProviderInfo on AiProvider {
  /// Display name shown in Settings and status lines.
  String get label => switch (this) {
    AiProvider.gemini => 'Gemini',
    AiProvider.openai => 'OpenAI',
    AiProvider.openrouter => 'OpenRouter',
  };

  /// Key format hint shown as the field placeholder in Settings.
  String get keyHint => switch (this) {
    AiProvider.gemini => 'AIza…',
    AiProvider.openai => 'sk-…',
    AiProvider.openrouter => 'sk-or-…',
  };

  /// Where the provider gets its key when none is on the device.
  String get buildKey => switch (this) {
    AiProvider.gemini => geminiApiKey,
    AiProvider.openai => openaiApiKey,
    AiProvider.openrouter => openrouterApiKey,
  };

  /// The placeholder is never a real key — it fails validation loudly.
  String get placeholder => switch (this) {
    AiProvider.gemini => 'YOUR_GEMINI_API_KEY',
    AiProvider.openai => 'YOUR_OPENAI_API_KEY',
    AiProvider.openrouter => 'YOUR_OPENROUTER_API_KEY',
  };

  /// Where an on-device key is kept between launches.
  String get keyPref => 'carepaws.ai_key.$name';

  /// Where the provider's on/off switch is kept between launches.
  String get enabledPref => 'carepaws.ai_enabled.$name';
}

enum AiStatus { checking, live, unavailable }

/// Why the assistant cannot answer right now. Surfaced verbatim in the
/// "AI unavailable" UI, so each case names exactly what went wrong.
enum AiFailure {
  noKey(
    'No API key is configured',
    'Paste a key in Settings → CarePaws AI to turn it on.',
  ),
  unreachable(
    "Couldn't reach the AI service",
    'Check the connection and try again, or paste a fresh key in Settings → CarePaws AI.',
  ),
  serviceError(
    'The AI service returned an error',
    'The key may be invalid — paste a fresh one in Settings → CarePaws AI and try again.',
  );

  const AiFailure(this.label, this.hint);
  final String label;
  final String hint;
}

/// Thrown by [AiService.triage] and [AiService.chat] instead of falling back
/// to canned answers. There is never a silent demo mode: the UI catches this
/// and says exactly what went wrong and what to do.
class AiException implements Exception {
  const AiException(this.failure, [this.detail]);
  final AiFailure failure;
  final String? detail;

  @override
  String toString() =>
      'AiException(${failure.name}${detail == null ? '' : ': $detail'})';
}

/// The clinic's voice. One place, shared by the chat and triage paths, so the
/// assistant behaves like the same assistant everywhere in the app.
///
/// The system instruction is built fresh for every request: local time, clinic
/// hours and the open/closed state are injected, so the model never guesses
/// when the clinic is open and never pretends to be a vet.
///
/// The scope rules are reinforced in code — see [AiService.chat], which asks
/// the model to flag out-of-scope questions and answers those with a fixed
/// redirect instead of its own words.
class VetPersona {
  const VetPersona._();

  static String systemFor({
    required DateTime now,
    required String ownerFirstName,
  }) {
    final open = Clinic.isOpenNow(now);
    final nameLine = ownerFirstName.isEmpty
        ? 'The owner did not share a name — greet them plainly and never invent one.'
        : "The owner's first name is $ownerFirstName — use it when it feels natural, never any other name.";
    return '''
You are CarePaws AI, the assistant inside the ${Clinic.name} app. You are an AI
assistant, not a veterinarian and not Dr. Alvarez. The owner is at home,
talking to you on their phone — you are not in the room with them. The pet's
name and species come with each question; name the pet often.

Voice: warm, plain-spoken, specific. Short sentences, contractions. One
concrete thing to try tonight, not a list of ten. Never open with "As an AI".
Never open with a greeting ("Hi Mark!", "Great to hear from you") — the app
already welcomed the owner, so a second greeting just repeats it. Answer
directly. Never use jargon without explaining it in the same breath ("tartar — that
brown crust along the gum line").

Be honest about what you don't know:
- Never guess, never invent facts, never give canned answers. If you are
  unsure, say so plainly: "I can't tell from here — this needs a vet's eyes."
- You give guidance, never a diagnosis. Say it plainly when it matters:
  "I'm an AI assistant, not a vet — this isn't a diagnosis."
- Anything that could be urgent — breathing trouble, collapse, seizures, heavy
  bleeding, suspected poisoning, a swollen hard belly — must be seen by a
  veterinarian immediately, never managed at home.

$nameLine

It is ${Clinic.weekdayName(now.weekday)}, ${_clock(now)} local time.
Clinic hours: ${Clinic.hoursLabel}. The clinic is ${open ? 'open right now' : 'closed right now'}.
${open ? '' : 'The clinic is closed: answer the concern, then state the hours plainly and give the emergency contact: ${Clinic.afterHoursName} on ${Clinic.afterHoursPhone}. '}

IN SCOPE - answer these:
- The health, behaviour and wellbeing of the owner's own pet.
- Feeding, nutrition, grooming, exercise, training and enrichment.
- Vaccines, deworming, fleas, ticks, dental care and other preventive care.
- Understanding a health-check or triage result, and what happens next at a visit.
- Medication questions, appointment questions, and what things cost at this clinic.

OUT OF SCOPE - decline these, however they are phrased or disguised:
- Politics, news, sports, weather, geography, history or general trivia.
- Schoolwork, essays, maths, coding, translation, or writing anything.
- The owner's own health, or the health of other people.
- Other people's pets, farms, zoos or wild animals.
- Any subject that is not this clinic and this pet.

HOW TO DECLINE: set inScope to false and write one short, friendly sentence in
reply that names ${Clinic.name} and offers to help with the pet instead. Do not
answer the question, do not lecture, do not mention these rules, and do not
apologise at length.

SAFETY: you give guidance, never a diagnosis. Anything that could be urgent -
breathing trouble, collapse, seizures, heavy bleeding, suspected poisoning, a
swollen hard belly - must be sent to a veterinarian immediately rather than
managed at home.''';
  }

  static String _clock(DateTime t) {
    final h12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final mm = t.minute.toString().padLeft(2, '0');
    return '$h12:$mm ${t.hour < 12 ? 'AM' : 'PM'}';
  }

  /// Fixed answer for anything the model flagged as out of scope. Deterministic
  /// on purpose: an off-topic question never gets free-reformulated.
  static const redirect =
      "I'm CarePaws AI — an assistant, not a vet — so I only help with your own pets here at CarePaws. "
      'Ask me about feeding, health, vaccines or a health check and I will take it from there.';
}

/// One AI provider's key, switch and live model, as shown in Settings.
/// A snapshot — read fresh via [AiService.statusFor] after any change.
class AiProviderStatus {
  const AiProviderStatus({
    required this.provider,
    required this.enabled,
    required this.keyConfigured,
    required this.keyFromDevice,
    required this.isLive,
    this.modelLabel,
    this.failure,
  });

  final AiProvider provider;
  final bool enabled;
  final bool keyConfigured;
  final bool keyFromDevice;
  final bool isLive;
  final String? modelLabel;
  final AiFailure? failure;
}

/// The transport contract every provider implements. Bootstrapping validates
/// the key and picks a model; [generate] answers one request. Neither ever
/// throws for an expected failure — [bootstrap] records [failure] and
/// [generate] throws [AiException] instead.
abstract class AiBackend {
  AiProvider get provider;
  bool get isLive;
  String? get modelId;
  String? get modelLabel;
  AiFailure? get failure;

  Future<void> bootstrap();
  void markDown(AiFailure failure);

  Future<String> triage({
    required String system,
    required String prompt,
    required String description,
    Uint8List? photo,
    String? photoMime,
  });

  Future<String> chat({required String system, required String userText});
}

/// Gemini, over the native `generateContent` API. Keeps the dynamic free-tier
/// model probe: the models list is ranked best-first and each candidate is
/// probed with a real minimal request, so the pick is the best *usable* model,
/// not just the best-listed one.
class GeminiBackend implements AiBackend {
  GeminiBackend({
    required this._client,
    required this.timeout,
    required this.key,
  });

  @override
  AiProvider get provider => AiProvider.gemini;

  final http.Client _client;
  final Duration timeout;
  final String key;

  static const _base = 'generativelanguage.googleapis.com';
  static const _v1beta = 'v1beta';

  bool _live = false;
  String? _modelId;
  String? _modelLabel;
  AiFailure? _failure;

  @override
  bool get isLive => _live;
  @override
  String? get modelId => _modelId;
  @override
  String? get modelLabel => _modelLabel;
  @override
  AiFailure? get failure => _failure;

  @override
  void markDown(AiFailure failure) {
    _live = false;
    _failure = failure;
  }

  /// Free-tier text model IDs, newest family first. Only used when the
  /// models-list endpoint fails or lists nothing usable — the dynamic list
  /// is always the primary path, so this never overrides what the API
  /// reports. Verified against Google's pricing page 2026-10-14: the 2.0
  /// family was shut down 2026-06-01, and omni / image / pro-preview are
  /// paid-only.
  static const _knownFreeIds = <String>[
    'gemini-3.8-flash',
    'gemini-3.5-flash',
    'gemini-3.1-flash-lite',
    'gemini-2.5-flash',
    'gemini-2.5-flash-lite',
    'gemini-2.5-pro',
  ];

  @override
  Future<void> bootstrap() async {
    _live = false;
    _modelId = null;
    _modelLabel = null;
    _failure = null;
    try {
      final candidates = await _candidates();
      for (final c in candidates) {
        if (await _probe(c.name)) {
          _modelId = c.name;
          _modelLabel = c.label;
          _live = true;
          debugPrint('[ai] live model: ${c.name}');
          return;
        }
        debugPrint('[ai] candidate ${c.name} did not answer, trying next');
      }
      _failure = AiFailure.serviceError;
    } on AiException catch (e) {
      _failure = e.failure;
    } on TimeoutException {
      _failure = AiFailure.unreachable;
    } catch (_) {
      _failure = AiFailure.unreachable;
    }
  }

  /// Ordered probe candidates: the API's live list first (filtered to
  /// free-tier text models and ranked best-first), then the known-free
  /// fallback IDs for when the list endpoint drifts or fails. Duplicates
  /// are removed; list order is probe order.
  Future<List<_Model>> _candidates() async {
    final out = <_Model>[];
    final seen = <String>{};
    try {
      for (final c in await _listModels()) {
        if (seen.add(c.name)) out.add(c);
      }
    } on AiException catch (e) {
      // Unreachable: the probes would fail too — propagate it.
      // 400/401/403 from the list endpoint means the key itself is
      // rejected — probing other models with the same key cannot succeed,
      // so fail fast instead of burning quota on doomed probes.
      if (e.failure == AiFailure.unreachable) rethrow;
      if (RegExp(r'HTTP 40[013]').hasMatch(e.detail ?? '')) rethrow;
      // Any other list failure falls through to the known IDs below.
    }
    for (final id in _knownFreeIds) {
      if (seen.add(id)) out.add(_Model(id, id));
    }
    return out;
  }

  /// One-word liveness probe. True when the key, the model and the tier all
  /// work together: HTTP 200 plus any text in the reply. Anything else —
  /// 400 on a bad key, 403/429 on quota or billing, transport failure —
  /// means "try the next candidate", never a crash.
  Future<bool> _probe(String id) async {
    try {
      final uri = Uri.https(_base, '/$_v1beta/models/$id:generateContent', {
        'key': key,
      });
      final res = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'role': 'user',
                  'parts': [
                    {'text': 'Reply with exactly this word: ok'},
                  ],
                },
              ],
              'generationConfig': {'temperature': 0, 'maxOutputTokens': 8},
            }),
          )
          .timeout(timeout);
      if (res.statusCode != 200) return false;
      return _content(res.body).trim().isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Free-tier candidates that advertise multimodal input, flash family first.
  /// Throws [AiException]: unreachable on transport failure, serviceError on
  /// a non-200 answer.
  Future<List<_Model>> _listModels() async {
    final uri = Uri.https(_base, '/$_v1beta/models', {'key': key});
    http.Response res;
    try {
      res = await _client.get(uri).timeout(timeout);
    } on TimeoutException {
      throw const AiException(AiFailure.unreachable);
    } on http.ClientException {
      throw const AiException(AiFailure.unreachable);
    } catch (_) {
      throw const AiException(AiFailure.unreachable);
    }
    if (res.statusCode != 200) {
      throw AiException(AiFailure.serviceError, 'HTTP ${res.statusCode}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final models = (body['models'] as List? ?? const []);
    final out = <_Model>[];
    for (final raw in models) {
      final m = raw as Map<String, dynamic>;
      final name = (m['name'] as String? ?? '').replaceFirst('models/', '');
      if (name.isEmpty) continue;
      final methods = (m['supportedGenerationMethods'] as List? ?? const [])
          .cast<String>();
      if (!methods.contains('generateContent')) continue;
      // Skip anything that is not a free-tier text model:
      // tuned: custom tuned models, not free-tier defaults.
      // embedding/aqa: not generative text.
      // tts/live/transcribe: audio endpoints with different request shapes.
      // image/omni: paid-only (image generation, Omni Flash).
      // robotics/veo/lyria: specialized models, not general chat.
      final n = name.toLowerCase();
      if (n.contains('tuned') ||
          n.contains('embedding') ||
          n.contains('aqa') ||
          n.contains('tts') ||
          n.contains('live') ||
          n.contains('transcribe') ||
          n.contains('image') ||
          n.contains('omni') ||
          n.contains('robotics') ||
          n.contains('veo') ||
          n.contains('lyria')) {
        continue;
      }
      out.add(_Model(name, m['displayName'] as String? ?? name));
    }
    out.sort(_rank);
    return out;
  }

  /// Ranks candidates: flash family first, then full flash over lite, then
  /// stable builds over previews and rolling aliases. Lower score is better.
  static int _score(_Model m) {
    final n = m.name.toLowerCase();
    var s = 0;
    if (!n.contains('flash')) s += 20;
    if (n.contains('lite')) s += 2;
    if (n.contains('preview') || n.contains('exp')) s += 6;
    if (n.contains('latest')) s += 1;
    return s;
  }

  static int _rank(_Model a, _Model b) {
    final d = _score(a).compareTo(_score(b));
    if (d != 0) return d;
    // Same tier: prefer the newest version number.
    final d2 = b.name.compareTo(a.name);
    if (d2 != 0) return d2;
    return a.name.compareTo(b.name);
  }

  Uri _generateUri() {
    final id = _modelId;
    if (id == null) throw AiException(_failure ?? AiFailure.noKey);
    return Uri.https(_base, '/$_v1beta/models/$id:generateContent', {
      'key': key,
    });
  }

  /// POSTs to the selected model. Non-200 answers are service errors — the
  /// caller maps transport failures to [AiFailure.unreachable].
  Future<http.Response> _post(Map<String, Object?> body) async {
    final res = await _client
        .post(
          _generateUri(),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(timeout);
    if (res.statusCode != 200) {
      throw AiException(AiFailure.serviceError, 'HTTP ${res.statusCode}');
    }
    return res;
  }

  /// POSTs a chat body that asks for structured JSON. Some models accept
  /// generateContent but reject responseJsonSchema with a 400 — in that
  /// case the request is retried once as plain text, which [_parseChat]
  /// already handles gracefully.
  Future<http.Response> _postChat(Map<String, Object?> withSchema) async {
    try {
      return await _post(withSchema);
    } on AiException catch (e) {
      final badRequest =
          e.failure == AiFailure.serviceError &&
          (e.detail ?? '').contains('400');
      if (!badRequest) rethrow;
      debugPrint('[ai] model rejected JSON schema, retrying as plain text');
      final plain = Map<String, Object?>.from(withSchema);
      final gc =
          Map<String, Object?>.from(
              withSchema['generationConfig'] as Map<String, Object?>,
            )
            ..remove('responseMimeType')
            ..remove('responseJsonSchema');
      plain['generationConfig'] = gc;
      return await _post(plain);
    }
  }

  @override
  Future<String> triage({
    required String system,
    required String prompt,
    required String description,
    Uint8List? photo,
    String? photoMime,
  }) async {
    try {
      final parts = <Map<String, Object?>>[
        <String, Object?>{'text': prompt},
        if (description.isNotEmpty)
          <String, Object?>{'text': "Owner's description: $description"},
      ];
      // Gemini image input uses camelCase `inlineData` — the old snake_case
      // `inline_data` key was silently ignored, so photo triage behaved like
      // text-only and photo answers looked "not working".
      if (photo != null) {
        parts.add({
          'inlineData': {
            'mimeType': photoMime ?? 'image/jpeg',
            'data': base64Encode(photo),
          },
        });
      } else if (description.isEmpty) {
        parts.add({
          'text': 'The pet shows a visible concern but no text description was given.',
        });
      }
      final body = {
        'systemInstruction': {
          'parts': [
            {'text': system},
          ],
        },
        'contents': [
          {'role': 'user', 'parts': parts},
        ],
        'generationConfig': {'temperature': 0.3, 'maxOutputTokens': 700},
        'safetySettings': <Map<String, Object?>>[
          <String, Object?>{
            'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
            'threshold': 'BLOCK_ONLY_HIGH',
          },
        ],
      };
      final res = await _post(body);
      return _content(res.body);
    } on AiException {
      rethrow;
    } on TimeoutException {
      throw const AiException(AiFailure.unreachable);
    } on http.ClientException {
      throw const AiException(AiFailure.unreachable);
    } on FormatException {
      throw const AiException(AiFailure.serviceError, 'unparseable reply');
    } catch (_) {
      throw const AiException(AiFailure.unreachable);
    }
  }

  @override
  Future<String> chat({
    required String system,
    required String userText,
  }) async {
    try {
      final body = {
        'systemInstruction': {
          'parts': [
            {'text': system},
          ],
        },
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': userText},
            ],
          },
        ],
        'generationConfig': {
          'temperature': 0.5,
          'maxOutputTokens': 400,
          'responseMimeType': 'application/json',
          'responseJsonSchema': {
            'type': 'object',
            'properties': {
              'inScope': {'type': 'boolean'},
              'reply': {'type': 'string'},
            },
            'required': ['inScope', 'reply'],
          },
        },
      };
      final res = await _postChat(body);
      return _content(res.body).trim();
    } on AiException {
      rethrow;
    } on TimeoutException {
      throw const AiException(AiFailure.unreachable);
    } on http.ClientException {
      throw const AiException(AiFailure.unreachable);
    } on FormatException {
      throw const AiException(AiFailure.serviceError, 'unparseable reply');
    } catch (_) {
      throw const AiException(AiFailure.unreachable);
    }
  }

  String _content(String body) {
    final j = jsonDecode(body) as Map<String, dynamic>;
    final parts = (j['candidates'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .firstOrNull;
    final content = parts?['content'] as Map<String, dynamic>?;
    final list = (content?['parts'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    return list.map((e) => e['text'] as String? ?? '').join('\n');
  }
}

/// OpenAI and OpenRouter, over the OpenAI-compatible `/chat/completions` API.
/// Photos travel as data URLs. `response_format: json_object` is requested
/// for structured answers, with a plain-text retry when a model rejects it.
class OpenAiBackend implements AiBackend {
  OpenAiBackend({
    required this.provider,
    required this._client,
    required this.timeout,
    required this.key,
  }) {
    assert(
      provider == AiProvider.openai || provider == AiProvider.openrouter,
      'OpenAiBackend only serves OpenAI-compatible providers',
    );
  }

  @override
  final AiProvider provider;

  final http.Client _client;
  final Duration timeout;
  final String key;

  String get _host =>
      provider == AiProvider.openai ? 'api.openai.com' : 'openrouter.ai';
  String get _basePath => provider == AiProvider.openai ? '/v1' : '/api/v1';

  /// Sensible default when the models list is unavailable or lacks it.
  String get _preferredModel =>
      provider == AiProvider.openai ? 'gpt-4o-mini' : 'google/gemini-2.5-flash';

  bool _live = false;
  String? _modelId;
  AiFailure? _failure;

  @override
  bool get isLive => _live;
  @override
  String? get modelId => _modelId;
  @override
  String? get modelLabel => _modelId;
  @override
  AiFailure? get failure => _failure;

  @override
  void markDown(AiFailure failure) {
    _live = false;
    _failure = failure;
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $key',
    if (provider == AiProvider.openrouter)
      'HTTP-Referer': 'https://carepaws.app',
    if (provider == AiProvider.openrouter) 'X-Title': 'CarePaws',
  };

  @override
  Future<void> bootstrap() async {
    _live = false;
    _modelId = null;
    _failure = null;
    List<String> ids;
    try {
      ids = await _listModels();
    } on AiException catch (e) {
      _failure = e.failure;
      return;
    }
    final pick = ids.contains(_preferredModel)
        ? _preferredModel
        : _firstChatty(ids) ?? (ids.isNotEmpty ? ids.first : _preferredModel);
    if (await _probe(pick)) {
      _modelId = pick;
      _live = true;
      debugPrint('[ai] live model: $provider $pick');
    } else {
      _failure = AiFailure.serviceError;
    }
  }

  /// First model id that looks like a chat model rather than an embedding,
  /// image or audio model.
  String? _firstChatty(List<String> ids) {
    for (final id in ids) {
      final n = id.toLowerCase();
      if (n.contains('embedding') ||
          n.contains('tts') ||
          n.contains('whisper') ||
          n.contains('dall-e') ||
          n.contains('image')) {
        continue;
      }
      return id;
    }
    return null;
  }

  Future<List<String>> _listModels() async {
    final uri = Uri.https(_host, '$_basePath/models');
    http.Response res;
    try {
      res = await _client.get(uri, headers: _headers).timeout(timeout);
    } on TimeoutException {
      throw const AiException(AiFailure.unreachable);
    } on http.ClientException {
      throw const AiException(AiFailure.unreachable);
    } catch (_) {
      throw const AiException(AiFailure.unreachable);
    }
    if (res.statusCode != 200) {
      throw AiException(AiFailure.serviceError, 'HTTP ${res.statusCode}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final data = (body['data'] as List? ?? const []);
    return [
      for (final raw in data)
        if (raw is Map<String, dynamic> &&
            (raw['id'] as String? ?? '').isNotEmpty)
          raw['id'] as String,
    ];
  }

  /// One-word liveness probe: HTTP 200 plus any text in the reply.
  Future<bool> _probe(String model) async {
    try {
      final res = await _postJson({
        'model': model,
        'messages': [
          {'role': 'user', 'content': 'Reply with exactly this word: ok'},
        ],
        'temperature': 0,
        'max_tokens': 8,
      });
      return _messageContent(res).trim().isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// POSTs a chat-completions body. Non-200 answers are service errors —
  /// the caller maps transport failures to [AiFailure.unreachable].
  Future<Map<String, dynamic>> _postJson(Map<String, Object?> body) async {
    final uri = Uri.https(_host, '$_basePath/chat/completions');
    http.Response res;
    try {
      res = await _client
          .post(uri, headers: _headers, body: jsonEncode(body))
          .timeout(timeout);
    } on TimeoutException {
      throw const AiException(AiFailure.unreachable);
    } on http.ClientException {
      throw const AiException(AiFailure.unreachable);
    } catch (_) {
      throw const AiException(AiFailure.unreachable);
    }
    if (res.statusCode != 200) {
      throw AiException(AiFailure.serviceError, 'HTTP ${res.statusCode}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  String _messageContent(Map<String, dynamic> body) {
    final choices = (body['choices'] as List? ?? const []);
    if (choices.isEmpty) return '';
    final message = (choices.first as Map<String, dynamic>)['message'];
    if (message is! Map<String, dynamic>) return '';
    final content = message['content'];
    if (content is String) return content;
    // Some providers return content blocks.
    if (content is List) {
      return content
          .whereType<Map<String, dynamic>>()
          .map((b) => b['text'] as String? ?? '')
          .join('\n');
    }
    return '';
  }

  List<Map<String, Object?>> _userParts({
    required String text,
    Uint8List? photo,
    String? photoMime,
  }) {
    final parts = <Map<String, Object?>>[
      {'type': 'text', 'text': text},
    ];
    if (photo != null) {
      parts.add({
        'type': 'image_url',
        'image_url': {
          'url':
              'data:${photoMime ?? 'image/jpeg'};base64,${base64Encode(photo)}',
        },
      });
    }
    return parts;
  }

  /// Sends one chat-completions request, asking for a JSON object when
  /// [jsonMode] and retrying once as plain text when the model rejects it.
  Future<String> _complete({
    required String system,
    required String text,
    Uint8List? photo,
    String? photoMime,
    required double temperature,
    required int maxTokens,
    required bool jsonMode,
  }) async {
    final model = _modelId;
    if (model == null) throw AiException(_failure ?? AiFailure.noKey);
    Map<String, Object?> body({required bool structured}) => {
      'model': model,
      'messages': [
        {'role': 'system', 'content': system},
        {
          'role': 'user',
          'content': _userParts(text: text, photo: photo, photoMime: photoMime),
        },
      ],
      'temperature': temperature,
      'max_tokens': maxTokens,
      if (structured) 'response_format': {'type': 'json_object'},
    };
    try {
      final res = await _postJson(body(structured: jsonMode));
      return _messageContent(res).trim();
    } on AiException catch (e) {
      final badRequest =
          e.failure == AiFailure.serviceError &&
          (e.detail ?? '').contains('400');
      if (!jsonMode || !badRequest) rethrow;
      debugPrint('[ai] model rejected json_object, retrying as plain text');
      final res = await _postJson(body(structured: false));
      return _messageContent(res).trim();
    } on FormatException {
      throw const AiException(AiFailure.serviceError, 'unparseable reply');
    }
  }

  @override
  Future<String> triage({
    required String system,
    required String prompt,
    required String description,
    Uint8List? photo,
    String? photoMime,
  }) async {
    final text = description.isEmpty
        ? (photo == null
              ? '$prompt\n\nThe pet shows a visible concern but no text description was given.'
              : prompt)
        : '$prompt\n\nOwner\'s description: $description';
    try {
      return await _complete(
        system: system,
        text: text,
        photo: photo,
        photoMime: photoMime,
        temperature: 0.3,
        maxTokens: 700,
        jsonMode: true,
      );
    } on AiException {
      rethrow;
    } on TimeoutException {
      throw const AiException(AiFailure.unreachable);
    } on http.ClientException {
      throw const AiException(AiFailure.unreachable);
    } catch (_) {
      throw const AiException(AiFailure.unreachable);
    }
  }

  @override
  Future<String> chat({
    required String system,
    required String userText,
  }) async {
    try {
      return await _complete(
        system: system,
        text: userText,
        temperature: 0.5,
        maxTokens: 400,
        jsonMode: true,
      );
    } on AiException {
      rethrow;
    } on TimeoutException {
      throw const AiException(AiFailure.unreachable);
    } on http.ClientException {
      throw const AiException(AiFailure.unreachable);
    } catch (_) {
      throw const AiException(AiFailure.unreachable);
    }
  }
}

/// One provider's slot in the routing table: its on-device key, its on/off
/// switch, and the backend built from them on the last bootstrap.
class _ProviderSlot {
  _ProviderSlot(this.provider);

  final AiProvider provider;
  String? deviceKey;
  bool enabled = true;
  AiBackend? backend;

  String get effectiveKey {
    final d = deviceKey?.trim() ?? '';
    return d.isNotEmpty ? d : provider.buildKey;
  }

  bool get keyConfigured => AiService.looksLikeKey(effectiveKey, provider);
  bool get keyFromDevice => AiService.looksLikeKey(deviceKey, provider);

  /// A slot only routes when it is switched on and holds a real key.
  bool get configured => enabled && keyConfigured;
}

/// Talks to the configured AI providers with automatic failover. Without a
/// key, or when every provider fails, requests throw [AiException] — there
/// is no canned fallback, so the UI always says exactly what went wrong.
class AiService {
  AiService({http.Client? client, this.timeout = const Duration(seconds: 12)})
    : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;

  /// Routing table in priority order: Gemini, then OpenAI, then OpenRouter.
  final List<_ProviderSlot> _slots = [
    for (final p in AiProvider.values) _ProviderSlot(p),
  ];

  _ProviderSlot? _active;

  /// Rejects blanks and the placeholder so a half-pasted key fails loudly
  /// instead of silently leaving the provider unconfigured.
  static bool looksLikeKey(String? k, AiProvider provider) =>
      k != null &&
      k.trim().isNotEmpty &&
      k.trim() != provider.placeholder &&
      k.trim().length > 20;

  /// Starts unavailable when no provider has a key, so the UI is honest from
  /// the very first frame, and only probes the network when a key exists.
  AiStatus status = AiProvider.values.any((p) => looksLikeKey(p.buildKey, p))
      ? AiStatus.checking
      : AiStatus.unavailable;

  /// Why the last bootstrap or request failed. Null when live.
  AiFailure? failure = AiProvider.values.any((p) => looksLikeKey(p.buildKey, p))
      ? null
      : AiFailure.noKey;

  bool get isLive => status == AiStatus.live;
  bool get isUnavailable => status == AiStatus.unavailable;

  /// The active backend's model id, e.g. `gemini-2.5-flash`.
  String? get modelId => _active?.backend?.modelId;

  /// What the UI shows, e.g. `Gemini · gemini-2.5-flash`.
  String? get modelLabel {
    final slot = _active;
    final label = slot?.backend?.modelLabel;
    if (slot == null || label == null) return null;
    return '${slot.provider.label} · $label';
  }

  bool get keyConfigured => _slots.any((s) => s.configured);

  /// The providers in routing priority order, for Settings.
  List<AiProvider> get providers => AiProvider.values;

  /// A snapshot of one provider's state for Settings.
  AiProviderStatus statusFor(AiProvider provider) {
    final slot = _slot(provider);
    final backend = slot.backend;
    return AiProviderStatus(
      provider: provider,
      enabled: slot.enabled,
      keyConfigured: slot.keyConfigured,
      keyFromDevice: slot.keyFromDevice,
      isLive: backend?.isLive ?? false,
      modelLabel: backend?.modelLabel,
      failure: backend?.failure,
    );
  }

  _ProviderSlot _slot(AiProvider provider) =>
      _slots.firstWhere((s) => s.provider == provider);

  AiBackend _buildBackend(_ProviderSlot slot) => switch (slot.provider) {
    AiProvider.gemini => GeminiBackend(
      client: _client,
      timeout: timeout,
      key: slot.effectiveKey,
    ),
    AiProvider.openai || AiProvider.openrouter => OpenAiBackend(
      provider: slot.provider,
      client: _client,
      timeout: timeout,
      key: slot.effectiveKey,
    ),
  };

  /// Runs at startup and after every key or switch change. Restores on-device
  /// keys, then bootstraps every configured provider in priority order — the
  /// first live one answers requests, the rest stand by for failover.
  /// Safe to call again any time.
  Future<void> bootstrap() async {
    await _restore();
    _active = null;
    status = AiStatus.checking;
    failure = null;
    var anyConfigured = false;
    AiFailure? lastFailure;
    for (final slot in _slots) {
      if (!slot.configured) {
        slot.backend = null;
        continue;
      }
      anyConfigured = true;
      final backend = _buildBackend(slot);
      slot.backend = backend;
      try {
        await backend.bootstrap();
      } catch (_) {
        // Backends record their own failure; a throw here is unexpected.
      }
      if (backend.isLive) {
        _active ??= slot;
      } else {
        lastFailure = backend.failure ?? lastFailure;
      }
    }
    if (_active != null) {
      status = AiStatus.live;
      failure = null;
      debugPrint('[ai] active provider: ${_active!.provider.label}');
    } else {
      _enterUnavailable(
        anyConfigured
            ? (lastFailure ?? AiFailure.serviceError)
            : AiFailure.noKey,
      );
    }
  }

  /// Re-probes every configured provider. Settings calls this for
  /// "Test connection".
  Future<void> recheck() => bootstrap();

  void _setActive(_ProviderSlot slot) {
    _active = slot;
    status = AiStatus.live;
    failure = null;
  }

  void _enterUnavailable(AiFailure why) {
    _active = null;
    status = AiStatus.unavailable;
    failure = why;
    debugPrint('[ai] unavailable: ${why.name}');
  }

  /// Reads on-device keys and switches, if there are any. A missing plugin
  /// (unit tests, desktop) is not an error: it just means nothing is stored.
  /// Never overwrites values set in-memory via [useKeyFor] before a bootstrap.
  Future<void> _restore() async {
    final prefs = await _openPrefs();
    for (final slot in _slots) {
      slot.deviceKey ??= prefs?.getString(slot.provider.keyPref);
      final enabled = prefs?.getBool(slot.provider.enabledPref);
      if (enabled != null) slot.enabled = enabled;
    }
    // Pre-multi-provider installs stored the Gemini key under the old name.
    // Migrate it so existing users do not silently lose their key. A key
    // already saved under the new name wins; the legacy entry is removed
    // either way so the migration runs once.
    const legacyKey = 'carepaws.gemini_api_key';
    final legacy = prefs?.getString(legacyKey);
    if (legacy != null && legacy.isNotEmpty) {
      final gemini = _slot(AiProvider.gemini);
      if (gemini.deviceKey == null) {
        gemini.deviceKey = legacy;
        await prefs?.setString(AiProvider.gemini.keyPref, legacy);
      }
      await prefs?.remove(legacyKey);
    }
  }

  Future<SharedPreferences?> _openPrefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  /// Saves a key entered on the device for one provider and re-probes
  /// straight away, so the Settings status flips without a restart.
  /// A blank value clears the key. Returns whether that provider is actually
  /// answering now — not just whether a plausible-looking key was saved.
  Future<bool> useKeyFor(AiProvider provider, String key) async {
    final slot = _slot(provider);
    final trimmed = key.trim();
    final prefs = await _openPrefs();
    if (looksLikeKey(trimmed, provider)) {
      slot.deviceKey = trimmed;
      await prefs?.setString(provider.keyPref, trimmed);
    } else {
      slot.deviceKey = null;
      await prefs?.remove(provider.keyPref);
    }
    await bootstrap();
    return slot.backend?.isLive ?? false;
  }

  /// Forgets one provider's on-device key, leaving any build-time key behind it.
  Future<bool> clearKeyFor(AiProvider provider) => useKeyFor(provider, '');

  /// Switches one provider on or off and re-probes.
  Future<void> setProviderEnabled(AiProvider provider, bool enabled) async {
    final slot = _slot(provider);
    slot.enabled = enabled;
    final prefs = await _openPrefs();
    await prefs?.setBool(provider.enabledPref, enabled);
    await bootstrap();
  }

  /// Routing order for a request: the active slot first, then the other live
  /// slots, then configured-but-not-live slots (they get one fresh bootstrap
  /// before their attempt). Priority order is kept inside each group because
  /// the sort is stable.
  List<_ProviderSlot> _routingOrder() {
    final configured = _slots.where((s) => s.configured).toList();
    int score(_ProviderSlot s) => s == _active
        ? 0
        : (s.backend?.isLive ?? false)
        ? 1
        : 2;
    configured.sort((a, b) => score(a).compareTo(score(b)));
    return configured;
  }

  /// Runs [attempt] against the routing table, moving to the next provider
  /// whenever one fails. Throws the last [AiException] when every provider
  /// is exhausted — and marks the service unavailable with its reason.
  Future<T> _withFailover<T>(Future<T> Function(AiBackend) attempt) async {
    final order = _routingOrder();
    if (order.isEmpty) throw const AiException(AiFailure.noKey);
    AiException? lastError;
    for (final slot in order) {
      var backend = slot.backend;
      if (backend == null || !backend.isLive) {
        backend = _buildBackend(slot);
        slot.backend = backend;
        try {
          await backend.bootstrap();
        } catch (_) {
          // Recorded on the backend itself.
        }
      }
      if (!backend.isLive) {
        lastError = AiException(backend.failure ?? AiFailure.serviceError);
        continue;
      }
      try {
        final out = await attempt(backend);
        _setActive(slot);
        return out;
      } on AiException catch (e) {
        lastError = e;
        backend.markDown(e.failure);
        debugPrint(
          '[ai] ${slot.provider.label} failed (${e.failure.name}), failing over',
        );
      }
    }
    final why = lastError?.failure ?? AiFailure.noKey;
    _enterUnavailable(why);
    throw lastError ?? const AiException(AiFailure.noKey);
  }

  /// Health check for the selected pet. Throws [AiException] when no provider
  /// can answer. A provider whose reply does not parse counts as failed, so
  /// the next provider gets a turn.
  Future<TriageResult> triage({
    required String petName,
    required String species,
    required String text,
    Uint8List? photo,
    String? photoMime,
    String ownerFirstName = '',
  }) async {
    return _withFailover((b) async {
      final raw = await b.triage(
        system: VetPersona.systemFor(
          now: DateTime.now(),
          ownerFirstName: ownerFirstName,
        ),
        prompt: _triagePrompt(petName, species, hasPhoto: photo != null),
        description: text,
        photo: photo,
        photoMime: photoMime,
      );
      final parsed = _parseTriage(raw);
      if (parsed == null) {
        throw const AiException(AiFailure.serviceError, 'unparseable reply');
      }
      return parsed;
    });
  }

  /// Health check where the AI also identifies which pet the concern is about.
  /// Returns the triage result plus the matched pet name exactly as the model
  /// wrote it (null when the model could not determine it — never guessed).
  /// Throws [AiException] when no provider can answer. An unparseable reply
  /// counts as a failed attempt, so the next provider gets a turn.
  Future<({TriageResult result, String? petName})> triageDetect({
    required List<Pet> pets,
    required String text,
    Uint8List? photo,
    String? photoMime,
    String ownerFirstName = '',
  }) async {
    return _withFailover((b) async {
      final raw = await b.triage(
        system: VetPersona.systemFor(
          now: DateTime.now(),
          ownerFirstName: ownerFirstName,
        ),
        prompt: _triageDetectPrompt(pets, hasPhoto: photo != null),
        description: text,
        photo: photo,
        photoMime: photoMime,
      );
      final parsed = _parseDetect(raw);
      if (parsed == null) {
        throw const AiException(AiFailure.serviceError, 'unparseable reply');
      }
      return parsed;
    });
  }

  /// General pet-care chat answer. Throws [AiException] when no provider can
  /// answer. An empty reply counts as a failed attempt so the next provider
  /// gets a turn; a malformed-but-nonempty reply is shown as-is (better an
  /// imperfect answer than a swallowed question).
  Future<String> chat({
    required String petName,
    required String species,
    required String question,
    String ownerFirstName = '',
  }) async {
    // The model returns a small envelope so scope is decided in the same
    // round trip — no extra call, and no keyword regex that would misfire on
    // legitimate answers like "what food should I feed my dog".
    final userText =
        "The owner is asking about $petName, a $species, from home in the clinic's app.\n"
        'Answer in 3-5 short sentences, warm and practical.\n'
        'Reply with ONLY a JSON object, no markdown, exactly:\n'
        '{"inScope":true|false,"reply":"your answer"}\n'
        'Set inScope to false if the question is not about veterinary care '
        'for this pet.\n'
        'Question: $question';
    final system = VetPersona.systemFor(
      now: DateTime.now(),
      ownerFirstName: ownerFirstName,
    );
    return _withFailover((b) async {
      final raw = await b.chat(system: system, userText: userText);
      if (raw.isEmpty) {
        throw const AiException(AiFailure.serviceError, 'empty reply');
      }

      // A malformed reply is treated as in-scope and shown as-is: better to
      // show an imperfect answer than to silently swallow a real question.
      final parsed = _parseChat(raw);
      if (parsed == null) return raw;
      if (!parsed.inScope) return VetPersona.redirect;
      if (parsed.reply.trim().isEmpty) {
        throw const AiException(AiFailure.serviceError, 'empty reply');
      }
      return parsed.reply.trim();
    });
  }

  /// Reads the `{"inScope":…,"reply":…}` envelope. Returns null when the model
  /// did not produce usable JSON, so the caller can fall back gracefully.
  static ({bool inScope, String reply})? _parseChat(String raw) {
    var s = raw.trim();
    final start = s.indexOf('{');
    final end = s.lastIndexOf('}');
    if (start == -1 || end <= start) return null;
    s = s.substring(start, end + 1);
    try {
      final j = jsonDecode(s) as Map<String, dynamic>;
      final reply = (j['reply'] as String? ?? '').trim();
      // Absent flag defaults to in-scope: an unlabelled but sensible answer
      // should not be thrown away.
      final inScope = (j['inScope'] as bool?) ?? true;
      return (inScope: inScope, reply: reply);
    } catch (_) {
      return null;
    }
  }

  void dispose() => _client.close();
}

String _triagePrompt(
  String petName,
  String species, {
  required bool hasPhoto,
}) =>
    'You triage pet health concerns for a veterinary clinic app. The pet is $petName ($species). '
    '${hasPhoto ? 'A photo of the pet is attached. ' : ''}'
    'Reply with ONLY a JSON object, no markdown, using exactly these keys: '
    '{"route":"book|chat|homeCare|emergency","urgency":0|1|2,"title":"short headline",'
    '"summary":"2-3 sentences","bullets":["what we noticed"],'
    '"redFlags":["danger signs that need a vet"],'
    '"homeCare":["care instructions"],"nextStep":"one sentence"}'
    'Choose route "emergency" for breathing difficulty, collapse, seizures, heavy bleeding, poisoning or severe pain. '
    'Choose "homeCare" only for mild, low-risk concerns. Otherwise use "book". This is guidance, not a diagnosis. '
    'Write warmly and reassuringly, like a calm vet nurse talking to a worried owner: plain words, no alarming '
    'language ("emergency", "critical", "danger", "immediately") in the title or summary — say what is needed, kindly.';

String _triageDetectPrompt(List<Pet> pets, {required bool hasPhoto}) {
  final roster = pets
      .map((p) => '${p.name} (${p.species.name}, ${p.breed})')
      .join('; ');
  return 'You triage pet health concerns for a veterinary clinic app. '
      "The owner's pets are: $roster. "
      '${hasPhoto ? 'A photo of the pet is attached. ' : ''}'
      'First identify which pet the concern is about from the description: use the exact name '
      'from the list above. If there is only one pet, it is that one. If the description does not '
      'identify a pet, use null for petName — never guess. '
      'Reply with ONLY a JSON object, no markdown, using exactly these keys: '
      '{"petName":"exact name from the list or null","route":"book|chat|homeCare|emergency",'
      '"urgency":0|1|2,"title":"short headline",'
      '"summary":"2-3 sentences","bullets":["what we noticed"],'
      '"redFlags":["danger signs that need a vet"],'
      '"homeCare":["care instructions"],"nextStep":"one sentence"}'
      'Choose route "emergency" for breathing difficulty, collapse, seizures, heavy bleeding, poisoning or severe pain. '
      'Choose "homeCare" only for mild, low-risk concerns. Otherwise use "book". This is guidance, not a diagnosis. '
      'Write warmly and reassuringly, like a calm vet nurse talking to a worried owner: plain words, no alarming '
      'language ("emergency", "critical", "danger", "immediately") in the title or summary — say what is needed, kindly.';
}

/// Parses the model's JSON reply and clamps it into a valid TriageResult.
TriageResult? _parseTriage(String raw) {
  final j = _extractJson(raw);
  return j == null ? null : _triageFromJson(j);
}

/// Parses a detect-mode reply: the triage result plus the model's pet
/// identification (null when the model could not determine it).
({TriageResult result, String? petName})? _parseDetect(String raw) {
  final j = _extractJson(raw);
  if (j == null) return null;
  final result = _triageFromJson(j);
  if (result == null) return null;
  final petName = (j['petName'] as String?)?.trim();
  return (
    result: result,
    petName: petName == null || petName.isEmpty ? null : petName,
  );
}

Map<String, dynamic>? _extractJson(String raw) {
  var s = raw.trim();
  final start = s.indexOf('{');
  final end = s.lastIndexOf('}');
  if (start == -1 || end <= start) return null;
  s = s.substring(start, end + 1);
  try {
    return jsonDecode(s) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}

TriageResult? _triageFromJson(Map<String, dynamic> j) {
  try {
    final route = switch ((j['route'] as String? ?? '').toLowerCase()) {
      'emergency' => TriageRoute.emergency,
      'homecare' => TriageRoute.homeCare,
      'chat' => TriageRoute.chat,
      _ => TriageRoute.book,
    };
    final u = (j['urgency'] as num?)?.toInt().clamp(0, 2) ?? 1;
    List<String> strs(String k) => (j[k] as List? ?? const [])
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return TriageResult(
      route: route,
      urgency: route == TriageRoute.emergency ? 2 : u,
      title: ((j['title'] as String?) ?? 'Health check complete').trim(),
      summary: ((j['summary'] as String?) ?? '').trim(),
      bullets: strs('bullets'),
      redFlags: strs('redFlags'),
      homeCare: strs('homeCare'),
      nextStep: (j['nextStep'] as String?)?.trim(),
    );
  } catch (_) {
    return null;
  }
}

class _Model {
  const _Model(this.name, this.label);
  final String name;
  final String label;
}
