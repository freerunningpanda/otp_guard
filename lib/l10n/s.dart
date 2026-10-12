import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 's_en.dart';
import 's_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of S
/// returned by `S.of(context)`.
///
/// Applications need to include `S.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/s.dart';
///
/// return MaterialApp(
///   localizationsDelegates: S.localizationsDelegates,
///   supportedLocales: S.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the S.supportedLocales
/// property.
abstract class S {
  S(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static S of(BuildContext context) {
    return Localizations.of<S>(context, S)!;
  }

  static const LocalizationsDelegate<S> delegate = _SDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
  ];

  /// The title of the app, in the task switcher.
  ///
  /// In ru, this message translates to:
  /// **'Аутентификатор'**
  String get appTitle;

  /// No description provided for @emptyTitle.
  ///
  /// In ru, this message translates to:
  /// **'Аккаунтов пока нет'**
  String get emptyTitle;

  /// No description provided for @emptyHint.
  ///
  /// In ru, this message translates to:
  /// **'Добавьте первый аккаунт: отсканируйте QR-код сайта или введите секрет вручную.'**
  String get emptyHint;

  /// No description provided for @addAccount.
  ///
  /// In ru, this message translates to:
  /// **'Добавить аккаунт'**
  String get addAccount;

  /// No description provided for @loadFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить аккаунты'**
  String get loadFailed;

  /// No description provided for @retry.
  ///
  /// In ru, this message translates to:
  /// **'Повторить'**
  String get retry;

  /// The tooltip of the button that opens the debug page. Debug builds only.
  ///
  /// In ru, this message translates to:
  /// **'Проверка ключа устройства'**
  String get deviceKeyDemo;

  /// A warning that some stored accounts could not be read.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{Не удалось прочитать {count} запись. Она не показана, но осталась в хранилище.} few{Не удалось прочитать {count} записи. Они не показаны, но остались в хранилище.} many{Не удалось прочитать {count} записей. Они не показаны, но остались в хранилище.} other{Не удалось прочитать {count} записи. Они не показаны, но остались в хранилище.}}'**
  String unreadableWarning(int count);

  /// No description provided for @deleteUnreadable.
  ///
  /// In ru, this message translates to:
  /// **'Удалить'**
  String get deleteUnreadable;

  /// No description provided for @deleteUnreadableTitle.
  ///
  /// In ru, this message translates to:
  /// **'Удалить нечитаемые записи?'**
  String get deleteUnreadableTitle;

  /// No description provided for @deleteUnreadableBody.
  ///
  /// In ru, this message translates to:
  /// **'Записи будут удалены без возможности восстановления.'**
  String get deleteUnreadableBody;

  /// No description provided for @deleteTitle.
  ///
  /// In ru, this message translates to:
  /// **'Удалить аккаунт?'**
  String get deleteTitle;

  /// Asks to confirm that an account is deleted.
  ///
  /// In ru, this message translates to:
  /// **'Коды для «{name}» перестанут показываться. Если вход по ним на сайте включён, вы можете потерять доступ: сначала отключите двухфакторную защиту на сайте.'**
  String deleteBody(String name);

  /// No description provided for @cancel.
  ///
  /// In ru, this message translates to:
  /// **'Отмена'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In ru, this message translates to:
  /// **'Удалить'**
  String get delete;

  /// No description provided for @deleteFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось удалить. Попробуйте ещё раз.'**
  String get deleteFailed;

  /// No description provided for @recordingBanner.
  ///
  /// In ru, this message translates to:
  /// **'Идёт запись экрана. Коды скрыты, пока она не закончится.'**
  String get recordingBanner;

  /// No description provided for @screenshotTaken.
  ///
  /// In ru, this message translates to:
  /// **'Сделан снимок экрана. Коды на нём могли попасть в кадр.'**
  String get screenshotTaken;

  /// A warning that the native screen protection could not be turned on, so the codes can leak through a screenshot or a recording.
  ///
  /// In ru, this message translates to:
  /// **'Защита экрана не включилась. Снимки, запись экрана и превью в списке приложений не защищены: коды могут попасть в кадр.'**
  String get protectionFailedBanner;

  /// No description provided for @scanQr.
  ///
  /// In ru, this message translates to:
  /// **'Сканировать QR-код'**
  String get scanQr;

  /// No description provided for @enterManually.
  ///
  /// In ru, this message translates to:
  /// **'Ввести вручную'**
  String get enterManually;

