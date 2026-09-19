import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import 'game.dart';

const int kStickDeadZone = 8000;

class GamepadState {
  const GamepadState({
    this.connected = false,
    this.direction,
    this.fire = false,
    this.beam = false,
    this.triple = false,
    this.pause = false,
  });

  final bool connected;
  final Direction? direction;
  final bool fire;
  final bool beam;
  final bool triple;
  final bool pause;
}

GamepadState mapXInput({
  required int buttons,
  required int thumbLX,
  required int thumbLY,
}) {
  Direction? direction;
  if (buttons & 0x0001 != 0) {
    direction = Direction.up;
  } else if (buttons & 0x0002 != 0) {
    direction = Direction.down;
  } else if (buttons & 0x0004 != 0) {
    direction = Direction.left;
  } else if (buttons & 0x0008 != 0) {
    direction = Direction.right;
  }
  if (direction == null) {
    final absX = thumbLX.abs();
    final absY = thumbLY.abs();
    if (absX > kStickDeadZone && absX >= absY) {
      direction = thumbLX > 0 ? Direction.right : Direction.left;
    } else if (absY > kStickDeadZone && absY > absX) {
      direction = thumbLY > 0 ? Direction.up : Direction.down;
    }
  }
  return GamepadState(
    connected: true,
    direction: direction,
    fire: buttons & 0x1000 != 0,
    beam: buttons & 0x2000 != 0,
    triple: buttons & 0x4000 != 0,
    pause: buttons & 0x0010 != 0,
  );
}

typedef _XInputGetStateNative = Int32 Function(
  Uint32 dwUserIndex,
  Pointer<XInputState> pState,
);
typedef _XInputGetStateDart = int Function(
  int dwUserIndex,
  Pointer<XInputState> pState,
);

final class XInputGamepad extends Struct {
  @Uint16()
  external int buttons;

  @Uint8()
  external int leftTrigger;

  @Uint8()
  external int rightTrigger;

  @Int16()
  external int thumbLX;

  @Int16()
  external int thumbLY;

  @Int16()
  external int thumbRX;

  @Int16()
  external int thumbRY;
}

final class XInputState extends Struct {
  @Uint32()
  external int packetNumber;

  external XInputGamepad gamepad;
}

class Gamepad {
  Gamepad() : _getState = _load();

  final _XInputGetStateDart? _getState;
  Pointer<XInputState>? _state;
  int _index = 0;

  static _XInputGetStateDart? _load() {
    if (!Platform.isWindows) {
      return null;
    }
    for (final name in const [
      'xinput1_4.dll',
      'xinput1_3.dll',
      'xinput9_1_0.dll',
    ]) {
      try {
        final library = DynamicLibrary.open(name);
        return library.lookupFunction<_XInputGetStateNative,
            _XInputGetStateDart>('XInputGetState');
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  bool get available => _getState != null;

  GamepadState poll() {
    final getState = _getState;
    if (getState == null) {
      return const GamepadState();
    }
    final state = _state ??= calloc<XInputState>();
    if (getState(_index, state) != 0) {
      _index = (_index + 1) % 4;
      return const GamepadState();
    }
    final pad = state.ref.gamepad;
    return mapXInput(
      buttons: pad.buttons,
      thumbLX: pad.thumbLX,
      thumbLY: pad.thumbLY,
    );
  }

  void dispose() {
    final state = _state;
    if (state != null) {
      calloc.free(state);
      _state = null;
    }
  }
}
