import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────────────────
// Template enum
// ─────────────────────────────────────────────────────────────────

enum CvTemplate {
  modern,
  classic,
  minimal;

  String get label => switch (this) {
        modern => 'Modern',
        classic => 'Classic',
        minimal => 'Minimal',
      };

  static CvTemplate fromName(String name) {
    for (final t in values) {
      if (t.name == name || t.label == name) return t;
    }
    return modern;
  }
}

// ─────────────────────────────────────────────────────────────────
// Data container passed into the template builder
// ─────────────────────────────────────────────────────────────────

class CvPreviewData {
  const CvPreviewData({
    required this.name,
    required this.title,
    required this.summary,
    required this.contact,
    required this.sectionOrder,
    required this.items,
  });

  final String name;
  final String title;
  final String summary;
  final List<String> contact;
  final List<String> sectionOrder;
  final Map<String, List<String>> items;
}

// ─────────────────────────────────────────────────────────────────
// Template builder — dispatches to the correct layout
// ─────────────────────────────────────────────────────────────────

class CvTemplateBuilder extends StatelessWidget {
  const CvTemplateBuilder({
    super.key,
    required this.template,
    required this.data,
    required this.accentColor,
    required this.fontFamily,
    required this.zoom,
  });

  final CvTemplate template;
  final CvPreviewData data;
  final Color accentColor;
  final String fontFamily;
  final double zoom;

  @override
  Widget build(BuildContext context) {
    return switch (template) {
      CvTemplate.modern => _ModernTemplate(
          data: data,
          accentColor: accentColor,
          fontFamily: fontFamily,
          zoom: zoom,
        ),
      CvTemplate.classic => _ClassicTemplate(
          data: data,
          accentColor: accentColor,
          zoom: zoom,
        ),
      CvTemplate.minimal => _MinimalTemplate(
          data: data,
          zoom: zoom,
        ),
    };
  }
}

// ─────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────

TextStyle _resolve(String family, TextStyle style) {
  return switch (family) {
    'Roboto' => GoogleFonts.roboto(textStyle: style),
    'Playfair Display' => GoogleFonts.playfairDisplay(textStyle: style),
    'Georgia' => GoogleFonts.sourceSerif4(textStyle: style),
    'Merriweather' => GoogleFonts.merriweather(textStyle: style),
    'Lato' => GoogleFonts.lato(textStyle: style),
    'Poppins' => GoogleFonts.poppins(textStyle: style),
    _ => GoogleFonts.inter(textStyle: style),
  };
}

String _sectionLabel(String key) {
  return switch (key) {
    'summary' => 'Summary',
    'skills' => 'Skills',
    'experience' => 'Experience',
    'education' => 'Education',
    'projects' => 'Projects',
    _ => key.replaceAll('_', ' '),
  };
}

Widget _contactRow(List<String> contact, TextStyle style) {
  if (contact.isEmpty) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Text(
      contact.join('  |  '),
      style: style,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    ),
  );
}

Widget _skillChips(
  List<String> skills, {
  required Color accent,
  required TextStyle style,
}) {
  return Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      for (final skill in skills)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(skill, style: style),
        ),
    ],
  );
}

Widget _sectionItems(
  List<String> items,
  TextStyle body, {
  bool bullets = true,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final item in items) ...[
        Text(
          bullets ? '•  $item' : item,
          style: body,
        ),
        const SizedBox(height: 4),
      ],
    ],
  );
}

/// Wraps the CV card in a scrollable A4-proportioned container.
Widget _cvShell({
  required double zoom,
  required EdgeInsets padding,
  required BoxDecoration decoration,
  required Widget child,
}) {
  return Padding(
    padding: const EdgeInsets.all(16),
    child: Scrollbar(
      child: SingleChildScrollView(
        child: Center(
          child: Container(
            width: 540 * zoom,
            padding: padding,
            decoration: decoration,
            child: child,
          ),
        ),
      ),
    ),
  );
}

BoxDecoration _paperDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(6),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.12),
        blurRadius: 32,
        offset: const Offset(0, 12),
      ),
    ],
  );
}

// ═════════════════════════════════════════════════════════════════
// Template 1 — MODERN (default)
// Sans-serif, blue accents, left-aligned, single-column
// ═════════════════════════════════════════════════════════════════

class _ModernTemplate extends StatelessWidget {
  const _ModernTemplate({
    required this.data,
    required this.accentColor,
    required this.fontFamily,
    required this.zoom,
  });

  final CvPreviewData data;
  final Color accentColor;
  final String fontFamily;
  final double zoom;

