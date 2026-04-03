import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SmartJobRemoteSync {
  SmartJobRemoteSync._(this._client);

  static const String accountTable = 'smart_job_accounts';
  static const String cvBucket = 'smart-job-cvs';

  final SupabaseClient _client;

  static Future<SmartJobRemoteSync?> initializeFromEnvironment() async {
    const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
    const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      return null;
    }

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );

    return SmartJobRemoteSync._(Supabase.instance.client);
  }

  Future<Map<String, dynamic>?> fetchAccount(String email) async {
    final normalizedEmail = _normalizeEmail(email);
    final row = await _client
        .from(accountTable)
        .select('account_data')
        .eq('email', normalizedEmail)
        .maybeSingle();

    if (row == null) {
      return null;
    }

    final accountData = row['account_data'];
    if (accountData is Map<String, dynamic>) {
      return accountData;
    }
    if (accountData is Map) {
      return accountData.map(
        (key, value) => MapEntry(key.toString(), value),
      );
    }
    return null;
  }

  Future<void> pushAccount({
    required String email,
    required String fullName,
    required Map<String, dynamic> accountData,
  }) async {
    final normalizedEmail = _normalizeEmail(email);
    await _client.from(accountTable).upsert({
      'email': normalizedEmail,
      'full_name': fullName.trim(),
      'account_data': accountData,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> deleteAccount(String email) async {
    final normalizedEmail = _normalizeEmail(email);
    await _client.from(accountTable).delete().eq('email', normalizedEmail);
  }

  Future<String> uploadCv({
    required String email,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final normalizedEmail = _normalizeEmail(email);
    final objectPath = '$normalizedEmail/${_sanitizeFileName(fileName)}';

    await _client.storage.from(cvBucket).uploadBinary(
          objectPath,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: _contentTypeFor(fileName),
          ),
        );

    return objectPath;
  }

  String _normalizeEmail(String email) => email.trim().toLowerCase();

  String _sanitizeFileName(String fileName) {
    final trimmed = fileName.trim();
    final sanitized = trimmed.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return sanitized.isEmpty ? 'resume.pdf' : sanitized;
  }

  String _contentTypeFor(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) {
      return 'application/pdf';
    }
    if (lower.endsWith('.doc')) {
      return 'application/msword';
    }
    if (lower.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    return 'application/octet-stream';
  }
}

final smartJobRemoteSyncProvider = Provider<SmartJobRemoteSync?>(
  (ref) => null,
);
