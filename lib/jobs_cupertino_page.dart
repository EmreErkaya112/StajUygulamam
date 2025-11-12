// jobs_cupertino_page.dart  — white & blue theme
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

/* ------------------------------ PARSERS ------------------------------ */
int _asInt(dynamic v, {int defaultValue = 0}) {
  if (v == null) return defaultValue;
  if (v is num) return v.toInt();
  final s = v.toString().trim();
  return int.tryParse(s) ?? defaultValue;
}

String? _asString(dynamic v) {
  if (v == null) return null;
  final s = v.toString();
  return s.isEmpty ? null : s;
}

/* ------------------------------ PAGE ------------------------------ */
class JobsCupertinoPage extends StatefulWidget {
  const JobsCupertinoPage({super.key});
  @override
  State<JobsCupertinoPage> createState() => _JobsCupertinoPageState();
}

class _JobsCupertinoPageState extends State<JobsCupertinoPage> {
  static const String baseUrl = 'https://yagmurlukoyu.org/api/get_jobs.php';

  final List<JobItem> _items = <JobItem>[];
  final ScrollController _scroll = ScrollController();

  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _hasError = false;
  String? _errorMsg;
  int _page = 1;
  final int _pageSize = 20;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    _fetch(reset: true);
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _fetch({bool reset = false}) async {
    if (_isLoading || _isRefreshing) return;

    if (reset) {
      setState(() {
        _page = 1;
        _totalPages = 1;
        _items.clear();
        _hasError = false;
        _errorMsg = null;
        _isRefreshing = true;
      });
    } else {
      setState(() => _isLoading = true);
    }

    try {
      final uri = Uri.parse(baseUrl).replace(queryParameters: <String, String>{
        'page': '$_page',
        'pageSize': '$_pageSize',
        'order': 'recent', // en son yayınlanan
        // scope=public default: aktif + süresi geçmemiş
      });

      final res = await http.get(uri, headers: const {'Accept': 'application/json'});
      if (res.statusCode != 200) {
        throw Exception('Sunucu yanıtı: ${res.statusCode}');
      }

      final Map<String, dynamic> map = json.decode(res.body) as Map<String, dynamic>;
      if (map['success'] != true) {
        throw Exception(map['error']?.toString() ?? 'Bilinmeyen API hatası');
      }

      _totalPages = _asInt(map['total_pages'], defaultValue: 1);
      final List<Map<String, dynamic>> data =
      (map['data'] as List).cast<Map<String, dynamic>>();

      final List<JobItem> fetched = data
          .map(JobItem.fromJson)
          .where((j) => j.isActive == 1)
          .toList();

      setState(() {
        _items.addAll(fetched);
        _hasError = false;
        _errorMsg = null;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMsg = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  Future<void> _onRefresh() async => _fetch(reset: true);

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 160) {
      if (!_isLoading && _page < _totalPages) {
        _page += 1;
        _fetch();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- White & Blue palette ---
    const bg = Color(0xFFFFFFFF);
    const card = Color(0xFFFFFFFF);
    const cardBorder = Color(0xFFE3F2FD);
    const pillBg = Color(0xFFEAF2FF);
    const textPrimary = Color(0xFF0B2B45); // koyu mavi
    const textMuted = Color(0xFF5E6A7D);   // mavi-gri
    const accent = Color(0xFF1976D2);      // ana mavi
    final canPop = Navigator.of(context).canPop();

    return CupertinoPageScaffold(
      backgroundColor: bg,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: bg,
        border: null,
        middle: const Text('İş İlanları',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: textPrimary)),
          leading: canPop
              ? CupertinoNavigationBarBackButton(
            color: accent,
            onPressed: () => Navigator.maybePop(context),
          ): null,
      ),
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          controller: _scroll,
          slivers: <Widget>[
            CupertinoSliverRefreshControl(onRefresh: _onRefresh),

            SliverToBoxAdapter(child: _buildHeader(textMuted, accent, pillBg)),

            if (_isRefreshing && _items.isEmpty) _buildSkeletonList(card, cardBorder),

            if (!_isRefreshing && _items.isEmpty && !_hasError)
              SliverToBoxAdapter(
                child: const _EmptyState(
                  textColor: textPrimary,
                  mutedColor: textMuted,
                ),
              ),

            if (_hasError && _items.isEmpty)
              SliverToBoxAdapter(
                child: _ErrorState(
                  textColor: textPrimary,
                  mutedColor: textMuted,
                  message: _errorMsg,
                  onRetry: () => _fetch(reset: true),
                ),
              ),

            SliverList.builder(
              itemCount: _items.length,
              itemBuilder: (ctx, i) => _JobCard(
                item: _items[i],
                cardColor: card,
                borderColor: cardBorder,
                textPrimary: textPrimary,
                textMuted: textMuted,
                accent: accent,
                pillBg: pillBg,
              ),
            ),

            SliverToBoxAdapter(child: _buildFooterLoader(textMuted, accent)),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Color textMuted, Color accent, Color pillBg) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Icon(CupertinoIcons.briefcase_fill, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text('En son yayınlanan ve aktif ilanlar',
                style: TextStyle(color: textMuted, fontSize: 14)),
          ),
          const SizedBox(width: 8),
          _SmallPill(
            text: 'Güncel',
            icon: CupertinoIcons.bolt_fill,
            bg: pillBg,
            fg: accent,
          ),
        ],
      ),
    );
  }

