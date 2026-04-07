import 'package:flutter/material.dart';

import 'job.dart';

const List<String> defaultCvSectionOrder = [
  'summary',
  'skills',
  'experience',
  'education',
  'projects',
];

class CvInsight {
  const CvInsight({
    required this.fileName,
    required this.lastUpdatedLabel,
    required this.completionScore,
    required this.atsScore,
    required this.keywordMatchScore,
    required this.missingSections,
    required this.improvementTips,
    required this.missingKeywords,
    required this.highlightedStrengths,
    required this.selectedTemplate,
    required this.parsedSummary,
    required this.remoteStoragePath,
    required this.uploadedCvBase64,
    required this.uploadedCvMimeType,
    required this.accentColorHex,
    required this.fontFamily,
    required this.sectionOrder,
    required this.lastEditedAtIso,
  });

  final String fileName;
  final String lastUpdatedLabel;
  final int completionScore;
  final int atsScore;
  final int keywordMatchScore;
  final List<String> missingSections;
  final List<String> improvementTips;
  final List<String> missingKeywords;
  final List<String> highlightedStrengths;
  final String selectedTemplate;
  final String parsedSummary;
  final String remoteStoragePath;
  final String uploadedCvBase64;
  final String uploadedCvMimeType;
  final String accentColorHex;
  final String fontFamily;
  final List<String> sectionOrder;
  final String lastEditedAtIso;

  bool get hasUploadedPreview => uploadedCvBase64.isNotEmpty;

  CvInsight copyWith({
    String? fileName,
    String? lastUpdatedLabel,
    int? completionScore,
    int? atsScore,
    int? keywordMatchScore,
    List<String>? missingSections,
    List<String>? improvementTips,
    List<String>? missingKeywords,
    List<String>? highlightedStrengths,
    String? selectedTemplate,
    String? parsedSummary,
    String? remoteStoragePath,
    String? uploadedCvBase64,
    String? uploadedCvMimeType,
    String? accentColorHex,
    String? fontFamily,
    List<String>? sectionOrder,
    String? lastEditedAtIso,
  }) {
    return CvInsight(
      fileName: fileName ?? this.fileName,
      lastUpdatedLabel: lastUpdatedLabel ?? this.lastUpdatedLabel,
      completionScore: completionScore ?? this.completionScore,
      atsScore: atsScore ?? this.atsScore,
      keywordMatchScore: keywordMatchScore ?? this.keywordMatchScore,
      missingSections: missingSections ?? this.missingSections,
      improvementTips: improvementTips ?? this.improvementTips,
      missingKeywords: missingKeywords ?? this.missingKeywords,
      highlightedStrengths: highlightedStrengths ?? this.highlightedStrengths,
      selectedTemplate: selectedTemplate ?? this.selectedTemplate,
      parsedSummary: parsedSummary ?? this.parsedSummary,
      remoteStoragePath: remoteStoragePath ?? this.remoteStoragePath,
      uploadedCvBase64: uploadedCvBase64 ?? this.uploadedCvBase64,
      uploadedCvMimeType: uploadedCvMimeType ?? this.uploadedCvMimeType,
      accentColorHex: accentColorHex ?? this.accentColorHex,
      fontFamily: fontFamily ?? this.fontFamily,
      sectionOrder: sectionOrder ?? this.sectionOrder,
      lastEditedAtIso: lastEditedAtIso ?? this.lastEditedAtIso,
    );
  }
}

enum CvCollectionSection {
  education,
  experience,
  projects,
  skills,
  certifications,
  languages,
  links,
  awards,
  volunteerWork,
  interests,
}

extension CvCollectionSectionX on CvCollectionSection {
  String get label {
    return switch (this) {
      CvCollectionSection.education => 'Education',
      CvCollectionSection.experience => 'Experience',
      CvCollectionSection.projects => 'Projects',
      CvCollectionSection.skills => 'Skills',
      CvCollectionSection.certifications => 'Certifications',
      CvCollectionSection.languages => 'Languages',
      CvCollectionSection.links => 'Links and portfolio',
      CvCollectionSection.awards => 'Awards and achievements',
      CvCollectionSection.volunteerWork => 'Volunteer work',
      CvCollectionSection.interests => 'Interests',
    };
  }

