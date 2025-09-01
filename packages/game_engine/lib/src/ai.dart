// packages/game_engine/lib/src/ai.dart
import 'dart:math';
import 'game.dart';

final _rng = Random();

/// Pick a random legal move.
/// Assumes caller won't ask when the game is already over.
List<int> randomMove(Game g) {
  final moves = g.availableEdges();
  return moves[_rng.nextInt(moves.length)];
}

/// 1-ply probe: after we play `m`, can the opponent score immediately?
/// We simulate our move, then check if *any* opponent reply increases their score.
/// Useful as a safety filter for greedy heuristics.
bool givesBoxToOpponent(Game g, List<int> m) {
  final sim = g.clone()..playEdge(m[0], m[1], m[2], m[3]);

  final opp = sim.currentPlayer;               // who moves after our test move
  final before = sim.scores[opp]!;
  for (final r in sim.availableEdges()) {
    final sim2 = sim.clone()..playEdge(r[0], r[1], r[2], r[3]);
    if (sim2.scores[opp]! > before) return true; // opponent gets at least 1 box
  }
  return false;
}

/// 1-ply heuristic:
/// Try to avoid moves that hand the opponent a box next turn;
/// if there are no safe moves, pick from all moves.
List<int> heuristic1Move(Game g) {
  final all = g.availableEdges();
  final safe = all.where((m) => !givesBoxToOpponent(g, m)).toList();
  final pool = safe.isNotEmpty ? safe : all;   // fallback when everything is risky
  return pool[_rng.nextInt(pool.length)];
}

/// 2-ply “deep” heuristic (minimax-ish, but shallow):
///   score = (my immediate gain) − (opponent’s best immediate gain)
/// This biases against moves that allow a big counter (e.g., opening a chain).
/// Notes:
/// - Assumes 2 players (me=0/1, you=1−me).
/// - Tie-breaks randomly to avoid deterministic patterns.
/// - This model doesn’t explicitly detect chains/double-crosses; it proxies via
///   “opponent best immediate gain”. If you want stronger chain awareness,
///   add structure (parity/chain counting) on top.
List<int> deep2Move(Game g) {
  final me = g.currentPlayerIndex;         // whose turn is it now?
  final you = 1 - me;                      // two-player assumption
  final baseMe  = g.scores[g.players[me]]!;
  final baseYou = g.scores[g.players[you]]!;

  int bestScore = -0x7FFFFFFF;
  List<List<int>> bestMoves = [];

  for (final m in g.availableEdges()) {
    // My move.
    final sim1 = g.clone()..playEdge(m[0], m[1], m[2], m[3]);
    final meGain = sim1.scores[sim1.players[me]]! - baseMe;

    // Opponent’s best immediate reply (worst for me).
    int worstYouGain = 0;
    for (final r in sim1.availableEdges()) {
      final sim2 = sim1.clone()..playEdge(r[0], r[1], r[2], r[3]);
      final youGain = sim2.scores[sim2.players[you]]! - baseYou;
      if (youGain > worstYouGain) worstYouGain = youGain;
    }

    final val = meGain - worstYouGain;

    if (val > bestScore) {
      bestScore = val;
      bestMoves = [m];
    } else if (val == bestScore) {
      bestMoves.add(m); // keep all ties; randomize below
    }
  }

  // Break ties randomly so play isn’t trivially predictable.
  return bestMoves[_rng.nextInt(bestMoves.length)];
}
