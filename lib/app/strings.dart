import 'package:otp_guard/features/otp/domain/otp_auth_parser.dart';

/// All the texts of the interface in one place, so they can be translated or
/// reworded without a search through the widgets.
abstract final class Strings {
  static const appTitle = 'Аутентификатор';

  // The list.
  static const emptyTitle = 'Аккаунтов пока нет';
  static const emptyHint =
      'Добавьте первый аккаунт: отсканируйте QR-код сайта '
      'или введите секрет вручную.';
  static const addAccount = 'Добавить аккаунт';
  static const loadFailed = 'Не удалось загрузить аккаунты';
  static const retry = 'Повторить';
  static const hiddenCode = '••• •••';
  static const deviceKeyDemo = 'Проверка ключа устройства';

  static String unreadableWarning(int count) =>
      'Не удалось прочитать записей: $count. Они не показаны, '
      'но остались в хранилище.';
  static const deleteUnreadable = 'Удалить';
  static const deleteUnreadableTitle = 'Удалить нечитаемые записи?';
  static const deleteUnreadableBody =
      'Записи будут удалены без возможности восстановления.';

  // Deleting.
  static const deleteTitle = 'Удалить аккаунт?';
  static String deleteBody(String name) =>
      'Коды для «$name» перестанут показываться. Если вход по ним на сайте '
      'включён, вы можете потерять доступ: сначала отключите двухфакторную '
      'защиту на сайте.';
  static const cancel = 'Отмена';
  static const delete = 'Удалить';
  static const deleteFailed = 'Не удалось удалить. Попробуйте ещё раз.';

  // Screen security.
  static const recordingBanner =
      'Идёт запись экрана. Коды скрыты, пока она не закончится.';
  static const screenshotTaken =
      'Сделан снимок экрана. Коды на нём могли попасть в кадр.';

  // Adding.
  static const scanQr = 'Сканировать QR-код';
  static const enterManually = 'Ввести вручную';
  static const accountAdded = 'Аккаунт добавлен';
  static const accountDuplicate = 'Этот аккаунт уже добавлен';
  static const saveFailed = 'Не удалось сохранить аккаунт. Попробуйте ещё раз.';

  // The scanner.
  static const scanTitle = 'Сканирование QR-кода';
  static const scanHint = 'Наведите камеру на QR-код сайта';
  static const cameraDeniedTitle = 'Нет доступа к камере';
  static const cameraDeniedBody =
      'Разрешите доступ к камере в настройках телефона '
      'или введите секрет вручную.';
  static const cameraFailedTitle = 'Не удалось запустить камеру';
  static const cameraFailedBody =
      'Попробуйте ещё раз или введите секрет вручную.';
  static const scanAgain = 'Сканировать снова';
  static const cannotAddTitle = 'Не удалось добавить аккаунт';

  // The manual form.
  static const manualTitle = 'Новый аккаунт';
  static const issuerLabel = 'Сервис (необязательно)';
  static const nameLabel = 'Аккаунт';
  static const secretLabel = 'Секрет (Base32)';
  static const save = 'Сохранить';
  static const nameRequired = 'Введите название аккаунта';
  static const secretRequired = 'Введите секрет';
  static const secretInvalid =
      'Секрет должен быть в формате Base32: буквы A–Z и цифры 2–7';

  /// A message for each reason a link can not be used. The `switch` is
  /// exhaustive: a new kind of failure does not compile until it has a text.
  static String forFailure(OtpAuthFailure failure) {
    return switch (failure) {
      NotAnOtpAuthUri() =>
        'Это не QR-код аутентификатора. Нужен код со ссылкой otpauth://.',
      UnsupportedOtpType(:final type) when type == 'hotp' =>
        'Счётчиковые коды (HOTP) не поддерживаются. Приложение работает '
            'с кодами по времени (TOTP).',
      UnsupportedOtpType(:final type) =>
        'Тип кодов «$type» не поддерживается. Приложение работает '
            'с кодами по времени (TOTP).',
      MissingLabel() => 'В QR-коде нет названия аккаунта.',
      MissingSecret() => 'В QR-коде нет секрета.',
      InvalidSecret() => 'Секрет в QR-коде повреждён: он не в формате Base32.',
      InvalidParameter(name: 'algorithm', :final value) =>
        'Алгоритм «$value» не поддерживается. Допустимы SHA1, SHA256 и SHA512.',
      InvalidParameter(name: 'digits', :final value) =>
        'Недопустимое число цифр: «$value». Допустимы 6, 7 и 8.',
      InvalidParameter(name: 'period', :final value) =>
        'Недопустимый период: «$value». Нужно целое число секунд больше нуля.',
      InvalidParameter(:final name, :final value) =>
        'Недопустимое значение «$value» параметра $name.',
    };
  }
}
