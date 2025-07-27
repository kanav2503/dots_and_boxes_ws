// // // packages/game_engine/bin/heuristic_vs_deep.dart

// // import 'dart:math';
// // import 'package:game_engine/game_engine.dart';
// // import 'package:game_engine/src/ai.dart'; // for deepHeuristicMove()

// // /// A standalone 1‑ply “safe‑move” heuristic.
// // /// Exactly the same logic your Flutter app uses in `_runHeuristicAi`,
// // /// but here packaged as a pure function for benchmarking.
// // List<int> heuristicMove(Game g) {
// //   final all = g.availableEdges();               // all empty edges
// //   // Filter to those that do NOT give opponent an immediate box
// //   final safe = all.where((m) {
// //     final sim = g.clone();                       // clone original
// //     sim.playEdge(m[0], m[1], m[2], m[3]);        // simulate AI move
// //     final opp = sim.currentPlayer;               // who moves next?
// //     final before = sim.scores[opp]!;             // their box count
// //     // simulate every possible reply
// //     for (var r in sim.availableEdges()) {
// //       final sim2 = sim.clone();
// //       sim2.playEdge(r[0], r[1], r[2], r[3]);
// //       if (sim2.scores[opp]! > before) {
// //         return false;                            // this move hands them a box
// //       }
// //     }
// //     return true;                                 // safe if no reply scores
// //   }).toList();

// //   // If there’s at least one “safe” move, use those; otherwise fall back to all
// //   final pool = safe.isNotEmpty ? safe : all;

// //   // Pick one uniformly at random
// //   return pool[Random().nextInt(pool.length)];
// // }

// // void main() {
// //   const int N = 1000;      // how many games to simulate
// //   const int GRID = 4;      // size of the board (4×4 boxes)

// //   // Counters for results
// //   int heurWins = 0, deepWins = 0, ties = 0;
// //   int totalHeurScore = 0, totalDeepScore = 0;
// //   final rand = Random();

// //   for (var i = 0; i < N; i++) {
// //     // 1) Start a fresh game each iteration
// //     final game = Game(GRID, numPlayers: 2);

// //     // 2) Loop until the board is full
// //     while (!game.isOver) {
// //       if (game.currentPlayerIndex == 0) {
// //         // Player 0: 1‑ply heuristic
// //         final m = heuristicMove(game);
// //         game.playEdge(m[0], m[1], m[2], m[3]);
// //       } else {
// //         // Player 1: 2‑ply deep heuristic
// //         final m = deepHeuristicMove(game);
// //         game.playEdge(m[0], m[1], m[2], m[3]);
// //       }
// //     }

// //     // 3) Tally final scores
// //     final scores = game.scores;
// //     final h = scores[game.players[0]]!;  // heuristic’s boxes
// //     final d = scores[game.players[1]]!;  // deep heuristic’s boxes
// //     totalHeurScore += h;
// //     totalDeepScore += d;

// //     if (h > d) heurWins++;
// //     else if (d > h) deepWins++;
// //     else ties++;
// //   }

// //   // 4) Print a summary
// //   print('After $N games on a $GRID×$GRID board:');
// //   print(' • 1‑ply Heuristic wins : $heurWins');
// //   print(' • 2‑ply Deep Heuristic wins : $deepWins');
// //   print(' • Ties                : $ties');
// //   print(' • Avg 1‑ply score     : ${totalHeurScore / N}');
// //   print(' • Avg 2‑ply score     : ${totalDeepScore / N}');
// // }

// // packages/game_engine/bin/heur_vs_deep.dart

// import 'dart:math';
// import 'package:game_engine/game_engine.dart';
// // import 'package:game_engine/src/ai.dart'; // for deepHeuristicMove()

// void main() {
//   const int N = 500;  // number of games
//   const int GRID = 6;  // 6×6 board

//   // Result counters
//   int hWins = 0, dWins = 0, ties = 0;
//   int totalH = 0, totalD = 0;

//   final rand = Random();

//   for (var i = 0; i < N; i++) {
//     final game = Game(GRID, numPlayers: 2);

//     while (!game.isOver) {
//       if (game.currentPlayerIndex == 0) {
//         // 1‑ply Heuristic turn
//         final m = heuristicMove(game, rand);
//         game.playEdge(m[0], m[1], m[2], m[3]);
//       } else {
//         // 2‑ply Deep Heuristic turn
//         final m = deepHeuristicMove(game);
//         game.playEdge(m[0], m[1], m[2], m[3]);
//       }
//     }

//     final scores = game.scores;
//     final h = scores[game.players[0]]!;
//     final d = scores[game.players[1]]!;

//     totalH += h;
//     totalD += d;

//     if (h > d) hWins++;
//     else if (d > h) dWins++;
//     else ties++;
//   }

//   print('After $N games on a $GRID×$GRID board:');
//   print(' • 1‑ply Heuristic wins : $hWins');
//   print(' • 2‑ply Deep Heuristic wins : $dWins');
//   print(' • Ties                : $ties');
//   print(' • Avg 1‑ply score     : ${totalH / N}');
//   print(' • Avg 2‑ply score     : ${totalD / N}');
// }

// /// Pure function for your 1-ply “safe-move” heuristic.
// ///
// /// Scans each candidate edge m, rejects those that let the opponent
// /// complete a box on their very next move, then picks randomly
// /// among the remaining (or among all if none are safe).
// List<int> heuristicMove(Game g, Random rand) {
//   final all = g.availableEdges();

