import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _tcController = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _emailController = TextEditingController();
  final _pwController = TextEditingController();
  String _selectedPaket = 'Standart';
  bool _loading = false;

  // Yeni: Sözleşme onayı
  bool _accepted = false;

  Future<void> _onRegister() async {
    if (!_accepted) {
      return _showAlert('Bilgi', 'Lütfen kullanıcı sözleşmesini kabul edin.');
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final payload = {
      'status': 'pasif',
      'firstName': _firstNameCtrl.text.trim(),
      'lastName': _lastNameCtrl.text.trim(),
      'address': _addressController.text.trim(),
      'phone': _phoneController.text.trim(),
      'tc': _tcController.text.trim(),
      'email': _emailController.text.trim(),
      'password': _pwController.text.trim(),
      'isActive': 0,
      'paket': _selectedPaket,
    };
    debugPrint('▶️ Payload: ${json.encode(payload)}');

    late http.Response response;
    try {
      response = await http.post(
        Uri.parse('https://erkayasoft.com/api/add.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );
    } catch (e) {
      setState(() => _loading = false);
      return _showAlert('Hata', 'Sunucuya bağlanılamadı:\n\$e');
    }

    debugPrint('◀️ HTTP \${response.statusCode}:\n\${response.body}');
    setState(() => _loading = false);

    dynamic body;
    try {
      body = json.decode(response.body);
    } catch (e) {
      return _showAlert(
        'Sunucu Yanıtı Hatası',
        'Beklenen JSON yerine farklı bir yanıt alındı.\n\n\${response.body}',
      );
    }

    if (response.statusCode == 200 && body is Map<String, dynamic>) {
      if (body['success'] == true) {
        await showCupertinoDialog(
          context: context,
          builder: (_) => CupertinoAlertDialog(
            title: const Text('Başarılı'),
            content: const Text(
                'Hesabınız onaylandıktan sonra giriş yapabilirsiniz.\n'
                    'Telefonunuza onaylandıktan sonra SMS gelecektir.'
            ),
            actions: [
              CupertinoDialogAction(
                child: const Text('Tamam'),
                onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
              )
            ],
          ),
        );
      } else {
        final error = body['error'] ?? 'Bilinmeyen hata';
        _showAlert('Kayıt Hatası', error);
      }
    } else {
      String msg = 'HTTP \${response.statusCode}';
      if (body is Map && body['error'] != null) {
        msg += '\n${body["error"]}';
      }
      _showAlert('Sunucu Hatası', msg);
    }
  }

  String? _nonEmptyValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'Bu alan boş geçilemez';
    return null;
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

  // Yeni: Sözleşme metni gösterimi
  void _showAgreement() {
    const agreement = '''
1. Gizlilik: Kayıt sırasında verdiğiniz bilgiler, tarafımızca gizli tutulacak ve üçüncü kişilerle paylaşılmayacaktır.
2. Kullanım Koşulları: Uygulamayı yasa dışı faaliyetler için kullanmamakla yükümlüsünüz.
3. Sorumluluk Reddi: Uygulama içeriğinin kesintisiz veya hatasız çalışacağına dair garanti verilmez.
4. Veri Güvenliği: Veritabanında saklanan kişisel verileriniz güvenli sunucularda tutulmaktadır.
5. İptal ve İade: Üyelik paketleri onaylandıktan sonra iptal edilemez.
6. Uygulama Güncellemeleri: Sözleşme değişiklikleri doğrudan uygulamaya yansıtılacak ve bildirim yapılacaktır.
''';

    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Kullanıcı Sözleşmesi'),
        content: SizedBox(
          height: 300,
          child: SingleChildScrollView(
            child: const Text(agreement),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Kapat'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tcController.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    _pwController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Kayıt Ol'),
      ),
      child: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            children: [
              Center(
                child: Icon(
                  CupertinoIcons.person_circle,
                  size: 80,
                  color: CupertinoColors.activeBlue,
                ),
              ),
              const SizedBox(height: 24),

              // Kişisel Bilgiler Bölümü
              CupertinoFormSection.insetGrouped(
                header: const Text('Kişisel Bilgiler'),
                children: [
                  CupertinoTextFormFieldRow(
                    controller: _tcController,
                    keyboardType: TextInputType.number,
                    placeholder: 'TC Kimlik No',
                    validator: _nonEmptyValidator,
                  ),
                  CupertinoTextFormFieldRow(
                    controller: _firstNameCtrl,
                    placeholder: 'Adınız',
                    validator: _nonEmptyValidator,
                  ),
                  CupertinoTextFormFieldRow(
                    controller: _lastNameCtrl,
                    placeholder: 'Soyadınız',
                    validator: _nonEmptyValidator,
                  ),
                  CupertinoTextFormFieldRow(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    placeholder: 'Telefon Numaranız',
                    validator: _nonEmptyValidator,
                  ),
                  CupertinoTextFormFieldRow(
                    controller: _addressController,
                    placeholder: 'Adresiniz',
                    validator: _nonEmptyValidator,
                  ),
                  CupertinoTextFormFieldRow(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    placeholder: 'E‑posta',
                    validator: (v) {
                      if (v == null || !v.contains('@')) {
                        return 'Geçerli bir e‑posta girin';
                      }
                      return null;
                    },
                  ),
                  CupertinoTextFormFieldRow(
                    controller: _pwController,
                    obscureText: true,
                    placeholder: 'Şifre',
                    validator: _nonEmptyValidator,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Paket Seçimi
              const Text(
                'Paket Seçimi:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              CupertinoSegmentedControl<String>(
                children: const {
                  'Standart': Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Standart'),
                  ),
                  'Gold': Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Gold'),
                  ),
                },
                groupValue: _selectedPaket,
                onValueChanged: (val) => setState(() => _selectedPaket = val),
              ),

              const SizedBox(height: 24),

              // Yeni: Sözleşme Onayı Bölümü
              CupertinoFormSection.insetGrouped(
                header: const Text('Sözleşme Onayı'),
                children: [
                  Row(
                    children: [
                      CupertinoSwitch(
                        value: _accepted,
                        onChanged: (val) => setState(() => _accepted = val),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: _showAgreement,
                          child: const Text(
                            'Kullanıcı Sözleşmesini okudum ve kabul ediyorum',
                            style: TextStyle(
                              decoration: TextDecoration.underline,
                              color: CupertinoColors.activeBlue,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Kayıt Butonu
              _loading
                  ? const CupertinoActivityIndicator()
                  : CupertinoButton.filled(
                onPressed: _onRegister,
                child: const Text('Kayıt Ol'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
