// lib/feedback_page.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final _titleCtrl     = TextEditingController();
  final _descCtrl      = TextEditingController();
  String _selectedType = 'istek';
  bool _loading        = false;

  Future<void> _submitFeedback() async {
    final title = _titleCtrl.text.trim();
    final desc  = _descCtrl.text.trim();
    if (title.isEmpty || desc.isEmpty) {
      _showAlert('Hata', 'Lütfen başlık ve açıklama girin.');
      return;
    }

    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    final uid   = prefs.getInt('userId');

    try {
      final res = await http.post(
        Uri.parse('https://erkayasoft.com/api/add_feedback.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId'     : uid,
          'type'       : _selectedType,
          'title'      : title,
          'description': desc,
        }),
      );

      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        if (body['success'] == true) {
          _showAlert(
            'Teşekkürler',
            _selectedType == 'istek'
                ? 'İsteğiniz başarıyla kaydedildi.'
                : 'Şikayetiniz başarıyla kaydedildi.',
            onOk: () => Navigator.of(context).pop(),
          );
          return;
        }
      }

      _showAlert('Hata', 'Sunucuda bir sorun oluştu.');
    } catch (e) {
      _showAlert('Hata', 'Bağlantı hatası: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showAlert(String title, String message, {VoidCallback? onOk}) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: Text(title),
        content: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(message),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Tamam'),
            onPressed: () {
              Navigator.of(context).pop();
              if (onOk != null) onOk();
            },
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGrey6,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('İstek & Şikayet'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          children: [
            // Başlık + ikon
            Row(
              children: const [
                Icon(CupertinoIcons.chat_bubble_text, size: 28, color: CupertinoColors.systemBlue),
                SizedBox(width: 12),
                Text(
                  'Geri Bildirim Gönder',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Tür seçimi
            Container(
              decoration: BoxDecoration(
                color: CupertinoColors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tür seçin', style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 8),
                  CupertinoSegmentedControl<String>(
                    children: const {
                      'istek': Padding(
                        padding: EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                        child: Text('İstek'),
                      ),
                      'sikayet': Padding(
                        padding: EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                        child: Text('Şikayet'),
                      ),
                    },
                    groupValue: _selectedType,
                    onValueChanged: (v) => setState(() => _selectedType = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Başlık alanı
            Container(
              decoration: BoxDecoration(
                color: CupertinoColors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: CupertinoTextField(
                controller: _titleCtrl,
                placeholder: 'Başlık girin',
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 16),

            // Açıklama alanı
            Container(
              height: 160,
              decoration: BoxDecoration(
                color: CupertinoColors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: CupertinoTextField(
                controller: _descCtrl,
                placeholder: 'Açıklamanızı yazın...',
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
              ),
            ),
            const SizedBox(height: 24),

            // Gönder butonu
            _loading
                ? const Center(child: CupertinoActivityIndicator())
                : CupertinoButton.filled(
              borderRadius: BorderRadius.circular(8),
              padding: const EdgeInsets.symmetric(vertical: 14),
              onPressed: _submitFeedback,
              child: const Text(
                'Gönder',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
