import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/update_info.dart';

class OtaUpdateService extends ChangeNotifier {
  static final OtaUpdateService instance = OtaUpdateService._();
  OtaUpdateService._();

  static const String currentVersion = '2.2.2';
  static const String repoOwner = 'ozertugrul';
  static const String repoName = 'vpnchain';
  static const String apiUrl = 'https://api.github.com/repos/$repoOwner/$repoName/releases/latest';

  bool _isChecking = false;
  DateTime? _lastChecked;
  UpdateInfo? _availableUpdate;
  String? _errorMessage;

  bool get isChecking => _isChecking;
  DateTime? get lastChecked => _lastChecked;
  UpdateInfo? get availableUpdate => _availableUpdate;
  String? get errorMessage => _errorMessage;
  bool get hasUpdate => _availableUpdate != null && _availableUpdate!.isNewer;

  /// Checks GitHub Releases API for a newer version.
  Future<UpdateInfo?> checkForUpdates({bool isManual = false}) async {
    if (_isChecking) return _availableUpdate;

    _isChecking = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 8);

      final uri = Uri.parse(apiUrl);
      final request = await client.getUrl(uri);
      request.headers.set('Accept', 'application/vnd.github.v3+json');
      request.headers.set('User-Agent', 'VPNChain-App-$currentVersion');

      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;

        final tagName = (json['tag_name'] ?? '').toString();
        final rawVersion = tagName.startsWith('v') ? tagName.substring(1) : tagName;
        final releaseName = (json['name'] ?? tagName).toString();
        final releaseNotes = (json['body'] ?? '').toString();
        final publishedAt = DateTime.tryParse(json['published_at'] ?? '') ?? DateTime.now();
        final htmlUrl = (json['html_url'] ?? '').toString();
        final assets = (json['assets'] as List<dynamic>?) ?? [];

        final downloadUrl = UpdateInfo.selectPlatformAsset(assets);
        String assetName = '';
        int assetSize = 0;

        for (final a in assets) {
          if (a['browser_download_url'] == downloadUrl) {
            assetName = a['name'] ?? '';
            assetSize = a['size'] ?? 0;
            break;
          }
        }

        final isNewer = UpdateInfo.compareVersions(rawVersion, currentVersion);

        final update = UpdateInfo(
          tagName: tagName,
          version: rawVersion,
          releaseName: releaseName,
          releaseNotes: releaseNotes,
          publishedAt: publishedAt,
          htmlUrl: htmlUrl,
          downloadUrl: downloadUrl.isNotEmpty ? downloadUrl : htmlUrl,
          assetName: assetName,
          assetSize: assetSize,
          isNewer: isNewer,
        );

        _availableUpdate = update;
        _lastChecked = DateTime.now();
        _isChecking = false;
        notifyListeners();
        return update;
      } else {
        _errorMessage = 'GitHub API returned code ${response.statusCode}';
      }
      client.close();
    } catch (e) {
      _errorMessage = 'Update check failed: $e';
    }

    _isChecking = false;
    _lastChecked = DateTime.now();
    notifyListeners();
    return null;
  }

  /// Opens the release or download URL in the external browser/installer handler.
  Future<bool> launchUpdate(UpdateInfo update) async {
    final targetUrl = update.downloadUrl.isNotEmpty ? update.downloadUrl : update.htmlUrl;
    final uri = Uri.parse(targetUrl);

    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  /// Dismisses the active update banner for the current session.
  void dismissUpdate() {
    _availableUpdate = null;
    notifyListeners();
  }
}
