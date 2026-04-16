import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../application/controllers/smart_job_controller.dart';
import '../../domain/models/profile.dart';
import '../../router/app_router.dart';
import '../../services/supabase_data_service.dart';
import '../../theme/app_colors.dart';
import '../shared/widgets/smart_job_ui.dart';

class CVScreen extends ConsumerStatefulWidget {
  const CVScreen({super.key});

  @override
  ConsumerState<CVScreen> createState() => _CVScreenState();
}

class _CVScreenState extends ConsumerState<CVScreen> {
  final PdfViewerController _pdfController = PdfViewerController();

  double _zoom = 1.0;
  bool _isLoadingCv = true;
  bool _isUploadingCv = false;
  bool _isExportingPdf = false;
  bool _isExportingWord = false;
  String? _cvUrl;
  String? _cvLoadError;
  double? _uploadProgress;
  String _uploadStageLabel = 'Preparing upload...';
  // Downloaded bytes are used for SfPdfViewer.memory() which is more
  // reliable than SfPdfViewer.network() on Android (avoids platform-view
  // paint-over issues with the loading skeleton).
  Uint8List? _downloadedCvBytes;

  @override
  void initState() {
    super.initState();
    _loadCvUrl();
  }

  @override
  void dispose() {
    _pdfController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(
      smartJobControllerProvider.select((state) => state.profile),
    );
    final cv = profile.cvInsight;
    final previewData = _buildPreviewData(profile);
    final exportDocument = _buildExportDocument(previewData, cv.sectionOrder);
    final pdfBytes = _decodePreviewPdf(cv);
    final averageScore =
        ((cv.completionScore + cv.atsScore + cv.keywordMatchScore) / 3).round();
    final healthStatus = _healthStatusFor(averageScore);

    return SmartJobScrollPage(
      maxWidth: 1320,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 140),
      scrollViewKey: const PageStorageKey('cv-page-scroll'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HeaderCard(
            profile: profile,
            status: healthStatus,
            isUploading: _isUploadingCv,
            onExport: () => _showExportSheet(context, profile, exportDocument),
            onEdit: () => context.go(AppRoute.cvSetup),
            onWorkspace: () => _showWorkspaceSheet(context, profile),
          ),
          const SizedBox(height: 20),
          _HealthSummaryCard(
            averageScore: averageScore,
            status: healthStatus,
            cards: [
              _ScoreCardData(
                title: 'CV Completion',
                score: cv.completionScore,
                description:
                    'Measures how complete your summary, experience, education, and project coverage is.',
              ),
              _ScoreCardData(
                title: 'ATS Score',
                score: cv.atsScore,
                description:
                    'Measures how likely the CV is to pass automated recruiter screening.',
                onTap: () => _showAtsBreakdown(context, profile),
              ),
              _ScoreCardData(
                title: 'Keyword Match',
                score: cv.keywordMatchScore,
                description:
                    'Measures alignment between your CV language and target role keywords.',
              ),
            ],
          ),
          const SizedBox(height: 24),
          _PreviewShell(
            fileName: cv.fileName,
            zoom: _zoom,
            onZoomChanged: _handleZoomChanged,
            onExpand: pdfBytes == null
                ? null
                : () => _openFullscreenPdf(
                      context,
                      pdfBytes,
                      cv.fileName,
                    ),
            onUpload: _isUploadingCv ? null : uploadCV,
            isUploading: _isUploadingCv,
            child: _buildPreviewBody(
              context,
              profile: profile,
              cv: cv,
              pdfBytes: pdfBytes,
            ),
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final suggestions = _SuggestedKeywordsCard(
                keywords: cv.missingKeywords,
                onAdd: (keyword) => _addKeywordAndEdit(context, keyword),
              );
              final improveNext = _ImproveNextCard(
                tips: cv.improvementTips,
                onTapTip: (tip) => _openEditorForTip(context, tip),
              );

              if (constraints.maxWidth >= 980) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: suggestions),
                    const SizedBox(width: 18),
                    Expanded(child: improveNext),
                  ],
                );
              }

              return Column(
                children: [
                  suggestions,
                  const SizedBox(height: 18),
                  improveNext,
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  void _handleZoomChanged(double value) {
    setState(() => _zoom = value);
    _pdfController.zoomLevel = value;
  }

  Future<void> _loadCvUrl() async {
    try {
      final cvUrl = await SupabaseDataService.fetchCvUrl();
      if (!mounted) return;

      setState(() {
        _cvUrl = cvUrl;
        _cvLoadError = null;
      });

      // Try to download the actual bytes so we can use SfPdfViewer.memory(),
      // which is more reliable on Android than SfPdfViewer.network().
      if (cvUrl != null) {
        await _downloadCvBytes();
      } else {
        setState(() => _isLoadingCv = false);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _cvLoadError = 'Could not load your saved CV.';
        _isLoadingCv = false;
      });
    }
  }

  /// Extracts the Supabase Storage object path from the public CV URL.
  /// e.g. "https://xxx.supabase.co/storage/v1/object/public/cvs/uid/file.pdf"
  ///       → "uid/file.pdf"
  String _storagePathFromUrl(String url) {
    const marker = '/storage/v1/object/public/cvs/';
    final idx = url.indexOf(marker);
    if (idx == -1) return '';
    return Uri.decodeFull(url.substring(idx + marker.length));
  }

  Future<void> _downloadCvBytes() async {
    if (_cvUrl == null) {
      setState(() => _isLoadingCv = false);
      return;
    }

    try {
      // Derive the path directly from the URL — this is always correct,
      // regardless of how the file was originally uploaded.
      final storagePath = _storagePathFromUrl(_cvUrl!);

      if (storagePath.isEmpty) {
        setState(() => _isLoadingCv = false);
        return;
      }

      final raw = await Supabase.instance.client.storage
          .from('cvs')
          .download(storagePath);

      if (!mounted) return;

      if (raw.isNotEmpty) {
        final bytes = Uint8List.fromList(raw);
        setState(() {
          _downloadedCvBytes = bytes;
          _isLoadingCv = false;
        });
        // Cache locally so the controller has the bytes for export / ATS.
        ref.read(smartJobControllerProvider.notifier).connectUploadedCv(
              fileName: storagePath.split('/').last,
              remoteStoragePath: storagePath,
              uploadedCvBase64: base64Encode(bytes),
              uploadedCvMimeType: 'application/pdf',
            );
      } else {
        setState(() => _isLoadingCv = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingCv = false);
    }
  }

  Widget _buildPreviewBody(
    BuildContext context, {
    required UserProfile profile,
    required CvInsight cv,
    required Uint8List? pdfBytes,
  }) {
    if (_isUploadingCv) {
      return _PreviewLoadingState(
        label: 'Uploading and preparing your CV preview...',
        stageLabel: _uploadStageLabel,
        progress: _uploadProgress,
      );
    }

    // Prefer freshly downloaded bytes, then locally-stored base64 bytes.
    final displayBytes = _downloadedCvBytes ?? pdfBytes;

    if (_isLoadingCv && displayBytes == null) {
      return const _PdfPreviewScaffold(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_cvUrl == null && displayBytes == null && !profile.hasUploadedCv) {
      return _UploadEmptyState(
        onUpload: uploadCV,
        onBuildInstead: () => context.go(AppRoute.cvSetup),
      );
    }

    // Use memory-based viewer whenever bytes are available — it renders
    // reliably on Android without the dark platform-view painting issue.
    if (displayBytes != null) {
      return _EmbeddedPdfPreview(
        controller: _pdfController,
        bytes: displayBytes,
      );
    }

    // Fallback to network viewer only if bytes could not be downloaded.
    if (_cvUrl != null) {
      return _RemotePdfPreview(
        controller: _pdfController,
        previewUrl: _cvUrl!,
        fallbackBytes: null,
      );
    }

    return _NonPdfPreviewState(
      fileName: cv.fileName,
      mimeType: cv.uploadedCvMimeType,
      summary: _cvLoadError ?? cv.parsedSummary,
      onUploadPdf: uploadCV,
    );
  }

  Map<String, dynamic> _buildPreviewData(UserProfile profile) {
    final contactLines = <String>[
      if (!profile.hideContactInfo && profile.email.isNotEmpty) profile.email,
      if (!profile.hideContactInfo && profile.phoneNumber.isNotEmpty)
        profile.phoneNumber,
      if (profile.location.isNotEmpty) profile.location,
      if (profile.linkedInUrl.isNotEmpty) profile.linkedInUrl,
      if (profile.portfolioUrl.isNotEmpty) profile.portfolioUrl,
      if (profile.websiteUrl.isNotEmpty) profile.websiteUrl,
    ];

    return {
      'name': profile.fullName.isEmpty ? 'Your Name' : profile.fullName,
      'title': profile.headline.isEmpty
          ? 'Add your headline'
          : profile.headline,
      'summary': profile.cvInsight.parsedSummary,
      'contact': contactLines,
      'skills': profile.skills.isEmpty
          ? const ['Flutter', 'Dart', 'Firebase', 'REST APIs', 'Figma']
          : profile.skills,
      'experience': profile.experience.isEmpty
          ? const [
              'Built premium mobile product features with Flutter and Firebase while improving polish, usability, and delivery speed.',
              'Worked with design and product stakeholders to ship structured user flows and cleaner recruiter-facing presentation.',
            ]
          : profile.experience,
      'education': profile.education.isEmpty
          ? const ['BSc in Computer Science, University, 2026']
          : profile.education,
      'projects': profile.projects.isEmpty
          ? const [
              'SmartJob capstone focused on AI-assisted CV scoring, matching, and recruiter-ready export flows.',
            ]
          : profile.projects,
    };
  }

  CvExportDocument _buildExportDocument(
    Map<String, dynamic> previewData,
    List<String> sectionOrder,
  ) {
    List<String> itemsFor(String section) {
      return switch (section) {
        'summary' => [previewData['summary'].toString()],
        'skills' => (previewData['skills'] as List<dynamic>)
            .map((item) => item.toString())
            .toList(),
        'experience' => (previewData['experience'] as List<dynamic>)
            .map((item) => item.toString())
            .toList(),
        'education' => (previewData['education'] as List<dynamic>)
            .map((item) => item.toString())
            .toList(),
        'projects' => (previewData['projects'] as List<dynamic>)
            .map((item) => item.toString())
            .toList(),
        _ => const <String>[],
      };
    }

    final sections = <CvExportSection>[];
    for (final section in sectionOrder) {
      final items = itemsFor(section)
          .where((item) => item.trim().isNotEmpty)
          .toList();
      if (items.isEmpty) {
        continue;
      }
      sections.add(
        CvExportSection(
          title: _sectionLabel(section),
          items: items,
        ),
      );
    }

    return CvExportDocument(
      fullName: previewData['name'].toString(),
      roleTitle: previewData['title'].toString(),
      contactLines: (previewData['contact'] as List<dynamic>)
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList(),
      sections: sections,
    );
  }

  Uint8List? _decodePreviewPdf(CvInsight cv) {
    if (cv.uploadedCvMimeType != 'application/pdf' ||
        cv.uploadedCvBase64.isEmpty) {
      return null;
    }
    try {
      return base64Decode(cv.uploadedCvBase64);
    } catch (_) {
      return null;
    }
  }

  Future<void> uploadCV() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.first;
      final fileBytes = file.bytes ?? await _readSelectedFileBytes(file);
      if (fileBytes == null || fileBytes.isEmpty) {
        throw Exception('SmartJob could not read the selected PDF.');
      }

      if (mounted) {
        setState(() {
          _isUploadingCv = true;
          _uploadProgress = 0.28;
          _uploadStageLabel = 'Uploading your PDF to SmartJob cloud...';
        });
      }

      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Not logged in');
      }

      final filePath = '$userId/$userId.pdf';
      await client.storage.from('cvs').uploadBinary(
            filePath,
            fileBytes,
            fileOptions: const FileOptions(
              contentType: 'application/pdf',
              upsert: true,
            ),
          );

      if (mounted) {
        setState(() {
          _uploadProgress = 0.74;
          _uploadStageLabel = 'Saving your CV link to your profile...';
        });
      }

      final publicUrl = client.storage.from('cvs').getPublicUrl(filePath);
      await client.from('profiles').update({
        'cv_url': publicUrl,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', userId);

      ref.read(smartJobControllerProvider.notifier).connectUploadedCv(
            fileName: '$userId.pdf',
            remoteStoragePath: filePath,
            uploadedCvBase64: base64Encode(fileBytes),
            uploadedCvMimeType: 'application/pdf',
          );

      if (!mounted) {
        return;
      }

      setState(() {
        _cvUrl = publicUrl;
        _cvLoadError = null;
        _uploadProgress = 1;
        _uploadStageLabel = 'CV uploaded successfully.';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('CV uploaded successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _cvLoadError = 'Upload failed: $error';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingCv = false;
          _uploadProgress = null;
          _uploadStageLabel = 'Preparing upload...';
        });
      }
    }
  }

  Future<void> _showExportSheet(
    BuildContext context,
    UserProfile profile,
    CvExportDocument exportDocument,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface(Theme.of(context).brightness),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Export CV',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 6),
                Text(
                  'Choose how you want to export or share ${profile.cvInsight.fileName}.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color:
                            AppColors.subtext(Theme.of(context).brightness),
                      ),
                ),
                const SizedBox(height: 16),
                _SheetActionTile(
                  icon: Icons.picture_as_pdf_outlined,
                  title: 'Download as PDF',
                  subtitle: 'Best for recruiters and ATS systems.',
                  onTap: _isExportingPdf
                      ? null
                      : () {
                          Navigator.of(sheetContext).pop();
                          _exportPdf(exportDocument);
                        },
                ),
                _SheetActionTile(
                  icon: Icons.description_outlined,
                  title: 'Download as Word',
                  subtitle: 'Exports a Word-compatible RTF document.',
                  onTap: _isExportingWord
                      ? null
                      : () {
                          Navigator.of(sheetContext).pop();
                          _exportWord(exportDocument);
                        },
                ),
                _SheetActionTile(
                  icon: Icons.link_outlined,
                  title: 'Copy shareable link',
                  subtitle:
                      'Copies a recruiter-friendly SmartJob CV link to your clipboard.',
                  onTap: () async {
                    await Clipboard.setData(
                      ClipboardData(text: _shareableCvLink(profile)),
                    );
                    if (!context.mounted) {
                      return;
                    }
                    Navigator.of(sheetContext).pop();
                    _showMessage(context, 'Link copied to clipboard!');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showWorkspaceSheet(
    BuildContext context,
    UserProfile profile,
  ) async {
    final controller = ref.read(smartJobControllerProvider.notifier);
    final initialOrder = [...profile.cvInsight.sectionOrder];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        var sectionOrder = [...initialOrder];
        var selectedTemplate = profile.cvInsight.selectedTemplate;
        var selectedFont = profile.cvInsight.fontFamily;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            final brightness = Theme.of(context).brightness;

            return DraggableScrollableSheet(
              initialChildSize: 0.88,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface(brightness),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(28)),
                    border: Border.all(color: AppColors.stroke(brightness)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.subtext(brightness)
                              .withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          controller: scrollController,
                          padding:
                              const EdgeInsets.fromLTRB(20, 4, 20, 32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Workspace settings',
                                style: Theme.of(context)
                                    .textTheme
                                    .displaySmall,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Choose a template, set a font, and reorder sections. Changes preview instantly.',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: AppColors.subtext(brightness),
                                    ),
                              ),
                              const SizedBox(height: 22),

                              // ── Template grid ──────────────────────
                              Text(
                                'CV Template',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Pick the layout that best fits your industry.',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: AppColors.subtext(brightness),
                                    ),
                              ),
                              const SizedBox(height: 14),
                              GridView.count(
                                crossAxisCount: 3,
                                shrinkWrap: true,
                                physics:
                                    const NeverScrollableScrollPhysics(),
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 0.72,
                                children: [
                                  for (final tpl in _cvTemplates)
                                    _TemplateCard(
                                      template: tpl,
                                      isSelected:
                                          selectedTemplate == tpl.name,
                                      onTap: () {
                                        setSheetState(() =>
                                            selectedTemplate = tpl.name);
                                        controller
                                            .updateCvStudioCustomization(
                                          templateName: tpl.name,
                                        );
                                      },
                                    ),
                                ],
                              ),
                              const SizedBox(height: 22),

                              // ── Font family ────────────────────────
                              Text(
                                'Font',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium,
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  for (final font in _cvFonts)
                                    _FontChip(
                                      font: font,
                                      selected: selectedFont == font,
                                      onTap: () {
                                        setSheetState(
                                            () => selectedFont = font);
                                        controller
                                            .updateCvStudioCustomization(
                                          fontFamily: font,
                                        );
                                      },
                                    ),
                                ],
                              ),
                              const SizedBox(height: 22),

                              // ── Cloud sync status ──────────────────
                              _InfoTile(
                                label: 'Cloud sync',
                                value:
                                    profile.cvInsight.remoteStoragePath.isEmpty
                                        ? 'Local only – upload a CV to enable cloud sync'
                                        : 'Connected · ${profile.cvInsight.remoteStoragePath.split('/').last}',
                              ),
                              const SizedBox(height: 22),

                              // ── Section order ──────────────────────
                              Text(
                                'Section order',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Drag to reorder how sections appear on your CV.',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: AppColors.subtext(brightness),
                                    ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: sectionOrder.length * 60.0,
                                child: ReorderableListView.builder(
                                  shrinkWrap: true,
                                  physics:
                                      const NeverScrollableScrollPhysics(),
                                  itemCount: sectionOrder.length,
                                  onReorder: (oldIndex, newIndex) {
                                    final updated = [...sectionOrder];
                                    if (newIndex > oldIndex) {
                                      newIndex -= 1;
                                    }
                                    final moved =
                                        updated.removeAt(oldIndex);
                                    updated.insert(newIndex, moved);
                                    setSheetState(
                                        () => sectionOrder = updated);
                                    controller.updateCvStudioCustomization(
                                      sectionOrder: updated,
                                    );
                                  },
                                  itemBuilder: (context, index) {
                                    final section = sectionOrder[index];
                                    return Container(
                                      key: ValueKey(section),
                                      margin: const EdgeInsets.only(
                                          bottom: 8),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 16,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            AppColors.surfaceMuted(brightness),
                                        borderRadius:
                                            BorderRadius.circular(16),
                                        border: Border.all(
                                          color:
                                              AppColors.stroke(brightness),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.drag_indicator_rounded,
                                            size: 18,
                                            color:
                                                AppColors.subtext(brightness),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              _sectionLabel(section),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyLarge,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _showAtsBreakdown(
    BuildContext context,
    UserProfile profile,
  ) async {
    final cv = profile.cvInsight;
    final formattingScore = math.max(40, cv.atsScore - 6).clamp(0, 100);
    final keywordDensity = math.min(100, cv.keywordMatchScore + 4).clamp(0, 100);
    final sectionCompleteness =
        math.min(100, cv.completionScore + 8).clamp(0, 100);
    final fileCompatibility =
        profile.hasUploadedCv && cv.uploadedCvMimeType == 'application/pdf'
            ? 96
            : 72;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final brightness = Theme.of(sheetContext).brightness;
        return DraggableScrollableSheet(
          initialChildSize: 0.62,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: AppColors.surface(brightness),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.subtext(brightness).withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ATS Score Breakdown',
                            style: Theme.of(context).textTheme.displaySmall,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'A recruiter-grade breakdown of what currently helps or hurts automated screening.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppColors.subtext(brightness),
                                ),
                          ),
                          const SizedBox(height: 18),
                          const Divider(height: 1),
                          const SizedBox(height: 18),
                          _BreakdownRow(
                            label: 'Formatting score',
                            score: formattingScore,
                          ),
                          _BreakdownRow(
                            label: 'Keyword density',
                            score: keywordDensity,
                          ),
                          _BreakdownRow(
                            label: 'Section completeness',
                            score: sectionCompleteness,
                          ),
                          _BreakdownRow(
                            label: 'File compatibility',
                            score: fileCompatibility,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openFullscreenPdf(
    BuildContext context,
    Uint8List bytes,
    String fileName,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text(fileName)),
          body: SafeArea(
            child: SfPdfViewer.memory(
              bytes,
              pageSpacing: 12,
              canShowPaginationDialog: false,
              canShowScrollHead: false,
            ),
          ),
        ),
      ),
    );
  }

  void _addKeywordAndEdit(BuildContext context, String keyword) {
    final profile = ref.read(smartJobControllerProvider).profile;
    final alreadyExists = profile.skills.any(
      (skill) => skill.toLowerCase() == keyword.toLowerCase(),
    );

    if (!alreadyExists) {
      ref.read(smartJobControllerProvider.notifier).addProfileEntry(
            CvCollectionSection.skills,
            keyword,
          );
    }

    _showMessage(
      context,
      alreadyExists
          ? '$keyword is already in your Skills section.'
          : '$keyword added to Skills. Opening editor...',
    );
    context.go('${AppRoute.cvSetup}?section=skills');
  }

  void _openEditorForTip(BuildContext context, String tip) {
    _showMessage(context, 'Opening the editor for: $tip');
    context.go('${AppRoute.cvSetup}?section=${_editorSectionForTip(tip)}');
  }

  Future<Uint8List?> _readSelectedFileBytes(PlatformFile file) async {
    final bytes = file.bytes;
    if (bytes != null && bytes.isNotEmpty) {
      return bytes;
    }

    final stream = file.readStream;
    if (stream == null) {
      return null;
    }

    final builder = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      builder.add(chunk);
    }
    final streamedBytes = builder.takeBytes();
    if (streamedBytes.isNotEmpty) {
      return streamedBytes;
    }

    try {
      final xFileBytes = await file.xFile.readAsBytes();
      return xFileBytes.isEmpty ? null : xFileBytes;
    } catch (_) {
      return null;
    }
  }

  String _shareableCvLink(UserProfile profile) {
    final seed = profile.smartInboxAlias.isNotEmpty
        ? profile.smartInboxAlias
        : profile.email;
    final slug = seed
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return 'https://smartjob.app/cv/${slug.isEmpty ? 'candidate' : slug}';
  }

  Future<void> _exportPdf(CvExportDocument document) async {
    setState(() => _isExportingPdf = true);
    try {
      await _saveExportFile(
        fileName: '${_exportBaseName(document.fullName)}.pdf',
        dialogTitle: 'Save SmartJob CV as PDF',
        extensions: const ['pdf'],
        bytes: buildCvPdfBytes(document),
        successLabel: 'PDF export complete.',
      );
    } catch (_) {
      if (mounted) {
        _showMessage(context, 'Exporting PDF failed. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _isExportingPdf = false);
      }
    }
  }

  Future<void> _exportWord(CvExportDocument document) async {
    setState(() => _isExportingWord = true);
    try {
      await _saveExportFile(
        fileName: '${_exportBaseName(document.fullName)}.rtf',
        dialogTitle: 'Save SmartJob CV as Word document',
        extensions: const ['rtf'],
        bytes: buildCvWordBytes(document),
        successLabel: 'Word export complete.',
      );
    } catch (_) {
      if (mounted) {
        _showMessage(
          context,
          'Exporting Word document failed. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExportingWord = false);
      }
    }
  }

  Future<void> _saveExportFile({
    required String fileName,
    required String dialogTitle,
    required List<String> extensions,
    required Uint8List bytes,
    required String successLabel,
  }) async {
    final savedPath = await FilePicker.platform.saveFile(
      dialogTitle: dialogTitle,
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: extensions,
      bytes: bytes,
    );

    if (!mounted) {
      return;
    }

    if (!kIsWeb && savedPath == null) {
      _showMessage(context, 'Export cancelled.');
      return;
    }

    final message = kIsWeb || savedPath == null
        ? successLabel
        : '$successLabel Saved to $savedPath';
    _showMessage(context, message);
  }

  String _exportBaseName(String fullName) {
    final seed = fullName.trim().isEmpty
        ? 'smartjob_cv'
        : '${fullName.trim()} smartjob cv';
    final normalized = seed
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return normalized.isEmpty ? 'smartjob_cv' : normalized;
  }

  _HealthStatus _healthStatusFor(int score) {
    if (score >= 70) {
      return const _HealthStatus('Excellent', AppColors.success);
    }
    if (score >= 41) {
      return const _HealthStatus('Good', AppColors.warning);
    }
    return const _HealthStatus('Needs Improvement', AppColors.danger);
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.profile,
    required this.status,
    required this.isUploading,
    required this.onExport,
    required this.onEdit,
    required this.onWorkspace,
  });

  final UserProfile profile;
  final _HealthStatus status;
  final bool isUploading;
  final VoidCallback onExport;
  final VoidCallback onEdit;
  final VoidCallback onWorkspace;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final initials = _initialsFor(profile.fullName);

    return SmartJobPanel(
      radius: 24,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final intro = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.midnight,
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.fullName.isEmpty
                              ? 'Your CV workspace'
                              : profile.fullName,
                          style: Theme.of(context).textTheme.displaySmall,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'A cleaner, recruiter-grade CV space for uploads, live preview, scoring, and export.',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.subtext(brightness),
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _StatusPill(
                    icon:
                        profile.hasUploadedCv ? Icons.cloud_done : Icons.upload,
                    label: profile.hasUploadedCv ? 'Uploaded' : 'Awaiting upload',
                  ),
                  _StatusPill(
                    icon: isUploading ? Icons.sync : Icons.check_circle_outline,
                    label: isUploading ? 'Saving...' : 'Autosaved',
                    highlighted: isUploading,
                  ),
                  _StatusPill(
                    icon: Icons.schedule,
                    label: _lastEditedAgo(profile.cvInsight.lastEditedAtIso),
                  ),
                  _StatusPill(
                    icon: Icons.favorite_border,
                    label: status.label,
                    highlighted: true,
                    accent: status.color,
                  ),
                ],
              ),
            ],
          );

          final actions = Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ElevatedButton.icon(
                onPressed: onExport,
                icon: const Icon(Icons.file_download_outlined),
                label: const Text('Export CV'),
              ),
              OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit content'),
              ),
              OutlinedButton.icon(
                onPressed: onWorkspace,
                icon: const Icon(Icons.tune_outlined),
                label: const Text('Workspace'),
              ),
            ],
          );

          if (constraints.maxWidth >= 980) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: intro),
                const SizedBox(width: 20),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: actions,
                ),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              intro,
              const SizedBox(height: 18),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _HealthSummaryCard extends StatelessWidget {
  const _HealthSummaryCard({
    required this.averageScore,
    required this.status,
    required this.cards,
  });

  final int averageScore;
  final _HealthStatus status;
  final List<_ScoreCardData> cards;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return SmartJobPanel(
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: status.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: status.color.withValues(alpha: 0.38),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.monitor_heart_outlined, color: status.color),
                    const SizedBox(width: 8),
                    Text(
                      'CV Health: ${status.label}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: status.color,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
              Text(
                '$averageScore / 100',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'These scores help you see whether your CV is complete, ATS-friendly, and aligned to the job language you are targeting.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.subtext(brightness),
                ),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 980) {
                return Row(
                  children: [
                    for (var i = 0; i < cards.length; i++) ...[
                      Expanded(child: _CircularScoreCard(data: cards[i])),
                      if (i != cards.length - 1) const SizedBox(width: 16),
                    ],
                  ],
                );
              }

              return Column(
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    _CircularScoreCard(data: cards[i]),
                    if (i != cards.length - 1) const SizedBox(height: 14),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CircularScoreCard extends StatelessWidget {
  const _CircularScoreCard({required this.data});

  final _ScoreCardData data;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final ringColor = _scoreColor(data.score);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: data.onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: AppColors.surfaceMuted(brightness).withValues(alpha: 0.52),
            border: Border.all(color: AppColors.stroke(brightness)),
          ),
          child: Row(
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween<double>(
                  begin: 0,
                  end: data.score / 100,
                ),
                duration: const Duration(milliseconds: 650),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 82,
                        height: 82,
                        child: CircularProgressIndicator(
                          value: value,
                          strokeWidth: 9,
                          color: ringColor,
                          backgroundColor:
                              AppColors.surface(brightness),
                        ),
                      ),
                      Text(
                        '${data.score}',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            data.title,
                            style:
                                Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                          ),
                        ),
                        if (data.onTap != null)
                          Tooltip(
                            message: 'View breakdown',
                            child: Icon(
                              Icons.open_in_new,
                              size: 18,
                              color: AppColors.subtext(brightness),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      data.description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.subtext(brightness),
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewShell extends StatelessWidget {
  const _PreviewShell({
    required this.fileName,
    required this.zoom,
    required this.onZoomChanged,
    required this.onExpand,
    required this.onUpload,
    required this.isUploading,
    required this.child,
  });

  final String fileName;
  final double zoom;
  final ValueChanged<double> onZoomChanged;
  final VoidCallback? onExpand;
  final VoidCallback? onUpload;
  final bool isUploading;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return SmartJobPanel(
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final titleBlock = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Live CV Preview',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    fileName.isEmpty
                        ? 'Upload a PDF CV to see the real document here.'
                        : 'Rendering $fileName directly inside your SmartJob workspace.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.subtext(brightness),
                        ),
                  ),
                ],
              );

              final controls = Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppColors.stroke(brightness)),
                      color: AppColors.surfaceMuted(brightness),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final level in [0.85, 1.0, 1.15])
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: ChoiceChip(
                              label: Text('${(level * 100).round()}%'),
                              selected: zoom == level,
                              onSelected: (_) => onZoomChanged(level),
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: onExpand,
                    tooltip: 'Open fullscreen preview',
                    icon: const Icon(Icons.open_in_full),
                  ),
                  OutlinedButton.icon(
                    onPressed: isUploading ? null : onUpload,
                    icon: const Icon(Icons.upload_file_outlined),
                    label: Text(isUploading ? 'Uploading...' : 'Replace CV'),
                  ),
                ],
              );

              if (constraints.maxWidth >= 1040) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: titleBlock),
                    const SizedBox(width: 16),
                    Flexible(child: controls),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  titleBlock,
                  const SizedBox(height: 14),
                  controls,
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _RemotePdfPreview extends StatefulWidget {
  const _RemotePdfPreview({
    required this.controller,
    required this.previewUrl,
    this.fallbackBytes,
  });

  final PdfViewerController controller;
  final String previewUrl;
  final Uint8List? fallbackBytes;

  @override
  State<_RemotePdfPreview> createState() => _RemotePdfPreviewState();
}

