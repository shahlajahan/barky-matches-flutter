import 'package:barky_matches_fixed/home/widgets/homepage_responsive_photo_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const viewportWidths = <double>[390, 600, 768, 1024, 1440, 1920];

  for (final width in viewportWidths) {
    testWidgets(
      'Homepage Web photo treatment preserves both image layers at ${width.toInt()}px',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 300));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            home: SizedBox(
              width: width,
              height: 135,
              child: buildHomepageResponsivePhotoImage(
                assetPath: 'assets/home/heroes/vet_hero.png',
                coverAlignment: Alignment.centerRight,
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        final images = tester.widgetList<Image>(find.byType(Image)).toList();
        expect(images, hasLength(2));
        expect(images.first.fit, BoxFit.cover);
        expect(images.last.fit, BoxFit.contain);
        expect(identical(images.first.image, images.last.image), isTrue);
      },
      skip: !kIsWeb,
    );
  }

  testWidgets(
    'native Homepage photo treatment retains the original cover path',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 390,
            height: 135,
            child: buildHomepageResponsivePhotoImage(
              assetPath: 'assets/home/heroes/vet_hero.png',
              coverAlignment: Alignment.centerRight,
            ),
          ),
        ),
      );

      final images = tester.widgetList<Image>(find.byType(Image)).toList();
      expect(images, hasLength(1));
      expect(images.single.fit, BoxFit.cover);
      expect(images.single.alignment, Alignment.centerRight);
    },
    skip: kIsWeb,
  );
}
