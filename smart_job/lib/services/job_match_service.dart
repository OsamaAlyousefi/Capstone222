import 'dart:ui';

import '../domain/models/job.dart';
import '../domain/models/profile.dart';
import '../theme/app_colors.dart';

class JobMatchResult {
  const JobMatchResult({
    required this.percentage,
    required this.label,
    required this.color,
    required this.matchedSkills,
    required this.missingSkills,
    required this.skillsScore,
    required this.titleScore,
    required this.locationScore,
    required this.experienceScore,
  });

  final int percentage;
  final String label;
  final Color color;
  final List<String> matchedSkills;
  final List<String> missingSkills;
  final double skillsScore;
  final double titleScore;
  final double locationScore;
  final double experienceScore;

  bool get shouldShow => percentage >= 20;

  static const empty = JobMatchResult(
    percentage: 0,
    label: '',
    color: Color(0x00000000),
    matchedSkills: [],
    missingSkills: [],
    skillsScore: 0,
    titleScore: 0,
    locationScore: 0,
    experienceScore: 0,
  );
}

class JobMatchService {
  static const _softSkills = {
    'communication',
    'teamwork',
    'leadership',
    'problem solving',
    'time management',
    'organization',
    'critical thinking',
    'adaptability',
    'creativity',
    'collaboration',
    'interpersonal',
    'management',
    'planning',
    'analytical',
    'detail oriented',
  };

  /// Whether the user has enough CV data to calculate match scores.
  static bool hasProfileData(UserProfile profile) {
    return profile.skills.isNotEmpty ||
        profile.experience.isNotEmpty ||
        profile.headline.isNotEmpty;
  }

  /// Calculates match percentage for a single job against the user's profile.
  /// Pure local computation — no API calls, no async.
  static JobMatchResult calculate(UserProfile profile, Job job) {
    if (!hasProfileData(profile)) return JobMatchResult.empty;

    final jobText =
        '${job.title} ${job.description} ${job.skills.join(' ')}'.toLowerCase();
    final jobTitle = job.title.toLowerCase();

    // Track active factor count for weight redistribution
    var totalWeight = 0.0;
    var totalScore = 0.0;

    // ── Factor 1: Skills Match (weight 50) ──────────────────────
    final matchedSkills = <String>[];
    final missingSkills = <String>[];
    double skillsRaw = 0;

    if (profile.skills.isNotEmpty) {
      double matchCount = 0;
      for (final skill in profile.skills) {
        final lower = skill.toLowerCase().trim();
        if (lower.isEmpty) continue;
        if (jobText.contains(lower)) {
          matchedSkills.add(skill);
          matchCount += _softSkills.contains(lower) ? 0.5 : 1.0;
        } else {
          missingSkills.add(skill);
        }
      }
      final effectiveTotal = profile.skills.where((s) => s.trim().isNotEmpty).length.toDouble();
      if (effectiveTotal > 0) {
        skillsRaw = (matchCount / effectiveTotal).clamp(0.0, 1.0);
      }
      totalWeight += 50;
      totalScore += skillsRaw * 50;
    }

    // ── Factor 2: Job Title Match (weight 25) ───────────────────
    double titleRaw = 0;
    final userTitleWords = <String>{};

    if (profile.headline.isNotEmpty) {
      userTitleWords.addAll(_extractKeywords(profile.headline));
    }
    for (final role in profile.jobPreferences.targetRoles) {
      userTitleWords.addAll(_extractKeywords(role));
    }
    for (final exp in profile.experience) {
      // Extract first part before "at" (the job title)
      final atIndex = exp.toLowerCase().indexOf(' at ');
      final titlePart = atIndex > 0 ? exp.substring(0, atIndex) : exp;
      userTitleWords.addAll(_extractKeywords(titlePart));
    }

    if (userTitleWords.isNotEmpty) {
      final jobTitleWords = _extractKeywords(job.title);
      var matched = 0;
      for (final word in userTitleWords) {
        if (jobTitleWords.contains(word) || jobTitle.contains(word)) {
          matched++;
        }
      }
      titleRaw = (matched / userTitleWords.length).clamp(0.0, 1.0);
      totalWeight += 25;
      totalScore += titleRaw * 25;
    }

    // ── Factor 3: Location Match (weight 15) ────────────────────
    double locationRaw = 0;

    if (profile.location.isNotEmpty ||
        profile.jobPreferences.preferredLocations.isNotEmpty) {
      final userLocations = <String>[
        if (profile.location.isNotEmpty) profile.location.toLowerCase(),
        ...profile.jobPreferences.preferredLocations
            .map((l) => l.toLowerCase()),
      ];
      final jobLocation = job.location.toLowerCase();

      if (job.workMode == WorkMode.remote) {
        locationRaw = 0.8; // Remote is generally a good match
      } else {
        for (final loc in userLocations) {
          if (jobLocation == loc || jobLocation.contains(loc) || loc.contains(jobLocation)) {
            locationRaw = 1.0;
            break;
          }
          // Partial match: same country/region
          if (_sameRegion(loc, jobLocation)) {
            locationRaw = 0.67;
          }
        }
      }
      totalWeight += 15;
      totalScore += locationRaw * 15;
    } else {
      // No location set — give neutral score
      totalWeight += 15;
      totalScore += 8;
    }

    // ── Factor 4: Experience Level Match (weight 10) ─────────────
    double experienceRaw = 0;
    final userLevel = _estimateUserLevel(profile.experience.length);
    final jobLevel = _detectJobLevel(jobText);

    if (jobLevel != null) {
      final diff = (userLevel - jobLevel).abs();
      experienceRaw = switch (diff) {
        0 => 1.0,
        1 => 0.5,
        _ => 0.2,
      };
    } else {
      experienceRaw = 0.7; // Job doesn't specify — neutral
    }
    totalWeight += 10;
    totalScore += experienceRaw * 10;

    // ── Final Score ──────────────────────────────────────────────
    final percentage =
        totalWeight > 0 ? ((totalScore / totalWeight) * 100).round() : 0;
    final clamped = percentage.clamp(0, 100);

    return JobMatchResult(
      percentage: clamped,
      label: _labelFor(clamped),
      color: _colorFor(clamped),
      matchedSkills: matchedSkills,
      missingSkills: missingSkills,
      skillsScore: skillsRaw,
      titleScore: titleRaw,
      locationScore: locationRaw,
      experienceScore: experienceRaw,
    );
  }

