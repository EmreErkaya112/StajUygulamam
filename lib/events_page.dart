// lib/events_page.dart
// Yağmurlu Derneği — Etkinlikler (Takvim + Liste)
// Yazar: sizinle çalışan asistan :)

import 'dart:async';
import 'dart:collection';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, BoxShadow, Divider; // sadece shadow renkleri
import 'package:http/http.dart' as http;
import 'dart:convert';

/// =========================
/// ========== API ==========
/// =========================

class EventCategory {
  final int id;
  final String name;
  final bool isActive;
  final int sortOrder;

  EventCategory({
    required this.id,
    required this.name,
    required this.isActive,
    required this.sortOrder,
  });

  factory EventCategory.fromJson(Map<String, dynamic> j) => EventCategory(
    id: (j['id'] ?? 0) is int ? j['id'] : int.tryParse('${j['id']}') ?? 0,
    name: (j['name'] ?? '').toString(),
    isActive: (j['is_active'] == 1 || j['is_active'] == true),
    sortOrder: (j['sort_order'] ?? 0) is int
        ? j['sort_order']
        : int.tryParse('${j['sort_order']}') ?? 0,
  );
}

class EventItem {
  final int id;
  final int categoryId;
  final String categoryName;
  final String title;
  final String description;
  final String address;
  final DateTime startAt;
  final DateTime? endAt;
  final bool allDay;
  final bool isActive;

  EventItem({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.title,
    required this.description,
    required this.address,
    required this.startAt,
    required this.endAt,
    required this.allDay,
    required this.isActive,
  });

  factory EventItem.fromJson(Map<String, dynamic> j) {
    DateTime parseDT(dynamic v) {
      if (v == null || (v is String && v.trim().isEmpty)) {
        return DateTime.now();
      }
      // Sunucudan "YYYY-MM-DD HH:MM:SS" (tz'siz) gelir => yerel kabul edilir.
      return DateTime.parse(v.toString());
    }

    DateTime? parseDTNullable(dynamic v) {
      if (v == null || (v is String && v.trim().isEmpty)) return null;
      return DateTime.parse(v.toString());
    }

    return EventItem(
      id: (j['id'] ?? 0) is int ? j['id'] : int.tryParse('${j['id']}') ?? 0,
      categoryId: (j['category_id'] ?? 0) is int
          ? j['category_id']
          : int.tryParse('${j['category_id']}') ?? 0,
      categoryName: (j['category_name'] ?? '').toString(),
      title: (j['title'] ?? '').toString(),
      description: (j['description'] ?? '').toString(),
      address: (j['address'] ?? '').toString(),
      startAt: parseDT(j['start_at']),
      endAt: parseDTNullable(j['end_at']),
      allDay: (j['all_day'] == 1 || j['all_day'] == true),
      isActive: (j['is_active'] == 1 || j['is_active'] == true),
    );
  }
}

class EventsApi {
  static const String _base = 'https://erkayasoft.com/api';

  static Future<List<EventCategory>> fetchCategories({
    bool includeInactive = false,
  }) async {
    final uri = Uri.parse(
        '$_base/get_event_categories.php${includeInactive ? '?include_inactive=1' : ''}');
    final r = await http.get(uri);
    if (r.statusCode != 200) return [];
    final b = json.decode(r.body);
    if (b is! Map || b['success'] != true) return [];
    final List list = b['data'] ?? [];
    return list.map((e) => EventCategory.fromJson(e)).toList();
  }

  /// Etkinlikleri getirir. Tarih aralığı girersen `upcoming` otomatik kapatılır.
  static Future<List<EventItem>> fetchEvents({
    String q = '',
    int? categoryId,
    DateTime? dateFrom,
    DateTime? dateTo,
    bool upcoming = true, // sadece geleceği al
    int page = 1,
    int pageSize = 200,
    String sort = 'start_asc',
    int? status, // 1/0
  }) async {
    final params = <String, String>{};
    if (q.isNotEmpty) params['q'] = q;
    if (categoryId != null) params['categoryId'] = '$categoryId';
    if (dateFrom != null) params['dateFrom'] = _fmtYMD(dateFrom);
    if (dateTo != null) params['dateTo'] = _fmtYMD(dateTo);
    if (dateFrom == null && dateTo == null) {
      params['upcoming'] = upcoming ? '1' : '0';
    } else {
      params['upcoming'] = '0';
    }
    params['page'] = '$page';
    params['pageSize'] = '$pageSize';
    params['sort'] = sort;
    if (status != null) params['status'] = '$status';

    final uri = Uri.parse('$_base/get_events.php').replace(queryParameters: params);
    final r = await http.get(uri);
    if (r.statusCode != 200) return [];
    final b = json.decode(r.body);
    if (b is! Map || b['success'] != true) return [];
    final List list = b['data'] ?? [];
    return list.map((e) => EventItem.fromJson(e)).toList();
  }

