import 'package:flutter/material.dart';

import 'package:smart_job/data/mock/mock_smart_job_repository.dart';
import 'package:smart_job/data/repositories/smart_job_repository.dart';
import 'package:smart_job/domain/models/profile.dart';

class InMemorySmartJobRepository implements SmartJobRepository {
  final MockSmartJobRepository _seedRepository = const MockSmartJobRepository();
  final Map<String, SmartJobAccountData> _accounts = <String, SmartJobAccountData>{};
  String? _sessionEmail;

  @override
  SmartJobAccountData initialAccount({ThemeMode themeMode = ThemeMode.system}) {
    final profile = _seedRepository.initialProfile().copyWith(themeMode: themeMode);
    return SmartJobAccountData(
      profile: profile,
      jobs: _seedRepository.jobs(),
      applications: _seedRepository.applications(),
      messages: _seedRepository.messages(),
    );
  }

  @override
  SmartJobAccountData loadOrCreateAccount({
    required String email,
    String? fullName,
    ThemeMode? themeMode,
  }) {
    final normalizedEmail = _normalizeEmail(email);
    final existing = _accounts[normalizedEmail];
    if (existing != null) {
      return existing;
    }

    final created = _newAccountData(
      email: normalizedEmail,
      fullName: fullName,
      themeMode: themeMode,
    );
    saveAccount(created);
    return created;
  }

  @override
  SmartJobAccountData createAccount({
    required String fullName,
    required String email,
    ThemeMode? themeMode,
  }) {
    final created = _newAccountData(
      email: _normalizeEmail(email),
      fullName: fullName,
      themeMode: themeMode,
    );
    saveAccount(created);
    return created;
  }

  @override
  void saveAccount(SmartJobAccountData account, {String? previousEmail}) {
    if (previousEmail != null) {
      final normalizedPreviousEmail = _normalizeEmail(previousEmail);
      final normalizedCurrentEmail = _normalizeEmail(account.profile.email);
      if (normalizedPreviousEmail != normalizedCurrentEmail) {
        _accounts.remove(normalizedPreviousEmail);
      }
    }
    _accounts[_normalizeEmail(account.profile.email)] = account;
  }

  @override
  void deleteAccount(String email) {
    final normalizedEmail = _normalizeEmail(email);
    _accounts.remove(normalizedEmail);
    if (_sessionEmail == normalizedEmail) {
      _sessionEmail = null;
    }
  }

  @override
  String? currentSessionEmail() => _sessionEmail;

  @override
  void saveCurrentSessionEmail(String email) {
    _sessionEmail = _normalizeEmail(email);
  }

  @override
  void clearCurrentSession() {
    _sessionEmail = null;
  }

  SmartJobAccountData _newAccountData({
    required String email,
    String? fullName,
    ThemeMode? themeMode,
  }) {
    final resolvedName =
        fullName != null && fullName.trim().isNotEmpty ? fullName.trim() : _nameFromEmail(email);

    final profile = _seedRepository.initialProfile().copyWith(
          fullName: resolvedName,
          email: email,
          phoneNumber: '',
          location: '',
          headline: 'Build a student-ready CV and job search system.',
          tagline: 'SmartJob candidate workspace',
          photoLabel: _initialsFromName(resolvedName),
          smartInboxAlias: '${email.split('@').first}@inbox.smartjob.app',
          hasCompletedOnboarding: false,
          hasUploadedCv: false,
          skills: const [],
          education: const [],
          experience: const [],
          certifications: const [],
          projects: const [],
          languages: const [],
          links: const [],
          awards: const [],
          volunteerWork: const [],
          interests: const [],
          linkedInUrl: '',
          portfolioUrl: '',
          websiteUrl: '',
          themeMode: themeMode ?? ThemeMode.system,
          cvInsight: const CvInsight(
            fileName: 'SmartJob_CV_Draft.pdf',
            lastUpdatedLabel: 'Draft ready to build',
            completionScore: 18,
            atsScore: 54,
            keywordMatchScore: 42,
            missingSections: ['Experience', 'Projects', 'Skills'],
            improvementTips: [
              'Start with your strongest project and add the tools you used.',
              'Turn coursework into proof of impact with outcomes and metrics.',
              'Add links to GitHub, LinkedIn, or a portfolio for faster shortlisting.',
            ],
            missingKeywords: ['State management', 'REST APIs', 'User testing'],
            highlightedStrengths: [
              'Student-friendly builder',
              'Structured profile guidance',
              'ATS scoring support',
            ],
            selectedTemplate: 'Classic Black & White Professional',
            parsedSummary:
                'Your SmartJob CV draft is ready. Add sections to improve ATS strength and recruiter trust.',
            remoteStoragePath: '',
            uploadedCvBase64: '',
            uploadedCvMimeType: '',
            accentColorHex: '#5D8CC3',
            fontFamily: 'Inter',
            sectionOrder: defaultCvSectionOrder,
            lastEditedAtIso: '',
          ),
          publicProfileEnabled: true,
          hideContactInfo: false,
        );

    return SmartJobAccountData(
      profile: profile,
      jobs: _seedRepository.jobs(),
      applications: const [],
      messages: const [],
    );
  }

  String _normalizeEmail(String email) => email.trim().toLowerCase();

  String _nameFromEmail(String email) {
    final localPart = email.split('@').first.replaceAll(RegExp(r'[._-]+'), ' ');
    return localPart
        .split(' ')
        .where((part) => part.trim().isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
        .join(' ');
  }

  String _initialsFromName(String value) {
    final parts = value.split(' ').where((part) => part.trim().isNotEmpty).take(2);
    return parts.map((part) => part[0].toUpperCase()).join();
  }
}



