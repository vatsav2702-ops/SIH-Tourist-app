import 'package:flutter/material.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import '../services/ml_translation_service.dart';

class _LanguageEntry {
  final String label;
  final TranslateLanguage language;
  _LanguageEntry(this.label, this.language);
}

class LanguageDownloadsScreen extends StatefulWidget {
  const LanguageDownloadsScreen({Key? key}) : super(key: key);

  @override
  State<LanguageDownloadsScreen> createState() => _LanguageDownloadsScreenState();
}

class _LanguageDownloadsScreenState extends State<LanguageDownloadsScreen> {
  final MLTranslationService _mlService = MLTranslationService();

  final List<_LanguageEntry> _allLanguages = [
    _LanguageEntry('English', TranslateLanguage.english),
    _LanguageEntry('Hindi', TranslateLanguage.hindi),
    _LanguageEntry('Telugu', TranslateLanguage.telugu),
    _LanguageEntry('Tamil', TranslateLanguage.tamil),
    _LanguageEntry('Marathi', TranslateLanguage.marathi),
  ];

  // bcpCode -> downloaded?
  final Map<String, bool> _downloaded = {};
  // bcpCode -> currently downloading/deleting?
  final Map<String, bool> _busy = {};
  // bcpCode -> last error, if any
  final Map<String, String> _errors = {};

  bool _wifiOnly = true;
  bool _loadingStatus = true;

  @override
  void initState() {
    super.initState();
    _refreshStatuses();
  }

  Future<void> _refreshStatuses() async {
    setState(() => _loadingStatus = true);
    for (final entry in _allLanguages) {
      try {
        final isDown = await _mlService.isModelDownloaded(entry.language);
        _downloaded[entry.language.bcpCode] = isDown;
      } catch (_) {
        _downloaded[entry.language.bcpCode] = false;
      }
    }
    if (mounted) setState(() => _loadingStatus = false);
  }

  Future<void> _download(_LanguageEntry entry) async {
    final code = entry.language.bcpCode;
    setState(() {
      _busy[code] = true;
      _errors.remove(code);
    });

    try {
      final success = await _mlService.downloadLanguage(
        entry.language,
        wifiOnly: _wifiOnly,
      );
      if (!mounted) return;
      setState(() {
        _downloaded[code] = success;
        _busy[code] = false;
        if (!success) _errors[code] = 'Download did not complete.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy[code] = false;
        _errors[code] = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _delete(_LanguageEntry entry) async {
    final code = entry.language.bcpCode;
    setState(() {
      _busy[code] = true;
      _errors.remove(code);
    });

    try {
      await _mlService.deleteLanguage(entry.language);
      if (!mounted) return;
      setState(() {
        _downloaded[code] = false;
        _busy[code] = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy[code] = false;
        _errors[code] = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _downloadAll() async {
    for (final entry in _allLanguages) {
      if (_downloaded[entry.language.bcpCode] != true) {
        await _download(entry);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Manage Languages'),
        backgroundColor: const Color(0xFF1E1B4B),
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshStatuses,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFC7D2FE)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Color(0xFF4F46E5)),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Download language packs ahead of time so translation works instantly, even offline.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF1E1B4B)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _wifiOnly,
              activeColor: const Color(0xFF0D9488),
              title: const Text(
                'Download over Wi-Fi only',
                style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E1B4B)),
              ),
              subtitle: const Text('Avoid using mobile data for language packs'),
              onChanged: (val) => setState(() => _wifiOnly = val),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.download_for_offline_rounded),
                label: const Text('Download all languages'),
                onPressed: _loadingStatus ? null : _downloadAll,
              ),
            ),
            const SizedBox(height: 20),
            if (_loadingStatus)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5))),
              )
            else
              ..._allLanguages.map(_buildLanguageTile),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageTile(_LanguageEntry entry) {
    final code = entry.language.bcpCode;
    final isDownloaded = _downloaded[code] ?? false;
    final isBusy = _busy[code] ?? false;
    final error = _errors[code];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: isDownloaded ? Colors.teal.shade50 : Colors.grey.shade100,
                child: Icon(
                  isDownloaded ? Icons.check_circle_rounded : Icons.language_rounded,
                  color: isDownloaded ? const Color(0xFF0D9488) : Colors.grey.shade500,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  entry.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF1E1B4B),
                  ),
                ),
              ),
              if (isBusy)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4, color: Color(0xFF4F46E5)),
                )
              else if (isDownloaded)
                TextButton.icon(
                  onPressed: () => _delete(entry),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                  label: const Text('Remove', style: TextStyle(color: Colors.redAccent)),
                )
              else
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _download(entry),
                  child: const Text('Download'),
                ),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: 6),
            Text(error, style: const TextStyle(fontSize: 12, color: Colors.redAccent)),
          ],
        ],
      ),
    );
  }
}
