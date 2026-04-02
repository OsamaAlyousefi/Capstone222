import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../application/controllers/auth_controller.dart';
import '../../application/controllers/smart_job_controller.dart';
import '../../router/app_router.dart';
import '../../theme/app_colors.dart';
import '../shared/widgets/smart_job_ui.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(
      smartJobControllerProvider.select((state) => state.profile),
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SmartJobPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          SmartJobAvatar(label: profile.photoLabel, size: 72),
                          Positioned(
                            bottom: -6,
                            right: -6,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: AppColors.midnight,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                LucideIcons.camera,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile.fullName,
                              style: Theme.of(context).textTheme.displayMedium,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              profile.headline,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              profile.smartInboxAlias,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.subtext(
                                      Theme.of(context).brightness,
                                    ),
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      SmartJobMetricPill(
                        label: 'location',
                        value: profile.location,
                        icon: LucideIcons.mapPin,
                      ),
                      SmartJobMetricPill(
                        label: 'CV',
                        value: profile.hasUploadedCv ? 'Ready' : 'Pending',
                        icon: LucideIcons.fileCheck2,
                      ),
                    ],
                  ),
                ],
              ),
            ).animate().fade().slideY(begin: 0.04),
            const SizedBox(height: 18),
            SmartJobPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SmartJobSectionHeader(
                    title: 'Personal information',
                    subtitle: 'Core account details and profile editing.',
                    trailing: TextButton(
                      onPressed: () => _showEditProfileSheet(context, ref),
                      child: const Text('Edit'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _InfoRow(label: 'Email', value: profile.email),
                  const SizedBox(height: 10),
                  _InfoRow(label: 'Phone', value: profile.phoneNumber),
                  const SizedBox(height: 10),
                  _InfoRow(label: 'Location', value: profile.location),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Password reset link sent in prototype mode.'),
                        ),
                      );
                    },
                    icon: const Icon(LucideIcons.keyRound),
                    label: const Text('Reset password'),
                  ),
                ],
              ),
            ).animate().fade(delay: 80.ms),
            const SizedBox(height: 18),
            SmartJobPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SmartJobSectionHeader(
                    title: 'Job preferences',
                    subtitle: 'Target roles, salary goal, and notifications.',
                    trailing: TextButton(
                      onPressed: () => _showJobPreferencesSheet(context, ref),
                      child: const Text('Adjust'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final role in profile.jobPreferences.targetRoles)
                        Chip(label: Text(role)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _InfoRow(
                    label: 'Salary goal',
                    value: profile.jobPreferences.salaryRange,
                  ),
                  const SizedBox(height: 14),
                  SwitchListTile.adaptive(
                    value: profile.notificationsEnabled,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Matching job notifications'),
                    subtitle: const Text('Get alerts for new recommendations and reminders'),
                    onChanged: ref
                        .read(smartJobControllerProvider.notifier)
                        .updateNotificationPreference,
                  ),
                ],
              ),
            ).animate().fade(delay: 120.ms),
            const SizedBox(height: 18),
            SmartJobPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SmartJobSectionHeader(
                    title: 'Theme and privacy',
                    subtitle: 'Control appearance and account visibility.',
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _ThemeChip(
                        label: 'System',
                        selected: profile.themeMode == ThemeMode.system,
                        onTap: () => ref
                            .read(smartJobControllerProvider.notifier)
                            .updateThemeMode(ThemeMode.system),
                      ),
                      _ThemeChip(
                        label: 'Light',
                        selected: profile.themeMode == ThemeMode.light,
                        onTap: () => ref
                            .read(smartJobControllerProvider.notifier)
                            .updateThemeMode(ThemeMode.light),
                      ),
                      _ThemeChip(
                        label: 'Dark',
                        selected: profile.themeMode == ThemeMode.dark,
                        onTap: () => ref
                            .read(smartJobControllerProvider.notifier)
                            .updateThemeMode(ThemeMode.dark),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SwitchListTile.adaptive(
                    value: profile.privacyModeEnabled,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Privacy mode'),
                    subtitle: const Text('Hide personal details from future public profile surfaces'),
                    onChanged: ref
                        .read(smartJobControllerProvider.notifier)
                        .updatePrivacyMode,
                  ),
                ],
              ),
            ).animate().fade(delay: 160.ms),
            const SizedBox(height: 18),
            SmartJobPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SmartJobSectionHeader(
                    title: 'Support',
                    subtitle: 'Capstone-friendly placeholders for real product extensions.',
                  ),
                  const SizedBox(height: 14),
                  const _InfoRow(
                    label: 'Help center',
                    value: 'In-app guidance for CV, feed, and inbox questions',
                  ),
                  const SizedBox(height: 10),
                  const _InfoRow(
                    label: 'SmartJob email',
                    value: 'support@smartjob.app',
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Support request drafted in prototype mode.'),
                        ),
                      );
                    },
                    icon: const Icon(LucideIcons.lifeBuoy),
                    label: const Text('Contact support'),
                  ),
                ],
              ),
            ).animate().fade(delay: 200.ms),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ref.read(authControllerProvider.notifier).signOut();
                      ref.read(smartJobControllerProvider.notifier).resetForLogout();
                      context.go(AppRoute.login);
                    },
                    icon: const Icon(LucideIcons.logOut),
                    label: const Text('Logout'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger,
                    ),
                    onPressed: () {
                      ref.read(authControllerProvider.notifier).signOut();
                      ref.read(smartJobControllerProvider.notifier).deleteAccount();
                      context.go(AppRoute.login);
                    },
                    icon: const Icon(LucideIcons.trash2),
                    label: const Text('Delete account'),
                  ),
                ),
              ],
            ).animate().fade(delay: 240.ms),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditProfileSheet(BuildContext context, WidgetRef ref) async {
    final profile = ref.read(smartJobControllerProvider).profile;
    final nameController = TextEditingController(text: profile.fullName);
    final phoneController = TextEditingController(text: profile.phoneNumber);
    final locationController = TextEditingController(text: profile.location);
    final headlineController = TextEditingController(text: profile.headline);

    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.viewInsetsOf(context).bottom + 16,
          ),
          child: SmartJobPanel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SmartJobSectionHeader(
                  title: 'Edit profile',
                  subtitle: 'Update the details reflected across SmartJob.',
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Full name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'Phone number'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: locationController,
                  decoration: const InputDecoration(labelText: 'Location'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: headlineController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Headline'),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    ref.read(smartJobControllerProvider.notifier).updateProfileDetails(
                          fullName: nameController.text.trim(),
                          phoneNumber: phoneController.text.trim(),
                          location: locationController.text.trim(),
                          headline: headlineController.text.trim(),
                        );
                    Navigator.of(context).pop();
                  },
                  child: const Text('Save profile'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showJobPreferencesSheet(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final profile = ref.read(smartJobControllerProvider).profile;
    final roleController = TextEditingController(
      text: profile.jobPreferences.targetRoles.join(', '),
    );
    final salaryController = TextEditingController(
      text: profile.jobPreferences.salaryRange,
    );

    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.viewInsetsOf(context).bottom + 16,
          ),
          child: SmartJobPanel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SmartJobSectionHeader(
                  title: 'Job preferences',
                  subtitle: 'Tune roles and salary goals for stronger recommendations.',
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: roleController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Target roles',
                    hintText: 'Flutter Developer, Product Designer',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: salaryController,
                  decoration: const InputDecoration(
                    labelText: 'Salary range',
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    ref.read(smartJobControllerProvider.notifier).updateJobPreferences(
                          targetRoles: roleController.text
                              .split(',')
                              .map((item) => item.trim())
                              .where((item) => item.isNotEmpty)
                              .toList(),
                          salaryRange: salaryController.text.trim(),
                        );
                    Navigator.of(context).pop();
                  },
                  child: const Text('Save preferences'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

class _ThemeChip extends StatelessWidget {
  const _ThemeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SmartJobFilterChip(
      label: label,
      selected: selected,
      onTap: onTap,
    );
  }
}
