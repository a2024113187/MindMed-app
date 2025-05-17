import 'package:flutter/material.dart';

class ReminderPopupScreen extends StatelessWidget {
  const ReminderPopupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reminder Popup')),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Reminder'),
                content: const Text('It\'s time to take your medication!'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('OK'),
                  )
                ],
              ),
            );
          },
          child: const Text('Show Reminder'),
        ),
      ),
    );
  }
}