  static String _fmtYMD(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// =============================
/// ======= ETKİNLİK SAYFASI ====
/// =============================

class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  // Veri
  List<EventCategory> _cats = [];
  List<EventItem> _monthEvents = []; // seçili ay için
  List<EventItem> _listEvents = []; // liste görünümü için

  // UI / durum
  bool _loadingCats = true;
  bool _loadingMonth = true;
  bool _loadingList = false;
  bool _includePast = false; // Gelecek mi / Tümü mü
  String _view = 'calendar'; // 'calendar' | 'list'
  final _searchCtrl = TextEditingController();
  Timer? _deb;

  int? _selectedCatId;
  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    await _loadCategories();
    await _loadMonthEvents();
  }

  Future<void> _loadCategories() async {
    setState(() => _loadingCats = true);
    try {
      _cats = await EventsApi.fetchCategories(includeInactive: false);
    } finally {
      if (mounted) setState(() => _loadingCats = false);
    }
  }

  Future<void> _loadMonthEvents() async {
    setState(() {
      _loadingMonth = true;
    });
    final start = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final end = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    try {
      _monthEvents = await EventsApi.fetchEvents(
        q: _searchCtrl.text.trim(),
        categoryId: _selectedCatId,
        dateFrom: start,
        dateTo: end,
        upcoming: false, // tarih aralığı verince backend zaten upcoming'ı yok sayıyoruz
        sort: 'start_asc',
        status: 1,
      );
      _monthEvents.sort((a, b) => a.startAt.compareTo(b.startAt));
    } finally {
      if (mounted) setState(() => _loadingMonth = false);
    }
  }

  Future<void> _loadListEvents() async {
    setState(() => _loadingList = true);
    try {
      // Liste görünümünde default: sadece gelecek; "Tümü" seçilirse geniş aralık
      DateTime? df;
      DateTime? dt;
      bool upcoming = !_includePast;
      if (_includePast) {
        df = DateTime.now().subtract(const Duration(days: 180));
        dt = DateTime.now().add(const Duration(days: 365));
      }
      _listEvents = await EventsApi.fetchEvents(
        q: _searchCtrl.text.trim(),
        categoryId: _selectedCatId,
        dateFrom: df,
        dateTo: dt,
        upcoming: upcoming,
        sort: 'start_asc',
        status: 1,
      );
      _listEvents.sort((a, b) => a.startAt.compareTo(b.startAt));
    } finally {
      if (mounted) setState(() => _loadingList = false);
    }
  }

  @override
  void dispose() {
    _deb?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    if (_view == 'calendar') {
      await _loadMonthEvents();
    } else {
      await _loadListEvents();
    }
  }

