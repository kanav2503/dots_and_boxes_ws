// lib/src/game.dart

import 'dart:math';

/// Player identities, supporting up to 4 human players.
enum Player { none, player1, player2, player3, player4 }

/// Core game engine with dynamic player count.
class Game {
  /// Number of boxes per row/column.
  final int size;
  /// Number of active players.
  final int numPlayers;

  /// Active players in rotation order.
  late final List<Player> players;
  /// Index into [players] for whose turn it is.
  int currentPlayerIndex = 0;

  /// Horizontal edges: (size+1) rows × size columns.
  late List<List<bool>> hEdges;
  /// Vertical edges: size rows × (size+1) columns.
  late List<List<bool>> vEdges;
  /// Owner of each box: Player.none or one of the active players.
  late List<List<Player>> boxes;

  /// Create a [size]×[size] game with [numPlayers] (2–4).
  Game(this.size, {this.numPlayers = 2}) {
    assert(numPlayers >= 2 && numPlayers <= 4,
        'numPlayers must be between 2 and 4');
    // Build the active players list: skip Player.none, take the first numPlayers
    players = List.generate(numPlayers, (i) => Player.values[i + 1]);

    hEdges = List.generate(size + 1, (_) => List.filled(size, false));
    vEdges = List.generate(size, (_) => List.filled(size + 1, false));
    boxes = List.generate(size, (_) => List.filled(size, Player.none));
  }

  /// Which player’s turn is it?
  Player get currentPlayer => players[currentPlayerIndex];

  /// Attempt to play the edge between (x1,y1) and (x2,y2).
  /// Returns false if the move is illegal.
  bool playEdge(int x1, int y1, int x2, int y2) {
    if ((x1 - x2).abs() + (y1 - y2).abs() != 1) return false;

    final isHoriz = y1 == y2;
    int row, col;
    if (isHoriz) {
      row = y1;
      col = min(x1, x2);
      if (row < 0 || row > size || col < 0 || col >= size) return false;
      if (hEdges[row][col]) return false;
      hEdges[row][col] = true;
    } else {
      col = x1;
      row = min(y1, y2);
      if (col < 0 || col > size || row < 0 || row >= size) return false;
      if (vEdges[row][col]) return false;
      vEdges[row][col] = true;
    }

    // Check for any boxes completed by this move
    var completed = 0;
    if (isHoriz) {
      // above
      if (row > 0 &&
          hEdges[row - 1][col] &&
          hEdges[row][col] &&
          vEdges[row - 1][col] &&
          vEdges[row - 1][col + 1] &&
          boxes[row - 1][col] == Player.none) {
        boxes[row - 1][col] = currentPlayer;
        completed++;
      }
      // below
      if (row < size &&
          hEdges[row][col] &&
          hEdges[row + 1][col] &&
          vEdges[row][col] &&
          vEdges[row][col + 1] &&
          boxes[row][col] == Player.none) {
        boxes[row][col] = currentPlayer;
        completed++;
      }
    } else {
      // left
      if (col > 0 &&
          vEdges[row][col - 1] &&
          vEdges[row][col] &&
          hEdges[row][col - 1] &&
          hEdges[row + 1][col - 1] &&
          boxes[row][col - 1] == Player.none) {
        boxes[row][col - 1] = currentPlayer;
        completed++;
      }
      // right
      if (col < size &&
          vEdges[row][col] &&
          vEdges[row][col + 1] &&
          hEdges[row][col] &&
          hEdges[row + 1][col] &&
          boxes[row][col] == Player.none) {
        boxes[row][col] = currentPlayer;
        completed++;
      }
    }

    // If no box captured, move to the next player in rotation.
    if (completed == 0) {
      currentPlayerIndex = (currentPlayerIndex + 1) % players.length;
    }
    // else, same player goes again.

    return true;
  }

  /// True when no more edges remain.
  bool get isOver {
    for (var row in hEdges) if (row.contains(false)) return false;
    for (var row in vEdges) if (row.contains(false)) return false;
    return true;
  }

  /// Count of boxes owned by each player.
  /// Returns a map from Player→count. Unused enum values get 0.
  Map<Player, int> get scores {
    final counts = <Player, int>{};
    for (var p in players) {
      counts[p] = 0;
    }
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        final owner = boxes[y][x];
        if (owner != Player.none) {
          counts[owner] = (counts[owner] ?? 0) + 1;
        }
      }
    }
    return counts;
  }

  /// Deep clone of the current game state.
  Game clone() {
    final copy = Game(size, numPlayers: numPlayers)
      ..currentPlayerIndex = currentPlayerIndex
      ..hEdges = hEdges.map((r) => List<bool>.from(r)).toList()
      ..vEdges = vEdges.map((r) => List<bool>.from(r)).toList()
      ..boxes = boxes.map((r) => List<Player>.from(r)).toList();
    return copy;
  }

  /// All unplayed edges as [x1,y1,x2,y2].
  List<List<int>> availableEdges() {
    final moves = <List<int>>[];
    for (var y = 0; y <= size; y++) {
      for (var x = 0; x < size; x++) {
        if (!hEdges[y][x]) moves.add([x, y, x + 1, y]);
      }
    }
    for (var y = 0; y < size; y++) {
      for (var x = 0; x <= size; x++) {
        if (!vEdges[y][x]) moves.add([x, y, x, y + 1]);
      }
    }
    return moves;
  }
}
