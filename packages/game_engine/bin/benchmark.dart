// // import 'dart:math';
// // import 'package:game_engine/game_engine.dart';  

// // /// Defines the signature for an AI move function.
// // typedef MoveFn = List<int> Function(Game game, Random rng);

// // class _AiDef {
// //   final String name;
// //   final MoveFn fn;
// //   _AiDef(this.name, this.fn);
// // }

// // void main() {
// //   const int GAMES = 500;    
// //   const int GRID  = 6;      
// //   final rng = Random();

// //   List<int> heuristicMove(Game g, Random r) {
// //     final all = g.availableEdges();
// //     final safe = all.where((m) {
// //       final sim = g.clone();
// //       sim.playEdge(m[0], m[1], m[2], m[3]);
// //       final opp    = sim.currentPlayer;
// //       final before = sim.scores[opp]!;
// //       for (var r2 in sim.availableEdges()) {
// //         final sim2 = sim.clone();
// //         sim2.playEdge(r2[0], r2[1], r2[2], r2[3]);
// //         if (sim2.scores[opp]! > before) return false;
// //       }
// //       return true;
// //     }).toList();
// //     final pool = safe.isNotEmpty ? safe : all;
// //     return pool[r.nextInt(pool.length)];
// //   }

// //   final ais = <_AiDef>[
// //     _AiDef('Random',        (g, r) => randomMove(g)),
// //     _AiDef('Heuristic‑1‑ply', heuristicMove),
// //     _AiDef('Deep‑2‑ply',    (g, r) => deepHeuristicMove(g)),
// //   ];

// //   for (var i = 0; i < ais.length; i++) {
// //     for (var j = i + 1; j < ais.length; j++) {
// //       final p1 = ais[i], p2 = ais[j];
// //       int p1Wins = 0, p2Wins = 0, ties = 0;
// //       int total1 = 0, total2 = 0;

// //       for (var gameIndex = 0; gameIndex < GAMES; gameIndex++) {
// //         final game = Game(GRID, numPlayers: 2);

// //         while (!game.isOver) {
// //           final mover = game.currentPlayerIndex == 0 ? p1 : p2;
// //           final move  = mover.fn(game, rng);
// //           game.playEdge(move[0], move[1], move[2], move[3]);
// //         }

// //         final scores = game.scores;
// //         final s1 = scores[game.players[0]]!;
// //         final s2 = scores[game.players[1]]!;
// //         total1 += s1;
// //         total2 += s2;

// //         if (s1 > s2)      p1Wins++;
// //         else if (s2 > s1) p2Wins++;
// //         else              ties++;
// //       }

// //       print('\n=== $GRID×$GRID: ${p1.name} vs ${p2.name} '
// //             '($GAMES games) ===');
// //       print(' • ${p1.name} wins: $p1Wins');
// //       print(' • ${p2.name} wins: $p2Wins');
// //       print(' • Ties         : $ties');
// //       print(' • Avg ${p1.name} score: ${ (total1 / GAMES).toStringAsFixed(2) }');
// //       print(' • Avg ${p2.name} score: ${ (total2 / GAMES).toStringAsFixed(2) }');
// //     }
// //   }
// // }


// import 'dart:io';
// import 'dart:math';
// import 'package:game_engine/game_engine.dart'; // exports Game, deepHeuristicMove, etc.

// typedef MoveFn = List<int> Function(Game g, Random rng);

// class Ai {
//   final String name;
//   final MoveFn fn;
//   const Ai(this.name, this.fn);
// }

// // 1-ply “safe” heuristic
// List<int> heuristicMove(Game g, Random rng) {
//   final all = g.availableEdges();
//   final safe = all.where((m) {
//     final sim = g.clone();
//     sim.playEdge(m[0], m[1], m[2], m[3]);
//     final opp = sim.currentPlayer;
//     final before = sim.scores[opp]!;
//     for (final r in sim.availableEdges()) {
//       final sim2 = sim.clone();
//       sim2.playEdge(r[0], r[1], r[2], r[3]);
//       if (sim2.scores[opp]! > before) return false;
//     }
//     return true;
//   }).toList();
//   final pool = safe.isNotEmpty ? safe : all;
//   return pool[rng.nextInt(pool.length)];
// }

// // Random AI
// List<int> randomMoveFn(Game g, Random rng) {
//   final moves = g.availableEdges();
//   return moves[rng.nextInt(moves.length)];
// }

