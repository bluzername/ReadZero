import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Branded gradient placeholder shown when an article has no image.
/// Displays a source-appropriate icon and domain text.
class SourcePlaceholder extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final String? logoUrl;

  const SourcePlaceholder({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.logoUrl,
  });

  @override
  Widget build(BuildContext context) {
    final source = _detectSource(url);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark ? source.gradientDark : source.gradientLight,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (logoUrl != null)
            // Use the provided logo URL directly
            _FaviconIcon(
              faviconUrl: logoUrl!,
              fallbackIcon: source.icon,
              size: height != null && height! < 80 ? 20 : 32,
            )
          else if (source.isGeneric)
            // Generic source - try loading favicon from Google API
            _FaviconIcon(
              faviconUrl: _buildFaviconUrl(url),
              fallbackIcon: source.icon,
              size: height != null && height! < 80 ? 20 : 32,
            )
          else
            Icon(
              source.icon,
              size: height != null && height! < 80 ? 20 : 32,
              color: Colors.white.withOpacity(0.9),
            ),
          if (height == null || height! >= 80) ...[
            const SizedBox(height: 8),
            Text(
              source.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.7),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _buildFaviconUrl(String url) {
    try {
      final domain = Uri.parse(url).host;
      return 'https://www.google.com/s2/favicons?domain=$domain&sz=128';
    } catch (_) {
      return '';
    }
  }

  static _SourceInfo _detectSource(String url) {
    final lower = url.toLowerCase();

    if (lower.contains('x.com') || lower.contains('twitter.com')) {
      return _SourceInfo(
        icon: Icons.tag,
        label: 'X',
        gradientLight: [const Color(0xFF1A1A2E), const Color(0xFF16213E)],
        gradientDark: [const Color(0xFF0F0F1A), const Color(0xFF1A1A2E)],
      );
    }
    if (lower.contains('linkedin.com')) {
      return _SourceInfo(
        icon: Icons.work_outline,
        label: 'LinkedIn',
        gradientLight: [const Color(0xFF0077B5), const Color(0xFF005885)],
        gradientDark: [const Color(0xFF004471), const Color(0xFF003355)],
      );
    }
    if (lower.contains('reddit.com')) {
      return _SourceInfo(
        icon: Icons.forum_outlined,
        label: 'Reddit',
        gradientLight: [const Color(0xFFFF4500), const Color(0xFFCC3700)],
        gradientDark: [const Color(0xFF992900), const Color(0xFF661C00)],
      );
    }
    if (lower.contains('youtube.com') || lower.contains('youtu.be')) {
      return _SourceInfo(
        icon: Icons.play_circle_outline,
        label: 'YouTube',
        gradientLight: [const Color(0xFFFF0000), const Color(0xFFCC0000)],
        gradientDark: [const Color(0xFF990000), const Color(0xFF660000)],
      );
    }
    if (lower.contains('github.com')) {
      return _SourceInfo(
        icon: Icons.code,
        label: 'GitHub',
        gradientLight: [const Color(0xFF24292E), const Color(0xFF1B1F23)],
        gradientDark: [const Color(0xFF0D1117), const Color(0xFF161B22)],
      );
    }
    if (lower.contains('medium.com')) {
      return _SourceInfo(
        icon: Icons.article_outlined,
        label: 'Medium',
        gradientLight: [const Color(0xFF292929), const Color(0xFF1A1A1A)],
        gradientDark: [const Color(0xFF1A1A1A), const Color(0xFF0D0D0D)],
      );
    }

    // Generic fallback - app indigo
    return _SourceInfo(
      icon: Icons.language,
      label: _extractDomain(url),
      gradientLight: [const Color(0xFF6366F1), const Color(0xFF4F46E5)],
      gradientDark: [const Color(0xFF3730A3), const Color(0xFF312E81)],
      isGeneric: true,
    );
  }

  static String _extractDomain(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.replaceFirst('www.', '');
    } catch (_) {
      return 'Article';
    }
  }
}

/// Loads a favicon via CachedNetworkImage, falling back to a Material icon.
class _FaviconIcon extends StatelessWidget {
  final String faviconUrl;
  final IconData fallbackIcon;
  final double size;

  const _FaviconIcon({
    required this.faviconUrl,
    required this.fallbackIcon,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    if (faviconUrl.isEmpty) {
      return Icon(
        fallbackIcon,
        size: size,
        color: Colors.white.withOpacity(0.9),
      );
    }

    return CachedNetworkImage(
      imageUrl: faviconUrl,
      width: size,
      height: size,
      placeholder: (_, __) => Icon(
        fallbackIcon,
        size: size,
        color: Colors.white.withOpacity(0.9),
      ),
      errorWidget: (_, __, ___) => Icon(
        fallbackIcon,
        size: size,
        color: Colors.white.withOpacity(0.9),
      ),
    );
  }
}

class _SourceInfo {
  final IconData icon;
  final String label;
  final List<Color> gradientLight;
  final List<Color> gradientDark;
  final bool isGeneric;

  const _SourceInfo({
    required this.icon,
    required this.label,
    required this.gradientLight,
    required this.gradientDark,
    this.isGeneric = false,
  });
}
