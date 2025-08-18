import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'; // sadece shadow vb.
import 'services/business_api.dart';
import 'business_detail_page.dart';

class BusinessesPage extends StatefulWidget {
  const BusinessesPage({super.key});
  @override
  State<BusinessesPage> createState() => _BusinessesPageState();
}

class _BusinessesPageState extends State<BusinessesPage> {
  // Genel durum
  bool _loadingCats = true, _loadingList = true;
  final _searchCtrl = TextEditingController();
  final _scroll = ScrollController();
  Timer? _deb;

  // Veriler
  List<BusinessCategory> _cats = [];
  List<Business> _items = [];

  // Filtre / görünüm
  int? _selectedCatId; // Liste modunda kullanılır
  String _q = '';
  String _sort = 'new'; // new | name
  int _page = 1;
  bool _hasMore = true;

  // Görünüm modu: 'sections' (kategorilere göre) | 'list'
  String _view = 'sections';

  @override
  void initState() {
    super.initState();
    _init();
    _scroll.addListener(() {
      if (_view == 'list' &&
          _hasMore &&
          !_loadingList &&
          _scroll.position.pixels > _scroll.position.maxScrollExtent - 280) {
        _loadMore();
      }
    });
  }

  Future<void> _init() async {
    try {
      setState(() => _loadingCats = true);
      _cats = await BusinessApi.fetchCategories();
    } catch (e) {
      // debugPrint('init cats error: $e');
      _cats = [];
    } finally {
      if (mounted) setState(() => _loadingCats = false);
    }
    // Listeyi de hazırla (kategori görünümü açık olsa bile)
    await _loadFirst();
  }


