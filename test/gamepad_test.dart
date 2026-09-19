import 'package:flutter_test/flutter_test.dart';

import 'package:tanks/game.dart';
import 'package:tanks/gamepad.dart';

void main() {
  test('D-pad and buttons are mapped', () {
    final state = mapXInput(
      buttons: 0x0001 | 0x1000 | 0x2000 | 0x4000 | 0x0010,
      thumbLX: 0,
      thumbLY: 0,
    );

    expect(state.connected, isTrue);
    expect(state.direction, Direction.up);
    expect(state.fire, isTrue);
    expect(state.beam, isTrue);
    expect(state.triple, isTrue);
    expect(state.pause, isTrue);
  });

  test('Left stick is mapped with a dead zone', () {
    expect(
      mapXInput(buttons: 0, thumbLX: 20000, thumbLY: 0).direction,
      Direction.right,
    );
    expect(
      mapXInput(buttons: 0, thumbLX: -20000, thumbLY: 0).direction,
      Direction.left,
    );
    expect(
      mapXInput(buttons: 0, thumbLX: 0, thumbLY: 20000).direction,
      Direction.up,
    );
    expect(
      mapXInput(buttons: 0, thumbLX: 0, thumbLY: -20000).direction,
      Direction.down,
    );
    expect(
      mapXInput(buttons: 0, thumbLX: 1000, thumbLY: -1200).direction,
      isNull,
    );
  });
}
