import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:game_engine/game_engine.dart';
import 'widgets/game_board.dart';

/// Local/online match screen.
/// Orchestrates engine state, optional Firebase move sync, and simple AI agents.
/// Assumes 2 players for online; local can show 2–4 names but engine here
/// uses two-player modes for human vs AI.
enum GameMode {
  twoPlayer,
  singlePlayerRandom,
  singlePlayerHeuristic,
  singlePlayerHeuristic2,
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

  // Firebase wires for online mode.
  DatabaseReference? _movesRef;
  late Stream<DatabaseEvent> _moveStream;

  // Set while applying a remote event to avoid echo/UX glitches.
  bool _isApplyingRemote = false;

  final _rand = Random();
  bool _isAiThinking = false;

  // Host is player 0, guest is player 1. Keep this aligned with lobby.
  int get _myPlayerIndex => widget.isOnlineHost ? 0 : 1;

  @override
  void initState() {
    super.initState();

    final numPlayers =
        widget.mode == GameMode.online ? 2 : widget.playerNames.length;
    game = Game(widget.gridSize, numPlayers: numPlayers);

    if (widget.mode == GameMode.online) {
      // Online: subscribe to room move stream.
      _movesRef = FirebaseDatabase.instance.ref('rooms/${widget.roomId}/moves');
      _moveStream = _movesRef!.onChildAdded;
      _moveStream.listen(_onRemoteMove);
      // To Do: store the subscription and cancel in dispose() to avoid leaks.
    } else if (game.currentPlayerIndex == 1) {
      // Local single-player: AI starts if engine says player 1 to move.
      _runAiForMode();
    }
  }

  // Apply a move coming from Firebase.
  // We set the engine's currentPlayer to whoever *sent* the move (playerIndex),
  // then let engine.playEdge() enforce extra-turn rules and scoring.
  void _onRemoteMove(DatabaseEvent e) {
    final data = Map<String, dynamic>.from(e.snapshot.value as Map);
    final x1 = data['x1'] as int;
    final y1 = data['y1'] as int;
    final x2 = data['x2'] as int;
    final y2 = data['y2'] as int;
    final pi = data['playerIndex'] as int;

    // Trust the stream for "who just moved".
    game.currentPlayerIndex = pi;

    _isApplyingRemote = true;
    game.playEdge(x1, y1, x2, y2);
    _isApplyingRemote = false;

    setState(() {});
    if (game.isOver) _showGameOverDialog();
  }

  // Push a move to Firebase. We only send when it's our turn.
  void _sendRemoteMove(int x1, int y1, int x2, int y2) {
    _movesRef!.push().set({
      'x1': x1,
      'y1': y1,
      'x2': x2,
      'y2': y2,
      'playerIndex': _myPlayerIndex, // marks who just moved
    });
  }

  // Human tapped an edge on the board.
  void _onEdgeTap(int x1, int y1, int x2, int y2) {
    if (widget.mode == GameMode.online) {
      // Guard: only allow local send if it's my turn and we aren't replaying.
      if (game.currentPlayerIndex != _myPlayerIndex || _isApplyingRemote) return;
      _sendRemoteMove(x1, y1, x2, y2);
      return; // remote listeners (both sides) will apply via _onRemoteMove
    }

    // Local (human or hot-seat): apply directly.
    if (!game.playEdge(x1, y1, x2, y2)) return; // ignore illegal/duplicate
    setState(() {});

    // If AI's turn now (player 1 in this app), let it move.
    if (!game.isOver && game.currentPlayerIndex == 1) {
      _runAiForMode();
    }
    if (game.isOver) _showGameOverDialog();
  }

