import 'package:flutter/material.dart';

class PhraseItem {
  final String english;
  final String translated;
  final String language;
  final String category;

  PhraseItem({
    required this.english,
    required this.translated,
    required this.language,
    required this.category,
  });
}

class TranslatorScreen extends StatefulWidget {
  const TranslatorScreen({Key? key}) : super(key: key);

  @override
  State<TranslatorScreen> createState() => _TranslatorScreenState();
}

class _TranslatorScreenState extends State<TranslatorScreen> {
  String _sourceLang = 'English';
  String _targetLang = 'Telugu';

  final List<String> _languages = ['English', 'Hindi', 'Telugu', 'Tamil', 'Marathi'];

  final TextEditingController _inputController = TextEditingController(
    text: 'How much is the auto fare to the temple?',
  );

  String _translatedText = 'గుడికి ఆటో ఛార్జ్ ఎంత అవుతుంది? (Gudiki auto charge entha avuthundi?)';
  bool _isTranslating = false;
  bool _isListening = false;

  final Map<String, Map<String, String>> _quickTranslations = {
    'How much is the auto fare?': {
      'Telugu': 'ఆటో ఛార్జ్ ఎంత? (Auto charge entha?)',
      'Hindi': 'ऑटो का किराया कितना है? (Auto ka kiraya kitna hai?)',
      'Tamil': 'ஆட்டோ கட்டணம் எவ்வளவு? (Auto kattanam evvalavu?)',
      'Marathi': 'ऑटोचे भाडे किती आहे? (Auto che bhade kiti aahe?)',
    },
    'Where is the local food market?': {
      'Telugu': 'స్థానిక ఆహార మార్కెట్ ఎక్కడ ఉంది? (Sthanika aahara market ekkada undi?)',
      'Hindi': 'स्थानीय भोजन बाज़ार कहाँ है? (Sthaniya bhojan bazaar kahan hai?)',
      'Tamil': 'உள்ளூர் உணவு சந்தை எங்கே உள்ளது? (Ullur unavu sandhai enge ulladhu?)',
      'Marathi': 'स्थानिक खाद्यपदार्थांची बाजारपेठ कुठे आहे? (Sthanik khadyapadarthanchi bajarpeth kuthe aahe?)',
    },
    'Where is the nearest emergency hospital?': {
      'Telugu': 'దగ్గరలోని ఎమర్జెన్సీ హాస్పిటల్ ఎక్కడ ఉంది? (Daggaraloni emergency hospital ekkada undi?)',
      'Hindi': 'निकटतम आपातकालीन अस्पताल कहाँ है? (Nikattam aapatkaleen hospital kahan hai?)',
      'Tamil': 'அருகிலுள்ள அவசர மருத்துவமனை எங்கே உள்ளது? (Arugilulla avasara maruthuvamanai enge ulladhu?)',
      'Marathi': 'जवळचे आणीबाणीचे रुग्णालय कुठे आहे? (Javalche anibaniche rugnalaya kuthe aahe?)',
    },
    'Can you recommend a good local handicraft shop?': {
      'Telugu': 'మంచి హస్తకళల షాప్ సిఫార్సు చేయగలరా? (Manchi hastakalala shop sifarusu cheyagalara?)',
      'Hindi': 'क्या आप किसी अच्छे हस्तशिल्प दुकान का सुझाव दे सकते हैं? (Kya aap kisi acche hastashilp dukan ka sujhav de sakte hain?)',
      'Tamil': 'நல்ல உள்ளூர் கைவினைப்பொருட்கள் கடையை பரிந்துரைக்க முடியுமா? (Nalla ullur kaivinaiporutkal kadaiyai parindhuraikka mudiyuma?)',
      'Marathi': 'तुम्ही एखाद्या चांगल्या हस्तकला दुकानाची शिफारस करू शकता का? (Tumhi ekhadya changlya hastakala dukanachi shipharas karu shakta ka?)',
    },
  };

  void _translate() {
    setState(() => _isTranslating = true);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        String input = _inputController.text.trim();
        String result = _quickTranslations[input]?[_targetLang] ??
            'translatedText in $_targetLang: "$input"';

        setState(() {
          _translatedText = result;
          _isTranslating = false;
        });
      }
    });
  }

  void _toggleListening() {
    setState(() => _isListening = !_isListening);
    if (_isListening) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Listening... Speak your phrase clearly.'),
          duration: Duration(seconds: 2),
          backgroundColor: Color(0xFF0D9488),
        ),
      );
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _isListening) {
          setState(() {
            _isListening = false;
            _inputController.text = "Where is the local food market?";
          });
          _translate();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner Title
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E1B4B), Color(0xFF4F46E5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.g_translate_rounded, color: Colors.tealAccent, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Regional Voice & Text Translator',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'English, Hindi, Telugu, Tamil & Marathi',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Language Selector Swap Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _sourceLang,
                      items: _languages.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                      onChanged: (val) => setState(() => _sourceLang = val!),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF0D9488)),
                    onPressed: () {
                      setState(() {
                        var temp = _sourceLang;
                        _sourceLang = _targetLang;
                        _targetLang = temp;
                      });
                      _translate();
                    },
                  ),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _targetLang,
                      items: _languages.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                      onChanged: (val) {
                        setState(() => _targetLang = val!);
                        _translate();
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Text Input Box & Voice Button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _inputController,
                    maxLines: 3,
                    onChanged: (_) => _translate(),
                    decoration: const InputDecoration(
                      hintText: 'Type or speak tourist phrase here...',
                      border: InputBorder.none,
                    ),
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isListening ? Colors.red : const Color(0xFF0D9488),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: Icon(_isListening ? Icons.mic : Icons.mic_none_rounded),
                        label: Text(_isListening ? 'Listening...' : 'Voice Input'),
                        onPressed: _toggleListening,
                      ),
                      IconButton(
                        icon: const Icon(Icons.volume_up_rounded, color: Color(0xFF4F46E5)),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Playing audio in $_sourceLang...')),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Translation Output Box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFC7D2FE)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$_targetLang Translation',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4F46E5),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.volume_up_rounded, color: Color(0xFF4F46E5), size: 20),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Playing pronunciation in $_targetLang...')),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (_isTranslating)
                    const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)))
                  else
                    Text(
                      _translatedText,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E1B4B),
                        height: 1.4,
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Phrasebook Cards Section
            Row(
              children: const [
                Icon(Icons.book_online_rounded, color: Color(0xFF0D9488), size: 20),
                SizedBox(width: 8),
                Text(
                  'Quick Travel Phrasebook',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E1B4B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            ..._quickTranslations.keys.map((phrase) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: CircleAvatar(
                    backgroundColor: Colors.teal.shade50,
                    child: const Icon(Icons.translate, color: Color(0xFF0D9488), size: 20),
                  ),
                  title: Text(
                    phrase,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E1B4B)),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _quickTranslations[phrase]?[_targetLang] ?? '',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF0D9488), fontWeight: FontWeight.w600),
                    ),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                  onTap: () {
                    _inputController.text = phrase;
                    _translate();
                  },
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}
