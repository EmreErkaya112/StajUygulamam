// lib/home_page.dart

import 'dart:math';
import 'dart:ui' show ImageFilter; // blur için
import 'package:flutter/services.dart'; // haptic için
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'; // sadece gölgeler/snackbar için
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'businesses_page.dart';
import 'events_page.dart';
import 'jobs_cupertino_page.dart';
import 'login_page.dart';
import 'profile_page.dart';
import 'feedback_page.dart';
import 'post_detail_page.dart';
import 'story_detail_page.dart';
import 'transactions_page.dart';
import 'polls_page.dart';
import 'about_page.dart';
import 'gallery_page.dart';
import 'payments_page.dart';
import 'privacy_policy_page.dart';


/// Post modeli
int _asInt(dynamic v) {
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v == null) return 0;
  return int.tryParse(v.toString()) ?? 0;
}
bool isGoldAudience(String? s) {
  final a = (s ?? '').toLowerCase().trim();
  // "gold", "sadece gold üyelere", "gold üyeler" vs. hepsini yakalar
  return a.contains('gold');
}

bool isPublicAudience(String? s) {
  final a = (s ?? '').toLowerCase().trim();
  // "herkes", "herkese", "public", boş gelenler → herkese açık say
  return a.isEmpty || a.startsWith('herk') || a == 'public' || a == 'everyone';
}

bool isGoldUserFrom(Map<String, dynamic>? user) {
  final paketRaw = ((user?['paket']) ?? '').toString().toLowerCase();
  // "gold", "gold üye", "gold üyelik" vb. hepsini yakalar
  return paketRaw.contains('gold');
}

class Post {
  final int id;
  final String title, content, audience, imageUrl, createdAt;
  int likes, dislikes;
  String userReaction;

  Post({
    required this.id,
    required this.title,
    required this.content,
    required this.audience,
    required this.imageUrl,
    required this.createdAt,
    required this.likes,
    required this.dislikes,
    required this.userReaction,
  });

  factory Post.fromJson(Map<String, dynamic> j) => Post(
    id: _asInt(j['id']),
    title: (j['title'] ?? '') as String,
    content: (j['content'] ?? '') as String,
    // önemli: stringe çevir, trimle (lowercase’i UI/filtre tarafında kullanacağız)
    audience: ((j['audience'] ?? '')).toString().trim(),
    imageUrl: (j['imageUrl'] ?? '') as String,
    createdAt: (j['created_at'] ?? '') as String,
    likes: _asInt(j['likes']),
    dislikes: _asInt(j['dislikes']),
    userReaction: (j['userReaction'] ?? 'none').toString(),
  );


}

/// Comment modeli
class Comment {
  final int id;
  final String author, comment, createdAt;

  Comment({
    required this.id,
    required this.author,
    required this.comment,
    required this.createdAt,
  });

  factory Comment.fromJson(Map<String, dynamic> j) => Comment(
    id: j['id'] as int,
    author: j['author'] as String,
    comment: j['comment'] as String,
    createdAt: j['created_at'] as String,
  );
}

