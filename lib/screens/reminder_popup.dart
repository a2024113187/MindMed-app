import 'package:flutter/material.dart';
import 'package:mindmeds/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() =>
      _EmergencyContactsScreenState();
}
  class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {

    List<Map<String, String>> customContacts = [];
    final List<Map<String, String>> contacts = const [
      { 'name': 'John Doe', 'phone': '+1234567890' },
      { 'name': 'Jane Smith', 'phone': '+0987654321' },
      { 'name': 'Emergency Services', 'phone': '911' },
    ];

    @override
    void initState() {
      super.initState();
      _loadCustomContacts();
    }

    Future<void> _loadCustomContacts() async {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? saved = prefs.getStringList('custom_contacts');
      if (saved != null) {
        setState(() {
          customContacts = saved.map((e) {
            final parts = e.split('|');
            return {'name': parts[0], 'phone': parts[1]};
          }).toList();
        });
      }
    }

    Future<void> _saveCustomContacts() async {
      final prefs = await SharedPreferences.getInstance();
      final List<String> toSave = customContacts.map((
          e) => '${e['name']}|${e['phone']}').toList();
      await prefs.setStringList('custom_contacts', toSave);
    }

    Future<void> _showAddContactDialog() async {
      final _nameController = TextEditingController();
      final _phoneController = TextEditingController();
      final formKey = GlobalKey<FormState>();

      final result = await showDialog<bool>(
        context: context,
        builder: (context) =>
            AlertDialog(
              title: const Text('Add Contact'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Name'),
                      validator: (value) =>
                      (value == null || value
                          .trim()
                          .isEmpty) ? 'Please enter a name' : null,
                    ),
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                          labelText: 'Phone Number'),
                      keyboardType: TextInputType.phone,
                      validator: (value) =>
                      (value == null || value
                          .trim()
                          .isEmpty) ? 'Please enter a phone number' : null,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState?.validate() ?? false) {
                      Navigator.of(context).pop(true);
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
            ),
      );

      if (result == true) {
        setState(() {
          customContacts.add({
            'name': _nameController.text.trim(),
            'phone': _phoneController.text.trim(),
          });
        });
        await _saveCustomContacts();
      }
    }


    Future<void> _callNumber(BuildContext context, String phoneNumber) async {
      final cleanNumber = phoneNumber.replaceAll(RegExp(r'\s+'), '');
      final Uri url = Uri(scheme: 'tel', path: cleanNumber);

      if (await canLaunchUrl(url)) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) =>
              AlertDialog(
                title: const Text('Confirm Call'),
                content: Text('Do you want to call $cleanNumber?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Call'),
                  ),
                ],
              ),
        );

        if (confirmed == true) {
          await launchUrl(url);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot make a call to $cleanNumber'),
            backgroundColor: Theme
                .of(context)
                .colorScheme
                .error,
          ),
        );
      }
    }

    String cleanPhoneNumber(String phone) {
      return phone.replaceAll(RegExp(r'\s+'), '');
    }

    @override
    Widget build(BuildContext context) {
      final theme = Theme.of(context);
      final colorScheme = theme.colorScheme;
      final textTheme = theme.textTheme;


      final allContacts = [...contacts, ...customContacts];



      return GlobalBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('Emergency Contacts'),
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            foregroundColor: colorScheme.onBackground,
            iconTheme: IconThemeData(color: colorScheme.onBackground),
          ),
          body: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: allContacts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final contact = allContacts[index];
              return Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  leading: CircleAvatar(
                    backgroundColor: colorScheme.primaryContainer,
                    child: Icon(
                      Icons.contact_phone,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  title: Text(
                    contact['name'] ?? '',
                    style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    contact['phone'] ?? '',
                    style: textTheme.bodyMedium,
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.call, color: colorScheme.primary),
                    tooltip: 'Call ${contact['name']}',
                    onPressed: () =>
                        _callNumber(context, contact['phone'] ?? ''),
                  ),
                ),
              );
            },
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: _showAddContactDialog,
            backgroundColor: colorScheme.primary,
            child: const Icon(Icons.add),
            tooltip: 'Add Contact',
          ),
        ),
      );
    }
  }
