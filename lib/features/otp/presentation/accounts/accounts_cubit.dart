import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:otp_guard/features/otp/domain/account_repository.dart';
import 'package:otp_guard/features/otp/domain/otp_auth_parser.dart';
import 'package:otp_guard/features/otp/presentation/accounts/accounts_state.dart';
import 'package:otp_guard/features/otp/presentation/accounts/add_account_outcome.dart';

/// Loads, adds and removes the accounts, and keeps the list for the screen.
class AccountsCubit extends Cubit<AccountsState> {
  /// Creates the cubit on a repository. [_newId] makes the ids of new
  /// accounts; a test passes its own.
  AccountsCubit(this._repository, {this._newId})
    : super(const AccountsLoading());

  final AccountRepository _repository;
  final String Function()? _newId;

  /// Reads the accounts from the storage.
  Future<void> load() async {
    emit(const AccountsLoading());
    await _reload();
  }

  /// Adds the account of an `otpauth://` link, such as a scanned QR code.
  Future<AddAccountOutcome> addFromUri(String uri) {
    return _add(parseOtpAuthUri(uri, newId: _newId));
  }

  /// Adds an account from what a person typed.
  Future<AddAccountOutcome> addManual({
    required String name,
    required String secret,
    String? issuer,
  }) {
    return _add(
      buildOtpAccount(
        issuer: issuer,
        name: name,
        secret: secret,
        newId: _newId,
      ),
    );
  }

  /// Removes the account with [id]. Returns whether the storage did it.
  Future<bool> remove(String id) async {
    try {
      await _repository.remove(id);
    } on Exception {
      // The storage can fail (a platform error, a full disk). The screen is
      // told "no" and the list stays as it is.
      return false;
    }
    await _reload();
    return true;
  }

  /// Removes the records that could not be read. Returns whether the storage
  /// did it.
  Future<bool> removeUnreadable() async {
    final current = state;
    if (current is! AccountsLoaded) return true;
    try {
      for (final id in current.unreadableIds) {
        await _repository.remove(id);
      }
    } on Exception {
      return false;
    }
    await _reload();
    return true;
  }

  Future<AddAccountOutcome> _add(OtpAuthParseResult parsed) async {
    switch (parsed) {
      case OtpAuthFailure():
        return AccountRejected(parsed);
      case OtpAuthParsed(:final account):
        final AddAccountResult result;
        try {
          result = await _repository.add(account);
        } on Exception {
          return const AccountStorageFailed();
        }
        switch (result) {
          case AccountAdded(:final account):
            await _reload();
            return AccountSaved(account);
          case AccountAlreadyExists(:final existing):
            return AccountDuplicate(existing);
        }
    }
  }

  Future<void> _reload() async {
    try {
      final stored = await _repository.getAccounts();
      if (isClosed) return;
      emit(
        AccountsLoaded(
          accounts: stored.accounts,
          unreadableIds: stored.unreadableIds,
        ),
      );
    } on Exception {
      if (isClosed) return;
      emit(const AccountsFailure());
    }
  }
}
