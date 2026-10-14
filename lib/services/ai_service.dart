import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../data/clinic.dart';
import '../data/models.dart';

/// ---------------------------------------------------------------------------
/// Gemini API key.
///
/// Two sources, in priority order:
///   1. A key typed into Settings ▸ PetCare AI on the device (dev/test only —
///      it is stored in plaintext on the phone, so it never ships).
///   2. A key baked in at build time:
///        flutter run --dart-define=GEMINI_API_KEY=your_key_here
///
/// This remains the only place a key is declared.
/// ---------------------------------------------------------------------------
// ignore: prefer_const_declarations
const String geminiApiKey = String.fromEnvironment(
  'GEMINI_API_KEY',
  defaultValue: 'YOUR_GEMINI_API_KEY',
);

enum AiStatus { checking, live, unavailable }

/// Why the assistant cannot answer right now. Surfaced verbatim in the
/// "AI unavailable" UI, so each case names exactly what went wrong.
enum AiFailure {
  noKey('No API key is configured', 'Paste a key in Settings → PetCare AI to turn it on.'),
  unreachable("Couldn't reach the AI service", 'Check the connection and try again, or paste a fresh key in Settings → PetCare AI.'),
  serviceError('The AI service returned an error', 'The key may be invalid — paste a fresh one in Settings → PetCare AI and try again.');

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

