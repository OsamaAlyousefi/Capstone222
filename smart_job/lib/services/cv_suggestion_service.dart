import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Generates ONE AI-powered CV improvement suggestion using Groq.
/// Cached in memory — only calls the API once per session.
class CvSuggestionService {
  static const _endpoint =
      'https://api.groq.com/openai/v1/chat/completions';
  static const _models = [
    'llama-3.3-70b-versatile',
    'llama-3.1-8b-instant',
  ];

  static String? _cached;
  static bool _hasAttempted = false;

  /// Returns the cached AI suggestion, or null.
  static String? get cached => _cached;

  /// Generates a single CV improvement suggestion. Only calls the API
  /// once per session — subsequent calls return the cached result.
  static Future<String?> generate({
    required String name,
    required List<String> skills,
    required List<String> experience,
    required List<String> education,
    required List<String> projects,
    required String headline,
  }) async {
    if (_hasAttempted) return _cached;
    _hasAttempted = true;

    final apiKey = dotenv.env['GROQ_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) return null;

    final cvData = StringBuffer()
      ..writeln('Name: $name')
      ..writeln('Headline: $headline')
      ..writeln('Skills: ${skills.take(10).join(", ")}')
      ..writeln('Experience: ${experience.take(3).join("; ")}')
      ..writeln('Education: ${education.take(2).join("; ")}')
      ..writeln('Projects: ${projects.take(3).join("; ")}');

    const systemPrompt =
        'You are a professional CV reviewer. Given this CV data, '
        'provide exactly ONE specific, actionable suggestion to improve '
        'this CV. Keep it under 30 words. Be specific, not generic. '
        'Respond with ONLY the suggestion text, nothing else.';

    for (final model in _models) {
      try {
        final response = await http
            .post(
              Uri.parse(_endpoint),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $apiKey',
              },
              body: jsonEncode({
                'model': model,
                'messages': [
                  {'role': 'system', 'content': systemPrompt},
                  {'role': 'user', 'content': cvData.toString()},
                ],
                'temperature': 0.4,
                'max_tokens': 80,
              }),
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 404 || response.statusCode == 429) {
          continue;
        }
        if (response.statusCode != 200) {
          debugPrint('[CvSuggestion] Error ${response.statusCode}');
          return null;
        }

        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final choices = decoded['choices'] as List<dynamic>?;
        if (choices == null || choices.isEmpty) return null;

        final message =
            choices[0]['message'] as Map<String, dynamic>? ?? const {};
        final content = (message['content'] as String?)?.trim() ?? '';

        if (content.isNotEmpty) {
          _cached = content;
          debugPrint('[CvSuggestion] Generated: $content');
          return content;
        }
      } on TimeoutException {
        debugPrint('[CvSuggestion] Timed out ($model)');
      } catch (e) {
        debugPrint('[CvSuggestion] Error: $e');
      }
    }

    return null;
  }
}
