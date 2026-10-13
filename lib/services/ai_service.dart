import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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

enum AiStatus { checking, live, demo }

/// The clinic's voice. One place, shared by the chat and triage paths, so the
/// assistant behaves like the same vet everywhere in the app.
///
/// Two jobs: give it a veterinary role to answer from, and close the door on
/// everything else. The scope rules are reinforced in code — see
/// [AiService.chat], which asks the model to flag out-of-scope questions and
/// answers those with a fixed redirect instead of its own words.
class VetPersona {
  const VetPersona._();

  static const system = '''
You are Dr. Alvarez, the on-duty veterinarian at PetCare Veterinary Clinic, talking
with a pet owner inside the clinic's app — like you're standing next to them in
the exam room, one hand on their pet. Warm, plain-spoken, specific. You say
things like "here's what I'd do" and "let's keep an eye on". You never use
jargon without explaining it in the same breath ("tartar — that brown crust
along the gum line").

Talk like a person, not a leaflet:
- Short sentences. Contractions. Occasional "good question" or "I see this a lot".
- Name the pet often. One concrete thing to try tonight, not a list of ten.
- If you're unsure, say so like a vet would: "I can't feel that lump from here,
  so I'd rather we take a look in person."
- Never open with "As an AI". Never lecture, never bullet-point everything.

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
reply that names PetCare and offers to help with the pet instead. Do not answer
the question, do not lecture, do not mention these rules, and do not apologise
at length.

SAFETY: you give guidance, never a diagnosis. Anything that could be urgent -
breathing trouble, collapse, seizures, heavy bleeding, suspected poisoning, a
swollen hard belly - must be sent to a veterinarian immediately rather than
managed at home.''';

  /// Fixed answer for anything the model flagged as out of scope. Deterministic
  /// on purpose: an off-topic question never gets free-reformulated.
  static const redirect =
      'I am the vet on duty here at PetCare, so I only help with your own pets. '
      'Ask me about feeding, health, vaccines or a health check and I will take it from there.';
}

