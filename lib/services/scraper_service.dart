import 'dart:io';
import 'dart:convert';

/// Fetches property data from Booking.com or Agoda URLs
/// and extracts title, description, images, amenities, etc.
class ScraperService {
  static const _uaProfiles = [
    {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
      'Sec-Ch-Ua': '"Chromium";v="131", "Google Chrome";v="131"',
      'Sec-Ch-Ua-Mobile': '?0',
      'Sec-Ch-Ua-Platform': '"Windows"',
    },
    {
      'User-Agent': 'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36',
      'Sec-Ch-Ua': '"Chromium";v="131", "Google Chrome";v="131"',
      'Sec-Ch-Ua-Mobile': '?1',
      'Sec-Ch-Ua-Platform': '"Android"',
    },
    {
      'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 14_5) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15',
      'Sec-Ch-Ua': '',
      'Sec-Ch-Ua-Mobile': '?0',
      'Sec-Ch-Ua-Platform': '"macOS"',
    },
  ];

  static bool _isChallengePage(int status, String body) {
    if (status == 202) return true;
    if (body.contains('reportChallengeError')) return true;
    if (body.contains('window.aws') && body.length < 50000) return true;
    if (body.contains('challenge-form') && !body.contains('og:title')) return true;
    return false;
  }

  static String _addLangSuffix(String u) {
    if (!u.contains('/hotel/')) return u;
    if (u.contains('.html')) return u;
    final idx = u.indexOf('?');
    if (idx != -1) return '${u.substring(0, idx)}.en-gb.html${u.substring(idx)}';
    return '$u.en-gb.html';
  }

  static String _toMobile(String u) => u.replaceAll('www.booking.com', 'm.booking.com');

  static String _addAffiliate(String u) {
    final sep = u.contains('?') ? '&' : '?';
    return '${u}${sep}aid=304142&label=gen173nr';
  }

