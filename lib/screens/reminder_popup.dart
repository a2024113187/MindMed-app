import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class EmergencyContactsScreen extends StatelessWidget {
  const EmergencyContactsScreen({super.key});

  final List<Map<String, String>> contacts = const [
    {
      'name': 'John Doe',
      'phone': '+1234567890',
    },
    {
      'name': 'Jane Smith',
      'phone': '+0987654321',
    },
    {
      'name': 'Emergency Services',
      'phone': '911',
    },
  ];

  void _callNumber(String phoneNumber) async {
    final Uri url = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      // No se pudo lanzar la llamada
      debugPrint('No se pudo llamar al número $phoneNumber');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Contacts'),
      ),
      body: ListView.builder(
        itemCount: contacts.length,
        itemBuilder: (context, index) {
          final contact = contacts[index];
          return ListTile(
            leading: const Icon(Icons.contact_phone),
            title: Text(contact['name']!),
            subtitle: Text(contact['phone']!),
            trailing: IconButton(
              icon: const Icon(Icons.call),
              onPressed: () => _callNumber(contact['phone']!),
            ),
          );
        },
      ),
    );
  }
}