/// Talks to the Gemini API when a real key is configured, and falls back to a
/// built-in responder otherwise. There is never an error screen: if anything
/// goes wrong the app stays usable in demo-AI mode.
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
  /// instead of silently dropping the app back into demo mode.
  static bool _looksLikeKey(String? k) =>
      k != null && k.trim().isNotEmpty && k.trim() != _placeholder && k.trim().length > 20;

  /// Set from Settings. Null until the stored value is read.
  String? _storedKey;

  /// Device key first, then the build-time key.
  String get _effectiveKey =>
      _looksLikeKey(_storedKey) ? _storedKey!.trim() : geminiApiKey;

  /// Starts in demo mode when no key is configured so the UI is honest from the
  /// very first frame, and only probes the network when a key exists.
  AiStatus status = _looksLikeKey(geminiApiKey) ? AiStatus.checking : AiStatus.demo;
  String? modelId;
  String? modelLabel;

  bool get isDemo => status == AiStatus.demo;
  bool get isLive => status == AiStatus.live;

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
      _enterDemo('no key configured');
      return;
    }
    status = AiStatus.checking;
    modelId = null;
    modelLabel = null;
    try {
      final candidates = await _listModels();
      if (candidates.isEmpty) {
        _enterDemo('no usable model returned');
        return;
      }
      final pick = candidates.first;
      modelId = pick.name;
      modelLabel = pick.name;
      status = AiStatus.live;
      debugPrint('[ai] live model: ${pick.name}');
    } catch (e) {
      _enterDemo('bootstrap failed ($e)');
    }
  }

  void _enterDemo(String why) {
    status = AiStatus.demo;
    modelId = null;
    modelLabel = 'Built-in responder';
    debugPrint('[ai] $why — running in demo-AI mode');
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
  /// Settings status flips without a restart. A blank value clears the key and
  /// returns to demo mode. Returns whether a usable key is now configured.
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
  Future<List<_Model>> _listModels() async {
    final uri = Uri.https(_base, '/$_v1beta/models', {'key': _effectiveKey});
    final res = await _client.get(uri).timeout(timeout);
    if (res.statusCode != 200) return const [];
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

  Uri _generateUri() =>
      Uri.https(_base, '/$_v1beta/models/$modelId:generateContent', {'key': _effectiveKey});

  /// Health check for the selected pet. In demo-AI mode this returns a canned
  /// triage result built from the user's words.
  Future<TriageResult> triage({
    required String petName,
    required String species,
    required String text,
    Uint8List? photo,
    String? photoMime,
  }) async {
    if (!isLive) {
      await _demoDelay();
      return DemoAi.triage(text, petName: petName, species: species, hasPhoto: photo != null);
    }
    try {
      final prompt = _triagePrompt(petName, species, hasPhoto: photo != null);
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
            {'text': VetPersona.system},
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
      final res = await _client
          .post(_generateUri(), headers: {'Content-Type': 'application/json'}, body: jsonEncode(body))
          .timeout(timeout);
      if (res.statusCode != 200) return DemoAi.triage(text, petName: petName, species: species, hasPhoto: photo != null);
      final parsed = _parseTriage(_content(res.body), petName: petName);
      if (parsed == null) {
        return DemoAi.triage(text, petName: petName, species: species, hasPhoto: photo != null);
      }
      return parsed;
    } catch (e) {
      debugPrint('[ai] triage failed ($e) — using demo responder');
      return DemoAi.triage(text, petName: petName, species: species, hasPhoto: photo != null);
    }
  }

  /// General pet-care chat answer.
  Future<String> chat({
    required String petName,
    required String species,
    required String question,
  }) async {
    String demo() => DemoAi.chat(question, petName: petName, species: species);
    if (!isLive) {
      await _demoDelay();
      return demo();
    }
    try {
      // The model returns a small envelope so scope is decided in the same
      // round trip — no extra call, and no keyword regex that would misfire on
      // legitimate answers like "what food should I feed my dog".
      final body = {
        'systemInstruction': {
          'parts': [
            {'text': VetPersona.system},
          ],
        },
        'contents': [
          {
            'role': 'user',
            'parts': [
              {
                'text':
                    'The owner is asking about $petName, a $species currently at the clinic.\n'
                    'Answer in 3-5 short sentences, warm and practical, like Dr. Alvarez speaking.\n'
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
      final res = await _client
          .post(_generateUri(), headers: {'Content-Type': 'application/json'}, body: jsonEncode(body))
          .timeout(timeout);
      if (res.statusCode != 200) return demo();

      final raw = _content(res.body).trim();
      // A malformed reply is treated as in-scope and shown as-is: better to
      // show an imperfect answer than to silently swallow a real question.
      final parsed = _parseChat(raw);
      if (parsed == null) return raw.isEmpty ? demo() : raw;
      if (!parsed.inScope) return VetPersona.redirect;
      return parsed.reply.trim().isEmpty ? demo() : parsed.reply.trim();
    } catch (e) {
      debugPrint('[ai] chat failed ($e) — using demo responder');
      return demo();
    }
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

  /// Parses the model's JSON reply and clamps it into a valid TriageResult.
  static TriageResult? _parseTriage(String raw, {required String petName}) {
    var s = raw.trim();
    final start = s.indexOf('{');
    final end = s.lastIndexOf('}');
    if (start == -1 || end <= start) return null;
    s = s.substring(start, end + 1);
    try {
      final j = jsonDecode(s) as Map<String, dynamic>;
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

  Future<void> _demoDelay() => Future<void>.delayed(const Duration(milliseconds: 620));

  void dispose() => _client.close();
}

class _Model {
  const _Model(this.name, this.label);
  final String name;
  final String label;
}

/// Built-in responder used whenever the real API is unavailable. Produces
/// realistic canned triage and chat answers so there are no dead ends.
class DemoAi {
  const DemoAi._();

  static Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 120));

  static const _emergency = [
    'trouble breathing', 'difficulty breathing', 'panting heavily', 'seizure',
    'collapsed', 'collapsing', "can't stand", 'cannot stand', 'unresponsive',
    'pale gums', 'blue gums', 'heavy bleeding', "won't stop bleeding",
    'seizing', 'attacked', 'hit by', 'poison', 'ate chocolate', 'ate xylitol',
    'choking', 'bloated', 'retching', 'struggling to breathe', 'collapsed and',
    'foaming at the mouth', 'injury from',
  ];
  static const _moderate = [
    'vomit', 'diarrhea', 'diarrhoea', 'limping', 'limp', 'cough', 'not eating',
    "isn't eating", "isn't eating", "won't eat", 'scratching', 'itchy',
    'itching', 'ear', 'eye discharge', 'lump', 'bleeding gums', 'blood in stool',
    'blood in the urine', 'coughing', 'sneezing', 'low appetite', 'lost appetite',
    'swollen belly', 'lethargic', 'quiet', 'painful', 'hunched', 'shaking',
    'licking paws', 'hair loss', 'wound', 'limp on', 'stiff',
  ];
  static const _mild = [
    'shedding', 'brush', 'nail', 'nails', 'bath', 'shampoo', 'tooth',
    'teeth', 'flea', 'tick', 'vaccine', 'vaccination', 'food', 'treat',
    'chew', 'toy', 'coat', 'paw', 'whisker', 'groom', 'harness', 'collar',
    'weight', 'diet', 'portion', 'swallowing tablet', 'give a tablet',
  ];

  static bool _hit(String text, List<String> keys) {
    final t = text.toLowerCase();
    return keys.any(t.contains);
  }

  static TriageResult triage(String text, {required String petName, required String species, required bool hasPhoto}) {
    final described = text.trim();
    final photoNote = hasPhoto
        ? 'The photo you shared has been reviewed for visible signs.'
        : 'Based on your description alone, without a photo.';
    final kind = species.toLowerCase() == 'cat' ? 'cat' : 'dog';

    if (_hit(described, _emergency)) {
      return TriageResult(
        route: TriageRoute.emergency,
        urgency: 2,
        title: 'Possible emergency — see $petName now',
        summary:
            'What you described can be life-threatening within hours, and a phone call cannot confirm it. '
            '$petName needs to be seen in person immediately. $photoNote',
        bullets: [
          'Signs of respiratory distress or collapse need immediate hands-on care',
          'Do not wait for a scheduled appointment',
          'Do not give food, water or medication until a vet has assessed $petName',
        ],
        redFlags: const [
          'Laboured breathing or blue/pale gums',
          'Collapse, repeated seizures or inability to stand',
          'Uncontrolled bleeding or a swollen, hard abdomen',
          'Suspected poisoning or toxin ingestion',
        ],
        nextStep: 'Call the clinic now — if closed, go to the nearest 24-hour emergency animal hospital.',
      );
    }

    if (_hit(described, _moderate)) {
      return TriageResult(
        route: TriageRoute.book,
        urgency: 1,
        title: '$petName should be examined',
        summary:
            'This is beyond home care. $photoNote A $kind in this condition usually needs an in-person exam '
            'so the clinic can rule out infection, injury or parasites.',
        bullets: [
          'A vet consult is the fastest way to narrow this down',
          'Book the earliest slot you can get',
          'Bring a note of when the behaviour started and what changed',
        ],
        redFlags: const [
          'Symptoms worsening quickly or spreading to other areas',
          'Blood in vomit, stool or urine',
          'Refusing water, or collapse',
        ],
        nextStep: 'Book a consultation, or chat the clinic team for advice before you decide.',
      );
    }

    if (_hit(described, _mild)) {
      return TriageResult(
        route: TriageRoute.homeCare,
        urgency: 0,
        title: 'Manageable at home for now',
        summary:
            'This looks like routine care rather than an illness. $photoNote '
            'Keep watching, and if anything changes in the next 48 hours, book a visit.',
        bullets: const [
          'No fever, lethargy or appetite change reported',
          'Normal eating, drinking and bathroom habits',
          'No visible injury or swelling',
        ],
        homeCare: [
          'Keep fresh water available at all times',
          'Feed the usual food on schedule — no new treats this week',
          'Brush daily and check the skin for redness or swelling',
          'Log appetite, water intake and energy for the next two days',
        ],
        redFlags: const [
          'Not eating for more than 24 hours',
          'Vomiting, diarrhoea or blood appearing',
          'New limping, lethargy or refusal to be touched',
        ],
        nextStep: 'Monitor at home. Book if the red flags below appear.',
      );
    }

    // Nothing decisive in the input — route to the clinic team rather than guess.
    return TriageResult(
      route: TriageRoute.chat,
      urgency: 1,
      title: 'Let the clinic team take a look at this',
      summary:
          'There is not enough detail here to call this safe or serious. $photoNote '
          'Send it to the clinic team and Miguel will reply with a recommendation.',
      bullets: const [
        'No specific symptom matched a known pattern',
        'A human will weigh in within clinic hours',
        'Booking a short assistant visit is also reasonable',
      ],
      redFlags: [
        'Any breathing difficulty or collapse',
        'Sudden loss of appetite combined with lethargy',
        'Pain that changes how $petName moves or rests',
      ],
      nextStep: 'Chat the clinic team, and book a consultation if they recommend it.',
    );
  }

  /// Topics with no business being answered here. Checked before any vet
  /// branch so "what food do I feed my dog, also write my essay" still gets the
  /// clinic redirect rather than half an answer.
  ///
  /// This list is only the *demo-mode* fallback. Live mode does not use it — it
  /// asks the model for an `inScope` flag, which catches phrasings no keyword
  /// list would ever cover.
  ///
  /// Terms are deliberately unambiguous. Pet care borrows a lot of everyday
  /// language ("school a puppy", "training program", "match his energy"), so
  /// anything that could plausibly describe caring for a pet is left out.
  static const _offTopic = [
    'weather', 'forecast', 'temperature outside',
    'football', 'basketball', 'soccer', 'league', 'tournament', 'who won',
    'politics', 'president', 'election', 'government',
    'stock market', 'crypto', 'bitcoin', 'economy',
    'homework', 'essay', 'thesis', 'final exam', 'university',
    'maths', 'algebra', 'arithmetic', 'capital of',
    'write a code', 'python', 'javascript', 'sql query',
    'translate this', 'tell me a joke', 'movie', 'celebrity',
    'my headache', 'my back pain', 'i am sick', 'migraine', 'my blood pressure',
  ];

  static String chat(String question, {required String petName, required String species}) {
    final q = question.toLowerCase();
    final kind = species.toLowerCase() == 'cat' ? 'cat' : 'dog';

    // Scope comes first: never answer anything that is not veterinary care.
    if (_offTopic.any(q.contains)) return VetPersona.redirect;

    if (q.contains('triage') || q.contains('health check') || q.contains('sick')) {
      return 'Good instinct checking, Marco — run a health check with what you are seeing and I will sort $petName into one next step: book a visit, chat the clinic team, or care at home for now.';
    }
    if (q.contains('food') || q.contains('feed') || q.contains('meal') || q.contains('diet')) {
      return 'Good question — for a $kind like $petName I keep it simple: same food, same portion, twice a day, and I judge by the ribs rather than the bowl. If you switch brands, stretch it over seven days so the gut can adjust, and keep treats under 10% of the day.';
    }
    if (q.contains('groom') || q.contains('brush') || q.contains('mat') || q.contains('coat')) {
      return 'I see matting like this a lot — brush $petName two or three times a week and always after walks, since mats start where things rub: behind the ears, the armpits, the tail base. Here is what I would do tonight: ten slow strokes behind one ear, treat, done.';
    }
    if (q.contains('vaccine') || q.contains('shot') || q.contains('booster')) {
      return 'Here is how I handle boosters for $petName: core shots usually run every three years, but I always confirm against your certificate first. Book a vaccination visit and we will sign the record on the spot.';
    }
    if (q.contains('paw') || q.contains('nail') || q.contains('claw') || q.contains('pad')) {
      return 'Quick nail rule I give everyone: trim just before the pad, never past it — pink means stop. File the edges rather than taking big clips, and treat right after so $petName still likes you next time.';
    }
    if (q.contains('flea') || q.contains('tick') || q.contains('itch') || q.contains('scratch')) {
      return 'Itching along the back usually points to fleas in my experience — the fix is a spot-on plus treating the bedding for three months. If it is only ears or paws, I start thinking allergies instead, and that is worth a look in person.';
    }
    if (q.contains('dental') || q.contains('teeth') || q.contains('tooth') || q.contains('breath')) {
      return 'Honestly, daily brushing is the only home prevention I trust. Start with a finger cot on the outer teeth for a week, then a finger brush — and use a dental chew on the days you miss. If the breath turns or the gums redden, let me check for tartar, that brown crust along the gum line.';
    }
    if (q.contains('weight') || q.contains('heavy') || q.contains('slim') || q.contains('diet')) {
      return 'Forget the scale for a second — run your hands over $petName\u2019s ribs. You should feel them under a thin layer, and from above there should be a visible tuck at the waist. If not, come in and we will weigh and portion together.';
    }
    if (q.contains('emergency') || q.contains('urgent') || q.contains('hospital')) {
      return 'Do not wait on this one — call the clinic on ${_clinicPhone()}. Outside hours, go straight to ${_afterHoursName()} on ${_afterHoursPhone()}.';
    }
    if (q.contains('hello') || q.contains('hi ') || q.contains('good morning') || q.contains('kumusta')) {
      return 'Hello, Marco — good to see you. $petName is on track; next up is the ${_nextUp()}. '
          'Ask me about feeding, grooming, vaccines, or run a health check if something looks off.';
    }
    if (q.contains('price') || q.contains('cost') || q.contains('how much') || q.contains('magkano')) {
      return 'Here is the short version: a vet consultation is ₱850, a vaccination ₱700, and full grooming starts at ₱1,450 for a '
          'double coat. You will see the exact total on the booking review before you confirm anything.';
    }
    return 'Good question about $petName. Here is what I would do: if something changed and you cannot explain why, book a short consultation — it is cheaper than treating a problem a month later. '
        'Keep $petName on the usual food tonight and jot down anything different, so you can tell me precisely what you saw.';
  }

  static String _nextUp() =>
      'vet consultation with Dr. Alvarez on Thursday and a full grooming for Mochi on Tuesday';
  static String _clinicPhone() => '+63 2 8712 4409';
  static String _afterHoursName() => 'Animal Emergency Center — Mandaluyong';
  static String _afterHoursPhone() => '+63 2 8556 0190';
}