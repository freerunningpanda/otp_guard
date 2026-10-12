import 'package:flutter/material.dart';
import 'package:otp_guard/l10n/s.dart';

/// The texts of the app in Russian, the language the screens are tested in. A
/// test looks for what the app shows, taken from the same place, so a reworded
/// text does not break it.
final S ru = lookupS(const Locale('ru'));

/// The texts of the app in English.
final S en = lookupS(const Locale('en'));

/// A [MaterialApp] with the localizations of the app, in Russian unless told
/// otherwise. What the pages under test need to find their texts.
MaterialApp localizedApp({
  required Widget home,
  Locale locale = const Locale('ru'),
}) {
  return MaterialApp(
    localizationsDelegates: S.localizationsDelegates,
    supportedLocales: S.supportedLocales,
    locale: locale,
    home: home,
  );
}