/// Ana Sayfa
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _user;
  List<Post> _posts = [];
  bool _loading = true;


  // SOL KAYAR MENÜ
  late final AnimationController _menuController;
  final double _menuWidth = 300;

  void _toggleMenu() {
    if (_menuController.isDismissed) {
      HapticFeedback.lightImpact();
      _menuController.forward();
    } else {
      _menuController.reverse();
    }
  }

  void _closeMenu() {
    if (!_menuController.isDismissed) _menuController.reverse();
  }

  @override
  void initState() {
    super.initState();
    _menuController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _initialize();

  }

  @override
  void dispose() {
    _menuController.dispose();
    super.dispose();
  }



  /// 1) Kullanıcı ve postları yükle
  Future<void> _initialize() async {
    await _loadUser();
    if (_user != null) await _loadPosts();
    setState(() => _loading = false);
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt('userId');
    if (id == null) return;
    final res =
    await http.get(Uri.parse('https://yagmurlukoyu.org/api/get_user.php?id=$id'));
    if (res.statusCode == 200) {
      final b = json.decode(res.body);
      if (b['success'] == true) _user = b['data'];
    }
  }

  Future<void> _loadPosts() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getInt('userId') ?? 0;
    final paketRaw = ((_user?['paket']) ?? '').toString().toLowerCase();
    final isGoldUser = paketRaw.contains('gold');
    final res = await http.get(Uri.parse(
        'https://yagmurlukoyu.org/api/get_posts.php'
            '?userId=$uid&page=1&pageSize=100'
            '&viewer=${isGoldUser ? 'gold' : 'public'}' // <<< eklendi
    ));
    if (res.statusCode == 200) {
      final b = json.decode(res.body);
      if (b['success'] == true) {
        final all = (b['data'] as List)
            .map((j) => Post.fromJson(j as Map<String, dynamic>))
            .toList();

        final bool isGoldUser = isGoldUserFrom(_user);

        // GOLD kullanıcı: tüm postlar
        // Standart kullanıcı: sadece herkese açık postlar
        _posts = isGoldUser
            ? all
            : all.where((p) => isPublicAudience(p.audience)).toList();

        // (İsteğe bağlı) Console’a hızlı teşhis için:
        // for (final p in all) {
        //   debugPrint('post#${p.id} audience="${p.audience}"  gold? ${isGoldAudience(p.audience)}  public? ${isPublicAudience(p.audience)}');
        // }
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    // Yükleniyorsa göster
    if (_loading) {
      return const Center(child: CupertinoActivityIndicator());
    }

    // Kullanıcı yoksa hata
    if (_user == null) {
      return CupertinoPageScaffold(
        navigationBar:
        CupertinoNavigationBar(middle: const Text('Ana Sayfa')),
        child:
        const Center(child: Text('Kullanıcı bilgisi yüklenemedi.')),
      );
    }

    final mainScaffold = _buildMainScaffold();

    return WillPopScope(
      onWillPop: () async {
        if (_menuController.value > 0.05) {
          _closeMenu();
          return false;
        }
        return true;
      },
      child: Stack(
        children: [
          // 1) Sol menü paneli
          AnimatedBuilder(
            animation: _menuController,
            builder: (context, _) {
              final t = Curves.easeOut.transform(_menuController.value);
              final left = -_menuWidth + _menuWidth * t;
              return Positioned(
                left: left,
                top: 0,
                bottom: 0,
                width: _menuWidth,
                child: _SideMenu(
                  user: _user!,
                  onClose: _closeMenu,
                  goProfile: () {
                    _closeMenu();
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                          builder: (_) => const ProfilePage()),
                    );
                  },
                  goPolls: () {
                    _closeMenu();
                    Navigator.of(context).push(
                      CupertinoPageRoute(builder: (_) => const PollsPage()),
                    );
                  },
                  goPayments: () {
                    _closeMenu();
                    Navigator.of(context).push(
                      CupertinoPageRoute(builder: (_) => PaymentsPage()),
                    );
                  },
                  goGallery: () {
                    _closeMenu();
                    Navigator.of(context).push(
                      CupertinoPageRoute(builder: (_) => const GalleryPage()),
                    );
                  },
                  goTransactions: () {
                    _closeMenu();
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                          builder: (_) => const TransactionsPage()),
                    );
                  },
                  goFeedback: () {
                    _closeMenu();
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                          builder: (_) => const FeedbackPage()),
                    );
                  },
                  goAbout: () {
                    _closeMenu();
                    Navigator.of(context).push(
                      CupertinoPageRoute(builder: (_) => const AboutPage()),
                    );
                  },
                  goPrivacy: () {
                    _closeMenu();
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                          builder: (_) => const PrivacyPolicyPage()),
                    );
                  },
                  doLogout: () async {

                    _closeMenu();
                    await OneSignal.logout();
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.remove('loggedIn');
                    await prefs.remove('userId');
                    if (!mounted) return;
                    Navigator.of(context).pushAndRemoveUntil(
                      CupertinoPageRoute(builder: (_) => const LoginPage()),
                          (route) => false,
                    );
                  },
                ),
              );
            },
          ),

          // 2) Karartma + blur overlay


          // 3) Ana içerik: sağa kaydır + scale + radius
          AnimatedBuilder(
            animation: _menuController,
            child: mainScaffold,
            builder: (context, child) {
              final t = Curves.easeOut.transform(_menuController.value);
              final dx = _menuWidth * t; // MENÜ KADAR kaydır
              final scale = 1 - 0.05 * t;
              final radius = 18.0 * t;
              return Transform(
                transform: Matrix4.identity()
                  ..translate(dx)
                  ..scale(scale, scale),
                alignment: Alignment.center,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(radius),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      boxShadow: t > 0
                          ? [
                        BoxShadow(
                            color: Colors.black12,
                            blurRadius: 12,
                            offset: const Offset(0, 8))
                      ]
                          : const [],
                    ),
                    child: AbsorbPointer(
                      absorbing: t > 0.01,
                      child: child,
                    ),
                  ),
                ),
              );
            },
          ),
