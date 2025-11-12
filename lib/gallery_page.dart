// lib/gallery_page.dart

import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key});
  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  static const _apiEndpoint = 'https://yagmurlukoyu.org/api/list_images.php';
  List<String> _images = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchImages();
  }

  Future<void> _fetchImages() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await http.get(Uri.parse(_apiEndpoint));
      if (res.statusCode != 200) {
        throw 'Sunucu hatası: ${res.statusCode}';
      }
      final decoded = json.decode(res.body);
      if (decoded is List) {
        _images = decoded.cast<String>();
      } else if (decoded is Map<String, dynamic> &&
          decoded['success'] == true &&
          decoded['data'] is List) {
        _images = (decoded['data'] as List).cast<String>();
      } else {
        throw 'Beklenmeyen format';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() => _loading = false);
    }
  }



  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Resim Galerisi'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.refresh),
          onPressed: _fetchImages,
        ),
      ),
      child: SafeArea(
        child: _loading
            ? const Center(child: CupertinoActivityIndicator())
            : _error != null
            ? Center(child: Text('Hata: $_error'))
            : CustomScrollView(
          slivers: [
            CupertinoSliverRefreshControl(onRefresh: _fetchImages),
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        final url = _images[i];
                    return _CreativeTile(url: url, tag: 'img$i');
                  },
                  childCount: _images.length,
                ),
                gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.75,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreativeTile extends StatefulWidget {
  final String url, tag;
  const _CreativeTile({required this.url, required this.tag, super.key});
  @override
  __CreativeTileState createState() => __CreativeTileState();
}

class __CreativeTileState extends State<_CreativeTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      lowerBound: 0.0,
      upperBound: 0.05,
    );
    _scale = Tween(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTapDown(_) => _ctrl.forward();
  void _onTapUp(_) => _ctrl.reverse();
  void _onTapCancel() => _ctrl.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Tıklayınca tam ekran
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (_) =>
                _FullScreenImage(url: widget.url, tag: widget.tag),
          ),
        );
      },
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (ctx, child) => Transform.scale(
          scale: _scale.value,
          child: child,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: CupertinoColors.systemGrey5,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 8,
                offset: Offset(0, 4),
              )
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              widget.url,
              fit: BoxFit.cover,
              loadingBuilder: (ctx, child, prog) {
                if (prog == null) return child;
                return const Center(child: CupertinoActivityIndicator());
              },
              errorBuilder: (_, __, ___) => const Center(
                child: Icon(CupertinoIcons.xmark_circle,
                    size: 50, color: CupertinoColors.destructiveRed),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FullScreenImage extends StatelessWidget {
  final String url, tag;
  const _FullScreenImage({required this.url, required this.tag, super.key});
  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(previousPageTitle: 'Geri'),
      child: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Center(
          child: Hero(
            tag: tag,
            child: Image.network(
              url,
              fit: BoxFit.contain,
              loadingBuilder: (ctx, child, prog) =>
              prog == null ? child : const CupertinoActivityIndicator(),
              errorBuilder: (_, __, ___) => const Icon(
                CupertinoIcons.xmark_circle,
                size: 60,
                color: CupertinoColors.systemRed,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
