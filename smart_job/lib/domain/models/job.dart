enum WorkMode { remote, hybrid, onsite }

enum JobType { fullTime, contract, internship, partTime }

enum ExperienceLevel { internship, junior, mid, senior, lead }

enum JobFeedback { none, interested, notInterested }

class Job {
  const Job({
    required this.id,
    required this.title,
    required this.companyName,
    required this.location,
    required this.source,
    required this.salary,
    required this.aiSummary,
    required this.description,
    required this.skills,
    required this.tags,
    required this.workMode,
    required this.jobType,
    required this.experienceLevel,
    required this.logoLabel,
    required this.postedLabel,
    required this.matchScore,
    this.isSaved = false,
    this.feedback = JobFeedback.none,
    this.hasEasyApply = true,
    this.applyUrl = '',
  });

  final String id;
  final String title;
  final String companyName;
  final String location;
  final String source;
  final String salary;
  final String aiSummary;
  final String description;
  final List<String> skills;
  final List<String> tags;
  final WorkMode workMode;
  final JobType jobType;
  final ExperienceLevel experienceLevel;
  final String logoLabel;
  final String postedLabel;
  final double matchScore;
  final bool isSaved;
  final JobFeedback feedback;
  final bool hasEasyApply;
  final String applyUrl;

  Job copyWith({
    String? id,
    String? title,
    String? companyName,
    String? location,
    String? source,
    String? salary,
    String? aiSummary,
    String? description,
    List<String>? skills,
    List<String>? tags,
    WorkMode? workMode,
    JobType? jobType,
    ExperienceLevel? experienceLevel,
    String? logoLabel,
    String? postedLabel,
    double? matchScore,
    bool? isSaved,
    JobFeedback? feedback,
    bool? hasEasyApply,
    String? applyUrl,
  }) {
    return Job(
      id: id ?? this.id,
      title: title ?? this.title,
      companyName: companyName ?? this.companyName,
      location: location ?? this.location,
      source: source ?? this.source,
      salary: salary ?? this.salary,
      aiSummary: aiSummary ?? this.aiSummary,
      description: description ?? this.description,
      skills: skills ?? this.skills,
      tags: tags ?? this.tags,
      workMode: workMode ?? this.workMode,
      jobType: jobType ?? this.jobType,
      experienceLevel: experienceLevel ?? this.experienceLevel,
      logoLabel: logoLabel ?? this.logoLabel,
      postedLabel: postedLabel ?? this.postedLabel,
      matchScore: matchScore ?? this.matchScore,
      isSaved: isSaved ?? this.isSaved,
      feedback: feedback ?? this.feedback,
      hasEasyApply: hasEasyApply ?? this.hasEasyApply,
      applyUrl: applyUrl ?? this.applyUrl,
    );
  }
}
