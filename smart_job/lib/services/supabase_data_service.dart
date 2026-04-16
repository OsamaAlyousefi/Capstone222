import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models/application.dart';
import '../domain/models/job.dart';
import '../domain/models/message.dart';
import '../domain/models/profile.dart';

class SupabaseDataService {
  static final SupabaseClient _client = Supabase.instance.client;

  static Future<UserProfile?> fetchProfile(UserProfile fallback) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return null;
    }

    final row = await _client.from('profiles').select().eq('id', userId).maybeSingle();
    if (row == null) {
      return null;
    }

    final profile = Map<String, dynamic>.from(row);
    final cvUrl = _asString(profile['cv_url']);
    final storagePath = _storagePathFromPublicUrl(cvUrl);

    return fallback.copyWith(
      fullName: _pickString(profile['full_name'], fallback.fullName),
      email: _pickString(profile['email'], fallback.email).toLowerCase(),
      phoneNumber: _pickString(profile['phone'], fallback.phoneNumber),
      location: _pickString(profile['location'], fallback.location),
      headline: _pickString(profile['title'], fallback.headline),
      smartInboxAlias:
          _pickString(profile['smartjob_inbox_email'], fallback.smartInboxAlias),
      skills: _stringList(profile['skills']).isEmpty
          ? fallback.skills
          : _stringList(profile['skills']),
      linkedInUrl: _pickString(profile['linkedin_url'], fallback.linkedInUrl),
      portfolioUrl: _pickString(profile['github_url'], fallback.portfolioUrl),
      websiteUrl: _pickString(profile['website_url'], fallback.websiteUrl),
      hasUploadedCv: cvUrl.isNotEmpty || fallback.hasUploadedCv,
      jobPreferences: fallback.jobPreferences.copyWith(
        targetRoles: _stringList(profile['desired_roles']).isEmpty
            ? fallback.jobPreferences.targetRoles
            : _stringList(profile['desired_roles']),
        preferredLocations: _stringList(profile['preferred_locations']).isEmpty
            ? fallback.jobPreferences.preferredLocations
            : _stringList(profile['preferred_locations']),
        preferredJobTypes: _jobTypes(profile['employment_types']).isEmpty
            ? fallback.jobPreferences.preferredJobTypes
            : _jobTypes(profile['employment_types']),
        preferredWorkModes: _workModes(profile['work_modes']).isEmpty
            ? fallback.jobPreferences.preferredWorkModes
            : _workModes(profile['work_modes']),
        wantsNotifications: profile['push_alerts_enabled'] as bool? ??
            fallback.jobPreferences.wantsNotifications,
        emailFrequency: _alertFrequency(profile['alert_frequency']) ??
            fallback.jobPreferences.emailFrequency,
        pushNotificationsEnabled: profile['push_alerts_enabled'] as bool? ??
            fallback.jobPreferences.pushNotificationsEnabled,
        emailNotificationsEnabled: profile['email_alerts_enabled'] as bool? ??
            fallback.jobPreferences.emailNotificationsEnabled,
      ),
      cvInsight: fallback.cvInsight.copyWith(
        fileName: storagePath.isEmpty
            ? fallback.cvInsight.fileName
            : storagePath.split('/').last,
        completionScore:
            profile['cv_completeness'] as int? ?? fallback.cvInsight.completionScore,
        atsScore: profile['cv_ats_score'] as int? ?? fallback.cvInsight.atsScore,
        keywordMatchScore: profile['cv_alignment_score'] as int? ??
            fallback.cvInsight.keywordMatchScore,
        remoteStoragePath: storagePath.isEmpty
            ? fallback.cvInsight.remoteStoragePath
            : storagePath,
        uploadedCvMimeType: cvUrl.toLowerCase().endsWith('.pdf')
            ? 'application/pdf'
            : fallback.cvInsight.uploadedCvMimeType,
        lastEditedAtIso: _pickString(
          profile['updated_at'],
          fallback.cvInsight.lastEditedAtIso,
        ),
      ),
    );
  }

  static Future<void> updateProfileWorkspace({
    required String fullName,
    required String headline,
    required String phoneNumber,
    required String location,
    required String linkedInUrl,
    required String portfolioUrl,
    required String websiteUrl,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Not logged in');
    }

    await _client.from('profiles').update({
      'full_name': fullName,
      'title': headline,
      'phone': phoneNumber,
      'location': location,
      'linkedin_url': linkedInUrl,
      'github_url': portfolioUrl,
      'website_url': websiteUrl,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', userId);
  }

  static Future<void> updateJobPreferences({
    required List<String> targetRoles,
    required List<JobType> preferredJobTypes,
    required List<WorkMode> preferredWorkModes,
    required List<String> preferredLocations,
    required AlertFrequency emailFrequency,
    required bool pushNotificationsEnabled,
    required bool emailNotificationsEnabled,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Not logged in');
    }

    await _client.from('profiles').update({
      'desired_roles': targetRoles,
      'employment_types':
          preferredJobTypes.map((type) => _jobTypeName(type)).toList(),
      'work_modes':
          preferredWorkModes.map((mode) => _workModeName(mode)).toList(),
      'preferred_locations': preferredLocations,
      'alert_frequency': _alertFrequencyName(emailFrequency),
      'push_alerts_enabled': pushNotificationsEnabled,
      'email_alerts_enabled': emailNotificationsEnabled,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', userId);
  }

  static Future<List<Job>> fetchJobs() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return const [];
    }

    final jobRows = await _client
        .from('jobs')
        .select()
        .eq('is_active', true)
        .order('posted_at', ascending: false);
    final interactionRows = await _client
        .from('user_job_interactions')
        .select()
        .eq('user_id', userId);

    final interactionsByJobId = {
      for (final row in interactionRows)
        row['job_id']?.toString() ?? '': Map<String, dynamic>.from(row),
    };

    return jobRows.map<Job>((row) {
      final job = Map<String, dynamic>.from(row);
      final interaction = interactionsByJobId[job['id']?.toString() ?? ''] ?? const {};
      final action = _asString(interaction['action']).toLowerCase();
      final matchScore = interaction['match_score'] is num
          ? ((interaction['match_score'] as num).toDouble() / 100).clamp(0.0, 1.0)
          : 0.72;

      return Job(
        id: job['id'].toString(),
        title: _pickString(job['title'], 'Untitled role'),
        companyName: _pickString(job['company'], 'Unknown company'),
        location: _pickString(job['location'], 'Location not listed'),
        source: _pickString(job['source'], 'SmartJob'),
        salary: _salaryLabel(job),
        aiSummary: _buildAiSummary(job),
        description: _pickString(
          job['description'],
          'No detailed description is available for this role yet.',
        ),
        skills: _stringList(job['required_skills']),
        tags: [
          if (_asString(job['work_mode']).isNotEmpty) _asString(job['work_mode']),
          if (_asString(job['employment_type']).isNotEmpty)
            _asString(job['employment_type']),
        ],
        workMode: _workModeFromValue(job['work_mode']) ?? WorkMode.remote,
        jobType: _jobTypeFromValue(job['employment_type']) ?? JobType.fullTime,
        experienceLevel: _experienceLevelForJob(job),
        logoLabel: _initials(_asString(job['company'])),
        postedLabel: _relativeDateLabel(job['posted_at'] ?? job['fetched_at']),
        matchScore: matchScore,
        isSaved: action == 'saved',
        feedback: action == 'interested'
            ? JobFeedback.interested
            : action == 'not_interested'
                ? JobFeedback.notInterested
                : JobFeedback.none,
        hasEasyApply: job['is_easy_apply'] as bool? ?? false,
      );
    }).toList();
  }

  static Future<void> saveJobInteraction(Job job, String action) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return;
    }

    await _client.from('user_job_interactions').upsert({
      'user_id': userId,
      'job_id': job.id,
      'action': action,
      'match_score': (job.matchScore * 100).round(),
      'match_label': '${(job.matchScore * 100).round()}% match',
      'match_reason': 'Updated from SmartJob mobile app',
    });
  }

  static Future<List<JobApplication>> fetchApplications() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return const [];
    }

    final rows = await _client
        .from('applications')
        .select(
          'id, job_id, status, applied_at, updated_at, notes, source, jobs(title, company, location)',
        )
        .eq('user_id', userId)
        .order('applied_at', ascending: false);

    return rows.map<JobApplication>((row) {
      final application = Map<String, dynamic>.from(row);
      final job = application['jobs'] is Map
          ? Map<String, dynamic>.from(application['jobs'] as Map)
          : const <String, dynamic>{};
      final status = _applicationStatus(application['status']);
      final appliedAt = application['applied_at'];

      return JobApplication(
        id: application['id'].toString(),
        jobId: application['job_id'].toString(),
        role: _pickString(job['title'], 'Application'),
        company: _pickString(job['company'], 'Unknown company'),
        location: _pickString(job['location'], 'Location not listed'),
        status: status,
        source: _pickString(application['source'], 'SmartJob'),
        logoLabel: _initials(_asString(job['company'])),
        appliedLabel: _relativeDateLabel(appliedAt, prefix: 'Applied '),
        note: _pickString(application['notes'], _applicationNote(status)),
        timeline: _applicationTimeline(status, appliedAt, application['updated_at']),
      );
    }).toList();
  }

  static Future<bool> applyToJob(Job job) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Not logged in');
    }

    // Mock/seed jobs have non-UUID IDs (e.g. "job_1"). The applications table
    // expects a UUID for job_id, so skip the remote insert and treat it as a
    // successful local-only application.
    if (!_isValidUuid(job.id)) {
      return true;
    }

    final existing = await _client
        .from('applications')
        .select('id')
        .eq('user_id', userId)
        .eq('job_id', job.id)
        .maybeSingle();
    if (existing != null) {
      return false;
    }

    await _client.from('applications').insert({
      'user_id': userId,
      'job_id': job.id,
      'status': 'pending',
      'notes': 'Submitted from SmartJob mobile Easy Apply.',
      'source': 'easy_apply',
    });

    return true;
  }

  static bool _isValidUuid(String value) {
    return RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    ).hasMatch(value);
  }

  static Future<List<InboxMessage>> fetchInboxMessages() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return const [];
    }

    final rows = await _client
        .from('inbox_messages')
        .select()
        .eq('user_id', userId)
        .order('received_at', ascending: false);

    return rows.map<InboxMessage>((row) {
      final message = Map<String, dynamic>.from(row);
      final senderName = _pickString(message['sender_name'], 'Recruiter');
      final senderEmail = _asString(message['sender_email']);
      final type = _messageType(message['category']);

      return InboxMessage(
        id: message['id'].toString(),
        senderName: senderName,
        senderCompany: _senderCompany(senderName, senderEmail),
        subject: _pickString(message['subject'], 'Recruiter update'),
        preview: _previewText(_asString(message['body'])),
        body: _pickString(message['body'], 'No message body is available.'),
        timeLabel: _relativeDateLabel(message['received_at']),
        type: type,
        applicationId: _asString(message['application_id']),
        isUnread: !(message['is_read'] as bool? ?? false),
        isImportant:
            type == MessageType.interview || type == MessageType.offer,
      );
    }).toList();
  }

  static Future<void> markMessageRead(String messageId) async {
    await _client
        .from('inbox_messages')
        .update({'is_read': true})
        .eq('id', messageId);
  }

  static Future<String?> fetchCvUrl() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return null;
    }

    final row = await _client
        .from('profiles')
        .select('cv_url')
        .eq('id', userId)
        .maybeSingle();
    if (row == null) {
      return null;
    }

    final cvUrl = _asString(row['cv_url']);
    return cvUrl.isEmpty ? null : cvUrl;
  }

  /// Downloads the CV PDF bytes directly from Supabase Storage.
  /// Returns null if the file doesn't exist or can't be fetched.
  static Future<List<int>?> fetchCvBytes(String storagePath) async {
    if (storagePath.isEmpty) {
      return null;
    }
    try {
      final bytes = await _client.storage.from('cvs').download(storagePath);
      return bytes.isEmpty ? null : bytes;
    } catch (_) {
      return null;
    }
  }

  static List<String> _stringList(dynamic value) {
    return (value as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList();
  }

  static String _pickString(dynamic value, String fallback) {
    final normalized = _asString(value);
    return normalized.isEmpty ? fallback : normalized;
  }

  static String _asString(dynamic value) => value?.toString().trim() ?? '';

  static String _storagePathFromPublicUrl(String url) {
    if (url.isEmpty) {
      return '';
    }

    const marker = '/storage/v1/object/public/cvs/';
    final index = url.indexOf(marker);
    if (index == -1) {
      return '';
    }

    return Uri.decodeFull(url.substring(index + marker.length));
  }

  static List<JobType> _jobTypes(dynamic value) {
    return _stringList(value)
        .map(_jobTypeFromValue)
        .whereType<JobType>()
        .toList();
  }

  static List<WorkMode> _workModes(dynamic value) {
    return _stringList(value)
        .map(_workModeFromValue)
        .whereType<WorkMode>()
        .toList();
  }

  static JobType? _jobTypeFromValue(dynamic value) {
    switch (_asString(value).toLowerCase().replaceAll('_', '').replaceAll('-', '')) {
      case 'fulltime':
        return JobType.fullTime;
      case 'contract':
        return JobType.contract;
      case 'internship':
        return JobType.internship;
      case 'parttime':
        return JobType.partTime;
      default:
        return null;
    }
  }

  static String _jobTypeName(JobType value) {
    return switch (value) {
      JobType.fullTime => 'full_time',
      JobType.contract => 'contract',
      JobType.internship => 'internship',
      JobType.partTime => 'part_time',
    };
  }

  static WorkMode? _workModeFromValue(dynamic value) {
    switch (_asString(value)
        .toLowerCase()
        .replaceAll('_', '')
        .replaceAll('-', '')
        .replaceAll(' ', '')) {
      case 'remote':
        return WorkMode.remote;
      case 'hybrid':
        return WorkMode.hybrid;
      case 'onsite':
        return WorkMode.onsite;
      default:
        return null;
    }
  }

  static String _workModeName(WorkMode value) {
    return switch (value) {
      WorkMode.remote => 'remote',
      WorkMode.hybrid => 'hybrid',
      WorkMode.onsite => 'onsite',
    };
  }

  static AlertFrequency? _alertFrequency(dynamic value) {
    switch (_asString(value).toLowerCase()) {
      case 'instant':
        return AlertFrequency.instant;
      case 'weekly':
        return AlertFrequency.weekly;
      case 'daily':
        return AlertFrequency.daily;
      default:
        return null;
    }
  }

  static String _alertFrequencyName(AlertFrequency value) {
    return switch (value) {
      AlertFrequency.instant => 'Instant',
      AlertFrequency.daily => 'Daily',
      AlertFrequency.weekly => 'Weekly',
    };
  }

  static ApplicationStatus _applicationStatus(dynamic value) {
    switch (_asString(value).toLowerCase()) {
      case 'saved':
        return ApplicationStatus.saved;
      case 'interview':
        return ApplicationStatus.interview;
      case 'accepted':
      case 'offer':
        return ApplicationStatus.accepted;
      case 'rejected':
        return ApplicationStatus.rejected;
      default:
        return ApplicationStatus.pending;
    }
  }

  static MessageType _messageType(dynamic value) {
    switch (_asString(value).toLowerCase()) {
      case 'interview':
        return MessageType.interview;
      case 'offer':
        return MessageType.offer;
      case 'rejection':
        return MessageType.rejection;
      case 'follow_up':
      case 'followup':
        return MessageType.followUp;
      default:
        return MessageType.update;
    }
  }

  static ExperienceLevel _experienceLevelForJob(Map<String, dynamic> job) {
    final title = _asString(job['title']).toLowerCase();
    if (title.contains('intern')) {
      return ExperienceLevel.internship;
    }
    if (title.contains('senior') || title.contains('lead')) {
      return ExperienceLevel.senior;
    }
    if (title.contains('junior')) {
      return ExperienceLevel.junior;
    }
    return ExperienceLevel.mid;
  }

  static String _salaryLabel(Map<String, dynamic> job) {
    final currency =
        _asString(job['salary_currency']).isEmpty ? 'AED' : _asString(job['salary_currency']);
    final min = job['salary_min'];
    final max = job['salary_max'];
    if (min is num && max is num) {
      return '$currency ${min.round()}-${max.round()}';
    }
    if (min is num) {
      return '$currency ${min.round()}+';
    }
    if (max is num) {
      return 'Up to $currency ${max.round()}';
    }
    return 'Compensation not listed';
  }

  static String _buildAiSummary(Map<String, dynamic> job) {
    final description = _asString(job['description']);
    if (description.isNotEmpty) {
      return description.length > 110
          ? '${description.substring(0, 107)}...'
          : description;
    }
    return '${_pickString(job['title'], 'This role')} is available in SmartJob.';
  }

  static String _initials(String value) {
    final parts = value
        .split(RegExp(r'\s+'))
        .where((part) => part.trim().isNotEmpty)
        .take(2)
        .toList();
    if (parts.isEmpty) {
      return 'SJ';
    }

    return parts.map((part) => part[0].toUpperCase()).join();
  }

  static String _senderCompany(String senderName, String senderEmail) {
    if (senderEmail.contains('@')) {
      final domain = senderEmail.split('@').last.split('.').first;
      if (domain.isNotEmpty) {
        return domain[0].toUpperCase() + domain.substring(1);
      }
    }

    final parts = senderName.split(' ');
    return parts.length > 1 ? parts.last : 'SmartJob';
  }

  static String _previewText(String value) {
    final singleLine = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (singleLine.isEmpty) {
      return 'No preview available.';
    }
    return singleLine.length > 120 ? '${singleLine.substring(0, 117)}...' : singleLine;
  }

  static String _relativeDateLabel(
    dynamic value, {
    String prefix = '',
  }) {
    final parsed = value == null ? null : DateTime.tryParse(value.toString());
    if (parsed == null) {
      return prefix.isEmpty ? 'Recently' : '${prefix}recently';
    }

    final difference = DateTime.now().toUtc().difference(parsed.toUtc());
    if (difference.inMinutes < 1) {
      return prefix.isEmpty ? 'Just now' : '${prefix}just now';
    }
    if (difference.inHours < 1) {
      return prefix.isEmpty
          ? '${difference.inMinutes}m ago'
          : '$prefix${difference.inMinutes}m ago';
    }
    if (difference.inDays < 1) {
      return prefix.isEmpty
          ? '${difference.inHours}h ago'
          : '$prefix${difference.inHours}h ago';
    }
    if (difference.inDays == 1) {
      return prefix.isEmpty ? 'Yesterday' : '${prefix}yesterday';
    }
    return prefix.isEmpty
        ? '${difference.inDays}d ago'
        : '$prefix${difference.inDays}d ago';
  }

  static String _applicationNote(ApplicationStatus status) {
    return switch (status) {
      ApplicationStatus.saved => 'Saved for later in SmartJob.',
      ApplicationStatus.pending => 'Your application is waiting for recruiter review.',
      ApplicationStatus.interview => 'Interview steps are in progress.',
      ApplicationStatus.accepted => 'Offer details are available in your inbox.',
      ApplicationStatus.rejected => 'This application was closed by the hiring team.',
    };
  }

  static List<ApplicationTimelineEvent> _applicationTimeline(
    ApplicationStatus status,
    dynamic appliedAt,
    dynamic updatedAt,
  ) {
    return [
      ApplicationTimelineEvent(
        label: 'Application sent',
        caption: 'Submitted through SmartJob.',
        dateLabel: _relativeDateLabel(appliedAt),
        isComplete: true,
      ),
      ApplicationTimelineEvent(
        label: _timelineLabel(status),
        caption: _applicationNote(status),
        dateLabel: _relativeDateLabel(updatedAt),
        isComplete: status != ApplicationStatus.pending,
      ),
    ];
  }

  static String _timelineLabel(ApplicationStatus status) {
    return switch (status) {
      ApplicationStatus.saved => 'Saved in tracker',
      ApplicationStatus.pending => 'Awaiting recruiter update',
      ApplicationStatus.interview => 'Interview stage',
      ApplicationStatus.accepted => 'Offer received',
      ApplicationStatus.rejected => 'Application closed',
    };
  }
}
