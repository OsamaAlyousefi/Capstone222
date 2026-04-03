import 'package:flutter/material.dart';

@immutable
class SmartJobStudioTheme extends ThemeExtension<SmartJobStudioTheme> {
  const SmartJobStudioTheme({
    required this.glassPanel,
    required this.glassStrong,
    required this.glassBorder,
    required this.sidebarGradientTop,
    required this.sidebarGradientBottom,
    required this.highlight,
    required this.mutedHighlight,
    required this.previewPaper,
    required this.exportBar,
  });

  final Color glassPanel;
  final Color glassStrong;
  final Color glassBorder;
  final Color sidebarGradientTop;
  final Color sidebarGradientBottom;
  final Color highlight;
  final Color mutedHighlight;
  final Color previewPaper;
  final Color exportBar;

  @override
  SmartJobStudioTheme copyWith({
    Color? glassPanel,
    Color? glassStrong,
    Color? glassBorder,
    Color? sidebarGradientTop,
    Color? sidebarGradientBottom,
    Color? highlight,
    Color? mutedHighlight,
    Color? previewPaper,
    Color? exportBar,
  }) {
    return SmartJobStudioTheme(
      glassPanel: glassPanel ?? this.glassPanel,
      glassStrong: glassStrong ?? this.glassStrong,
      glassBorder: glassBorder ?? this.glassBorder,
      sidebarGradientTop: sidebarGradientTop ?? this.sidebarGradientTop,
      sidebarGradientBottom: sidebarGradientBottom ?? this.sidebarGradientBottom,
      highlight: highlight ?? this.highlight,
      mutedHighlight: mutedHighlight ?? this.mutedHighlight,
      previewPaper: previewPaper ?? this.previewPaper,
      exportBar: exportBar ?? this.exportBar,
    );
  }

  @override
  SmartJobStudioTheme lerp(ThemeExtension<SmartJobStudioTheme>? other, double t) {
    if (other is! SmartJobStudioTheme) {
      return this;
    }

    return SmartJobStudioTheme(
      glassPanel: Color.lerp(glassPanel, other.glassPanel, t) ?? glassPanel,
      glassStrong: Color.lerp(glassStrong, other.glassStrong, t) ?? glassStrong,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t) ?? glassBorder,
      sidebarGradientTop:
          Color.lerp(sidebarGradientTop, other.sidebarGradientTop, t) ??
              sidebarGradientTop,
      sidebarGradientBottom:
          Color.lerp(sidebarGradientBottom, other.sidebarGradientBottom, t) ??
              sidebarGradientBottom,
      highlight: Color.lerp(highlight, other.highlight, t) ?? highlight,
      mutedHighlight:
          Color.lerp(mutedHighlight, other.mutedHighlight, t) ?? mutedHighlight,
      previewPaper: Color.lerp(previewPaper, other.previewPaper, t) ?? previewPaper,
      exportBar: Color.lerp(exportBar, other.exportBar, t) ?? exportBar,
    );
  }
}
