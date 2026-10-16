import 'package:carepaws/design/theme.dart';
import 'package:carepaws/screens/home_screen.dart';
import 'package:carepaws/state/app_store.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The greeting row must grow with Dynamic Type instead of clipping the
/// greeting at AX5 (3.2x): a fixed 48pt row cannot fit a ~84pt title2 line.
/// The RenderParagraph clamps to its incoming maxHeight, so the honest check
/// is the paragraph's *intrinsic* (unclamped) height against the row height.
void main() {
  testWidgets('greeting row fits its text at AX5 without clipping', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore(now: DateTime(2026, 10, 13, 10, 0));
    addTearDown(store.dispose);
    await tester.pumpWidget(
      AppScope(
        store: store,
        child: CupertinoApp(
          theme: themeFor(AppPalette.light),
          home: const HomeScreen(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(3.2)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final text = find.textContaining('Good morning');
    expect(text, findsOneWidget);
    final para = tester.renderObject<RenderParagraph>(text);
    // Intrinsic height of the scaled line, ignoring the row's clamp.
    final intrinsic = para.getMaxIntrinsicHeight(double.infinity);
    expect(
      intrinsic,
      greaterThan(48),
      reason: 'sanity: at 3.2x the line must exceed the 48pt row',
    );

    final row = find.ancestor(
      of: text,
      matching: find.byWidgetPredicate(
        (w) => w is SizedBox || w is ConstrainedBox,
      ),
    );
    final rowBox = tester.getRect(row.first);
    expect(
      rowBox.height,
      greaterThanOrEqualTo(intrinsic),
      reason: 'greeting needs ${intrinsic}pt but its row is ${rowBox.height}pt',
    );
  });
}
