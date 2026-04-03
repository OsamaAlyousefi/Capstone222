import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../domain/models/profile.dart';

enum CvTemplateLayout {
  classic,
  minimal,
  creative,
  compact,
  techSidebar,
  executive,
}

class CvTemplateOption {
  const CvTemplateOption({
    required this.title,
    required this.caption,
    required this.layout,
    required this.background,
    required this.headerBackground,
    required this.sectionBackground,
    required this.chipBackground,
    required this.previewCanvas,
    required this.previewAccent,
    required this.previewBar,
    required this.borderColor,
    required this.textColor,
    required this.defaultAccentColor,
    required this.defaultFontFamily,
  });

  final String title;
  final String caption;
  final CvTemplateLayout layout;
  final Color background;
  final Color headerBackground;
  final Color sectionBackground;
  final Color chipBackground;
  final Color previewCanvas;
  final Color previewAccent;
  final Color previewBar;
  final Color borderColor;
  final Color textColor;
  final Color defaultAccentColor;
  final String defaultFontFamily;
}

class CvSectionConfig {
  const CvSectionConfig({
    required this.title,
    required this.subtitle,
    required this.suggestion,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.fieldLabel,
    required this.placeholder,
    required this.editorHint,
    required this.icon,
    this.maxLines = 4,
  });

  final String title;
  final String subtitle;
  final String suggestion;
  final String emptyTitle;
  final String emptyMessage;
  final String fieldLabel;
  final String placeholder;
  final String editorHint;
  final IconData icon;
  final int maxLines;
}

const List<CvCollectionSection> orderedCvSections = [
  CvCollectionSection.education,
  CvCollectionSection.experience,
  CvCollectionSection.projects,
  CvCollectionSection.certifications,
  CvCollectionSection.languages,
  CvCollectionSection.links,
  CvCollectionSection.awards,
  CvCollectionSection.volunteerWork,
  CvCollectionSection.interests,
];

const List<CvCollectionSection> requiredCvSections = [
  CvCollectionSection.education,
  CvCollectionSection.experience,
  CvCollectionSection.projects,
  CvCollectionSection.skills,
  CvCollectionSection.certifications,
  CvCollectionSection.languages,
  CvCollectionSection.links,
  CvCollectionSection.awards,
  CvCollectionSection.volunteerWork,
];