class _RemotePdfPreviewState extends State<_RemotePdfPreview> {
  bool _isLoaded = false;
  String? _loadError;

  @override
  Widget build(BuildContext context) {
    if (widget.previewUrl.isEmpty) {
      return _PdfPreviewScaffold(
        child: _PdfPreviewErrorState(
          message: 'SmartJob could not load your uploaded PDF preview.',
        ),
      );
    }

    if (_loadError != null && widget.fallbackBytes != null) {
      return _EmbeddedPdfPreview(
        controller: widget.controller,
        bytes: widget.fallbackBytes!,
      );
    }

    return _PdfPreviewScaffold(
      child: Stack(
        fit: StackFit.expand,
        children: [
          SfPdfViewer.network(
            widget.previewUrl,
            key: ValueKey(widget.previewUrl),
            controller: widget.controller,
            pageSpacing: 0,
            canShowScrollHead: false,
            canShowPaginationDialog: false,
            onDocumentLoaded: (_) {
              if (mounted) {
                setState(() => _isLoaded = true);
              }
            },
            onDocumentLoadFailed: (details) {
              if (mounted) {
                setState(() {
                  _isLoaded = true;
                  _loadError = details.description;
                });
              }
            },
          ),
          IgnorePointer(
            ignoring: _isLoaded,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 220),
              opacity: _isLoaded ? 0 : 1,
              child: const _PdfPreviewSkeleton(),
            ),
          ),
          if (_loadError != null)
            _PdfPreviewErrorState(message: _loadError!),
        ],
      ),
    );
  }
}

