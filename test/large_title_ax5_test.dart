import 'package:carepaws/app.dart';
import 'package:carepaws/design/theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// The LargeTitleBar must grow with Dynamic Type: at AX5 (3.2x) the 34pt
/// large title renders ~130pt tall, and the fixed 64pt header clips it.
/// The header's maxExtent must fit the title's intrinsic (scaled) height.
void main() {
  testWidgets('large title fits inside the header at AX5', (tester) async {
    await tester.pumpWidget(
      CupertinoApp(
        theme: themeFor(AppPalette.light),
        home: CupertinoPageScaffold(
          child: CustomScrollView(
            slivers: [
              const LargeTitleBar(title: 'Appointments'),
              SliverToBoxAdapter(
                child: Container(height: 1200, color: const Color(0xFFFFFFFF)),
              ),
            ],
          ),
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(3.2)),
          child: child!,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final title = find.text('Appointments');
    expect(title, findsOneWidget);
    final para = tester.renderObject<RenderParagraph>(title);
    final intrinsic = para.getMaxIntrinsicHeight(double.infinity);
    expect(
      intrinsic,
      greaterThan(64),
      reason: 'sanity: at 3.2x the title must exceed the 64pt header',
    );

    // The sliver header at offset 0 renders at maxExtent. The delegate's
    // root is a Container (a RenderBox); the sliver itself is a RenderSliver.
    final headerBox = find.ancestor(
      of: title,
      matching: find.byWidgetPredicate(
        (w) => w is Container && w.color != null,
      ),
    );
    final headerRect = tester.getRect(headerBox.first);
    expect(
      headerRect.height,
      greaterThanOrEqualTo(intrinsic),
      reason:
          'title needs ${intrinsic}pt but the header is ${headerRect.height}pt',
    );
  });
}