  /// No description provided for @accountAdded.
  ///
  /// In ru, this message translates to:
  /// **'Аккаунт добавлен'**
  String get accountAdded;

  /// No description provided for @accountDuplicate.
  ///
  /// In ru, this message translates to:
  /// **'Этот аккаунт уже добавлен'**
  String get accountDuplicate;

  /// No description provided for @saveFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить аккаунт. Попробуйте ещё раз.'**
  String get saveFailed;

  /// No description provided for @scanTitle.
  ///
  /// In ru, this message translates to:
  /// **'Сканирование QR-кода'**
  String get scanTitle;

  /// No description provided for @scanHint.
  ///
  /// In ru, this message translates to:
  /// **'Наведите камеру на QR-код сайта'**
  String get scanHint;

  /// No description provided for @cameraDeniedTitle.
  ///
  /// In ru, this message translates to:
  /// **'Нет доступа к камере'**
  String get cameraDeniedTitle;

  /// No description provided for @cameraDeniedBody.
  ///
  /// In ru, this message translates to:
  /// **'Разрешите доступ к камере в настройках телефона или введите секрет вручную.'**
  String get cameraDeniedBody;

  /// No description provided for @cameraFailedTitle.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось запустить камеру'**
  String get cameraFailedTitle;

  /// No description provided for @cameraFailedBody.
  ///
  /// In ru, this message translates to:
  /// **'Попробуйте ещё раз или введите секрет вручную.'**
  String get cameraFailedBody;

  /// No description provided for @scanAgain.
  ///
  /// In ru, this message translates to:
  /// **'Сканировать снова'**
  String get scanAgain;

  /// No description provided for @cannotAddTitle.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось добавить аккаунт'**
  String get cannotAddTitle;

  /// No description provided for @manualTitle.
  ///
  /// In ru, this message translates to:
  /// **'Новый аккаунт'**
  String get manualTitle;

  /// No description provided for @issuerLabel.
  ///
  /// In ru, this message translates to:
  /// **'Сервис (необязательно)'**
  String get issuerLabel;

  /// No description provided for @nameLabel.
  ///
  /// In ru, this message translates to:
  /// **'Аккаунт'**
  String get nameLabel;

  /// No description provided for @secretLabel.
  ///
  /// In ru, this message translates to:
  /// **'Секрет (Base32)'**
  String get secretLabel;

  /// No description provided for @save.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить'**
  String get save;

  /// No description provided for @nameRequired.
  ///
  /// In ru, this message translates to:
  /// **'Введите название аккаунта'**
  String get nameRequired;

  /// No description provided for @secretRequired.
  ///
  /// In ru, this message translates to:
  /// **'Введите секрет'**
  String get secretRequired;

  /// No description provided for @secretInvalid.
  ///
  /// In ru, this message translates to:
  /// **'Секрет должен быть в формате Base32: буквы A–Z и цифры 2–7'**
  String get secretInvalid;

  /// No description provided for @failureNotAnOtpAuthUri.
  ///
  /// In ru, this message translates to:
  /// **'Это не QR-код аутентификатора. Нужен код со ссылкой otpauth://.'**
  String get failureNotAnOtpAuthUri;

  /// No description provided for @failureHotp.
  ///
  /// In ru, this message translates to:
  /// **'Счётчиковые коды (HOTP) не поддерживаются. Приложение работает с кодами по времени (TOTP).'**
  String get failureHotp;

  /// No description provided for @failureUnsupportedType.
  ///
  /// In ru, this message translates to:
  /// **'Тип кодов «{type}» не поддерживается. Приложение работает с кодами по времени (TOTP).'**
  String failureUnsupportedType(String type);

  /// No description provided for @failureMissingLabel.
  ///
  /// In ru, this message translates to:
  /// **'В QR-коде нет названия аккаунта.'**
  String get failureMissingLabel;

  /// No description provided for @failureMissingSecret.
  ///
  /// In ru, this message translates to:
  /// **'В QR-коде нет секрета.'**
  String get failureMissingSecret;

  /// No description provided for @failureInvalidSecret.
  ///
  /// In ru, this message translates to:
  /// **'Секрет в QR-коде повреждён: он не в формате Base32.'**
  String get failureInvalidSecret;

  /// No description provided for @failureInvalidAlgorithm.
  ///
  /// In ru, this message translates to:
  /// **'Алгоритм «{value}» не поддерживается. Допустимы SHA1, SHA256 и SHA512.'**
  String failureInvalidAlgorithm(String value);

