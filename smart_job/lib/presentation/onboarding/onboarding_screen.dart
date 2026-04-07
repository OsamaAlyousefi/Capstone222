import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../application/controllers/smart_job_controller.dart';
import '../../data/remote/smart_job_remote_sync.dart';
import '../../router/app_router.dart';
import '../../theme/app_colors.dart';
import '../shared/widgets/smart_job_ui.dart';

enum _CvMode { upload, build }

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  _CvMode _cvMode = _CvMode.upload;
  PlatformFile? _selectedFile;
  bool _isPickingFile = false;
  bool _isUploading = false;

  late final List<String> _selectedRoles;
  late final List<String> _selectedLocations;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(smartJobControllerProvider).profile;
    _selectedRoles = profile.jobPreferences.targetRoles.isEmpty
        ? ['Flutter Developer']
        : [...profile.jobPreferences.targetRoles];
    _selectedLocations = profile.jobPreferences.preferredLocations.isEmpty
        ? ['Remote']
        : [...profile.jobPreferences.preferredLocations];
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isUpload = _cvMode == _CvMode.upload;
    final remoteSync = ref.watch(smartJobRemoteSyncProvider);
    final hasCloudUpload = remoteSync != null;

    return Scaffold(
      body: SmartJobBackground(
        child: SmartJobScrollPage(
          maxWidth: 980,
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SmartJobAppLogo(centered: true),
              const SizedBox(height: 28),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SmartJobHeroLabel(label: 'One-time CV setup'),
                      const SizedBox(height: 24),
                      Text(
                        'Upload your CV or start with the builder.',
                        textAlign: TextAlign.center,
                        style: textTheme.displayLarge,
                      ).animate().fade().slideY(begin: 0.04),
                      const SizedBox(height: 12),
                      Text(
                        hasCloudUpload
                            ? 'Pick a real CV file from your device and SmartJob will upload it to cloud storage, sync it to your account, and keep your local workspace updated.'
                            : 'The preferences screen has been removed. Pick a real CV file from your device, or open the builder and finish your resume inside SmartJob. Cloud upload will switch on automatically when Supabase keys are configured.',
                        textAlign: TextAlign.center,
                        style: textTheme.bodyLarge?.copyWith(
                          color: AppColors.subtext(Theme.of(context).brightness),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              LayoutBuilder(
                builder: (context, constraints) {
                  final uploadCard = _ModeCard(
                    icon: LucideIcons.uploadCloud,
                    title: 'Upload my CV',
                    subtitle: hasCloudUpload
                        ? 'Choose a real PDF, DOC, or DOCX file and upload it into SmartJob cloud storage.'
                        : 'Choose a real PDF, DOC, or DOCX file from your device and connect it locally now.',
                    selected: isUpload,
                    onTap: () => setState(() => _cvMode = _CvMode.upload),
                  );
                  final builderCard = _ModeCard(
                    icon: LucideIcons.penTool,
                    title: 'Build inside SmartJob',
                    subtitle:
                        'Skip uploading and create a structured resume draft directly in the SmartJob builder.',
                    selected: !isUpload,
                    onTap: () => setState(() => _cvMode = _CvMode.build),
                  );

                  if (constraints.maxWidth < 760) {
                    return Column(
                      children: [
                        uploadCard,
                        const SizedBox(height: 16),
                        builderCard,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: uploadCard),
                      const SizedBox(width: 16),
                      Expanded(child: builderCard),
                    ],
                  );
                },
              ).animate().fade(delay: 80.ms),
              const SizedBox(height: 20),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: isUpload
                    ? _buildUploadPanel(context, hasCloudUpload: hasCloudUpload)
                    : _buildBuilderPanel(),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: isUpload
                    ? (_selectedFile == null || _isPickingFile || _isUploading
                        ? null
                        : _finishUploadFlow)
                    : _finishBuilderFlow,
                child: Text(
                  isUpload
                      ? _isUploading
                          ? 'Uploading CV...'
                          : hasCloudUpload
                              ? 'Upload CV and continue'
                              : 'Finish upload'
                      : 'Open CV builder',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUploadPanel(
    BuildContext context, {
    required bool hasCloudUpload,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final selectedFileName = _selectedFile?.name;
    final selectedFileSize = _selectedFile?.size == null ? null : _formatFileSize(_selectedFile?.size ?? 0);

    return SmartJobPanel(
      key: const ValueKey('real-upload-panel'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SmartJobSectionHeader(
            title: hasCloudUpload ? 'Real CV upload' : 'Real CV connection',
            subtitle: hasCloudUpload
                ? 'Pick a real file from your device. Supported formats: PDF, DOC, and DOCX. SmartJob will upload it to your backend storage.'
                : 'Pick a real file from your device. Supported formats: PDF, DOC, and DOCX. SmartJob will connect it locally until cloud storage is configured.',
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _isPickingFile || _isUploading ? null : _pickCvFile,
            icon: const Icon(LucideIcons.folderSearch2),
            label: Text(
              selectedFileName ??
                  (_isPickingFile ? 'Opening file picker...' : 'Choose CV file'),
            ),
          ),
          if (selectedFileName != null) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SmartJobMetricPill(
                  label: 'file',
                  value: selectedFileName,
                  icon: LucideIcons.fileText,
                ),
                if (selectedFileSize != null)
                  SmartJobMetricPill(
                    label: 'size',
                    value: selectedFileSize,
                    icon: LucideIcons.hardDrive,
                  ),
                SmartJobMetricPill(
                  label: 'storage',
                  value: hasCloudUpload ? 'Cloud sync on' : 'Local only',
                  icon: hasCloudUpload ? LucideIcons.uploadCloud : LucideIcons.laptop,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.teal.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(LucideIcons.badgeCheck, color: AppColors.teal),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      hasCloudUpload
                          ? 'CV file selected successfully. SmartJob will upload $selectedFileName to your backend storage as soon as you continue.'
                          : 'CV file connected successfully. SmartJob will use $selectedFileName as your uploaded resume entry now, and cloud upload will be available once Supabase is configured.',
                      style: textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBuilderPanel() {
    return const SmartJobPanel(
      key: ValueKey('builder-panel'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SmartJobSectionHeader(
            title: 'Start with the builder',
            subtitle:
                'We will create your builder workspace now and take you directly to the CV editor to add sections at your own pace.',
          ),
          SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SmartJobMetricPill(
                label: 'sections',
                value: '10',
                icon: LucideIcons.layoutGrid,
              ),
              SmartJobMetricPill(
                label: 'templates',
                value: '5',
                icon: LucideIcons.layoutTemplate,
              ),
              SmartJobMetricPill(
                label: 'autosave',
                value: 'On',
                icon: LucideIcons.save,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickCvFile() async {
    setState(() => _isPickingFile = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'doc', 'docx'],
        withData: true,
      );

      if (!mounted) {
        return;
      }

      final selectedFile = result?.files.single;
      if (selectedFile == null) {
        setState(() => _isPickingFile = false);
        return;
      }

      final hasBytes = selectedFile.bytes != null && selectedFile.bytes!.isNotEmpty;
      final hasStream = selectedFile.readStream != null;
      if (!hasBytes && !hasStream) {
        setState(() => _isPickingFile = false);
        _showMessage('SmartJob could not read that file. Please choose another CV.');
        return;
      }

      setState(() {
        _cvMode = _CvMode.upload;
        _selectedFile = selectedFile;
        _isPickingFile = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isPickingFile = false);
      _showMessage('Opening the file picker failed. Please try again.');
    }
  }

  String _formatFileSize(int sizeInBytes) {
    if (sizeInBytes >= 1024 * 1024) {
      return '${(sizeInBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (sizeInBytes >= 1024) {
      return '${(sizeInBytes / 1024).toStringAsFixed(0)} KB';
    }
    return '$sizeInBytes B';
  }

  Future<void> _finishUploadFlow() async {
    final selectedFile = _selectedFile;
    if (selectedFile == null || _isUploading) {
      return;
    }

    setState(() => _isUploading = true);

    final remoteSync = ref.read(smartJobRemoteSyncProvider);
    var remoteStoragePath = '';

    try {
      final bytes = await _readSelectedFileBytes(selectedFile);
      if (bytes == null || bytes.isEmpty) {
        _showMessage('SmartJob could not read that file for upload. Please choose another CV.');
        return;
      }

      if (remoteSync != null) {
        final email = ref.read(smartJobControllerProvider).profile.email;
        remoteStoragePath = await remoteSync.uploadCv(
          email: email,
          fileName: selectedFile.name,
          bytes: bytes,
        );
      }

      if (!mounted) {
        return;
      }

      ref.read(smartJobControllerProvider.notifier).completeOnboardingFromUpload(
            fileName: selectedFile.name,
            targetRoles: _selectedRoles,
            preferredLocations: _selectedLocations,
            remoteStoragePath: remoteStoragePath,
            uploadedCvBase64: _isPdfFile(selectedFile.name) ? base64Encode(bytes) : '',
            uploadedCvMimeType: _mimeTypeForFileName(selectedFile.name),
          );
      context.go(AppRoute.main);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage('Uploading your CV failed. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
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
    return streamedBytes.isEmpty ? null : streamedBytes;
  }

  bool _isPdfFile(String fileName) {
    return fileName.toLowerCase().endsWith('.pdf');
  }

  String _mimeTypeForFileName(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) {
      return 'application/pdf';
    }
    if (lower.endsWith('.doc')) {
      return 'application/msword';
    }
    if (lower.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    return 'application/octet-stream';
  }

  void _finishBuilderFlow() {
    ref.read(smartJobControllerProvider.notifier).beginBuilderSetup(
          targetRoles: _selectedRoles,
          preferredLocations: _selectedLocations,
        );
    context.go(AppRoute.cvSetup);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.midnight
                : AppColors.surface(Theme.of(context).brightness).withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: selected
                  ? AppColors.midnight
                  : AppColors.stroke(Theme.of(context).brightness),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: selected ? Colors.white : AppColors.text(Theme.of(context).brightness),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: selected ? Colors.white : AppColors.text(Theme.of(context).brightness),
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: selected
                          ? Colors.white.withValues(alpha: 0.86)
                          : AppColors.subtext(Theme.of(context).brightness),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}



