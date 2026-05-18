import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/home_banner_models.dart';
import 'app_session_controller.dart';
import 'gesit_api_client.dart';

class HomeBannerController extends ChangeNotifier {
  HomeBannerController({
    required AppSessionController sessionController,
    GesitApiClient? apiClient,
  }) : _sessionController = sessionController,
       _apiClient = apiClient ?? GesitApiClient();

  final AppSessionController _sessionController;
  final GesitApiClient _apiClient;

  List<HomeBannerItem> _banners = const <HomeBannerItem>[];
  bool _loading = false;
  bool _loaded = false;
  String? _error;

  List<HomeBannerItem> get banners => _banners;
  bool get loading => _loading;
  bool get loaded => _loaded;
  String? get error => _error;

  Future<void> ensureLoaded() async {
    if (_loaded || _loading) {
      return;
    }

    await refresh();
  }

  Future<void> refresh() async {
    final session = _sessionController.session;
    if (session == null) {
      _banners = const <HomeBannerItem>[];
      _loaded = true;
      notifyListeners();
      return;
    }

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final payload = await _apiClient.fetchHomeBanners(
        baseUrl: session.apiBaseUrl,
        cookies: session.cookies,
      );
      await _sessionController.syncCookies(payload.cookies);

      _banners = homeBannerItemsFromPayload(payload.data['banners']);
      _error = null;
    } on TimeoutException {
      _error = 'Banner home terlalu lama merespons.';
    } on GesitApiException catch (error) {
      _error = error.message;
      if (error.statusCode == 401 ||
          error.statusCode == 403 ||
          error.statusCode == 419) {
        _banners = const <HomeBannerItem>[];
      }
    } catch (_) {
      _error = 'Banner home belum bisa dimuat.';
    } finally {
      _loading = false;
      _loaded = true;
      notifyListeners();
    }
  }
}