  Future<void> _loadFirst() async {
    setState(() { _loadingList = true; _page = 1; _hasMore = true; _items.clear(); });
    final res = await BusinessApi.fetchBusinesses(
      q: _q, categoryId: _selectedCatId, page: _page, sort: _sort,
    );
    setState(() {
      _items = res.items;
      _hasMore = res.nextPage != null;
      _loadingList = false;
    });
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loadingList) return;
    setState(() => _loadingList = true);
    final res = await BusinessApi.fetchBusinesses(
      q: _q, categoryId: _selectedCatId, page: _page + 1, sort: _sort,
    );
    setState(() {
      _page += 1;
      _items.addAll(res.items);
      _hasMore = res.nextPage != null;
      _loadingList = false;
    });
  }

  Future<void> _onRefresh() async {
    if (_view == 'list') {
      await _loadFirst();
    } else {
      // section widget'ları kendi içinde yenileyecek; sadece küçük bir bekleme
      setState((){}); await Future<void>.delayed(const Duration(milliseconds: 400));
    }
  }

  @override
  void dispose() {
    _deb?.cancel();
    _searchCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('İşletmeler'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            _searchCtrl.clear();
            setState(() { _q = ''; _selectedCatId = null; _sort = 'new'; _view = 'sections'; });
            _loadFirst();
          },
          child: const Icon(CupertinoIcons.refresh),
        ),
      ),
      child: SafeArea(
        bottom: true,
        child: CustomScrollView(
          controller: _scroll,
          slivers: [
            // Pull-to-refresh
            CupertinoSliverRefreshControl(onRefresh: _onRefresh),

            // Arama kutusu
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: CupertinoSearchTextField(
                  controller: _searchCtrl,
                  placeholder: 'İşletme veya anahtar kelime ara',
                  onSubmitted: (v) { _q = v.trim(); _view = 'list'; _loadFirst(); },
                  onChanged: (v) {
                    _deb?.cancel();
                    _deb = Timer(const Duration(milliseconds: 300), () {
                      _q = v.trim();
                      _view = 'list';
                      _loadFirst();
                    });
                  },
                ),
              ),
            ),

            // Görünüm anahtarı
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                child: Row(
                  children: [
                    const Text('Görünüm:', style: TextStyle(color: CupertinoColors.inactiveGray)),
                    const SizedBox(width: 8),
                    _ViewPill(current: _view, value: 'sections', label: 'Kategoriler', onTap: () { setState(() => _view = 'sections'); }),
                    const SizedBox(width: 6),
                    _ViewPill(current: _view, value: 'list', label: 'Liste', onTap: () { setState(() => _view = 'list'); }),
                    const Spacer(),
                    if (_view == 'list')
                      Text('${_items.length}${_hasMore ? "+" : ""}',
                          style: const TextStyle(fontSize: 12, color: CupertinoColors.inactiveGray)),
                  ],
                ),
              ),
            ),

            // ——— KATEGORİLER GÖRÜNÜMÜ ———
            if (_view == 'sections')
              ..._buildCategorySections()

            // ——— LİSTE GÖRÜNÜMÜ ———
            else ...[
              // Sıralama + kategori seçiciler (liste modunda)
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    SizedBox(
                      height: 46,
                      child: _loadingCats
                          ? const Center(child: CupertinoActivityIndicator())
                          : ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        children: [
                          _CategoryChip(
                            label: 'Tümü',
                            selected: _selectedCatId == null,
                            onTap: () { setState(() => _selectedCatId = null); _loadFirst(); },
                          ),
                          for (final c in _cats)
                            _CategoryChip(
                              label: c.name,
                              selected: _selectedCatId == c.id,
                              onTap: () { setState(() => _selectedCatId = c.id); _loadFirst(); },
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                      child: Row(
                        children: [
                          const Text('Sırala:', style: TextStyle(color: CupertinoColors.inactiveGray)),
                          const SizedBox(width: 8),
                          _SortPill(current: _sort, value: 'new',  label: 'En yeni', onTap: () { setState(() => _sort = 'new');  _loadFirst(); }),
                          const SizedBox(width: 6),
                          _SortPill(current: _sort, value: 'name', label: 'İsim',    onTap: () { setState(() => _sort = 'name'); _loadFirst(); }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              if (_loadingList && _items.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CupertinoActivityIndicator()),
                )
              else if (_items.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text('Sonuç bulunamadı')),
                )
              else
                SliverList.builder(
                  itemCount: _items.length,
                  itemBuilder: (context, i) {
                    final b = _items[i];
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                        child:_BusinessCard(
                               b: b,
                               onTap: () async {
                         await Navigator.of(context).push(
                           CupertinoPageRoute(builder: (_) => BusinessDetailPage(businessId: b.id)),
                         );
                         setState(() {}); // detail’den dönüşte tazele
                       },
                         ),
                    );
                  },
                ),

              if (_hasMore)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CupertinoActivityIndicator()),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCategorySections() {
    if (_loadingCats) {
      return const [SliverFillRemaining(hasScrollBody: false, child: Center(child: CupertinoActivityIndicator()))];
    }
    if (_cats.isEmpty) {
      return const [SliverFillRemaining(hasScrollBody: false, child: Center(child: Text('Kategori yok')))];
    }
    // Her kategori için bir bölüm
    return [
      for (final cat in _cats)
        SliverToBoxAdapter(
          child: _CategorySection(
            category: cat,
            onSeeAll: () {
              setState(() { _view = 'list'; _selectedCatId = cat.id; _q = ''; _sort = 'new'; });
              _loadFirst();
            },
          ),
        ),
      const SliverToBoxAdapter(child: SizedBox(height: 24)),
    ];
  }
}

/* ————— Yardımcı küçük UI parçaları ————— */

class _ViewPill extends StatelessWidget {
  final String current, value, label;
  final VoidCallback onTap;
  const _ViewPill({required this.current, required this.value, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final sel = current == value;
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      minSize: 28,
      color: sel ? CupertinoColors.activeBlue : CupertinoColors.systemGrey5,
      onPressed: onTap,
      child: Text(label, style: TextStyle(color: sel ? CupertinoColors.white : CupertinoColors.label, fontSize: 13)),
    );
  }
}

class _SortPill extends StatelessWidget {
  final String current, value, label;
  final VoidCallback onTap;
  const _SortPill({required this.current, required this.value, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final sel = current == value;
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      minSize: 30,
      color: sel ? CupertinoColors.activeBlue : CupertinoColors.systemGrey5,
      onPressed: onTap,
      child: Text(label, style: TextStyle(color: sel ? CupertinoColors.white : CupertinoColors.label, fontSize: 13)),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label; final bool selected; final VoidCallback onTap;
  const _CategoryChip({required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minSize: 30,
        color: selected ? CupertinoColors.activeBlue : CupertinoColors.systemGrey5,
        onPressed: onTap,
        child: Text(label, style: TextStyle(color: selected ? CupertinoColors.white : CupertinoColors.label, fontSize: 13)),
      ),
    );
  }
}

class _BusinessCard extends StatelessWidget {
  final Business b;
  final VoidCallback onTap;
  const _BusinessCard({required this.b, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (b.coverUrl.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Image.network(b.coverUrl, height: 160, width: double.infinity, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(height: 160, color: CupertinoColors.systemGrey5),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(b.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: CupertinoColors.systemGrey6, borderRadius: BorderRadius.circular(8)),
                      child: Text(b.categoryName, style: const TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 8),

                  ]),
                  const SizedBox(height: 4),
                  Text(b.address, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: CupertinoColors.inactiveGray)),
                ]),
              ),

            ]),
          ),
        ]),
      ),
    );
  }
}

/* ————— Kategori bölümü: başlık + yatay liste ————— */

class _CategorySection extends StatefulWidget {
  final BusinessCategory category;
  final VoidCallback onSeeAll;
  const _CategorySection({required this.category, required this.onSeeAll});

  @override
  State<_CategorySection> createState() => _CategorySectionState();
}

class _CategorySectionState extends State<_CategorySection> {
  bool _loading = true;
  List<Business> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await BusinessApi.fetchBusinesses(
      categoryId: widget.category.id, page: 1, pageSize: 10, sort: 'name',
    );
    setState(() { _items = res.items; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
          child: Row(
            children: [
              Expanded(child: Text(widget.category.name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                onPressed: widget.onSeeAll,
                child: const Text('Tümünü gör'),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 180,
          child: _loading
              ? const Center(child: CupertinoActivityIndicator())
              : _items.isEmpty
              ? const Center(child: Text('Kayıt yok'))
              : ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) => _SmallBizTile(b: _items[i]),
          ),
        ),
      ]),
    );
  }
}

class _SmallBizTile extends StatelessWidget {
  final Business b;
  const _SmallBizTile({required this.b});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () {
          Navigator.of(context).push(
            CupertinoPageRoute(builder: (_) => BusinessDetailPage(businessId: b.id)),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: CupertinoColors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: b.coverUrl.isEmpty
                  ? Container(height: 110, color: CupertinoColors.systemGrey5)
                  : Image.network(b.coverUrl, height: 110, width: 220, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(height: 110, color: CupertinoColors.systemGrey5)),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(b.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(b.address, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: CupertinoColors.inactiveGray)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
