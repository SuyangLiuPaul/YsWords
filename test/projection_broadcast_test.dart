import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:yswords/services/projection_broadcast.dart';

/// The projector's second screen, without a second Flutter engine.
///
/// `projection_page.dart` argued — correctly — that a second Flutter
/// window costs a four-second splash in front of a congregation. The
/// follower is therefore not Flutter: `web/stage.html` paints a FRAME
/// the page sends over a BroadcastChannel. These pin the frame's shape
/// (the follower is plain JavaScript reading these exact keys) and the
/// page's obligations: post on every build, answer a late follower,
/// close on leaving.
void main() {
  test('a frame serialises to the keys stage.html reads', () {
    const f = ProjectionFrame(
      blank: false,
      typeSize: 76,
      reference: '创世纪 1:1–2',
      tags: ['和合本', 'KJV'],
      verses: [
        {'label': '1', 'text': '起初，神创造天地。'},
        {'label': '2', 'text': '地是空虚混沌…'},
      ],
      second: [
        {'label': '1', 'text': 'In the beginning…'},
        {'label': '2', 'text': null},
      ],
      secondNote: null,
      groundColors: ['#0b1320'],
      radial: false,
      ink: '#e6ecf3',
      muted: '#9aa7b8',
    );
    final j = jsonDecode(jsonEncode(f.toJson())) as Map<String, dynamic>;
    expect(j['v'], 1, reason: 'the follower checks the version first');
    expect(j['verses'], hasLength(2));
    expect((j['verses'] as List).first, {'label': '1', 'text': '起初，神创造天地。'});
    expect((j['second'] as List)[1]['text'], isNull,
        reason: 'a verse the second edition lacks is null, not dropped — '
            'positions must line up');
    expect(j['ground'], {'colors': ['#0b1320'], 'radial': false});
    expect(j['reference'], '创世纪 1:1–2');
  });

  test('stage.html exists, joins the same channel, and says hello', () {
    final html = File('web/stage.html').readAsStringSync();
    expect(html.contains("BroadcastChannel('yswords-projection')"), isTrue,
        reason: 'one channel name on both ends');
    expect(html.contains("postMessage('hello')"), isTrue,
        reason: 'a follower opened late asks for the current wall');
    // The desktop wire, in the same file: one painter, two transports.
    expect(html.contains('new WebSocket('), isTrue,
        reason: 'a desktop has no second window to broadcast to');
    expect(html.contains("get('ws')"), isTrue,
        reason: 'which wire is in use is decided by how the page was '
            'opened, never guessed');
    for (final key in ['verses', 'second', 'secondNote', 'ground', 'blank',
        'typeSize', 'reference', 'tags', 'ink', 'muted']) {
      expect(html.contains(key), isTrue, reason: 'stage.html reads $key');
    }
  });

  test('the page posts a frame after every build and closes on leaving', () {
    final page = File('lib/pages/projection_page.dart').readAsStringSync();
    expect(page.contains('ProjectionBroadcast.post(frame)'), isTrue);
    expect(page.contains('addPostFrameCallback'), isTrue,
        reason: 'after the frame is painted, so a follower never runs '
            'ahead of the wall');
    expect(page.contains('ProjectionBroadcast.close();'), isTrue);
    expect(page.contains('ProjectionCommand.openStage'), isTrue);
  });

  test('off the web, a DESKTOP is supported and a phone is not', () {
    // 2026-09-13: this used to read "nothing is supported off the web",
    // which was true while the native half was a stub. A desktop now
    // serves the same follower page over loopback — see
    // `projection_broadcast_io.dart` and its own test — so what is
    // asserted here is the rule, not the answer on this machine: a
    // second display is a desktop's, and a phone has none to drag a
    // window onto.
    expect(
      ProjectionBroadcast.isSupported,
      Platform.isMacOS || Platform.isWindows || Platform.isLinux,
    );
    ProjectionBroadcast.close();
  });
}
