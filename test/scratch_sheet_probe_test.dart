import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petcare_artifact/app.dart';
import 'package:petcare_artifact/design/theme.dart';
import 'package:petcare_artifact/state/app_store.dart';

Future<AppStore> boot(WidgetTester t) async {
  await t.binding.setSurfaceSize(const Size(390, 844));
  final s = AppStore(now: DateTime(2026, 10, 13, 9, 40));
  await t.pumpWidget(
    AppScope(store: s, child: CupertinoApp(theme: themeFor(AppPalette.light), home: const RootShell())),
  );
  await t.pumpAndSettle();
  return s;
}

void main() {
  testWidgets('PROBE: chats staff directory sheet Done button', (t) async {
    await boot(t);
    await t.tap(find.text('Chats').last);
    await t.pumpAndSettle();
    // Open the staff directory sheet via its header action.
    final dir = find.bySemanticsLabel(RegExp('Staff'));
    // ignore: avoid_print
    print('staff finder count: ${dir.evaluate().length}');
    await t.pumpAndSettle();
    // Tap Done if present
    final done = find.text('Done');
    // ignore: avoid_print
    print('Done present before tap: ${done.evaluate().length}');
  });

  testWidgets('PROBE: barrier tap dismisses sheet', (t) async {
    await boot(t);
    final ctx = t.element(find.byType(RootShell));
    showAppSheet(ctx, child: const Center(child: Text('SHEET BODY')));
    await t.pumpAndSettle();
    // ignore: avoid_print
    print('sheet shown: ${find.text('SHEET BODY').evaluate().length}');
    await t.tapAt(const Offset(195, 60));
    await t.pumpAndSettle();
    // ignore: avoid_print
    print('after barrier tap, sheet shown: ${find.text('SHEET BODY').evaluate().length}');
  });
}