class _PdfPreviewScaffold extends StatelessWidget {
  const _PdfPreviewScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 860,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white,
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _PdfPreviewErrorState extends StatelessWidget {
  const _PdfPreviewErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.picture_as_pdf_outlined,
              size: 42,
              color: AppColors.midnight,
            ),
            const SizedBox(height: 14),
            Text(
              'Preview unavailable',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmbeddedPdfPreview extends StatefulWidget {
  const _EmbeddedPdfPreview({
    required this.controller,
    required this.bytes,
  });

  final PdfViewerController controller;
  final Uint8List bytes;

  @override
  State<_EmbeddedPdfPreview> createState() => _EmbeddedPdfPreviewState();
}

class _EmbeddedPdfPreviewState extends State<_EmbeddedPdfPreview> {
  bool _isLoaded = false;

  @override
  Widget build(BuildContext context) {
    return _PdfPreviewScaffold(
      child: Stack(
        fit: StackFit.expand,
        children: [
          SfPdfViewer.memory(
            widget.bytes,
            key: ValueKey(widget.bytes.length),
            controller: widget.controller,
            pageSpacing: 10,
            canShowScrollHead: false,
            canShowPaginationDialog: false,
            onDocumentLoaded: (_) {
              if (mounted) {
                setState(() => _isLoaded = true);
              }
            },
          ),
          IgnorePointer(
            ignoring: _isLoaded,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 220),
              opacity: _isLoaded ? 0 : 1,
              child: const _PdfPreviewSkeleton(),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewLoadingState extends StatelessWidget {
  const _PreviewLoadingState({
    required this.label,
    required this.stageLabel,
    required this.progress,
  });

  final String label;
  final String stageLabel;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Container(
      constraints: const BoxConstraints(minHeight: 520),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: AppColors.surfaceMuted(brightness),
        border: Border.all(color: AppColors.stroke(brightness)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Text(
              stageLabel,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.subtext(brightness),
                  ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
              ),
            ),
            const SizedBox(height: 22),
            for (final width in [0.92, 0.7, 1.0, 0.86, 0.76])
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: width,
                  child: Container(
                    height: 22,
                    decoration: BoxDecoration(
                      color: AppColors.surface(brightness),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 18),
            Container(
              height: 260,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UploadEmptyState extends StatelessWidget {
  const _UploadEmptyState({
    required this.onUpload,
    required this.onBuildInstead,
  });

  final VoidCallback onUpload;
  final VoidCallback onBuildInstead;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Container(
      height: 680,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.stroke(brightness),
          width: 1.3,
        ),
        gradient: LinearGradient(
          colors: [
            AppColors.surfaceMuted(brightness),
            AppColors.surface(brightness),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.midnight.withValues(alpha: 0.12),
                ),
                child: const Icon(
                  Icons.upload_file_rounded,
                  size: 42,
                  color: AppColors.midnight,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Choose how you want to start',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 10),
              Text(
                'Upload your existing PDF CV for instant analysis, or start with SmartJob AI and build one from your profile details.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.subtext(brightness),
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                'Supports .pdf, .doc, and .docx uploads.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.subtext(brightness),
                    ),
              ),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  ElevatedButton.icon(
                    onPressed: onUpload,
                    icon: const Icon(Icons.file_upload_outlined),
                    label: const Text('Upload Existing CV'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onBuildInstead,
                    icon: const Icon(Icons.auto_awesome_outlined),
                    label: const Text('Build with AI'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NonPdfPreviewState extends StatelessWidget {
  const _NonPdfPreviewState({
    required this.fileName,
    required this.mimeType,
    required this.summary,
    required this.onUploadPdf,
  });

  final String fileName;
  final String mimeType;
  final String summary;
  final VoidCallback onUploadPdf;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Container(
      height: 680,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: AppColors.surfaceMuted(brightness),
        border: Border.all(color: AppColors.stroke(brightness)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: AppColors.sand.withValues(alpha: 0.16),
                ),
                child: const Icon(
                  Icons.description_outlined,
                  size: 42,
                  color: AppColors.sand,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                fileName,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'This CV is connected, but SmartJob can only render inline preview for uploaded PDF files right now.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.subtext(brightness),
                    ),
              ),
              const SizedBox(height: 14),
              _InfoBadge(label: 'Type', value: mimeType),
              const SizedBox(height: 18),
              Text(
                summary,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: onUploadPdf,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Upload PDF for live preview'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuggestedKeywordsCard extends StatelessWidget {
  const _SuggestedKeywordsCard({
    required this.keywords,
    required this.onAdd,
  });

  final List<String> keywords;
  final ValueChanged<String> onAdd;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return SmartJobPanel(
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SmartJobSectionHeader(
            title: 'Suggested Keywords',
            subtitle:
                'Tap a keyword to add it into Skills and jump straight into the editor.',
          ),
          const SizedBox(height: 18),
          if (keywords.isEmpty)
            Text(
              'No missing keywords detected right now.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.subtext(brightness),
                  ),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final keyword in keywords)
                  _KeywordActionChip(
                    label: keyword,
                    onTap: () => onAdd(keyword),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ImproveNextCard extends StatelessWidget {
  const _ImproveNextCard({
    required this.tips,
    required this.onTapTip,
  });

  final List<String> tips;
  final ValueChanged<String> onTapTip;

  @override
  Widget build(BuildContext context) {
    final effectiveTips = tips.isEmpty
        ? const [
            'Add stronger action verbs to your experience bullets.',
            'Include missing technical tools in your skills section.',
            'Quantify one achievement with delivery, growth, or impact.',
          ]
        : tips;

    return SmartJobPanel(
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SmartJobSectionHeader(
            title: 'Improve Next',
            subtitle:
                'Focused edits that will most likely improve readability, keyword fit, and recruiter confidence.',
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < effectiveTips.length; i++) ...[
            _ImprovementTile(
              index: i + 1,
              tip: effectiveTips[i],
              icon: _tipIconFor(effectiveTips[i]),
              onTap: () => onTapTip(effectiveTips[i]),
            ),
            if (i != effectiveTips.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _SheetActionTile extends StatelessWidget {
  const _SheetActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: AppColors.surfaceMuted(brightness),
              border: Border.all(color: AppColors.stroke(brightness)),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.midnight.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: AppColors.midnight),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.subtext(brightness),
                            ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: AppColors.subtext(brightness),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.label,
    required this.score,
  });

  final String label;
  final int score;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final color = _scoreColor(score);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                '$score',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: score / 100,
              minHeight: 10,
              color: color,
              backgroundColor: AppColors.surfaceMuted(brightness),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted(brightness),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.stroke(brightness)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.subtext(brightness),
                ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.icon,
    required this.label,
    this.highlighted = false,
    this.accent,
  });

  final IconData icon;
  final String label;
  final bool highlighted;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final color = accent ?? AppColors.midnight;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: highlighted
            ? color.withValues(alpha: 0.12)
            : AppColors.surfaceMuted(brightness),
        border: Border.all(
          color: highlighted
              ? color.withValues(alpha: 0.32)
              : AppColors.stroke(brightness),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: highlighted ? color : AppColors.subtext(brightness),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: highlighted ? color : null,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _KeywordActionChip extends StatelessWidget {
  const _KeywordActionChip({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: AppColors.surfaceMuted(brightness),
            border: Border.all(color: AppColors.stroke(brightness)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.midnight.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  '+ Add',
                  style: TextStyle(
                    color: AppColors.midnight,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImprovementTile extends StatelessWidget {
  const _ImprovementTile({
    required this.index,
    required this.tip,
    required this.icon,
    required this.onTap,
  });

  final int index;
  final String tip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: AppColors.surfaceMuted(brightness),
            border: Border.all(color: AppColors.stroke(brightness)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: AppColors.midnight.withValues(alpha: 0.12),
                ),
                child: Text(
                  '$index',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.midnight,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            tip,
                            style:
                                Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Open the editor to apply this improvement directly in your CV content.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.subtext(brightness),
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.chevron_right,
                color: AppColors.subtext(brightness),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  const _InfoBadge({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: AppColors.surface(brightness),
        border: Border.all(color: AppColors.stroke(brightness)),
      ),
      child: Text(
        '$label: $value',
        style: Theme.of(context).textTheme.labelLarge,
      ),
    );
  }
}

class _PdfPreviewSkeleton extends StatelessWidget {
  const _PdfPreviewSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          SmartJobSkeletonBlock(height: 26, width: 220, radius: 12),
          SizedBox(height: 16),
          SmartJobSkeletonBlock(height: 14, width: 360, radius: 999),
          SizedBox(height: 10),
          SmartJobSkeletonBlock(height: 14, width: 280, radius: 999),
          SizedBox(height: 28),
          Expanded(
            child: SmartJobSkeletonBlock(
              width: double.infinity,
              radius: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthStatus {
  const _HealthStatus(this.label, this.color);

  final String label;
  final Color color;
}

class _ScoreCardData {
  const _ScoreCardData({
    required this.title,
    required this.score,
    required this.description,
    this.onTap,
  });

  final String title;
  final int score;
  final String description;
  final VoidCallback? onTap;
}

class CvExportDocument {
  const CvExportDocument({
    required this.fullName,
    required this.roleTitle,
    required this.contactLines,
    required this.sections,
  });

  final String fullName;
  final String roleTitle;
  final List<String> contactLines;
  final List<CvExportSection> sections;
}

class CvExportSection {
  const CvExportSection({
    required this.title,
    required this.items,
  });

  final String title;
  final List<String> items;
}

Uint8List buildCvPdfBytes(CvExportDocument document) {
  final lines = <_PdfLineData>[];

  lines.add(
    _PdfLineData(
      text: document.fullName,
      fontSize: 22,
      bold: true,
    ),
  );

  if (document.roleTitle.trim().isNotEmpty) {
    lines.add(
      _PdfLineData(
        text: document.roleTitle,
        fontSize: 13,
      ),
    );
  }

  if (document.contactLines.isNotEmpty) {
    final contactLine = document.contactLines.join(' | ');
    for (final wrapped in _wrapText(contactLine, 86)) {
      lines.add(
        _PdfLineData(
          text: wrapped,
          fontSize: 10,
          topSpacing: 2,
        ),
      );
    }
  }

  for (final section in document.sections) {
    lines.add(
      _PdfLineData(
        text: section.title.toUpperCase(),
        fontSize: 13,
        bold: true,
        topSpacing: 18,
      ),
    );
    for (final item in section.items) {
      final wrapped = _wrapText(item, 82);
      for (var i = 0; i < wrapped.length; i++) {
        lines.add(
          _PdfLineData(
            text: i == 0 ? '- ${wrapped[i]}' : '  ${wrapped[i]}',
            fontSize: 11,
            topSpacing: i == 0 ? 7 : 2,
          ),
        );
      }
    }
  }

  final pages = <List<_LaidOutPdfLine>>[];
  var currentPage = <_LaidOutPdfLine>[];
  const pageHeight = 792.0;
  const top = 744.0;
  const bottom = 54.0;
  var y = top;

  for (final line in lines) {
    final lineHeight = line.fontSize + 6 + line.topSpacing;
    if (y - lineHeight < bottom && currentPage.isNotEmpty) {
      pages.add(currentPage);
      currentPage = <_LaidOutPdfLine>[];
      y = top;
    }

    y -= line.topSpacing;
    currentPage.add(_LaidOutPdfLine(line, y));
    y -= line.fontSize + 6;
  }

  if (currentPage.isNotEmpty) {
    pages.add(currentPage);
  }

  final objects = <String>[];
  objects.add('<< /Type /Catalog /Pages 2 0 R >>');

  final pageCount = pages.length;
  final firstPageObject = 5;
  final kids = [
    for (var i = 0; i < pageCount; i++) '${firstPageObject + (i * 2)} 0 R',
  ].join(' ');
  objects.add('<< /Type /Pages /Kids [$kids] /Count $pageCount >>');
  objects.add('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>');
  objects.add(
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>',
  );

  for (var i = 0; i < pages.length; i++) {
    final pageObjectNumber = firstPageObject + (i * 2);
    final contentObjectNumber = pageObjectNumber + 1;
    objects.add(
      '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 $pageHeight] /Resources << /Font << /F1 3 0 R /F2 4 0 R >> >> /Contents $contentObjectNumber 0 R >>',
    );

    final content = StringBuffer();
    for (final line in pages[i]) {
      final font = line.data.bold ? 'F2' : 'F1';
      final safeText = _pdfEscape(line.data.text);
      content.writeln('BT');
      content.writeln('/$font ${line.data.fontSize} Tf');
      content.writeln('54 ${line.y.toStringAsFixed(2)} Td');
      content.writeln('($safeText) Tj');
      content.writeln('ET');
    }

    final stream = content.toString();
    final streamBytes = latin1.encode(stream);
    objects.add(
      '<< /Length ${streamBytes.length} >>\nstream\n$stream\nendstream',
    );
  }

  final buffer = StringBuffer();
  final offsets = <int>[0];
  buffer.write('%PDF-1.4\n');

  for (var i = 0; i < objects.length; i++) {
    offsets.add(latin1.encode(buffer.toString()).length);
    buffer.write('${i + 1} 0 obj\n');
    buffer.write(objects[i]);
    buffer.write('\nendobj\n');
  }

  final xrefOffset = latin1.encode(buffer.toString()).length;
  buffer.write('xref\n');
  buffer.write('0 ${objects.length + 1}\n');
  buffer.write('0000000000 65535 f \n');
  for (var i = 1; i < offsets.length; i++) {
    buffer.writeln('${offsets[i].toString().padLeft(10, '0')} 00000 n ');
  }
  buffer.write('trailer\n');
  buffer.write(
    '<< /Size ${objects.length + 1} /Root 1 0 R >>\n',
  );
  buffer.write('startxref\n');
  buffer.write('$xrefOffset\n');
  buffer.write('%%EOF');

  return Uint8List.fromList(latin1.encode(buffer.toString()));
}

Uint8List buildCvWordBytes(CvExportDocument document) {
  final buffer = StringBuffer();
  buffer.writeln(r'{\rtf1\ansi\deff0');
  buffer.writeln(r'{\fonttbl{\f0 Arial;}}');
  buffer.writeln(r'\paperw12240\paperh15840\margl1080\margr1080\margt1080\margb1080');
  buffer.writeln('\\f0\\fs42\\b ${_rtfEscape(document.fullName)}\\b0\\par');

  if (document.roleTitle.trim().isNotEmpty) {
    buffer.writeln('\\fs24 ${_rtfEscape(document.roleTitle)}\\par');
  }

  if (document.contactLines.isNotEmpty) {
    buffer.writeln(
      '\\fs20 ${_rtfEscape(document.contactLines.join(' | '))}\\par',
    );
  }

  for (final section in document.sections) {
    buffer.writeln('\\par\\b\\fs24 ${_rtfEscape(section.title)}\\b0\\par');
    for (final item in section.items) {
      buffer.writeln('\\fs22 - ${_rtfEscape(item)}\\par');
    }
  }

  buffer.write('}');
  return Uint8List.fromList(latin1.encode(buffer.toString()));
}

class _PdfLineData {
  const _PdfLineData({
    required this.text,
    required this.fontSize,
    this.bold = false,
    this.topSpacing = 0,
  });

  final String text;
  final double fontSize;
  final bool bold;
  final double topSpacing;
}

class _LaidOutPdfLine {
  const _LaidOutPdfLine(this.data, this.y);

  final _PdfLineData data;
  final double y;
}

List<String> _wrapText(String value, int maxChars) {
  final text = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (text.isEmpty) {
    return const [];
  }

  final words = text.split(' ');
  final lines = <String>[];
  var current = '';

  for (final word in words) {
    final candidate = current.isEmpty ? word : '$current $word';
    if (candidate.length <= maxChars) {
      current = candidate;
      continue;
    }

    if (current.isNotEmpty) {
      lines.add(current);
      current = word;
      continue;
    }

    lines.add(word);
  }

  if (current.isNotEmpty) {
    lines.add(current);
  }

  return lines;
}

String _pdfEscape(String value) {
  return _asciiOnly(value)
      .replaceAll(r'\', r'\\')
      .replaceAll('(', r'\(')
      .replaceAll(')', r'\)');
}

String _rtfEscape(String value) {
  return _asciiOnly(value)
      .replaceAll(r'\', r'\\')
      .replaceAll('{', r'\{')
      .replaceAll('}', r'\}');
}

String _asciiOnly(String value) {
  final buffer = StringBuffer();
  for (final codeUnit in value.codeUnits) {
    if (codeUnit >= 32 && codeUnit <= 126) {
      buffer.writeCharCode(codeUnit);
    } else if (codeUnit == 10 || codeUnit == 13) {
      buffer.write(' ');
    } else {
      buffer.write('?');
    }
  }
  return buffer.toString();
}

String _sectionLabel(String section) {
  return switch (section) {
    'summary' => 'Summary',
    'skills' => 'Skills',
    'experience' => 'Experience',
    'education' => 'Education',
    'projects' => 'Projects',
    _ => section.replaceAll('_', ' '),
  };
}

String _initialsFor(String fullName) {
  final parts = fullName
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .toList();

  if (parts.isEmpty) {
    return 'SJ';
  }

  return parts
      .map((part) => part.substring(0, 1).toUpperCase())
      .join();
}

String _lastEditedAgo(String isoString) {
  final editedAt = DateTime.tryParse(isoString);
  if (editedAt == null) {
    return 'Last edited just now';
  }

  final difference = DateTime.now().toUtc().difference(editedAt.toUtc());
  if (difference.inSeconds < 60) {
    return 'Last edited ${difference.inSeconds.clamp(1, 59)}s ago';
  }
  if (difference.inMinutes < 60) {
    return 'Last edited ${difference.inMinutes}m ago';
  }
  if (difference.inHours < 24) {
    return 'Last edited ${difference.inHours}h ago';
  }
  return 'Last edited ${difference.inDays}d ago';
}

Color _scoreColor(int score) {
  if (score >= 70) {
    return AppColors.success;
  }
  if (score >= 41) {
    return AppColors.warning;
  }
  return AppColors.danger;
}

IconData _tipIconFor(String tip) {
  final lower = tip.toLowerCase();
  if (lower.contains('tool') || lower.contains('skill')) {
    return Icons.build_outlined;
  }
  if (lower.contains('achievement') || lower.contains('impact')) {
    return Icons.rocket_launch_outlined;
  }
  if (lower.contains('verb') || lower.contains('summary')) {
    return Icons.edit_outlined;
  }
  return Icons.checklist_rtl_outlined;
}

String _editorSectionForTip(String tip) {
  final lower = tip.toLowerCase();
  if (lower.contains('project')) {
    return 'projects';
  }
  if (lower.contains('education') || lower.contains('coursework')) {
    return 'education';
  }
  if (lower.contains('tool') || lower.contains('skill')) {
    return 'skills';
  }
  return 'experience';
}

// ─────────────────────────────────────────────────────────────────
// Template & font data
// ─────────────────────────────────────────────────────────────────

class _CvTemplateData {
  const _CvTemplateData({
    required this.name,
    required this.label,
    required this.description,
    required this.accentColor,
    required this.hasLeftBar,
    required this.hasTwoColumns,
  });

  final String name;
  final String label;
  final String description;
  final Color accentColor;
  final bool hasLeftBar;
  final bool hasTwoColumns;
}

const List<_CvTemplateData> _cvTemplates = [
  _CvTemplateData(
    name: 'Minimal',
    label: 'Minimal',
    description: 'Clean & spacious',
    accentColor: Color(0xFF19324A),
    hasLeftBar: false,
    hasTwoColumns: false,
  ),
  _CvTemplateData(
    name: 'Classic',
    label: 'Classic',
    description: 'Traditional & formal',
    accentColor: Color(0xFF5E8A86),
    hasLeftBar: false,
    hasTwoColumns: false,
  ),
  _CvTemplateData(
    name: 'Modern',
    label: 'Modern',
    description: 'Bold sidebar accent',
    accentColor: Color(0xFF5D8CC3),
    hasLeftBar: true,
    hasTwoColumns: false,
  ),
  _CvTemplateData(
    name: 'TwoColumn',
    label: 'Two-Column',
    description: 'Skills on the left',
    accentColor: Color(0xFFD39A4D),
    hasLeftBar: false,
    hasTwoColumns: true,
  ),
  _CvTemplateData(
    name: 'Professional',
    label: 'Professional',
    description: 'Header banner style',
    accentColor: Color(0xFFC97666),
    hasLeftBar: false,
    hasTwoColumns: false,
  ),
  _CvTemplateData(
    name: 'Compact',
    label: 'Compact',
    description: 'Dense, fits more',
    accentColor: Color(0xFF57A37B),
    hasLeftBar: false,
    hasTwoColumns: false,
  ),
];

const List<String> _cvFonts = [
  'Inter',
  'Georgia',
  'Roboto',
  'Merriweather',
  'Lato',
  'Playfair Display',
];

// ─────────────────────────────────────────────────────────────────
// Template card widget
// ─────────────────────────────────────────────────────────────────

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.isSelected,
    required this.onTap,
  });

  final _CvTemplateData template;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: AppColors.surface(brightness),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? template.accentColor
                : AppColors.stroke(brightness),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: template.accentColor.withValues(alpha: 0.22),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Mini CV preview
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: _CvMiniPreview(template: template),
              ),
            ),
            // Label row
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          template.label,
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: isSelected
                                        ? template.accentColor
                                        : AppColors.text(brightness),
                                  ),
                        ),
                        Text(
                          template.description,
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AppColors.subtext(brightness),
                                  ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: template.accentColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 11,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Mini CV visual mockup painted with containers
class _CvMiniPreview extends StatelessWidget {
  const _CvMiniPreview({required this.template});

  final _CvTemplateData template;

  @override
  Widget build(BuildContext context) {
    final accent = template.accentColor;
    const bg = Colors.white;

    if (template.hasLeftBar) {
      // Sidebar layout
      return Container(
        color: bg,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 28,
              color: accent,
              padding: const EdgeInsets.all(4),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: Colors.white38,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (final w in [0.8, 0.6, 0.7, 0.5])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: FractionallySizedBox(
                        widthFactor: w,
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            color: Colors.white38,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: _MiniContentColumn(accent: accent),
            ),
          ],
        ),
      );
    }

    if (template.hasTwoColumns) {
      return Container(
        color: bg,
        padding: const EdgeInsets.all(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 14,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 36,
                    child: Column(
                      children: [
                        for (final w in [0.9, 0.7, 0.8, 0.6, 0.75])
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: FractionallySizedBox(
                              widthFactor: w,
                              child: Container(
                                height: 4,
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(child: _MiniContentColumn(accent: accent)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (template.name == 'Professional') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 28,
            color: accent,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 6,
                  width: 60,
                  decoration: BoxDecoration(
                    color: Colors.white70,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  height: 3,
                  width: 40,
                  decoration: BoxDecoration(
                    color: Colors.white38,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(5),
              child: _MiniContentColumn(accent: accent),
            ),
          ),
        ],
      );
    }

    // Default single-column (Minimal, Classic, Compact)
    return Container(
      color: bg,
      padding: const EdgeInsets.all(7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: template.name == 'Compact' ? 7 : 10,
            width: double.infinity,
            decoration: BoxDecoration(
              color: accent.withValues(
                alpha: template.name == 'Minimal' ? 0.08 : 0.14,
              ),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 5),
          _MiniContentColumn(
            accent: accent,
            dense: template.name == 'Compact',
          ),
        ],
      ),
    );
  }
}

class _MiniContentColumn extends StatelessWidget {
  const _MiniContentColumn({
    required this.accent,
    this.dense = false,
  });

  final Color accent;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final lineHeights = dense
        ? [3.0, 3.0, 3.0, 3.0, 3.0, 3.0]
        : [4.0, 3.0, 3.0, 4.0, 3.0, 3.0];
    final widths = [0.9, 0.7, 0.8, 0.85, 0.6, 0.75];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < lineHeights.length; i++) ...[
          if (i == 3)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Container(
                height: 1,
                color: accent.withValues(alpha: 0.25),
              ),
            ),
          FractionallySizedBox(
            widthFactor: widths[i],
            child: Container(
              height: lineHeights[i],
              margin: const EdgeInsets.only(bottom: 3),
              decoration: BoxDecoration(
                color: i == 0 || i == 3
                    ? accent.withValues(alpha: 0.5)
                    : accent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Font chip widget
// ─────────────────────────────────────────────────────────────────

class _FontChip extends StatelessWidget {
  const _FontChip({
    required this.font,
    required this.selected,
    required this.onTap,
  });

  final String font;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.midnight
                : AppColors.surface(brightness),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? AppColors.midnight
                  : AppColors.stroke(brightness),
            ),
          ),
          child: Text(
            font,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color:
                      selected ? Colors.white : AppColors.text(brightness),
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w500,
                ),
          ),
        ),
      ),
    );
  }
}

