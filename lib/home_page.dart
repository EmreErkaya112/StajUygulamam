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

class Story {
  final int id;
  final String companyName, phone, website, description, imageUrl;
  final bool isActive;
  final String createdAt;

  Story({
    required this.id,
    required this.companyName,
    required this.phone,
    required this.website,
    required this.description,
    required this.imageUrl,
    required this.isActive,
    required this.createdAt,
  });

  factory Story.fromJson(Map<String, dynamic> j) {
    final raw = j['is_active'];
    final bool active = (raw is bool && raw) ||
        raw.toString() == '1' ||
        raw.toString().toLowerCase() == 'true';

    return Story(
      id: j['id'] as int,
      companyName: (j['company_name'] as String?) ?? '',
      phone: (j['phone'] as String?) ?? '',
      website: (j['website'] as String?) ?? '',
      description: (j['description'] as String?) ?? '',
      imageUrl: (j['image_url'] as String?) ?? '',
      isActive: active,
      createdAt: (j['created_at'] as String?) ?? '',
    );
  }
}

/// Post modeli
int _asInt(dynamic v) {
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v == null) return 0;
  return int.tryParse(v.toString()) ?? 0;
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
    audience: (j['audience'] ?? 'herkes') as String,
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
  List<Story> _stories = [];
  bool _loadingStories = true;

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
    _loadStories();
  }

  @override
  void dispose() {
    _menuController.dispose();
    super.dispose();
  }

  Future<void> _loadStories() async {
    setState(() => _loadingStories = true);
    final res = await http
        .get(Uri.parse('https://erkayasoft.com/api/get_stories.php'));
    if (res.statusCode == 200) {
      final b = json.decode(res.body);
      if (b['success'] == true) {
        final List<Story> fetched = [];
        for (var item in (b['data'] as List)) {
          try {
            final s = Story.fromJson(item as Map<String, dynamic>);
            if (s.isActive) {
              fetched.add(s);
            }
          } catch (_) {
            // parse hatası → kaydı atla
          }
        }
        _stories = fetched;
      }
    }
    setState(() => _loadingStories = false);
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
    await http.get(Uri.parse('https://erkayasoft.com/api/get_user.php?id=$id'));
    if (res.statusCode == 200) {
      final b = json.decode(res.body);
      if (b['success'] == true) _user = b['data'];
    }
  }

  Future<void> _loadPosts() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getInt('userId') ?? 0;
    final res = await http.get(Uri.parse(
        'https://erkayasoft.com/api/get_posts.php?userId=$uid&page=1&pageSize=100'));


    if (res.statusCode == 200) {
      final b = json.decode(res.body);
      if (b['success'] == true) {
        final all = (b['data'] as List)
            .map((j) => Post.fromJson(j as Map<String, dynamic>))
            .toList();
        final paket = (_user!['paket'] as String).toLowerCase();
        _posts = all.where((p) {
          final aud = p.audience.toLowerCase();
          return aud == paket || aud == 'herkes';
        }).toList();
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
            SizedBox(
              height: 100,
              child: _loadingStories
                  ? const Center(child: CupertinoActivityIndicator())
                  : _stories.isEmpty
                  ? const Center(
                child: Text(
                  'Henüz hikâye yok',
                  style: TextStyle(
                      color: CupertinoColors.inactiveGray),
                ),
              )
                  : ListView.separated(
                scrollDirection: Axis.horizontal,
                padding:
                const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _stories.length,
                separatorBuilder: (_, __) =>
                const SizedBox(width: 12),
                itemBuilder: (_, i) {
                  final s = _stories[i];
                  return GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        CupertinoPageRoute(
                            builder: (_) =>
                                StoryDetailPage(story: s)),
                      );
                    },
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundImage:
                          NetworkImage(s.imageUrl),
                          backgroundColor:
                          CupertinoColors.systemGrey5,
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: 72,
                          child: Text(
                            s.companyName,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  );
                },
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

class _PostCardState extends State<PostCard>
    with SingleTickerProviderStateMixin {
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

  @override
  void initState() {
    super.initState();
    p = widget.post;
  }

  Future<void> _loadComments() async {
    setState(() {
      _commentsVisible = true;
      _loadingComments = true;
    });

    final res = await http.get(
      Uri.parse(
          'https://erkayasoft.com/api/get_comments.php?postId=${p.id}'),
    );
    if (res.statusCode == 200) {
      final b = json.decode(res.body);
      if (b['success'] == true) {
        // 1) Ham listeyi oluştur
        _comments = (b['data'] as List)
            .map((j) => Comment.fromJson(j as Map<String, dynamic>))
            .toList();

        // 2) Tarihe göre ters sırala: en yeni en başta
        _comments.sort((a, b) =>
            DateTime.parse(b.createdAt)
                .compareTo(DateTime.parse(a.createdAt)));
      }
    }

    setState(() {
      _loadingComments = false;
      _commentsToShow =
      (_comments.length < 5) ? _comments.length : 5;
    });
  }

  void _toggleCommentCount() {
    setState(() {
      if (_commentsToShow < _comments.length) {
        _commentsToShow = _comments.length;
      } else {
        _commentsToShow =
        (_comments.length < 5) ? _comments.length : 5;
      }
    });
  }

  void _reportComment(int commentId) {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: const Text('Yorumu bildir'),
        message: const Text('Bu yorumu neden bildiriyorsunuz?'),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Rapor işlemi için API çağrısı
            },
            child: const Text('Uygunsuz içerik'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Diğer rapor sebebi
            },
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
      Uri.parse('https://erkayasoft.com/api/add_comment.php'),
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
      // Cupertino ortamında basit uyarı:
      showCupertinoDialog(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('Giriş gerekli'),
          content: const Text('Beğenmek için giriş yapmalısınız.'),
          actions: [CupertinoDialogAction(child: const Text('Tamam'), onPressed: () => Navigator.pop(context))],
        ),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final res = await http
          .post(
        Uri.parse('https://erkayasoft.com/api/react.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'userId': uid, 'postId': p.id, 'reaction': reaction}),
      )
          .timeout(const Duration(seconds: 12));

      final body = res.body.trim();
      // Debug istersen:
      // print('[react] status=${res.statusCode} body=$body');

      if (res.statusCode == 200 && body.startsWith('{')) {
        final b = json.decode(body) as Map<String, dynamic>;
        if (b['success'] == true) {
          final likes = _asInt(b['likes']);
          final dislikes = _asInt(b['dislikes']);
          final action = (b['action'] ?? '').toString();
          final serverReaction = (b['reaction'] ?? 'none').toString();

          setState(() {
            p.likes = likes;
            p.dislikes = dislikes;
            p.userReaction = action == 'removed' ? 'none' : serverReaction; // 'like' / 'dislike'
          });
        } else {
          _showToast(b['error']?.toString() ?? 'İşlem başarısız');
        }
      } else {
        _showToast('Sunucu hatası: ${res.statusCode}');
      }
    } catch (e) {
      _showToast('Bağlantı sorunu oluştu');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showToast(String msg) {
    // basit Cupertino toast
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (_) => Positioned(
        bottom: 80,
        left: 24,
        right: 24,
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


  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ▶ Görsele tıklayınca detay sayfasına geç
          if (p.imageUrl.isNotEmpty)
            GestureDetector(
              onTap: () => Navigator.of(context).push(
                CupertinoPageRoute(builder: (_) => PostDetailPage(post: p)),
              ),
              child: ClipRRect(
                borderRadius:
                const BorderRadius.vertical(top: Radius.circular(12)),
                child: Image.network(
                  p.imageUrl,
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Container(height: 150, color: CupertinoColors.systemGrey5),
                ),
              ),
            ),

          // ▶ Başlık, özet, tarih, reaksiyonlar
          Padding(
            padding: const EdgeInsets.all(12),
            child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  CupertinoPageRoute(builder: (_) => PostDetailPage(post: p)),
                ),
                child: Text(p.title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 6),
              Text(p.content, maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Text(p.createdAt,
                  style: const TextStyle(
                      fontSize: 12, color: CupertinoColors.inactiveGray)),
              const SizedBox(height: 12),
              Row(children: [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => _react('like'),
                  child: Row(children: [
                    Icon(
                      CupertinoIcons.hand_thumbsup_fill,
                      color: p.userReaction == 'like'
                          ? CupertinoColors.activeBlue
                          : CupertinoColors.inactiveGray,
                    ),
                    const SizedBox(width: 4),
                    Text('${p.likes}'),
                  ]),
                ),
                const SizedBox(width: 16),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => _react('dislike'),
                  child: Row(children: [
                    Icon(
                      CupertinoIcons.hand_thumbsdown_fill,
                      color: p.userReaction == 'dislike'
                          ? CupertinoColors.destructiveRed
                          : CupertinoColors.inactiveGray,
                    ),
                    const SizedBox(width: 4),
                    Text('${p.dislikes}'),
                  ]),
                ),
                const Spacer(),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _commentsVisible
                      ? () => setState(() => _commentsVisible = false)
                      : _loadComments,
                  child: const Icon(CupertinoIcons.chat_bubble_2),
                ),
              ]),
            ]),
          ),

          // ▶ Yorumlar (animasyonlu açılır/kapanır)
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: _commentsVisible
                ? Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              color: CupertinoColors.systemGrey6,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_loadingComments)
                      const Center(
                          child: CupertinoActivityIndicator())
                    else ...[
                      // İlk X yorumu göster
                      for (var c in _comments.take(_commentsToShow))
                        Padding(
                          padding:
                          const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  CupertinoIcons.person_solid,
                                  size: 16,
                                  color: CupertinoColors.inactiveGray,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Text(c.author,
                                            style: const TextStyle(
                                                fontWeight:
                                                FontWeight.bold)),
                                        const SizedBox(height: 2),
                                        Text(c.comment),
                                        const SizedBox(height: 2),
                                        Text(c.createdAt,
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: CupertinoColors
                                                    .inactiveGray)),
                                      ]),
                                ),
                                CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: () =>
                                      _reportComment(c.id),
                                  child: const Icon(
                                    CupertinoIcons
                                        .exclamationmark_bubble,
                                    size: 20,
                                  ),
                                ),
                              ]),
                        ),

                      // “Daha fazla” / “Yorumları daralt” butonu
                      if (_comments.length > 5)
                        Center(
                          child: CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: _toggleCommentCount,
                            child: Text(
                              _commentsToShow < _comments.length
                                  ? 'Daha fazla yorum yükle'
                                  : 'Yorumları daralt',
                              style: const TextStyle(
                                  color: CupertinoColors.activeBlue),
                            ),
                          ),
                        ),

                      const Divider(),

                      // Yorum ekleme alanı
                      Row(children: [
                        Expanded(
                          child: CupertinoTextField(
                              controller: _commentCtrl,
                              placeholder: 'Yorum yazın…'),
                        ),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed:
                          _posting ? null : _addComment,
                          child: _posting
                              ? const CupertinoActivityIndicator()
                              : const Icon(
                              CupertinoIcons
                                  .arrow_up_circle_fill,
                              size: 24),
                        ),
                      ]),
                    ],
                  ]),
            )
                : const SizedBox.shrink(),
          ),
        ],
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
