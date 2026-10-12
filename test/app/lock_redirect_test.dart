import 'package:flutter_test/flutter_test.dart';
import 'package:otp_guard/app/router.dart';
import 'package:otp_guard/features/lock/domain/biometric_setting.dart';
import 'package:otp_guard/features/lock/presentation/lock_state.dart';

void main() {
  const everyScreen = [
    AppRoutes.accounts,
    AppRoutes.scan,
    AppRoutes.manual,
    AppRoutes.keyDemo,
    AppRoutes.lock,
    AppRoutes.pinSetup,
    '/something/else',
  ];

  group('while the lock is closed, every path leads to the lock screen', () {
    const closed = <String, AppLockState>{
      'loading': LockLoading(),
      'failed to load': LockLoadFailed(),
      'locked': Locked(),
      'locked, with biometrics': Locked(biometric: BiometricStatus.on),
      'locked, waiting': Locked(problem: UnlockProblem.wrongPin),
      'locked, busy': Locked(isBusy: true),
    };

    for (final MapEntry(key: name, value: state) in closed.entries) {
      test(name, () {
        for (final location in everyScreen) {
          final target = lockRedirect(state, location);
          if (location == AppRoutes.lock) {
            expect(target, isNull, reason: 'already there');
          } else {
            expect(target, AppRoutes.lock, reason: location);
          }
        }
      });
    }
  });

  group('while no PIN is set, every path leads to its creation', () {
    test('from every screen', () {
      for (final location in everyScreen) {
        final target = lockRedirect(const PinNotSet(), location);
        if (location == AppRoutes.pinSetup) {
          expect(target, isNull, reason: 'already there');
        } else {
          expect(target, AppRoutes.pinSetup, reason: location);
        }
      }
    });
  });

  group('once the app is open', () {
    test('its screens are free', () {
      for (final location in [
        AppRoutes.accounts,
        AppRoutes.scan,
        AppRoutes.manual,
        AppRoutes.keyDemo,
        '/something/else',
      ]) {
        expect(
          lockRedirect(const Unlocked(), location),
          isNull,
          reason: location,
        );
      }
    });

    test('the screens of the lock lead on to the list', () {
      expect(
        lockRedirect(const Unlocked(), AppRoutes.lock),
        AppRoutes.accounts,
      );
      expect(
        lockRedirect(const Unlocked(), AppRoutes.pinSetup),
        AppRoutes.accounts,
      );
    });

    test('the offer does not change where the app goes', () {
      const state = Unlocked(offer: BiometricOffer.setup);

      expect(lockRedirect(state, AppRoutes.accounts), isNull);
      expect(lockRedirect(state, AppRoutes.lock), AppRoutes.accounts);
    });
  });

  test('a redirect never sends to a place that redirects again', () {
    // A chain of redirects would loop. Each target must be a place where the
    // same state has nothing more to say.
    const states = <AppLockState>[
      LockLoading(),
      LockLoadFailed(),
      PinNotSet(),
      Locked(),
      Unlocked(),
    ];
    for (final state in states) {
      for (final location in everyScreen) {
        final target = lockRedirect(state, location);
        if (target != null) {
          expect(
            lockRedirect(state, target),
            isNull,
            reason: '$state $location',
          );
        }
      }
    }
  });
}
