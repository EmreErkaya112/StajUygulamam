// lib/services/business_api.dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// ------------------------------------------------------------
/// API base
/// ------------------------------------------------------------
const String _baseUrl = 'https://yagmurlukoyu.org/api';

/// Http helpers (timeout'lu)
Future<http.Response> _safeGet(Uri uri) =>
    http.get(uri).timeout(const Duration(seconds: 15));

Future<http.Response> _safePost(Uri uri,
    {Map<String, String>? headers, Object? body}) =>
    http.post(uri, headers: headers, body: body)
        .timeout(const Duration(seconds: 15));

/// ------------------------------------------------------------
/// Models
/// ------------------------------------------------------------
class BusinessCategory {
  final int id;
  final String name;
  final String? icon;
  final bool isActive;

  BusinessCategory({
    required this.id,
    required this.name,
    this.icon,
    required this.isActive,
  });

  factory BusinessCategory.fromJson(Map<String, dynamic> j) {
    int _toInt(dynamic v) => (v is int) ? v : int.tryParse('$v') ?? 0;
    bool _toBool(dynamic v) {
      if (v is bool) return v;
      final s = ('$v').toLowerCase();
      return s == '1' || s == 'true' || s == 'yes';
    }

    return BusinessCategory(
      id: _toInt(j['id']),
      name: (j['name'] ?? j['category_name'] ?? '').toString(),
      icon: (j['icon'] ?? j['icon_url'])?.toString(),
      isActive: _toBool(j['is_active'] ?? 1),
    );
  }
}

class Business {
  final int id;
  final int categoryId;
  final String categoryName;
  final String name;
  final String description;
  final String address;
  final String phone;
  final String website;
  final String coverUrl;
  final String whatsapp; // ← eklendi
  final double? lat;
  final double? lng;
  final double ratingAvg;
  final int ratingCount;
  bool isFavorite;

  Business({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.name,
    required this.description,
    required this.address,
    required this.phone,
    required this.website,
    required this.coverUrl,
    required this.whatsapp, // ← eklendi
    required this.lat,
    required this.lng,
    required this.ratingAvg,
    required this.ratingCount,
    required this.isFavorite,
  });

  factory Business.fromJson(Map<String, dynamic> j) {
    int _toInt(dynamic v) => (v is int) ? v : int.tryParse('$v') ?? 0;
    double? _toDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse('$v');
    }
    bool _toBool(dynamic v) {
      if (v is bool) return v;
      final s = ('$v').toLowerCase();
      return s == '1' || s == 'true' || s == 'yes';
    }
    String _str(dynamic v) => (v ?? '').toString();

    return Business(
      id: _toInt(j['id']),
      categoryId: _toInt(j['category_id'] ?? j['categoryId']),
      categoryName: _str(j['category_name'] ?? j['categoryName']),
      name: _str(j['name']),
      description: _str(j['description']),
      address: _str(j['address']),
      phone: _str(j['phone']),
      website: _str(j['website']),
      coverUrl: _str(j['cover_url'] ?? j['coverUrl']),
      whatsapp: _str(j['whatsapp'] ?? j['whatsapp_phone'] ?? j['whatsApp']), // ← eklendi
      lat: _toDouble(j['lat']),
      lng: _toDouble(j['lng']),
      ratingAvg: _toDouble(j['rating_avg'] ?? j['ratingAvg']) ?? 0.0,
      ratingCount: _toInt(j['rating_count'] ?? j['ratingCount']),
      isFavorite: _toBool(j['is_favorite'] ?? j['isFavorite'] ?? false),
    );
  }
}

class BusinessDetail {
  final Business data;
  final List<String> images;

  BusinessDetail({required this.data, required this.images});
}

/// Liste endpoint’i için basit sonuç sınıfı
class BusinessListResult {
  final List<Business> items;
  final int? nextPage;
  BusinessListResult({required this.items, required this.nextPage});
}

/// ------------------------------------------------------------
/// API client
/// ------------------------------------------------------------
class BusinessApi {
  /// Kategoriler
  static Future<List<BusinessCategory>> fetchCategories() async {
    try {
      final uri = Uri.parse('$_baseUrl/get_business_categories.php');
      final r = await _safeGet(uri);
      if (r.statusCode != 200) return [];
      final b = json.decode(r.body);
      final ok = b is Map && (b['success'] == true || b['success'] == 1);
      if (!ok) return [];
      final list = (b['data'] as List)
          .map((e) => BusinessCategory.fromJson(e as Map<String, dynamic>))
          .toList();
      return list;
    } catch (_) {
      return [];
    }
  }

  /// İşletmeler listesi (sayfalı)
  static Future<BusinessListResult> fetchBusinesses({
    String q = '',
    int? categoryId,
    int page = 1,
    int pageSize = 20,
    String sort = 'new', // 'new' | 'name'
    double? lat,
    double? lng,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getInt('userId') ?? 0;

      final params = <String, String>{
        if (q.isNotEmpty) 'q': q,
        if (categoryId != null) 'categoryId': '$categoryId',
        'page': '$page',
        'pageSize': '$pageSize',
        'sort': sort,
        'userId': '$uid',
        if (lat != null) 'lat': '$lat',
        if (lng != null) 'lng': '$lng',
      };

      final uri = Uri.parse('$_baseUrl/get_businesses.php')
          .replace(queryParameters: params);

      final r = await _safeGet(uri);
      if (r.statusCode != 200) {
        return BusinessListResult(items: const [], nextPage: null);
      }
      final b = json.decode(r.body);
      final ok = b is Map && (b['success'] == true || b['success'] == 1);
      if (!ok) {
        return BusinessListResult(items: const [], nextPage: null);
      }

      final items = (b['data'] as List)
          .map((e) => Business.fromJson(e as Map<String, dynamic>))
          .toList();

      final nextRaw = b['nextPage'];
      final next = nextRaw == null ? null : int.tryParse('$nextRaw');

      return BusinessListResult(items: items, nextPage: next);
    } catch (_) {
      return BusinessListResult(items: const [], nextPage: null);
    }
  }

  /// İşletme detay + galeri
  static Future<BusinessDetail?> fetchBusinessDetail(int id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getInt('userId') ?? 0;

      final uri = Uri.parse('$_baseUrl/get_business_detail.php')
          .replace(queryParameters: {'id': '$id', 'userId': '$uid'});

      final r = await _safeGet(uri);
      if (r.statusCode != 200) return null;

      final b = json.decode(r.body);
      final ok = b is Map && (b['success'] == true || b['success'] == 1);
      if (!ok) return null;

      final data = Business.fromJson(b['data'] as Map<String, dynamic>);
      final images =
          (b['images'] as List?)?.map((e) => '$e').toList() ?? <String>[];

      return BusinessDetail(data: data, images: images);
    } catch (_) {
      return null;
    }
  }

  /// Favori durumunu toggle eder; yeni durumu döner (true/false) veya hata varsa null.
  static Future<bool?> toggleFavorite(int businessId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getInt('userId') ?? 0;

      final uri = Uri.parse('$_baseUrl/toggle_business_favorite.php');
      final r = await _safePost(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'businessId': businessId, 'userId': uid}),
      );

      if (r.statusCode != 200) return null;

      final b = json.decode(r.body);
      final ok = b is Map && (b['success'] == true || b['success'] == 1);
      if (!ok) return null;

      final val = b['isFavorite'];
      if (val is bool) return val;
      if (val is num) return val != 0;
      if (val is String) {
        final s = val.toLowerCase();
        return s == '1' || s == 'true' || s == 'yes';
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