const Map<CvCollectionSection, CvSectionConfig> cvSectionConfigs = {
  CvCollectionSection.education: CvSectionConfig(
    title: 'Education',
    subtitle: 'Add degrees, diplomas, bootcamps, or standout coursework.',
    suggestion:
        'Mention school, program, graduation year, and one signal of excellence like GPA, honors, or capstone focus.',
    emptyTitle: 'No education entries yet',
    emptyMessage:
        'Add your latest degree or academic program to ground your profile quickly.',
    fieldLabel: 'Education entry',
    placeholder:
        'BSc in Computer Science / University / 2026 / GPA / Capstone focus',
    editorHint: 'Use one entry per degree, bootcamp, or academic milestone.',
    icon: LucideIcons.graduationCap,
  ),
  CvCollectionSection.experience: CvSectionConfig(
    title: 'Experience',
    subtitle:
        'Turn internships, freelance work, clubs, or part-time roles into clear achievements.',
    suggestion:
        'Lead with the role, tools used, and what changed because of your work. Numbers help a lot here.',
    emptyTitle: 'No experience entries yet',
    emptyMessage:
        'Add internships, campus work, freelance projects, or leadership roles to build credibility.',
    fieldLabel: 'Experience entry',
    placeholder:
        'Role / Company / Date range / What you built / Result or metric',
    editorHint: 'Keep each experience block outcome-focused and easy to scan.',
    icon: LucideIcons.briefcase,
    maxLines: 5,
  ),
  CvCollectionSection.projects: CvSectionConfig(
    title: 'Projects',
    subtitle: 'Show proof of work with product, engineering, or design examples.',
    suggestion:
        'Projects are especially valuable for students. Explain the problem, your role, and the result.',
    emptyTitle: 'No projects added yet',
    emptyMessage:
        'Add one strong academic, freelance, or personal project to strengthen the CV fast.',
    fieldLabel: 'Project entry',
    placeholder: 'Project / Role / Stack / What shipped / Link or impact',
    editorHint: 'Treat each project like proof of initiative and execution.',
    icon: LucideIcons.folderKanban,
    maxLines: 5,
  ),
  CvCollectionSection.certifications: CvSectionConfig(
    title: 'Certifications',
    subtitle: 'Add certificates that support the kind of roles you want.',
    suggestion:
        'Mention the issuer and focus area so recruiters immediately understand relevance.',
    emptyTitle: 'No certifications listed yet',
    emptyMessage:
        'Add any role-relevant certifications, courses, or verified programs.',
    fieldLabel: 'Certification entry',
    placeholder: 'Certificate / Issuer / Year / Credential link',
    editorHint: 'Keep certificate entries short and verifiable.',
    icon: LucideIcons.badgeCheck,
  ),
  CvCollectionSection.languages: CvSectionConfig(
    title: 'Languages',
    subtitle: 'Highlight spoken languages or language proficiency.',
    suggestion:
        'Include native, fluent, or conversational labels if they help recruiters understand your range.',
    emptyTitle: 'No languages added yet',
    emptyMessage: 'Add any languages you speak to broaden your profile.',
    fieldLabel: 'Languages',
    placeholder: 'English, Arabic, French',
    editorHint: 'Separate multiple values with commas.',
    icon: LucideIcons.languages,
    maxLines: 2,
  ),
  CvCollectionSection.links: CvSectionConfig(
    title: 'Links and portfolio',
    subtitle: 'Link your LinkedIn, GitHub, Behance, Dribbble, or personal site.',
    suggestion:
        'Even one strong link can lift trust quickly. Prioritize the place that best proves your work.',
    emptyTitle: 'No links added yet',
    emptyMessage:
        'Add portfolio or profile links so recruiters can verify your work beyond the PDF.',
    fieldLabel: 'Link entry',
    placeholder: 'LinkedIn / GitHub / Portfolio URL / Behance project',
    editorHint: 'Add one destination per card so links stay easy to manage.',
    icon: LucideIcons.link,
    maxLines: 3,
  ),
  CvCollectionSection.awards: CvSectionConfig(
    title: 'Awards and achievements',
    subtitle:
        'Show recognitions, scholarships, competition wins, or standout milestones.',
    suggestion:
        'Students often underestimate this section. Awards are strong proof when experience is still growing.',
    emptyTitle: 'No awards added yet',
    emptyMessage:
        'Add scholarships, dean list honors, competitions, or standout achievements.',
    fieldLabel: 'Award entry',
    placeholder: 'Award / Organization / Date / Why it mattered',
    editorHint: 'Keep it concise but specific enough to show the signal.',
    icon: LucideIcons.trophy,
  ),
  CvCollectionSection.volunteerWork: CvSectionConfig(
    title: 'Volunteer work',
    subtitle:
        'Capture community impact, leadership, and initiative outside paid roles.',
    suggestion:
        'Volunteer work strengthens trust and shows initiative, especially for early-career candidates.',
    emptyTitle: 'No volunteer work added yet',
    emptyMessage:
        'Add mentoring, community work, event organizing, or nonprofit contributions.',
    fieldLabel: 'Volunteer entry',
    placeholder: 'Role / Organization / What you contributed / Outcome',
    editorHint: 'Frame volunteer work like real experience with outcomes and scope.',
    icon: LucideIcons.heartHandshake,
    maxLines: 4,
  ),
  CvCollectionSection.interests: CvSectionConfig(
    title: 'Interests',
    subtitle: 'Optional, but useful when the interests feel specific and human.',
    suggestion:
        'Choose a few interests that make you memorable without feeling generic.',
    emptyTitle: 'No interests added yet',
    emptyMessage:
        'Add a few interests if they support your story or help you feel more human on paper.',
    fieldLabel: 'Interests',
    placeholder: 'Hackathons, editorial design, mentoring',
    editorHint: 'Separate multiple values with commas.',
    icon: LucideIcons.sparkles,
    maxLines: 2,
  ),
};

