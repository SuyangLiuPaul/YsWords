import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/services/sermon_audio_service.dart';
import 'package:yswords/widgets/sermon_audio_bar.dart';

/// The bar is docked on the sermon page, so it is built for *every*
/// sermon — including any that has no audio. Rendering nothing in that
/// case is the whole contract: a docked disabled transport would eat
/// screen height on a reading page and promise something it cannot do.
void main() {
  Future<void> pump(WidgetTester tester, String sermonId) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AppSettings>(
        create: (_) => AppSettings(),
        child: MaterialApp(
          home: Scaffold(
            bottomNavigationBar: SermonAudioBar(sermonId: sermonId),
            body: const SizedBox(),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('a sermon with no audio renders nothing', (tester) async {
    await pump(tester, 'no-such-sermon-id');
    expect(find.byType(Slider), findsNothing);
    expect(find.byType(IconButton), findsNothing);
    // Not merely invisible — it must take no space on the page.
    final size = tester.getSize(find.byType(SermonAudioBar));
    expect(size.height, 0);
  });

  testWidgets('the bar does not throw before the index loads',
      (tester) async {
    // load() is async and the first frame happens before it resolves;
    // hasAudio must tolerate a null index rather than blowing up the
    // whole sermon page on the way in.
    await pump(tester, '002');
    expect(tester.takeException(), isNull);
  });

  test('the service reports every sermon as playable', () async {
    // Guards the wiring end-to-end: the index parses, the base URL is
    // set, and hasAudio is true — the three things that have to hold
    // for a play button to appear at all.
    await SermonAudioService.instance.load();
    expect(SermonAudioService.instance.playableSermonCount, 289);
    expect(SermonAudioService.instance.hasAudio('002'), isTrue);
    expect(SermonAudioService.instance.hasAudio('nope'), isFalse);
  }, skip: 'needs rootBundle; covered by sermon_audio_index_test.dart');
}
