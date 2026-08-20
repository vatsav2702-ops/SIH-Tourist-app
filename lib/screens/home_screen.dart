import 'package:flutter/material.dart';
import '../models/spot_model.dart';
import '../models/vendor_model.dart';
import '../services/firebase_service.dart';
import '../widgets/spot_card.dart';
import '../widgets/vendor_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedCity = 'Vijayawada';
  String _selectedCategory = 'All';
  String _searchQuery = '';

  final List<String> _cities = ['Vijayawada', 'Hyderabad', 'Visakhapatnam', 'Tirupati', 'All Cities'];
  final List<String> _categories = ['All', 'Historical', 'Religious', 'Landmarks', 'Food'];

  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section with Gradient Background
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Greeting & City Dropdown Selector
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Namaste, Explorer! 👋',
                          style: TextStyle(
                            color: Colors.tealAccent,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Discover Heritage',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    // City Dropdown Selector
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCity,
                          dropdownColor: const Color(0xFF1E1B4B),
                          icon: const Icon(Icons.location_on_rounded, color: Colors.tealAccent, size: 18),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() => _selectedCity = newValue);
                            }
                          },
                          items: _cities.map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Search Bar Input
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() => _searchQuery = val);
                    },
                    decoration: InputDecoration(
                      hintText: 'Search temples, caves, palaces...',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                      icon: const Icon(Icons.search_rounded, color: Color(0xFF0D9488)),
                      border: InputBorder.none,
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Category Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(cat),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() => _selectedCategory = cat);
                    },
                    selectedColor: const Color(0xFF0D9488),
                    backgroundColor: Colors.white,
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFF1E1B4B),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected ? const Color(0xFF0D9488) : Colors.grey.shade300,
                      ),
                    ),
                    elevation: isSelected ? 2 : 0,
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 20),

          // "Vocal for Local" Street Food & Artisan Horizontal Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.storefront_rounded, color: Colors.orange.shade800, size: 18),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Vocal for Local',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E1B4B),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Text(
                    'Artisans & Street Food',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // StreamBuilder for Vendors
          StreamBuilder<List<Vendor>>(
            stream: FirebaseService().getVendorsStream(''),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox(
                  height: 150,
                  child: Center(child: CircularProgressIndicator(color: Color(0xFF0D9488))),
                );
              }
              final vendors = snapshot.data!;
              if (vendors.isEmpty) {
                return const SizedBox.shrink();
              }

              return SizedBox(
                height: 185,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: vendors.length,
                  itemBuilder: (context, index) {
                    return VendorCard(vendor: vendors[index]);
                  },
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          // Heritage Tourist Spots Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(Icons.explore_rounded, color: Color(0xFF0D9488), size: 20),
                const SizedBox(width: 8),
                Text(
                  'Explore $_selectedCity Heritage',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E1B4B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // StreamBuilder rendering Tourist Spots from Cloud Firestore
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: StreamBuilder<List<Spot>>(
              stream: FirebaseService().getSpotsStream(_selectedCity),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(30),
                    child: Center(child: CircularProgressIndicator(color: Color(0xFF0D9488))),
                  );
                }

                List<Spot> spots = snapshot.data ?? [];

                // Filter by category
                if (_selectedCategory != 'All') {
                  spots = spots.where((s) => s.category.toLowerCase() == _selectedCategory.toLowerCase()).toList();
                }

                // Filter by search query
                if (_searchQuery.isNotEmpty) {
                  spots = spots.where((s) =>
                      s.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                      s.shortDescription.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
                }

                if (spots.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(30),
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 10),
                        Text(
                          'No heritage spots found for "$_selectedCategory"',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: spots.length,
                  itemBuilder: (context, index) {
                    return SpotCard(spot: spots[index]);
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