  Widget _buildFooterLoader(Color textMuted, Color accent) {
    if (_hasError && _items.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Yüklenirken bir sorun oluştu', style: TextStyle(color: textMuted)),
            const SizedBox(height: 8),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: accent.withOpacity(.12),
              onPressed: () => _fetch(),
              child: Text('Tekrar Dene', style: TextStyle(color: accent)),
            ),
          ],
        ),
      );
    }
    if (_isLoading && _items.isNotEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CupertinoActivityIndicator()),
      );
    }
    if (_page >= _totalPages && _items.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Text('Hepsi bu kadar', style: TextStyle(color: textMuted)),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  SliverList _buildSkeletonList(Color card, Color border) {
    return SliverList.builder(
      itemCount: 6,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Container(
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: const [
              _Skeleton(height: 18, width: 220),
              SizedBox(height: 8),
              _Skeleton(height: 14, width: 140),
              SizedBox(height: 12),
              Row(
                children: [
                  _Skeleton(height: 24, width: 80),
                  SizedBox(width: 8),
                  _Skeleton(height: 24, width: 70),
                  SizedBox(width: 8),
                  _Skeleton(height: 24, width: 60),
                ],
              ),
              SizedBox(height: 12),
              _Skeleton(height: 14, width: double.infinity),
              SizedBox(height: 6),
              _Skeleton(height: 14, width: double.infinity),
              SizedBox(height: 6),
              _Skeleton(height: 14, width: 180),
            ],
          ),
        ),
      ),
    );
  }
}

/* ----------------------------- MODEL ----------------------------- */
class JobItem {
  final int id;
  final String title;
  final String companyName;
  final String city;
  final String? district;
  final String? locationText;
  final String employmentType;
  final String workModel;
  final String? experienceLevel;
  final String? educationLevel;
  final int? salaryMin;
  final int? salaryMax;
  final String? currency;
  final String? tags;
  final String? contactEmail;
  final String? contactPhone;
  final String? applyUrl;
  final String? postedAt;
  final String? expireAt;
  final int isActive;
  final String? shortDescription;

  JobItem({
    required this.id,
    required this.title,
    required this.companyName,
    required this.city,
    this.district,
    this.locationText,
    required this.employmentType,
    required this.workModel,
    this.experienceLevel,
    this.educationLevel,
    this.salaryMin,
    this.salaryMax,
    this.currency,
    this.tags,
    this.contactEmail,
    this.contactPhone,
    this.applyUrl,
    this.postedAt,
    this.expireAt,
    required this.isActive,
    this.shortDescription,
  });