  // ── Helpers ──────────────────────────────────────────────────

  static Set<String> _extractKeywords(String text) {
    const stopWords = {
      'a', 'an', 'the', 'and', 'or', 'of', 'in', 'at', 'to', 'for',
      'is', 'on', 'with', 'by', 'as', '&', '-', '/', '|',
    };
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 1 && !stopWords.contains(w))
        .toSet();
  }

  static bool _sameRegion(String a, String b) {
    const uaeTerms = ['uae', 'dubai', 'abu dhabi', 'sharjah', 'ajman', 'united arab emirates'];
    final aIsUae = uaeTerms.any((t) => a.contains(t));
    final bIsUae = uaeTerms.any((t) => b.contains(t));
    if (aIsUae && bIsUae) return true;

    const ukTerms = ['uk', 'london', 'united kingdom', 'england'];
    final aIsUk = ukTerms.any((t) => a.contains(t));
    final bIsUk = ukTerms.any((t) => b.contains(t));
    if (aIsUk && bIsUk) return true;

    return false;
  }

  /// Maps experience count to a numeric level: 0=entry, 1=mid, 2=senior
  static int _estimateUserLevel(int experienceCount) {
    if (experienceCount <= 0) return 0;
    if (experienceCount <= 2) return 1;
    return 2;
  }

  /// Detects job level from text. Returns 0=entry, 1=mid, 2=senior, null=unspecified
  static int? _detectJobLevel(String text) {
    if (RegExp(r'\b(senior|lead|principal|manager|head|director)\b').hasMatch(text)) return 2;
    if (RegExp(r'\b(mid|intermediate|experienced)\b').hasMatch(text)) return 1;
    if (RegExp(r'\b(junior|entry|intern|graduate|fresh|trainee)\b').hasMatch(text)) return 0;
    return null;
  }

  static String _labelFor(int pct) {
    if (pct >= 80) return 'Excellent match';
    if (pct >= 60) return 'Strong match';
    if (pct >= 40) return 'Good match';
    if (pct >= 20) return 'Fair match';
    return '';
  }

  static Color _colorFor(int pct) {
    if (pct >= 80) return AppColors.success;
    if (pct >= 60) return AppColors.info;
    if (pct >= 40) return AppColors.warning;
    return AppColors.darkSubtext;
  }
}
