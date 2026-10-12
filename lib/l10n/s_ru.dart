// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 's.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class SRu extends S {
  SRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Аутентификатор';

  @override
  String get emptyTitle => 'Аккаунтов пока нет';

  @override
  String get emptyHint =>
      'Добавьте первый аккаунт: отсканируйте QR-код сайта или введите секрет вручную.';

  @override
  String get addAccount => 'Добавить аккаунт';

  @override
  String get loadFailed => 'Не удалось загрузить аккаунты';

  @override
  String get retry => 'Повторить';

  @override
  String get deviceKeyDemo => 'Проверка ключа устройства';

  @override
  String unreadableWarning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Не удалось прочитать $count записи. Они не показаны, но остались в хранилище.',
      many:
          'Не удалось прочитать $count записей. Они не показаны, но остались в хранилище.',
      few:
          'Не удалось прочитать $count записи. Они не показаны, но остались в хранилище.',
      one:
          'Не удалось прочитать $count запись. Она не показана, но осталась в хранилище.',
    );
    return '$_temp0';
  }

  @override
  String get deleteUnreadable => 'Удалить';

  @override
  String get deleteUnreadableTitle => 'Удалить нечитаемые записи?';

  @override
  String get deleteUnreadableBody =>
      'Записи будут удалены без возможности восстановления.';

  @override
  String get deleteTitle => 'Удалить аккаунт?';

  @override
  String deleteBody(String name) {
    return 'Коды для «$name» перестанут показываться. Если вход по ним на сайте включён, вы можете потерять доступ: сначала отключите двухфакторную защиту на сайте.';
  }

  @override
  String get cancel => 'Отмена';

  @override
  String get delete => 'Удалить';

  @override
  String get deleteFailed => 'Не удалось удалить. Попробуйте ещё раз.';

  @override
  String get recordingBanner =>
      'Идёт запись экрана. Коды скрыты, пока она не закончится.';

  @override
  String get screenshotTaken =>
      'Сделан снимок экрана. Коды на нём могли попасть в кадр.';

  @override
  String get protectionFailedBanner =>
      'Защита экрана не включилась. Снимки, запись экрана и превью в списке приложений не защищены: коды могут попасть в кадр.';

  @override
  String get scanQr => 'Сканировать QR-код';

  @override
  String get enterManually => 'Ввести вручную';

  @override
  String get accountAdded => 'Аккаунт добавлен';

  @override
  String get accountDuplicate => 'Этот аккаунт уже добавлен';

  @override
  String get saveFailed => 'Не удалось сохранить аккаунт. Попробуйте ещё раз.';

  @override
  String get scanTitle => 'Сканирование QR-кода';

  @override
  String get scanHint => 'Наведите камеру на QR-код сайта';

  @override
  String get cameraDeniedTitle => 'Нет доступа к камере';

  @override
  String get cameraDeniedBody =>
      'Разрешите доступ к камере в настройках телефона или введите секрет вручную.';

  @override
  String get cameraFailedTitle => 'Не удалось запустить камеру';

  @override
  String get cameraFailedBody =>
      'Попробуйте ещё раз или введите секрет вручную.';

  @override
  String get scanAgain => 'Сканировать снова';

  @override
  String get cannotAddTitle => 'Не удалось добавить аккаунт';

  @override
  String get manualTitle => 'Новый аккаунт';

  @override
  String get issuerLabel => 'Сервис (необязательно)';

  @override
  String get nameLabel => 'Аккаунт';

  @override
  String get secretLabel => 'Секрет (Base32)';

  @override
  String get save => 'Сохранить';

  @override
  String get nameRequired => 'Введите название аккаунта';

  @override
  String get secretRequired => 'Введите секрет';

  @override
  String get secretInvalid =>
      'Секрет должен быть в формате Base32: буквы A–Z и цифры 2–7';

  @override
  String get failureNotAnOtpAuthUri =>
      'Это не QR-код аутентификатора. Нужен код со ссылкой otpauth://.';

  @override
  String get failureHotp =>
      'Счётчиковые коды (HOTP) не поддерживаются. Приложение работает с кодами по времени (TOTP).';

  @override
  String failureUnsupportedType(String type) {
    return 'Тип кодов «$type» не поддерживается. Приложение работает с кодами по времени (TOTP).';
  }

  @override
  String get failureMissingLabel => 'В QR-коде нет названия аккаунта.';

  @override
  String get failureMissingSecret => 'В QR-коде нет секрета.';

  @override
  String get failureInvalidSecret =>
      'Секрет в QR-коде повреждён: он не в формате Base32.';

  @override
  String failureInvalidAlgorithm(String value) {
    return 'Алгоритм «$value» не поддерживается. Допустимы SHA1, SHA256 и SHA512.';
  }

  @override
  String failureInvalidDigits(String value) {
    return 'Недопустимое число цифр: «$value». Допустимы 6, 7 и 8.';
  }

  @override
  String failureInvalidPeriod(String value) {
    return 'Недопустимый период: «$value». Нужно целое число секунд больше нуля.';
  }

  @override
  String failureInvalidParameter(String name, String value) {
    return 'Недопустимое значение «$value» параметра $name.';
  }

  @override
  String get lockTitle => 'Приложение заблокировано';

  @override
  String get lockLoadFailedTitle => 'Не удалось прочитать настройки блокировки';

  @override
  String get lockLoadFailedBody =>
      'Приложение остаётся закрытым, пока их нельзя прочитать.';

  @override
  String get lockDamagedTitle => 'Запись блокировки повреждена';

  @override
  String get lockDamagedBody =>
      'Прочитать её нельзя, и повтор не поможет. Выйти из этого состояния можно, только сбросив приложение: все аккаунты будут удалены.';

  @override
  String get resetApp => 'Сбросить приложение';

  @override
  String get pinLabel => 'PIN-код';

  @override
  String get unlock => 'Разблокировать';

  @override
  String get unlockWithBiometrics => 'Войти по отпечатку или лицу';

  @override
  String get pinWrong => 'Неверный PIN-код';

  @override
  String pinWait(String time) {
    return 'Слишком много попыток. Повторите через $time';
  }

  @override
  String get lockBiometricUnavailable =>
      'Вход по биометрии сейчас недоступен. Введите PIN-код.';

  @override
  String get lockBiometricFailed =>
      'Не удалось подтвердить личность. Введите PIN-код.';

  @override
  String get lockBiometricRenewalHint =>
      'Набор отпечатков или лиц на устройстве изменился, и вход по биометрии отключён. Введите PIN-код: после входа его можно включить заново.';

  @override
  String get lockStorageFailed =>
      'Не удалось записать попытку входа. Попробуйте ещё раз.';

  @override
  String get forgotPin => 'Забыли PIN-код?';

  @override
  String get resetTitle => 'Сбросить приложение?';

  @override
  String get resetBody =>
      'Все аккаунты и PIN-код будут удалены с этого устройства без возможности восстановления. Если вход на сайте защищён этими кодами, вы можете потерять доступ: проверьте, что у вас есть резервные коды или другой способ входа. После сброса вы создадите новый PIN-код.';

  @override
  String get resetConfirm => 'Стереть всё';

  @override
  String get lockResetFailed =>
      'Не удалось стереть данные. Попробуйте ещё раз.';

  @override
  String get biometricPromptTitle => 'Подтвердите вход';

  @override
  String get biometricPromptSubtitle => 'Приложение заблокировано';

  @override
  String get pinSetupTitle => 'Создайте PIN-код';

  @override
  String get pinSetupHint =>
      'PIN-код закрывает вход в приложение. Он не шифрует секреты и не восстанавливается, поэтому запомните его.';

  @override
  String get pinConfirmLabel => 'Повторите PIN-код';

  @override
  String get pinCreate => 'Создать PIN-код';

  @override
  String pinLengthError(int min, int max) {
    return 'От $min до $max цифр';
  }

  @override
  String get pinDigitsOnly => 'Только цифры';

  @override
  String get pinMismatch => 'PIN-коды не совпадают';

  @override
  String get pinSaveFailed =>
      'Не удалось сохранить PIN-код. Попробуйте ещё раз.';

  @override
  String get biometricOfferTitle => 'Включить вход по биометрии?';

  @override
  String get biometricOfferBody =>
      'Отпечаток или лицо вместо PIN-кода. PIN-код останется запасным способом.';

  @override
  String get biometricRenewTitle => 'Набор отпечатков изменился';

  @override
  String get biometricRenewBody =>
      'Вход по биометрии отключён, потому что на устройстве изменился набор отпечатков или лиц. Включить его заново?';

  @override
  String get biometricEnable => 'Включить';

  @override
  String get biometricNotNow => 'Не сейчас';

  @override
  String get biometricUnavailableOnDevice =>
      'Биометрия недоступна на этом устройстве: нужны настроенные отпечатки или лицо и защищённое хранилище ключей.';

  @override
  String get biometricEnableFailed => 'Не удалось включить вход по биометрии';

  @override
  String get biometricDisableFailed => 'Не удалось отключить вход по биометрии';

  @override
  String get menuLockNow => 'Заблокировать';

  @override
  String get menuBiometricsOn => 'Включить вход по биометрии';

  @override
  String get menuBiometricsOff => 'Отключить вход по биометрии';
}
