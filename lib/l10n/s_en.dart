// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 's.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class SEn extends S {
  SEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Authenticator';

  @override
  String get emptyTitle => 'No accounts yet';

  @override
  String get emptyHint =>
      'Add your first account: scan the QR code of a website or type the secret in by hand.';

  @override
  String get addAccount => 'Add account';

  @override
  String get loadFailed => 'Could not load the accounts';

  @override
  String get retry => 'Retry';

  @override
  String get deviceKeyDemo => 'Device key check';

  @override
  String unreadableWarning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count entries could not be read. They are not shown but are still in the storage.',
      one:
          '$count entry could not be read. It is not shown but is still in the storage.',
    );
    return '$_temp0';
  }

  @override
  String get deleteUnreadable => 'Delete';

  @override
  String get deleteUnreadableTitle => 'Delete the unreadable entries?';

  @override
  String get deleteUnreadableBody => 'The entries will be deleted for good.';

  @override
  String get deleteTitle => 'Delete the account?';

  @override
  String deleteBody(String name) {
    return 'The codes for “$name” will no longer be shown. If signing in with them is turned on for the website, you may lose access: turn two-factor authentication off on the website first.';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get deleteFailed => 'Could not delete. Try again.';

  @override
  String get recordingBanner =>
      'The screen is being recorded. The codes are hidden until it ends.';

  @override
  String get screenshotTaken =>
      'A screenshot was taken. The codes may be in it.';

  @override
  String get protectionFailedBanner =>
      'Screen protection could not be turned on. Screenshots, screen recording and the app preview in the task switcher are not protected: the codes may leak.';

  @override
  String get scanQr => 'Scan a QR code';

  @override
  String get enterManually => 'Enter manually';

  @override
  String get accountAdded => 'Account added';

  @override
  String get accountDuplicate => 'This account is already added';

  @override
  String get saveFailed => 'Could not save the account. Try again.';

  @override
  String get scanTitle => 'Scan a QR code';

  @override
  String get scanHint => 'Point the camera at the QR code of a website';

  @override
  String get cameraDeniedTitle => 'No access to the camera';

  @override
  String get cameraDeniedBody =>
      'Allow access to the camera in the phone settings or enter the secret manually.';

  @override
  String get cameraFailedTitle => 'Could not start the camera';

  @override
  String get cameraFailedBody => 'Try again or enter the secret manually.';

  @override
  String get scanAgain => 'Scan again';

  @override
  String get cannotAddTitle => 'Could not add the account';

  @override
  String get manualTitle => 'New account';

  @override
  String get issuerLabel => 'Service (optional)';

  @override
  String get nameLabel => 'Account';

  @override
  String get secretLabel => 'Secret (Base32)';

  @override
  String get save => 'Save';

  @override
  String get nameRequired => 'Enter the account name';

  @override
  String get secretRequired => 'Enter the secret';

  @override
  String get secretInvalid =>
      'The secret must be in Base32: letters A–Z and digits 2–7';

  @override
  String get failureNotAnOtpAuthUri =>
      'This is not an authenticator QR code. It must contain an otpauth:// link.';

  @override
  String get failureHotp =>
      'Counter-based codes (HOTP) are not supported. The app works with time-based codes (TOTP).';

  @override
  String failureUnsupportedType(String type) {
    return 'The code type “$type” is not supported. The app works with time-based codes (TOTP).';
  }

  @override
  String get failureMissingLabel => 'The QR code has no account name.';

  @override
  String get failureMissingSecret => 'The QR code has no secret.';

  @override
  String get failureInvalidSecret =>
      'The secret in the QR code is damaged: it is not in Base32.';

  @override
  String failureInvalidAlgorithm(String value) {
    return 'The algorithm “$value” is not supported. SHA1, SHA256 and SHA512 are allowed.';
  }

  @override
  String failureInvalidDigits(String value) {
    return 'Invalid number of digits: “$value”. 6, 7 and 8 are allowed.';
  }

  @override
  String failureInvalidPeriod(String value) {
    return 'Invalid period: “$value”. It must be a whole number of seconds above zero.';
  }

  @override
  String failureInvalidParameter(String name, String value) {
    return 'Invalid value “$value” of the parameter $name.';
  }

  @override
  String get lockTitle => 'The app is locked';

  @override
  String get lockLoadFailedTitle => 'Could not read the lock settings';

  @override
  String get lockLoadFailedBody =>
      'The app stays locked until they can be read.';

  @override
  String get lockDamagedTitle => 'The lock record is damaged';

  @override
  String get lockDamagedBody =>
      'It cannot be read, and trying again will not help. The only way out is to reset the app, which deletes all the accounts.';

  @override
  String get resetApp => 'Reset the app';

  @override
  String get pinLabel => 'PIN';

  @override
  String get unlock => 'Unlock';

  @override
  String get unlockWithBiometrics => 'Sign in with fingerprint or face';

  @override
  String get pinWrong => 'Wrong PIN';

  @override
  String pinWait(String time) {
    return 'Too many attempts. Try again in $time';
  }

  @override
  String get lockBiometricUnavailable =>
      'Biometric sign-in is not available now. Enter the PIN.';

  @override
  String get lockBiometricFailed =>
      'Could not confirm your identity. Enter the PIN.';

  @override
  String get lockBiometricRenewalHint =>
      'The fingerprints or faces on the device changed, so biometric sign-in is off. Enter the PIN; you can turn it on again after signing in.';

  @override
  String get lockStorageFailed =>
      'Could not record the sign-in attempt. Try again.';

  @override
  String get forgotPin => 'Forgot the PIN?';

  @override
  String get resetTitle => 'Reset the app?';

  @override
  String get resetBody =>
      'All accounts and the PIN will be deleted from this device for good. If signing in to a website is protected by these codes, you may lose access: make sure you have backup codes or another way to sign in. After the reset you will create a new PIN.';

  @override
  String get resetConfirm => 'Erase everything';

  @override
  String get lockResetFailed => 'Could not erase the data. Try again.';

  @override
  String get biometricPromptTitle => 'Confirm sign-in';

  @override
  String get biometricPromptSubtitle => 'The app is locked';

  @override
  String get pinSetupTitle => 'Create a PIN';

  @override
  String get pinSetupHint =>
      'The PIN guards the way into the app. It does not encrypt the secrets and cannot be recovered, so remember it.';

  @override
  String get pinConfirmLabel => 'Repeat the PIN';

  @override
  String get pinCreate => 'Create PIN';

  @override
  String pinLengthError(int min, int max) {
    return '$min to $max digits';
  }

  @override
  String get pinDigitsOnly => 'Digits only';

  @override
  String get pinMismatch => 'The PINs do not match';

  @override
  String get pinSaveFailed => 'Could not save the PIN. Try again.';

  @override
  String get biometricOfferTitle => 'Turn on biometric sign-in?';

  @override
  String get biometricOfferBody =>
      'A fingerprint or face instead of the PIN. The PIN stays as the fallback.';

  @override
  String get biometricRenewTitle => 'The fingerprints changed';

  @override
  String get biometricRenewBody =>
      'Biometric sign-in was turned off because the fingerprints or faces on the device changed. Turn it on again?';

  @override
  String get biometricEnable => 'Turn on';

  @override
  String get biometricNotNow => 'Not now';

  @override
  String get biometricUnavailableOnDevice =>
      'Biometrics are not available on this device: it needs enrolled fingerprints or a face and secure key storage.';

  @override
  String get biometricEnableFailed => 'Could not turn on biometric sign-in';

  @override
  String get biometricDisableFailed => 'Could not turn off biometric sign-in';

  @override
  String get menuLockNow => 'Lock now';

  @override
  String get menuBiometricsOn => 'Turn on biometric sign-in';

  @override
  String get menuBiometricsOff => 'Turn off biometric sign-in';
}
