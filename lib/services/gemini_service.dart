import 'dart:convert';
import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/itinerary_model.dart';

class TranslationResult {
  final String translated; // native script
  final String romanized; // pronunciation guide in Latin letters

  TranslationResult({required this.translated, required this.romanized});

  /// Matches the display format already used by the static phrasebook:
  /// "நல்ல... (Nalla...)"
  String get display => '$translated ($romanized)';
}

class GeminiService {
  final String? apiKey;

  GeminiService({this.apiKey});

  String? get _effectiveApiKey {
    final key = apiKey ?? const String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
    return key.isEmpty ? null : key;
  }

  /// Whether a Gemini API key is actually configured — screens can use
  /// this to decide whether to show a "live translation" vs
  /// "sample phrasebook only" state.
  bool get isConfigured => _effectiveApiKey != null;

  /// Translates a single phrase for a tourist, returning both the
  /// native-script translation and a romanized pronunciation guide —
  /// same two-part format the static phrasebook already displays.
  /// Returns null (never throws) on missing key or any API/network
  /// failure, so callers can fall back to the static phrasebook.
  Future<TranslationResult?> translateText({
    required String text,
    required String sourceLang,
    required String targetLang,
  }) async {
    final key = _effectiveApiKey;
    if (key == null || text.trim().isEmpty) return null;

    try {
      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: key,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          temperature: 0.3, // translations should be literal, not creative
        ),
      );

      final prompt = '''
Translate this phrase for an Indian tourist, from $sourceLang to $targetLang.
Respond ONLY with valid JSON, no other text:
{"translated": "translation in $targetLang native script", "romanized": "phonetic pronunciation using Latin letters"}

If $targetLang is English, "translated" and "romanized" can be the same plain English text.

Phrase: "$text"
''';

      final response = await model.generateContent([Content.text(prompt)]);
      if (response.text == null || response.text!.isEmpty) return null;

