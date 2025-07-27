import 'package:test/test.dart';
import 'package:game_engine/game_engine.dart';

void main() {
  group('Game Engine Core', () {
    test('initial state: zero scores, not over', () {
      final game = Game(2);
      expect(game.scores[Player.player1], 0);
      expect(game.scores[Player.player2], 0);
      expect(game.isOver, isFalse);
    });

    test('invalid moves are rejected', () {
      final game = Game(2);
      expect(game.playEdge(0, 0, 2, 2), isFalse);
      expect(game.playEdge(-1, 0, 0, 0), isFalse);
    });

    test('valid move toggles edge and switches turn', () {
      final game = Game(2);
      expect(game.currentPlayer, Player.player1);
      final ok = game.playEdge(0, 0, 1, 0);
      expect(ok, isTrue);
      expect(game.currentPlayer, Player.player2);
    });

    test(
      'P1 completing a single box awards a point and retains turn',
      () {
        final game = Game(2);

        // Manually set up three sides of the top-left box at (0,0):
        game.hEdges[1][0] = true; // bottom edge of that box
        game.vEdges[0][0] = true; // left edge
        game.vEdges[0][1] = true; // right edge

        // It's still Player1's turn; closing the top edge should capture
        final didPlay = game.playEdge(0, 0, 1, 0);
        expect(didPlay, isTrue);

        // Verify Player1 scored and keeps the turn
        expect(game.scores[Player.player1], 1);
        expect(game.currentPlayer, Player.player1);
      },
    );

    test('game is over after all edges are played', () {
      final game = Game(1);
      expect(game.isOver, isFalse);
      game.playEdge(0, 0, 1, 0);
      game.playEdge(0, 1, 1, 1);
      game.playEdge(0, 0, 0, 1);
      game.playEdge(1, 0, 1, 1);
      expect(game.isOver, isTrue);
    });
  });
}