// 3.5) (GÜNCEL) Karartma + blur overlay: İçeriğin ÜSTÜNE ve menünün DIŞINA
          AnimatedBuilder(
            animation: _menuController,
            builder: (context, _) {
              final t = Curves.easeOut.transform(_menuController.value);
              if (t == 0) return const SizedBox.shrink();

              final overlayLeft = _menuWidth * t; // menünün bittiği yer

              return Positioned(
                left: overlayLeft, right: 0, top: 0, bottom: 0,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _closeMenu,
                  child: ClipRect( // <<< EKLENDİ: blur’u bu dikdörtgenle sınırla
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 6 * t, sigmaY: 6 * t),
                      child: Container(
                        color: Colors.black.withOpacity(0.15 * t),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),


          // 4) Kenardan sürükleyerek açma
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 20,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragUpdate: (details) {
                final delta = details.primaryDelta ?? 0;
                _menuController.value =
                    (_menuController.value + delta / _menuWidth)
                        .clamp(0.0, 1.0);
              },
              onHorizontalDragEnd: (details) {
                final v = details.velocity.pixelsPerSecond.dx;
                if (_menuController.value > 0.5 || v > 400) {
                  _menuController.forward();
                } else {
                  _menuController.reverse();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  // ————— Ana içeriği döndüren Scaffold (mevcut yapın korunuyor)
  Widget _buildMainScaffold() {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _toggleMenu,
          child: const Icon(CupertinoIcons.bars),
        ),
        // middle yerine Row kullanıyoruz:
        middle: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                'YAĞMURLU DERNEĞİ',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Baloo2',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('userId');
            if (!mounted) return;
            Navigator.of(context).pushAndRemoveUntil(
              CupertinoPageRoute(builder: (_) => const LoginPage()),
                  (route) => false,
            );
          },
          child: const Icon(CupertinoIcons.power),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ――― “Hoşgeldin” başlığı
            Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                'Hoş geldin, ${_user!['firstName']} ${_user!['lastName']}!',
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),


            const Divider(),
            // ――― Post listesi
            Expanded(
              child: ListView.builder(
                padding:
                const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _posts.length,
                itemBuilder: (_, i) => PostCard(post: _posts[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class PostCard extends StatefulWidget {
  final Post post;
  const PostCard({required this.post, super.key});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> with SingleTickerProviderStateMixin {
  late Post p;
  bool _busy = false;

  // Yorumlar
  bool _commentsVisible = false;
  bool _loadingComments = false;
  List<Comment> _comments = [];
  int _commentsToShow = 5;

  // Yorum ekleme
  final TextEditingController _commentCtrl = TextEditingController();
  bool _posting = false;

  // UI: içerik aç/kapa + küçük animler
  bool _expanded = false;
  double _likeScale = 1.0;
  double _dislikeScale = 1.0;

  @override
  void initState() {
    super.initState();
    p = widget.post;
  }
  void _openDetail() {
    Navigator.of(context).push(
      CupertinoPageRoute(builder: (_) => PostDetailPage(post: p)),
    );
  }

  // --------- API tarafı (sizdekiyle aynı mantık) ---------
  Future<void> _loadComments() async {
    setState(() { _commentsVisible = true; _loadingComments = true; });

    final res = await http.get(
      Uri.parse('https://yagmurlukoyu.org/api/get_comments.php?postId=${p.id}'),
    );

    if (res.statusCode == 200) {
      final b = json.decode(res.body);
      if (b['success'] == true) {
        _comments = (b['data'] as List)
            .map((j) => Comment.fromJson(j as Map<String, dynamic>))
            .toList();
        _comments.sort((a, b) =>
            DateTime.parse(b.createdAt).compareTo(DateTime.parse(a.createdAt)));
      }
    }

    setState(() {
      _loadingComments = false;
      _commentsToShow = (_comments.length < 5) ? _comments.length : 5;
    });
  }

  void _toggleCommentCount() {
    setState(() {
      if (_commentsToShow < _comments.length) {
        _commentsToShow = _comments.length;
      } else {
        _commentsToShow = (_comments.length < 5) ? _comments.length : 5;
      }
    });
  }

  void _reportComment(int id) {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: const Text('Yorumu bildir'),
        message: const Text('Bu yorumu neden bildiriyorsunuz?'),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Uygunsuz içerik'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Diğer'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('İptal'),
        ),
      ),
    );
  }

  Future<void> _addComment() async {
    final txt = _commentCtrl.text.trim();
    if (txt.isEmpty) return;

    setState(() => _posting = true);
    final uid = (await SharedPreferences.getInstance()).getInt('userId');
    final res = await http.post(
      Uri.parse('https://yagmurlukoyu.org/api/add_comment.php'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'postId': p.id, 'userId': uid, 'comment': txt}),
    );
    final body = res.body.trim();
    if (body.startsWith('{')) {
      final b = json.decode(body);
      if (b['success'] == true) {
        _commentCtrl.clear();
        await _loadComments();
      }
    }
    setState(() => _posting = false);
  }

  Future<void> _react(String reaction) async {
    if (_busy) return;

    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getInt('userId');
    if (uid == null || uid <= 0) {
      showCupertinoDialog(
        context: context,
        builder: (_) => const CupertinoAlertDialog(
          title: Text('Giriş gerekli'),
          content: Text('Beğenmek için giriş yapmalısınız.'),
          actions: [CupertinoDialogAction(child: Text('Tamam'))],
        ),
      );
      return;
    }

    // küçük haptic + scale
    if (reaction == 'like') {
      HapticFeedback.lightImpact();
      setState(() => _likeScale = 0.9);
      Future.delayed(const Duration(milliseconds: 90),
              () => setState(() => _likeScale = 1.0));
    } else {
      HapticFeedback.lightImpact();
      setState(() => _dislikeScale = 0.9);
      Future.delayed(const Duration(milliseconds: 90),
              () => setState(() => _dislikeScale = 1.0));
    }

    setState(() => _busy = true);
    try {
      final res = await http
          .post(
        Uri.parse('https://yagmurlukoyu.org/api/react.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'userId': uid, 'postId': p.id, 'reaction': reaction}),
      )
          .timeout(const Duration(seconds: 12));

      final body = res.body.trim();
      if (res.statusCode == 200 && body.startsWith('{')) {
        final b = json.decode(body) as Map<String, dynamic>;
        if (b['success'] == true) {
          setState(() {
            p.likes     = _asInt(b['likes']);
            p.dislikes  = _asInt(b['dislikes']);
            final action = (b['action'] ?? '').toString();
            final serverReaction = (b['reaction'] ?? 'none').toString();
            p.userReaction = action == 'removed' ? 'none' : serverReaction;
          });
        }
      }
    } catch (_) {
      _showToast('Bağlantı sorunu oluştu');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showToast(String msg) {
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (_) => Positioned(
        bottom: 80, left: 24, right: 24,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xCC333333),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Center(child: Text(msg, style: const TextStyle(color: Colors.white))),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 2), () => entry.remove());
  }

  bool get _isGoldPost => p.audience.toLowerCase() == 'gold';

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Color(0x15000000), blurRadius: 8, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---- KAPAK (varsa) ----
          if (p.imageUrl.isNotEmpty)
            GestureDetector(
                onTap: _openDetail,
                behavior: HitTestBehavior.opaque,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                  child: Stack(
                children: [
                  Image.network(
                    p.imageUrl,
                    height: 220, width: double.infinity, fit: BoxFit.cover,
                    loadingBuilder: (ctx, child, prog) {
                      if (prog == null) return child;
                      return const SizedBox(
                        height: 220,
                        child: Center(child: CupertinoActivityIndicator()),
                      );
                    },
                    errorBuilder: (_, __, ___) =>
                        Container(height: 220, color: CupertinoColors.systemGrey5),
                  ),
                  // Sadece GOLD gönderilerde rozet (sol üst)
                  if (_isGoldPost)
                    Positioned(
                      left: 10, top: 10,
                      child: _Chip(text: 'Gold', color: const Color(0xFFB8860B)),
                    ),
                  // Başlık görüntüde, ama tarih artık gövdede
                  Positioned(
                    left: 0, right: 0, bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 28, 12, 12),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter, end: Alignment.bottomCenter,
                          colors: [Color(0x00000000), Color(0x80000000)],
                        ),
                      ),
                      child: Text(
                        p.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: CupertinoColors.white,
                          fontSize: 18, fontWeight: FontWeight.w600,
                          shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ),
          // ---- Gövde başlık (sadece resim YOKSA) ----
          if (p.imageUrl.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Row(
                children: [
                  if (_isGoldPost)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _Chip(text: 'Gold', color: const Color(0xFFB8860B)),
                    ),
                  Expanded(
                    child: Text(
                      p.title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),

          // ---- Tarih (her zaman burada) ----
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
            child: Row(
              children: [
                const Icon(CupertinoIcons.calendar, size: 16, color: CupertinoColors.inactiveGray),
                const SizedBox(width: 6),
                Text(
                  p.createdAt,
                  style: const TextStyle(fontSize: 12, color: CupertinoColors.inactiveGray),
                ),
              ],
            ),
          ),

          // ---- İçerik özeti ----
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: AnimatedCrossFade(
              crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 180),
              firstChild: Text(
                p.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15),
              ),
              secondChild: Text(p.content, style: const TextStyle(fontSize: 15)),
            ),
          ),
          if (p.content.length > 120)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  onPressed: () => setState(() => _expanded = !_expanded),
                  child: Text(
                    _expanded ? 'Daha az göster' : 'Devamını göster',
                    style: const TextStyle(color: CupertinoColors.activeBlue, fontSize: 13),
                  ),
                ),
              ),
            ),

          // ---- Aksiyonlar ----
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                AnimatedScale(
                  scale: _likeScale, duration: const Duration(milliseconds: 90),
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    onPressed: () => _react('like'),
                    child: Row(children: [
                      Icon(
                        CupertinoIcons.hand_thumbsup_fill,
                        color: p.userReaction == 'like'
                            ? CupertinoColors.activeBlue
                            : CupertinoColors.inactiveGray,
                      ),
                      const SizedBox(width: 4),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 150),
                        transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                        child: Text('${p.likes}', key: ValueKey(p.likes)),
                      ),
                    ]),
                  ),
                ),
                AnimatedScale(
                  scale: _dislikeScale, duration: const Duration(milliseconds: 90),
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    onPressed: () => _react('dislike'),
                    child: Row(children: [
                      Icon(
                        CupertinoIcons.hand_thumbsdown_fill,
                        color: p.userReaction == 'dislike'
                            ? CupertinoColors.destructiveRed
                            : CupertinoColors.inactiveGray,
                      ),
                      const SizedBox(width: 4),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 150),
                        transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                        child: Text('${p.dislikes}', key: ValueKey(p.dislikes)),
                      ),
                    ]),
                  ),
                ),
                const Spacer(),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  onPressed: _commentsVisible
                      ? () => setState(() => _commentsVisible = false)
                      : _loadComments,
                  child: const Icon(CupertinoIcons.chat_bubble_2),
                ),
              ],
            ),
          ),

          // ---- Yorumlar ----
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: _commentsVisible
                ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: CupertinoColors.systemGrey6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_loadingComments)
                    const Center(child: CupertinoActivityIndicator())
                  else ...[
                    for (var c in _comments.take(_commentsToShow))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(CupertinoIcons.person_solid,
                                size: 16, color: CupertinoColors.inactiveGray),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(c.author, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 2),
                                  Text(c.comment),
                                  const SizedBox(height: 2),
                                  Text(c.createdAt,
                                      style: const TextStyle(fontSize: 11, color: CupertinoColors.inactiveGray)),
                                ],
                              ),
                            ),
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () => _reportComment(c.id),
                              child: const Icon(CupertinoIcons.exclamationmark_bubble, size: 20),
                            ),
                          ],
                        ),
                      ),
                    if (_comments.length > 5)
                      Center(
                        child: CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: _toggleCommentCount,
                          child: const Text('Daha fazla yorum yükle',
                              style: TextStyle(color: CupertinoColors.activeBlue)),
                        ),
                      ),
                    const Divider(),
                    Row(
                      children: [
                        Expanded(
                          child: CupertinoTextField(
                            controller: _commentCtrl,
                            placeholder: 'Yorum yazın…',
                          ),
                        ),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: _posting ? null : _addComment,
                          child: _posting
                              ? const CupertinoActivityIndicator()
                              : const Icon(CupertinoIcons.arrow_up_circle_fill, size: 24),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// küçük rozet
class _Chip extends StatelessWidget {
  final String text;
  final Color color;
  const _Chip({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CupertinoColors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1),
        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 6, offset: Offset(0, 3))],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(text,
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
      ),
    );
  }
}