      final jsonMap = jsonDecode(response.text!);
      return TranslationResult(
        translated: jsonMap['translated'] as String? ?? '',
        romanized: jsonMap['romanized'] as String? ?? '',
      );
    } catch (e) {
      return null;
    }
  }

  /// Reads visible text directly from a photo using Gemini's vision
  /// model — the fallback path for scripts Google ML Kit's on-device
  /// text recognizer doesn't support (notably Telugu and Tamil; ML Kit
  /// only covers Latin, Chinese, Devanagari, Japanese, Korean).
  /// Returns null on missing key or any failure.
  Future<String?> readTextFromImage(Uint8List imageBytes) async {
    final key = _effectiveApiKey;
    if (key == null) return null;

    try {
      final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: key);
      final response = await model.generateContent([
        Content.multi([
          TextPart(
            'Read every piece of visible text in this photo (sign, menu, label — any language or script) '
            'and return it verbatim, exactly as written, with no translation, explanation, or extra commentary. '
            'If there is no readable text, respond with exactly: NO_TEXT_FOUND',
          ),
          DataPart('image/jpeg', imageBytes),
        ]),
      ]);

      final text = response.text?.trim();
      if (text == null || text.isEmpty || text == 'NO_TEXT_FOUND') return null;
      return text;
    } catch (e) {
      return null;
    }
  }

  Future<ItineraryPlan> generateItinerary({
    required String city,
    required double budget,
    required int days,
    required List<String> interests,
  }) async {
    final effectiveApiKey = apiKey ?? const String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

    if (effectiveApiKey.isNotEmpty) {
      try {
        final model = GenerativeModel(
          model: 'gemini-2.5-flash',
          apiKey: effectiveApiKey,
          generationConfig: GenerationConfig(
            responseMimeType: 'application/json',
            temperature: 0.7,
          ),
        );

        final prompt = '''
You are an expert Indian tourism & heritage planner. Generate a highly detailed, realistic ${days}-day travel itinerary for $city, India with a total budget of ₹${budget.toInt()}.
User interests: ${interests.join(', ')}.

Respond strictly in valid JSON matching this exact structure:
{
  "city": "$city",
  "budget": ${budget.toInt()},
  "durationDays": $days,
  "interests": ${jsonEncode(interests)},
  "totalEstimatedBudget": "₹${budget.toInt()}",
  "days": [
    {
      "dayNumber": 1,
      "title": "Day 1 Title",
      "totalDayCost": "₹800",
      "stops": [
        {
          "timeOfDay": "Morning",
          "spotName": "Spot Name",
          "description": "Brief description of heritage activity and street food highlights.",
          "estimatedCost": "₹200",
          "duration": "2 Hours"
        },
        {
          "timeOfDay": "Afternoon",
          "spotName": "Spot Name 2",
          "description": "Exploration description.",
          "estimatedCost": "₹350",
          "duration": "2.5 Hours"
        },
        {
          "timeOfDay": "Evening",
          "spotName": "Spot Name 3",
          "description": "Sunset view & local market.",
          "estimatedCost": "₹250",
          "duration": "2 Hours"
        }
      ]
    }
  ]
}
''';

        final response = await model.generateContent([Content.text(prompt)]);
        if (response.text != null && response.text!.isNotEmpty) {
          final jsonMap = jsonDecode(response.text!);
          return ItineraryPlan.fromJson(jsonMap);
        }
      } catch (e) {
        // Fallback on network or API key issues
      }
    }

    // Fallback generator when API key is unconfigured or offline
    return _generateFallbackItinerary(city, budget, days, interests);
  }

  ItineraryPlan _generateFallbackItinerary(
    String city,
    double budget,
    int days,
    List<String> interests,
  ) {
    double dailyBudget = budget / days;
    List<DayPlan> dayPlans = [];

    Map<String, List<Map<String, String>>> cityHighlights = {
      'Vijayawada': [
        {
          'm': 'Kanaka Durga Temple',
          'm_desc': 'Early morning divine darshan atop Indrakeeladri hill.',
          'a': 'Undavalli Rock Cut Caves',
          'a_desc': 'Explore 5th-century monolithic sandstone architecture.',
          'e': 'Prakasam Barrage & Bhavani Island',
          'e_desc': 'Sunset stroll along Krishna river barrage and boat ride to island.',
        },
        {
          'm': 'Bapu Museum & Victoria Jubilee Hall',
          'm_desc': 'View ancient sculptures, bronze idols, and weapons.',
          'a': 'Kondapalli Fort & Artisan Village',
          'a_desc': 'Visit wooden toy craft workshops and hilltop fortress ruins.',
          'e': 'Besant Road Heritage Food Walk',
          'e_desc': 'Savor Punugulu, Mirchi Bajji, and local sweets.',
        },
        {
          'm': 'Mangalagiri Panakala Narasimha Temple',
          'm_desc': 'Historic temple famous for jaggery water offerings.',
          'a': 'Mangalagiri Handloom Weavers Market',
          'a_desc': 'Shop authentic GI-tagged cotton and silk sarees.',
          'e': 'Gunadala Mary Matha Church & Hilltop',
          'e_desc': 'Panoramic view of Vijayawada city from the hilltop shrine.',
        },
      ],
      'Hyderabad': [
        {
          'm': 'Charminar & Mecca Masjid',
          'm_desc': 'Morning heritage walk around historic 1591 monument.',
          'a': 'Chowmahalla Palace',
          'a_desc': 'Marvel at royal Nizami throne rooms & crystal chandeliers.',
          'e': 'Laad Bazaar Bangle Market & Nimrah Cafe',
          'e_desc': 'Taste hot Irani Chai with Osmania biscuits near Charminar.',
        },
        {
          'm': 'Golconda Fort Acoustic Tour',
          'm_desc': 'Guided acoustics trek up the majestic hilltop fort.',
          'a': 'Qutb Shahi Tombs',
          'a_desc': 'Stroll through 21 domed royal granite tombs.',
          'e': 'Hussain Sagar Lake & Statue of Equality',
          'e_desc': 'Evening boat ride to Buddha statue & illuminated skyline.',
        },
        {
          'm': 'Salar Jung Museum',
          'm_desc': 'Explore world\'s largest one-man antique collection.',
          'a': 'Birla Mandir & Science Center',
          'a_desc': 'Marble temple atop Naubat Pahad with planetarium view.',
          'e': 'Necklace Road Street Food Festival',
          'e_desc': 'Sample Hyderabadi Biryani and Double Ka Meetha.',
        },
      ]
    };

    var highlights = cityHighlights[city] ?? cityHighlights['Vijayawada']!;

    for (int i = 1; i <= days; i++) {
      var template = highlights[(i - 1) % highlights.length];
      double morningCost = dailyBudget * 0.25;
      double afternoonCost = dailyBudget * 0.45;
      double eveningCost = dailyBudget * 0.30;

      dayPlans.add(
        DayPlan(
          dayNumber: i,
          title: 'Day $i: ${interests.contains("History") ? "Heritage" : "Culture"} & ${interests.contains("Food") ? "Gastronomy" : "Sightseeing"}',
          totalDayCost: '₹${dailyBudget.toInt()}',
          stops: [
            ActivityStop(
              timeOfDay: 'Morning (8:30 AM)',
              spotName: template['m']!,
              description: template['m_desc']!,
              estimatedCost: '₹${morningCost.toInt()}',
              duration: '2.5 Hours',
            ),
            ActivityStop(
              timeOfDay: 'Afternoon (1:00 PM)',
              spotName: template['a']!,
              description: template['a_desc']!,
              estimatedCost: '₹${afternoonCost.toInt()}',
              duration: '3.0 Hours',
            ),
            ActivityStop(
              timeOfDay: 'Evening (5:30 PM)',
              spotName: template['e']!,
              description: template['e_desc']!,
              estimatedCost: '₹${eveningCost.toInt()}',
              duration: '2.5 Hours',
            ),
          ],
        ),
      );
    }

    return ItineraryPlan(
      city: city,
      budget: budget,
      durationDays: days,
      interests: interests,
      days: dayPlans,
      totalEstimatedBudget: '₹${budget.toInt()}',
    );
  }
}