const List<CvTemplateOption> cvTemplateOptions = [
  CvTemplateOption(
    title: 'Classic Black & White Professional',
    caption: 'Structured, timeless, ATS-friendly',
    layout: CvTemplateLayout.classic,
    background: Color(0xFFF8F8F5),
    headerBackground: Colors.white,
    sectionBackground: Color(0xFFF0F0EA),
    chipBackground: Color(0xFFE7E7DE),
    previewCanvas: Colors.white,
    previewAccent: Color(0xFF1F1F1F),
    previewBar: Color(0xFFD9D9D2),
    borderColor: Color(0xFFD9D7CF),
    textColor: Color(0xFF151515),
    defaultAccentColor: Color(0xFF1F1F1F),
    defaultFontFamily: 'Inter',
  ),
  CvTemplateOption(
    title: 'Modern Minimal',
    caption: 'Quiet spacing and crisp hierarchy',
    layout: CvTemplateLayout.minimal,
    background: Color(0xFFF5F7FA),
    headerBackground: Color(0xFFFFFFFF),
    sectionBackground: Color(0xFFEAF0F6),
    chipBackground: Color(0xFFDDE7F1),
    previewCanvas: Color(0xFFFFFFFF),
    previewAccent: Color(0xFF3B5C7A),
    previewBar: Color(0xFFD6E3EF),
    borderColor: Color(0xFFD9E1E8),
    textColor: Color(0xFF173042),
    defaultAccentColor: Color(0xFF3B5C7A),
    defaultFontFamily: 'Poppins',
  ),
  CvTemplateOption(
    title: 'Creative Soft Accent',
    caption: 'Warm editorial feel with gentle accents',
    layout: CvTemplateLayout.creative,
    background: Color(0xFFFBF5EE),
    headerBackground: Color(0xFFFFFBF7),
    sectionBackground: Color(0xFFF5EADF),
    chipBackground: Color(0xFFF0DDC9),
    previewCanvas: Color(0xFFFFFBF7),
    previewAccent: Color(0xFFC97666),
    previewBar: Color(0xFFEFD7CF),
    borderColor: Color(0xFFE5D4C6),
    textColor: Color(0xFF463026),
    defaultAccentColor: Color(0xFFC97666),
    defaultFontFamily: 'Playfair Display',
  ),
  CvTemplateOption(
    title: 'Compact One-Page',
    caption: 'Dense, concise, optimized for speed',
    layout: CvTemplateLayout.compact,
    background: Color(0xFFF4F5F0),
    headerBackground: Color(0xFFFBFBF8),
    sectionBackground: Color(0xFFE8ECDF),
    chipBackground: Color(0xFFDBE3CF),
    previewCanvas: Color(0xFFFBFBF8),
    previewAccent: Color(0xFF58724E),
    previewBar: Color(0xFFD7E0CF),
    borderColor: Color(0xFFD9DED1),
    textColor: Color(0xFF283126),
    defaultAccentColor: Color(0xFF58724E),
    defaultFontFamily: 'Roboto',
  ),
  CvTemplateOption(
    title: 'Tech Sidebar',
    caption: 'Code-forward split layout with a bold sidebar',
    layout: CvTemplateLayout.techSidebar,
    background: Color(0xFF111B2B),
    headerBackground: Color(0xFF162334),
    sectionBackground: Color(0xFF1A2B40),
    chipBackground: Color(0xFF223550),
    previewCanvas: Color(0xFF172638),
    previewAccent: Color(0xFF5D8CC3),
    previewBar: Color(0xFF2B415F),
    borderColor: Color(0xFF29415A),
    textColor: Color(0xFFF4F7FA),
    defaultAccentColor: Color(0xFF5D8CC3),
    defaultFontFamily: 'Inter',
  ),
  CvTemplateOption(
    title: 'Executive Elegant',
    caption: 'Refined serif hierarchy for senior-looking polish',
    layout: CvTemplateLayout.executive,
    background: Color(0xFFF7F1EC),
    headerBackground: Color(0xFFFFFCFA),
    sectionBackground: Color(0xFFEEE3D8),
    chipBackground: Color(0xFFE6D6C7),
    previewCanvas: Color(0xFFFFFCFA),
    previewAccent: Color(0xFF8A6A45),
    previewBar: Color(0xFFE2D2C0),
    borderColor: Color(0xFFE7D8CB),
    textColor: Color(0xFF35261C),
    defaultAccentColor: Color(0xFF8A6A45),
    defaultFontFamily: 'Playfair Display',
  ),
];