  void _prevMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
      _selectedDay = null;
    });
    _loadMonthEvents();
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
      _selectedDay = null;
    });
    _loadMonthEvents();
  }

  void _goToday() {
    setState(() {
      _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
      _selectedDay = DateTime.now();
    });
    _loadMonthEvents();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Etkinlikler'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _onRefresh,
          child: const Icon(CupertinoIcons.refresh),
        ),
      ),
      child: SafeArea(
        bottom: true,
        child: CustomScrollView(
          slivers: [
            CupertinoSliverRefreshControl(onRefresh: _onRefresh),

            // Arama
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: CupertinoSearchTextField(
                  controller: _searchCtrl,
                  placeholder: 'Başlık, adres, açıklama ara…',
                  onSubmitted: (_) => _view == 'calendar' ? _loadMonthEvents() : _loadListEvents(),
                  onChanged: (v) {
                    _deb?.cancel();
                    _deb = Timer(const Duration(milliseconds: 300), () {
                      _view == 'calendar' ? _loadMonthEvents() : _loadListEvents();
                    });
                  },
                ),
              ),
            ),

            // Görünüm & Geçmiş/Gelecek & Kategori şerit
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                child: Row(
                  children: [
                    _ViewToggle(
                      current: _view,
                      onChange: (v) async {
                        setState(() => _view = v);
                        if (v == 'list') {
                          await _loadListEvents();
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    _PastToggle(
                      includePast: _includePast,
                      onChange: (val) async {
                        setState(() => _includePast = val);
                        if (_view == 'list') {
                          await _loadListEvents();
                        } else {
                          // takvimde sadece filtreyi etkiliyor; seçili ay zaten yüklü
                          await _loadMonthEvents();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 46,
                child: _loadingCats
                    ? const Center(child: CupertinoActivityIndicator())
                    : ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    _CatChip(
                      label: 'Tümü',
                      selected: _selectedCatId == null,
                      onTap: () {
                        setState(() => _selectedCatId = null);
                        _view == 'calendar' ? _loadMonthEvents() : _loadListEvents();
                      },
                    ),
                    for (final c in _cats)
                      _CatChip(
                        label: c.name,
                        selected: _selectedCatId == c.id,
                        onTap: () {
                          setState(() => _selectedCatId = c.id);
                          _view == 'calendar' ? _loadMonthEvents() : _loadListEvents();
                        },
                      ),
                  ],
                ),
              ),
            ),

            // Takvim görünümü
            if (_view == 'calendar') ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                  child: _MonthHeader(
                    month: _currentMonth,
                    onPrev: _prevMonth,
                    onNext: _nextMonth,
                    onToday: _goToday,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                  child: _CalendarGrid(
                    month: _currentMonth,
                    events: _monthEvents,
                    includePast: _includePast,
                    selected: _selectedDay,
                    onSelectDay: (d) => setState(() => _selectedDay = d),
                  ),
                ),
              ),
              // Gün/ay listesi
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    _selectedDay == null
                        ? 'Bu ayın etkinlikleri'
                        : 'Seçili gün: ${_fmtLongDate(_selectedDay!)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              if (_loadingMonth)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CupertinoActivityIndicator()),
                )
              else
                SliverList.list(
                  children: _buildEventTiles(
                    (_selectedDay == null)
                        ? _monthEvents
                        : _monthEvents
                        .where((e) => _sameYMD(e.startAt, _selectedDay!))
                        .toList(),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ]
            // Liste görünümü
            else ...[
              if (_loadingList)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CupertinoActivityIndicator()),
                )
              else if (_listEvents.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text('Kayıt bulunamadı')),
                )
              else ..._buildGroupedList(_listEvents),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ],
        ),
      ),
    );
  }

  // Günlere göre gruplu liste (Liste görünümü için)
  List<Widget> _buildGroupedList(List<EventItem> items) {
    final map = SplayTreeMap<String, List<EventItem>>();
    for (final e in items) {
      final k = '${e.startAt.year}-${e.startAt.month}-${e.startAt.day}';
      (map[k] ??= []).add(e);
    }
    final widgets = <Widget>[];
    map.forEach((k, list) {
      list.sort((a, b) => a.startAt.compareTo(b.startAt));
      final d = list.first.startAt;
      widgets.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Text(
              _fmtLongDate(d),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      );
      widgets.add(
        SliverList.builder(
          itemCount: list.length,
          itemBuilder: (_, i) => Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: _EventCard(e: list[i]),
          ),
        ),
      );
    });
    return widgets;
  }

  // Ay/gün listesi (Takvim görünümü için)
  List<Widget> _buildEventTiles(List<EventItem> items) {
    if (items.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text('Bu tarih için etkinlik yok',
              style:
              TextStyle(color: CupertinoColors.inactiveGray, fontSize: 14)),
        )
      ];
    }
    return [
      for (final e in items)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          child: _EventCard(e: e),
        ),
    ];
  }
}

/// =============================
/// ======== KÜÇÜK WIDGETS ======
/// =============================

class _ViewToggle extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChange;
  const _ViewToggle({required this.current, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return CupertinoSlidingSegmentedControl<String>(
      groupValue: current,
      children: const {
        'calendar': Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Text('Takvim'),
        ),
        'list': Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Text('Liste'),
        ),
      },
      onValueChanged: (v) {
        if (v != null) onChange(v);
      },
    );
  }
}

