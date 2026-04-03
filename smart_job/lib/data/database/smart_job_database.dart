import 'dart:async';
import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SmartJobDatabase {
  SmartJobDatabase._(this._accountsBox, this._sessionBox);

  static const String legacyAccountsKey = 'smart_job.accounts.v1';
  static const String accountsBoxName = 'smart_job.accounts.box';
  static const String sessionBoxName = 'smart_job.session.box';
  static const String currentSessionEmailKey = 'current_session_email';

  final Box<String> _accountsBox;
  final Box<String> _sessionBox;

  static Future<SmartJobDatabase> open({
    SharedPreferences? legacyPreferences,
  }) async {
    await Hive.initFlutter();
    return _openBoxes(legacyPreferences: legacyPreferences);
  }

  static Future<SmartJobDatabase> openAtPath(
    String path, {
    SharedPreferences? legacyPreferences,
  }) async {
    Hive.init(path);
    return _openBoxes(legacyPreferences: legacyPreferences);
  }

  static Future<SmartJobDatabase> _openBoxes({
    SharedPreferences? legacyPreferences,
  }) async {
    final accountsBox = await Hive.openBox<String>(accountsBoxName);
    final sessionBox = await Hive.openBox<String>(sessionBoxName);
    final database = SmartJobDatabase._(accountsBox, sessionBox);
    if (legacyPreferences != null) {
      await database.migrateLegacyAccounts(legacyPreferences);
    }
    return database;
  }

  Future<void> migrateLegacyAccounts(SharedPreferences preferences) async {
    final legacyAccounts = preferences.getString(legacyAccountsKey);
    if (legacyAccounts == null || legacyAccounts.isEmpty || _accountsBox.isNotEmpty) {
      return;
    }

    final decoded = jsonDecode(legacyAccounts);
    if (decoded is! Map<String, dynamic>) {
      return;
    }

    final migratedEntries = <String, String>{
      for (final entry in decoded.entries)
        normalizeEmail(entry.key): jsonEncode(entry.value),
    };

    if (migratedEntries.isEmpty) {
      return;
    }

    await _accountsBox.putAll(migratedEntries);
    await preferences.remove(legacyAccountsKey);
  }

  Map<String, dynamic>? readAccount(String email) {
    final raw = _accountsBox.get(normalizeEmail(email));
    if (raw == null || raw.isEmpty) {
      return null;
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    return decoded;
  }

  void writeAccount(String email, Map<String, dynamic> account) {
    unawaited(
      _accountsBox.put(normalizeEmail(email), jsonEncode(account)),
    );
  }

  void deleteAccount(String email) {
    final normalizedEmail = normalizeEmail(email);
    unawaited(_accountsBox.delete(normalizedEmail));
    if (currentSessionEmail() == normalizedEmail) {
      clearCurrentSession();
    }
  }

  String? currentSessionEmail() {
    final email = _sessionBox.get(currentSessionEmailKey);
    if (email == null || email.isEmpty) {
      return null;
    }
    return email;
  }

  void saveCurrentSessionEmail(String email) {
    unawaited(
      _sessionBox.put(currentSessionEmailKey, normalizeEmail(email)),
    );
  }

  void clearCurrentSession() {
    unawaited(_sessionBox.delete(currentSessionEmailKey));
  }

  String normalizeEmail(String email) => email.trim().toLowerCase();
}

