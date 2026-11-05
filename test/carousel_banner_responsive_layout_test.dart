import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:responsive_framework/responsive_framework.dart';

import 'package:Orvia/screens/screen/chart/carousal_widget.dart';
import 'package:Orvia/services/banner/smart_banner_service.dart';
import 'package:Orvia/services/festival/festival_service.dart';

Widget _buildResponsiveTestHarness({
  required Size screenSize,
  required Widget child,
}) {
  return MediaQuery(
    data: MediaQueryData(
      size: screenSize,
      devicePixelRatio: 1.0,
    ),
    child: ResponsiveBreakpoints.builder(
      breakpoints: const [
        Breakpoint(start: 0, end: 450, name: MOBILE),
        Breakpoint(start: 451, end: 800, name: TABLET),
        Breakpoint(start: 801, end: 1920, name: DESKTOP),
        Breakpoint(start: 1921, end: double.infinity, name: '4K'),
      ],
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Material(
          child: Center(
            child: SizedBox(
              width: screenSize.width,
              height: screenSize.height,
              child: child,
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testBanner = SmartBannerItem(
    id: 'creators_choice',
    title: "Creator's Choice",
    subtitle: 'Where Melodies Meet Memories',
    badge: 'EXCLUSIVE',
    destination: 'creators_choice',
    imageUrl: 'assets/images/creators_choice_banner.webp',
    gradientColors: const [Color(0xFF2E1C0C), Color(0xFF140D07)],
    tracks: const [],
    activeHours: const [],
    priority: 95,
  );

  final testFestival = FestivalEvent(
    id: 'diwali_2026',
    name: 'Diwali Festive Special',
    greeting: 'Happy Diwali',
    region: 'National',
    startDate: DateTime(2026, 11, 8),
    endDate: DateTime(2026, 11, 12),
    promotionDays: 15,
    bannerUrl: 'assets/images/diwali_banner.webp',
    bannerTitle: 'Diwali Festive Special',
    bannerSubtitle: 'Festival of Lights Celebration',
    categories: const ['devotional', 'festive'],
    tracks: const [],
  );

  group('Responsive Carousel Banner Sizing Tests', () {
    testWidgets('1. Compact phone (360x640): Card width fits viewport slot without overflow', (tester) async {
      const screenSize = Size(360, 640);
      const viewportFraction = 0.65;
      final slotWidth = screenSize.width * viewportFraction; // 234.0
      final expectedCardWidth = slotWidth - 8.0; // 226.0

      await tester.binding.setSurfaceSize(screenSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _buildResponsiveTestHarness(
          screenSize: screenSize,
          child: Center(
            child: SmartBannerSlide(
              banner: testBanner,
              cardWidth: expectedCardWidth,
              cardHeight: 224.0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final clipFinder = find.descendant(
        of: find.byType(SmartBannerSlide),
        matching: find.byType(ClipRRect),
      );
      expect(clipFinder, findsOneWidget);
      final renderBox = tester.renderObject<RenderBox>(clipFinder);
      final size = renderBox.size;

      expect(size.width, closeTo(expectedCardWidth, 1.0));
      expect(size.width, lessThanOrEqualTo(slotWidth),
          reason: 'Card width must strictly fit inside the 234dp carousel slot');
      expect(size.height, closeTo(224.0, 1.0));

      // Verify zero Flutter overflow errors occurred
      expect(tester.takeException(), isNull);
    });

    testWidgets('2. Tall phone (392x920 like realme 16 Pro): Card width is bound to viewport slot, preventing overflow', (tester) async {
      const screenSize = Size(392, 920);
      const viewportFraction = 0.65;
      final slotWidth = screenSize.width * viewportFraction; // 254.8
      final expectedCardWidth = slotWidth - 8.0; // 246.8

      await tester.binding.setSurfaceSize(screenSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // With previous height-dependent sizing: height * 0.3 = 920 * 0.3 = 276.0dp (> 254.8dp slot!).
      // With our fix: cardWidth is based on slot width (246.8dp <= 254.8dp).
      await tester.pumpWidget(
        _buildResponsiveTestHarness(
          screenSize: screenSize,
          child: Center(
            child: SmartBannerSlide(
              banner: testBanner,
              cardWidth: expectedCardWidth,
              cardHeight: 310.0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final clipFinder = find.descendant(
        of: find.byType(SmartBannerSlide),
        matching: find.byType(ClipRRect),
      );
      expect(clipFinder, findsOneWidget);
      final renderBox = tester.renderObject<RenderBox>(clipFinder);
      final size = renderBox.size;

      expect(size.width, closeTo(expectedCardWidth, 1.0));
      expect(size.width, lessThanOrEqualTo(slotWidth),
          reason: 'Card width (246.8) must fit within 254.8dp slot width, preventing the 21.2dp overflow bug');
      expect(size.width, lessThan(276.0),
          reason: 'Card width must not equal the old erroneous height-dependent 276dp value');

      expect(tester.takeException(), isNull);
    });

    testWidgets('3. Split-screen / Multi-window (392x400): Card width fills slot properly, avoiding tiny sliver card', (tester) async {
      const screenSize = Size(392, 400);
      const viewportFraction = 0.65;
      final slotWidth = screenSize.width * viewportFraction; // 254.8
      final expectedCardWidth = slotWidth - 8.0; // 246.8

      await tester.binding.setSurfaceSize(screenSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // In split screen: old height * 0.3 produced 120.0dp (tiny shrunken card with 134.8dp empty space!).
      // With our fix: cardWidth remains width-driven at 246.8dp, while height is clamped safely.
      await tester.pumpWidget(
        _buildResponsiveTestHarness(
          screenSize: screenSize,
          child: Center(
            child: SmartBannerSlide(
              banner: testBanner,
              cardWidth: expectedCardWidth,
              cardHeight: 170.0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final clipFinder = find.descendant(
        of: find.byType(SmartBannerSlide),
        matching: find.byType(ClipRRect),
      );
      expect(clipFinder, findsOneWidget);
      final renderBox = tester.renderObject<RenderBox>(clipFinder);
      final size = renderBox.size;

      expect(size.width, closeTo(expectedCardWidth, 1.0));
      expect(size.width, greaterThan(130.0),
          reason: 'Card width must not collapse to the 120dp shrunken state in split-screen');
      expect(size.height, greaterThanOrEqualTo(160.0),
          reason: 'Card height is safely clamped in split-screen');

      expect(tester.takeException(), isNull);
    });

    testWidgets('4. FestiveSpecialSlide responsive sizing adheres to viewport constraints across all dimensions', (tester) async {
      const screenSize = Size(392, 920);
      const viewportFraction = 0.65;
      final slotWidth = screenSize.width * viewportFraction; // 254.8
      final expectedCardWidth = slotWidth - 8.0; // 246.8

      await tester.binding.setSurfaceSize(screenSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _buildResponsiveTestHarness(
          screenSize: screenSize,
          child: Center(
            child: FestiveSpecialSlide(
              festival: testFestival,
              onTap: () {},
              cardWidth: expectedCardWidth,
              cardHeight: 310.0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final clipFinder = find.descendant(
        of: find.byType(FestiveSpecialSlide),
        matching: find.byType(ClipRRect),
      );
      expect(clipFinder, findsOneWidget);
      final renderBox = tester.renderObject<RenderBox>(clipFinder);
      final size = renderBox.size;

      expect(size.width, closeTo(expectedCardWidth, 1.0));
      expect(size.width, lessThanOrEqualTo(slotWidth));
      expect(tester.takeException(), isNull);
    });

    testWidgets('5. LayoutBuilder fallback inside slide calculates width from parent constraints if cardWidth is omitted', (tester) async {
      const parentWidth = 250.0;
      const parentHeight = 280.0;

      await tester.pumpWidget(
        _buildResponsiveTestHarness(
          screenSize: const Size(400, 800),
          child: Center(
            child: SizedBox(
              width: parentWidth,
              height: parentHeight,
              child: Center(
                child: SmartBannerSlide(
                  banner: testBanner,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final clipFinder = find.descendant(
        of: find.byType(SmartBannerSlide),
        matching: find.byType(ClipRRect),
      );
      expect(clipFinder, findsOneWidget);
      final renderBox = tester.renderObject<RenderBox>(clipFinder);
      final size = renderBox.size;

      // When placed in a 250dp slot without explicit cardWidth, it should use constraints.maxWidth - 8 = 242dp
      expect(size.width, closeTo(242.0, 1.0));
      expect(size.width, lessThanOrEqualTo(parentWidth));
      expect(tester.takeException(), isNull);
    });

    test('6. Curated Smart Banners and Festive Banner identity & rules are preserved', () {
      final banners = SmartBannerService.getActiveBanners();
      expect(banners.isNotEmpty, isTrue);

      final creatorsChoice = banners.firstWhere((b) => b.id == 'creators_choice');
      expect(creatorsChoice.title, equals("Creator's Choice"));
      expect(creatorsChoice.destination, equals('creators_choice'));
      expect(creatorsChoice.priority, equals(95));

      // Verify India Songs banner is absent
      expect(banners.any((b) => b.id == 'india_songs_spotlight'), isFalse);
    });
  });
}
