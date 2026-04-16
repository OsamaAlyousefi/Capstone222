import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class AiCvResult {
  const AiCvResult({
    required this.fullName,
    required this.headline,
    required this.tagline,
    required this.skills,
    required this.experience,
    required this.education,
    required this.projects,
  });

  final String fullName;
  final String headline;
  final String tagline;
  final List<String> skills;
  final List<String> experience;
  final List<String> education;
  final List<String> projects;
}

class GroqCvService {
  static const _endpoint =
      'https://api.groq.com/openai/v1/chat/completions';

  static const _systemPrompt = '''
You are a professional CV writer. Analyze the user's paragraph and extract
structured information. Return ONLY valid JSON matching the schema.
Professionalize the wording while staying truthful to the input. If a field
is missing from the paragraph, return an empty string or empty array.

Return this exact JSON structure:
{
  "fullName": "",
  "headline": "",
  "tagline": "",
  "skills": [],
  "experience": [],
  "education": [],
  "projects": []
}

Field rules:
- fullName: The person's full name if mentioned, otherwise empty string
- headline: A short professional title (e.g., "Flutter Developer", "Marketing Specialist")
- tagline: A one-sentence professional summary
- skills: Array of individual skill strings (technical and soft skills)
- experience: Array of strings, each string is one job/role formatted like
  "Job Title at Company (dates): description of responsibilities"
- education: Array of strings, each like "Degree at Institution (dates)"
- projects: Array of strings, each like "Project Name: description"
''';

  static const _models = [
    'llama-3.3-70b-versatile',
    'llama-3.1-8b-instant',
  ];

  static Future<AiCvResult> generateCvFromText(String userParagraph) async {
    final apiKey = dotenv.env['GROQ_API_KEY'];
    debugPrint('[Groq] KEY LOADED: ${apiKey != null && apiKey.isNotEmpty}, '
        'LENGTH: ${apiKey?.length ?? 0}');

    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('GROQ_API_KEY is not set. Add it to assets/.env');
    }

    final url = Uri.parse(_endpoint);

    for (var i = 0; i < _models.length; i++) {
      final model = _models[i];
      debugPrint('[Groq] Trying model: $model');

      final requestBody = jsonEncode({
        'model': model,
        'messages': [
          {'role': 'system', 'content': _systemPrompt},
          {'role': 'user', 'content': userParagraph},
        ],
        'temperature': 0.3,
        'response_format': {'type': 'json_object'},
        'max_tokens': 2000,
      });

      final http.Response response;
      try {
        response = await http
            .post(
              url,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $apiKey',
              },
              body: requestBody,
            )
            .timeout(const Duration(seconds: 30));
      } on TimeoutException {
        debugPrint('[Groq] Request timed out for model $model');
        if (i < _models.length - 1) continue;
        throw Exception(
            'Request timed out after 30 seconds. Check your internet connection and try again.');
      } catch (e) {
        debugPrint('[Groq] Network error for model $model: $e');
        if (i < _models.length - 1) continue;
        throw Exception('Network error: $e');
      }

      debugPrint('[Groq] Status: ${response.statusCode}');
      debugPrint('[Groq] Body (first 500 chars): '
          '${response.body.length > 500 ? response.body.substring(0, 500) : response.body}');

      // 404 = model not available — try next.
      if (response.statusCode == 404 && i < _models.length - 1) {
        debugPrint('[Groq] Model $model not found, trying next...');
        continue;
      }

      if (response.statusCode != 200) {
        final detail = _extractErrorDetail(response.body);
        final message = switch (response.statusCode) {
          400 => 'Bad request — $detail',
          401 || 403 => 'Invalid or unauthorized API key. $detail',
          404 => 'Model not found. $detail',
          429 => 'Rate limit reached. Please wait a moment and try again. $detail',
          >= 500 => 'Groq server error (${response.statusCode}). $detail',
          _ => 'Groq API error (${response.statusCode}). $detail',
        };
        debugPrint('[Groq] ERROR: $message');

        // Quota/rate error on this model — try next.
        if (response.statusCode == 429 && i < _models.length - 1) {
          debugPrint('[Groq] Trying next model...');
          continue;
        }
        throw Exception(message);
      }

      return _parseResponse(response.body);
    }

    throw Exception('All Groq models failed. Please try again later.');
  }

  // ── Response parsing (OpenAI-compatible format) ──────────────────────

  static AiCvResult _parseResponse(String responseBody) {
    final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
    final choices = decoded['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      debugPrint('[Groq] No choices in response');
      throw Exception(
          'Groq returned no results. Please try rephrasing your paragraph.');
    }

    final message =
        choices[0]['message'] as Map<String, dynamic>? ?? const {};
    final content = (message['content'] as String?) ?? '';
    debugPrint('[Groq] Content length: ${content.length}');

    if (content.isEmpty) {
      debugPrint('[Groq] Empty content in response');
      throw Exception('Groq returned an empty response. Please try again.');
    }

    final Map<String, dynamic> parsed;
    try {
      parsed = jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[Groq] JSON parse error: $e');
      debugPrint('[Groq] Raw content: '
          '${content.length > 300 ? content.substring(0, 300) : content}');
      throw Exception('Invalid JSON from Groq. Please try again.');
    }

    return AiCvResult(
      fullName: (parsed['fullName'] as String?) ?? '',
      headline: (parsed['headline'] as String?) ?? '',
      tagline: (parsed['tagline'] as String?) ?? '',
      skills: _toStringList(parsed['skills']),
      experience: _toStringList(parsed['experience']),
      education: _toStringList(parsed['education']),
      projects: _toStringList(parsed['projects']),
    );
  }

  static String _extractErrorDetail(String body) {
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final error = decoded['error'] as Map<String, dynamic>?;
      if (error != null) {
        return (error['message'] as String?) ?? body;
      }
    } catch (_) {}
    return body.length > 200 ? '${body.substring(0, 200)}...' : body;
  }

  static List<String> _toStringList(dynamic value) {
    if (value is! List) return const [];
    return value
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
}