  bool get supportsChipInput {
    return switch (this) {
      CvCollectionSection.skills ||
      CvCollectionSection.languages ||
      CvCollectionSection.interests =>
        true,
      _ => false,
    };
  }
}

enum AlertFrequency { instant, daily, weekly }

class JobPreferences {
  const JobPreferences({
    required this.targetRoles,
    required this.preferredLocations,
    required this.preferredWorkModes,
    required this.preferredJobTypes,
    required this.preferredLevels,
    required this.salaryRange,
    required this.salaryExpectation,
    required this.wantsNotifications,
    required this.emailFrequency,
    required this.pushNotificationsEnabled,
    required this.emailNotificationsEnabled,
    required this.hasWorkAuthorization,
    required this.openToRelocation,
  });

  final List<String> targetRoles;
  final List<String> preferredLocations;
  final List<WorkMode> preferredWorkModes;
  final List<JobType> preferredJobTypes;
  final List<ExperienceLevel> preferredLevels;
  final String salaryRange;
  final int salaryExpectation;
  final bool wantsNotifications;
  final AlertFrequency emailFrequency;
  final bool pushNotificationsEnabled;
  final bool emailNotificationsEnabled;
  final bool hasWorkAuthorization;
  final bool openToRelocation;

  JobPreferences copyWith({
    List<String>? targetRoles,
    List<String>? preferredLocations,
    List<WorkMode>? preferredWorkModes,
    List<JobType>? preferredJobTypes,
    List<ExperienceLevel>? preferredLevels,
    String? salaryRange,
    int? salaryExpectation,
    bool? wantsNotifications,
    AlertFrequency? emailFrequency,
    bool? pushNotificationsEnabled,
    bool? emailNotificationsEnabled,
    bool? hasWorkAuthorization,
    bool? openToRelocation,
  }) {
    return JobPreferences(
      targetRoles: targetRoles ?? this.targetRoles,
      preferredLocations: preferredLocations ?? this.preferredLocations,
      preferredWorkModes: preferredWorkModes ?? this.preferredWorkModes,
      preferredJobTypes: preferredJobTypes ?? this.preferredJobTypes,
      preferredLevels: preferredLevels ?? this.preferredLevels,
      salaryRange: salaryRange ?? this.salaryRange,
      salaryExpectation: salaryExpectation ?? this.salaryExpectation,
      wantsNotifications: wantsNotifications ?? this.wantsNotifications,
      emailFrequency: emailFrequency ?? this.emailFrequency,
      pushNotificationsEnabled:
          pushNotificationsEnabled ?? this.pushNotificationsEnabled,
      emailNotificationsEnabled:
          emailNotificationsEnabled ?? this.emailNotificationsEnabled,
      hasWorkAuthorization:
          hasWorkAuthorization ?? this.hasWorkAuthorization,
      openToRelocation: openToRelocation ?? this.openToRelocation,
    );
  }
}

class UserProfile {
  const UserProfile({
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.location,
    required this.headline,
    required this.tagline,
    required this.photoLabel,
    required this.smartInboxAlias,
    required this.hasCompletedOnboarding,
    required this.hasUploadedCv,
    required this.skills,
    required this.education,
    required this.experience,
    required this.certifications,
    required this.projects,
    required this.languages,
    required this.links,
    required this.awards,
    required this.volunteerWork,
    required this.interests,
    required this.linkedInUrl,
    required this.portfolioUrl,
    required this.websiteUrl,
    required this.jobPreferences,
    required this.cvInsight,
    required this.themeMode,
    required this.notificationsEnabled,
    required this.privacyModeEnabled,
    required this.publicProfileEnabled,
    required this.hideContactInfo,
  });

  final String fullName;
  final String email;
  final String phoneNumber;
  final String location;
  final String headline;
  final String tagline;
  final String photoLabel;
  final String smartInboxAlias;
  final bool hasCompletedOnboarding;
  final bool hasUploadedCv;
  final List<String> skills;
  final List<String> education;
  final List<String> experience;
  final List<String> certifications;
  final List<String> projects;
  final List<String> languages;
  final List<String> links;
  final List<String> awards;
  final List<String> volunteerWork;
  final List<String> interests;
  final String linkedInUrl;
  final String portfolioUrl;
  final String websiteUrl;
  final JobPreferences jobPreferences;
  final CvInsight cvInsight;
  final ThemeMode themeMode;
  final bool notificationsEnabled;
  final bool privacyModeEnabled;
  final bool publicProfileEnabled;
  final bool hideContactInfo;

