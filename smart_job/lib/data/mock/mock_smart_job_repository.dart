import 'package:flutter/material.dart';

import '../../domain/models/application.dart';
import '../../domain/models/job.dart';
import '../../domain/models/message.dart';
import '../../domain/models/profile.dart';

class MockSmartJobRepository {
  const MockSmartJobRepository();

  static final Map<String, UserProfile> _profiles = <String, UserProfile>{};

  UserProfile initialProfile() {
    return _baseProfile();
  }

  UserProfile loadOrCreateAccount({
    required String email,
    String? fullName,
    ThemeMode? themeMode,
  }) {
    final normalizedEmail = email.trim().toLowerCase();
    final existing = _profiles[normalizedEmail];
    if (existing != null) {
      return existing;
    }

    final createdProfile = _createDraftProfile(
      email: normalizedEmail,
      fullName: fullName,
      themeMode: themeMode,
    );
    _profiles[normalizedEmail] = createdProfile;
    return createdProfile;
  }

  UserProfile createAccount({
    required String fullName,
    required String email,
    ThemeMode? themeMode,
  }) {
    final normalizedEmail = email.trim().toLowerCase();
    final createdProfile = _createDraftProfile(
      email: normalizedEmail,
      fullName: fullName,
      themeMode: themeMode,
    );
    _profiles[normalizedEmail] = createdProfile;
    return createdProfile;
  }

  void saveProfile(UserProfile profile) {
    _profiles[profile.email.trim().toLowerCase()] = profile;
  }

  void deleteProfile(String email) {
    _profiles.remove(email.trim().toLowerCase());
  }

  UserProfile _baseProfile() {
    return UserProfile(
      fullName: 'Maya Al Mansoori',
      email: 'maya@smartjob.app',
      phoneNumber: '+971 50 555 2044',
      location: 'Dubai, UAE',
      headline: 'Mobile Product Designer turning research into polished apps',
      tagline: 'Flutter Developer seeking internships',
      photoLabel: 'MA',
      smartInboxAlias: 'maya@inbox.smartjob.app',
      hasCompletedOnboarding: false,
      hasUploadedCv: false,
      skills: const [
        'Flutter',
        'Dart',
        'Firebase',
        'Figma',
        'Design Systems',
        'Product Discovery',
      ],
      education: const [
        'BSc in Computer Science, University of Sharjah',
      ],
      experience: const [
        'Built student services apps with Flutter and Firebase for 2+ years.',
        'Led a UX refresh for a campus marketplace, increasing retention by 18%.',
      ],
      certifications: const [
        'Google UX Design Certificate',
        'Firebase for Mobile Developers',
      ],
      projects: const [
        'SmartStudy planner with offline task sync and shared boards.',
        'Portfolio microsite with case studies and motion prototypes.',
      ],
      languages: const ['English', 'Arabic'],
      links: const ['linkedin.com/in/maya', 'github.com/maya-smartjob'],
      awards: const ['Dean list recognition for product systems project'],
      volunteerWork: const ['Mentored first-year students in mobile prototyping'],
      interests: const ['Human-centered AI', 'Editorial layouts', 'Mentorship'],
      linkedInUrl: 'linkedin.com/in/maya',
      portfolioUrl: 'github.com/maya-smartjob',
      websiteUrl: 'mayaalmansoori.dev',
      jobPreferences: const JobPreferences(
        targetRoles: ['Flutter Developer', 'Product Designer'],
        preferredLocations: ['Dubai', 'Remote', 'Abu Dhabi'],
        preferredWorkModes: [WorkMode.remote, WorkMode.hybrid],
        preferredJobTypes: [JobType.internship, JobType.fullTime, JobType.partTime],
        preferredLevels: [ExperienceLevel.junior, ExperienceLevel.mid],
        salaryRange: '\$4k-\$6k / month',
        salaryExpectation: 6,
        wantsNotifications: true,
        emailFrequency: AlertFrequency.daily,
        pushNotificationsEnabled: true,
        emailNotificationsEnabled: true,
        hasWorkAuthorization: true,
        openToRelocation: true,
      ),
      cvInsight: const CvInsight(
        fileName: 'No CV uploaded yet',
        lastUpdatedLabel: 'Waiting for onboarding',
        completionScore: 64,
        atsScore: 71,
        keywordMatchScore: 69,
        missingSections: ['Certifications detail', 'Impact-focused bullets'],
        improvementTips: [
          'Rewrite generic bullets into measurable outcomes with numbers.',
          'Add product metrics and user research deliverables.',
          'Mention remote collaboration tools to improve ATS relevance.',
        ],
        missingKeywords: ['A/B testing', 'API integration', 'State management'],
        highlightedStrengths: [
          'Clean portfolio storytelling',
          'Cross-functional collaboration',
          'Strong mobile UI craft',
        ],
        selectedTemplate: 'Classic',
        parsedSummary:
            'AI parsing will extract role history, skills, and achievements after upload.',
        remoteStoragePath: '',
        uploadedCvBase64: '',
        uploadedCvMimeType: '',
        accentColorHex: '#5D8CC3',
        fontFamily: 'Inter',
        sectionOrder: defaultCvSectionOrder,
        lastEditedAtIso: '',
      ),
      themeMode: ThemeMode.system,
      notificationsEnabled: true,
      privacyModeEnabled: false,
      publicProfileEnabled: true,
      hideContactInfo: false,
    );
  }

