// lib/profile_page.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? _user;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt('userId');
    if (id == null) {
      setState(() => _loading = false);
      return;
    }

    final res = await http.get(
      Uri.parse('https://erkayasoft.com/api/get_user.php?id=$id'),
    );
    if (res.statusCode == 200) {
      final jsonBody = json.decode(res.body);
      if (jsonBody['success'] == true) {
        setState(() {
          _user = jsonBody['data'] as Map<String, dynamic>;
          _loading = false;
        });
        return;
      }
    }

    // Başarısızsa
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    // Loading ekranı
    if (_loading) {
      return CupertinoPageScaffold(
        navigationBar: const CupertinoNavigationBar(middle: Text('Profilim')),
        child: const Center(child: CupertinoActivityIndicator()),
      );
    }

    // Kullanıcı yüklenemedi
    if (_user == null) {
      return CupertinoPageScaffold(
        navigationBar: const CupertinoNavigationBar(middle: Text('Profilim')),
        child: const Center(
          child: Text(
            'Kullanıcı bilgisi yüklenemedi.\nLütfen tekrar giriş yapın.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Gold üye mi?
    final paket = (_user!['paket'] as String).toLowerCase();
    final isGold = paket == 'gold';

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Profilim'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Profil başlığı & ikonu
            const SizedBox(height: 24),
            Center(
              child: Container(
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey5,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(16),
                child: const Icon(
                  CupertinoIcons.person_solid,
                  size: 60,
                  color: CupertinoColors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                '${_user!['firstName']} ${_user!['lastName']}',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color:
                  isGold ? CupertinoColors.systemYellow : CupertinoColors.label,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                isGold ? 'Gold Üye' : '${_user!['paket']} Üye',
                style: TextStyle(
                  fontSize: 16,
                  color: isGold
                      ? CupertinoColors.systemYellow
                      : CupertinoColors.inactiveGray,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),

            // Bilgi satırları
            _buildInfoRow(
              CupertinoIcons.person_crop_circle,
              'TC Kimlik No',
              _user!['tc'] as String,
            ),
            _buildInfoRow(
              CupertinoIcons.mail_solid,
              'E‑posta',
              _user!['email'] as String,
            ),
            if (_user!.containsKey('address'))
              _buildInfoRow(
                CupertinoIcons.location_solid,
                'Adres',
                (_user!['address'] as String).isNotEmpty
                    ? _user!['address'] as String
                    : '-',
              ),
            if (_user!.containsKey('phone'))
              _buildInfoRow(
                CupertinoIcons.phone_solid,
                'Telefon',
                (_user!['phone'] as String).isNotEmpty
                    ? _user!['phone'] as String
                    : '-',
              ),
            _buildInfoRow(
              CupertinoIcons.calendar,
              'Üyelik Tarihi',
              _user!['created_at'] as String,
            ),
            _buildInfoRow(
              CupertinoIcons.check_mark_circled_solid,
              'Hesap Durumu',
              (_user!['isActive'] as int) == 1 ? 'Aktif' : 'Pasif',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 28, color: CupertinoColors.activeBlue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
