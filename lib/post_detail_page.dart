// lib/post_detail_page.dart

import 'dart:math'; // min()
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'home_page.dart'; // Post ve Comment modelleri burada tanımlı

class PostDetailPage extends StatefulWidget {
  final Post post;
  const PostDetailPage({required this.post, super.key});

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  late Post p;
  bool _busy = false;

  List<Comment> _allComments = [];
  bool _loadingComments = true;

  // AnimatedList anahtarı ve gösterilen yorumlar
  final GlobalKey<AnimatedListState> _listKey = GlobalKey();
  final List<Comment> _visibleComments = [];

  int _loadedCount = 0; // şimdiye kadar eklenen yorum sayısı

  // Yorum ekleme
  final TextEditingController _commentCtrl = TextEditingController();
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    p = widget.post;
    _fetchComments();
  }

  Future<void> _fetchComments() async {
    setState(() {
      _loadingComments = true;
      _allComments.clear();
      _visibleComments.clear();
      _loadedCount = 0;
    });

    final res = await http.get(
      Uri.parse('https://erkayasoft.com/api/get_comments.php?postId=${p.id}'),
    );
    if (res.statusCode == 200) {
      final b = json.decode(res.body);
      if (b['success'] == true) {
        // 1) Ham JSON’dan Comment listesi oluştur
        final List<Comment> fetched = (b['data'] as List)
            .map((j) => Comment.fromJson(j as Map<String, dynamic>))
            .toList();

        // 2) Tarihe göre en yeniler en başta olacak şekilde sırala
        fetched.sort((a, b) =>
            DateTime.parse(b.createdAt)
                .compareTo(DateTime.parse(a.createdAt)));

        // 3) Sıralanmış listeyi _allComments’e ekle
        _allComments.addAll(fetched);
      }
    }

    setState(() => _loadingComments = false);
    _loadMoreComments();
  }


  void _loadMoreComments() {
    // 5'er 5'er ekle
    final nextCount = min(_allComments.length, _loadedCount + 5);
    for (int i = _loadedCount; i < nextCount; i++) {
      _visibleComments.add(_allComments[i]);
      _listKey.currentState?.insertItem(i);
    }
    _loadedCount = nextCount;
    setState(() {});
  }

  void _toggleHideComments() {
    // tümünü gösterdiysen gizle, değilse baştan 5 yükle
    if (_loadedCount >= _allComments.length) {
      // gizle → AnimatedList'ten hepsini çıkar
      for (int i = _visibleComments.length - 1; i >= 0; i--) {
        final removed = _visibleComments.removeAt(i);
        _listKey.currentState?.removeItem(
          i,
              (ctx, anim) => SizeTransition(
            sizeFactor: anim,
            child: _buildCommentRow(removed),
          ),
          duration: const Duration(milliseconds: 200),
        );
      }
      _loadedCount = 0;
      // sonra tekrar 5 yükle
      _loadMoreComments();
    }
  }

  Future<void> _react(String reaction) async {
    if (_busy) return;
    setState(() => _busy = true);

    // 1) İsteği sunucuya gönder
    final uid = (await SharedPreferences.getInstance()).getInt('userId') ?? 0;
    final res = await http.post(
      Uri.parse('https://erkayasoft.com/api/react.php'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'userId': uid,
        'postId' : p.id,
        'reaction': reaction,
      }),
    );

    // 2) Başarılıysa yanıtı işle ve UI’ı güncelle
    if (res.statusCode == 200 && res.body.trim().startsWith('{')) {
      final b = json.decode(res.body);
      if (b['success'] == true) {
        setState(() {
          // Sunucudan gelen kesin değerleri atıyoruz
          p.likes       = b['likes']    as int;
          p.dislikes    = b['dislikes'] as int;
          p.userReaction = (b['action'] == 'removed')
              ? 'none'
              : (b['reaction'] as String);
        });
      }
    } else {
      // Opsiyonel: hata durumunu kullanıcıya bildirin
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reaksiyon kaydedilemedi.'))
      );
    }

    setState(() => _busy = false);
  }


  Future<void> _addComment() async {
    final txt = _commentCtrl.text.trim();
    if (txt.isEmpty) return;
    setState(() => _posting = true);

    final uid = (await SharedPreferences.getInstance()).getInt('userId');
    final res = await http.post(
      Uri.parse('https://erkayasoft.com/api/add_comment.php'),
      headers: {'Content-Type':'application/json'},
      body: json.encode({
        'postId': p.id,
        'userId': uid,
        'comment': txt,
      }),
    );
    if (res.body.trim().startsWith('{')) {
      final b = json.decode(res.body);
      if (b['success'] == true) {
        _commentCtrl.clear();
        await _fetchComments();
      }
    }
    setState(() => _posting = false);
  }

  void _showReportOptions(Comment c) {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: const Text('Yorumu bildir'),
        message: const Text('Bu yorumu neden bildiriyorsunuz?'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: rapor işlemi
            },
            isDestructiveAction: true,
            child: const Text('Uygunsuz içerik'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: başka bir sebep
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

  Widget _buildCommentRow(Comment c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(CupertinoIcons.person_solid, size: 18),
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
            onPressed: () => _showReportOptions(c),
            child: const Icon(CupertinoIcons.exclamationmark_circle, size: 20),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allLoaded = _loadedCount >= _allComments.length;
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          p.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Görsel
                  if (p.imageUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        p.imageUrl,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_,__,___) =>
                            Container(height:200, color: CupertinoColors.systemGrey5),
                      ),
                    ),
                  const SizedBox(height:12),
                  // Başlık & tarih
                  Text(p.title,
                      style: const TextStyle(fontSize:22,fontWeight:FontWeight.bold)),
                  const SizedBox(height:4),
                  Text(p.createdAt,
                      style: const TextStyle(fontSize:13, color:CupertinoColors.inactiveGray)),
                  const SizedBox(height:16),
                  // İçerik
                  Text(p.content, style: const TextStyle(fontSize:16)),
                  const SizedBox(height:24),
                  // Reaksiyonlar
                  Row(children:[
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: ()=>_react('like'),
                      child: Row(children:[
                        Icon(CupertinoIcons.hand_thumbsup_fill,
                            color:p.userReaction=='like'
                                ?CupertinoColors.activeBlue
                                :CupertinoColors.inactiveGray),
                        const SizedBox(width:4),
                        Text('${p.likes}')
                      ]),
                    ),
                    const SizedBox(width:24),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: ()=>_react('dislike'),
                      child: Row(children:[
                        Icon(CupertinoIcons.hand_thumbsdown_fill,
                            color:p.userReaction=='dislike'
                                ?CupertinoColors.destructiveRed
                                :CupertinoColors.inactiveGray),
                        const SizedBox(width:4),
                        Text('${p.dislikes}')
                      ]),
                    ),
                  ]),
                  const Divider(height:32),

                  const Text('Yorumlar',
                      style: TextStyle(fontSize:18,fontWeight:FontWeight.w600)),
                  const SizedBox(height:12),

                  if (_loadingComments)
                    const Center(child: CupertinoActivityIndicator()),

                  if (!_loadingComments)
                    AnimatedList(
                      key: _listKey,
                      initialItemCount: _visibleComments.length,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemBuilder: (ctx,index,anim)=>
                          SizeTransition(
                            sizeFactor: anim,
                            child: _buildCommentRow(_visibleComments[index]),
                          ),
                    ),

                  if (!_loadingComments && _allComments.isNotEmpty)
                    Center(
                      child: CupertinoButton(
                        onPressed: allLoaded
                            ? _toggleHideComments
                            : _loadMoreComments,
                        child: Text(
                          allLoaded
                              ? 'Yorumları gizle'
                              : 'Daha fazla yorum yükle',
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const Divider(height:1),
            // Yorum girişi
            Padding(
              padding: const EdgeInsets.symmetric(horizontal:12, vertical:8),
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoTextField(
                      controller: _commentCtrl,
                      placeholder: 'Yorumunuzu yazın…',
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _posting ? null : _addComment,
                    child: _posting
                        ? const CupertinoActivityIndicator()
                        : const Icon(CupertinoIcons.arrow_up_circle_fill, size:28),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