  factory JobItem.fromJson(Map<String, dynamic> j) => JobItem(
    id: _asInt(j['id']),
    title: _asString(j['title']) ?? '',
    companyName: _asString(j['company_name']) ?? '',
    city: _asString(j['city']) ?? '',
    district: _asString(j['district']),
    locationText: _asString(j['location_text']),
    employmentType: _asString(j['employment_type']) ?? 'full_time',
    workModel: _asString(j['work_model']) ?? 'onsite',
    experienceLevel: _asString(j['experience_level']),
    educationLevel: _asString(j['education_level']),
    salaryMin: j['salary_min'] == null ? null : _asInt(j['salary_min']),
    salaryMax: j['salary_max'] == null ? null : _asInt(j['salary_max']),
    currency: _asString(j['currency']),
    tags: _asString(j['tags']),
    contactEmail: _asString(j['contact_email']),
    contactPhone: _asString(j['contact_phone']),
    applyUrl: _asString(j['apply_url']),
    postedAt: _asString(j['posted_at']),
    expireAt: _asString(j['expire_at']),
    isActive: _asInt(j['is_active']),
    shortDescription: _asString(j['short_description']),
  );
}

/* --------------------------- UI BİLEŞENLER --------------------------- */
class _JobCard extends StatelessWidget {
  final JobItem item;
  final Color cardColor;
  final Color borderColor;
  final Color textPrimary;
  final Color textMuted;
  final Color accent;
  final Color pillBg;

  const _JobCard({
    required this.item,
    required this.cardColor,
    required this.borderColor,
    required this.textPrimary,
    required this.textMuted,
    required this.accent,
    required this.pillBg,
  });

  @override
  Widget build(BuildContext context) {
    final cityLine = item.locationText?.isNotEmpty == true
        ? item.locationText!
        : [item.district, item.city].where((e) => (e ?? '').isNotEmpty).join(' / ');
    final money = _formatMoney(item.salaryMin, item.salaryMax, item.currency);
    final when = _formatDate(item.postedAt);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
          boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2))],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(CupertinoIcons.building_2_fill, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.title,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Flexible(
                child: Text(
                  '${item.companyName} • $cityLine',
                  style: TextStyle(color: textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Pill(text: _employmentLabel(item.employmentType), icon: CupertinoIcons.time_solid, bg: pillBg, fg: accent),
              _Pill(text: _workModelLabel(item.workModel), icon: CupertinoIcons.location_solid, bg: pillBg, fg: accent),
              if ((item.experienceLevel ?? '').isNotEmpty)
                _Pill(text: _experienceLabel(item.experienceLevel!), icon: CupertinoIcons.star_fill, bg: pillBg, fg: accent),
            ],
          ),
          const SizedBox(height: 12),
          if ((item.shortDescription ?? '').isNotEmpty)
            Text(item.shortDescription!.trim(),
                maxLines: 4, overflow: TextOverflow.ellipsis, style: TextStyle(color: textPrimary, height: 1.35)),
          if ((item.shortDescription ?? '').isNotEmpty) const SizedBox(height: 12),
          Row(
            children: [
              if (money.isNotEmpty)
                Row(
                  children: [
                    Icon(CupertinoIcons.money_dollar_circle, color: accent, size: 18),
                    const SizedBox(width: 4),
                    Text(money, style: TextStyle(color: textMuted)),
                  ],
                ),
              const Spacer(),
              Text(when, style: TextStyle(color: textMuted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _ActionButton(icon: CupertinoIcons.envelope_fill, label: 'E-posta', onTap: (item.contactEmail ?? '').isEmpty ? null : () => _launch(Uri.parse('mailto:${item.contactEmail}')), primaryColor: accent),
              const SizedBox(width: 8),
              _ActionButton(icon: CupertinoIcons.phone_fill, label: 'Ara', onTap: (item.contactPhone ?? '').isEmpty ? null : () => _launch(Uri.parse('tel:${item.contactPhone}')), primaryColor: accent),
              const SizedBox(width: 8),
              _ActionButton(icon: CupertinoIcons.paperplane_fill, label: 'Başvur', primary: true, onTap: _buildApplyHandler(item), primaryColor: accent),
            ],
          ),
        ]),
      ),
    );
  }

  VoidCallback? _buildApplyHandler(JobItem item) {
    if ((item.applyUrl ?? '').isNotEmpty) {
      final uri = Uri.tryParse(item.applyUrl!.trim());
      if (uri != null) return () => _launch(uri);
    }
    if ((item.contactEmail ?? '').isNotEmpty) return () => _launch(Uri.parse('mailto:${item.contactEmail}'));
    if ((item.contactPhone ?? '').isNotEmpty) return () => _launch(Uri.parse('tel:${item.contactPhone}'));
    return null;
  }

  static String _formatMoney(int? min, int? max, String? cur) {
    if (min == null && max == null) return '';
    final n = NumberFormat.decimalPattern('tr_TR');
    final c = (cur ?? 'TRY').toUpperCase();
    if (min != null && max != null) return '${n.format(min)}–${n.format(max)} $c';
    if (min != null) return '${n.format(min)}+ $c';
    return '${n.format(max!)} $c';
  }

  static String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final fmt = DateFormat('d MMMM y HH:mm', 'tr_TR');
      return fmt.format(dt);
    } catch (_) {
      return iso;
    }
  }

  static String _employmentLabel(String v) {
    switch (v) {
      case 'part_time': return 'Yarı Zamanlı';
      case 'intern': return 'Stajyer';
      case 'contract': return 'Sözleşmeli';
      case 'temporary': return 'Geçici';
      case 'project': return 'Proje Bazlı';
      default: return 'Tam Zamanlı';
    }
  }

  static String _workModelLabel(String v) {
    switch (v) {
      case 'remote': return 'Uzaktan';
      case 'hybrid': return 'Hibrit';
      default: return 'Ofiste';
    }
  }

  static String _experienceLabel(String v) {
    switch (v) {
      case 'junior': return 'Junior';
      case 'mid': return 'Mid';
      case 'senior': return 'Senior';
      case 'lead': return 'Lead';
      case 'manager': return 'Manager';
      case 'director': return 'Director';
      default: return v;
    }
  }
}

