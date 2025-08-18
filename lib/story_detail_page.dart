// lib/story_detail_page.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'home_page.dart'; // Story modelinin tanımlı olduğu dosya

class StoryDetailPage extends StatelessWidget {
  final Story story;
  const StoryDetailPage({required this.story, super.key});

  // Telefonu çevirici (dialer) açar
  Future<void> _launchPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  // Web tarayıcı açar
  Future<void> _launchWebsite(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.systemGrey.withOpacity(0.1),
        middle: Text(
          story.companyName,
          style: const TextStyle(fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ——— Görsel kartı (16:9 oranında) ———
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: FadeInImage.assetNetwork(
                    placeholder: 'assets/derneklogo.png',
                    image: story.imageUrl,
                    fit: BoxFit.contain,
                    imageErrorBuilder: (ctx, err, stack) => Container(
                      color: CupertinoColors.systemGrey5,
                      alignment: Alignment.center,
                      child: const Icon(
                        CupertinoIcons.photo,
                        size: 40,
                        color: CupertinoColors.inactiveGray,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ——— Firma adı ———
              Text(
                story.companyName,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 16),

              // ——— Telefon satırı ———
              _InfoRow(
                icon: CupertinoIcons.phone,
                text: story.phone,
                isLink: true,
                onTap: () => _launchPhone(story.phone),
              ),
              const SizedBox(height: 12),

              // ——— Web satırı ———
              _InfoRow(
                icon: CupertinoIcons.link,
                text: story.website,
                isLink: true,
                onTap: () => _launchWebsite(story.website),
              ),

              const SizedBox(height: 24),

              // ——— Açıklama kartı ———
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  story.description,
                  style: const TextStyle(fontSize: 16, height: 1.4),
                ),
              ),

              const SizedBox(height: 24),

              // ——— Yayın tarihi ———
              Text(
                'Yayın tarihi: ${story.createdAt}',
                style: const TextStyle(color: CupertinoColors.inactiveGray),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tek bir satırlık ikon + metin, isLink ise tıklanabilir
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isLink;
  final VoidCallback? onTap;

  const _InfoRow({
    required this.icon,
    required this.text,
    this.isLink = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final row = Row(
      children: [
        Icon(icon, size: 20, color: CupertinoColors.activeGreen),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 16,
              color: isLink ? CupertinoColors.activeBlue : CupertinoColors.label,
              decoration: isLink ? TextDecoration.underline : TextDecoration.none,
            ),
          ),
        ),
      ],
    );

    if (isLink && onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: row,
      );
    }
    return row;
  }
}
