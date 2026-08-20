class Spot {
  final String id;
  final String name;
  final String city;
  final String category;
  final double rating;
  final String shortDescription;
  final String history;
  final String operatingHours;
  final String ticketFees;
  final String imageUrl;
  final double lat;
  final double lng;
  final String audioUrl;
  final int reviewsCount;

  Spot({
    required this.id,
    required this.name,
    required this.city,
    required this.category,
    required this.rating,
    required this.shortDescription,
    required this.history,
    required this.operatingHours,
    required this.ticketFees,
    required this.imageUrl,
    required this.lat,
    required this.lng,
    required this.audioUrl,
    this.reviewsCount = 120,
  });

  factory Spot.fromFirestore(Map<String, dynamic> json, String docId) {
    return Spot(
      id: docId,
      name: json['name'] ?? 'Heritage Landmark',
      city: json['city'] ?? 'Vijayawada',
      category: json['category'] ?? 'Historical',
      rating: (json['rating'] as num?)?.toDouble() ?? 4.5,
      shortDescription: json['shortDescription'] ?? 'Famous historic monument and cultural attraction.',
      history: json['history'] ?? 'Rich historical heritage dating back centuries with intricate architectural craftsmanship.',
      operatingHours: json['operatingHours'] ?? '6:00 AM - 8:00 PM Daily',
      ticketFees: json['ticketFees'] ?? 'Free Entry (Special Darshan / Guide fees may apply)',
      imageUrl: json['imageUrl'] ?? 'https://images.unsplash.com/photo-1582510003544-4d00b7f74220?auto=format&fit=crop&w=800&q=80',
      lat: (json['lat'] as num?)?.toDouble() ?? 16.5062,
      lng: (json['lng'] as num?)?.toDouble() ?? 80.6480,
      audioUrl: json['audioUrl'] ?? 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
      reviewsCount: (json['reviewsCount'] as num?)?.toInt() ?? 245,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'city': city,
      'category': category,
      'rating': rating,
      'shortDescription': shortDescription,
      'history': history,
      'operatingHours': operatingHours,
      'ticketFees': ticketFees,
      'imageUrl': imageUrl,
      'lat': lat,
      'lng': lng,
      'audioUrl': audioUrl,
      'reviewsCount': reviewsCount,
    };
  }
}
