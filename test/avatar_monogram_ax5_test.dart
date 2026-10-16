import 'package:carepaws/design/theme.dart';
import 'package:carepaws/widgets/common.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Avatar monograms are graphics, not content text (the semantics label
/// carries the meaning) — like icons, they must not scale with Dynamic
/// Type. At AX5 (3.2x) a 22pt "MD" would be ~70pt and burst the 62pt
/// circle; the ClipOval would then cut the glyphs.
Widget _ax5(Widget child) => CupertinoApp(
      theme: themeFor(AppPalette.light),
      home: Center(child: child),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(3.2)),
        child: child!,
      ),
    );

void main() {
  group('avatar monograms do not scale with Dynamic Type', () {
    testWidgets('OwnerAvatar initials fit the circle at AX5', (tester) async {
      await tester.pumpWidget(_ax5(
        const OwnerAvatar(initials: 'MD', size: 62),
      ));
      await tester.pumpAndSettle();
      final para = tester.renderObject<RenderParagraph>(find.text('MD'));
      expect(
        para.getMaxIntrinsicWidth(double.infinity),
        lessThanOrEqualTo(62),
        reason: 'monogram must fit the 62pt circle at 3.2x',
      );
    });

    testWidgets('StaffAvatar initials fit the circle at AX5', (tester) async {
      await tester.pumpWidget(_ax5(
        const StaffAvatar(initials: 'RA', size: 42),
      ));
      await tester.pumpAndSettle();
      final para = tester.renderObject<RenderParagraph>(find.text('RA'));
      expect(
        para.getMaxIntrinsicWidth(double.infinity),
        lessThanOrEqualTo(42),
        reason: 'monogram must fit the 42pt circle at 3.2x',
      );
    });
  });
}