  String get firstName {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) {
      return 'there';
    }
    return trimmed.split(RegExp(r'\s+')).first;
  }

  bool get hasCvDraft {
    return skills.isNotEmpty ||
        education.isNotEmpty ||
        experience.isNotEmpty ||
        projects.isNotEmpty ||
        certifications.isNotEmpty ||
        awards.isNotEmpty ||
        volunteerWork.isNotEmpty ||
        links.isNotEmpty;
  }

  List<String> entriesFor(CvCollectionSection section) {
    return switch (section) {
      CvCollectionSection.education => education,
      CvCollectionSection.experience => experience,
      CvCollectionSection.projects => projects,
      CvCollectionSection.skills => skills,
      CvCollectionSection.certifications => certifications,
      CvCollectionSection.languages => languages,
      CvCollectionSection.links => links,
      CvCollectionSection.awards => awards,
      CvCollectionSection.volunteerWork => volunteerWork,
      CvCollectionSection.interests => interests,
    };
  }

  UserProfile copyWithSection(
    CvCollectionSection section,
    List<String> entries,
  ) {
    return switch (section) {
      CvCollectionSection.education => copyWith(education: entries),
      CvCollectionSection.experience => copyWith(experience: entries),
      CvCollectionSection.projects => copyWith(projects: entries),
      CvCollectionSection.skills => copyWith(skills: entries),
      CvCollectionSection.certifications => copyWith(certifications: entries),
      CvCollectionSection.languages => copyWith(languages: entries),
      CvCollectionSection.links => copyWith(links: entries),
      CvCollectionSection.awards => copyWith(awards: entries),
      CvCollectionSection.volunteerWork => copyWith(volunteerWork: entries),
      CvCollectionSection.interests => copyWith(interests: entries),
    };
  }

  UserProfile copyWith({
    String? fullName,
    String? email,
    String? phoneNumber,
    String? location,
    String? headline,
    String? tagline,
    String? photoLabel,
    String? smartInboxAlias,
    bool? hasCompletedOnboarding,
    bool? hasUploadedCv,
    List<String>? skills,
    List<String>? education,
    List<String>? experience,
    List<String>? certifications,
    List<String>? projects,
    List<String>? languages,
    List<String>? links,
    List<String>? awards,
    List<String>? volunteerWork,
    List<String>? interests,
    String? linkedInUrl,
    String? portfolioUrl,
    String? websiteUrl,
    JobPreferences? jobPreferences,
    CvInsight? cvInsight,
    ThemeMode? themeMode,
    bool? notificationsEnabled,
    bool? privacyModeEnabled,
    bool? publicProfileEnabled,
    bool? hideContactInfo,
  }) {
    return UserProfile(
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      location: location ?? this.location,
      headline: headline ?? this.headline,
      tagline: tagline ?? this.tagline,
      photoLabel: photoLabel ?? this.photoLabel,
      smartInboxAlias: smartInboxAlias ?? this.smartInboxAlias,
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      hasUploadedCv: hasUploadedCv ?? this.hasUploadedCv,
      skills: skills ?? this.skills,
      education: education ?? this.education,
      experience: experience ?? this.experience,
      certifications: certifications ?? this.certifications,
      projects: projects ?? this.projects,
      languages: languages ?? this.languages,
      links: links ?? this.links,
      awards: awards ?? this.awards,
      volunteerWork: volunteerWork ?? this.volunteerWork,
      interests: interests ?? this.interests,
      linkedInUrl: linkedInUrl ?? this.linkedInUrl,
      portfolioUrl: portfolioUrl ?? this.portfolioUrl,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      jobPreferences: jobPreferences ?? this.jobPreferences,
      cvInsight: cvInsight ?? this.cvInsight,
      themeMode: themeMode ?? this.themeMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      privacyModeEnabled: privacyModeEnabled ?? this.privacyModeEnabled,
      publicProfileEnabled: publicProfileEnabled ?? this.publicProfileEnabled,
      hideContactInfo: hideContactInfo ?? this.hideContactInfo,
    );
  }
}
