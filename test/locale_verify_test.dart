import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dream_ai/l10n/generated/app_localizations.dart';

Widget _harness(Locale locale, Widget Function(AppLocalizations) builder) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => builder(AppLocalizations.of(context)!),
    ),
  );
}

void main() {
  testWidgets('resolves Turkish strings when locale is tr', (tester) async {
    await tester.pumpWidget(_harness(
      const Locale('tr'),
      (l10n) => Column(children: [
        Text(l10n.dreamHint),
        Text(l10n.analyzeButton),
        Text(l10n.chooseInterpreter),
        Text(l10n.privacyPolicyTitle),
        Text(l10n.dreamsLeftThisMonth(3)),
      ]),
    ));

    expect(find.text('Rüyanı anlat...'), findsOneWidget);
    expect(find.text('yorumla'), findsOneWidget);
    expect(find.text('Bir Yorumcu Seç'), findsOneWidget);
    expect(find.text('Gizlilik Politikası'), findsOneWidget);
    expect(find.text('Bu ay 3 rüya hakkın kaldı'), findsOneWidget);
  });

  testWidgets('falls back to English for an unsupported device locale',
      (tester) async {
    await tester.pumpWidget(_harness(
      const Locale('fr'),
      (l10n) => Column(children: [
        Text(l10n.dreamHint),
        Text(l10n.analyzeButton),
        Text(l10n.privacyPolicyTitle),
      ]),
    ));

    expect(find.text('Tell me your dream...'), findsOneWidget);
    expect(find.text('analyze'), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);
  });

  testWidgets('English plurals use singular/plural forms correctly',
      (tester) async {
    await tester.pumpWidget(_harness(
      const Locale('en'),
      (l10n) => Column(children: [
        Text(l10n.freeDreamsLeft(1)),
        Text(l10n.freeDreamsLeft(5)),
      ]),
    ));

    expect(find.text('1 free dream left'), findsOneWidget);
    expect(find.text('5 free dreams left'), findsOneWidget);
  });
}
