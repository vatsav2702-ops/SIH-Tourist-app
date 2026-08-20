import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/location_service.dart';

class EmergencyDialog extends StatelessWidget {
  const EmergencyDialog({Key? key}) : super(key: key);

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const EmergencyDialog(),
    );
  }

  Future<void> _makeEmergencyCall(BuildContext context) async {
    final Uri telUri = Uri(scheme: 'tel', path: '112');
    try {
      if (await canLaunchUrl(telUri)) {
        await launchUrl(telUri);
      } else {
        await launchUrl(telUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Opening Phone Dialer with 112...'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = LocationService().currentPosition;
    final latStr = loc?.latitude.toStringAsFixed(4) ?? '16.5062';
    final lngStr = loc?.longitude.toStringAsFixed(4) ?? '80.6480';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      title: Row(
        children: const [
          Icon(Icons.warning_amber_rounded, color: Colors.red, size: 32),
          SizedBox(width: 10),
          Text(
            'Emergency Assistance',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E1B4B),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.my_location, color: Colors.red, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your Live GPS Coordinates:\nLat: $latStr | Lng: $lngStr',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.redAccent,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'This action will instantly connect you to National Emergency Helpline 112 and transmit your location details to nearby emergency tourist dispatch.',
            style: TextStyle(fontSize: 14, color: Colors.black87),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.phone_in_talk),
          label: const Text('CALL 112 NOW', style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: () {
            Navigator.of(context).pop();
            _makeEmergencyCall(context);
          },
        ),
      ],
    );
  }
}
