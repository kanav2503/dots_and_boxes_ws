// packages/game_engine/bin/benchmark_experiments.dart
//
// Batch runner for AI-vs-AI experiments.
// - Round-robins AIs across grid sizes
// - Logs scores + behaviour metrics (unsafe moves, turns, longest streak)
// - Times AI selection + engine.apply per move
// - Writes two CSVs: pairing-level summary and per-game details
//
// Run with `dart run packages/game_engine/bin/benchmark_experiments.dart`.
// NOTE: Per-game CSV can get large; tune gamesPerPair if needed.

import 'dart:io';
import 'dart:math';
import 'package:game_engine/game_engine.dart';

typedef MoveFn = List<int> Function(Game g, Random rng);

class Ai {
  final String name;
  final MoveFn fn;
  const Ai(this.name, this.fn);
}

void main() async {
  // --------------------------------------------------
  // CONFIG
  // --------------------------------------------------
  const grids = [4, 5, 6];   // add more sizes if you wish
  const gamesPerPair = 300;  // per pairing & order
  final rng = Random(42);    // seed for reproducibility

  // Plug in the move selectors you want to test.
  // NOTE: randomMove/heuristic1Move/deep2Move are provided by game_engine.
  final ais = <Ai>[
    Ai('Random',      (g, r) => randomMove(g)),
    Ai('Heuristic1',  (g, r) => heuristic1Move(g)),
    Ai('Deep2',       (g, r) => deep2Move(g)),
  ];

  // CSV buffers (kept in memory for simplicity).
  // TO DO: if files get huge, stream to disk instead of buffering.
  final summary = StringBuffer()
    ..writeln(
        'grid,games,p1_ai,p2_ai,'
        'p1_wins,p2_wins,ties,'
        'p1_avg,p2_avg,total_boxes,'
        'p1_unsafe_avg,p2_unsafe_avg,'
        'p1_turns_avg,p2_turns_avg,'
        'p1_streak_avg,p2_streak_avg,'
        // aggregated timing (ms)
        'p1_ai_mean_ms,p1_ai_p50_ms,p1_ai_p95_ms,'
        'p2_ai_mean_ms,p2_ai_p50_ms,p2_ai_p95_ms,'
        'p1_apply_mean_ms,p1_apply_p50_ms,p1_apply_p95_ms,'
        'p2_apply_mean_ms,p2_apply_p50_ms,p2_apply_p95_ms');

  // Optional per-game details (big).
  final perGame = StringBuffer()
    ..writeln(
        'grid,p1_ai,p2_ai,game_idx,'
        'p1_score,p2_score,'
        'p1_unsafe_moves,p2_unsafe_moves,'
        'p1_turns,p2_turns,'
        'p1_longest_streak,p2_longest_streak,'
        // per-game timing (ms)
        'p1_ai_mean_ms,p1_ai_p50_ms,p1_ai_p95_ms,'
        'p2_ai_mean_ms,p2_ai_p50_ms,p2_ai_p95_ms,'
        'p1_apply_mean_ms,p1_apply_p50_ms,p1_apply_p95_ms,'
        'p2_apply_mean_ms,p2_apply_p50_ms,p2_apply_p95_ms');

  for (final grid in grids) {
    final totalBoxes = grid * grid;

    for (var i = 0; i < ais.length; i++) {
      for (var j = 0; j < ais.length; j++) {
        final p1 = ais[i];
        final p2 = ais[j];

        // Aggregates for this pairing (over N games).
        int p1Wins = 0, p2Wins = 0, ties = 0;
        int sumP1 = 0, sumP2 = 0;

        int sumP1Unsafe = 0, sumP2Unsafe = 0;
        int sumP1Turns  = 0, sumP2Turns  = 0;
        int sumP1Streak = 0, sumP2Streak = 0;

        // Pairing-wide timing pools (µs) across all games.
        final pairingP1AiUs = <int>[];
        final pairingP2AiUs = <int>[];
        final pairingP1ApplyUs = <int>[];
        final pairingP2ApplyUs = <int>[];

        for (var gIdx = 0; gIdx < gamesPerPair; gIdx++) {
          final res = _playOneGame(
            grid: grid,
            p1: p1,
            p2: p2,
            rng: rng,
          );

          // Scores & wins.
          sumP1 += res.p1Score;
          sumP2 += res.p2Score;

          if (res.p1Score > res.p2Score) p1Wins++;
          else if (res.p2Score > res.p1Score) p2Wins++;
          else ties++;

          // Behavioural metrics.
          sumP1Unsafe += res.p1Unsafe;
          sumP2Unsafe += res.p2Unsafe;

          sumP1Turns  += res.p1Turns;
          sumP2Turns  += res.p2Turns;

          sumP1Streak += res.p1LongestStreak;
          sumP2Streak += res.p2LongestStreak;

          // Pairing timing pools.
          pairingP1AiUs.addAll(res.p1AiUs);
          pairingP2AiUs.addAll(res.p2AiUs);
          pairingP1ApplyUs.addAll(res.p1ApplyUs);
          pairingP2ApplyUs.addAll(res.p2ApplyUs);

          // Per-game timing stats (µs → ms for CSV).
          final p1AiMeanMs   = _usToMsStr(_meanUs(res.p1AiUs));
          final p1AiP50Ms    = _usToMsStr(_percentileUs(res.p1AiUs, 0.50));
          final p1AiP95Ms    = _usToMsStr(_percentileUs(res.p1AiUs, 0.95));

          final p2AiMeanMs   = _usToMsStr(_meanUs(res.p2AiUs));
          final p2AiP50Ms    = _usToMsStr(_percentileUs(res.p2AiUs, 0.50));
          final p2AiP95Ms    = _usToMsStr(_percentileUs(res.p2AiUs, 0.95));

          final p1ApplyMeanMs = _usToMsStr(_meanUs(res.p1ApplyUs));
          final p1ApplyP50Ms  = _usToMsStr(_percentileUs(res.p1ApplyUs, 0.50));
          final p1ApplyP95Ms  = _usToMsStr(_percentileUs(res.p1ApplyUs, 0.95));

          final p2ApplyMeanMs = _usToMsStr(_meanUs(res.p2ApplyUs));
          final p2ApplyP50Ms  = _usToMsStr(_percentileUs(res.p2ApplyUs, 0.50));
          final p2ApplyP95Ms  = _usToMsStr(_percentileUs(res.p2ApplyUs, 0.95));

          perGame.writeln(
              '$grid,${p1.name},${p2.name},$gIdx,'
              '${res.p1Score},${res.p2Score},'
              '${res.p1Unsafe},${res.p2Unsafe},'
              '${res.p1Turns},${res.p2Turns},'
              '${res.p1LongestStreak},${res.p2LongestStreak},'
              '$p1AiMeanMs,$p1AiP50Ms,$p1AiP95Ms,'
              '$p2AiMeanMs,$p2AiP50Ms,$p2AiP95Ms,'
              '$p1ApplyMeanMs,$p1ApplyP50Ms,$p1ApplyP95Ms,'
              '$p2ApplyMeanMs,$p2ApplyP50Ms,$p2ApplyP95Ms');
        }

        // Pairing-level aggregates for summary CSV.
        final p1Avg = sumP1 / gamesPerPair;
        final p2Avg = sumP2 / gamesPerPair;

        final p1UnsafeAvg = sumP1Unsafe / gamesPerPair;
        final p2UnsafeAvg = sumP2Unsafe / gamesPerPair;

        final p1TurnsAvg  = sumP1Turns  / gamesPerPair;
        final p2TurnsAvg  = sumP2Turns  / gamesPerPair;

        final p1StreakAvg = sumP1Streak / gamesPerPair;
        final p2StreakAvg = sumP2Streak / gamesPerPair;

        // Aggregated timing (µs → ms) over all moves in the pairing.
        final p1AiMeanMs    = _usToMsStr(_meanUs(pairingP1AiUs));
        final p1AiP50Ms     = _usToMsStr(_percentileUs(pairingP1AiUs, 0.50));
        final p1AiP95Ms     = _usToMsStr(_percentileUs(pairingP1AiUs, 0.95));

        final p2AiMeanMs    = _usToMsStr(_meanUs(pairingP2AiUs));
        final p2AiP50Ms     = _usToMsStr(_percentileUs(pairingP2AiUs, 0.50));
        final p2AiP95Ms     = _usToMsStr(_percentileUs(pairingP2AiUs, 0.95));

        final p1ApplyMeanMs = _usToMsStr(_meanUs(pairingP1ApplyUs));
        final p1ApplyP50Ms  = _usToMsStr(_percentileUs(pairingP1ApplyUs, 0.50));
        final p1ApplyP95Ms  = _usToMsStr(_percentileUs(pairingP1ApplyUs, 0.95));

        final p2ApplyMeanMs = _usToMsStr(_meanUs(pairingP2ApplyUs));
        final p2ApplyP50Ms  = _usToMsStr(_percentileUs(pairingP2ApplyUs, 0.50));
        final p2ApplyP95Ms  = _usToMsStr(_percentileUs(pairingP2ApplyUs, 0.95));

        summary.writeln(
            '$grid,$gamesPerPair,${p1.name},${p2.name},'
            '$p1Wins,$p2Wins,$ties,'
            '${p1Avg.toStringAsFixed(3)},${p2Avg.toStringAsFixed(3)},$totalBoxes,'
            '${p1UnsafeAvg.toStringAsFixed(3)},${p2UnsafeAvg.toStringAsFixed(3)},'
            '${p1TurnsAvg.toStringAsFixed(2)},${p2TurnsAvg.toStringAsFixed(2)},'
            '${p1StreakAvg.toStringAsFixed(2)},${p2StreakAvg.toStringAsFixed(2)},'
            '$p1AiMeanMs,$p1AiP50Ms,$p1AiP95Ms,'
            '$p2AiMeanMs,$p2AiP50Ms,$p2AiP95Ms,'
            '$p1ApplyMeanMs,$p1ApplyP50Ms,$p1ApplyP95Ms,'
            '$p2ApplyMeanMs,$p2ApplyP50Ms,$p2ApplyP95Ms');
      }
    }
  }

  // Write files.
  // TO DO: accept output dir via args; consider timestamped filenames.
  await File('benchmark2_summary.csv').writeAsString(summary.toString());
  await File('benchmark2_games.csv').writeAsString(perGame.toString());
  print('Saved benchmark2_summary.csv & benchmark2_games.csv');
}

