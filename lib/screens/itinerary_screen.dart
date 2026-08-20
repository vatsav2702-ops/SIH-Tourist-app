import 'package:flutter/material.dart';
import '../models/itinerary_model.dart';
import '../services/gemini_service.dart';

class ItineraryScreen extends StatefulWidget {
  const ItineraryScreen({Key? key}) : super(key: key);

  @override
  State<ItineraryScreen> createState() => _ItineraryScreenState();
}

class _ItineraryScreenState extends State<ItineraryScreen> {
  String _selectedCity = 'Vijayawada';
  double _budget = 3000.0; // ₹500 to ₹10,000
  int _durationDays = 2; // 1-5 days

  final Map<String, bool> _interests = {
    'History': true,
    'Food': true,
    'Nature': false,
    'Shopping': false,
  };

  final GeminiService _geminiService = GeminiService();

  bool _isGenerating = false;
  ItineraryPlan? _generatedPlan;

  final List<String> _cities = ['Vijayawada', 'Hyderabad', 'Visakhapatnam', 'Tirupati'];

  @override
  void initState() {
    super.initState();
    _generateDefaultPlan();
  }

  void _generateDefaultPlan() async {
    final selectedList = _interests.entries.where((e) => e.value).map((e) => e.key).toList();
    final plan = await _geminiService.generateItinerary(
      city: _selectedCity,
      budget: _budget,
      days: _durationDays,
      interests: selectedList,
    );
    if (mounted) {
      setState(() => _generatedPlan = plan);
    }
  }

  void _onGeneratePressed() async {
    setState(() {
      _isGenerating = true;
    });

    final selectedList = _interests.entries.where((e) => e.value).map((e) => e.key).toList();
    if (selectedList.isEmpty) {
      selectedList.add('History');
    }

    final plan = await _geminiService.generateItinerary(
      city: _selectedCity,
      budget: _budget,
      days: _durationDays,
      interests: selectedList,
    );

    if (mounted) {
      setState(() {
        _generatedPlan = plan;
        _isGenerating = false;
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
            // Header Banner
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.teal.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'AI Itinerary Planner',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Powered by Gemini 2.5 Flash',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Input Form Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // City Selector & Duration
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Destination City',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E1B4B),
                              ),
                            ),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              value: _selectedCity,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              items: _cities.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedCity = val);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Trip Duration',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E1B4B),
                              ),
                            ),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<int>(
                              value: _durationDays,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              items: [1, 2, 3, 4, 5]
                                  .map((d) => DropdownMenuItem(value: d, child: Text('$d Day${d > 1 ? 's' : ''}')))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _durationDays = val);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Budget Slider (₹500 to ₹10,000)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Travel Budget',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E1B4B),
                        ),
                      ),
                      Text(
                        '₹${_budget.round()}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0D9488),
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    min: 500,
                    max: 10000,
                    divisions: 19,
                    activeColor: const Color(0xFF0D9488),
                    inactiveColor: Colors.teal.shade100,
                    value: _budget,
                    onChanged: (val) {
                      setState(() => _budget = val);
                    },
                  ),

                  const SizedBox(height: 16),

                  // Interest Checkboxes
                  const Text(
                    'Travel Interests',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E1B4B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    children: _interests.keys.map((key) {
                      final isChecked = _interests[key]!;
                      return FilterChip(
                        label: Text(key),
                        selected: isChecked,
                        selectedColor: const Color(0xFF4F46E5),
                        checkmarkColor: Colors.white,
                        labelStyle: TextStyle(
                          color: isChecked ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                        onSelected: (val) {
                          setState(() => _interests[key] = val);
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  // Generate Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E1B4B),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 4,
                      ),
                      icon: _isGenerating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.tealAccent, strokeWidth: 2),
                            )
                          : const Icon(Icons.bolt_rounded, color: Colors.amber),
                      label: Text(
                        _isGenerating ? 'Querying Gemini AI...' : 'Generate AI Plan',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      onPressed: _isGenerating ? null : _onGeneratePressed,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Daily Collapsible Timeline Cards Output
            if (_generatedPlan != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_generatedPlan!.city} Custom Plan (${_generatedPlan!.durationDays} Days)',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E1B4B),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Est: ${_generatedPlan!.totalEstimatedBudget}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0D9488),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Days List Render
              ..._generatedPlan!.days.map((day) => _buildDayTimelineCard(day)).toList(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDayTimelineCard(DayPlan day) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: ExpansionTile(
        initiallyExpanded: day.dayNumber == 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF0D9488),
          child: Text(
            'D${day.dayNumber}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          day.title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E1B4B),
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          'Estimated Day Cost: ${day.totalDayCost}',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: day.stops.map((stop) => _buildStopTimelineItem(stop)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStopTimelineItem(ActivityStop stop) {
    Color badgeColor;
    if (stop.timeOfDay.toLowerCase().contains('morning')) {
      badgeColor = Colors.orange.shade700;
    } else if (stop.timeOfDay.toLowerCase().contains('afternoon')) {
      badgeColor = Colors.blue.shade700;
    } else {
      badgeColor = const Color(0xFF4F46E5);
    }

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  stop.timeOfDay,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.sell_outlined, size: 13, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    stop.estimatedCost,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0D9488),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            stop.spotName,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E1B4B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            stop.description,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.3),
          ),
        ],
      ),
    );
  }
}
