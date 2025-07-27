// lib/game_page.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:game_engine/game_engine.dart';
import 'widgets/game_board.dart';

enum GameMode {
  twoPlayer,
  singlePlayerRandom,
  singlePlayerHeuristic,   // 1-ply lookahead
  singlePlayerHeuristic2,  // 2-ply lookahead
  online,
}

class GamePage extends StatefulWidget {
  final int gridSize;
  final GameMode mode;
  final List<String> playerNames;
  final String? roomId;
  final bool isOnlineHost;

  const GamePage({
    Key? key,
    required this.gridSize,
    required this.mode,
    required this.playerNames,
    this.roomId,
    this.isOnlineHost = false,
  }) : super(key: key);

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late Game game;
  final _rand = Random();
  bool _isAiThinking = false;
  DatabaseReference? _movesRef;
  Stream<DatabaseEvent>? _moveStream;

  @override
  void initState() {
    super.initState();
    _newGame();
    if (widget.mode == GameMode.online) _setupOnline();
  }

  void _newGame() {
    final numPlayers = widget.mode == GameMode.twoPlayer
        ? widget.playerNames.length
        : 2;
    game = Game(widget.gridSize, numPlayers: numPlayers);
    _isAiThinking = false;
    setState(() {});
    debugPrint('[NewGame] mode=${widget.mode}, currentPlayer=${game.currentPlayerIndex}');
    // If AI starts, kick it off:
    if (game.currentPlayerIndex == 1) {
      switch (widget.mode) {
        case GameMode.singlePlayerRandom:
          _runRandomAi();
          break;
        case GameMode.singlePlayerHeuristic:
          _runHeuristicAi();
          break;
        case GameMode.singlePlayerHeuristic2:
          _runDeepHeuristicAi();
          break;
        default:
          break;
      }
    }
  }

  void _setupOnline() {
    final room = widget.roomId!;
    _movesRef = FirebaseDatabase.instance.ref('rooms/$room/moves');
    _moveStream = _movesRef!.onChildAdded;
    _moveStream!.listen((e) {
      final data = Map<String, dynamic>.from(e.snapshot.value as Map);
      game.playEdge(data['x1'], data['y1'], data['x2'], data['y2']);
      setState(() {});
      if (game.currentPlayerIndex == 1) _runOnlineAi();
    });
  }

  // void _sendOnlineMove(int x1, int y1, int x2, int y2) {
  //   _movesRef!.push().set({
  //     'x1': x1,
  //     'y1': y1,
  //     'x2': x2,
  //     'y2': y2,
  //     'host': widget.isOnlineHost,
  //   });
  // }

  // —————————————————————————
  // 1-ply Heuristic helper
  bool _givesBoxToOpponent(List<int> m) {
    final sim = game.clone();
    sim.playEdge(m[0], m[1], m[2], m[3]);
    final opp = sim.currentPlayer;
    final before = sim.scores[opp]!;
    for (var r in sim.availableEdges()) {
      final sim2 = sim.clone();
      sim2.playEdge(r[0], r[1], r[2], r[3]);
      if (sim2.scores[opp]! > before) return true;
    }
    return false;
  }

  // —————————————————————————
  // RANDOM AI
  void _runRandomAi() {
    if (game.isOver || _isAiThinking) return;
    _isAiThinking = true;
    final moves = game.availableEdges();
    if (moves.isEmpty) return;
    final c = moves[_rand.nextInt(moves.length)];
    game.playEdge(c[0], c[1], c[2], c[3]);
    setState(() {});
    _isAiThinking = false;
    if (game.currentPlayerIndex == 1 && !game.isOver) _runRandomAi();
    if (game.isOver) _showGameOverDialog();
  }

