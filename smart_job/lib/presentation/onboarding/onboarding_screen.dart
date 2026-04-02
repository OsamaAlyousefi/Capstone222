import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../application/controllers/smart_job_controller.dart';
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
  String? _selectedFileName;
  String? _selectedFileSizeLabel;
  bool _isPickingFile = false;

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
                        'The preferences screen has been removed. Pick a real CV file from your device, or open the builder and finish your resume inside SmartJob.',
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
                    subtitle:
                        'Choose a real PDF, DOC, or DOCX file from your device and bring it into SmartJob.',
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
                child: isUpload ? _buildUploadPanel(context) : _buildBuilderPanel(),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: isUpload
                    ? (_selectedFileName == null ? null : _finishUploadFlow)
                    : _finishBuilderFlow,
                child: Text(isUpload ? 'Finish upload' : 'Open CV builder'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUploadPanel(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SmartJobPanel(
      key: const ValueKey('real-upload-panel'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SmartJobSectionHeader(
            title: 'Real CV upload',
            subtitle: 'Pick a real file from your device. Supported formats: PDF, DOC, and DOCX.',
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _isPickingFile ? null : _pickCvFile,
            icon: Icon(
              LucideIcons.folderSearch2,
            ),
            label: Text(
              _selectedFileName == null
                  ? (_isPickingFile ? 'Opening file picker...' : 'Choose CV file')
                  : _selectedFileName!,
            ),
          ),
          if (_selectedFileName != null) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SmartJobMetricPill(
                  label: 'file',
                  value: _selectedFileName!,
                  icon: LucideIcons.fileText,
                ),
                if (_selectedFileSizeLabel != null)
                  SmartJobMetricPill(
                    label: 'size',
                    value: _selectedFileSizeLabel!,
                    icon: LucideIcons.hardDrive,
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
                      'CV file connected successfully. SmartJob will use $_selectedFileName as your uploaded resume entry and keep the upload state in your account.',
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
      final hasPath = selectedFile.path != null && selectedFile.path!.isNotEmpty;
      if (!hasBytes && !hasPath) {
        setState(() => _isPickingFile = false);
        _showMessage('SmartJob could not read that file. Please choose another CV.');
        return;
      }

      setState(() {
        _cvMode = _CvMode.upload;
        _selectedFileName = selectedFile.name;
        _selectedFileSizeLabel = _formatFileSize(selectedFile.size);
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

  void _finishUploadFlow() {
    ref.read(smartJobControllerProvider.notifier).completeOnboardingFromUpload(
          fileName: _selectedFileName!,
          targetRoles: _selectedRoles,
          preferredLocations: _selectedLocations,
        );
    context.go(AppRoute.main);
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


