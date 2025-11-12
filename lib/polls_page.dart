import 'dart:math';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// --------- MODELLER ---------
class Poll {
  final int id;
  final String title;
  final String description;
  final String createdAt; // "YYYY-MM-DD HH:MM:SS"
  final int isActive;     // 1 aktif, 0 pasif
  final int? userVote;    // kullanıcının seçtiği optionId (yoksa null)
  final List<PollOption> options;

  Poll({
    required this.id,
    required this.title,
    required this.description,
    required this.createdAt,
    required this.isActive,
    required this.userVote,
    required this.options,
  });

  factory Poll.fromJson(Map<String, dynamic> j) {
    final rawActive = j['is_active'];
    final isActive = (rawActive is int)
        ? rawActive
        : int.tryParse(rawActive.toString()) ?? 0;

    return Poll(
      id:          j['id'] as int,
      title:       j['title'] as String,
      description: j['description'] as String,
      createdAt:   j['created_at'] as String,
      isActive:    isActive,
      userVote:    j['userVote'] == null ? null : j['userVote'] as int,
      options: (j['options'] as List)
          .map((o) => PollOption.fromJson(o as Map<String, dynamic>))
          .toList(),
    );
  }
}

class PollOption {
  final int id;
  final String label;
  final int voteCount;

  PollOption({
    required this.id,
    required this.label,
    required this.voteCount,
  });

  factory PollOption.fromJson(Map<String, dynamic> j) => PollOption(
    id:        j['id'] as int,
    label:     j['label'] as String,
    voteCount: j['vote_count'] as int,
  );
}

/// --------- SAYFA ---------
class PollsPage extends StatefulWidget {
  const PollsPage({super.key});
  @override
  State<PollsPage> createState() => _PollsPageState();
}

class _PollsPageState extends State<PollsPage> {
  bool _loading = true;
  List<Poll> _polls = [];
  final ScrollController _scrollController = ScrollController();

  static const String _base = 'https://yagmurlukoyu.org/api';