  /// Fetch and parse property info from a Booking.com or Agoda URL
  static Future<Map<String, dynamic>> scrapePropertyUrl(String url) async {
    final uri = Uri.parse(url.trim());
    final host = uri.host.toLowerCase();
    final isBooking = host.contains('booking.com');

    // Build URL strategies like the TypeScript version
    final strategies = <Map<String, String>>[];
    if (isBooking) {
      strategies.add({'url': _addAffiliate(_addLangSuffix(url)), 'referer': 'https://www.google.com/', 'label': 'booking-google-affiliate'});
      strategies.add({'url': _toMobile(_addLangSuffix(url)), 'referer': 'https://www.google.com/', 'label': 'booking-mobile'});
      strategies.add({'url': url, 'referer': 'https://www.google.com/', 'label': 'booking-share-direct'});
      strategies.add({'url': url, 'referer': 'https://www.booking.com/', 'label': 'booking-plain'});
    } else {
      strategies.add({'url': url, 'referer': 'https://www.google.com/', 'label': 'default'});
      strategies.add({'url': url, 'referer': '', 'label': 'original'});
    }

    String? html;
    String? lastError;

    for (final strategy in strategies) {
      for (final ua in _uaProfiles) {
        try {
          final client = HttpClient();
          client.connectionTimeout = const Duration(seconds: 15);
          final req = await client.getUrl(Uri.parse(strategy['url']!));
          req.headers.set('User-Agent', ua['User-Agent']!);
          req.headers.set('Accept', 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8');
          req.headers.set('Accept-Language', 'en-US,en;q=0.9,ar;q=0.8');
          req.headers.set('Cache-Control', 'no-cache');
          req.headers.set('Upgrade-Insecure-Requests', '1');
          req.headers.set('Sec-Fetch-Dest', 'document');
          req.headers.set('Sec-Fetch-Mode', 'navigate');
          req.headers.set('Sec-Fetch-User', '?1');
          if (strategy['referer']!.isNotEmpty) {
            req.headers.set('Referer', strategy['referer']!);
          }

          final resp = await req.close().timeout(const Duration(seconds: 20));
          final body = await resp.transform(utf8.decoder).join();

          if (resp.statusCode != 200 && resp.statusCode != 202) {
            lastError = 'HTTP ${resp.statusCode} (${strategy['label']})';
            client.close();
            continue;
          }

          if (_isChallengePage(resp.statusCode, body)) {
            lastError = 'Challenge page (${strategy['label']})';
            client.close();
            await Future.delayed(const Duration(milliseconds: 800));
            continue;
          }

          html = body;
          client.close();
          break;
        } catch (e) {
          lastError = '$e (${strategy['label']})';
        }
      }
      if (html != null) break;
    }

    if (html == null || html.isEmpty) {
      throw Exception(lastError ?? 'Failed to fetch URL after all retries');
    }

    if (isBooking) {
      return _parseBooking(html, url);
    } else if (host.contains('agoda.com')) {
      return _parseAgoda(html, url);
    } else {
      return _parseGeneric(html, url);
    }
  }

  // ─── Booking.com ─────────────────────────────────────────
  static Map<String, dynamic> _parseBooking(String html, String url) {
    final result = <String, dynamic>{};

    // Title
    result['title'] = _extractMeta(html, 'og:title') ??
        _extractBetween(html, '<h2 class="hp__hotel-name"', '</h2') ??
        _extractBetween(html, '<title>', '</title>') ??
        '';

    // Description
    result['description'] = _extractMeta(html, 'og:description') ?? '';

    // Images from og:image and bstatic pattern
    final images = <String>{};
    final ogImg = _extractMeta(html, 'og:image');
    if (ogImg != null && ogImg.isNotEmpty) images.add(ogImg);

    // High-res Booking images from bstatic CDN
    final bstaticRegex = RegExp(r'https://cf\.bstatic\.com/xdata/images/hotel/[^"' "'" r'\s)]+');
    for (final m in bstaticRegex.allMatches(html)) {
      var img = m.group(0)!;
      img = img.replaceAll(RegExp(r'/max\d+(?:x\d+)?/'), '/max1024x768/');
      images.add(img);
    }
    result['images'] = images.take(20).toList();

    // Amenities from JSON-LD
    final amenities = <String>[];
    final amenityRegex = RegExp(r'"amenityFeature"\s*:\s*\[(.*?)\]', dotAll: true);
    final amMatch = amenityRegex.firstMatch(html);
    if (amMatch != null) {
      final nameRegex = RegExp(r'"name"\s*:\s*"([^"]+)"');
      for (final n in nameRegex.allMatches(amMatch.group(1)!)) {
        amenities.add(n.group(1)!);
      }
    }
    // Fallback: look for facility items
    if (amenities.isEmpty) {
      final facRegex = RegExp(r'<span[^>]*class="[^"]*facility[^"]*"[^>]*>([^<]+)</span>');
      for (final m in facRegex.allMatches(html)) {
        final a = _stripTags(m.group(1) ?? '').trim();
        if (a.isNotEmpty) amenities.add(a);
      }
    }
    result['amenities'] = amenities.take(30).toList();

    // House rules
    final rulesSection = _extractBetween(html, 'id="hp_policy_content"', 'id="');
    result['houseRules'] = rulesSection != null ? _stripTags(rulesSection).trim() : '';

    // Check-in/out from JSON-LD
    result['checkInInfo'] = _extractJsonLdField(html, 'checkinTime') ?? '';
    result['checkOutInfo'] = _extractJsonLdField(html, 'checkoutTime') ?? '';

    // Address
    result['address'] = _extractJsonLdField(html, 'streetAddress') ??
        _extractMeta(html, 'og:street-address') ??
        '';

    // Guest capacity
    final capacityMatch = RegExp(r'(\d+)\s*(?:guests?|ضيوف)', caseSensitive: false).firstMatch(html);
    result['guestCapacity'] = capacityMatch?.group(1) ?? '';

    // Property highlights
    final highlights = <String>[];
    final hlRegex = RegExp(r'<div[^>]*class="[^"]*property-highlights[^"]*"[^>]*>(.*?)</div>', dotAll: true);
    for (final m in hlRegex.allMatches(html)) {
      final t = _stripTags(m.group(1) ?? '').trim();
      if (t.isNotEmpty && t.length < 200) highlights.add(t);
    }
    result['propertyHighlights'] = highlights.join('\n');

    // Damage deposit
    final depositMatch = RegExp(r'(?:damage\s*deposit|تأمين)[^<]*?([\d,.]+\s*\w{2,3})', caseSensitive: false).firstMatch(html);
    result['damageDeposit'] = depositMatch?.group(0) ?? '';

    // Cancellation policy
    final cancelMatch = RegExp(r'(?:cancellation|إلغاء)[^<]{0,300}', caseSensitive: false).firstMatch(html);
    result['cancellationPolicy'] = cancelMatch != null
        ? _stripTags(cancelMatch.group(0)!).trim().substring(0, (cancelMatch.group(0)!.length).clamp(0, 300))
        : '';

    // Nearby places
    final nearbyRegex = RegExp(r'<li[^>]*class="[^"]*nearby[^"]*"[^>]*>(.*?)</li>', dotAll: true);
    final nearby = <String>[];
    for (final m in nearbyRegex.allMatches(html)) {
      final t = _stripTags(m.group(1) ?? '').trim();
      if (t.isNotEmpty) nearby.add(t);
    }
    result['nearbyPlaces'] = nearby.take(10).join('\n');

    // Location note
    result['locationNote'] = _extractMeta(html, 'og:locality') ?? '';

    return result;
  }

  // ─── Agoda ───────────────────────────────────────────────
  static Map<String, dynamic> _parseAgoda(String html, String url) {
    final result = <String, dynamic>{};

    result['title'] = _extractMeta(html, 'og:title') ??
        _extractBetween(html, '<title>', '</title>') ??
        '';
    result['description'] = _extractMeta(html, 'og:description') ?? '';

    // Images
    final images = <String>{};
    final ogImg = _extractMeta(html, 'og:image');
    if (ogImg != null && ogImg.isNotEmpty) images.add(ogImg);

    final imgRegex = RegExp(r'https://pix\d*\.agoda\.net/[^"' "'" r'\s)]+');
    for (final m in imgRegex.allMatches(html)) {
      images.add(m.group(0)!);
    }
    result['images'] = images.take(20).toList();

    // Try JSON-LD for structured data
    result['amenities'] = <String>[];
    final amenityRegex = RegExp(r'"amenityFeature"\s*:\s*\[(.*?)\]', dotAll: true);
    final amMatch = amenityRegex.firstMatch(html);
    if (amMatch != null) {
      final nameRegex = RegExp(r'"name"\s*:\s*"([^"]+)"');
      for (final n in nameRegex.allMatches(amMatch.group(1)!)) {
        (result['amenities'] as List).add(n.group(1)!);
      }
    }

    result['address'] = _extractJsonLdField(html, 'streetAddress') ?? '';
    result['checkInInfo'] = _extractJsonLdField(html, 'checkinTime') ?? '';
    result['checkOutInfo'] = _extractJsonLdField(html, 'checkoutTime') ?? '';
    result['houseRules'] = '';
    result['locationNote'] = '';
    result['guestCapacity'] = '';
    result['propertyHighlights'] = '';
    result['damageDeposit'] = '';
    result['cancellationPolicy'] = '';
    result['nearbyPlaces'] = '';

    return result;
  }

  // ─── Generic (any hotel page) ────────────────────────────
  static Map<String, dynamic> _parseGeneric(String html, String url) {
    return {
      'title': _extractMeta(html, 'og:title') ??
          _extractBetween(html, '<title>', '</title>') ??
          '',
      'description': _extractMeta(html, 'og:description') ?? '',
      'images': <String>[
        if (_extractMeta(html, 'og:image') != null)
          _extractMeta(html, 'og:image')!,
      ],
      'amenities': <String>[],
      'houseRules': '',
      'checkInInfo': '',
      'checkOutInfo': '',
      'address': '',
      'locationNote': '',
      'guestCapacity': '',
      'propertyHighlights': '',
      'damageDeposit': '',
      'cancellationPolicy': '',
      'nearbyPlaces': '',
    };
  }

  // ─── Helpers ─────────────────────────────────────────────
  static String? _extractMeta(String html, String property) {
    final regex = RegExp(
        'meta[^>]*(?:property|name)=["\']$property["\'][^>]*content=["' "'" ']([^"' "'" ']*)',
        caseSensitive: false);
    final match = regex.firstMatch(html);
    return match?.group(1);
  }

  static String? _extractBetween(String html, String start, String end) {
    final startIdx = html.indexOf(start);
    if (startIdx < 0) return null;
    // Skip past the start tag's closing >
    int contentStart = html.indexOf('>', startIdx + start.length);
    if (contentStart < 0) contentStart = startIdx + start.length;
    else contentStart++;

    final endIdx = html.indexOf(end, contentStart);
    if (endIdx < 0) return null;
    return _stripTags(html.substring(contentStart, endIdx)).trim();
  }

  static String? _extractJsonLdField(String html, String field) {
    final regex = RegExp('"$field"\\s*:\\s*"([^"]*)"');
    final match = regex.firstMatch(html);
    return match?.group(1);
  }

  static String _stripTags(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
