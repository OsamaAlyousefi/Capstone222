enum ApplicationStatus { saved, pending, interview, accepted, rejected }

class ApplicationTimelineEvent {
  const ApplicationTimelineEvent({
    required this.label,
    required this.caption,
    required this.dateLabel,
    required this.isComplete,
  });

  final String label;
  final String caption;
  final String dateLabel;
  final bool isComplete;
}

class JobApplication {
  const JobApplication({
    required this.id,
    required this.jobId,
    required this.role,
    required this.company,
    required this.location,
    required this.status,
    required this.source,
    required this.logoLabel,
    required this.appliedLabel,
    required this.note,
    required this.timeline,
  });

  final String id;
  final String jobId;
  final String role;
  final String company;
  final String location;
  final ApplicationStatus status;
  final String source;
  final String logoLabel;
  final String appliedLabel;
  final String note;
  final List<ApplicationTimelineEvent> timeline;

  JobApplication copyWith({
    String? id,
    String? jobId,
    String? role,
    String? company,
    String? location,
    ApplicationStatus? status,
    String? source,
    String? logoLabel,
    String? appliedLabel,
    String? note,
    List<ApplicationTimelineEvent>? timeline,
  }) {
    return JobApplication(
      id: id ?? this.id,
      jobId: jobId ?? this.jobId,
      role: role ?? this.role,
      company: company ?? this.company,
      location: location ?? this.location,
      status: status ?? this.status,
      source: source ?? this.source,
      logoLabel: logoLabel ?? this.logoLabel,
      appliedLabel: appliedLabel ?? this.appliedLabel,
      note: note ?? this.note,
      timeline: timeline ?? this.timeline,
    );
  }
}
