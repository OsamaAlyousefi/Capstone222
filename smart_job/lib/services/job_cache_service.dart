import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../domain/models/job.dart';

/// Caches job search results in Hive to preserve free API quotas.
/// Cache entries expire after 30 minutes.
class JobCacheService {
  static const _boxName = 'jobCache';
  static const _ttlMs = 30 * 60 * 1000; // 30 minutes
  static Box? _box;

  static Future<void> init() async {
    try {
      // initFlutter() sets up the correct storage path for all platforms.
      await Hive.initFlutter();
      _box = await Hive.openBox(_boxName);
      clearExpired();
    } catch (e) {
      // Non-fatal — app works without cache, just makes more API calls.
      debugPrint('[JobCache] Init failed: $e');
    }
  }

  /// Returns a cache key for the given search params.
  static String key({
    required String query,
    required String location,
    required bool remoteOnly,
    required int page,
  }) {
    return '${query.toLowerCase().trim()}|${location.toLowerCase().trim()}|$remoteOnly|$page';
  }

  /// Returns cached jobs if the entry exists and is less than 30 min old.
  static List<Job>? get(String cacheKey) {
    final box = _box;
    if (box == null) return null;

    final raw = box.get(cacheKey);
    if (raw == null || raw is! Map) return null;

    final timestamp = raw['timestamp'] as int? ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - timestamp > _ttlMs) {
      box.delete(cacheKey);
      return null;
    }

    final jobMaps = raw['jobs'] as List<dynamic>? ?? [];
    try {
      return jobMaps
          .cast<Map<dynamic, dynamic>>()
          .map(_jobFromMap)
          .toList();
    } catch (e) {
      debugPrint('[JobCache] Parse error: $e');
      box.delete(cacheKey);
      return null;
    }
  }

  /// Saves jobs to cache with the current timestamp.
  static Future<void> set(String cacheKey, List<Job> jobs) async {
    final box = _box;
    if (box == null) return;

    await box.put(cacheKey, {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'jobs': jobs.map(_jobToMap).toList(),
    });
  }

  /// Removes all expired cache entries.
  static void clearExpired() {
    final box = _box;
    if (box == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final expired = <dynamic>[];
    for (final key in box.keys) {
      final raw = box.get(key);
      if (raw is Map) {
        final timestamp = raw['timestamp'] as int? ?? 0;
        if (now - timestamp > _ttlMs) {
          expired.add(key);
        }
      }
    }
    for (final key in expired) {
      box.delete(key);
    }
    if (expired.isNotEmpty) {
      debugPrint('[JobCache] Cleared ${expired.length} expired entries');
    }
  }

  // ── Serialization ─────────────────────────────────────────────────

  static Map<String, dynamic> _jobToMap(Job job) {
    return {
      'id': job.id,
      'title': job.title,
      'companyName': job.companyName,
      'location': job.location,
      'source': job.source,
      'salary': job.salary,
      'aiSummary': job.aiSummary,
      'description': job.description,
      'skills': job.skills,
      'tags': job.tags,
      'workMode': job.workMode.index,
      'jobType': job.jobType.index,
      'experienceLevel': job.experienceLevel.index,
      'logoLabel': job.logoLabel,
      'postedLabel': job.postedLabel,
      'matchScore': job.matchScore,
      'hasEasyApply': job.hasEasyApply,
      'applyUrl': job.applyUrl,
    };
  }

  static Job _jobFromMap(Map<dynamic, dynamic> map) {
    return Job(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      companyName: map['companyName']?.toString() ?? '',
      location: map['location']?.toString() ?? '',
      source: map['source']?.toString() ?? '',
      salary: map['salary']?.toString() ?? 'Not listed',
      aiSummary: map['aiSummary']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      skills: (map['skills'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      tags: (map['tags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      workMode: WorkMode.values.elementAtOrNull(map['workMode'] as int? ?? 0) ??
          WorkMode.onsite,
      jobType:
          JobType.values.elementAtOrNull(map['jobType'] as int? ?? 0) ??
              JobType.fullTime,
      experienceLevel: ExperienceLevel.values
              .elementAtOrNull(map['experienceLevel'] as int? ?? 2) ??
          ExperienceLevel.mid,
      logoLabel: map['logoLabel']?.toString() ?? 'SJ',
      postedLabel: map['postedLabel']?.toString() ?? 'Recently',
      matchScore: (map['matchScore'] as num?)?.toDouble() ?? 0.7,
      hasEasyApply: map['hasEasyApply'] as bool? ?? false,
      applyUrl: map['applyUrl']?.toString() ?? '',
    );
  }
}
