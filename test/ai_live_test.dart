@Tags(['live'])
library;


import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carepaws/data/models.dart';
import 'package:carepaws/services/ai_service.dart';

/// Live Gemini API checks. Skipped unless a key is supplied at build time:
///
///   flutter test --dart-define=GEMINI_API_KEY=... --tags live
///
/// The key is never stored in the repository — the only place it can appear is
/// `lib/services/ai_service.dart` as a build-time constant.
void main() {
  // No network needed: with no key the service must be honestly unavailable.
  group('Unavailable without a key', () {
    test('bootstrap reports noKey and requests throw it', () async {
      final ai = AiService();
      addTearDown(ai.dispose);
      await ai.bootstrap();
      expect(ai.status, AiStatus.unavailable);
      expect(ai.failure, AiFailure.noKey);
      await expectLater(
        ai.chat(petName: 'Biscuit', species: 'dog', question: 'hi'),
        throwsA(isA<AiException>().having((e) => e.failure, 'failure', AiFailure.noKey)),
      );
    });
  });

  final hasKey = geminiApiKey.isNotEmpty &&
      geminiApiKey != 'YOUR_GEMINI_API_KEY' &&
      geminiApiKey.length > 20;
  if (!hasKey) {
    test('live AI tests skipped (no GEMINI_API_KEY)', () {}, skip: true);
    return;
  }

  group('Gemini model discovery', () {
    test('bootstraps into live mode and picks a vision-capable model', () async {
      final ai = AiService();
      await ai.bootstrap();
      expect(ai.status, AiStatus.live, reason: 'should reach live mode');
      expect(ai.isUnavailable, isFalse);
      expect(ai.modelId, isNotNull);
      expect(ai.modelId, isNotEmpty);
      // A full flash-family model is preferred over lite/preview/aliases.
      expect(ai.modelId, contains('flash'));
      expect(ai.modelId, isNot(contains('lite')));
      expect(ai.modelId, isNot(contains('preview')));
      expect(ai.modelId, isNot(contains('latest')));
      expect(ai.modelId, isNot(contains('tts')));
      expect(ai.modelId, isNot(contains('embedding')));
      debugPrint('[live] selected model: ${ai.modelId}');
      ai.dispose();
    }, timeout: const Timeout(Duration(seconds: 60)));
  });

  group('Live triage', () {
    late AiService ai;

    setUpAll(() async {
      ai = AiService();
      await ai.bootstrap();
    });

    tearDownAll(() => ai.dispose());

    Future<TriageResult> triage(String text, {Uint8List? photo}) => ai.triage(
      petName: 'Biscuit',
      species: 'Golden Retriever',
      text: text,
      photo: photo,
    );

    test('serious signs route to emergency', () async {
      final r = await triage('Biscuit collapsed and is struggling to breathe');
      expect(r.route, TriageRoute.emergency);
      expect(r.urgency, 2);
      expect(r.title, isNotEmpty);
      expect(r.summary, isNotEmpty);
      expect(r.redFlags, isNotEmpty);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('moderate symptoms route to booking or chat', () async {
      final r = await triage('Biscuit has been vomiting since last night');
      expect(
        r.route,
        anyOf(TriageRoute.book, TriageRoute.chat, TriageRoute.homeCare),
      );
      expect(r.route, isNot(TriageRoute.emergency));
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('mild concern can be handled at home', () async {
      final r = await triage('Mochi is shedding a lot, how often should I brush her?');
      expect(r.route, isNot(TriageRoute.emergency));
      expect(r.summary, isNotEmpty);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('accepts a photo (vision input) and still returns a usable result',
        () async {
      // 1x1 transparent PNG.
      final png = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
        0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
        0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
        0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
      ]);
      final r = await triage('Is this coat healthy?', photo: png);
      expect(r.route, isNotNull);
      expect(r.summary, isNotEmpty);
    }, timeout: const Timeout(Duration(seconds: 60)));
  });

  group('Live chat', () {
    test('answers a general care question', () async {
      final ai = AiService();
      await ai.bootstrap();
      final answer = await ai.chat(
        petName: 'Biscuit',
        species: 'Golden Retriever',
        question: 'How often should I brush a golden retriever?',
      );
      expect(answer, isNotEmpty);
      expect(answer.length, greaterThan(20));
      ai.dispose();
    }, timeout: const Timeout(Duration(seconds: 60)));
  });

  group('Fallback behaviour', () {
    test('an unreachable API surfaces unreachable instead of a canned answer', () async {
      // A 1ms timeout guarantees the request cannot complete; the service
      // must report unreachable, never guess.
      final ai = AiService(timeout: const Duration(milliseconds: 1));
      addTearDown(ai.dispose);
      await ai.bootstrap();
      expect(ai.status, AiStatus.unavailable);
      expect(ai.failure, AiFailure.unreachable);
    });
  });
}