import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class GeminiCvResult {
  const GeminiCvResult({
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

class GeminiCvService {
  static const _systemPrompt = '''
You are a professional CV writer. Analyze the user's paragraph and extract
structured information. Return ONLY valid JSON matching the schema.
Professionalize the wording while staying truthful to the input. If a field
is missing from the paragraph, return an empty string or empty array.

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
    'gemini-1.5-flash-latest',
    'gemini-1.5-flash',
    'gemini-1.5-flash-8b',
    'gemini-2.0-flash-exp',
    'gemini-2.0-flash',
  ];

  static Future<GeminiCvResult> generateCvFromText(
      String userParagraph) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    debugPrint('[Gemini] KEY LOADED: ${apiKey != null && apiKey.isNotEmpty}, '
        'LENGTH: ${apiKey?.length ?? 0}');

    if (apiKey == null || apiKey.isEmpty) {
      throw Exception(
          'GEMINI_API_KEY is not set. Add it to assets/.env');
    }

    final requestBody = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': userParagraph},
          ],
        },
      ],
      'systemInstruction': {
        'parts': [
          {'text': _systemPrompt},
        ],
      },
      'generationConfig': {
        'temperature': 0.3,
        'responseMimeType': 'application/json',
        'responseSchema': {
          'type': 'OBJECT',
          'properties': {
            'fullName': {'type': 'STRING'},
            'headline': {'type': 'STRING'},
            'tagline': {'type': 'STRING'},
            'skills': {
              'type': 'ARRAY',
              'items': {'type': 'STRING'},
            },
            'experience': {
              'type': 'ARRAY',
              'items': {'type': 'STRING'},
            },
            'education': {
              'type': 'ARRAY',
              'items': {'type': 'STRING'},
            },
            'projects': {
              'type': 'ARRAY',
              'items': {'type': 'STRING'},
            },
          },
          'required': [
            'fullName',
            'headline',
            'tagline',
            'skills',
            'experience',
            'education',
            'projects',
          ],
        },
      },
    });

    // Try each model in order until one succeeds.
    for (var i = 0; i < _models.length; i++) {
      final model = _models[i];
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
      );

      debugPrint('[Gemini] Trying model: $model');
      debugPrint('[Gemini] URL: ${url.toString().replaceAll(apiKey, '***')}');

      final http.Response response;
      try {
        response = await http
            .post(url,
                headers: {'Content-Type': 'application/json'},
                body: requestBody)
            .timeout(const Duration(seconds: 30));
      } on TimeoutException {
        debugPrint('[Gemini] Request timed out for model $model');
        if (i < _models.length - 1) continue;
        throw Exception(
            'Request timed out after 30 seconds. Check your internet connection and try again.');
      } catch (e) {
        debugPrint('[Gemini] Network error for model $model: $e');
        if (i < _models.length - 1) continue;
        throw Exception('Network error: $e');
      }

      debugPrint('[Gemini] Status: ${response.statusCode}');
      debugPrint('[Gemini] Body (first 500 chars): '
          '${response.body.length > 500 ? response.body.substring(0, 500) : response.body}');

      // 404 means this model doesn't exist — try the next one.
      if (response.statusCode == 404 && i < _models.length - 1) {
        debugPrint('[Gemini] Model $model not found, trying next...');
        continue;
      }

      if (response.statusCode != 200) {
        final detail = _extractErrorDetail(response.body);
        final message = switch (response.statusCode) {
          400 => 'Bad request — $detail',
          401 || 403 => 'Invalid or unauthorized API key. $detail',
          404 => 'Model not found. $detail',
          429 => 'Rate limit reached. Please wait a moment and try again. $detail',
          >= 500 => 'Gemini server error (${response.statusCode}). $detail',
          _ => 'Gemini API error (${response.statusCode}). $detail',
        };
        debugPrint('[Gemini] ERROR: $message');
        throw Exception(message);
      }

      // Success — parse the response.
      return _parseResponse(response.body);
    }

    // Should never reach here, but just in case.
    throw Exception('All Gemini models failed. Please try again later.');
  }

  static GeminiCvResult _parseResponse(String responseBody) {
    final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
    final candidates = decoded['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      debugPrint('[Gemini] No candidates in response');
      throw Exception(
          'Gemini returned no results. Please try rephrasing your paragraph.');
    }

    final content =
        candidates[0]['content'] as Map<String, dynamic>? ?? const {};
    final parts = content['parts'] as List<dynamic>? ?? const [];
    if (parts.isEmpty) {
      debugPrint('[Gemini] Empty parts in response');
      throw Exception(
          'Gemini returned an empty response. Please try again.');
    }

    final jsonText = parts[0]['text'] as String? ?? '';
    debugPrint('[Gemini] Parsed JSON text length: ${jsonText.length}');

    final Map<String, dynamic> parsed;
    try {
      parsed = jsonDecode(jsonText) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[Gemini] JSON parse error: $e');
      debugPrint('[Gemini] Raw text: ${jsonText.length > 300 ? jsonText.substring(0, 300) : jsonText}');
      throw Exception(
          'Invalid JSON from Gemini. Please try again.');
    }

    return GeminiCvResult(
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
