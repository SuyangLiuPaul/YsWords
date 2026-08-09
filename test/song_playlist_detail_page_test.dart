import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/song_playlist.dart';
import 'package:yswords/pages/song_playlist_detail_page.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/services/song_playlist_service.dart';
import 'package:yswords/services/song_service.dart';

/// The playlist contents page.
///
/// `reorder` and `removeSong` had unit tests and no UI at all, so a
/// song added by mistake could not be taken out and the play order was
/// whatever order things were added in. These tests drive the real
/// page against the real catalogue, because the part most likely to
/// break is the wiring between the list widget's index convention and
/// the service's — not either side on its own.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final locale = AppSettings().locale;

  Future<void> pump(WidgetTester tester, String playlistId) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => MainProvider()),
          ChangeNotifierProvider(create: (_) => AppSettings()),
        ],
        child: MaterialApp(
          home: SongPlaylistDetailPage(playlistId: playlistId),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('lists a playlist, removes a song, and undoes it',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    addTearDown(tester.view.reset);

    final catalogue = (await tester.runAsync(SongService.load))!;
    final svc = SongPlaylistService.instance;
    await svc.resetForTest();

    final three = catalogue.take(3).toList();
    final playlist = await svc.create('test list');
    await svc.addSongs(playlist, three);

    await pump(tester, playlist.id);

    for (final s in three) {
      expect(find.text(s.title), findsWidgets,
          reason: '${s.title} should be listed');
    }

    // Remove the middle one.
    final removeButtons = find.byIcon(Icons.remove_circle_outline);
    expect(removeButtons, findsNWidgets(3));
    await tester.tap(removeButtons.at(1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      svc.playlists.firstWhere((p) => p.id == playlist.id).songIds,
      [three[0].id, three[2].id],
    );

    // Undo puts it back where it was, not on the end — a list someone
    // ordered by hand should survive a mis-tap.
    await tester.tap(find.text(uiStrings['undo']![locale]!));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      svc.playlists.firstWhere((p) => p.id == playlist.id).songIds,
      [three[0].id, three[1].id, three[2].id],
      reason: 'undo should restore the original position',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('a smart playlist is read-only', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    addTearDown(tester.view.reset);

    await tester.runAsync(SongService.load);
    final svc = SongPlaylistService.instance;
    await svc.resetForTest();

    // A saved filter's membership comes from the catalogue, so offering
    // a drag handle or a remove button would promise something the
    // model cannot keep.
    final smart = await svc.create('cgdc 2025',
        filter: const PlaylistFilter(source: 'cgdc'));

    await pump(tester, smart.id);

    expect(find.byIcon(Icons.remove_circle_outline), findsNothing);
    expect(find.byIcon(Icons.drag_handle_rounded), findsNothing);
    expect(find.text(uiStrings['songsSmartPlaylistNote']![locale]!),
        findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('a deleted playlist says so instead of looking empty',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    addTearDown(tester.view.reset);

    await tester.runAsync(SongService.load);
    await SongPlaylistService.instance.resetForTest();

    await pump(tester, 'no-such-playlist');

    expect(find.text(uiStrings['songsPlaylistGone']![locale]!),
        findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 400));
  });
}
