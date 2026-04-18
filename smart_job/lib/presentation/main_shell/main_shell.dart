import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../router/app_router.dart';
import '../../theme/app_colors.dart';
import '../shared/widgets/smart_job_ui.dart';

class MainShell extends StatelessWidget {
  const MainShell({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final destinations = const [
      _ShellDestination(AppRoute.main, 'Home', LucideIcons.sparkles),
      _ShellDestination(AppRoute.cv, 'CV', LucideIcons.fileSpreadsheet),
      _ShellDestination(
        AppRoute.applications,
        'Applications',
        LucideIcons.barChart3,
      ),
      _ShellDestination(AppRoute.profile, 'Profile', LucideIcons.user),
    ];

    return Scaffold(
      body: SmartJobBackground(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: KeyedSubtree(
                key: ValueKey(location),
                child: child,
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: SafeArea(
                top: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 980),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surface(Theme.of(context).brightness)
                            .withValues(alpha: 0.96),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: AppColors.stroke(Theme.of(context).brightness),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          for (final destination in destinations)
                            Expanded(
                              child: _ShellButton(
                                destination: destination,
                                selected: location == destination.path,
                                onTap: () => context.go(destination.path),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShellDestination {
  const _ShellDestination(this.path, this.label, this.icon);

  final String path;
  final String label;
  final IconData icon;
}

class _ShellButton extends StatefulWidget {
  const _ShellButton({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _ShellDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_ShellButton> createState() => _ShellButtonState();
}

class _ShellButtonState extends State<_ShellButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(22),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            decoration: BoxDecoration(
              color: widget.selected
                  ? AppColors.midnight
                  : _hovered
                      ? AppColors.surfaceMuted(brightness)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.destination.icon,
                  size: 18,
                  color: widget.selected
                      ? Colors.white
                      : AppColors.subtext(brightness),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.destination.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: widget.selected
                            ? Colors.white
                            : AppColors.subtext(brightness),
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