  /// No description provided for @failureInvalidDigits.
  ///
  /// In ru, this message translates to:
  /// **'Недопустимое число цифр: «{value}». Допустимы 6, 7 и 8.'**
  String failureInvalidDigits(String value);

  /// No description provided for @failureInvalidPeriod.
  ///
  /// In ru, this message translates to:
  /// **'Недопустимый период: «{value}». Нужно целое число секунд больше нуля.'**
  String failureInvalidPeriod(String value);

  /// A parameter of the otpauth link that is not one of the known ones, or has a wrong value.
  ///
  /// In ru, this message translates to:
  /// **'Недопустимое значение «{value}» параметра {name}.'**
  String failureInvalidParameter(String name, String value);

  /// The headline of the lock screen.
  ///
  /// In ru, this message translates to:
  /// **'Приложение заблокировано'**
  String get lockTitle;

  /// No description provided for @lockLoadFailedTitle.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось прочитать настройки блокировки'**
  String get lockLoadFailedTitle;

  /// No description provided for @lockLoadFailedBody.
  ///
  /// In ru, this message translates to:
  /// **'Приложение остаётся закрытым, пока их нельзя прочитать.'**
  String get lockLoadFailedBody;

  /// No description provided for @lockDamagedTitle.
  ///
  /// In ru, this message translates to:
  /// **'Запись блокировки повреждена'**
  String get lockDamagedTitle;

  /// No description provided for @lockDamagedBody.
  ///
  /// In ru, this message translates to:
  /// **'Прочитать её нельзя, и повтор не поможет. Выйти из этого состояния можно, только сбросив приложение: все аккаунты будут удалены.'**
  String get lockDamagedBody;

  /// No description provided for @resetApp.
  ///
  /// In ru, this message translates to:
  /// **'Сбросить приложение'**
  String get resetApp;

  /// No description provided for @pinLabel.
  ///
  /// In ru, this message translates to:
  /// **'PIN-код'**
  String get pinLabel;

  /// No description provided for @unlock.
  ///
  /// In ru, this message translates to:
  /// **'Разблокировать'**
  String get unlock;

  /// No description provided for @unlockWithBiometrics.
  ///
  /// In ru, this message translates to:
  /// **'Войти по отпечатку или лицу'**
  String get unlockWithBiometrics;

  /// No description provided for @pinWrong.
  ///
  /// In ru, this message translates to:
  /// **'Неверный PIN-код'**
  String get pinWrong;

  /// No description provided for @pinBlocked.
  ///
  /// In ru, this message translates to:
  /// **'PIN-код заблокирован: слишком много неверных попыток подряд. Войдите по отпечатку или лицу, если они включены, либо сбросьте приложение: все аккаунты будут удалены.'**
  String get pinBlocked;

  /// Shown while the wait after wrong PINs is on. The time is minutes and seconds, like 0:30 or 5:00.
  ///
  /// In ru, this message translates to:
  /// **'Слишком много попыток. Повторите через {time}'**
  String pinWait(String time);

  /// No description provided for @lockBiometricUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Вход по биометрии сейчас недоступен. Введите PIN-код.'**
  String get lockBiometricUnavailable;

  /// No description provided for @lockBiometricFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось подтвердить личность. Введите PIN-код.'**
  String get lockBiometricFailed;

  /// No description provided for @lockBiometricRenewalHint.
  ///
  /// In ru, this message translates to:
  /// **'Набор отпечатков или лиц на устройстве изменился, и вход по биометрии отключён. Введите PIN-код: после входа его можно включить заново.'**
  String get lockBiometricRenewalHint;

  /// No description provided for @lockStorageFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось записать попытку входа. Попробуйте ещё раз.'**
  String get lockStorageFailed;

  /// No description provided for @forgotPin.
  ///
  /// In ru, this message translates to:
  /// **'Забыли PIN-код?'**
  String get forgotPin;

  /// No description provided for @resetTitle.
  ///
  /// In ru, this message translates to:
  /// **'Сбросить приложение?'**
  String get resetTitle;

  /// No description provided for @resetBody.
  ///
  /// In ru, this message translates to:
  /// **'Все аккаунты и PIN-код будут удалены с этого устройства без возможности восстановления. Если вход на сайте защищён этими кодами, вы можете потерять доступ: проверьте, что у вас есть резервные коды или другой способ входа. После сброса вы создадите новый PIN-код.'**
  String get resetBody;

