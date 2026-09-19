import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'game.dart';
import 'gamepad.dart';
import 'records.dart';
import 'save.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }
  runApp(const TanksApp());
}

class TanksApp extends StatelessWidget {
  const TanksApp({super.key, this.recordStore, this.saveStore});

  final RecordStore? recordStore;
  final SaveStore? saveStore;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Танчики',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7C4DFF),
          brightness: Brightness.dark,
        ),
      ),
      home: MainMenuScreen(recordStore: recordStore, saveStore: saveStore),
    );
  }
}

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key, this.recordStore, this.saveStore});

  final RecordStore? recordStore;
  final SaveStore? saveStore;

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  late final RecordStore _recordStore = widget.recordStore ?? RecordStore();
  late final SaveStore _saveStore = widget.saveStore ?? SaveStore();
  late Records _records = _recordStore.load();
  late bool _hasSave = _saveStore.hasSave;

  Future<void> _play() async {
    final saved = _saveStore.loadGame();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GameScreen(
          recordStore: _recordStore,
          saveStore: _saveStore,
          resumeGame: saved,
        ),
      ),
    );
    if (mounted) {
      setState(() {
        _records = _recordStore.load();
        _hasSave = _saveStore.hasSave;
      });
    }
  }

  Future<void> _continueGame() async {
    final game = _saveStore.loadGame();
    if (game == null) {
      setState(() {
        _hasSave = false;
      });
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GameScreen(
          recordStore: _recordStore,
          saveStore: _saveStore,
          resumeGame: game,
        ),
      ),
    );
    if (mounted) {
      setState(() {
        _records = _recordStore.load();
        _hasSave = _saveStore.hasSave;
      });
    }
  }

  void _showRecords() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Рекорды'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _RecordRow(
                label: 'Рекорд по убийствам',
                value: '${_records.bestKills}',
              ),
              _RecordRow(
                label: 'Максимальный уровень',
                value: '${_records.bestLevel}',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Закрыть'),
            ),
          ],
        );
      },
    );
  }

  void _showRules() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Правила игры'),
          content: const SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Цель',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(height: 6),
                Text(
                  'Уничтожь всех врагов на уровне — и начнётся следующий, '
                  'с новым лабиринтом. Уровни бесконечные, твой рекорд — '
                  'как далеко ты забрался.',
                ),
                SizedBox(height: 14),
                Text(
                  'Жизни',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(height: 6),
                Text(
                  'У тебя 6 жизней. Каждое попадание вражеской стрелки '
                  'отнимает 1. Аптечка (белая коробочка с крестом) '
                  'восстанавливает 1 жизнь, если ты не на полном здоровье. '
                  'За каждый пройденный уровень дают +1 жизнь.',
                ),
                SizedBox(height: 14),
                Text(
                  'Управление',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(height: 6),
                Text(
                  'W A S D или стрелки — движение по клеткам.\n'
                  'Space — выстрел из пушки (5 зарядов, восстанавливаются).\n'
                  'Q — луч: жжёт коридор по 1 урону в секунду. '
                  'Заряд даётся за каждые 3 убийства.\n'
                  'F — тройной залп: 3 снаряда вперёд. Открывается после '
                  '5 убийств, 5 зарядов переносятся между уровнями.\n'
                  'Esc — пауза и выход в меню.\n'
                  'Геймпад Xbox: стик или крестовина — движение, '
                  'A — огонь, B — луч, X — тройной, Start — пауза.\n'
                  'На телефоне — экранные кнопки: крестовина слева, '
                  'действия справа.',
                ),
                SizedBox(height: 14),
                Text(
                  'Полезно знать',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(height: 6),
                Text(
                  'Кирпичные стены (коричневые) ломаются выстрелами, '
                  'синие — неразрушимые.\n'
                  'У бронированных врагов есть голубой щит: первое '
                  'попадание снимает щит, второе — убивает.\n'
                  'Твой снаряд и вражеский при встрече взрываются — '
                  'так можно сбивать чужие выстрелы.\n'
                  'Мины (колючие кружки) наносят 1 урон тому, кто наедет '
                  'на их клетку, — и тебе, и врагам. Их всегда можно объехать.\n'
                  'Кусты не мешают движению, но в них тебя и врагов '
                  'плохо видно.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Понятно'),
            ),
          ],
        );
      },
    );
  }

  void _exitApp() {
    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      SystemNavigator.pop();
    } else {
      exit(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1116),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 140,
              height: 140,
            ),
            const SizedBox(height: 12),
            const Text(
              'Танчики',
              style: TextStyle(fontSize: 52, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Танковый лабиринт',
              style: TextStyle(color: Colors.white54, fontSize: 16),
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: 220,
              child: FilledButton(
                onPressed: _play,
                child: const Text('Играть'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 220,
              child: OutlinedButton(
                onPressed: _hasSave ? _continueGame : null,
                child: const Text('Продолжить игру'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 220,
              child: OutlinedButton(
                onPressed: _showRecords,
                child: const Text('Рекорды'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 220,
              child: OutlinedButton(
                onPressed: _showRules,
                child: const Text('Правила игры'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 220,
              child: OutlinedButton(
                onPressed: _exitApp,
                child: const Text('Выйти из игры'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 24),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, this.recordStore, this.saveStore, this.resumeGame});

  final RecordStore? recordStore;
  final SaveStore? saveStore;
  final Game? resumeGame;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final FocusNode _focusNode = FocusNode();
  Game _game = Game();
  late final RecordStore _recordStore =
      widget.recordStore ?? RecordStore();
  late final SaveStore _saveStore = widget.saveStore ?? SaveStore();
  late Records _records = _recordStore.load();
  late final Ticker _ticker;
  final Gamepad _gamepad = Gamepad();
  Direction? _padDirection;
  bool _padFire = false;
  bool _padBeam = false;
  bool _padTriple = false;
  bool _padPause = false;
  Duration _lastElapsed = Duration.zero;
  int _lastRevision = 0;
  bool _wasAnimating = false;
  bool _saveCleared = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final resumeGame = widget.resumeGame;
    if (resumeGame != null) {
      _game = resumeGame;
      _game.togglePause();
    }
    _lastRevision = _game.revision;
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _gamepad.dispose();
    _ticker.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _updateGamepad() {
    if (!_gamepad.available) {
      return;
    }
    final state = _gamepad.poll();
    if (!state.connected) {
      if (_padDirection != null) {
        _game.releaseDirection(_padDirection!);
        _padDirection = null;
      }
      if (_padFire) {
        _game.setShooting(false);
        _padFire = false;
      }
      _padBeam = false;
      _padTriple = false;
      _padPause = false;
      return;
    }

    if (state.direction != _padDirection) {
      final previous = _padDirection;
      if (previous != null) {
        _game.releaseDirection(previous);
      }
      _padDirection = state.direction;
      if (state.direction != null) {
        _game.pressDirection(state.direction!);
      }
    }
    if (state.fire != _padFire) {
      _padFire = state.fire;
      _game.setShooting(state.fire);
    }
    if (state.beam && !_padBeam) {
      _game.useAbility();
    }
    _padBeam = state.beam;
    if (state.triple && !_padTriple) {
      _game.useTripleShot();
    }
    _padTriple = state.triple;
    if (state.pause && !_padPause) {
      _game.togglePause();
    }
    _padPause = state.pause;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      if (_game.status == GameStatus.playing && !_game.awaitingNextLevel) {
        _saveStore.saveGame(_game);
      }
    }
  }

  void _syncRecords() {
    if (_game.kills <= _records.bestKills && _game.level <= _records.bestLevel) {
      return;
    }
    _records = _records.merge(_game.kills, _game.level);
    _recordStore.save(_records);
  }

  void _onTick(Duration elapsed) {
    final delta = elapsed - _lastElapsed;
    _lastElapsed = elapsed;
    _updateGamepad();
    _game.advance(delta);
    _syncRecords();
    if (_game.status == GameStatus.lost && !_saveCleared) {
      _saveCleared = true;
      _saveStore.clear();
    }
    final animating =
        (_game.isAnimating || _game.levelBannerVisible) && !_game.paused;
    if (_game.revision != _lastRevision || animating || _wasAnimating) {
      _wasAnimating = animating;
      setState(() {
        _lastRevision = _game.revision;
      });
    }
  }

  void _continueToNextLevel() {
    setState(() {
      _game.startNextLevel();
      _lastRevision = _game.revision;
    });
    _saveStore.saveGame(_game);
    _focusNode.requestFocus();
  }

  void _exitToMenu() {
    _saveStore.saveGame(_game);
    Navigator.of(context).maybePop();
  }

  void _restart() {
    setState(() {
      _game = Game();
      _lastRevision = _game.revision;
      _saveCleared = false;
    });
    _focusNode.requestFocus();
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (event is KeyDownEvent) {
        _game.togglePause();
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.space) {
      if (event is KeyDownEvent) {
        _game.setShooting(true);
      } else if (event is KeyUpEvent) {
        _game.setShooting(false);
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyQ ||
        event.physicalKey == PhysicalKeyboardKey.keyQ) {
      if (event is KeyDownEvent) {
        _game.useAbility();
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyF ||
        event.physicalKey == PhysicalKeyboardKey.keyF) {
      if (event is KeyDownEvent) {
        _game.useTripleShot();
      }
      return KeyEventResult.handled;
    }
    final direction = Direction.fromKey(event);
    if (direction == null) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent) {
      _game.pressDirection(direction);
    } else if (event is KeyUpEvent) {
      _game.releaseDirection(direction);
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final lost = _game.status == GameStatus.lost;
    final touchPlatform = defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    return Scaffold(
      backgroundColor: const Color(0xFF0E1116),
      body: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _onKeyEvent,
        onFocusChange: (hasFocus) {
          if (!hasFocus) {
            _game.clearInput();
          }
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _focusNode.requestFocus,
          child: Stack(
            children: [
              SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: touchPlatform ? 2 : 4,
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back),
                            tooltip: 'В меню',
                            iconSize: touchPlatform ? 20 : 24,
                            visualDensity: touchPlatform
                                ? VisualDensity.compact
                                : VisualDensity.standard,
                            onPressed: _exitToMenu,
                          ),
                          Expanded(
                            child: _Hud(
                              lives: _game.lives,
                              level: _game.level,
                              enemiesLeft: _game.enemies.length,
                              abilityCharges: _game.abilityCharges,
                              shotCharges: _game.shotCharges,
                              tripleAmmo: _game.tripleAmmo,
                              compact: touchPlatform,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: 15 / 13,
                          child: CustomPaint(painter: MazePainter(_game)),
                        ),
                      ),
                    ),
                    if (touchPlatform && !lost && !_game.awaitingNextLevel)
                      _TouchControls(game: _game)
                    else if (!touchPlatform) ...[
                      const SizedBox(height: 4),
                      const Text(
                        'WASD — движение, Space — выстрел, Q — луч',
                        style: TextStyle(color: Colors.white38, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                    ],
                  ],
                ),
              ),
              if (_game.levelBannerVisible)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Center(
                      child: Opacity(
                        opacity: _game.levelBannerOpacity,
                        child: Text(
                          'Уровень ${_game.level}',
                          style: TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.bold,
                            color: Colors.white.withValues(alpha: 0.85),
                            shadows: const [
                              Shadow(color: Colors.black, blurRadius: 12),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (_game.awaitingNextLevel)
                Positioned.fill(
                  child: ColoredBox(
                    color: const Color(0xE60E1116),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Уровень ${_game.level} пройден!',
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _RecordsTable(
                            kills: _game.kills,
                            level: _game.level,
                            bestKills: _records.bestKills,
                            bestLevel: _records.bestLevel,
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _continueToNextLevel,
                            child: const Text('Дальше'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (lost)
                Positioned.fill(
                  child: ColoredBox(
                    color: const Color(0xE60E1116),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Поражение',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Жизни закончились',
                            style: TextStyle(color: Colors.white54),
                          ),
                          const SizedBox(height: 16),
                          _RecordsTable(
                            kills: _game.kills,
                            level: _game.level,
                            bestKills: _records.bestKills,
                            bestLevel: _records.bestLevel,
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _restart,
                            child: const Text('Заново'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (_game.paused)
                Positioned.fill(
                  child: ColoredBox(
                    color: const Color(0x99000000),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Пауза',
                            style: TextStyle(
                              fontSize: 44,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: 220,
                            child: FilledButton(
                              onPressed: () {
                                _game.togglePause();
                                _focusNode.requestFocus();
                              },
                              child: const Text('Продолжить'),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: 220,
                            child: OutlinedButton(
                              onPressed: _exitToMenu,
                              child: const Text('Выйти в главное меню'),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Esc — продолжить',
                            style: TextStyle(color: Colors.white38),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hud extends StatelessWidget {
  const _Hud({
    required this.lives,
    required this.level,
    required this.enemiesLeft,
    required this.abilityCharges,
    required this.shotCharges,
    required this.tripleAmmo,
    required this.compact,
  });

  final int lives;
  final int level;
  final int enemiesLeft;
  final int abilityCharges;
  final int shotCharges;
  final int tripleAmmo;
  final bool compact;

  TextStyle _style(Color color) => TextStyle(
        color: color,
        fontWeight: FontWeight.bold,
        fontSize: compact ? 12 : 14,
      );

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('Жизни: $lives', style: _style(const Color(0xFFE53935))),
        const Spacer(),
        Text('Уровень: $level', style: _style(const Color(0xFFB0BEC5))),
        const Spacer(),
        Text(
          'Q · луч: $abilityCharges',
          style: _style(
            abilityCharges > 0 ? const Color(0xFF80DEEA) : Colors.white38,
          ),
        ),
        const Spacer(),
        if (tripleAmmo > 0) ...[
          Text(
            'F · тройной: $tripleAmmo',
            style: _style(const Color(0xFFFFB300)),
          ),
          const Spacer(),
        ],
        Text('Врагов: $enemiesLeft', style: _style(const Color(0xFFE53935))),
        const SizedBox(width: 10),
        _ShotCharges(count: shotCharges, compact: compact),
      ],
    );
  }
}

class _ShotCharges extends StatelessWidget {
  const _ShotCharges({required this.count, required this.compact});

  final int count;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 10.0 : 12.0;
    return Row(
      key: const Key('shotCharges'),
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < Game.maxShotCharges; i++)
          Container(
            width: size,
            height: size,
            margin: const EdgeInsets.only(left: 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < count
                  ? const Color(0xFF42A5F5)
                  : Colors.transparent,
              border: Border.all(
                color: const Color(0xFF42A5F5),
                width: 1.5,
              ),
            ),
          ),
      ],
    );
  }
}

class _RecordsTable extends StatelessWidget {
  const _RecordsTable({
    required this.kills,
    required this.level,
    required this.bestKills,
    required this.bestLevel,
  });

  final int kills;
  final int level;
  final int bestKills;
  final int bestLevel;

  @override
  Widget build(BuildContext context) {
    return Table(
      defaultColumnWidth: const IntrinsicColumnWidth(),
      children: [
        _row('Убито врагов за забег', '$kills'),
        _row('Достигнутый уровень', '$level'),
        _row('Рекорд по убийствам', '$bestKills'),
        _row('Рекорд по уровню', '$bestLevel'),
      ],
    );
  }

  TableRow _row(String label, String value) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Text(label, style: const TextStyle(color: Colors.white70)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

class _TouchControls extends StatelessWidget {
  const _TouchControls({required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PadButton(
                icon: Icons.keyboard_arrow_up,
                onPressed: () => game.pressDirection(Direction.up),
                onReleased: () => game.releaseDirection(Direction.up),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PadButton(
                    icon: Icons.keyboard_arrow_left,
                    onPressed: () => game.pressDirection(Direction.left),
                    onReleased: () => game.releaseDirection(Direction.left),
                  ),
                  const SizedBox(width: 38),
                  _PadButton(
                    icon: Icons.keyboard_arrow_right,
                    onPressed: () => game.pressDirection(Direction.right),
                    onReleased: () => game.releaseDirection(Direction.right),
                  ),
                ],
              ),
              _PadButton(
                icon: Icons.keyboard_arrow_down,
                onPressed: () => game.pressDirection(Direction.down),
                onReleased: () => game.releaseDirection(Direction.down),
              ),
            ],
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (game.tripleAmmo > 0) ...[
                _ActionButton(
                  label: 'Тройной',
                  color: const Color(0xFFFFB300),
                  onPressed: game.useTripleShot,
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  _ActionButton(
                    label: 'Луч',
                    color: const Color(0xFF80DEEA),
                    onPressed: game.useAbility,
                  ),
                  const SizedBox(width: 12),
                  _ActionButton(
                    label: 'Огонь',
                    color: const Color(0xFFE53935),
                    onPressed: () => game.setShooting(true),
                    onReleased: () => game.setShooting(false),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PadButton extends StatelessWidget {
  const _PadButton({
    required this.icon,
    required this.onPressed,
    required this.onReleased,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final VoidCallback onReleased;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => onPressed(),
      onTapUp: (_) => onReleased(),
      onTapCancel: onReleased,
      child: Container(
        width: 42,
        height: 42,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: const Color(0x660E1116),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0x88FFFFFF)),
        ),
        child: Icon(icon, color: Colors.white70, size: 26),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.color,
    required this.onPressed,
    this.onReleased,
  });

  final String label;
  final Color color;
  final VoidCallback onPressed;
  final VoidCallback? onReleased;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => onPressed(),
      onTapUp: onReleased == null ? null : (_) => onReleased!(),
      onTapCancel: onReleased,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.25),
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 2),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class MazePainter extends CustomPainter {
  const MazePainter(this.game);

  final Game game;

  static final Paint _floorPaint = Paint()..color = const Color(0xFF151A22);
  static final Paint _wallPaint = Paint()..color = const Color(0xFF3A4B63);
  static final Paint _wallEdgePaint = Paint()
    ..color = const Color(0xFF243146)
    ..style = PaintingStyle.stroke;
  static final Paint _brickPaint = Paint()..color = const Color(0xFF8A5A2B);
  static final Paint _brickEdgePaint = Paint()
    ..color = const Color(0xFF5C3A18)
    ..style = PaintingStyle.stroke;
  static final Paint _brickSeamPaint = Paint()
    ..color = const Color(0x66241508)
    ..style = PaintingStyle.stroke;
  static final Paint _medkitBoxPaint = Paint()..color = const Color(0xFFF5F5F5);
  static final Paint _medkitCrossPaint = Paint()..color = const Color(0xFF43A047);
  static final Paint _mineBodyPaint = Paint()..color = const Color(0xFF37474F);
  static final Paint _mineLightPaint = Paint()..color = const Color(0xFFE53935);
  static final Paint _bushDarkPaint = Paint()..color = const Color(0xFF2F5D36);
  static final Paint _bushLightPaint = Paint()..color = const Color(0xFF4E8A52);
  static final Paint _playerShotPaint = Paint()..color = const Color(0xFF42A5F5);
  static final Paint _ballHighlightPaint = Paint()
    ..color = const Color(0xCCFFFFFF);
  static final Paint _enemyShotPaint = Paint()..color = const Color(0xFFFF7043);
  static final Paint _shieldFillPaint = Paint()
    ..color = const Color(0x444FC3F7);
  static final Paint _shieldEdgePaint = Paint()
    ..color = const Color(0xFF81D4FA)
    ..style = PaintingStyle.stroke;
  static final _TankStyle _enemyTank = _TankStyle(
    tracks: Paint()..color = const Color(0xFF46505F),
    hull: Paint()..color = const Color(0xFFD32F2F),
    turret: Paint()..color = const Color(0xFFE53935),
    barrel: Paint()..color = const Color(0xFF8E1A1A),
  );
  static final _TankStyle _playerTank = _TankStyle(
    tracks: Paint()..color = const Color(0xFF2F4A6B),
    hull: Paint()..color = const Color(0xFF1E88E5),
    turret: Paint()..color = const Color(0xFF42A5F5),
    barrel: Paint()..color = const Color(0xFF1565C0),
  );
  static final Paint _outlinePaint = Paint()
    ..color = const Color(0xFF141414)
    ..style = PaintingStyle.stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rows = game.maze.length;
    final cols = game.maze.first.length;
    final cell = math.min(size.width / cols, size.height / rows);
    final originX = (size.width - cell * cols) / 2;
    final originY = (size.height - cell * rows) / 2;

    final mazeRect = Rect.fromLTWH(originX, originY, cell * cols, cell * rows);
    canvas.drawRRect(
      RRect.fromRectAndRadius(mazeRect, Radius.circular(cell * 0.3)),
      _floorPaint,
    );

    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        if (!game.isWall(row, col) || game.isDestroyed(row, col)) {
          continue;
        }
        final rect = Rect.fromLTWH(
          originX + col * cell,
          originY + row * cell,
          cell,
          cell,
        ).deflate(cell * 0.06);
        final rrect = RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.14));
        final breakable = game.isBreakable(row, col);
        canvas.drawRRect(rrect, breakable ? _brickPaint : _wallPaint);
        canvas.drawRRect(
          rrect,
          (breakable ? _brickEdgePaint : _wallEdgePaint)
            ..strokeWidth = cell * 0.05
            ..style = PaintingStyle.stroke,
        );
        if (breakable) {
          for (var i = 1; i <= 2; i++) {
            final y = rect.top + rect.height * i / 3;
            canvas.drawLine(
              Offset(rect.left + cell * 0.06, y),
              Offset(rect.right - cell * 0.06, y),
              _brickSeamPaint..strokeWidth = cell * 0.05,
            );
          }
        }
      }
    }

    for (final medkit in game.medkits) {
      _drawMedkit(
        canvas,
        Offset(
          originX + (medkit.col + 0.5) * cell,
          originY + (medkit.row + 0.5) * cell,
        ),
        cell,
      );
    }

    for (final mine in game.mines) {
      _drawMine(
        canvas,
        Offset(
          originX + (mine.col + 0.5) * cell,
          originY + (mine.row + 0.5) * cell,
        ),
        cell,
      );
    }

    for (final projectile in game.projectiles) {
      _drawBall(
        canvas,
        Offset(
          originX + (projectile.col + 0.5) * cell,
          originY + (projectile.row + 0.5) * cell,
        ),
        cell,
        projectile.owner == ProjectileOwner.player
            ? _playerShotPaint
            : _enemyShotPaint,
      );
    }

    for (final enemy in game.enemies) {
      final t = game.enemyMoveProgress(enemy);
      final center = Offset(
        originX +
            (_lerp(enemy.fromCol.toDouble(), enemy.col.toDouble(), t) + 0.5) *
                cell,
        originY +
            (_lerp(enemy.fromRow.toDouble(), enemy.row.toDouble(), t) + 0.5) *
                cell,
      );
      if (enemy.shielded) {
        _drawShield(canvas, center, cell);
      }
      _drawTank(
        canvas,
        center,
        cell,
        _lerpAngle(enemy.fromFacing.angle, enemy.facing.angle, t),
        _enemyTank,
      );
    }

    final playerT = game.playerMoveProgress;
    _drawTank(
      canvas,
      Offset(
        originX +
            (_lerp(
                      game.playerFromCol.toDouble(),
                      game.playerCol.toDouble(),
                      playerT,
                    ) +
                    0.5) *
                cell,
        originY +
            (_lerp(
                      game.playerFromRow.toDouble(),
                      game.playerRow.toDouble(),
                      playerT,
                    ) +
                    0.5) *
                cell,
      ),
      cell,
      _lerpAngle(
        game.playerFromFacing.angle,
        game.playerFacing.angle,
        playerT,
      ),
      _playerTank,
      opacity: game.playerInvulnerable ? 0.3 : 1,
      scale: 1.08,
    );

    for (final bush in game.bushes) {
      _drawBush(
        canvas,
        Offset(
          originX + (bush.col + 0.5) * cell,
          originY + (bush.row + 0.5) * cell,
        ),
        cell,
      );
    }

    final beam = game.beam;
    if (beam != null) {
      final progress = game.beamProgress;
      final alpha = progress < 0.8 ? 1.0 : (1 - progress) / 0.2;
      _drawBeam(canvas, originX, originY, cell, beam, alpha);
    }

    for (final explosion in game.explosions) {
      _drawExplosion(
        canvas,
        Offset(
          originX + (explosion.col + 0.5) * cell,
          originY + (explosion.row + 0.5) * cell,
        ),
        cell,
        game.explosionProgress(explosion),
      );
    }
  }

  void _drawExplosion(
    Canvas canvas,
    Offset center,
    double cell,
    double progress,
  ) {
    final alpha = (1 - progress).clamp(0.0, 1.0);
    final radius = cell * (0.15 + 0.5 * progress);
    final glow = Paint()
      ..color = const Color(0xFFFFB74D).withValues(alpha: 0.6 * alpha);
    final core = Paint()
      ..color = const Color(0xFFFFF176).withValues(alpha: alpha);
    canvas.drawCircle(center, radius, glow);
    canvas.drawCircle(center, radius * 0.55, core);
  }

  void _drawBeam(
    Canvas canvas,
    double originX,
    double originY,
    double cell,
    Beam beam,
    double alpha,
  ) {
    final cols = game.maze.first.length;
    final start = Offset(
      originX + (beam.col + 0.5) * cell,
      originY + (beam.row + 0.5) * cell,
    );
    var end = start;
    if (beam.cells.isNotEmpty) {
      final last = beam.cells.last;
      end = Offset(
        originX + (last % cols + 0.5) * cell,
        originY + (last ~/ cols + 0.5) * cell,
      );
    }
    final glow = Paint()
      ..color = const Color(0xFF80DEEA).withValues(alpha: 0.35 * alpha)
      ..strokeWidth = cell * 0.62
      ..strokeCap = StrokeCap.round;
    final core = Paint()
      ..color = Colors.white.withValues(alpha: alpha)
      ..strokeWidth = cell * 0.22
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(start, end, glow);
    canvas.drawLine(start, end, core);
  }

  static double _lerp(double from, double to, double t) =>
      from + (to - from) * t;

  static double _lerpAngle(double from, double to, double t) {
    var delta = (to - from) % (2 * math.pi);
    if (delta > math.pi) {
      delta -= 2 * math.pi;
    }
    return from + delta * t;
  }

  void _drawTank(
    Canvas canvas,
    Offset center,
    double cell,
    double angle,
    _TankStyle style, {
    double opacity = 1,
    double scale = 1,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    canvas.scale(cell * scale);

    final leftTrack = RRect.fromRectAndRadius(
      const Rect.fromLTRB(-0.44, -0.36, -0.29, 0.36),
      const Radius.circular(0.07),
    );
    final rightTrack = RRect.fromRectAndRadius(
      const Rect.fromLTRB(0.29, -0.36, 0.44, 0.36),
      const Radius.circular(0.07),
    );
    canvas.drawRRect(leftTrack, _fade(style.tracks, opacity));
    canvas.drawRRect(rightTrack, _fade(style.tracks, opacity));

    final hull = RRect.fromRectAndRadius(
      const Rect.fromLTRB(-0.31, -0.34, 0.31, 0.34),
      const Radius.circular(0.09),
    );
    canvas.drawRRect(hull, _fade(style.hull, opacity));
    canvas.drawRRect(
      hull,
      _outlinePaint..strokeWidth = 0.05,
    );

    final barrel = RRect.fromRectAndRadius(
      const Rect.fromLTRB(-0.06, -0.58, 0.06, 0),
      const Radius.circular(0.05),
    );
    canvas.drawRRect(barrel, _fade(style.barrel, opacity));
    canvas.drawRRect(
      barrel,
      _outlinePaint..strokeWidth = 0.05,
    );

    canvas.drawCircle(Offset.zero, 0.18, _fade(style.turret, opacity));
    canvas.drawCircle(
      Offset.zero,
      0.18,
      _outlinePaint..strokeWidth = 0.05,
    );

    canvas.restore();
  }

  static Paint _fade(Paint base, double opacity) =>
      Paint()..color = base.color.withValues(alpha: opacity);

  void _drawShield(Canvas canvas, Offset center, double cell) {
    canvas.drawCircle(center, cell * 0.56, _shieldFillPaint);
    canvas.drawCircle(
      center,
      cell * 0.56,
      _shieldEdgePaint..strokeWidth = cell * 0.06,
    );
  }

  void _drawMine(Canvas canvas, Offset center, double cell) {
    final radius = cell * 0.34;
    final spikes = Paint()
      ..color = const Color(0xFF90A4AE)
      ..strokeWidth = cell * 0.05
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      final from = Offset(
        center.dx + math.cos(angle) * radius * 0.6,
        center.dy + math.sin(angle) * radius * 0.6,
      );
      final to = Offset(
        center.dx + math.cos(angle) * radius * 1.15,
        center.dy + math.sin(angle) * radius * 1.15,
      );
      canvas.drawLine(from, to, spikes);
    }
    canvas.drawCircle(center, radius, _mineBodyPaint);
    canvas.drawCircle(
      center,
      radius,
      _outlinePaint..strokeWidth = cell * 0.05,
    );
    canvas.drawCircle(center, radius * 0.35, _mineLightPaint);
  }

  void _drawBush(Canvas canvas, Offset center, double cell) {
    final radius = cell * 0.24;
    final blobs = <Offset>[
      Offset.zero,
      Offset(-cell * 0.2, -cell * 0.1),
      Offset(cell * 0.2, -cell * 0.12),
      Offset(-cell * 0.14, cell * 0.18),
      Offset(cell * 0.16, cell * 0.16),
      Offset(0, -cell * 0.26),
      Offset(-cell * 0.26, cell * 0.02),
      Offset(cell * 0.26, cell * 0.02),
      Offset(0, cell * 0.26),
    ];
    final bounds = Rect.fromLTWH(
      center.dx - cell * 0.5,
      center.dy - cell * 0.5,
      cell,
      cell,
    );
    canvas.saveLayer(bounds, Paint());
    final base = RRect.fromRectAndRadius(
      bounds.deflate(cell * 0.03),
      Radius.circular(cell * 0.14),
    );
    canvas.drawRRect(base, _bushDarkPaint);
    for (final blob in blobs) {
      canvas.drawCircle(center + blob, radius, _bushLightPaint);
    }
    for (final blob in blobs) {
      canvas.drawCircle(center + blob, radius * 0.35, _bushDarkPaint);
    }
    final holePaint = Paint()..blendMode = BlendMode.clear;
    canvas.drawCircle(center, cell * 0.035, holePaint);
    canvas.restore();
  }

  void _drawMedkit(Canvas canvas, Offset center, double cell) {    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(cell * 0.85);

    final box = RRect.fromRectAndRadius(
      const Rect.fromLTRB(-0.5, -0.42, 0.5, 0.42),
      const Radius.circular(0.12),
    );
    canvas.drawRRect(box, _medkitBoxPaint);
    canvas.drawRRect(
      box,
      _outlinePaint..strokeWidth = 0.08,
    );

    final vertical = RRect.fromRectAndRadius(
      const Rect.fromLTRB(-0.11, -0.26, 0.11, 0.26),
      const Radius.circular(0.03),
    );
    final horizontal = RRect.fromRectAndRadius(
      const Rect.fromLTRB(-0.26, -0.11, 0.26, 0.11),
      const Radius.circular(0.03),
    );
    canvas.drawRRect(vertical, _medkitCrossPaint);
    canvas.drawRRect(horizontal, _medkitCrossPaint);

    canvas.restore();
  }

  void _drawBall(Canvas canvas, Offset center, double cell, Paint fill) {
    final radius = cell * 0.28;
    canvas.drawCircle(center, radius, fill);
    canvas.drawCircle(
      center,
      radius,
      _outlinePaint..strokeWidth = cell * 0.05,
    );
    canvas.drawCircle(
      center.translate(-radius * 0.35, -radius * 0.35),
      radius * 0.35,
      _ballHighlightPaint,
    );
  }

  @override
  bool shouldRepaint(covariant MazePainter oldDelegate) => true;
}

class _TankStyle {
  const _TankStyle({
    required this.tracks,
    required this.hull,
    required this.turret,
    required this.barrel,
  });

  final Paint tracks;
  final Paint hull;
  final Paint turret;
  final Paint barrel;
}
