import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/business_api.dart';
import 'package:url_launcher/url_launcher.dart';

class BusinessDetailPage extends StatefulWidget {
  final int businessId;
  const BusinessDetailPage({super.key, required this.businessId});

  @override
  State<BusinessDetailPage> createState() => _BusinessDetailPageState();
}

class _BusinessDetailPageState extends State<BusinessDetailPage> {
  BusinessDetail? _detail;
  bool _loading = true;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _detail = await BusinessApi.fetchBusinessDetail(widget.businessId);
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final d = _detail?.data;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(d?.name ?? 'İşletme'),
        // favori butonu kaldırıldı: trailing: null
      ),
      child: _loading
          ? const Center(child: CupertinoActivityIndicator())
          : d == null
          ? const Center(child: Text('Bulunamadı'))
          : SafeArea(
        bottom: true,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Kapak + Galeri
            if (_detail!.images.isNotEmpty || d.coverUrl.isNotEmpty)
              _Gallery(
                images: _detail!.images.isNotEmpty
                    ? _detail!.images
                    : [d.coverUrl],
                onPage: (i) => setState(() => _page = i),
                index: _page,
              ),

            // Başlık & kategori
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(d.name,
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color:
                              CupertinoColors.systemGrey6,
                              borderRadius:
                              BorderRadius.circular(8),
                            ),
                            child: Text(d.categoryName,
                                style:
                                const TextStyle(fontSize: 12)),
                          ),
                        ]),
                  ),
                  // küçük kalp butonu kaldırıldı
                ],
              ),
            ),

            // İletişim Hızlı Aksiyonlar
            const SizedBox(height: 8),
            _ActionsRow(
              phone: d.phone,
              whatsapp: d.whatsapp,
              website: d.website,
              address: d.address,
            ),

            // Açıklama
            if (d.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 16),
                child: Text(d.description,
                    style: const TextStyle(fontSize: 15)),
              ),
            ],

            // Adres
            if (d.address.isNotEmpty) ...[
              const SizedBox(height: 16),
              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(CupertinoIcons.location,
                        size: 18,
                        color: CupertinoColors.activeBlue),
                    const SizedBox(width: 8),
                    Expanded(child: Text(d.address)),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        Clipboard.setData(
                            ClipboardData(text: d.address));
                        _toast(context, 'Adres kopyalandı');
                      },
                      child: const Icon(
                          CupertinoIcons.doc_on_doc),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _toast(BuildContext context, String msg) {
    final ctrl = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (_) => Positioned(
        bottom: 100,
        left: 24,
        right: 24,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            color: const Color(0xCC333333),
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
            child: Center(
              child: Text(msg,
                  style:
                  const TextStyle(color: CupertinoColors.white)),
            ),
          ),
        ),
      ),
    );
    ctrl.insert(entry);
    Future.delayed(const Duration(milliseconds: 1500),
            () => entry.remove());
  }
}

class _Gallery extends StatefulWidget {
  final List<String> images;
  final ValueChanged<int> onPage;
  final int index;
  const _Gallery(
      {required this.images, required this.onPage, required this.index});
  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  late final PageController _pc =
  PageController(initialPage: widget.index);
  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imgs = widget.images.where((e) => e.isNotEmpty).toList();
    if (imgs.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: PageView.builder(
            controller: _pc,
            itemCount: imgs.length,
            onPageChanged: widget.onPage,
            itemBuilder: (_, i) => Image.network(
              imgs[i],
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Container(color: CupertinoColors.systemGrey5),
            ),
          ),
        ),
        const SizedBox(height: 6),
        if (imgs.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              imgs.length,
                  (i) => Container(
                width: 6,
                height: 6,
                margin:
                const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i == widget.index
                      ? CupertinoColors.activeBlue
                      : CupertinoColors.inactiveGray,
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _ActionsRow extends StatelessWidget {
  final String phone, whatsapp, website, address;
  const _ActionsRow(
      {required this.phone,
        required this.whatsapp,
        required this.website,
        required this.address});

  @override
  Widget build(BuildContext context) {
    final items = <_ActionBtn>[];
    if (phone.isNotEmpty) {
      items.add(_ActionBtn(
          icon: CupertinoIcons.phone,
          label: 'Ara',
          onTap: () => _call(phone)));
    }
    if (whatsapp.isNotEmpty) {
      items.add(_ActionBtn(
          icon: CupertinoIcons.chat_bubble_2,
          label: 'WhatsApp',
          onTap: () => _wa(whatsapp)));
    }
    if (website.isNotEmpty) {
      items.add(_ActionBtn(
          icon: CupertinoIcons.globe,
          label: 'Web',
          onTap: () => _web(website)));
    }
    if (address.isNotEmpty) {
      items.add(_ActionBtn(
          icon: CupertinoIcons.map,
          label: 'Harita',
          onTap: () => _maps(address)));
    }

    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Wrap(spacing: 8, runSpacing: 8, children: items),
    );
  }

  static Future<void> _call(String phone) async {
    final uri = Uri.parse('tel:${phone.replaceAll(' ', '')}');
    await launchUrl(uri);
  }

  static Future<void> _wa(String phone) async {
    final digits =
    phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('https://wa.me/$digits');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static Future<void> _web(String url) async {
    final uri =
    Uri.parse(url.startsWith('http') ? url : 'https://$url');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static Future<void> _maps(String address) async {
    final uri = Uri.parse(
        Uri.encodeFull('https://maps.google.com/?q=$address'));
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding:
      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: CupertinoColors.systemGrey5,
      onPressed: onTap,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 18),
        const SizedBox(width: 6),
        Text(label),
      ]),
    );
  }
}