// // Deep 2-ply heuristic
// List<int> deepMove(Game g, Random rng) => deepHeuristicMove(g);

// void main() async {
//   // ==== CONFIGURE HERE ====
//   const grids = [4, 5, 6];   // try more if you like
//   const gamesPerPair = 300;  // per pairing & order
//   final rng = Random(42);    // seed for reproducibility

//   final ais = <Ai>[
//     Ai('Random', randomMoveFn),
//     Ai('Heuristic1', heuristicMove),
//     Ai('Deep2', deepMove),
//   ];

//   // CSV header
//   final sb = StringBuffer()
//     ..writeln('grid,games,p1_ai,p2_ai,p1_wins,p2_wins,ties,p1_avg,p2_avg,total_boxes');

//   for (final grid in grids) {
//     final totalBoxes = grid * grid;

//     for (var i = 0; i < ais.length; i++) {
//       for (var j = 0; j < ais.length; j++) {
//         final p1 = ais[i];
//         final p2 = ais[j];

//         int p1Wins = 0, p2Wins = 0, ties = 0;
//         int sumP1 = 0, sumP2 = 0;

//         for (var gIndex = 0; gIndex < gamesPerPair; gIndex++) {
//           final game = Game(grid, numPlayers: 2);

//           while (!game.isOver) {
//             final mover = game.currentPlayerIndex == 0 ? p1 : p2;
//             final mv = mover.fn(game, rng);
//             game.playEdge(mv[0], mv[1], mv[2], mv[3]);
//           }

//           final s = game.scores;
//           final p1Score = s[game.players[0]]!;
//           final p2Score = s[game.players[1]]!;
//           sumP1 += p1Score;
//           sumP2 += p2Score;

//           if (p1Score > p2Score) p1Wins++;
//           else if (p2Score > p1Score) p2Wins++;
//           else ties++;
//         }

//         final p1Avg = sumP1 / gamesPerPair;
//         final p2Avg = sumP2 / gamesPerPair;

//         sb.writeln('$grid,$gamesPerPair,${p1.name},${p2.name},'
//             '$p1Wins,$p2Wins,$ties,'
//             '${p1Avg.toStringAsFixed(3)},${p2Avg.toStringAsFixed(3)},$totalBoxes');
//       }
//     }
//   }

//   // Write CSV to file
//   final outPath = 'benchmark_results.csv';
//   await File(outPath).writeAsString(sb.toString());
//   print('Saved results to $outPath');
// }