  /// No description provided for @resetConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Стереть всё'**
  String get resetConfirm;

  /// No description provided for @lockResetFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось стереть данные. Попробуйте ещё раз.'**
  String get lockResetFailed;

  /// The headline of the system prompt for a fingerprint or a face, which unlocks the app.
  ///
  /// In ru, this message translates to:
  /// **'Подтвердите вход'**
  String get biometricPromptTitle;

  /// The explanation under the headline of the system prompt.
  ///
  /// In ru, this message translates to:
  /// **'Приложение заблокировано'**
  String get biometricPromptSubtitle;

  /// No description provided for @pinSetupTitle.
  ///
  /// In ru, this message translates to:
  /// **'Создайте PIN-код'**
  String get pinSetupTitle;

  /// No description provided for @pinSetupHint.
  ///
  /// In ru, this message translates to:
  /// **'PIN-код закрывает вход в приложение. Он не шифрует секреты и не восстанавливается, поэтому запомните его.'**
  String get pinSetupHint;

  /// No description provided for @pinConfirmLabel.
  ///
  /// In ru, this message translates to:
  /// **'Повторите PIN-код'**
  String get pinConfirmLabel;

  /// No description provided for @pinCreate.
  ///
  /// In ru, this message translates to:
  /// **'Создать PIN-код'**
  String get pinCreate;

  /// No description provided for @pinLengthError.
  ///
  /// In ru, this message translates to:
  /// **'От {min} до {max} цифр'**
  String pinLengthError(int min, int max);

  /// No description provided for @pinDigitsOnly.
  ///
  /// In ru, this message translates to:
  /// **'Только цифры'**
  String get pinDigitsOnly;

  /// No description provided for @pinMismatch.
  ///
  /// In ru, this message translates to:
  /// **'PIN-коды не совпадают'**
  String get pinMismatch;

  /// No description provided for @pinSaveFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить PIN-код. Попробуйте ещё раз.'**
  String get pinSaveFailed;

  /// No description provided for @biometricOfferTitle.
  ///
  /// In ru, this message translates to:
  /// **'Включить вход по биометрии?'**
  String get biometricOfferTitle;

  /// No description provided for @biometricOfferBody.
  ///
  /// In ru, this message translates to:
  /// **'Отпечаток или лицо вместо PIN-кода. PIN-код останется запасным способом.'**
  String get biometricOfferBody;

  /// No description provided for @biometricRenewTitle.
  ///
  /// In ru, this message translates to:
  /// **'Набор отпечатков изменился'**
  String get biometricRenewTitle;

  /// No description provided for @biometricRenewBody.
  ///
  /// In ru, this message translates to:
  /// **'Вход по биометрии отключён, потому что на устройстве изменился набор отпечатков или лиц. Включить его заново?'**
  String get biometricRenewBody;

  /// No description provided for @biometricEnable.
  ///
  /// In ru, this message translates to:
  /// **'Включить'**
  String get biometricEnable;

  /// No description provided for @biometricNotNow.
  ///
  /// In ru, this message translates to:
  /// **'Не сейчас'**
  String get biometricNotNow;

  /// No description provided for @biometricUnavailableOnDevice.
  ///
  /// In ru, this message translates to:
  /// **'Биометрия недоступна на этом устройстве: нужны настроенные отпечатки или лицо и защищённое хранилище ключей.'**
  String get biometricUnavailableOnDevice;

  /// No description provided for @biometricEnableFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось включить вход по биометрии'**
  String get biometricEnableFailed;

  /// No description provided for @biometricDisableFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось отключить вход по биометрии'**
  String get biometricDisableFailed;

  /// No description provided for @menuLockNow.
  ///
  /// In ru, this message translates to:
  /// **'Заблокировать'**
  String get menuLockNow;

  /// No description provided for @menuBiometricsOn.
  ///
  /// In ru, this message translates to:
  /// **'Включить вход по биометрии'**
  String get menuBiometricsOn;

  /// No description provided for @menuBiometricsOff.
  ///
  /// In ru, this message translates to:
  /// **'Отключить вход по биометрии'**
  String get menuBiometricsOff;
}

class _SDelegate extends LocalizationsDelegate<S> {
  const _SDelegate();

  @override
  Future<S> load(Locale locale) {
    return SynchronousFuture<S>(lookupS(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_SDelegate old) => false;
}

S lookupS(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return SEn();
    case 'ru':
      return SRu();
  }

  throw FlutterError(
    'S.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
