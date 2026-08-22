import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/itinerary_model.dart';

/// Languages supported by the in-app translator.
enum AppLanguage {
  english('en', 'English'),
  hindi('hi', 'Hindi'),
  telugu('te', 'Telugu'),
  tamil('ta', 'Tamil'),
  marathi('mr', 'Marathi');

  final String code;
  final String label;
  const AppLanguage(this.code, this.label);

  /// Maps a dropdown label like 'Telugu' back to the enum value.
  static AppLanguage fromLabel(String label) {
    return AppLanguage.values.firstWhere(
      (l) => l.label.toLowerCase() == label.toLowerCase(),
      orElse: () => AppLanguage.english,
    );
  }
}

/// Thrown when a translation call fails and no fallback is possible.
class TranslationException implements Exception {
  final String message;
  TranslationException(this.message);

  @override
  String toString() => 'TranslationException: $message';
}

class GeminiTranslationService {
  final String? apiKey;

  GeminiTranslationService({this.apiKey});

  String get _effectiveApiKey =>
      apiKey ?? const String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

  GenerativeModel _plainTextModel() {
    return GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: _effectiveApiKey,
      generationConfig: GenerationConfig(temperature: 0.2),
    );
  }

  GenerativeModel _jsonModel() {
    return GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: _effectiveApiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        temperature: 0.2,
      ),
    );
  }

  /// General-purpose translation: pass any text, get it back in [targetLanguage].
  ///
  /// If [sourceLanguage] is omitted, Gemini auto-detects the source language.
  /// Returns the original [text] unchanged if [targetLanguage] is English
  /// and no [sourceLanguage] is given (skips a wasted API call), unless
  /// [forceTranslate] is true.
  Future<String> translateText(
    String text, {
    required AppLanguage targetLanguage,
    AppLanguage? sourceLanguage,
    bool forceTranslate = false,
  }) async {
    if (text.trim().isEmpty) return text;

    if (_effectiveApiKey.isEmpty) {
      throw TranslationException('Gemini API key is not configured.');
    }

    try {
      final model = _plainTextModel();

      final sourceClause = sourceLanguage != null
          ? 'The source language is ${sourceLanguage.label}.'
          : 'Detect the source language automatically.';

      final prompt = '''
You are a precise translation engine. $sourceClause
Translate the text below into ${targetLanguage.label} (${targetLanguage.code}).

Rules:
- Output ONLY the translated text, nothing else.
- No quotes, no explanations, no preamble, no language labels.
- Preserve numbers, currency symbols (₹), proper nouns, and formatting as-is unless they need transliteration to read naturally in ${targetLanguage.label}.
- Keep the tone and meaning faithful to the original.

Text:
"""
$text
"""
''';

      final response = await model.generateContent([Content.text(prompt)]);
      final result = response.text?.trim();

      if (result == null || result.isEmpty) {
        throw TranslationException('Empty response from Gemini.');
      }
      return result;
    } catch (e) {
      throw TranslationException('Translation failed: $e');
    }
  }

  /// Translates a batch of independent strings in a single API call.
  /// Much cheaper than calling [translateText] in a loop.
  Future<List<String>> translateBatch(
    List<String> texts, {
    required AppLanguage targetLanguage,
  }) async {
    if (texts.isEmpty) return [];

    if (_effectiveApiKey.isEmpty) {
      throw TranslationException('Gemini API key is not configured.');
    }

    try {
      final model = _jsonModel();

      final payload = {
        for (int i = 0; i < texts.length; i++) i.toString(): texts[i],
      };

      final prompt = '''
Translate every value in this JSON object into ${targetLanguage.label} (${targetLanguage.code}).
Keep the same keys. Return ONLY a JSON object with the same keys, translated values.
Preserve numbers, currency symbols (₹), and proper nouns naturally.

Input:
${jsonEncode(payload)}
''';

      final response = await model.generateContent([Content.text(prompt)]);
      if (response.text == null || response.text!.isEmpty) {
        throw TranslationException('Empty response from Gemini.');
      }

      final Map<String, dynamic> resultMap = jsonDecode(response.text!);
      return List<String>.generate(
        texts.length,
        (i) => resultMap[i.toString()]?.toString() ?? texts[i],
      );
    } catch (e) {
      throw TranslationException('Batch translation failed: $e');
    }
  }

  /// Translates all human-readable text in an [ItineraryPlan] (day titles,
  /// stop names, descriptions, time-of-day labels) into [targetLanguage],
  /// leaving city name, budget numbers, and structure untouched.
  Future<ItineraryPlan> translateItinerary(
    ItineraryPlan plan, {
    required AppLanguage targetLanguage,
  }) async {
    if (_effectiveApiKey.isEmpty) {
      throw TranslationException('Gemini API key is not configured.');
    }

    // Collect every translatable string with a stable index so we can
    // map the response back onto the original structure.
    final List<String> strings = [];
    for (final day in plan.days) {
      strings.add(day.title);
      for (final stop in day.stops) {
        strings.add(stop.timeOfDay);
        strings.add(stop.spotName);
        strings.add(stop.description);
        strings.add(stop.duration);
      }
    }

    List<String> translated;
    try {
      translated = await translateBatch(strings, targetLanguage: targetLanguage);
    } catch (e) {
      // Fall back to the original (untranslated) plan rather than crashing
      // the itinerary screen if Gemini is unavailable.
      return plan;
    }

    int cursor = 0;
    final translatedDays = plan.days.map((day) {
      final newTitle = translated[cursor++];
      final newStops = day.stops.map((stop) {
        final newTimeOfDay = translated[cursor++];
        final newSpotName = translated[cursor++];
        final newDescription = translated[cursor++];
        final newDuration = translated[cursor++];
        return ActivityStop(
          timeOfDay: newTimeOfDay,
          spotName: newSpotName,
          description: newDescription,
          estimatedCost: stop.estimatedCost, // costs stay numeric/untranslated
          duration: newDuration,
        );
      }).toList();

      return DayPlan(
        dayNumber: day.dayNumber,
        title: newTitle,
        totalDayCost: day.totalDayCost,
        stops: newStops,
      );
    }).toList();

    return ItineraryPlan(
      city: plan.city,
      budget: plan.budget,
      durationDays: plan.durationDays,
      interests: plan.interests,
      days: translatedDays,
      totalEstimatedBudget: plan.totalEstimatedBudget,
    );
  }
}
