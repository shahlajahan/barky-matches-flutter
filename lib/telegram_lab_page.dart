import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';

class TelegramLabPage extends StatefulWidget {
  const TelegramLabPage({super.key});

  @override
  State<TelegramLabPage> createState() => _TelegramLabPageState();
}

class _TelegramLabPageState extends State<TelegramLabPage> {
  bool _isSending = false;
  String _result = '';

 

  Future<void> _sendMessage() async {
  setState(() {
    _isSending = true;
    _result = '';
  });

  try {
    final callable = FirebaseFunctions.instanceFor(
      region: 'europe-west1',
    ).httpsCallable('sendTelegramMessage');

    final response = await callable.call({
      'chatId': '723570051',
      'text': '''
🐶 Petsupo Lab Bot

Hello!

This message was sent securely through Firebase Cloud Functions v2.

✅ Flutter
✅ Cloud Functions v2
✅ Secret Manager
✅ Telegram Bot API

📌 Today's Tasks
• Book vet appointment
• Check medical records
• Schedule grooming
''',
    });

    setState(() {
  _result = '✅ Telegram message sent successfully';
});
  } catch (e) {
    setState(() {
      _result = e.toString();
    });
  }

  setState(() {
    _isSending = false;
  });
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Telegram Lab'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(
              Icons.telegram,
              size: 80,
              color: Colors.blue,
            ),

            const SizedBox(height: 20),

            const Text(
              'Telegram Bot API Test',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            const Text(
              'Press the button below to send a test message.',
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSending ? null : _sendMessage,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _isSending
                      ? const CircularProgressIndicator()
                      : const Text(
                          'Send Telegram Message',
                        ),
                ),
              ),
            ),

            const SizedBox(height: 30),

            Expanded(
              child: SingleChildScrollView(
                child: SelectableText(
                  _result.isEmpty
                      ? 'No response yet.'
                      : _result,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}