// --------------------------------------------------
// STRUCTS & HELPERS
// --------------------------------------------------

class GameResult {
  final int p1Score, p2Score;
  final int p1Unsafe, p2Unsafe;
  final int p1Turns, p2Turns;
  final int p1LongestStreak, p2LongestStreak;

  // Per-move timings (µs) collected during this game.
  final List<int> p1AiUs, p2AiUs;         // AI selection
  final List<int> p1ApplyUs, p2ApplyUs;   // engine applyMove

  GameResult({
    required this.p1Score,
    required this.p2Score,
    required this.p1Unsafe,
    required this.p2Unsafe,
    required this.p1Turns,
    required this.p2Turns,
    required this.p1LongestStreak,
    required this.p2LongestStreak,
    required this.p1AiUs,
    required this.p2AiUs,
    required this.p1ApplyUs,
    required this.p2ApplyUs,
  });
}

// Simple stats helpers.
// NOTE: percentile uses nearest-rank via round(); fine for large N.
double _meanUs(List<int> xs) =>
    xs.isEmpty ? 0.0 : xs.fold<int>(0, (a, b) => a + b) / xs.length;

int _percentileUs(List<int> xs, double q) {
  if (xs.isEmpty) return 0;
  final v = [...xs]..sort();
  final i = (q * (v.length - 1)).round();
  return v[i];
}