  // —————————————————————————
  // 1-ply Heuristic AI
  void _runHeuristicAi() {
    if (game.isOver || _isAiThinking) return;
    _isAiThinking = true;
    final all = game.availableEdges();
    final safe = all.where((m) => !_givesBoxToOpponent(m)).toList();
    final pool = safe.isNotEmpty ? safe : all;
    final choice = pool[_rand.nextInt(pool.length)];
    game.playEdge(choice[0], choice[1], choice[2], choice[3]);
    setState(() {});
    _isAiThinking = false;
    if (game.currentPlayerIndex == 1 && !game.isOver) _runHeuristicAi();
    if (game.isOver) _showGameOverDialog();
  }

  // —————————————————————————
  // 2-ply Deep Heuristic AI
  void _runDeepHeuristicAi() {
    if (game.isOver || _isAiThinking) return;
    _isAiThinking = true;
    final moves = game.availableEdges();
    if (moves.isEmpty) {
      _isAiThinking = false;
      return;
    }

    // Baseline scores
    final baseHuman = game.scores[game.players[0]]!;
    final baseAi    = game.scores[game.players[1]]!;

    int bestScore = -999999;
    List<List<int>> bestMoves = [];

    for (var m in moves) {
      final sim1 = game.clone();
      sim1.playEdge(m[0], m[1], m[2], m[3]);
      final aiGain = sim1.scores[game.players[1]]! - baseAi;

      int worstHumanGain = 0;
      for (var r in sim1.availableEdges()) {
        final sim2 = sim1.clone();
        sim2.playEdge(r[0], r[1], r[2], r[3]);
        final humanGain = sim2.scores[game.players[0]]! - baseHuman;
        worstHumanGain = max(worstHumanGain, humanGain);
      }

      final val = aiGain - worstHumanGain;

      if (val > bestScore) {
        bestScore = val;
        bestMoves = [m];
      } else if (val == bestScore) {
        bestMoves.add(m);
      }
    }

    // Pick randomly among the best‐scoring moves
    final choice = bestMoves[_rand.nextInt(bestMoves.length)];
    game.playEdge(choice[0], choice[1], choice[2], choice[3]);

    setState(() {});
    _isAiThinking = false;

    // If AI gets another turn, recurse
    if (game.currentPlayerIndex == 1 && !game.isOver) {
      _runDeepHeuristicAi();
    } else if (game.isOver) {
      _showGameOverDialog();
    }
  }


  // —————————————————————————
  // (stub) for online moves
  void _runOnlineAi() => null;

  // —————————————————————————
  // Handle taps
  void _onEdgeTap(int x1, int y1, int x2, int y2) {
    // Only allow human (player0) on these modes
    if (widget.mode != GameMode.twoPlayer &&
        game.currentPlayerIndex != 0) return;

    if (!game.playEdge(x1, y1, x2, y2)) return;
    setState(() {});

    // Trigger next turn
    if (game.isOver) {
      _showGameOverDialog();
    } else if (game.currentPlayerIndex == 1) {
      switch (widget.mode) {
        case GameMode.singlePlayerRandom:
          _runRandomAi();
          break;
        case GameMode.singlePlayerHeuristic:
          _runHeuristicAi();
          break;
        case GameMode.singlePlayerHeuristic2:
          _runDeepHeuristicAi();
          break;
        default:
          break;
      }
    }
  }

  void _showGameOverDialog() {
    final s = game.scores;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Game Over'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < widget.playerNames.length; i++)
              Text('${widget.playerNames[i]}: ${s[game.players[i]] ?? 0}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _newGame();
            },
            child: const Text('Play Again'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = game.scores;
    final names = widget.playerNames;
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.gridSize}×${widget.gridSize} Dots & Boxes'),
        leading: BackButton(),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _newGame)],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              [
                for (var i = 0; i < names.length; i++)
                  '${names[i]}: ${s[game.players[i]] ?? 0}',
                'Turn: ${names[game.players.indexOf(game.currentPlayer)]}'
              ].join('   '),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Expanded(
            child: Center(
              child: GameBoard(game: game, onEdgeTap: _onEdgeTap),
            ),
          ),
        ],
      ),
    );
  }
}