  @override
  Widget build(BuildContext context) {
    final heading = _resolve(
      fontFamily,
      const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          height: 1.15,
          color: Colors.black),
    );
    final subtitle = _resolve(
      fontFamily,
      TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: accentColor,
          height: 1.3),
    );
    final sectionHead = _resolve(
      fontFamily,
      TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: accentColor),
    );
    final body = _resolve(
      fontFamily,
      const TextStyle(fontSize: 10.5, height: 1.5, color: Color(0xFF1A1A1A)),
    );
    final contactStyle = _resolve(
      fontFamily,
      const TextStyle(
          fontSize: 9.5, color: Color(0xFF555555), height: 1.3),
    );
    final chipStyle = _resolve(
      fontFamily,
      TextStyle(fontSize: 9.5, color: accentColor, fontWeight: FontWeight.w500),
    );

    return _cvShell(
      zoom: zoom,
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 32),
      decoration: _paperDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Text(data.name, style: heading),
          const SizedBox(height: 4),
          Text(data.title, style: subtitle),
          _contactRow(data.contact, contactStyle),
          const SizedBox(height: 20),

          // ── Sections ──
          for (final section in data.sectionOrder) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(bottom: 5),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                      color: accentColor.withValues(alpha: 0.25)),
                ),
              ),
              child: Text(
                _sectionLabel(section).toUpperCase(),
                style: sectionHead,
              ),
            ),
            const SizedBox(height: 8),
            if (section == 'summary')
              Text(data.summary, style: body)
            else if (section == 'skills')
              _skillChips(
                data.items['skills'] ?? [],
                accent: accentColor,
                style: chipStyle,
              )
            else
              _sectionItems(data.items[section] ?? [], body),
            const SizedBox(height: 18),
          ],
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// Template 2 — CLASSIC
// Serif typography, centered header, gray/black, horizontal rules
// ═════════════════════════════════════════════════════════════════

class _ClassicTemplate extends StatelessWidget {
  const _ClassicTemplate({
    required this.data,
    required this.accentColor,
    required this.zoom,
  });

  final CvPreviewData data;
  final Color accentColor;
  final double zoom;

  @override
  Widget build(BuildContext context) {
    const serif = 'Merriweather';
    final heading = _resolve(
      serif,
      const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          height: 1.2,
          color: Colors.black),
    );
    final subtitle = _resolve(
      serif,
      const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: Color(0xFF444444),
          height: 1.4),
    );
    final sectionHead = _resolve(
      serif,
      const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: Color(0xFF222222)),
    );
    final body = _resolve(
      serif,
      const TextStyle(fontSize: 10.5, height: 1.55, color: Color(0xFF333333)),
    );
    final contactStyle = _resolve(
      serif,
      const TextStyle(
          fontSize: 9.5, color: Color(0xFF666666), height: 1.3),
    );
    final chipStyle = _resolve(
      serif,
      const TextStyle(
          fontSize: 9.5,
          color: Color(0xFF444444),
          fontWeight: FontWeight.w500),
    );

    return _cvShell(
      zoom: zoom,
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 36),
      decoration: _paperDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Centered header ──
          Text(data.name, style: heading, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(data.title, style: subtitle, textAlign: TextAlign.center),
          if (data.contact.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              data.contact.join('  •  '),
              style: contactStyle,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 14),
          const Divider(color: Color(0xFFBBBBBB), thickness: 1),
          const SizedBox(height: 14),

          // ── Sections (left-aligned content) ──
          for (final section in data.sectionOrder) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _sectionLabel(section).toUpperCase(),
                style: sectionHead,
              ),
            ),
            const SizedBox(height: 2),
            const Divider(color: Color(0xFFDDDDDD), thickness: 0.5),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: section == 'summary'
                  ? Text(data.summary, style: body)
                  : section == 'skills'
                      ? _skillChips(
                          data.items['skills'] ?? [],
                          accent: const Color(0xFF888888),
                          style: chipStyle,
                        )
                      : _sectionItems(
                          data.items[section] ?? [], body,
                          bullets: false),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// Template 3 — MINIMAL
// Ultra-clean, Inter light, pure black/white/gray, no color
// ═════════════════════════════════════════════════════════════════

class _MinimalTemplate extends StatelessWidget {
  const _MinimalTemplate({
    required this.data,
    required this.zoom,
  });

  final CvPreviewData data;
  final double zoom;

  @override
  Widget build(BuildContext context) {
    final heading = _resolve(
      'Inter',
      const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w300,
          height: 1.2,
          color: Colors.black,
          letterSpacing: 1.2),
    );
    final subtitle = _resolve(
      'Inter',
      const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w400,
          color: Color(0xFF666666),
          height: 1.4),
    );
    final sectionHead = _resolve(
      'Inter',
      const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
          color: Color(0xFF999999)),
    );
    final body = _resolve(
      'Inter',
      const TextStyle(
          fontSize: 10.5,
          height: 1.55,
          color: Color(0xFF333333),
          fontWeight: FontWeight.w300),
    );
    final contactStyle = _resolve(
      'Inter',
      const TextStyle(
          fontSize: 9, color: Color(0xFF999999), height: 1.3),
    );
    final chipStyle = _resolve(
      'Inter',
      const TextStyle(
          fontSize: 9.5,
          color: Color(0xFF555555),
          fontWeight: FontWeight.w400),
    );

    return _cvShell(
      zoom: zoom,
      padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 40),
      decoration: _paperDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Text(data.name, style: heading),
          const SizedBox(height: 6),
          Text(data.title, style: subtitle),
          _contactRow(data.contact, contactStyle),
          const SizedBox(height: 28),

          // ── Sections ──
          for (final section in data.sectionOrder) ...[
            Text(
              _sectionLabel(section).toUpperCase(),
              style: sectionHead,
            ),
            const SizedBox(height: 8),
            if (section == 'summary')
              Text(data.summary, style: body)
            else if (section == 'skills')
              _skillChips(
                data.items['skills'] ?? [],
                accent: const Color(0xFFEEEEEE),
                style: chipStyle,
              )
            else
              _sectionItems(data.items[section] ?? [], body, bullets: false),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }
}