// ——————————————— SOL MENÜ WIDGET’LARI ———————————————

class _SideMenu extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onClose;
  final VoidCallback goProfile;
  final VoidCallback goPolls;
  final VoidCallback goPayments;
  final VoidCallback goGallery;
  final VoidCallback goTransactions;
  final VoidCallback goFeedback;
  final VoidCallback goAbout;
  final VoidCallback goPrivacy;
  final Future<void> Function() doLogout;

  const _SideMenu({
    required this.user,
    required this.onClose,
    required this.goProfile,
    required this.goPolls,
    required this.goPayments,
    required this.goGallery,
    required this.goTransactions,
    required this.goFeedback,
    required this.goAbout,
    required this.goPrivacy,
    required this.doLogout,
  });

  @override
  Widget build(BuildContext context) {
    final name =
    '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();
    final initials = name.isNotEmpty
        ? name
        .split(' ')
        .where((e) => e.isNotEmpty)
        .map((e) => e[0])
        .take(2)
        .join()
        .toUpperCase()
        : 'U';

    return Container(
      decoration: const BoxDecoration(
        color: CupertinoColors.systemGroupedBackground,
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 16)],
      ),
      child: SafeArea(
        bottom: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFE8F0FE),
                    Color(0xFFF8FBFF),
                  ],
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: CupertinoColors.activeBlue,
                    child: Text(initials,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name.isEmpty ? 'Misafir' : name,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                        Text(user['email'] ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12,
                                color: CupertinoColors.inactiveGray)),
                      ],
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: onClose,
                    child: const Icon(CupertinoIcons.xmark_circle_fill,
                        size: 24,
                        color: CupertinoColors.inactiveGray),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Menü öğeleri
            _MenuItem(
                icon: CupertinoIcons.person,
                label: 'Profil',
                onTap: goProfile),
            _MenuItem(
                icon: CupertinoIcons.chart_bar,
                label: 'Anketler',
                onTap: goPolls),
            _MenuItem(
                icon: CupertinoIcons.creditcard,
                label: 'Ödemelerim',
                onTap: goPayments),
            _MenuItem(
                icon: CupertinoIcons.photo_on_rectangle,
                label: 'Galerimiz',
                onTap: goGallery),
            _MenuItem(
                icon: CupertinoIcons.doc_text_search,
                label: 'Dernek Muhasebesi',
                onTap: goTransactions),
            _MenuItem(
                icon: CupertinoIcons.bubble_left_bubble_right,
                label: 'İstek & Şikayetler',
                onTap: goFeedback),
            _MenuItem(
              icon: CupertinoIcons.building_2_fill,
              label: 'İşletmeler',
              onTap: () {
                onClose();
                Navigator.of(context).push(
                  CupertinoPageRoute(builder: (_) => const BusinessesPage()),
                );
              },
            ),
            _MenuItem(
              icon: CupertinoIcons.briefcase_fill, // işe alım / kariyer için ideal
              label: 'İş İlanları',
              onTap: () {
                onClose();
                Navigator.of(context).push(
                  CupertinoPageRoute(builder: (_) => const JobsCupertinoPage()),
                );
              },
            ),

            _MenuItem(
              icon: CupertinoIcons.calendar,
              label: 'Etkinliklerimiz',
              onTap: () {
                onClose();
                Navigator.of(context).push(
                  CupertinoPageRoute(builder: (_) => const EventsPage()),
                );
              },
            ),

            _MenuItem(
                icon: CupertinoIcons.info,
                label: 'Hakkımızda',
                onTap: goAbout),
            _MenuItem(
                icon: CupertinoIcons.lock,
                label: 'Gizlilik Politikaları',
                onTap: goPrivacy),

            const Spacer(),
            const Divider(height: 1),
            _MenuItem(
              icon: CupertinoIcons.power,
              label: 'Çıkış Yap',
              destructive: true,
              onTap: () async => await doLogout(),
            ),
          ],
        ),
      ),
    );
  }
}


class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22,
                color: destructive
                    ? CupertinoColors.destructiveRed
                    : CupertinoColors.activeBlue),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  color: destructive
                      ? CupertinoColors.destructiveRed
                      : CupertinoColors.label,
                ),
              ),
            ),
            const Icon(CupertinoIcons.chevron_right,
                size: 18, color: CupertinoColors.inactiveGray),
          ],
        ),
      ),
    );
  }
}
