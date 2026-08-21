import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/spot_model.dart';
import '../models/vendor_model.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  bool _isFirebaseInitialized = false;

  void markInitialized() {
    _isFirebaseInitialized = true;
  }

  // --- Initial Mock Data Generator ---
  static List<Spot> getMockSpots(String cityFilter) {
    List<Spot> allSpots = [
      // Vijayawada
      Spot(
        id: 'spot_vij_1',
        name: 'Kanaka Durga Temple',
        city: 'Vijayawada',
        category: 'Religious',
        rating: 4.9,
        shortDescription: 'Sacred temple situated on the Indrakeeladri hill overlooking Krishna river.',
        history: 'Dating back to the 8th century, the Kanaka Durga Temple is mentioned in ancient scriptures. Arjuna is believed to have obtained the Pasupatastra here after praying to Lord Shiva.',
        operatingHours: '4:00 AM - 9:00 PM Daily',
        ticketFees: 'Free Entry (Rs. 100/300 Quick Darshan)',
        imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/b/ba/Kanakadurga_Temple_gopuram.jpg?utm_source=en.wikipedia.org&utm_campaign=index&utm_content=original',
        lat: 16.5161,
        lng: 80.6074,
        audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
        reviewsCount: 3820,
      ),
      Spot(
        id: 'spot_vij_2',
        name: 'Undavalli Caves',
        city: 'Vijayawada',
        category: 'Historical',
        rating: 4.7,
        shortDescription: 'Monolithic rock-cut cave temples dating back to 4th-5th century AD.',
        history: 'Built by Vishnukundina kings, these sandstone caves feature a giant 5-meter long reclining statue of Lord Vishnu carved out of a single block of granite.',
        operatingHours: '9:00 AM - 5:30 PM',
        ticketFees: '₹25 for Indians, ₹300 for Foreign Tourists',
        imageUrl: 'https://images.unsplash.com/photo-1590050752117-238cb0fb12b1?auto=format&fit=crop&w=800&q=80',
        lat: 16.4975,
        lng: 80.5822,
        audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
        reviewsCount: 1450,
      ),
      Spot(
        id: 'spot_vij_3',
        name: 'Prakasam Barrage',
        city: 'Vijayawada',
        category: 'Landmarks',
        rating: 4.6,
        shortDescription: 'Iconic 1224-meter bridge structure lit beautifully over Krishna River at night.',
        history: 'Constructed in 1957 across Krishna River, it forms a vast lake reservoir and supplies irrigation water while serving as Vijayawada\'s signature skyline backdrop.',
        operatingHours: '24 Hours Open',
        ticketFees: 'Free Access',
        imageUrl: 'https://images.unsplash.com/photo-1544644181-1484b3fdfc62?auto=format&fit=crop&w=800&q=80',
        lat: 16.5065,
        lng: 80.6092,
        audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
        reviewsCount: 2190,
      ),
      Spot(
        id: 'spot_vij_4',
        name: 'Bhavani Island',
        city: 'Vijayawada',
        category: 'Landmarks',
        rating: 4.5,
        shortDescription: 'One of the largest river islands in India with water sports and eco-resorts.',
        history: 'Spanning 133 acres in the Krishna River, Bhavani Island offers tranquil boat rides, lush gardens, rope courses, and heritage puppet shows.',
        operatingHours: '8:30 AM - 7:00 PM',
        ticketFees: '₹60 Ferry Ride Fee',
        imageUrl: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=800&q=80',
        lat: 16.5284,
        lng: 80.5851,
        audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3',
        reviewsCount: 980,
      ),

      // Hyderabad
      Spot(
        id: 'spot_hyd_1',
        name: 'Charminar',
        city: 'Hyderabad',
        category: 'Historical',
        rating: 4.8,
        shortDescription: 'Global icon of Hyderabad built in 1591 with 4 ornate grand minarets.',
        history: 'Constructed by Sultan Muhammad Quli Qutb Shah to commemorate the eradication of a devastating plague, standing at the heart of historic Old City.',
        operatingHours: '9:30 AM - 5:30 PM',
        ticketFees: '₹25 for Indians, ₹300 for Foreigners',
        imageUrl: 'https://images.unsplash.com/photo-1582510003544-4d00b7f74220?auto=format&fit=crop&w=800&q=80',
        lat: 17.3616,
        lng: 78.4747,
        audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-5.mp3',
        reviewsCount: 5400,
      ),
      Spot(
        id: 'spot_hyd_2',
        name: 'Golconda Fort',
        city: 'Hyderabad',
        category: 'Historical',
        rating: 4.7,
        shortDescription: 'Magnificent citadel famous for acoustic engineering and Koh-i-Noor history.',
        history: 'Originally built by Kakatiya Dynasty and later expanded by Qutb Shahi kings. Famous for hand-clap acoustics echoing from entrance gate to top palace acoustic dome 1km away.',
        operatingHours: '9:00 AM - 5:30 PM (Sound & Light show at 6:30 PM)',
        ticketFees: '₹25 Entry, ₹140 Light Show',
        imageUrl: 'https://images.unsplash.com/photo-1600100397608-f010e423b971?auto=format&fit=crop&w=800&q=80',
        lat: 17.3833,
        lng: 78.4011,
        audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-6.mp3',
        reviewsCount: 4120,
      ),
      Spot(
        id: 'spot_hyd_3',
        name: 'Chowmahalla Palace',
        city: 'Hyderabad',
        category: 'Landmarks',
        rating: 4.8,
        shortDescription: 'Opulent palace of the Nizams featuring grand courtyards and vintage cars.',
        history: 'The official seat of the Asaf Jahi dynasty, modeled after the Shah\'s palace in Tehran, housing imperial throne rooms and crystal chandeliers.',
        operatingHours: '10:00 AM - 5:00 PM (Closed Fridays)',
        ticketFees: '₹100 for Adults',
        imageUrl: 'https://images.unsplash.com/photo-1564507592333-c60657eea523?auto=format&fit=crop&w=800&q=80',
        lat: 17.3578,
        lng: 78.4717,
        audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-7.mp3',
        reviewsCount: 3100,
      ),
    ];

    if (cityFilter == 'All Cities') {
      return allSpots;
    }
    return allSpots.where((s) => s.city.toLowerCase() == cityFilter.toLowerCase()).toList();
  }

  static List<Vendor> getMockVendors(String spotId) {
    List<Vendor> allVendors = [
      Vendor(
        id: 'v1',
        spotId: 'spot_vij_1',
        name: 'Sri Durga Punugulu & Mirchi Bajji',
        type: 'Street Food',
        specialty: 'Hot Crispy Punugulu with Coconut & Ginger Chutney',
        rating: 4.9,
        distance: '80m from Temple',
        priceRange: '₹30 - ₹60',
        imageUrl: 'https://images.unsplash.com/photo-1601050690597-df0568f70950?auto=format&fit=crop&w=600&q=80',
        contactPhone: '+91 94401 22334',
      ),
      Vendor(
        id: 'v2',
        spotId: 'spot_vij_1',
        name: 'Kondapalli Wooden Toys Stall',
        type: 'Artisan Handicrafts',
        specialty: 'Handcrafted Eco Wood Dancing Dolls (Kondapalli Bommalu)',
        rating: 4.8,
        distance: '120m from Temple',
        priceRange: '₹150 - ₹1,200',
        imageUrl: 'https://images.unsplash.com/photo-1513519245088-0e12902e5a38?auto=format&fit=crop&w=600&q=80',
        contactPhone: '+91 98480 11223',
      ),
      Vendor(
        id: 'v3',
        spotId: 'spot_vij_1',
        name: 'Indrakeeladri Organic Jaggery Sweets',
        type: 'Local Sweets',
        specialty: 'Fresh Ariselu, Bobbatlu & Mysore Pak',
        rating: 4.7,
        distance: '200m from Temple Gate',
        priceRange: '₹100 - ₹400/kg',
        imageUrl: 'https://images.unsplash.com/photo-1599488615731-7e5c2823ff28?auto=format&fit=crop&w=600&q=80',
        contactPhone: '+91 97001 55667',
      ),
      Vendor(
        id: 'v4',
        spotId: 'spot_hyd_1',
        name: 'Nimrah Cafe & Bakery',
        type: 'Street Food',
        specialty: 'Authentic Irani Chai & Osmania Biscuits',
        rating: 4.9,
        distance: '30m from Charminar',
        priceRange: '₹20 - ₹80',
        imageUrl: 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=600&q=80',
        contactPhone: '+91 99890 77889',
      ),
      Vendor(
        id: 'v5',
        spotId: 'spot_hyd_1',
        name: 'Laad Bazaar Lac Bangles Artisan',
        type: 'Artisan Handicrafts',
        specialty: 'Hand-embedded Crystal Lac Bangles & Zardozi Crafts',
        rating: 4.8,
        distance: '90m in Laad Bazaar',
        priceRange: '₹200 - ₹2,500',
        imageUrl: 'https://images.unsplash.com/photo-1611591475281-91217c469f63?auto=format&fit=crop&w=600&q=80',
        contactPhone: '+91 93910 44556',
      ),
    ];

    if (spotId.isEmpty) return allVendors;
    var filtered = allVendors.where((v) => v.spotId == spotId).toList();
    return filtered.isNotEmpty ? filtered : allVendors.take(3).toList();
  }

  // --- Real-time Streams with Fallbacks ---
  Stream<List<Spot>> getSpotsStream(String city) {
    if (!_isFirebaseInitialized) {
      return Stream.value(getMockSpots(city));
    }

    try {
      Query query = FirebaseFirestore.instance.collection('spots');
      if (city != 'All Cities') {
        query = query.where('city', isEqualTo: city);
      }
      return query.snapshots().map((snapshot) {
        if (snapshot.docs.isEmpty) {
          return getMockSpots(city);
        }
        return snapshot.docs
            .map((doc) => Spot.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
            .toList();
      }).handleError((e) {
        return getMockSpots(city);
      });
    } catch (_) {
      return Stream.value(getMockSpots(city));
    }
  }

  Stream<List<Vendor>> getVendorsStream(String spotId) {
    if (!_isFirebaseInitialized) {
      return Stream.value(getMockVendors(spotId));
    }

    try {
      Query query = FirebaseFirestore.instance.collection('vendors');
      if (spotId.isNotEmpty) {
        query = query.where('spotId', isEqualTo: spotId);
      }
      return query.snapshots().map((snapshot) {
        if (snapshot.docs.isEmpty) {
          return getMockVendors(spotId);
        }
        return snapshot.docs
            .map((doc) => Vendor.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
            .toList();
      }).handleError((e) {
        return getMockVendors(spotId);
      });
    } catch (_) {
      return Stream.value(getMockVendors(spotId));
    }
  }
}