  // Entry point to pick the AI for the current mode.
  void _runAiForMode() {
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
        break; // no AI in twoPlayer/online
    }
  }

  // === Random AI ============================================================
  void _runRandomAi() {
    if (game.isOver || _isAiThinking) return;
    _isAiThinking = true;

    final moves = game.availableEdges();
    if (moves.isEmpty) {
      _isAiThinking = false;
      return;
    }

    final c = moves[_rand.nextInt(moves.length)];
    game.playEdge(c[0], c[1], c[2], c[3]);
    setState(() {});
    _isAiThinking = false;

    // Extra-turn rule: if AI still to move, keep going.
    if (game.currentPlayerIndex == 1 && !game.isOver) _runRandomAi();
    if (game.isOver) _showGameOverDialog();
  }

  // === Heuristic AI (one-ply safety) =======================================
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

  // Simulate: if we play m, can the opponent immediately score on their reply?
  // Returns true if at least one reply increases opponent's score.
  bool _givesBoxToOpponent(List<int> m) {
    final sim = game.clone()..playEdge(m[0], m[1], m[2], m[3]);

    final opp = sim.currentPlayerIndex; // who moves next after our move
    final before = sim.scores[sim.players[opp]]!;

    for (var r in sim.availableEdges()) {
      final sim2 = sim.clone()..playEdge(r[0], r[1], r[2], r[3]);
      if (sim2.scores[sim2.players[opp]]! > before) return true;
    }
    return false;
  }

  // === Deep Heuristic AI (two-ply with double-cross awareness) =============
  void _runDeepHeuristicAi() {
    if (game.isOver || _isAiThinking) return;
    _isAiThinking = true;

    final moves = game.availableEdges();
    if (moves.isEmpty) {
      _isAiThinking = false;
      return;
    }

    // In this app: player index 1 is the AI, 0 is the human.
    final myPlayer = game.players[1];
    final baseMy = game.scores[myPlayer]!;
    final oppPlayer = game.players[0];
    final baseOpp = game.scores[oppPlayer]!;

    int bestScore = -999999;
    List<List<int>> bestMoves = [];

    for (var m in moves) {
      // My move.
      final afterMyMove = game.clone()..playEdge(m[0], m[1], m[2], m[3]);
      final gainMy = afterMyMove.scores[myPlayer]! - baseMy;

      // Opponent's best counter (we track the *worst* for us).
      int worstOpponentGain = 0;

      for (var reply in afterMyMove.availableEdges()) {
        final afterReply = afterMyMove.clone()
          ..playEdge(reply[0], reply[1], reply[2], reply[3]);

        final gainOpp = afterReply.scores[oppPlayer]! - baseOpp;

        // "Double-cross" proxy: penalise replies that give opponent 2+ boxes.
        if (gainOpp >= 2) {
          worstOpponentGain = max(worstOpponentGain, gainOpp);
        }
      }

      final value = gainMy - worstOpponentGain;

      if (value > bestScore) {
        bestScore = value;
        bestMoves = [m];
      } else if (value == bestScore) {
        bestMoves.add(m);
      }
    }

    // Break ties randomly to avoid deterministic patterns.
    final move = bestMoves[_rand.nextInt(bestMoves.length)];
    game.playEdge(move[0], move[1], move[2], move[3]);
    setState(() {});
    _isAiThinking = false;

    // Extra-turn loop for chain harvests.
    if (game.currentPlayerIndex == 1 && !game.isOver) {
      _runDeepHeuristicAi();
    } else if (game.isOver) {
      _showGameOverDialog();
    }
  }

  void _showGameOverDialog() {
    final scores = game.scores;
    final names = widget.playerNames;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Game Over'),
        content: Text(
          names
              .asMap()
              .entries
              .map((e) => '${e.value}: ${scores[game.players[e.key]]}')
              .join('\n'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _resetGame();
            },
            child: const Text('Play Again'),
          ),
        ],
      ),
    );
  }

  void _resetGame() {
    final numPlayers =
        widget.mode == GameMode.online ? 2 : widget.playerNames.length;
    setState(() {
      game = Game(widget.gridSize, numPlayers: numPlayers);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scores = game.scores;
    final names = widget.playerNames;
    final turnName = names[game.currentPlayerIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.gridSize}×${widget.gridSize} Dots & Boxes'),
        leading: const BackButton(),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _resetGame),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              [
                for (var i = 0; i < names.length; i++)
                  '${names[i]}: ${scores[game.players[i]]}',
                'Turn: $turnName',
              ].join('   '),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: AspectRatio(
                  aspectRatio: 1.0,
                  child: GameBoard(
                    game: game,
                    onEdgeTap: _onEdgeTap,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// NOTES:
// - Online echo: We rely on _isApplyingRemote + "send only on my turn" to avoid
//   double-apply. Works because both sides consume the same stream.
// - Consider a tiny Edge value object instead of List<int> [x1,y1,x2,y2] for
//   readability and safer indexing.
// - If you expect large boards, you may want to yield to the UI between AI
//   chain loops to keep animations smooth.
// - Dispose: if you keep the StreamSubscription, cancel it in dispose().
