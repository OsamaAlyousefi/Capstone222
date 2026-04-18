import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../domain/models/job.dart';

/// Generates short AI summaries for individual job listings using Groq.
///
/// Summaries are cached in-memory for the session — no Hive persistence needed.
class JobSummaryService {
  static const _endpoint =
      'https://api.groq.com/openai/v1/chat/completions';

  static const _model = 'llama-3.3-70b-versatile';
  static const _fallbackModel = 'llama-3.1-8b-instant';
  static const _timeout = Duration(seconds: 10);

  static const _systemPrompt =
      'Summarize this job in 2 concise sentences. First sentence: what '
      'the role does. Second sentence: key requirements or what makes '
      'it interesting. Be direct and professional. No bullet points.';

  /// In-memory cache: jobId → summary text.
  static final Map<String, String> _cache = {};

  /// Fires whenever a new summary is cached so listeners can rebuild.
  static final ValueNotifier<int> summaryNotifier = ValueNotifier<int>(0);

  /// Returns a cached summary if available, otherwise null.
  static String? getCached(String jobId) => _cache[jobId];

  /// Returns true if the API key is configured.
  static bool get isAvailable {
    final key = dotenv.env['GROQ_API_KEY'];
    return key != null && key.isNotEmpty;
  }

  /// Auto-summarizes the first [count] jobs in the background, one at a time
  /// with a small delay between each to avoid rate limits. Never throws.
  static Future<void> summarizeInBackground(List<Job> jobs, {int count = 5}) async {
    if (!isAvailable) return;
    for (final job in jobs.take(count)) {
      if (_cache.containsKey(job.id)) continue;
      await generateSummary(
        jobId: job.id,
        jobTitle: job.title,
        company: job.companyName,
        location: job.location,
        rawDescription: job.description,
      );
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  }

  /// Generates a summary for a single job listing.
  ///
  /// Returns the summary text, or null on failure. Never throws.
  static Future<String?> generateSummary({
    required String jobId,
    required String jobTitle,
    required String company,
    required String location,
    required String rawDescription,
    String? salary,
  }) async {
    // Return cached version if available.
    final cached = _cache[jobId];
    if (cached != null) return cached;

    // Read key fresh every call — user may have changed it.
    final apiKey = dotenv.env['GROQ_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      debugPrint('[JobSummary] GROQ_API_KEY not set, skipping');
      return null;
    }

    final desc = rawDescription.length > 300
        ? rawDescription.substring(0, 300)
        : rawDescription;
    final userMessage = 'Job: $jobTitle at $company in $location. Description: $desc';

    // Try primary model, then fallback.
    for (final model in [_model, _fallbackModel]) {
      final result = await _callGroq(apiKey, model, userMessage);
      if (result != null) {
        _cache[jobId] = result;
        summaryNotifier.value++;
        return result;
      }
    }

    return null;
  }

  static Future<String?> _callGroq(
    String apiKey,
    String model,
    String userMessage,
  ) async {
    final url = Uri.parse(_endpoint);
    final body = jsonEncode({
      'model': model,
      'messages': [
        {'role': 'system', 'content': _systemPrompt},
        {'role': 'user', 'content': userMessage},
      ],
      'temperature': 0.3,
      'max_tokens': 100,
    });

    try {
      debugPrint('[JobSummary] Calling Groq ($model)...');
      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: body,
          )
          .timeout(_timeout);

      if (response.statusCode == 404 || response.statusCode == 429) {
        debugPrint('[JobSummary] $model returned ${response.statusCode}, trying fallback');
        return null;
      }

      // Detect restricted / unauthorized accounts.
      if (response.statusCode == 400 || response.statusCode == 403) {
        final bodyLower = response.body.toLowerCase();
        if (bodyLower.contains('restricted') || bodyLower.contains('unauthorized')) {
          debugPrint('[GROQ] Account restricted - check API key');
        } else {
          debugPrint('[JobSummary] Error ${response.statusCode}: ${response.body}');
        }
        return null;
      }

      if (response.statusCode != 200) {
        debugPrint('[JobSummary] Error ${response.statusCode}: ${response.body}');
        return null;
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = decoded['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) return null;

      final message =
          choices[0]['message'] as Map<String, dynamic>? ?? const {};
      final content = (message['content'] as String?)?.trim() ?? '';

      if (content.isEmpty) return null;

      debugPrint('[JobSummary] Generated summary (${content.length} chars)');
      return content;
    } on TimeoutException {
      debugPrint('[JobSummary] Timed out ($model)');
      return null;
    } on http.ClientException catch (e) {
      debugPrint('[JobSummary] Client error: $e');
      return null;
    } catch (e) {
      debugPrint('[JobSummary] Error: $e');
      return null;
    }
  }
}
