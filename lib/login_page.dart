// lib/login_page.dart

import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'home_page.dart';
import 'register_page.dart';
// >>> EKLE
import 'package:onesignal_flutter/onesignal_flutter.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _tcController = TextEditingController();
  final _pwController = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _checkAlreadyLoggedIn();
  }

  Future<List<Map<String, dynamic>>> _fetchUsers() async {
    final res = await http.get(Uri.parse('https://yagmurlukoyu.org/api/kisiler.php'));
    if (res.statusCode == 200) {
      final body = json.decode(res.body);
      if (body['success'] == true) {
        return List<Map<String, dynamic>>.from(body['data']);
      }
    }
    throw Exception('Kullanıcı alınamadı');
  }

  Future<void> _checkAlreadyLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt('userId');
    if (id != null && mounted) {
      Navigator.of(context).pushReplacement(
        CupertinoPageRoute(builder: (_) => const HomePage()),
      );
    }
  }

  // >>> EKLE: OneSignal external_id bağlama yardımcı fonksiyonu
  Future<void> _linkOneSignal(int userId, {String? tc}) async {
    try {
      // Her ihtimale karşı önce ayrıl, sonra doğru ID ile giriş yap
      await OneSignal.logout();
      await OneSignal.login(userId.toString());

      // İsteğe bağlı: kullanıcıya ait etiketler
      final tags = <String, String>{};
      if (tc != null && tc.isNotEmpty) tags['tc'] = tc;
      if (tags.isNotEmpty) {
        await OneSignal.User.addTags(tags);
      }

      // Teşhis için log
      final sub = OneSignal.User.pushSubscription;
      // ignore: avoid_print
      print('[OS] linked extId=$userId subId=${sub.id} token=${sub.token} optedIn=${sub.optedIn}');
    } catch (e) {
      // ignore: avoid_print
      print('[OS] link error: $e');
    }
  }

  Future<void> _onLogin() async {
    final tc = _tcController.text.trim();
    final pw = _pwController.text.trim();
    if (tc.isEmpty || pw.isEmpty) {
      return _showAlert('Hata', 'Lütfen TC ve şifre girin.');
    }

    setState(() => _loading = true);
    try {
      final users = await _fetchUsers();

      Map<String, dynamic>? user;
      try {
        user = users.firstWhere((u) => u['tc'] == tc && u['password'] == pw);
      } catch (_) {
        user = null;
      }

      if (user == null) {
        _showAlert('Hata', 'TC veya şifre hatalı.');
      } else if (user['isActive'].toString() != '1') {
        _showAlert(
          'Hesap Onayı Bekleniyor',
          'Hesabınız henüz onaylanmadı. Lütfen SMS ile gelen onayı bekleyin.',
        );
      } else {
        final prefs = await SharedPreferences.getInstance();
        final id = int.parse(user!['_id'].toString());

        // >>> EKLE: kalıcı oturum bayrağı ve userId
        await prefs.setBool('loggedIn', true);
        await prefs.setInt('userId', id);

        // >>> EKLE: OneSignal external_id bağla
        await _linkOneSignal(id, tc: tc);

        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          CupertinoPageRoute(builder: (_) => const HomePage()),
        );
      }
    } catch (e) {
      _showAlert('Hata', 'Sunucu hatası: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showAlert(String title, String msg) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: [
          CupertinoDialogAction(
            child: const Text('Tamam'),
            onPressed: () => Navigator.of(context).pop(),
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tcController.dispose();
    _pwController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Giriş Yap'),
      ),
      resizeToAvoidBottomInset: true,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            24,
            32,
            24,
            MediaQuery.of(context).viewInsets.bottom + 32,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/derneklogo.png', width: 180, height: 180),
              const SizedBox(height: 12),
              const Text(
                'Tokat Yağmurlu Derneği',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: CupertinoColors.activeBlue,
                ),
              ),
              const SizedBox(height: 32),

              CupertinoTextField(
                controller: _tcController,
                keyboardType: TextInputType.number,
                placeholder: 'TC Kimlik No',
                padding: const EdgeInsets.all(16),
                prefix: const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(CupertinoIcons.person),
                ),
              ),
              const SizedBox(height: 16),

              CupertinoTextField(
                controller: _pwController,
                obscureText: true,
                placeholder: 'Şifre',
                padding: const EdgeInsets.all(16),
                prefix: const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(CupertinoIcons.lock),
                ),
              ),
              const SizedBox(height: 32),

              _loading
                  ? const CupertinoActivityIndicator()
                  : CupertinoButton.filled(
                onPressed: _onLogin,
                child: const Text('Giriş Yap'),
              ),
              const SizedBox(height: 16),

              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () {
                  Navigator.of(context).push(
                    CupertinoPageRoute(builder: (_) => const RegisterPage()),
                  );
                },
                child: const Text(
                  'Hesabınız yok mu? Kayıt Ol',
                  style: TextStyle(
                    color: CupertinoColors.activeBlue,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
