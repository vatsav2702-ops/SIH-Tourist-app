import 'dart:async';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

class MLTranslationService {
  final OnDeviceTranslatorModelManager _modelManager =
  OnDeviceTranslatorModelManager();

  OnDeviceTranslator? _translator;

  /// Checks whether a language's model is already downloaded on-device.
  Future<bool> isModelDownloaded(TranslateLanguage language) {
    return _modelManager.isModelDownloaded(language.bcpCode);
  }

  /// Downloads a single language's model ahead of time (e.g. from a
  /// "Manage languages" screen), independent of any translator pair.
  /// Set [wifiOnly] to true to avoid burning mobile data.
  Future<bool> downloadLanguage(
    TranslateLanguage language, {
    bool wifiOnly = false,
  }) {
    return _modelManager
        .downloadModel(language.bcpCode, isWifiRequired: wifiOnly)
        .timeout(
      const Duration(seconds: 40),
      onTimeout: () => throw TimeoutException(
        'Timed out downloading the ${language.bcpCode} language model. Check your connection and try again.',
      ),
    );
  }

  /// Removes a downloaded language model to free up storage.
  Future<bool> deleteLanguage(TranslateLanguage language) {
    return _modelManager.deleteModel(language.bcpCode);
  }

  Future<void> initialize({
    required TranslateLanguage sourceLanguage,
    required TranslateLanguage targetLanguage,
  }) async {
    // Download models if they aren't already available. Wrapped in a
    // timeout so a stalled/blocked network doesn't hang the caller forever.
    final sourceReady = await _modelManager
        .downloadModel(sourceLanguage.bcpCode)
        .timeout(
      const Duration(seconds: 25),
      onTimeout: () => throw TimeoutException(
        'Timed out downloading the ${sourceLanguage.bcpCode} language model. Check your connection and try again.',
      ),
    );

    final targetReady = await _modelManager
        .downloadModel(targetLanguage.bcpCode)
        .timeout(
      const Duration(seconds: 25),
      onTimeout: () => throw TimeoutException(
        'Timed out downloading the ${targetLanguage.bcpCode} language model. Check your connection and try again.',
      ),
    );

    if (!sourceReady || !targetReady) {
      throw Exception(
        'Could not download the language models needed for this translation.',
      );
    }

    // Close the previous translator if one exists.
    _translator?.close();

    _translator = OnDeviceTranslator(
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
    );
  }

  Future<String> translate(String text) async {
    if (_translator == null) {
      throw Exception('Translator has not been initialized.');
    }

    return await _translator!.translateText(text).timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw TimeoutException('Translation took too long.'),
    );
  }

  void dispose() {
    _translator?.close();
  }
}
