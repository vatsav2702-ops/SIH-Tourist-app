class Vendor {
  final String id;
  final String spotId;
  final String name;
  final String type; // e.g., 'Street Food', 'Artisan Handicrafts', 'Local Sweets'
  final String specialty;
  final double rating;
  final String distance;
  final String priceRange;
  final String imageUrl;
  final String contactPhone;

  Vendor({
    required this.id,
    required this.spotId,
    required this.name,
    required this.type,
    required this.specialty,
    required this.rating,
    required this.distance,
    required this.priceRange,
    required this.imageUrl,
    required this.contactPhone,
  });

  factory Vendor.fromFirestore(Map<String, dynamic> json, String docId) {
    return Vendor(
      id: docId,
      spotId: json['spotId'] ?? 'spot_1',
      name: json['name'] ?? 'Local Heritage Vendor',
      type: json['type'] ?? 'Street Food',
      specialty: json['specialty'] ?? 'Traditional Snacks & Delicacies',
      rating: (json['rating'] as num?)?.toDouble() ?? 4.8,
      distance: json['distance'] ?? '150m away',
      priceRange: json['priceRange'] ?? '₹50 - ₹200',
      imageUrl: json['imageUrl'] ?? 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=600&q=80',
      contactPhone: json['contactPhone'] ?? '+91 98765 43210',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'spotId': spotId,
      'name': name,
      'type': type,
      'specialty': specialty,
      'rating': rating,
      'distance': distance,
      'priceRange': priceRange,
      'imageUrl': imageUrl,
      'contactPhone': contactPhone,
    };
  }
}