/* ------------------------------ WIDGETS ------------------------------ */
class _Pill extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color bg;
  final Color fg;
  const _Pill({required this.text, required this.icon, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFBDD6FF)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: fg),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _SmallPill extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color bg;
  final Color fg;
  const _SmallPill({required this.text, required this.icon, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFBDD6FF)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: fg),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(color: fg, fontSize: 12)),
      ]),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final Color primaryColor;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.primary = false,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final Color bg = primary ? primaryColor : primaryColor.withOpacity(.12);
    final Color fg = primary ? const Color(0xFFFFFFFF) : primaryColor;

    return Expanded(
      child: Opacity(
        opacity: disabled ? 0.5 : 1,
        child: CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          color: bg,
          borderRadius: BorderRadius.circular(12),
          onPressed: disabled ? null : onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  final double height;
  final double width;
  const _Skeleton({required this.height, required this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width == double.infinity ? double.infinity : width,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F8),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final Color textColor;
  final Color mutedColor;
  const _EmptyState({required this.textColor, required this.mutedColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
      child: Column(
        children: [
          Icon(CupertinoIcons.hourglass, color: mutedColor, size: 48),
          const SizedBox(height: 12),
          Text('Şu an gösterilecek ilan bulunamadı.',
              style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Yeni ilanlar yayınlandığında burada görünecek.',
              textAlign: TextAlign.center, style: TextStyle(color: mutedColor)),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String? message;
  final VoidCallback onRetry;
  final Color textColor;
  final Color mutedColor;

  const _ErrorState({
    this.message,
    required this.onRetry,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
      child: Column(
        children: [
          const Icon(CupertinoIcons.exclamationmark_triangle_fill, color: Color(0xFFFF5A52), size: 48),
          const SizedBox(height: 12),
          Text('Bir hata oluştu', style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(message ?? 'Bilinmeyen hata', textAlign: TextAlign.center, style: TextStyle(color: mutedColor)),
          const SizedBox(height: 16),
          CupertinoButton(
            color: const Color(0xFF1976D2),
            onPressed: onRetry,
            child: const Text('Tekrar Dene', style: TextStyle(color: Color(0xFFFFFFFF))),
          ),
        ],
      ),
    );
  }
}

/* ------------------------------ HELPERS ------------------------------ */
Future<void> _launch(Uri uri) async {
  if (!await canLaunchUrl(uri)) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
