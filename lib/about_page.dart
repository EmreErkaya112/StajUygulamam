// lib/about_page.dart

import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

class AboutPage extends StatelessWidget {
  const AboutPage({Key? key}) : super(key: key);

  Future<Map<String, String>> fetchAbout() async {
    final uri = Uri.parse('https://erkayasoft.com/api/get_about.php');
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final body = json.decode(response.body);
      if (body['success'] == true && body['data'] is Map<String, dynamic>) {
        final data = body['data'] as Map<String, dynamic>;
        return {
          'about': data['about_text'] ?? '',
          'phone': data['contact_phone'] ?? '',
          'email': data['contact_email'] ?? '',
        };
      } else {
        throw Exception(body['message'] ?? 'API hatası');
      }
    } else {
      throw Exception('Sunucu hatası: ${response.statusCode}');
    }
  }

  Future<void> _launch(Uri uri) async {
    if (!await launchUrl(uri)) {
      // Hata durumunda isterseniz kullanıcıya bildirim gösterin
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Hakkımızda'),
      ),
      child: SafeArea(
        child: FutureBuilder<Map<String, String>>(
          future: fetchAbout(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CupertinoActivityIndicator());
            }
            if (snapshot.hasError || snapshot.data == null) {
              return Center(
                child: Text(
                  'Hata: \${snapshot.error}',
                  style: const TextStyle(color: CupertinoColors.destructiveRed),
                ),
              );
            }
            final about = snapshot.data!['about']!;
            final phone = snapshot.data!['phone']!;
            final email = snapshot.data!['email']!;

            return ListView(
              children: [
                // Kapak görseli
                Image.asset(
                  'assets/derneklogo.png',
                  width: double.infinity,
                  height: 220,
                  fit: BoxFit.contain,
                ),

                const SizedBox(height: 24),

                // Hakkımızda metni
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    about,
                    style: const TextStyle(fontSize: 16, height: 1.5),
                    textAlign: TextAlign.justify,
                  ),
                ),

                const SizedBox(height: 32),
                const Divider(height: 1),

                // İletişim
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  child: Column(
                    children: [
                      // Telefon
                      GestureDetector(
                        onTap: () => _launch(Uri(scheme: 'tel', path: phone)),
                        child: Row(
                          children: [
                            const Icon(
                              CupertinoIcons.phone_solid,
                              color: CupertinoColors.activeBlue,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              phone,
                              style: const TextStyle(
                                fontSize: 16,
                                color: CupertinoColors.activeBlue,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // E‑posta
                      GestureDetector(
                        onTap: () => _launch(Uri(
                          scheme: 'mailto',
                          path: email,
                          query: 'subject=Hakkımızda',
                        )),
                        child: Row(
                          children: [
                            const Icon(
                              CupertinoIcons.mail_solid,
                              color: CupertinoColors.activeBlue,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              email,
                              style: const TextStyle(
                                fontSize: 16,
                                color: CupertinoColors.activeBlue,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
