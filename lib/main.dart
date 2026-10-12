import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:otp_guard/app/app.dart';
import 'package:otp_guard/app/injection.dart';
import 'package:otp_guard/app/router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final getIt = GetIt.instance;
  configureDependencies(getIt);
  runApp(
    App(
      getIt: getIt,
      router: createRouter(lock: getIt()),
    ),
  );
}