String _usToMsStr(num us) => (us / 1000.0).toStringAsFixed(3);

GameResult _playOneGame({
  required int grid,
  required Ai p1,
  required Ai p2,
  required Random rng,
}) {
  final g = Game(grid, numPlayers: 2);

  int p1Unsafe = 0, p2Unsafe = 0;
  int p1Turns = 0, p2Turns = 0;

  // Track how many consecutive moves each player gets (chain harvests).
  int currentStreak = 0;
  int p1Longest = 0, p2Longest = 0;
  int lastPlayer = -1;

  // Timings in microseconds (Stopwatch resolution).
  final p1AiUs = <int>[];
  final p2AiUs = <int>[];
  final p1ApplyUs = <int>[];
  final p2ApplyUs = <int>[];

  while (!g.isOver) {
    final moverIndex = g.currentPlayerIndex; // 0 or 1
    final mover = moverIndex == 0 ? p1 : p2;

    // Streak accounting: reset when turn changes.
    if (moverIndex != lastPlayer) {
      currentStreak = 0;
      lastPlayer = moverIndex;
    }
    currentStreak++;

    // --- AI move selection timing ---
    final swSel = Stopwatch()..start();
    final mv = mover.fn(g, rng);
    swSel.stop();
    if (moverIndex == 0) p1AiUs.add(swSel.elapsedMicroseconds);
    else p2AiUs.add(swSel.elapsedMicroseconds);

    // Unsafe = opponent can immediately score after this move (benchmark-only).
    // NOTE: givesBoxToOpponent(g, mv) comes from game_engine in this setup.
    if (givesBoxToOpponent(g, mv)) {
      if (moverIndex == 0) p1Unsafe++;
      else p2Unsafe++;
    }

    // --- Engine apply timing ---
    final beforeScore = g.scores[g.players[moverIndex]]!;
    final swApply = Stopwatch()..start();
    g.playEdge(mv[0], mv[1], mv[2], mv[3]);
    swApply.stop();
    if (moverIndex == 0) p1ApplyUs.add(swApply.elapsedMicroseconds);
    else p2ApplyUs.add(swApply.elapsedMicroseconds);

    final afterScore = g.scores[g.players[moverIndex]]!;
    final gained = afterScore - beforeScore;

    // Count turns for each side; extra turns are separate increments.
    if (moverIndex == 0) p1Turns++; else p2Turns++;

    // If no box was gained, turn will hand over; finalize streak now.
    if (gained == 0) {
      if (moverIndex == 0) {
        if (currentStreak > p1Longest) p1Longest = currentStreak;
      } else {
        if (currentStreak > p2Longest) p2Longest = currentStreak;
      }
    }
  }

  // Finalize the streak for whoever took the last move.
  if (lastPlayer == 0) {
    if (currentStreak > p1Longest) p1Longest = currentStreak;
  } else {
    if (currentStreak > p2Longest) p2Longest = currentStreak;
  }

  final s = g.scores;
  return GameResult(
    p1Score: s[g.players[0]]!,
    p2Score: s[g.players[1]]!,
    p1Unsafe: p1Unsafe,
    p2Unsafe: p2Unsafe,
    p1Turns: p1Turns,
    p2Turns: p2Turns,
    p1LongestStreak: p1Longest,
    p2LongestStreak: p2Longest,
    p1AiUs: p1AiUs,
    p2AiUs: p2AiUs,
    p1ApplyUs: p1ApplyUs,
    p2ApplyUs: p2ApplyUs,
  );
}
