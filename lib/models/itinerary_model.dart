class ActivityStop {
  final String timeOfDay; // Morning, Afternoon, Evening
  final String spotName;
  final String description;
  final String estimatedCost;
  final String duration;

  ActivityStop({
    required this.timeOfDay,
    required this.spotName,
    required this.description,
    required this.estimatedCost,
    required this.duration,
  });

  factory ActivityStop.fromJson(Map<String, dynamic> json) {
    return ActivityStop(
      timeOfDay: json['timeOfDay'] ?? 'Morning',
      spotName: json['spotName'] ?? 'Popular Sight',
      description: json['description'] ?? 'Explore heritage architecture.',
      estimatedCost: json['estimatedCost'] ?? '₹150',
      duration: json['duration'] ?? '2 Hours',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timeOfDay': timeOfDay,
      'spotName': spotName,
      'description': description,
      'estimatedCost': estimatedCost,
      'duration': duration,
    };
  }
}

class DayPlan {
  final int dayNumber;
  final String title;
  final List<ActivityStop> stops;
  final String totalDayCost;

  DayPlan({
    required this.dayNumber,
    required this.title,
    required this.stops,
    required this.totalDayCost,
  });

  factory DayPlan.fromJson(Map<String, dynamic> json) {
    var rawStops = json['stops'] as List<dynamic>? ?? [];
    List<ActivityStop> parsedStops = rawStops
        .map((s) => ActivityStop.fromJson(Map<String, dynamic>.from(s)))
        .toList();

    return DayPlan(
      dayNumber: json['dayNumber'] ?? 1,
      title: json['title'] ?? 'Heritage & Culture Discovery',
      stops: parsedStops,
      totalDayCost: json['totalDayCost'] ?? '₹800',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dayNumber': dayNumber,
      'title': title,
      'stops': stops.map((s) => s.toJson()).toList(),
      'totalDayCost': totalDayCost,
    };
  }
}

class ItineraryPlan {
  final String city;
  final double budget;
  final int durationDays;
  final List<String> interests;
  final List<DayPlan> days;
  final String totalEstimatedBudget;

  ItineraryPlan({
    required this.city,
    required this.budget,
    required this.durationDays,
    required this.interests,
    required this.days,
    required this.totalEstimatedBudget,
  });

  factory ItineraryPlan.fromJson(Map<String, dynamic> json) {
    var rawDays = json['days'] as List<dynamic>? ?? [];
    List<DayPlan> parsedDays = rawDays
        .map((d) => DayPlan.fromJson(Map<String, dynamic>.from(d)))
        .toList();

    return ItineraryPlan(
      city: json['city'] ?? 'Vijayawada',
      budget: (json['budget'] as num?)?.toDouble() ?? 3000.0,
      durationDays: json['durationDays'] ?? 2,
      interests: List<String>.from(json['interests'] ?? ['History', 'Food']),
      days: parsedDays,
      totalEstimatedBudget: json['totalEstimatedBudget'] ?? '₹2,500',
    );
  }
}