//   // Filter to edges that do NOT give the opponent an immediate box
//   final safe = all.where((m) {
//     final sim = g.clone();
//     sim.playEdge(m[0], m[1], m[2], m[3]);

//     final opp = sim.currentPlayer;
//     final before = sim.scores[opp]!;

//     for (var r in sim.availableEdges()) {
//       final sim2 = sim.clone();
//       sim2.playEdge(r[0], r[1], r[2], r[3]);
//       if (sim2.scores[opp]! > before) {
//         return false; // this move hands them a box
//       }
//     }
//     return true; // no reply scores → safe
//   }).toList();

//   // If any safe moves exist, use those; otherwise fall back to all moves
//   final pool = safe.isNotEmpty ? safe : all;

//   // Randomly pick one
//   return pool[rand.nextInt(pool.length)];
// }


// // // // packages/game_engine/bin/benchmark.dart

// // // import 'package:game_engine/game_engine.dart';
// // // import 'dart:math';

// // // void main() {
// // //   const int N = 1000;  // number of games to simulate

// // //   // Non‑nullable counters
// // //   int randomWins = 0;
// // //   int heurWins   = 0;
// // //   int ties       = 0;

// // //   int totalRandomScore = 0;
// // //   int totalHeurScore   = 0;

// // //   final rand = Random();

// // //   for (var i = 0; i < N; i++) {
// // //     final game = Game(4, numPlayers: 2);

// // //     while (!game.isOver) {
// // //       if (game.currentPlayerIndex == 0) {
// // //         // Random AI’s turn
// // //         final moves = game.availableEdges();
// // //         final m = moves[rand.nextInt(moves.length)];
// // //         game.playEdge(m[0], m[1], m[2], m[3]);
// // //       } else {
// // //         // Deep Heuristic AI’s turn
// // //         final m = deepHeuristicMove(game);
// // //         game.playEdge(m[0], m[1], m[2], m[3]);
// // //       }
// // //     }

// // //     // Record final scores
// // //     final scores = game.scores;
// // //     final r = scores[game.players[0]]!;
// // //     final h = scores[game.players[1]]!;

// // //     totalRandomScore += r;
// // //     totalHeurScore   += h;

// // //     if (r > h) randomWins++;
// // //     else if (h > r) heurWins++;
// // //     else ties++;
// // //   }

// // //   // Print summary
// // //   print('After $N games (4×4 grid):');
// // //   print(' • Random AI won   : $randomWins');
// // //   print(' • Heuristic AI won: $heurWins');
// // //   print(' • Ties            : $ties');
// // //   print(' • Avg Random score: ${totalRandomScore / N}');
// // //   print(' • Avg Heur score  : ${totalHeurScore   / N}');
// // // }


// // import 'dart:math';
// // import 'package:game_engine/game_engine.dart';

// // void main() {
// //   const int N = 500;     // you can bump this up if you like
// //   const int GRID = 6;    // 6×6 boxes

// //   int randomWins = 0, heurWins = 0, ties = 0;
// //   int totalRandomScore = 0, totalHeurScore = 0;
// //   final rand = Random();

// //   for (var i = 0; i < N; i++) {
// //     final game = Game(GRID, numPlayers: 2);
// //     while (!game.isOver) {
// //       if (game.currentPlayerIndex == 0) {
// //         // Random AI
// //         final m = randomMove(game);
// //         game.playEdge(m[0], m[1], m[2], m[3]);
// //       } else {
// //         // 1‑ply Heuristic
// //         // (reuse the same helper from your Flutter code)
// //         final all = game.availableEdges();
// //         final safe = all.where((m) => !_givesBoxToOpponent(m)).toList();
// //         final pool = safe.isNotEmpty ? safe : all;
// //         final m = pool[rand.nextInt(pool.length)];
// //         game.playEdge(m[0], m[1], m[2], m[3]);
// //       }
// //     }
// //     final s = game.scores;
// //     final r = s[game.players[0]]!;
// //     final h = s[game.players[1]]!;
// //     totalRandomScore += r;
// //     totalHeurScore   += h;
// //     if (r > h) randomWins++;
// //     else if (h > r) heurWins++;
// //     else ties++;
// //   }

// //   print('After $N games on a $GRID×$GRID board:');
// //   print(' • Random AI won   : $randomWins');
// //   print(' • 1‑ply Heuristic won : $heurWins');
// //   print(' • Ties            : $ties');
// //   print(' • Avg Random score: ${totalRandomScore / N}');
// //   print(' • Avg Heur score  : ${totalHeurScore   / N}');
// // }

// // // Copy your 1‑ply helper from game_page.dart:
// // bool _givesBoxToOpponent(List<int> m) {
// //   final sim = Game(6, numPlayers: 2)..hEdges = List.from(Game(6, numPlayers:2).hEdges)..vEdges = List.from(Game(6, numPlayers:2).vEdges)..boxes = List.from(Game(6, numPlayers:2).boxes); // you’ll want a proper .clone() here
// //   sim.playEdge(m[0], m[1], m[2], m[3]);
// //   final opp = sim.currentPlayer;
// //   final before = sim.scores[opp]!;
// //   for (var r in sim.availableEdges()) {
// //     final sim2 = sim.clone();
// //     sim2.playEdge(r[0], r[1], r[2], r[3]);
// //     if (sim2.scores[opp]! > before) return true;
// //   }
// //   return false;
// // }


// // packages/game_engine/bin/benchmark_all_ai.dart
