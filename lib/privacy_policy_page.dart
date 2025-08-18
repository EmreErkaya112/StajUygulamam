// lib/privacy_policy_page.dart

import 'package:flutter/cupertino.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({Key? key}) : super(key: key);

  // Örnek gizlilik politikası metni
  static const String _policyText = '''
GİZLİLİK POLİTİKASI

1. Toplanan Bilgiler
- Ad, soyad, e-posta, telefon numarası gibi kişisel veriler.

2. Bilgi Kullanımı
- Hizmet iyileştirmeleri, kullanıcı desteği ve yasal yükümlülükler için kullanılır.

3. Bilgi Paylaşımı
- Kişisel veriler üçüncü taraflarla paylaşılmaz; yasal zorunluluklar saklıdır.

4. Güvenlik
- Tüm veriler TLS şifrelemesi ile korunur ve güvenli sunucularda saklanır.

5. Çocukların Gizliliği
- 18 yaş altı kullanıcılar için özel izin gereklidir.

6. Değişiklikler
- Gizlilik politikası güncellendiğinde uygulama içinde bildirim yapılacaktır.
''';

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Gizlilik Politikası'),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Text(
            _policyText,
            style: const TextStyle(
              fontSize: 16,
              height: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}
