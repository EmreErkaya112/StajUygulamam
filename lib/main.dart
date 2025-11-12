// main.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

// (Opsiyonel) Firebase kullanıyorsan
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'login_page.dart';
import 'home_page.dart';

const String kOneSignalAppId = 'e932afa0-2fb6-4ee9-8338-f89d634bb3c3';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.white,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  ));

  // (Opsiyonel) Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {}

  // OneSignal init
  OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
  OneSignal.initialize(kOneSignalAppId);
  await OneSignal.Notifications.requestPermission(true);

  // --- Gözlemciler (hata veren ".current" YOK) ---
  OneSignal.Notifications.addPermissionObserver((bool hasPermission) {
    // sadece true/false döner
    // ignore: avoid_print
    print('OneSignal permission: $hasPermission');
  });

  OneSignal.User.pushSubscription.addObserver((_) {
    final sub = OneSignal.User.pushSubscription;
    // ignore: avoid_print
    print('OneSignal sub -> id=${sub.id} token=${sub.token} optedIn=${sub.optedIn}');
  });

  // Oturum & external_id bağlama
  final prefs = await SharedPreferences.getInstance();
  final loggedIn = prefs.getBool('loggedIn') ?? false;
  if (loggedIn) {
    final uid = prefs.getInt('userId');
    if (uid != null) {
      // Güvenli: önce olası eski kimliği temizle, sonra doğru kullanıcıyla login
      await OneSignal.logout();
      await OneSignal.login(uid.toString());
    }
  } else {
    // Oturum yoksa kimliği temiz tut
    await OneSignal.logout();
  }

  // Hızlı teşhis log’u
  await Future<void>.delayed(const Duration(milliseconds: 150));
  final sub = OneSignal.User.pushSubscription;
  // ignore: avoid_print
  print('[OneSignal] extId=(set by login) subId=${sub.id} token=${sub.token} optedIn=${sub.optedIn}');

  runApp(MyApp(loggedIn: loggedIn));
}

class MyApp extends StatelessWidget {
  final bool loggedIn;
  const MyApp({required this.loggedIn, super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      debugShowCheckedModeBanner: false,
      theme: CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: CupertinoColors.activeBlue,
      ),
      // Giriş kontrolünü üstte yaptık, Home/Login yönlendirmesini oraya taşı
      home: LoginOrHomeGate(),
    );
  }
}

/// İsteğe bağlı küçük bir kapı: loggedIn durumunu burada da kontrol edebilirsin
class LoginOrHomeGate extends StatefulWidget {
  const LoginOrHomeGate({super.key});
  @override
  State<LoginOrHomeGate> createState() => _LoginOrHomeGateState();
}

class _LoginOrHomeGateState extends State<LoginOrHomeGate> {
  bool? _logged;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      setState(() => _logged = p.getBool('loggedIn') ?? false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_logged == null) {
      return const CupertinoPageScaffold(
        child: Center(child: CupertinoActivityIndicator()),
      );
    }
    return _logged! ? const HomePage() : const LoginPage();
  }
}
