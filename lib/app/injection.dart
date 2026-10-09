import 'package:device_security/device_security.dart';
import 'package:get_it/get_it.dart';
import 'package:otp_guard/core/security/screen_security.dart';
import 'package:otp_guard/core/time/clock.dart';
import 'package:otp_guard/core/time/system_clock.dart';
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
    ..registerFactory<AccountsCubit>(() => AccountsCubit(getIt()));
}
