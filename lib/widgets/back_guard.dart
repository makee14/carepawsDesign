import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import 'common.dart';

/// Shared exit-confirm dialog + back-guard recipe (Stream A owns it; every
/// stream reuses it — never a second system per screen).
///
/// Mark's standing rule: the system back button at the app root asks
/// "do you want to exit?" instead of closing the app silently. Generalized:
/// any back navigation that would discard unsaved state or abandon a flow
/// confirms first, extending the existing [confirmDiscardIfDirty] + PopScope
/// recipe (see `lib/widgets/common.dart`).
///
/// PopScope recipe for a flow root (booking, add-pet, health check, triage):
///
/// ```dart
/// RootBackGuard( // app shell only — see below
/// ```
///
/// ```dart
/// PopScope(
///   canPop: false, // or `!_isDirty` for dirty-form screens, which keep
///                   // using confirmDiscardIfDirty directly
///   onPopInvokedWithResult: (didPop, _) async {
///     if (didPop) return;
///     // Step-aware flows handle their own step-back here first.
///     if (await showExitConfirmDialog(context)) {
///       if (context.mounted) Navigator.of(context).pop();
///     }
///   },
///   child: ...,
/// )
/// ```
///
/// The nav-bar back button keeps its default `maybePop` — which honours
/// PopScope — unless the flow overrides `onBack` for step-back behaviour, in
/// which case the override runs the same confirm itself.

/// "Exit CarePaws?" confirmation. Returns true only when the user chose Exit;
/// barrier tap and Stay both return false.
///
/// Copy is deliberately short and non-anxiety-inducing. The safe choice
/// (Stay) is the default action — bold and first, per the HIG
/// destructive-action pattern; Exit is the destructive action.
Future<bool> showExitConfirmDialog(BuildContext context) async {
  final exit = await showPopup<bool>(
    context,
    centered: true,
    barrierDismissible: true,
    builder: (ctx) => CupertinoAlertDialog(
      title: const Text('Exit CarePaws?'),
      content: const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Text('Your data is saved on this device. Come back anytime.'),
      ),
      actions: [
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Stay'),
        ),
        CupertinoDialogAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Exit'),
        ),
      ],
    ),
  );
  return exit ?? false;
}

/// Wraps the app shell: the system back button at the tab roots (nothing
/// left to pop) shows [showExitConfirmDialog] instead of closing the app.
///
/// System-back double-handling quirk (verified; shared with the vet shell):
/// on system back, the tab's own Navigator pops the pushed screen AND this
/// guard's [PopScope] callback fires — so the exit dialog can appear
/// alongside the pop. This guard does NOT only fire "when there is nothing
/// left to pop anywhere". The fix belongs in the shared shell recipe later;
/// do not diverge one shell to work around it here.
///
/// [onExit] is injectable so widget tests can assert the wiring without
/// touching the platform channel; production passes [SystemNavigator.pop].
class RootBackGuard extends StatelessWidget {
  const RootBackGuard({
    super.key,
    required this.child,
    this.onExit = SystemNavigator.pop,
  });

  final Widget child;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await showExitConfirmDialog(context)) onExit();
      },
      child: child,
    );
  }
}