  @override
  void initState() {
    super.initState();
    _loadPolls();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Sunucudan TÜM (aktif+pasif) anketleri çeker.
  Future<void> _loadPolls() async {
    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId') ?? 0;

      // status=all -> pasifler de gelsin, cache kırmak için _ts:
      final uri = Uri.parse(
        '$_base/list_polls.php'
            '?userId=$userId&status=all&page=1&pageSize=200'
            '&_ts=${DateTime.now().millisecondsSinceEpoch}',
      );

      final res = await http.get(uri);
      if (res.statusCode != 200) {
        throw 'HTTP ${res.statusCode}';
      }
      final body = json.decode(res.body);
      if (body['success'] != true) {
        throw body['error'] ?? 'API hatası';
      }

      final data = (body['data'] as List)
          .map((p) => Poll.fromJson(p))
          .toList();

      // SIRALAMA: En yeni en üstte. created_at parse edilemiyorsa id DESC.
      int cmp(Poll a, Poll b) {
        final da = _parseTs(a.createdAt);
        final db = _parseTs(b.createdAt);
        if (da != null && db != null) return db.compareTo(da); // yeni -> önce
        return b.id.compareTo(a.id);
      }
      data.sort(cmp);

      _polls = data;
    } catch (e) {
      debugPrint('Anket yükleme hatası: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// "YYYY-MM-DD HH:MM:SS" -> DateTime (fail-safe)
  DateTime? _parseTs(String s) {
    try {
      // "YYYY-MM-DD HH:MM:SS" -> "YYYY-MM-DDTHH:MM:SS"
      final fixed = s.contains('T') ? s : s.replaceFirst(' ', 'T');
      return DateTime.tryParse(fixed);
    } catch (_) {
      return null;
    }
  }

  Future<void> _vote(Poll poll, PollOption option) async {
    final currentOffset = _scrollController.offset;
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId') ?? 0;

      final res = await http.post(
        Uri.parse('$_base/vote_poll.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'pollId':   poll.id,
          'userId':   userId,
          'optionId': option.id,
        }),
      );

      final body = json.decode(res.body);
      if (body['success'] == true) {
        await _loadPolls();
        // Scroll konumunu koru
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            final max = _scrollController.position.maxScrollExtent;
            _scrollController.jumpTo(min(currentOffset, max));
          }
        });
      } else {
        _showError(body['error'] ?? 'Bilinmeyen hata');
      }
    } catch (e) {
      _showError('Sunucu hatası: $e');
    }
  }

  void _showError(String msg) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Hata'),
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
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Anketler')),
      child: SafeArea(
        child: _loading
            ? const Center(child: CupertinoActivityIndicator())
            : _polls.isEmpty
            ? const Center(child: Text('Henüz anket yok'))
            : ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: _polls.length,
          itemBuilder: (_, i) => _buildPollCard(_polls[i]),
        ),
      ),
    );
  }

  Widget _buildPollCard(Poll poll) {
    final totalVotes =
    poll.options.fold<int>(0, (sum, o) => sum + o.voteCount);

    // KURAL:
    // - Pasif (isActive==0) ise DOĞRUDAN SONUÇ modu.
    // - Aktif ama userVote != null ise sonuç modu.
    // - Aktif ve userVote == null ise oy verme modu.
    final resultsMode = (poll.isActive == 0) || (poll.userVote != null);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                poll.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (poll.isActive == 0)
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey5,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Sonlandı',
                  style: TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.inactiveGray,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(poll.description),
        const SizedBox(height: 12),

        if (!resultsMode) ...[
          // OYLAMA MODU
          for (final o in poll.options)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: CupertinoButton(
                padding:
                const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                color: CupertinoColors.systemGrey6,
                onPressed: () => _vote(poll, o),
                child: Row(children: [
                  const Icon(CupertinoIcons.circle, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Text(o.label)),
                ]),
              ),
            ),
        ] else ...[
          // SONUÇ MODU
          for (final o in poll.options)
            _buildResultRow(
              o,
              o.id == poll.userVote, // kendi seçimi vurgulansın
              totalVotes,
            ),
        ],

        const SizedBox(height: 8),
        Text(
          'Toplam oy: $totalVotes',
          style: const TextStyle(
            fontSize: 12,
            color: CupertinoColors.inactiveGray,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _friendlyDate(poll.createdAt),
          style: const TextStyle(
            fontSize: 11,
            color: CupertinoColors.inactiveGray,
          ),
        ),
      ]),
    );
  }

  Widget _buildResultRow(PollOption o, bool selected, int totalVotes) {
    final pct = totalVotes == 0 ? 0.0 : o.voteCount / totalVotes;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(
            selected
                ? CupertinoIcons.check_mark_circled_solid
                : CupertinoIcons.circle,
            color: selected
                ? CupertinoColors.activeBlue
                : CupertinoColors.inactiveGray,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              o.label,
              style: TextStyle(
                fontWeight: selected ? FontWeight.bold : null,
              ),
            ),
          ),
          Text('${(pct * 100).toStringAsFixed(1)}%'),
        ]),
        const SizedBox(height: 4),
        LayoutBuilder(builder: (ctx, box) {
          return Stack(children: [
            Container(
              width: box.maxWidth,
              height: 6,
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey4,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Container(
              width: box.maxWidth * pct,
              height: 6,
              decoration: BoxDecoration(
                color: CupertinoColors.activeBlue,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ]);
        }),
      ]),
    );
  }

  String _friendlyDate(String raw) {
    final dt = _parseTs(raw);
    if (dt == null) return raw;
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'az önce';
    if (diff.inHours < 1) return '${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return '${diff.inHours} sa önce';
    return '${dt.year}-${_two(dt.month)}-${_two(dt.day)} ${_two(dt.hour)}:${_two(dt.minute)}';
  }

  String _two(int n) => n.toString().padLeft(2, '0');
}