class _PastToggle extends StatelessWidget {
  final bool includePast;
  final ValueChanged<bool> onChange;
  const _PastToggle({required this.includePast, required this.onChange});
  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      color: includePast
          ? CupertinoColors.activeBlue
          : CupertinoColors.systemGrey5,
      minSize: 30,
      onPressed: () => onChange(!includePast),
      child: Text(
        includePast ? 'Tümü' : 'Gelecek',
        style: TextStyle(
          color:
          includePast ? CupertinoColors.white : CupertinoColors.label,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _CatChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CatChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minSize: 30,
        color:
        selected ? CupertinoColors.activeBlue : CupertinoColors.systemGrey5,
        onPressed: onTap,
        child: Text(
          label,
          style: TextStyle(
              color:
              selected ? CupertinoColors.white : CupertinoColors.label,
              fontSize: 13),
        ),
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  final DateTime month;
  final VoidCallback onPrev, onNext, onToday;
  const _MonthHeader({
    required this.month,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
  });

  @override
  Widget build(BuildContext context) {
    final lbl =
        '${_monthNameTR(month.month)} ${month.year}';
    return Row(
      children: [
        CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          onPressed: onPrev,
          child: const Icon(CupertinoIcons.chevron_left),
        ),
        Expanded(
          child: Center(
            child: Text(lbl,
                style:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ),
        ),
        CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          onPressed: onNext,
          child: const Icon(CupertinoIcons.chevron_right),
        ),
        CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          color: CupertinoColors.systemGrey5,
          onPressed: onToday,
          child: const Text('Bugün'),
        ),
      ],
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  final DateTime month;
  final List<EventItem> events;
  final bool includePast;
  final DateTime? selected;
  final ValueChanged<DateTime> onSelectDay;

  const _CalendarGrid({
    required this.month,
    required this.events,
    required this.includePast,
    required this.selected,
    required this.onSelectDay,
  });

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final last = DateTime(month.year, month.month + 1, 0);
    // Haftanın ilk günü: Pazartesi (1)
    final startOffset = first.weekday - 1; // 0..6
    final totalDays = last.day;
    final totalCells = ((startOffset + totalDays) / 7).ceil() * 7;

    // Gün -> etkinlik sayısı
    final counts = <String, int>{};
    for (final e in events) {
      final k = _keyYMD(e.startAt);
      counts[k] = (counts[k] ?? 0) + 1;
    }

    final weekDays = const ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

    return Column(
      children: [
        // Hafta başlıkları
        Row(
          children: [
            for (final w in weekDays)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(w,
                        style: const TextStyle(
                            fontSize: 12,
                            color: CupertinoColors.inactiveGray,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
          ],
        ),
        // Izgara
        Container(
          decoration: BoxDecoration(
            color: CupertinoColors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
          ),
          child: Column(
            children: [
              for (int row = 0; row < totalCells / 7; row++)
                Row(
                  children: [
                    for (int col = 0; col < 7; col++)
                      _DayCell(
                        index: row * 7 + col,
                        startOffset: startOffset,
                        month: month,
                        counts: counts,
                        selected: selected,
                        includePast: includePast,
                        onTap: onSelectDay,
                      ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  final int index;
  final int startOffset;
  final DateTime month;
  final Map<String, int> counts;
  final DateTime? selected;
  final bool includePast;
  final ValueChanged<DateTime> onTap;

  const _DayCell({
    required this.index,
    required this.startOffset,
    required this.month,
    required this.counts,
    required this.selected,
    required this.includePast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dayNum = index - startOffset + 1;
    final inMonth = dayNum >= 1 && dayNum <= DateTime(month.year, month.month + 1, 0).day;
    DateTime? day;
    if (inMonth) {
      day = DateTime(month.year, month.month, dayNum);
    }

    final isToday = inMonth && _sameYMD(day!, DateTime.now());
    final isSelected = inMonth && selected != null && _sameYMD(day!, selected!);
    final key = inMonth ? _keyYMD(day!) : '';
    final count = counts[key] ?? 0;

    final canTap = inMonth && (includePast || !day!.isBefore(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)));

    return Expanded(
      child: GestureDetector(
        onTap: inMonth
            ? () {
          if (canTap) onTap(day!);
        }
            : null,
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            color: isSelected
                ? CupertinoColors.activeBlue
                : CupertinoColors.white,
            border: Border.all(
                color: CupertinoColors.systemGrey5, width: 0.5),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  inMonth ? '$dayNum' : '',
                  style: TextStyle(
                    fontWeight:
                    isToday ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected
                        ? CupertinoColors.white
                        : (inMonth
                        ? CupertinoColors.label
                        : CupertinoColors.inactiveGray),
                  ),
                ),
                if (count > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Container(
                      width: 18,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? CupertinoColors.white
                            : CupertinoColors.activeBlue,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final EventItem e;
  const _EventCard({required this.e});

  @override
  Widget build(BuildContext context) {
    final time = e.allDay ? 'Tüm gün' : _fmtTimeRange(e.startAt, e.endAt);

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () => _openEventModal(context, e),
      child: Container(
        decoration: BoxDecoration(
          color: CupertinoColors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sol şerit (kategori)
              Container(
                width: 4,
                height: 54,
                decoration: BoxDecoration(
                  color: CupertinoColors.activeBlue,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(e.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey6,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(e.categoryName, style: const TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 8),
                    const Icon(CupertinoIcons.time, size: 14, color: CupertinoColors.inactiveGray),
                    const SizedBox(width: 2),
                    Text(time, style: const TextStyle(fontSize: 12, color: CupertinoColors.inactiveGray)),
                  ]),
                  if (e.address.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(CupertinoIcons.location, size: 14, color: CupertinoColors.inactiveGray),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          e.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: CupertinoColors.inactiveGray),
                        ),
                      ),
                    ]),
                  ],
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
void _openEventModal(BuildContext context, EventItem e) {
  showCupertinoModalPopup(
    context: context,
    barrierDismissible: true,
    builder: (_) => _EventDetailSheet(e: e),
  );
}

class _EventDetailSheet extends StatelessWidget {
  final EventItem e;
  const _EventDetailSheet({required this.e});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isAllDay = e.allDay;
    final dateLbl = _fmtLongDate(e.startAt);
    final timeLbl = isAllDay ? 'Tüm gün' : _fmtTimeRange(e.startAt, e.endAt);

    return SafeArea(
      child: Stack(
        children: [
          // arka plan karartma
          GestureDetector(onTap: () => Navigator.pop(context), child: Container(color: Colors.black26)),
          // alttan yuvarlak kart
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              constraints: BoxConstraints(maxHeight: media.size.height * 0.75),
              decoration: BoxDecoration(
                color: CupertinoColors.systemBackground,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 16)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // tutacak
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGrey3,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // başlık + kapat
                  Row(
                    children: [
                      Expanded(
                        child: Text(e.title,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.pop(context),
                        child: const Icon(CupertinoIcons.xmark_circle_fill, color: CupertinoColors.inactiveGray),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // info satırları
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey6,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(e.categoryName, style: const TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 8),
                    const Icon(CupertinoIcons.calendar_today, size: 16, color: CupertinoColors.inactiveGray),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text('$dateLbl • $timeLbl',
                          style: const TextStyle(fontSize: 12, color: CupertinoColors.inactiveGray),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                  if (e.address.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(CupertinoIcons.location, size: 16, color: CupertinoColors.inactiveGray),
                      const SizedBox(width: 6),
                      Expanded(child: Text(e.address)),
                    ]),
                  ],

                  const SizedBox(height: 10),
                  const Divider(height: 1),

                  // açıklama
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(top: 10, bottom: 6),
                      child: Text(
                        (e.description.isEmpty) ? 'Açıklama bulunmuyor.' : e.description,
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                  ),

                  // alt butonlar
                  Row(
                    children: [
                      const Spacer(),
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        color: CupertinoColors.activeBlue,
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Kapat', style: TextStyle(color: CupertinoColors.white)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


/// =============================
/// ========== YARDIMCI =========
/// =============================

bool _sameYMD(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _keyYMD(DateTime d) => '${d.year}-${d.month}-${d.day}';

String _fmtTime(DateTime d) {
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}

String _fmtTimeRange(DateTime s, DateTime? e) {
  if (e == null) return _fmtTime(s);
  return '${_fmtTime(s)}–${_fmtTime(e)}';
}

String _fmtLongDate(DateTime d) {
  final wd = _weekdayTR(d.weekday);
  final m = _monthNameTR(d.month);
  return '$wd, ${d.day} $m ${d.year}';
}

String _weekdayTR(int w) {
  switch (w) {
    case 1:
      return 'Pazartesi';
    case 2:
      return 'Salı';
    case 3:
      return 'Çarşamba';
    case 4:
      return 'Perşembe';
    case 5:
      return 'Cuma';
    case 6:
      return 'Cumartesi';
    case 7:
      return 'Pazar';
    default:
      return '';
  }
}

String _monthNameTR(int m) {
  const names = [
    '',
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık'
  ];
  return names[m];
}
