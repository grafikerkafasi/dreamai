import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dream_ai/l10n/generated/app_localizations.dart';
import 'package:dream_ai/main.dart' show resolveAppLocale;

Widget _harness(Locale locale, Widget Function(AppLocalizations) builder) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    localeResolutionCallback: resolveAppLocale,
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

    expect(find.text('Aşağıya dokun ve rüyanı anlat'), findsOneWidget);
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

    expect(find.text('Tap below and tell me your dream'), findsOneWidget);
    expect(find.text('analyze'), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);
  });

  testWidgets('resolves Arabic strings with correct plural forms',
      (tester) async {
    await tester.pumpWidget(_harness(
      const Locale('ar'),
      (l10n) => Column(children: [
        Text(l10n.dreamHint),
        Text(l10n.dreamsLeftThisMonth(0)),
        Text(l10n.dreamsLeftThisMonth(1)),
        Text(l10n.dreamsLeftThisMonth(2)),
        Text(l10n.dreamsLeftThisMonth(5)),
      ]),
    ));

    expect(find.text('اضغط أدناه وأخبرني بحلمك'), findsOneWidget);
    expect(find.text('لم يتبقَّ أي حلم هذا الشهر'), findsOneWidget);
    expect(find.text('تبقّى حلم واحد هذا الشهر'), findsOneWidget);
    expect(find.text('تبقّى حلمان هذا الشهر'), findsOneWidget);
    expect(find.text('تبقّت 5 أحلام هذا الشهر'), findsOneWidget);
  });

  testWidgets('resolves Russian strings with correct plural forms',
      (tester) async {
    await tester.pumpWidget(_harness(
      const Locale('ru'),
      (l10n) => Column(children: [
        Text(l10n.freeDreamsLeft(1)),
        Text(l10n.freeDreamsLeft(3)),
        Text(l10n.freeDreamsLeft(5)),
      ]),
    ));

    expect(find.text('Остался 1 бесплатный сон'), findsOneWidget);
    expect(find.text('Осталось 3 бесплатных сна'), findsOneWidget);
    expect(find.text('Осталось 5 бесплатных снов'), findsOneWidget);
  });

  test(
      'resolveAppLocale falls back to English, not the alphabetically-first '
      'supported locale, for an unmatched device locale', () {
    // AppLocalizations.supportedLocales is sorted alphabetically by
    // flutter gen-l10n, so its first entry is 'ar' — Flutter's *default*
    // fallback (supportedLocales.first) would silently pick Arabic for any
    // unmatched device locale. resolveAppLocale exists specifically to
    // override that with an explicit English fallback.
    expect(AppLocalizations.supportedLocales.first, const Locale('ar'));

    final resolved =
        resolveAppLocale(const Locale('ja'), AppLocalizations.supportedLocales);

    expect(resolved, const Locale('en'));
  });

  test('resolveAppLocale matches a supported language when available', () {
    final resolved =
        resolveAppLocale(const Locale('de'), AppLocalizations.supportedLocales);

    expect(resolved, const Locale('de'));
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
