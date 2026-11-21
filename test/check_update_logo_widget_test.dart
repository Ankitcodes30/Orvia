import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Orvia/l10n/app_localizations.dart';
import 'package:Orvia/screens/screen/home_views/setting_views/check_update_view.dart';
import 'package:Orvia/services/updater/orvia_update_service.dart';

void main() {
  testWidgets('CheckUpdateView renders official Orvia master logo with rounded-square container', (tester) async {
    const upToDateResult = UpdateCheckResult(
      status: UpdateStatus.upToDate,
      currentVersion: '3.0.7',
      currentBuild: '4',
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CheckUpdateView(
          initialFuture: Future.value(upToDateResult),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Orvia master logo asset is present
    final imageFinder = find.byWidgetPredicate(
      (w) => w is Image && w.image is AssetImage && (w.image as AssetImage).assetName == 'assets/icons/OrviaLogo_Master.png',
    );
    expect(imageFinder, findsOneWidget);

    final Image imageWidget = tester.widget<Image>(imageFinder);
    expect(imageWidget.width, equals(72));
    expect(imageWidget.height, equals(72));
    expect(imageWidget.fit, equals(BoxFit.cover));

    // Verify it is inside a ClipRRect with rounded corners (not circular)
    final clipFinder = find.ancestor(of: imageFinder, matching: find.byType(ClipRRect));
    expect(clipFinder, findsOneWidget);
    final ClipRRect clipRRect = tester.widget<ClipRRect>(clipFinder);
    expect(clipRRect.borderRadius, equals(BorderRadius.circular(18.5)));

    // Verify outer container uses rounded rectangle (not BoxShape.circle)
    final containerFinder = find.ancestor(of: clipFinder, matching: find.byType(Container)).first;
    final Container container = tester.widget<Container>(containerFinder);
    final boxDecoration = container.decoration as BoxDecoration?;
    expect(boxDecoration, isNotNull);
    expect(boxDecoration!.shape, equals(BoxShape.rectangle));
    expect(boxDecoration.borderRadius, equals(BorderRadius.circular(20)));

    // Verify status text and actions
    expect(find.text('Check Again'), findsOneWidget);
  });
}
