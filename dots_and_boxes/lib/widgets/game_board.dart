// lib/widgets/game_board.dart

import 'package:flutter/material.dart';
import 'package:game_engine/game_engine.dart';

/// A fixed palette for up to 4 players. Add more if you support >4.
const _playerColors = [
  Colors.blue,    // player1
  Colors.red,     // player2
  Colors.green,   // player3
  Colors.orange,  // player4
];

class GameBoard extends StatelessWidget {
  final Game game;
  final void Function(int x1, int y1, int x2, int y2) onEdgeTap;

  const GameBoard({
    Key? key,
    required this.game,
    required this.onEdgeTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final size = constraints.biggest.shortestSide;
      return GestureDetector(
        onTapDown: (d) {
          final edge = _detectEdge(d.localPosition, size, game.size);
          if (edge != null) onEdgeTap(edge[0], edge[1], edge[2], edge[3]);
        },
        child: CustomPaint(
          size: Size(size, size),
          painter: _BoardPainter(game),
        ),
      );
    });
  }

  List<int>? _detectEdge(Offset pos, double boardSize, int n) {
    final cell = boardSize / n;
    final tol = cell * 0.2;
    final x = pos.dx, y = pos.dy;

    // horizontal
    for (var row = 0; row <= n; row++) {
      for (var col = 0; col < n; col++) {
        final y0 = row * cell;
        final x0 = col * cell, x1 = x0 + cell;
        if ((y - y0).abs() < tol && x >= x0 - tol && x <= x1 + tol) {
          return [col, row, col + 1, row];
        }
      }
    }
    // vertical
    for (var row = 0; row < n; row++) {
      for (var col = 0; col <= n; col++) {
        final x0 = col * cell;
        final y0 = row * cell, y1 = y0 + cell;
        if ((x - x0).abs() < tol && y >= y0 - tol && y <= y1 + tol) {
          return [col, row, col, row + 1];
        }
      }
    }
    return null;
  }
}

class _BoardPainter extends CustomPainter {
  final Game game;
  _BoardPainter(this.game);

  @override
  void paint(Canvas c, Size s) {
    final n = game.size;
    final cell = s.width / n;
    final dotR = cell * 0.05;

    final dotPaint = Paint()..color = Colors.black;
    final edgePaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 4;

    // 1) Fill in completed boxes
    for (var r = 0; r < n; r++) {
      for (var col = 0; col < n; col++) {
        final owner = game.boxes[r][col];
        if (owner != Player.none) {
          final idx = owner == Player.player1
              ? 0
              : owner == Player.player2
                  ? 1
                  : 2; // if you support >2 players, adjust
          final paint = Paint()..color = _playerColors[idx].withOpacity(0.4);
          c.drawRect(
            Rect.fromLTWH(
              col * cell + 2,
              r * cell + 2,
              cell - 4,
              cell - 4,
            ),
            paint,
          );
        }
      }
    }

    // 2) Draw edges
    for (var y = 0; y <= n; y++) {
      for (var x = 0; x < n; x++) {
        if (game.hEdges[y][x]) {
          c.drawLine(
            Offset(x * cell, y * cell),
            Offset((x + 1) * cell, y * cell),
            edgePaint,
          );
        }
      }
    }
    for (var y = 0; y < n; y++) {
      for (var x = 0; x <= n; x++) {
        if (game.vEdges[y][x]) {
          c.drawLine(
            Offset(x * cell, y * cell),
            Offset(x * cell, (y + 1) * cell),
            edgePaint,
          );
        }
      }
    }

    // 3) Draw dots on top
    for (var y = 0; y <= n; y++) {
      for (var x = 0; x <= n; x++) {
        c.drawCircle(Offset(x * cell, y * cell), dotR, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BoardPainter old) => true;
}
