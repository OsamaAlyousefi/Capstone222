import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../domain/models/job.dart';

/// Holds search results plus metadata about how the results were obtained.
class JobSearchResult {
  const JobSearchResult({
    required this.jobs,
    this.isGlobalFallback = false,
  });

  final List<Job> jobs;

  /// True when no UAE-specific results were found and the results shown are
  /// from a worldwide / non-UAE search.
  final bool isGlobalFallback;
}

class _ApiResult {
  const _ApiResult(this.jobs, this.isGlobalFallback);
  final List<Job> jobs;
  final bool isGlobalFallback;
}

class JobApiService {
  static const _timeout = Duration(seconds: 30);

  /// Searches all available job APIs and returns a merged, deduplicated list.
  /// Match scores default to 0 — the controller calculates real scores
  /// using the user's profile skills.
  static Future<JobSearchResult> searchJobs({
    required String query,
    String location = '',
    bool remoteOnly = false,
    int page = 1,
  }) async {
    if (query.trim().isEmpty) return const JobSearchResult(jobs: []);

    final resolvedLocation =
        location.trim().isEmpty ? 'United Arab Emirates' : location;

    debugPrint('[JobAPI] ═══════════════════════════════════════════');
    debugPrint('[JobAPI] searchJobs START');
    debugPrint('[JobAPI]   query="$query"');
    debugPrint('[JobAPI]   location="$resolvedLocation" (original: "$location")');
    debugPrint('[JobAPI]   remoteOnly=$remoteOnly, page=$page');

    // Fire all three APIs in parallel — each catches its own errors.
    final results = await Future.wait<_ApiResult>([
      _fetchJoobleWithFallback(
          query: query, location: resolvedLocation, page: page)
        .catchError((_) => _ApiResult([], false)),
      _fetchAdzunaWithFallback(
          query: query, location: resolvedLocation, page: page)
        .catchError((_) => _ApiResult([], false)),
      _fetchRemotive(query: query)
        .then((jobs) => _ApiResult(jobs, false))
        .catchError((_) => _ApiResult([], false)),
    ]);

    final all = <Job>[];
    bool isGlobal = false;
    for (final result in results) {
      all.addAll(result.jobs);
      if (result.isGlobalFallback) isGlobal = true;
    }

    debugPrint('[JobAPI] Total raw results: ${all.length}');
    final deduped = _deduplicate(all);
    debugPrint('[JobAPI] After dedup: ${deduped.length}');

    // Sort by posted date (newest first).
    deduped.sort((a, b) => _postedOrder(a.postedLabel, b.postedLabel));

    debugPrint('[JobAPI] searchJobs END (globalFallback=$isGlobal)');
    debugPrint('[JobAPI] ═══════════════════════════════════════════');

    return JobSearchResult(jobs: deduped, isGlobalFallback: isGlobal);
  }

  // ── Jooble (with location + keyword fallback chain) ───────────────

  static Future<_ApiResult> _fetchJoobleWithFallback({
    required String query,
    required String location,
    required int page,
  }) async {
    // UAE locations to try — order matters (most specific first).
    final uaeLocations = [
      'Dubai',
      'Abu Dhabi',
      'UAE',
      'United Arab Emirates',
      'Dubai, United Arab Emirates',
    ];

    // Keywords: original query, then progressively broader.
    // Empty string = "all jobs in that location" — broadest possible.
    final keywords = [query, 'jobs', ''];

    // Phase 1: try each keyword with each UAE location.
    for (final kw in keywords) {
      for (final loc in uaeLocations) {
        final jobs = await _fetchJooble(keywords: kw, location: loc, page: page);
        if (jobs.isNotEmpty) {
          debugPrint('[JOOBLE] Got ${jobs.length} results with keywords="$kw", location="$loc"');
          return _ApiResult(jobs, false);
        }
        debugPrint('[JOOBLE] 0 results for keywords="$kw", location="$loc", trying next...');
      }
    }

    // Phase 2: Worldwide as absolute last resort.
    final globalJobs = await _fetchJooble(keywords: query, location: '', page: page);
    if (globalJobs.isNotEmpty) {
      debugPrint('[JOOBLE] Got ${globalJobs.length} GLOBAL results (no UAE jobs found)');
      return _ApiResult(globalJobs, true);
    }

    debugPrint('[JOOBLE] All fallbacks exhausted, returning empty');
    return const _ApiResult([], false);
  }

