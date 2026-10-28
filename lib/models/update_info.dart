import 'dart:io';

class UpdateInfo {
  final String tagName;
  final String version;
  final String releaseName;
  final String releaseNotes;
  final DateTime publishedAt;
  final String htmlUrl;
  final String downloadUrl;
  final String assetName;
  final int assetSize;
  final bool isNewer;

  const UpdateInfo({
    required this.tagName,
    required this.version,
    required this.releaseName,
    required this.releaseNotes,
    required this.publishedAt,
    required this.htmlUrl,
    required this.downloadUrl,
    required this.assetName,
    required this.assetSize,
    required this.isNewer,
  });

  String get formattedSize {
    if (assetSize <= 0) return '';
    final mb = assetSize / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  static bool compareVersions(String remote, String current) {
    try {
      final rParts = remote.replaceAll(RegExp(r'[^0-9.]'), '').split('.').map(int.parse).toList();
      final cParts = current.replaceAll(RegExp(r'[^0-9.]'), '').split('.').map(int.parse).toList();

      for (int i = 0; i < 3; i++) {
        final r = i < rParts.length ? rParts[i] : 0;
        final c = i < cParts.length ? cParts[i] : 0;
        if (r > c) return true;
        if (r < c) return false;
      }
      return false;
    } catch (_) {
      return remote != current;
    }
  }

  static String selectPlatformAsset(List<dynamic> assets) {
    if (assets.isEmpty) return '';

    String? preferredUrl;
    if (Platform.isAndroid) {
      preferredUrl = _findUrl(assets, (name) => name.endsWith('.apk'));
    } else if (Platform.isWindows) {
      // Prioritize setup installer (.exe), then portable .zip
      preferredUrl = _findUrl(assets, (name) => name.contains('installer') || name.contains('setup') || name.endsWith('.exe')) ??
          _findUrl(assets, (name) => name.contains('windows') && name.endsWith('.zip'));
    } else if (Platform.isMacOS) {
      preferredUrl = _findUrl(assets, (name) => (name.contains('macos') || name.contains('darwin')) && (name.endsWith('.zip') || name.endsWith('.dmg')));
    }

    // Fallback to first asset or html url
    return preferredUrl ?? (assets.isNotEmpty ? assets.first['browser_download_url'] ?? '' : '');
  }

  static String? _findUrl(List<dynamic> assets, bool Function(String name) predicate) {
    for (final a in assets) {
      final name = (a['name'] ?? '').toString().toLowerCase();
      if (predicate(name)) {
        return a['browser_download_url'] as String?;
      }
    }
    return null;
  }
}
