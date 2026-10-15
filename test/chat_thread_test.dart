import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:carepaws/data/models.dart';
import 'package:carepaws/design/icons.dart';
import 'package:carepaws/design/theme.dart';
import 'package:carepaws/screens/chat_thread_screen.dart';
import 'package:carepaws/state/app_store.dart';
import 'package:carepaws/widgets/ai_unavailable.dart';

/// Tuesday 2026-10-13 10:00 — inside clinic hours (Mon–Sat 9:00–18:00).
DateTime openNow() => DateTime(2026, 10, 13, 10, 0);

/// Sunday 2026-10-11 10:00 — clinic closed.
DateTime closedNow() => DateTime(2026, 10, 11, 10, 0);

Future<AppStore> pumpThread(
  WidgetTester tester,
  String threadId, {
  DateTime? now,
  String? accountName,
}) async {
  SharedPreferences.setMockInitialValues({});
  await tester.binding.setSurfaceSize(const Size(390, 844));
  final s = AppStore(now: now ?? openNow());
  s.accountName = accountName;
  s.accountEmail = 'mark@example.com';
  await tester.pumpWidget(
    AppScope(
      store: s,
      child: CupertinoApp(
        theme: themeFor(AppPalette.light),
        home: ChatThreadScreen(threadId: threadId),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return s;
}

Future<void> sendText(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(CupertinoTextField).first, text);
  await tester.pump();
  await tester.tap(find.bySemanticsLabel('Send message'));
  await tester.pumpAndSettle();
}

void main() {
  group('clinic team tone (#11)', () {
    testWidgets('reply addresses the user by first name, never email', (
      tester,
    ) async {
      await pumpThread(
        tester,
        'th_clinic',
        accountName: 'Mark Jefferson Rivera',
      );
      await sendText(tester, 'I have a question about my appointment.');
      expect(find.textContaining('Thanks, Mark!'), findsOneWidget);
      expect(find.textContaining('@'), findsNothing);
      // Warm copy, no bureaucratic "noted on".
      expect(find.textContaining('noted on'), findsNothing);
      // Dynamic reply: references the booking inquiry, never canned.
      expect(
        find.textContaining('I\u2019ll confirm the slot here'),
        findsOneWidget,
      );
    });

    testWidgets('an email-like "name" falls back to a plain greeting', (
      tester,
    ) async {
      await pumpThread(
        tester,
        'th_clinic',
        // The user typed their email into the name field at registration.
        accountName: 'rivermarkjefferson13@gmail.com',
      );
      await sendText(tester, 'I have a question about my appointment.');
      expect(find.textContaining('Thanks!'), findsOneWidget);
      expect(
        find.textContaining('rivermarkjefferson13@gmail.com'),
        findsNothing,
      );
    });

    testWidgets('offline reply is warm and names the 9 AM reopening', (
      tester,
    ) async {
      await pumpThread(
        tester,
        'th_clinic',
        now: closedNow(),
        accountName: 'Mark Jefferson Rivera',
      );
      await sendText(tester, 'I have a question about my appointment.');
      expect(find.textContaining('Thanks, Mark!'), findsOneWidget);
      expect(find.textContaining('back at 9:00 AM'), findsOneWidget);
      expect(find.textContaining('Got your message.'), findsNothing);
    });
  });

  group('photo sending (#12)', () {
    test('image message model carries bytes and kind', () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final m = ChatMessage(
        id: 'u1',
        threadId: 'th_clinic',
        author: ChatAuthor.vetAssistant,
        text: '',
        at: DateTime(2026, 10, 13, 10, 0),
        sentByMe: true,
        kind: ChatKind.image,
        imageBytes: bytes,
      );
      expect(m.kind, ChatKind.image);
      expect(m.imageBytes, bytes);
      expect(m.text, isEmpty);
    });

    testWidgets('photo button shows in the clinic thread only', (tester) async {
      await pumpThread(tester, 'th_clinic', accountName: 'Mark');
      expect(find.bySemanticsLabel('Attach a photo'), findsOneWidget);

      await pumpThread(tester, 'th_ai', accountName: 'Mark');
      expect(find.bySemanticsLabel('Attach a photo'), findsNothing);
    });

    testWidgets('tapping the photo button offers library and camera', (
      tester,
    ) async {
      await pumpThread(tester, 'th_clinic', accountName: 'Mark');
      await tester.tap(find.bySemanticsLabel('Attach a photo'));
      await tester.pumpAndSettle();
      expect(find.text('Add a photo'), findsOneWidget);
      expect(find.text('Photo library'), findsOneWidget);
      expect(find.text('Camera'), findsOneWidget);
      // The desktop test harness has no picker: choosing a source must
      // fail soft (no preview, no crash, no message sent).
      final before = tester.widgetList(find.byType(Image)).length;
      await tester.tap(find.text('Photo library'));
      await tester.pumpAndSettle();
      expect(find.text('Add a photo'), findsNothing);
      expect(tester.widgetList(find.byType(Image)).length, before);
    });

    testWidgets('an image message renders as a photo bubble', (tester) async {
      final s = await pumpThread(tester, 'th_clinic', accountName: 'Mark');
      // A real 1x1 PNG: the codec must decode the bytes under test.
      final png = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
      );
      s.pushMessage(
        ChatMessage(
          id: 'u1',
          threadId: 'th_clinic',
          author: ChatAuthor.vetAssistant,
          text: '',
          kind: ChatKind.image,
          imageBytes: png,
          at: openNow(),
          sentByMe: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('You sent a photo'), findsOneWidget);
      expect(find.byType(Image), findsWidgets);
    });

    testWidgets('tapping a photo bubble opens the full-screen preview', (
      tester,
    ) async {
      final s = await pumpThread(tester, 'th_clinic', accountName: 'Mark');
      final png = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
      );
      s.pushMessage(
        ChatMessage(
          id: 'u1',
          threadId: 'th_clinic',
          author: ChatAuthor.vetAssistant,
          text: '',
          kind: ChatKind.image,
          imageBytes: png,
          at: openNow(),
          sentByMe: true,
        ),
      );
      await tester.pumpAndSettle();

      // Tap the bubble itself (what a finger hits): the 1x1 test PNG
      // shrink-wraps the Image to 0x0, so tap the PressScale ancestor —
      // its hit area is the bubble.
      final bubble = find.ancestor(
        of: find.byType(Image).first,
        matching: find.byType(PressScale),
      );
      await tester.tap(bubble);
      await tester.pumpAndSettle();
      // Full-screen viewer: pinch-zoom surface + 44pt close button.
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.bySemanticsLabel('Close photo viewer'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Close photo viewer'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Close photo viewer'), findsNothing);
    });
  });

  group('dynamic replies (B5)', () {
    testWidgets('grooming question gets a role-matched dynamic reply', (
      tester,
    ) async {
      await pumpThread(tester, 'th_clinic', accountName: 'Mark');
      await sendText(tester, 'How much is a full groom for Biscuit?');
      // Miguel routes grooming to Ana — the reply names the inquiry.
      expect(find.textContaining('Ana'), findsOneWidget);
      expect(find.textContaining('Biscuit'), findsWidgets);
    });

    testWidgets('symptom question gets a calm, specific reply', (tester) async {
      await pumpThread(tester, 'th_clinic', accountName: 'Mark');
      await sendText(tester, 'Biscuit has been scratching a lot');
      // The reply (not just the echoed question) names the symptom.
      expect(find.textContaining('worth a proper look'), findsOneWidget);
      expect(find.textContaining('redness'), findsOneWidget);
    });

    testWidgets('member role drives the reply voice', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(390, 844));
      final s = AppStore(now: openNow());
      s.accountName = 'Mark';
      s.accountEmail = 'mark@example.com';
      await tester.pumpWidget(
        AppScope(
          store: s,
          child: CupertinoApp(
            theme: themeFor(AppPalette.light),
            home: const ChatThreadScreen(
              threadId: 'th_clinic',
              replyRole: StaffRole.groomer,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await sendText(tester, 'How much is a full groom?');
      // Ana answers in her own voice, under her own name. The price matches
      // Seed.services sv4 (Full Grooming) — the booking flow's price.
      expect(find.textContaining('₱1450'), findsOneWidget);
      expect(find.textContaining('Ana · Groomer'), findsOneWidget);
    });
  });

  group('AI thread cleanup (B6)', () {
    testWidgets('unavailable AI shows an inline notice, not the API card', (
      tester,
    ) async {
      // No key in mock prefs → AiStatus.unavailable.
      await pumpThread(tester, 'th_ai', accountName: 'Mark');
      expect(find.textContaining('AI is unavailable'), findsOneWidget);
      expect(find.text('Open Settings'), findsOneWidget);
      expect(find.byType(AiUnavailableCard), findsNothing);
    });
  });

  group('health result button (B7)', () {
    testWidgets('hidden when no health-check result exists', (tester) async {
      await pumpThread(tester, 'th_clinic', accountName: 'Mark');
      expect(find.bySemanticsLabel('Open health check result'), findsNothing);
    });
  });
}