// packages/game_engine/bin/benchmark_experiments.dart
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

  final ais = <Ai>[
    Ai('Random',      (g, r) => randomMove(g)),
    Ai('Heuristic1',  (g, r) => heuristic1Move(g)),
    Ai('Deep2',       (g, r) => deep2Move(g)),
  ];

  // CSV buffers
  final summary = StringBuffer()
    ..writeln('grid,games,p1_ai,p2_ai,p1_wins,p2_wins,ties,'
              'p1_avg,p2_avg,total_boxes,'
              'p1_unsafe_avg,p2_unsafe_avg,'
              'p1_turns_avg,p2_turns_avg,'
              'p1_streak_avg,p2_streak_avg');

  // optional per-game details (large file!)
  final perGame = StringBuffer()
    ..writeln('grid,p1_ai,p2_ai,game_idx,p1_score,p2_score,'
              'p1_unsafe_moves,p2_unsafe_moves,'
              'p1_turns,p2_turns,'
              'p1_longest_streak,p2_longest_streak');

  for (final grid in grids) {
    final totalBoxes = grid * grid;

    for (var i = 0; i < ais.length; i++) {
      for (var j = 0; j < ais.length; j++) {
        final p1 = ais[i];
        final p2 = ais[j];

        // aggregate stats
        int p1Wins = 0, p2Wins = 0, ties = 0;
        int sumP1 = 0, sumP2 = 0;

        int sumP1Unsafe = 0, sumP2Unsafe = 0;
        int sumP1Turns  = 0, sumP2Turns  = 0;
        int sumP1Streak = 0, sumP2Streak = 0;

        for (var gIdx = 0; gIdx < gamesPerPair; gIdx++) {
          final res = _playOneGame(
            grid: grid,
            p1: p1,
            p2: p2,
            rng: rng,
          );

          // tally
          sumP1 += res.p1Score;
          sumP2 += res.p2Score;

          if (res.p1Score > res.p2Score) p1Wins++;
          else if (res.p2Score > res.p1Score) p2Wins++;
          else ties++;

          sumP1Unsafe += res.p1Unsafe;
          sumP2Unsafe += res.p2Unsafe;

          sumP1Turns  += res.p1Turns;
          sumP2Turns  += res.p2Turns;

          sumP1Streak += res.p1LongestStreak;
          sumP2Streak += res.p2LongestStreak;

          perGame.writeln('${grid},${p1.name},${p2.name},$gIdx,'
              '${res.p1Score},${res.p2Score},'
              '${res.p1Unsafe},${res.p2Unsafe},'
              '${res.p1Turns},${res.p2Turns},'
              '${res.p1LongestStreak},${res.p2LongestStreak}');
        }

        final p1Avg = sumP1 / gamesPerPair;
        final p2Avg = sumP2 / gamesPerPair;

        final p1UnsafeAvg = sumP1Unsafe / gamesPerPair;
        final p2UnsafeAvg = sumP2Unsafe / gamesPerPair;

        final p1TurnsAvg  = sumP1Turns  / gamesPerPair;
        final p2TurnsAvg  = sumP2Turns  / gamesPerPair;

        final p1StreakAvg = sumP1Streak / gamesPerPair;
        final p2StreakAvg = sumP2Streak / gamesPerPair;

        summary.writeln('$grid,$gamesPerPair,${p1.name},${p2.name},'
            '$p1Wins,$p2Wins,$ties,'
            '${p1Avg.toStringAsFixed(3)},${p2Avg.toStringAsFixed(3)},$totalBoxes,'
            '${p1UnsafeAvg.toStringAsFixed(3)},${p2UnsafeAvg.toStringAsFixed(3)},'
            '${p1TurnsAvg.toStringAsFixed(2)},${p2TurnsAvg.toStringAsFixed(2)},'
            '${p1StreakAvg.toStringAsFixed(2)},${p2StreakAvg.toStringAsFixed(2)}');
      }
    }
  }

  // Write files
  await File('benchmark_summary.csv').writeAsString(summary.toString());
  await File('benchmark_games.csv').writeAsString(perGame.toString());
  print('Saved benchmark_summary.csv & benchmark_games.csv');
}

// --------------------------------------------------
// STRUCTS & HELPERS
// --------------------------------------------------

class GameResult {
  final int p1Score, p2Score;
  final int p1Unsafe, p2Unsafe;
  final int p1Turns, p2Turns;
  final int p1LongestStreak, p2LongestStreak;

  GameResult({
    required this.p1Score,
    required this.p2Score,
    required this.p1Unsafe,
    required this.p2Unsafe,
    required this.p1Turns,
    required this.p2Turns,
    required this.p1LongestStreak,
    required this.p2LongestStreak,
  });
}

GameResult _playOneGame({
  required int grid,
  required Ai p1,
  required Ai p2,
  required Random rng,
}) {
  final g = Game(grid, numPlayers: 2);

  int p1Unsafe = 0, p2Unsafe = 0;
  int p1Turns = 0, p2Turns = 0;
  int currentStreak = 0;
  int p1Longest = 0, p2Longest = 0;
  int lastPlayer = -1;

  while (!g.isOver) {
    final moverIndex = g.currentPlayerIndex; // 0 or 1
    final mover = moverIndex == 0 ? p1 : p2;

    // count turns & streaks
    if (moverIndex != lastPlayer) {
      currentStreak = 0;
      lastPlayer = moverIndex;
    }
    currentStreak++;

    // choose move
    final mv = mover.fn(g, rng);

    // unsafe check: if opponent can score after this move
    if (givesBoxToOpponent(g, mv)) {
      if (moverIndex == 0) p1Unsafe++;
      else p2Unsafe++;
    }

    // play it
    final beforeScore = g.scores[g.players[moverIndex]]!;
    g.playEdge(mv[0], mv[1], mv[2], mv[3]);
    final afterScore = g.scores[g.players[moverIndex]]!;
    final gained = afterScore - beforeScore;

    // update turns
    if (moverIndex == 0) p1Turns++; else p2Turns++;

    // if gained > 0, same player keeps turn, so streak continues;
    // if gained == 0, we’ll reset streak next loop automatically
    if (gained == 0) {
      if (moverIndex == 0) {
        if (currentStreak > p1Longest) p1Longest = currentStreak;
      } else {
        if (currentStreak > p2Longest) p2Longest = currentStreak;
      }
    }
  }

  // finalize streaks for whoever finished
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
  );
}
