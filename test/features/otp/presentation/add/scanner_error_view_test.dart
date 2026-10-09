import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:otp_guard/app/strings.dart';
import 'package:otp_guard/features/otp/presentation/add/scanner_page.dart';

Future<void> pumpView(
  WidgetTester tester,
  MobileScannerErrorCode code,
  VoidCallback onEnterManually,
) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ScannerErrorView(
          errorCode: code,
          onEnterManually: onEnterManually,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('a refused permission is explained, with a way to type', (
    tester,
  ) async {
    var typed = 0;
    await pumpView(
      tester,
      MobileScannerErrorCode.permissionDenied,
      () => typed++,
    );

    expect(find.text(Strings.cameraDeniedTitle), findsOneWidget);
    expect(find.text(Strings.cameraDeniedBody), findsOneWidget);
    expect(find.text(Strings.cameraFailedTitle), findsNothing);

    await tester.tap(find.text(Strings.enterManually));

    expect(typed, 1);
  });

  testWidgets('any other camera error is told apart from a refusal', (
    tester,
  ) async {
    var typed = 0;
    await pumpView(
      tester,
      MobileScannerErrorCode.genericError,
      () => typed++,
    );

    expect(find.text(Strings.cameraFailedTitle), findsOneWidget);
    expect(find.text(Strings.cameraDeniedTitle), findsNothing);

    await tester.tap(find.text(Strings.enterManually));

    expect(typed, 1);
  });

  testWidgets('a device without a scanner also gets the way to type', (
    tester,
  ) async {
    await pumpView(tester, MobileScannerErrorCode.unsupported, () {});

    expect(find.text(Strings.enterManually), findsOneWidget);
  });
}
