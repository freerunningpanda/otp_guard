import 'package:device_security/device_security.dart';
import 'package:get_it/get_it.dart';
import 'package:otp_guard/core/security/device_keys.dart';
import 'package:otp_guard/core/security/screen_security.dart';
import 'package:otp_guard/core/time/clock.dart';
import 'package:otp_guard/core/time/system_clock.dart';
import 'package:otp_guard/features/lock/data/secure_lock_repository.dart';
import 'package:otp_guard/features/lock/domain/biometric_auth.dart';
import 'package:otp_guard/features/lock/domain/lock_repository.dart';
import 'package:otp_guard/features/lock/domain/pin_hasher.dart';
import 'package:otp_guard/features/lock/presentation/lock_cubit.dart';
import 'package:otp_guard/features/otp/data/flutter_secure_key_value_store.dart';
import 'package:otp_guard/features/otp/data/key_value_store.dart';
import 'package:otp_guard/features/otp/data/secure_account_repository.dart';
import 'package:otp_guard/features/otp/domain/account_repository.dart';
import 'package:otp_guard/features/otp/presentation/accounts/accounts_cubit.dart';

/// Registers what the app is made of. This is the one place that names the
/// concrete classes; everything else asks for an interface.
///
/// [getIt] is a parameter, so a test can fill its own container.
void configureDependencies(GetIt getIt) {
  getIt
    ..registerLazySingleton<Clock>(SystemClock.new)
    ..registerLazySingleton<KeyValueStore>(FlutterSecureKeyValueStore.new)
    ..registerLazySingleton<AccountRepository>(
      () => SecureAccountRepository(getIt()),
    )
    ..registerLazySingleton<DeviceSecurity>(DeviceSecurity.new)
    ..registerLazySingleton<ScreenSecurity>(
      () => DeviceScreenSecurity(getIt()),
    )
    ..registerLazySingleton<DeviceKeys>(() => DeviceSecurityKeys(getIt()))
    ..registerLazySingleton<LockRepository>(
      () => SecureLockRepository(getIt()),
    )
    ..registerLazySingleton<PinHasher>(PinHasher.new)
    ..registerLazySingleton<BiometricAuth>(() => BiometricAuth(getIt()))
    // One lock for the whole app: the router and the screens ask the same one.
    ..registerLazySingleton<LockCubit>(
      () => LockCubit(
        repository: getIt(),
        accounts: getIt(),
        hasher: getIt(),
        biometrics: getIt(),
        clock: getIt(),
      ),
    )
    ..registerFactory<AccountsCubit>(() => AccountsCubit(getIt()));
}
