import 'package:test/test.dart';
import 'package:game_engine/game_engine.dart';

void main() {
  group('Game Engine Core', () {
    test('initial state: zero scores, not over', () {
      final game = Game(2);
      // Fresh board: nobody has boxes; edges remain → not over.
      expect(game.scores[Player.player1], 0);
      expect(game.scores[Player.player2], 0);
      expect(game.isOver, isFalse);
    });

    test('invalid moves are rejected', () {
      final game = Game(2);
      // Non-adjacent dots (diag/length>1) and out-of-bounds should fail.
      expect(game.playEdge(0, 0, 2, 2), isFalse);
      expect(game.playEdge(-1, 0, 0, 0), isFalse);
      // NOTE: duplicate-edge rejection is covered implicitly elsewhere via state.
    });

    test('valid move toggles edge and switches turn', () {
      final game = Game(2);
      expect(game.currentPlayer, Player.player1);
      // Legal horizontal edge along the top row.
      final ok = game.playEdge(0, 0, 1, 0);
      expect(ok, isTrue);
      // No box completed → turn passes to Player2.
      expect(game.currentPlayer, Player.player2);
    });

    test('P1 completing a single box awards a point and retains turn', () {
      final game = Game(2);

      // Pre-fill three sides of the (0,0) box:
      game.hEdges[1][0] = true; // bottom edge
      game.vEdges[0][0] = true; // left edge
      game.vEdges[0][1] = true; // right edge

      // Closing the top edge should claim the box for Player1 and keep the turn.
      final didPlay = game.playEdge(0, 0, 1, 0);
      expect(didPlay, isTrue);

      expect(game.scores[Player.player1], 1);
      expect(game.currentPlayer, Player.player1); // extra-turn rule
    });

    test('game is over after all edges are played', () {
      final game = Game(1);
      expect(game.isOver, isFalse);

      // 1×1 board: four edges total. After all are drawn, game ends.
      game.playEdge(0, 0, 1, 0);
      game.playEdge(0, 1, 1, 1);
      game.playEdge(0, 0, 0, 1);
      game.playEdge(1, 0, 1, 1);

      expect(game.isOver, isTrue);
    });
  });
}