  static Future<List<Job>> _fetchJooble({
    required String keywords,
    required String location,
    required int page,
  }) async {
    final apiKey = dotenv.env['JOOBLE_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      debugPrint('[JOOBLE] API_KEY not set, skipping');
      return const [];
    }

    final url = Uri.parse('https://jooble.org/api/$apiKey');

    // NOTE: "page" must be a STRING — Jooble is picky about this.
    // No datecreatedfrom — we want ALL available jobs.
    final bodyMap = {
      'keywords': keywords,
      'location': location,
      'page': '$page',
    };
    final body = jsonEncode(bodyMap);

    try {
      debugPrint('[JOOBLE] POST body: $bodyMap');
      final response = await http
          .post(url,
              headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(_timeout);

      debugPrint('[JOOBLE] Status: ${response.statusCode}');
      debugPrint('[JOOBLE] FULL RESPONSE: ${response.body}');

      if (response.statusCode != 200) {
        return const [];
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final jobs = decoded['jobs'] as List<dynamic>? ?? [];
      final totalCount = decoded['totalCount'] ?? 'unknown';
      debugPrint('[JOOBLE] Parsed ${jobs.length} jobs (totalCount: $totalCount)');

      if (jobs.isEmpty) return const [];
      return jobs.map((j) => _fromJooble(j as Map<String, dynamic>)).toList();
    } on TimeoutException {
      debugPrint('[JOOBLE] Timed out (keywords="$keywords", location="$location")');
      return const [];
    } on http.ClientException catch (e) {
      debugPrint('[JOOBLE] Client error (likely CORS on web): $e');
      return const [];
    } catch (e) {
      debugPrint('[JOOBLE] Error: $e');
      return const [];
    }
  }

  static Job _fromJooble(Map<String, dynamic> json) {
    final title = _str(json['title']);
    final company = _str(json['company']);
    final loc = _str(json['location']);
    final snippet = _str(json['snippet']);
    final salary = _str(json['salary']);
    final type = _str(json['type']).toLowerCase();
    final link = _str(json['link']);
    final updated = _str(json['updated']);
    final id = _str(json['id']);

    return Job(
      id: 'jooble_$id',
      title: _cleanHtml(title),
      companyName: _cleanHtml(company),
      location: loc.isEmpty ? 'Not specified' : loc,
      source: 'Jooble',
      salary: salary.isEmpty ? 'Not listed' : salary,
      aiSummary: _truncate(_cleanHtml(snippet), 120),
      description: _cleanHtml(snippet),
      skills: const [],
      tags: _buildTags(type, loc),
      workMode: _parseWorkMode(loc, type),
      jobType: _parseJobType(type),
      experienceLevel: ExperienceLevel.mid,
      logoLabel: _initials(company),
      postedLabel: _relativeTime(updated),
      matchScore: 0.0,
      hasEasyApply: false,
      applyUrl: link,
    );
  }

  // ── Adzuna (skipped for UAE — only used for UK/US/EU) ─────────────

  /// Returns true if the location string refers to UAE/Dubai/Abu Dhabi.
  static bool _isUaeLocation(String location) {
    final lower = location.toLowerCase();
    return lower.contains('uae') ||
        lower.contains('dubai') ||
        lower.contains('abu dhabi') ||
        lower.contains('united arab emirates') ||
        lower.contains('sharjah') ||
        lower.contains('ajman');
  }

  static Future<_ApiResult> _fetchAdzunaWithFallback({
    required String query,
    required String location,
    required int page,
  }) async {
    // Adzuna does NOT have a UAE country code. Skip entirely for UAE searches
    // to avoid returning irrelevant UK/US jobs. Jooble covers UAE.
    if (_isUaeLocation(location)) {
      debugPrint('[ADZUNA] Skipping — location "$location" is UAE (no Adzuna coverage)');
      return const _ApiResult([], false);
    }

    final appId = dotenv.env['ADZUNA_APP_ID'];
    final appKey = dotenv.env['ADZUNA_APP_KEY'];
    if (appId == null ||
        appId.isEmpty ||
        appKey == null ||
        appKey.isEmpty) {
      debugPrint('[ADZUNA] Keys not set, skipping');
      return const _ApiResult([], false);
    }

    // Determine country from location text.
    final lower = location.toLowerCase();
    final isUk = lower.contains('uk') ||
        lower.contains('london') ||
        lower.contains('united kingdom') ||
        lower.contains('england');
    final country = isUk ? 'gb' : 'us';

    final jobs = await _fetchAdzuna(
      query: query,
      where: location,
      page: page,
      country: country,
      appId: appId,
      appKey: appKey,
    );
    if (jobs.isNotEmpty) return _ApiResult(jobs, false);

    debugPrint('[ADZUNA] No results for country=$country');
    return const _ApiResult([], false);
  }

  static Future<List<Job>> _fetchAdzuna({
    required String query,
    required String? where,
    required int page,
    required String country,
    required String appId,
    required String appKey,
    int? timeoutSeconds,
  }) async {
    final params = {
      'app_id': appId,
      'app_key': appKey,
      'what': query,
      if (where != null && where.isNotEmpty) 'where': where,
      'results_per_page': '50',
      'sort_by': 'date',
    };

    final url = Uri.parse(
      'https://api.adzuna.com/v1/api/jobs/$country/search/$page',
    ).replace(queryParameters: params);

    final timeout = Duration(seconds: timeoutSeconds ?? 30);

    try {
      debugPrint('[ADZUNA] GET: $url');
      final response = await http.get(url).timeout(timeout);

      debugPrint('[ADZUNA] Status: ${response.statusCode} (country=$country)');
      debugPrint('[ADZUNA] FULL RESPONSE: ${response.body}');

      if (response.statusCode != 200) {
        return const [];
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final results = decoded['results'] as List<dynamic>? ?? [];
      final count = decoded['count'] ?? 'unknown';
      debugPrint(
          '[ADZUNA] Parsed ${results.length} jobs (total: $count, country=$country)');
      return results
          .map((j) => _fromAdzuna(j as Map<String, dynamic>, country))
          .toList();
    } on TimeoutException {
      debugPrint('[ADZUNA] Timed out (country=$country)');
      return const [];
    } on http.ClientException catch (e) {
      // Likely CORS on web — works on Android/iOS device.
      debugPrint('[ADZUNA] Client error (likely CORS on web): $e');
      return const [];
    } catch (e) {
      debugPrint('[ADZUNA] Error (country=$country): $e');
      return const [];
    }
  }

  static Job _fromAdzuna(Map<String, dynamic> json, String country) {
    final title = _str(json['title']);
    final company =
        _str((json['company'] as Map<String, dynamic>?)?['display_name']);
    final loc =
        _str((json['location'] as Map<String, dynamic>?)?['display_name']);
    final description = _str(json['description']);
    final salaryMin = (json['salary_min'] as num?)?.toDouble();
    final salaryMax = (json['salary_max'] as num?)?.toDouble();
    final link = _str(json['redirect_url']);
    final created = _str(json['created']);
    final contractType = _str(json['contract_type']).toLowerCase();
    final id = json['id']?.toString() ?? '';

    final currencySymbol = country == 'gb' ? '\u00A3' : '\$';
    String salary = 'Not listed';
    if (salaryMin != null && salaryMax != null) {
      if (salaryMin.round() == salaryMax.round()) {
        // Same min/max — show single number.
        salary = '$currencySymbol${_formatNumber(salaryMin.round())}';
      } else {
        salary =
            '$currencySymbol${_formatNumber(salaryMin.round())}–$currencySymbol${_formatNumber(salaryMax.round())}';
      }
    } else if (salaryMin != null) {
      if (salaryMin.round() == 0) {
        salary = 'Not listed';
      } else {
        salary = 'From $currencySymbol${_formatNumber(salaryMin.round())}';
      }
    } else if (salaryMax != null) {
      if (salaryMax.round() == 0) {
        salary = 'Not listed';
      } else {
        salary = 'Up to $currencySymbol${_formatNumber(salaryMax.round())}';
      }
    }

    return Job(
      id: 'adzuna_$id',
      title: _cleanHtml(title),
      companyName: company.isEmpty ? 'Company' : _cleanHtml(company),
      location: loc.isEmpty ? 'Not specified' : loc,
      source: 'Adzuna',
      salary: salary,
      aiSummary: _truncate(_cleanHtml(description), 120),
      description: _cleanHtml(description),
      skills: const [],
      tags: _buildTags(contractType, loc),
      workMode: _parseWorkMode(loc, contractType),
      jobType: _parseJobType(contractType),
      experienceLevel: ExperienceLevel.mid,
      logoLabel: _initials(company),
      postedLabel: _relativeTime(created),
      matchScore: 0.0,
      hasEasyApply: false,
      applyUrl: link,
    );
  }

  // ── Remotive ──────────────────────────────────────────────────────

  static Future<List<Job>> _fetchRemotive({required String query}) async {
    // First try: broad fetch without keyword filter — returns more results.
    final broadUrl = Uri.parse('https://remotive.com/api/remote-jobs').replace(
      queryParameters: {'limit': '50'},
    );

    try {
      debugPrint('[REMOTIVE] Fetching broad (limit=50)...');
      final response = await http.get(broadUrl).timeout(_timeout);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final jobs = decoded['jobs'] as List<dynamic>? ?? [];
        debugPrint('[REMOTIVE] Broad fetch returned ${jobs.length} jobs');
        if (jobs.isNotEmpty) {
          return jobs
              .map((j) => _fromRemotive(j as Map<String, dynamic>))
              .toList();
        }
      } else {
        debugPrint('[REMOTIVE] Broad fetch error: ${response.statusCode}');
      }
    } on TimeoutException {
      debugPrint('[REMOTIVE] Broad fetch timed out');
    } on http.ClientException catch (e) {
      // Likely CORS on web — works on Android/iOS device.
      debugPrint('[REMOTIVE] Broad fetch client error (likely CORS): $e');
    } catch (e) {
      debugPrint('[REMOTIVE] Broad fetch error: $e');
    }

    // Second try: with keyword filter.
    try {
      final filteredUrl =
          Uri.parse('https://remotive.com/api/remote-jobs').replace(
        queryParameters: {'search': query, 'limit': '50'},
      );
      debugPrint('[REMOTIVE] Trying filtered: query="$query"');
      final response = await http.get(filteredUrl).timeout(_timeout);

      if (response.statusCode != 200) {
        debugPrint('[REMOTIVE] Filtered error: ${response.statusCode}');
        return const [];
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final jobs = decoded['jobs'] as List<dynamic>? ?? [];
      debugPrint('[REMOTIVE] Filtered returned ${jobs.length} jobs');
      return jobs
          .map((j) => _fromRemotive(j as Map<String, dynamic>))
          .toList();
    } on TimeoutException {
      debugPrint('[REMOTIVE] Filtered timed out');
      return const [];
    } on http.ClientException catch (e) {
      debugPrint('[REMOTIVE] Filtered client error (likely CORS): $e');
      return const [];
    } catch (e) {
      debugPrint('[REMOTIVE] Filtered error: $e');
      return const [];
    }
  }

  static Job _fromRemotive(Map<String, dynamic> json) {
    final title = _str(json['title']);
    final company = _str(json['company_name']);
    final loc = _str(json['candidate_required_location']);
    final description = _str(json['description']);
    final salary = _str(json['salary']);
    final type = _str(json['job_type']).toLowerCase();
    final link = _str(json['url']);
    final published = _str(json['publication_date']);
    final id = json['id']?.toString() ?? '';

    return Job(
      id: 'remotive_$id',
      title: _cleanHtml(title),
      companyName: company.isEmpty ? 'Company' : company,
      location: loc.isEmpty ? 'Remote' : loc,
      source: 'Remotive',
      salary: salary.isEmpty ? 'Not listed' : salary,
      aiSummary: _truncate(_cleanHtml(description), 120),
      description: _cleanHtml(description),
      skills: const [],
      tags: ['Remote', if (type.isNotEmpty) _capitalizeType(type)],
      workMode: WorkMode.remote,
      jobType: _parseJobType(type),
      experienceLevel: ExperienceLevel.mid,
      logoLabel: _initials(company),
      postedLabel: _relativeTime(published),
      matchScore: 0.0,
      hasEasyApply: false,
      applyUrl: link,
    );
  }

  // ── Match score ──────────────────────────────────────────────────

  /// Calculates a real skill-based match score.
  /// Formula: (user skills found in job text) / (total user skills).
  static double calculateMatchScore(Job job, List<String> userSkills) {
    if (userSkills.isEmpty) return 0.0;

    final jobText =
        '${job.title} ${job.description} ${job.aiSummary} ${job.tags.join(' ')}'
            .toLowerCase();
    int matched = 0;
    for (final skill in userSkills) {
      if (skill.trim().isEmpty) continue;
      if (jobText.contains(skill.toLowerCase())) {
        matched++;
      }
    }
    return (matched / userSkills.length).clamp(0.0, 1.0);
  }

  // ── Helpers ───────────────────────────────────────────────────────

  static String _str(dynamic value) => value?.toString().trim() ?? '';

  static String _cleanHtml(String text) {
    if (text.isEmpty) return text;
    String cleaned = text;
    // Strip HTML tags.
    cleaned = cleaned.replaceAll(RegExp(r'<[^>]*>'), ' ');
    // Decode common HTML entities.
    cleaned = cleaned.replaceAll('&nbsp;', ' ');
    cleaned = cleaned.replaceAll('&amp;', '&');
    cleaned = cleaned.replaceAll('&lt;', '<');
    cleaned = cleaned.replaceAll('&gt;', '>');
    cleaned = cleaned.replaceAll('&quot;', '"');
    cleaned = cleaned.replaceAll('&#x27;', "'");
    cleaned = cleaned.replaceAll('&#39;', "'");
    cleaned = cleaned.replaceAll('&apos;', "'");
    // Normalize whitespace (including \r\n).
    cleaned = cleaned.replaceAll(RegExp(r'\r\n|\r|\n'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');
    cleaned = cleaned.trim();
    // Strip leading/trailing ellipsis fragments.
    cleaned = cleaned.replaceAll(RegExp(r'^\.{3}|\.{3}$'), '');
    cleaned = cleaned.trim();
    return cleaned.isEmpty ? 'No description available' : cleaned;
  }

  static String _truncate(String text, int max) {
    if (text.length <= max) return text;
    return '${text.substring(0, max - 3)}...';
  }

  static String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).take(2);
    if (parts.isEmpty) return 'SJ';
    return parts.map((p) => p[0].toUpperCase()).join();
  }

  static String _formatNumber(int n) {
    return n.toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+$)'),
          (m) => '${m[1]},',
        );
  }

  static String _relativeTime(String dateStr) {
    if (dateStr.isEmpty) return 'Recently';
    final parsed = DateTime.tryParse(dateStr);
    if (parsed == null) return 'Recently';
    final diff = DateTime.now().toUtc().difference(parsed.toUtc());
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return '${(diff.inDays / 30).floor()}mo ago';
  }

  /// Sorts newest first based on the relative time label.
  static int _postedOrder(String a, String b) {
    return _postedRank(a).compareTo(_postedRank(b));
  }

  static int _postedRank(String label) {
    final lower = label.toLowerCase();
    if (lower.contains('m ago')) {
      return int.tryParse(lower.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    }
    if (lower.contains('h ago')) {
      return (int.tryParse(lower.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0) * 60;
    }
    if (lower == 'yesterday') return 1440;
    if (lower.contains('d ago')) {
      return (int.tryParse(lower.replaceAll(RegExp(r'[^0-9]'), '')) ?? 30) *
          1440;
    }
    if (lower.contains('mo ago')) {
      return (int.tryParse(lower.replaceAll(RegExp(r'[^0-9]'), '')) ?? 12) *
          43200;
    }
    return 999999; // "Recently" or unknown — sort last
  }

  static WorkMode _parseWorkMode(String location, String type) {
    final combined = '$location $type'.toLowerCase();
    if (combined.contains('remote')) return WorkMode.remote;
    if (combined.contains('hybrid')) return WorkMode.hybrid;
    return WorkMode.onsite;
  }

  static JobType _parseJobType(String type) {
    final lower = type.toLowerCase().replaceAll(RegExp(r'[_\-\s]'), '');
    if (lower.contains('fulltime') || lower.contains('permanent')) {
      return JobType.fullTime;
    }
    if (lower.contains('parttime')) return JobType.partTime;
    if (lower.contains('contract') || lower.contains('freelance')) {
      return JobType.contract;
    }
    if (lower.contains('intern')) return JobType.internship;
    return JobType.fullTime;
  }

  static List<String> _buildTags(String type, String location) {
    final tags = <String>[];
    if (location.toLowerCase().contains('remote')) tags.add('Remote');
    final jt = _capitalizeType(type);
    if (jt.isNotEmpty) tags.add(jt);
    return tags;
  }

  static String _capitalizeType(String type) {
    final lower = type.toLowerCase().replaceAll(RegExp(r'[_\-]'), ' ').trim();
    if (lower.isEmpty) return '';
    return lower
        .split(' ')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  static List<Job> _deduplicate(List<Job> jobs) {
    final seen = <String>{};
    final result = <Job>[];
    for (final job in jobs) {
      final key =
          '${job.title.toLowerCase().trim()}|${job.companyName.toLowerCase().trim()}';
      if (seen.add(key)) {
        result.add(job);
      }
    }
    return result;
  }
}
