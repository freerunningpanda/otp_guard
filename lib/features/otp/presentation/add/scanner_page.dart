import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:otp_guard/app/strings.dart';
import 'package:otp_guard/features/otp/presentation/accounts/accounts_cubit.dart';
import 'package:otp_guard/features/otp/presentation/accounts/add_account_outcome.dart';

/// Scans a QR code of an authenticator and adds the account in it.
class ScannerPage extends StatefulWidget {
  /// Creates the page. [onFinished] is called when the account is added or
  /// already there, and [onEnterManually] when the user prefers to type.
  const ScannerPage({
    required this.onFinished,
    required this.onEnterManually,
    super.key,
  });

  /// Closes the page after an account is added.
  final VoidCallback onFinished;

  /// Goes to the form for typing an account.
  final VoidCallback onEnterManually;

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );

  // The scanner reports the same code several times a second. After the first
  // one the scanner is stopped and the rest are ignored, or one scan would try
  // to add the account again and again.
  bool _isHandling = false;

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isHandling) return;
    final value = capture.barcodes
        .map((barcode) => barcode.rawValue)
        .whereType<String>()
        .firstOrNull;
    if (value == null) return;
    _isHandling = true;
    unawaited(_handle(value));
  }

  Future<void> _handle(String value) async {
    await _controller.stop();
    if (!mounted) return;

    final outcome = await context.read<AccountsCubit>().addFromUri(value);
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    switch (outcome) {
      case AccountSaved():
        messenger.showSnackBar(
          const SnackBar(content: Text(Strings.accountAdded)),
        );
        widget.onFinished();
      case AccountDuplicate():
        messenger.showSnackBar(
          const SnackBar(content: Text(Strings.accountDuplicate)),
        );
        widget.onFinished();
      case AccountRejected(:final failure):
        await _showProblem(Strings.forFailure(failure));
      case AccountStorageFailed():
        await _showProblem(Strings.saveFailed);
    }
  }

  // Tells what is wrong and lets the user scan again or type. The scanner
  // starts again only after that, so a QR code that can not be used is not
  // read and refused over and over.
  Future<void> _showProblem(String message) async {
    final scanAgain = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text(Strings.cannotAddTitle),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(Strings.enterManually),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(Strings.scanAgain),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (scanAgain ?? false) {
      _isHandling = false;
      await _controller.start();
    } else {
      widget.onEnterManually();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(Strings.scanTitle)),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => ScannerErrorView(
              errorCode: error.errorCode,
              onEnterManually: widget.onEnterManually,
            ),
          ),
          const Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.all(24),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    Strings.scanHint,
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// What the scanner shows instead of the camera when it can not start: the
/// permission was refused, or the camera does not work. Either way the user can
/// go on and type the secret.
class ScannerErrorView extends StatelessWidget {
  /// Creates the view for the [errorCode] of the scanner.
  const ScannerErrorView({
    required this.errorCode,
    required this.onEnterManually,
    super.key,
  });

  /// Why the scanner did not start.
  final MobileScannerErrorCode errorCode;

  /// Goes to the form for typing an account.
  final VoidCallback onEnterManually;

  @override
  Widget build(BuildContext context) {
    final denied = errorCode == MobileScannerErrorCode.permissionDenied;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              denied ? Icons.no_photography_outlined : Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              denied ? Strings.cameraDeniedTitle : Strings.cameraFailedTitle,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              denied ? Strings.cameraDeniedBody : Strings.cameraFailedBody,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onEnterManually,
              child: const Text(Strings.enterManually),
            ),
          ],
        ),
      ),
    );
  }
}
