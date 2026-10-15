import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carepaws/design/theme.dart';
import 'package:carepaws/widgets/back_guard.dart';

Future<void> pumpDialogHost(WidgetTester tester, Widget child) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  await tester.pumpWidget(
    CupertinoApp(
      theme: themeFor(AppPalette.light),
      home: CupertinoPageScaffold(child: Center(child: child)),
    ),
  );
  await tester.pumpAndSettle();
}

/// Host widget that calls [showExitConfirmDialog] on tap and records the
/// returned value.
class DialogProbe extends StatefulWidget {
  const DialogProbe({super.key, required this.onResult});
  final ValueChanged<bool> onResult;

  @override
  State<DialogProbe> createState() => _DialogProbeState();
}

class _DialogProbeState extends State<DialogProbe> {
  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      child: const Text('ask'),
      onPressed: () async {
        final result = await showExitConfirmDialog(context);
        widget.onResult(result);
      },
    );
  }
}

void main() {
  testWidgets('dialog shows Stay (default) and Exit (destructive)', (
    tester,
  ) async {
    await pumpDialogHost(tester, DialogProbe(onResult: (_) {}));
    await tester.tap(find.text('ask'));
    await tester.pumpAndSettle();

    expect(find.text('Exit CarePaws?'), findsOneWidget);
    expect(
      find.text('Your data is saved on this device. Come back anytime.'),
      findsOneWidget,
    );
    expect(find.text('Stay'), findsOneWidget);
    expect(find.text('Exit'), findsOneWidget);

    final stay = tester.widget<CupertinoDialogAction>(
      find.widgetWithText(CupertinoDialogAction, 'Stay'),
    );
    expect(stay.isDefaultAction, isTrue);
    final exit = tester.widget<CupertinoDialogAction>(
      find.widgetWithText(CupertinoDialogAction, 'Exit'),
    );
    expect(exit.isDestructiveAction, isTrue);
  });

  testWidgets('Stay returns false', (tester) async {
    var result = true;
    await pumpDialogHost(tester, DialogProbe(onResult: (v) => result = v));
    await tester.tap(find.text('ask'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
    expect(find.text('Exit CarePaws?'), findsNothing);
  });

  testWidgets('Exit returns true', (tester) async {
    var result = false;
    await pumpDialogHost(tester, DialogProbe(onResult: (v) => result = v));
    await tester.tap(find.text('ask'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exit'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('barrier tap dismisses as Stay', (tester) async {
    var result = true;
    await pumpDialogHost(tester, DialogProbe(onResult: (v) => result = v));
    await tester.tap(find.text('ask'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });

  testWidgets('RootBackGuard asks on system back instead of exiting', (
    tester,
  ) async {
    var exited = false;
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      CupertinoApp(
        theme: themeFor(AppPalette.light),
        home: RootBackGuard(
          onExit: () => exited = true,
          child: const CupertinoPageScaffold(
            child: Center(child: Text('app root')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    // The app did not exit — the dialog is showing instead.
    expect(exited, isFalse);
    expect(find.text('Exit CarePaws?'), findsOneWidget);

    await tester.tap(find.text('Exit'));
    await tester.pumpAndSettle();
    expect(exited, isTrue);
  });

  testWidgets('RootBackGuard Stay keeps the app open', (tester) async {
    var exited = false;
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      CupertinoApp(
        theme: themeFor(AppPalette.light),
        home: RootBackGuard(
          onExit: () => exited = true,
          child: const CupertinoPageScaffold(
            child: Center(child: Text('app root')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();
    expect(exited, isFalse);
    expect(find.text('app root'), findsOneWidget);
  });
}
