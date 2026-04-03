import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/application.dart';
import '../../domain/models/job.dart';
import '../../domain/models/message.dart';
import '../../domain/models/profile.dart';

class SmartJobAccountData {
  const SmartJobAccountData({
    required this.profile,
    required this.jobs,
    required this.applications,
    required this.messages,
  });

  final UserProfile profile;
  final List<Job> jobs;
  final List<JobApplication> applications;
  final List<InboxMessage> messages;

  SmartJobAccountData copyWith({
    UserProfile? profile,
    List<Job>? jobs,
    List<JobApplication>? applications,
    List<InboxMessage>? messages,
  }) {
    return SmartJobAccountData(
      profile: profile ?? this.profile,
      jobs: jobs ?? this.jobs,
      applications: applications ?? this.applications,
      messages: messages ?? this.messages,
    );
  }
}

abstract class SmartJobRepository {
  SmartJobAccountData initialAccount({ThemeMode themeMode = ThemeMode.system});

  SmartJobAccountData loadOrCreateAccount({
    required String email,
    String? fullName,
    ThemeMode? themeMode,
  });

  SmartJobAccountData createAccount({
    required String fullName,
    required String email,
    ThemeMode? themeMode,
  });

  void saveAccount(
    SmartJobAccountData account, {
    String? previousEmail,
  });

  void deleteAccount(String email);

  String? currentSessionEmail();

  void saveCurrentSessionEmail(String email);

  void clearCurrentSession();
}

final smartJobRepositoryProvider = Provider<SmartJobRepository>(
  (ref) => throw UnimplementedError('SmartJobRepository override missing'),
);
