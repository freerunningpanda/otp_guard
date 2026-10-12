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
}