  static String systemFor({required DateTime now, required String ownerFirstName}) {
    final open = Clinic.isOpenNow(now);
    final nameLine = ownerFirstName.isEmpty
        ? 'The owner did not share a name — greet them plainly and never invent one.'
        : "The owner's first name is $ownerFirstName — use it when it feels natural, never any other name.";
    return '''
You are PetCare AI, the assistant inside the ${Clinic.name} app. You are an AI
assistant, not a veterinarian and not Dr. Alvarez. The owner is at home,
talking to you on their phone — you are not in the room with them. The pet's
name and species come with each question; name the pet often.

Voice: warm, plain-spoken, specific. Short sentences, contractions. One
concrete thing to try tonight, not a list of ten. Never open with "As an AI".
Never use jargon without explaining it in the same breath ("tartar — that
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
      "I'm PetCare AI — an assistant, not a vet — so I only help with your own pets here at PetCare. "
      'Ask me about feeding, health, vaccines or a health check and I will take it from there.';
}

/// Talks to the Gemini API when a real key is configured. Without a key, or
/// when the network or the API fails, every request throws [AiException] —
/// there is no canned fallback, so the UI always says exactly what went wrong.
class AiService {
  AiService({http.Client? client, this.timeout = const Duration(seconds: 12)})
    : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;

  static const _base = 'generativelanguage.googleapis.com';
  static const _v1beta = 'v1beta';

  /// Where an on-device key is kept between launches.
  static const keyPrefName = 'petcare.gemini_api_key';
  static const _keyPref = keyPrefName;
  static const _placeholder = 'YOUR_GEMINI_API_KEY';

  /// Rejects blanks and the placeholder so a half-pasted key fails loudly
  /// instead of silently leaving the assistant unavailable.
  static bool _looksLikeKey(String? k) =>
      k != null && k.trim().isNotEmpty && k.trim() != _placeholder && k.trim().length > 20;

  /// Set from Settings. Null until the stored value is read.
  String? _storedKey;

  /// Device key first, then the build-time key.
  String get _effectiveKey =>
      _looksLikeKey(_storedKey) ? _storedKey!.trim() : geminiApiKey;

  /// Starts unavailable when no key is configured so the UI is honest from the
  /// very first frame, and only probes the network when a key exists.
  AiStatus status = _looksLikeKey(geminiApiKey) ? AiStatus.checking : AiStatus.unavailable;

  /// Why the last bootstrap or request failed. Null when live.
  AiFailure? failure = _looksLikeKey(geminiApiKey) ? null : AiFailure.noKey;

  String? modelId;
  String? modelLabel;

  bool get isLive => status == AiStatus.live;
  bool get isUnavailable => status == AiStatus.unavailable;

  bool get keyConfigured => _looksLikeKey(_effectiveKey);

  /// True when the key came from the device rather than the build. Settings
  /// uses this to warn that the value is stored in plaintext.
  bool get keyFromDevice => _looksLikeKey(_storedKey);

  /// Runs at startup. Loads any on-device key, then lists models and dynamically
  /// picks a free-tier model that supports text + image input, preferring the
  /// flash family. Safe to call again after a key changes.
  Future<void> bootstrap() async {
    await _restoreKey();
    if (!keyConfigured) {
      _enterUnavailable(AiFailure.noKey);
      return;
    }
    status = AiStatus.checking;
    failure = null;
    modelId = null;
    modelLabel = null;
    try {
      final candidates = await _listModels();
      if (candidates.isEmpty) {
        _enterUnavailable(AiFailure.serviceError);
        return;
      }
      final pick = candidates.first;
      modelId = pick.name;
      modelLabel = pick.name;
      status = AiStatus.live;
      failure = null;
      debugPrint('[ai] live model: ${pick.name}');
    } on AiException catch (e) {
      _enterUnavailable(e.failure);
    } on TimeoutException {
      _enterUnavailable(AiFailure.unreachable);
    } catch (_) {
      _enterUnavailable(AiFailure.unreachable);
    }
  }

  void _enterUnavailable(AiFailure why) {
    status = AiStatus.unavailable;
    failure = why;
    modelId = null;
    modelLabel = null;
    debugPrint('[ai] unavailable: ${why.name}');
  }

  /// Reads the on-device key, if there is one. A missing plugin (unit tests,
  /// desktop) is not an error: it just means there is no stored key.
  Future<void> _restoreKey() async {
    if (_storedKey != null) return;
    final prefs = await _openPrefs();
    _storedKey = prefs?.getString(_keyPref);
  }

  Future<SharedPreferences?> _openPrefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  /// Saves a key entered on the device and re-probes straight away, so the
  /// Settings status flips without a restart. A blank value clears the key.
  /// Returns whether a usable key is now configured.
  Future<bool> useKey(String key) async {
    final trimmed = key.trim();
    final prefs = await _openPrefs();
    if (_looksLikeKey(trimmed)) {
      _storedKey = trimmed;
      await prefs?.setString(_keyPref, trimmed);
    } else {
      _storedKey = null;
      await prefs?.remove(_keyPref);
    }
    await bootstrap();
    return keyConfigured;
  }

  /// Forgets the on-device key, leaving any build-time key in charge.
  Future<bool> clearKey() => useKey('');

  /// Free-tier candidates that advertise multimodal input, flash family first.
  /// Throws [AiException]: unreachable on transport failure, serviceError on
  /// a non-200 answer.
  Future<List<_Model>> _listModels() async {
    final uri = Uri.https(_base, '/$_v1beta/models', {'key': _effectiveKey});
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
      // Tuning a generative model (e.g. *_tuned) is not a free-tier default.
      if (name.contains('tuned')) continue;
      // Vision: models with image understanding are not embeddings / aqa / tts.
      if (name.contains('embedding') ||
          name.contains('aqa') ||
          name.contains('tts') ||
          name.contains('live')) {
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
    final id = modelId;
    if (id == null) throw AiException(failure ?? AiFailure.noKey);
    return Uri.https(_base, '/$_v1beta/models/$id:generateContent', {'key': _effectiveKey});
  }

  /// Throws [AiException] when the assistant cannot answer.
  Never _requireLive() {
    throw AiException(failure ?? AiFailure.noKey);
  }

  /// Health check for the selected pet. Throws [AiException] when there is no
  /// key, the network fails, or the API answers with an error.
  Future<TriageResult> triage({
    required String petName,
    required String species,
    required String text,
    Uint8List? photo,
    String? photoMime,
    String ownerFirstName = '',
  }) async {
    final raw = await _generateTriage(
      prompt: _triagePrompt(petName, species, hasPhoto: photo != null),
      text: text,
      photo: photo,
      photoMime: photoMime,
      ownerFirstName: ownerFirstName,
    );
    final parsed = _parseTriage(raw);
    if (parsed == null) {
      throw const AiException(AiFailure.serviceError, 'unparseable reply');
    }
    return parsed;
  }

  /// Health check where the AI also identifies which pet the concern is about.
  /// Returns the triage result plus the matched pet name exactly as the model
  /// wrote it (null when the model could not determine it — never guessed).
  /// Throws [AiException] when there is no key, the network fails, or the API
  /// answers with an error.
  Future<({TriageResult result, String? petName})> triageDetect({
    required List<Pet> pets,
    required String text,
    Uint8List? photo,
    String? photoMime,
    String ownerFirstName = '',
  }) async {
    final raw = await _generateTriage(
      prompt: _triageDetectPrompt(pets, hasPhoto: photo != null),
      text: text,
      photo: photo,
      photoMime: photoMime,
      ownerFirstName: ownerFirstName,
    );
    final parsed = _parseDetect(raw);
    if (parsed == null) {
      throw const AiException(AiFailure.serviceError, 'unparseable reply');
    }
    return parsed;
  }

  /// Sends one triage-style generation request and returns the model's raw
  /// text. Throws [AiException] on any transport or API failure.
  Future<String> _generateTriage({
    required String prompt,
    required String text,
    Uint8List? photo,
    String? photoMime,
    required String ownerFirstName,
  }) async {
    if (!isLive) _requireLive();
    try {
      final parts = <Map<String, Object?>>[
        <String, Object?>{'text': prompt},
        if (text.isNotEmpty)
          <String, Object?>{'text': "Owner's description: $text"},
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
      } else if (text.isEmpty) {
        parts.add({
          'text':
              'The pet shows a visible concern but no text description was given.',
        });
      }
      final body = {
        'systemInstruction': {
          'parts': [
            {'text': VetPersona.systemFor(now: DateTime.now(), ownerFirstName: ownerFirstName)},
          ],
        },
        'contents': [
          {
            'role': 'user',
            'parts': parts,
          }
        ],
        'generationConfig': {'temperature': 0.3, 'maxOutputTokens': 700},
        'safetySettings': <Map<String, Object?>>[
          <String, Object?>{
            'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
            'threshold': 'BLOCK_ONLY_HIGH',
          }
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

  /// General pet-care chat answer. Throws [AiException] when the assistant
  /// cannot answer.
  Future<String> chat({
    required String petName,
    required String species,
    required String question,
    String ownerFirstName = '',
  }) async {
    if (!isLive) _requireLive();
    try {
      // The model returns a small envelope so scope is decided in the same
      // round trip — no extra call, and no keyword regex that would misfire on
      // legitimate answers like "what food should I feed my dog".
      final body = {
        'systemInstruction': {
          'parts': [
            {'text': VetPersona.systemFor(now: DateTime.now(), ownerFirstName: ownerFirstName)},
          ],
        },
        'contents': [
          {
            'role': 'user',
            'parts': [
              {
                'text':
                    "The owner is asking about $petName, a $species, from home in the clinic's app.\n"
                    'Answer in 3-5 short sentences, warm and practical.\n'
                    'Reply with ONLY a JSON object, no markdown, exactly:\n'
                    '{"inScope":true|false,"reply":"your answer"}\n'
                    'Set inScope to false if the question is not about veterinary care '
                    'for this pet.\n'
                    'Question: $question',
              }
            ],
          }
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
      final res = await _post(body);

      final raw = _content(res.body).trim();
      // A malformed reply is treated as in-scope and shown as-is: better to
      // show an imperfect answer than to silently swallow a real question.
      final parsed = _parseChat(raw);
      if (parsed == null) {
        if (raw.isEmpty) throw const AiException(AiFailure.serviceError, 'empty reply');
        return raw;
      }
      if (!parsed.inScope) return VetPersona.redirect;
      if (parsed.reply.trim().isEmpty) {
        throw const AiException(AiFailure.serviceError, 'empty reply');
      }
      return parsed.reply.trim();
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

  /// POSTs to the selected model. Non-200 answers are service errors — the
  /// caller maps transport failures to [AiFailure.unreachable].
  Future<http.Response> _post(Map<String, Object?> body) async {
    final res = await _client
        .post(_generateUri(), headers: {'Content-Type': 'application/json'}, body: jsonEncode(body))
        .timeout(timeout);
    if (res.statusCode != 200) {
      throw AiException(AiFailure.serviceError, 'HTTP ${res.statusCode}');
    }
    return res;
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

  String _content(String body) {
    final j = jsonDecode(body) as Map<String, dynamic>;
    final parts = (j['candidates'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .firstOrNull;
    final content = parts?['content'] as Map<String, dynamic>?;
    final list = (content?['parts'] as List? ?? const []).cast<Map<String, dynamic>>();
    return list.map((e) => e['text'] as String? ?? '').join('\n');
  }

  static String _triagePrompt(String petName, String species, {required bool hasPhoto}) =>
      'You triage pet health concerns for a veterinary clinic app. The pet is $petName ($species). '
      '${hasPhoto ? 'A photo of the pet is attached. ' : ''}'
      'Reply with ONLY a JSON object, no markdown, using exactly these keys: '
      '{"route":"book|chat|homeCare|emergency","urgency":0|1|2,"title":"short headline",'
      '"summary":"2-3 sentences","bullets":["what we noticed"],'
      '"redFlags":["danger signs that need a vet"],'
      '"homeCare":["care instructions"],"nextStep":"one sentence"}'
      'Choose route "emergency" for breathing difficulty, collapse, seizures, heavy bleeding, poisoning or severe pain. '
      'Choose "homeCare" only for mild, low-risk concerns. Otherwise use "book". This is guidance, not a diagnosis.';

  static String _triageDetectPrompt(List<Pet> pets,
          {required bool hasPhoto}) {
    final roster =
        pets.map((p) => '${p.name} (${p.species.name}, ${p.breed})').join('; ');
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
        'Choose "homeCare" only for mild, low-risk concerns. Otherwise use "book". This is guidance, not a diagnosis.';
  }

  /// Parses the model's JSON reply and clamps it into a valid TriageResult.
  static TriageResult? _parseTriage(String raw) {
    final j = _extractJson(raw);
    return j == null ? null : _triageFromJson(j);
  }

  /// Parses a detect-mode reply: the triage result plus the model's pet
  /// identification (null when the model could not determine it).
  static ({TriageResult result, String? petName})? _parseDetect(String raw) {
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

  static Map<String, dynamic>? _extractJson(String raw) {
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

  static TriageResult? _triageFromJson(Map<String, dynamic> j) {
    try {
      final route = switch ((j['route'] as String? ?? '').toLowerCase()) {
        'emergency' => TriageRoute.emergency,
        'homecare' => TriageRoute.homeCare,
        'chat' => TriageRoute.chat,
        _ => TriageRoute.book,
      };
      final u = (j['urgency'] as num?)?.toInt().clamp(0, 2) ?? 1;
      List<String> strs(String k) =>
          (j[k] as List? ?? const []).map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
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

  void dispose() => _client.close();
}

class _Model {
  const _Model(this.name, this.label);
  final String name;
  final String label;
}
