// packages/game_engine/lib/src/ai.dart
import 'dart:math';
import 'game.dart';

final _rng = Random();

/// Returns a random legal move.
List<int> randomMove(Game g) {
  final moves = g.availableEdges();
  return moves[_rng.nextInt(moves.length)];
}

/// 1‑ply helper: does playing m immediately allow opponent to score?
bool givesBoxToOpponent(Game g, List<int> m) {
  final sim = g.clone();
  sim.playEdge(m[0], m[1], m[2], m[3]);

  final opp = sim.currentPlayer;
  final before = sim.scores[opp]!;
  for (final r in sim.availableEdges()) {
    final sim2 = sim.clone();
    sim2.playEdge(r[0], r[1], r[2], r[3]);
    if (sim2.scores[opp]! > before) return true;
  }
  return false;
}

/// 1‑ply heuristic: avoid moves that hand the opponent a box next turn.
List<int> heuristic1Move(Game g) {
  final all = g.availableEdges();
  final safe = all.where((m) => !givesBoxToOpponent(g, m)).toList();
  final pool = safe.isNotEmpty ? safe : all;
  return pool[_rng.nextInt(pool.length)];
}

/// 2‑ply deep heuristic (minimax-ish):
///   val = (my immediate gain) - (opponent best immediate gain)
List<int> deep2Move(Game g) {
  final me = g.currentPlayerIndex;       // who am I right now?
  final you = 1 - me;                    // the other player (supports 2-player game)
  final baseMe  = g.scores[g.players[me]]!;
  final baseYou = g.scores[g.players[you]]!;

  int bestScore = -0x7FFFFFFF;
  List<List<int>> bestMoves = [];

  for (final m in g.availableEdges()) {
    final sim1 = g.clone();
    sim1.playEdge(m[0], m[1], m[2], m[3]);
    final meGain = sim1.scores[sim1.players[me]]! - baseMe;

    int worstYouGain = 0;
    for (final r in sim1.availableEdges()) {
      final sim2 = sim1.clone();
      sim2.playEdge(r[0], r[1], r[2], r[3]);
      final youGain = sim2.scores[sim2.players[you]]! - baseYou;
      if (youGain > worstYouGain) worstYouGain = youGain;
    }

    final val = meGain - worstYouGain;
    if (val > bestScore) {
      bestScore = val;
      bestMoves = [m];
    } else if (val == bestScore) {
      bestMoves.add(m);
    }
  }

  return bestMoves[_rng.nextInt(bestMoves.length)];
}
