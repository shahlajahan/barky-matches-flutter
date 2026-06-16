import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class TelegramLabPage extends StatefulWidget {
  const TelegramLabPage({super.key});

  @override
  State<TelegramLabPage> createState() => _TelegramLabPageState();
}

class _TelegramLabPageState extends State<TelegramLabPage> {
  bool _isSending = false;
  String _result = '';

  // ⚠️ بعد از revoke این‌ها را جایگزین کن
  static const String botToken = 'YOUR_NEW_BOT_TOKEN';
  static const String chatId = 'YOUR_CHAT_ID';

  Future<void> _sendMessage() async {
    setState(() {
      _isSending = true;
      _result = '';
    });

    try {
      final url = Uri.parse(
        'https://api.telegram.org/bot$botToken/sendMessage',
      );

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'chat_id': chatId,
          'text': '''
🐶 Petsupo Lab Bot

سلام شهلا!

این اولین پیام ربات تلگرام از داخل Flutter است.

📋 Checklist
✅ Flutter Connected
✅ Telegram Bot API
✅ Petsupo Lab

💉 Vaccines
✅ DHPP
⏳ Rabies
❌ Bordetella

📌 Today's Tasks
• Book vet appointment
• Check medical records
• Schedule grooming
''',
        }),
      );

      setState(() {
        _result = response.body;
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