  UserProfile _createDraftProfile({
    required String email,
    String? fullName,
    ThemeMode? themeMode,
  }) {
    final resolvedName =
        (fullName != null && fullName.trim().isNotEmpty)
            ? fullName.trim()
            : _nameFromEmail(email);

    return _baseProfile().copyWith(
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
      cvInsight: const CvInsight(
        fileName: 'SmartJob_CV_Draft.pdf',
        lastUpdatedLabel: 'Draft ready to build',
        completionScore: 18,
        atsScore: 54,
        keywordMatchScore: 42,
        missingSections: [
          'Experience',
          'Projects',
          'Skills',
        ],
        improvementTips: [
          'Start with your strongest project and add the tools you used.',
          'Turn coursework into proof of impact with outcomes and metrics.',
          'Add links to GitHub, LinkedIn, or a portfolio for faster shortlisting.',
        ],
        missingKeywords: [
          'State management',
          'REST APIs',
          'User testing',
        ],
        highlightedStrengths: [
          'Student-friendly builder',
          'Structured profile guidance',
          'ATS scoring support',
        ],
        selectedTemplate: 'Classic',
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
      themeMode: themeMode ?? ThemeMode.system,
    );
  }

  String _nameFromEmail(String email) {
    final localPart = email.split('@').first.replaceAll(RegExp(r'[._-]+'), ' ');
    return localPart
        .split(' ')
        .where((part) => part.trim().isNotEmpty)
        .map(
          (part) => '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  String _initialsFromName(String value) {
    final parts =
        value.split(' ').where((part) => part.trim().isNotEmpty).take(2);
    return parts.map((part) => part[0].toUpperCase()).join();
  }

  List<Job> jobs() {
    return const [
      Job(
        id: 'job_1',
        title: 'Flutter Product Engineer',
        companyName: 'Northstar Labs',
        location: 'Remote / UAE timezone',
        source: 'LinkedIn',
        salary: '\$4,800-\$6,200 / month',
        aiSummary:
            'Excellent fit for your Flutter + product design blend. Their team wants someone who can shape UI patterns, not just ship tickets.',
        description:
            'Own a premium mobile experience for a fintech product used across the GCC. You will work with product, data, and growth teams to build a thoughtful, high-trust experience.',
        skills: ['Flutter', 'Dart', 'Design Systems', 'Firebase'],
        tags: ['Premium product', 'High ownership', 'Remote-first'],
        workMode: WorkMode.remote,
        jobType: JobType.fullTime,
        experienceLevel: ExperienceLevel.mid,
        logoLabel: 'NL',
        postedLabel: '16 min ago',
        matchScore: 0.93,
        isSaved: true,
        hasEasyApply: true,
      ),
      Job(
        id: 'job_2',
        title: 'Junior Mobile UX Engineer',
        companyName: 'Loom District',
        location: 'Dubai Internet City',
        source: 'Indeed',
        salary: '\$3,100-\$4,000 / month',
        aiSummary:
            'Strong starter role if you want heavier design exposure. The posting matches your portfolio and motion design strengths.',
        description:
            'Collaborate with product designers to implement nuanced mobile interactions, motion systems, and accessibility improvements for a consumer app.',
        skills: ['Flutter', 'Motion', 'Accessibility', 'Figma'],
        tags: ['Hybrid', 'Mentorship', 'Design-heavy'],
        workMode: WorkMode.hybrid,
        jobType: JobType.fullTime,
        experienceLevel: ExperienceLevel.junior,
        logoLabel: 'LD',
        postedLabel: '44 min ago',
        matchScore: 0.88,
        hasEasyApply: true,
      ),
      Job(
        id: 'job_3',
        title: 'Product Designer, Career Tools',
        companyName: 'Wellfound',
        location: 'Remote',
        source: 'Wellfound',
        salary: '\$4,000-\$5,100 / month',
        aiSummary:
            'High keyword overlap with your CV draft. Their JD values candidate journeys, information hierarchy, and prototype quality.',
        description:
            'Design flows for onboarding, profile building, and career marketplace discovery. Partner closely with mobile engineers and content strategists.',
        skills: ['Product Design', 'Figma', 'Research', 'Information Architecture'],
        tags: ['Career tech', 'Portfolio fit', 'Remote'],
        workMode: WorkMode.remote,
        jobType: JobType.fullTime,
        experienceLevel: ExperienceLevel.mid,
        logoLabel: 'WF',
        postedLabel: '1 h ago',
        matchScore: 0.84,
        hasEasyApply: true,
      ),
      Job(
        id: 'job_4',
        title: 'Mobile App Intern',
        companyName: 'Quartz Studio',
        location: 'Abu Dhabi',
        source: 'Bayt',
        salary: '\$1,200-\$1,700 / month',
        aiSummary:
            'Useful internship if you want to sharpen architecture fundamentals, though it is less aligned with your salary target.',
        description:
            'Support the mobile team on UI implementation, bug fixing, and analytics instrumentation across internal products.',
        skills: ['Flutter', 'Git', 'QA', 'Analytics'],
        tags: ['On-site', 'Internship', 'Fast-paced'],
        workMode: WorkMode.onsite,
        jobType: JobType.internship,
        experienceLevel: ExperienceLevel.internship,
        logoLabel: 'QS',
        postedLabel: '2 h ago',
        matchScore: 0.58,
        hasEasyApply: true,
      ),
      Job(
        id: 'job_5',
        title: 'Product Designer, Hiring Intelligence',
        companyName: 'Signal Hire',
        location: 'Hybrid / Dubai',
        source: 'LinkedIn',
        salary: '\$4,500-\$6,000 / month',
        aiSummary:
            'A well-balanced match. Your research and systems thinking line up with their AI-assisted recruiting platform.',
        description:
            'Shape recruiter workflows, candidate analytics, and trust-centered AI explanation patterns inside a hiring SaaS platform.',
        skills: ['Design Systems', 'Product Design', 'User Testing', 'AI UX'],
        tags: ['Hybrid', 'AI UX', 'Research'],
        workMode: WorkMode.hybrid,
        jobType: JobType.fullTime,
        experienceLevel: ExperienceLevel.mid,
        logoLabel: 'SH',
        postedLabel: '3 h ago',
        matchScore: 0.86,
        hasEasyApply: true,
      ),
      Job(
        id: 'job_6',
        title: 'Freelance Flutter Builder',
        companyName: 'Mint Layer',
        location: 'Remote',
        source: 'Upwork',
        salary: '\$35-\$45 / hour',
        aiSummary:
            'Good short-term contract for portfolio depth. It scores lower than full-time roles because your preferences lean toward stable team growth.',
        description:
            'Help modernize an education product, clean up visual consistency, and ship a premium onboarding flow in six weeks.',
        skills: ['Flutter', 'UI Polish', 'Animations', 'API Integration'],
        tags: ['Contract', 'Fast delivery', 'Remote'],
        workMode: WorkMode.remote,
        jobType: JobType.contract,
        experienceLevel: ExperienceLevel.mid,
        logoLabel: 'ML',
        postedLabel: 'Today',
        matchScore: 0.74,
        hasEasyApply: true,
      ),
    ];
  }

  List<JobApplication> applications() {
    return const [
      JobApplication(
        id: 'app_1',
        jobId: 'job_1',
        role: 'Flutter Product Engineer',
        company: 'Northstar Labs',
        location: 'Remote',
        status: ApplicationStatus.interview,
        source: 'LinkedIn',
        logoLabel: 'NL',
        appliedLabel: 'Applied 3 days ago',
        note: 'Portfolio shortlisting completed. Technical interview pending.',
        timeline: [
          ApplicationTimelineEvent(
            label: 'Application sent',
            caption: 'CV and portfolio delivered through Easy Apply.',
            dateLabel: 'Mar 24',
            isComplete: true,
          ),
          ApplicationTimelineEvent(
            label: 'Recruiter review',
            caption: 'Strong alignment on product thinking and UI craft.',
            dateLabel: 'Mar 25',
            isComplete: true,
          ),
          ApplicationTimelineEvent(
            label: 'Interview stage',
            caption: 'Panel interview requested for next week.',
            dateLabel: 'Mar 27',
            isComplete: true,
          ),
          ApplicationTimelineEvent(
            label: 'Offer decision',
            caption: 'Awaiting final loop and decision.',
            dateLabel: 'Pending',
            isComplete: false,
          ),
        ],
      ),
      JobApplication(
        id: 'app_2',
        jobId: 'job_2',
        role: 'Junior Mobile UX Engineer',
        company: 'Loom District',
        location: 'Dubai',
        status: ApplicationStatus.pending,
        source: 'Indeed',
        logoLabel: 'LD',
        appliedLabel: 'Applied yesterday',
        note: 'Application opened. Portfolio viewed once.',
        timeline: [
          ApplicationTimelineEvent(
            label: 'Application sent',
            caption: 'Resume submitted through SmartJob profile.',
            dateLabel: 'Mar 27',
            isComplete: true,
          ),
          ApplicationTimelineEvent(
            label: 'Awaiting response',
            caption: 'No recruiter message yet.',
            dateLabel: 'Live',
            isComplete: false,
          ),
        ],
      ),
      JobApplication(
        id: 'app_3',
        jobId: 'job_5',
        role: 'Product Designer, Hiring Intelligence',
        company: 'Signal Hire',
        location: 'Dubai',
        status: ApplicationStatus.accepted,
        source: 'LinkedIn',
        logoLabel: 'SH',
        appliedLabel: 'Applied 12 days ago',
        note: 'Offer packet shared. Awaiting your decision.',
        timeline: [
          ApplicationTimelineEvent(
            label: 'Application sent',
            caption: 'Shortlisted quickly due to portfolio quality.',
            dateLabel: 'Mar 16',
            isComplete: true,
          ),
          ApplicationTimelineEvent(
            label: 'Case study review',
            caption: 'Positive feedback on hiring intelligence concept.',
            dateLabel: 'Mar 19',
            isComplete: true,
          ),
          ApplicationTimelineEvent(
            label: 'Offer received',
            caption: 'Compensation and relocation notes attached.',
            dateLabel: 'Mar 25',
            isComplete: true,
          ),
        ],
      ),
      JobApplication(
        id: 'app_4',
        jobId: 'job_4',
        role: 'Mobile App Intern',
        company: 'Quartz Studio',
        location: 'Abu Dhabi',
        status: ApplicationStatus.rejected,
        source: 'Bayt',
        logoLabel: 'QS',
        appliedLabel: 'Applied 2 weeks ago',
        note: 'Role closed after final shortlist.',
        timeline: [
          ApplicationTimelineEvent(
            label: 'Application sent',
            caption: 'CV submitted through Bayt link.',
            dateLabel: 'Mar 11',
            isComplete: true,
          ),
          ApplicationTimelineEvent(
            label: 'Position closed',
            caption: 'The company moved forward with a different profile.',
            dateLabel: 'Mar 20',
            isComplete: true,
          ),
        ],
      ),
      JobApplication(
        id: 'app_5',
        jobId: 'job_3',
        role: 'Product Designer, Career Tools',
        company: 'Wellfound',
        location: 'Remote',
        status: ApplicationStatus.saved,
        source: 'Wellfound',
        logoLabel: 'WF',
        appliedLabel: 'Saved for later',
        note: 'Waiting for CV keyword refresh before applying.',
        timeline: [
          ApplicationTimelineEvent(
            label: 'Saved',
            caption: 'Bookmarked for a stronger CV version.',
            dateLabel: 'Today',
            isComplete: true,
          ),
        ],
      ),
    ];
  }

  List<InboxMessage> messages() {
    return const [
      InboxMessage(
        id: 'msg_1',
        senderName: 'Rina Osman',
        senderCompany: 'Northstar Labs',
        subject: 'Interview availability for Flutter Product Engineer',
        preview:
            'We loved the way your portfolio balances UX detail and build quality. Could you share your availability for a 45 minute interview?',
        body:
            'Hi Maya,\n\nWe loved the way your portfolio balances UX detail and build quality. Could you share your availability for a 45 minute interview next week?\n\nBest,\nRina',
        timeLabel: '10:42 AM',
        type: MessageType.interview,
        applicationId: 'app_1',
        isUnread: true,
        isImportant: true,
      ),
      InboxMessage(
        id: 'msg_2',
        senderName: 'Nadine Cole',
        senderCompany: 'Signal Hire',
        subject: 'Offer package and next steps',
        preview:
            'Your offer details are attached, including a learning budget and hybrid schedule.',
        body:
            'Hello Maya,\n\nYour offer details are attached, including compensation, a learning budget, and our hybrid schedule. Let us know if you would like a walkthrough call.\n\nWarmly,\nNadine',
        timeLabel: 'Yesterday',
        type: MessageType.offer,
        applicationId: 'app_3',
        isImportant: true,
      ),
      InboxMessage(
        id: 'msg_3',
        senderName: 'Amina Rahman',
        senderCompany: 'Loom District',
        subject: 'Application received',
        preview:
            'Thanks for applying. We have shared your CV with the mobile design lead for review.',
        body:
            'Hi Maya,\n\nThanks for applying. We have shared your CV with the mobile design lead for review and will be back with an update soon.\n\nRegards,\nAmina',
        timeLabel: 'Yesterday',
        type: MessageType.update,
        applicationId: 'app_2',
        isUnread: false,
      ),
      InboxMessage(
        id: 'msg_4',
        senderName: 'Karim Ibrahim',
        senderCompany: 'Quartz Studio',
        subject: 'Update on your internship application',
        preview:
            'Thank you again for your interest. We have decided to move forward with another candidate.',
        body:
            'Dear Maya,\n\nThank you again for your interest in Quartz Studio. We have decided to move forward with another candidate for this internship opening.\n\nBest wishes,\nKarim',
        timeLabel: 'Mar 20',
        type: MessageType.rejection,
        applicationId: 'app_4',
      ),
    ];
  }
}








