import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// 2026-08-30: runtime companion to [kChinaMode] for the font picker.
///
/// `kChinaMode` is a compile-time bet about the *build*, not the
/// network the device is actually on — several mainland-China users
/// report running the international build successfully. This service
/// answers the narrower, runtime question `availableFontOptions()`
/// actually needs: can this device reach the CDN `google_fonts`
/// downloads font bytes from, right now?
enum GoogleFontsReachability { unknown, reachable, unreachable }

/// Probes `fonts.gstatic.com` — the exact host+path shape
/// `package:google_fonts` fetches font bytes from at runtime (see
/// `GoogleFontsFile.url` in the package's `google_fonts_descriptor.dart`:
/// `https://fonts.gstatic.com/s/a/<sha256>.ttf`). Probing this real byte
/// URL, rather than guessing at some other Google origin's CORS
/// behaviour, means a "reachable" verdict actually predicts whether a
/// font download will succeed.
///
/// The verdict is cached in memory and in SharedPreferences with a
/// timestamp so the font picker doesn't re-probe on every open — at
/// most once per [cacheTtl].
class GoogleFontsReachabilityService {
  GoogleFontsReachabilityService._();
  static final GoogleFontsReachabilityService instance =
      GoogleFontsReachabilityService._();

  static const _prefsKeyVerdict = 'googleFontsReachability.verdict';
  static const _prefsKeyCheckedAt = 'googleFontsReachability.checkedAtMs';

  static const cacheTtl = Duration(hours: 24);
  static const probeTimeout = Duration(seconds: 4);

  // EB Garamond Regular's actual gstatic byte URL, taken from
  // google_fonts 6.3.3's generated `part_e.g.dart`. The hash is a
  // content address (sha256 of the font bytes) — stable as long as the
  // package version pinned in pubspec.yaml doesn't change the file.
  static const _probeUrl =
      'https://fonts.gstatic.com/s/a/'
      '7972e824546ea84fd60f287a863b9a3b8cfeb69ca63f2257e11d29d2699fb691.ttf';

  GoogleFontsReachability _verdict = GoogleFontsReachability.unknown;
  bool _loadedFromPrefs = false;
  Future<void>? _inFlight;

  /// Test-only seam: swap in a fake [http.Client] (e.g.
  /// `http.testing.MockClient`) instead of making a real network call.
  @visibleForTesting
  http.Client Function() clientFactory = http.Client.new;

  /// Current best-known verdict. `unknown` until a probe completes (or
  /// resolves from cache) — callers must fail open on `unknown`.
  GoogleFontsReachability get verdict => _verdict;

  /// Kicks off a probe if the cached verdict is missing or stale.
  /// Fire-and-forget: safe to call from `build()` / a synchronous
  /// catalogue function — never awaited by the caller, never throws.
  void ensureProbed() {
    if (_inFlight != null) return;
    _inFlight = _run().whenComplete(() => _inFlight = null);
  }

  Future<void> _run() async {
    if (!_loadedFromPrefs) {
      _loadedFromPrefs = true;
      await _loadFromPrefsIfFresh();
      if (_verdict != GoogleFontsReachability.unknown) return;
    } else if (_verdict != GoogleFontsReachability.unknown) {
      // Already resolved this session; only re-probe once the cache
      // (checked via prefs timestamp) goes stale, which a fresh
      // process picks up through _loadFromPrefsIfFresh above.
      return;
    }
    await _probeNetwork();
  }

  Future<void> _loadFromPrefsIfFresh() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final checkedAtMs = prefs.getInt(_prefsKeyCheckedAt);
      if (checkedAtMs == null) return;
      final checkedAt = DateTime.fromMillisecondsSinceEpoch(checkedAtMs);
      if (DateTime.now().difference(checkedAt) > cacheTtl) return;
      final stored = prefs.getString(_prefsKeyVerdict);
      if (stored == 'reachable') {
        _verdict = GoogleFontsReachability.reachable;
      } else if (stored == 'unreachable') {
        _verdict = GoogleFontsReachability.unreachable;
      }
    } catch (e) {
      debugPrint('[google_fonts_reachability] prefs read failed: $e');
    }
  }

  Future<void> _probeNetwork() async {
    GoogleFontsReachability result;
    final client = clientFactory();
    try {
      final response = await client
          .get(Uri.parse(_probeUrl))
          .timeout(probeTimeout);
      result = response.statusCode == 200
          ? GoogleFontsReachability.reachable
          : GoogleFontsReachability.unreachable;
    } catch (e) {
      // Timeout, DNS failure, TLS reset, CORS rejection on web — all
      // mean the same thing here: the picker should hide Google fonts.
      result = GoogleFontsReachability.unreachable;
    } finally {
      client.close();
    }
    _verdict = result;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKeyVerdict,
        result == GoogleFontsReachability.reachable
            ? 'reachable'
            : 'unreachable',
      );
      await prefs.setInt(
        _prefsKeyCheckedAt,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      debugPrint('[google_fonts_reachability] prefs write failed: $e');
    }
  }

  /// Test-only hook: force a verdict without a real network call or
  /// SharedPreferences round-trip.
  @visibleForTesting
  void debugSetVerdict(GoogleFontsReachability v) {
    _verdict = v;
    _loadedFromPrefs = true;
  }

  /// Test-only hook: return to the untouched startup state.
  @visibleForTesting
  void debugReset() {
    _verdict = GoogleFontsReachability.unknown;
    _loadedFromPrefs = false;
    _inFlight = null;
    clientFactory = http.Client.new;
  }

  /// Test-only hook: await whatever probe [ensureProbed] most recently
  /// kicked off, so a test can assert on the verdict deterministically
  /// instead of racing the fire-and-forget future.
  @visibleForTesting
  Future<void> debugWaitForProbe() => _inFlight ?? Future<void>.value();
}
