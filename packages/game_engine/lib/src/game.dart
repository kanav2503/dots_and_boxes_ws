// lib/src/game.dart

import 'dart:math';

/// Player identities, supporting up to 4 human players.
/// NOTE: engine uses 1-based players for ownership (player1..player4);
/// `Player.none` marks unclaimed boxes.
enum Player { none, player1, player2, player3, player4 }

/// Core game engine with dynamic player count (2–4).
/// Coordinates are **dot coordinates**: (x, y) in a (size+1) × (size+1) grid.
/// An edge is a segment between two adjacent dots (Manhattan distance = 1).
class Game {
  /// Number of boxes per row/column (so there are `size+1` dots per side).
  final int size;

  /// Number of active players (2–4). Rotation order is player1..playerN.
  final int numPlayers;

  /// Active players in rotation order (excludes [Player.none]).
  late final List<Player> players;

  /// Index into [players] for whose turn it is (0-based).
  int currentPlayerIndex = 0;

  /// Horizontal edges: (size+1) rows × size columns.
  /// `hEdges[y][x] == true` means the edge from (x,y) → (x+1,y) is drawn.
  late List<List<bool>> hEdges;

  /// Vertical edges: size rows × (size+1) columns.
  /// `vEdges[y][x] == true` means the edge from (x,y) → (x,y+1) is drawn.
  late List<List<bool>> vEdges;

  /// Owner of each box: [Player.none] or one of [players].
  /// `boxes[row][col]` refers to the box whose top-left dot is (col,row).
  late List<List<Player>> boxes;

  /// Create a [size]×[size] game with [numPlayers] (2–4).
  Game(this.size, {this.numPlayers = 2}) {
    assert(numPlayers >= 2 && numPlayers <= 4,
        'numPlayers must be between 2 and 4');

    // Build the rotation: skip Player.none and take the first N.
    players = List.generate(numPlayers, (i) => Player.values[i + 1]);

    // Empty board.
    hEdges = List.generate(size + 1, (_) => List.filled(size, false));
    vEdges = List.generate(size, (_) => List.filled(size + 1, false));
    boxes  = List.generate(size,   (_) => List.filled(size, Player.none));
  }

  /// Which player’s turn is it (enum value)?
  Player get currentPlayer => players[currentPlayerIndex];

  /// Attempt to play the edge between (x1,y1) and (x2,y2).
  /// Returns `false` if the move is illegal (non-adjacent or already drawn).
  ///
  /// Rules applied:
  /// - If this edge completes one or two boxes, current player **goes again**.
  /// - Otherwise, advance turn to the next player in rotation.
  bool playEdge(int x1, int y1, int x2, int y2) {
    // Must be axis-aligned to an adjacent dot (Manhattan distance 1).
    if ((x1 - x2).abs() + (y1 - y2).abs() != 1) return false;

    final isHoriz = y1 == y2;
    int row, col;

    // Mark the edge; bail if out of bounds or already drawn.
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

    // Check for any boxes completed by this move and assign ownership.
    // We only need to check up to two boxes adjacent to the drawn edge.
    var completed = 0;
    if (isHoriz) {
      // Box above the horizontal edge.
      if (row > 0 &&
          hEdges[row - 1][col] &&
          hEdges[row][col] &&
          vEdges[row - 1][col] &&
          vEdges[row - 1][col + 1] &&
          boxes[row - 1][col] == Player.none) {
        boxes[row - 1][col] = currentPlayer;
        completed++;
      }
      // Box below the horizontal edge.
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
      // Box to the left of the vertical edge.
      if (col > 0 &&
          vEdges[row][col - 1] &&
          vEdges[row][col] &&
          hEdges[row][col - 1] &&
          hEdges[row + 1][col - 1] &&
          boxes[row][col - 1] == Player.none) {
        boxes[row][col - 1] = currentPlayer;
        completed++;
      }
      // Box to the right of the vertical edge.
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
    // Otherwise the same player plays again (extra-turn rule).
    if (completed == 0) {
      currentPlayerIndex = (currentPlayerIndex + 1) % players.length;
    }

    return true;
  }

  /// True when no more edges remain.
  /// NOTE: This scans both edge grids; if you need faster checks,
  /// track a counter of remaining edges on each play.
  bool get isOver {
    for (var row in hEdges) {
      if (row.contains(false)) return false;
    }
    for (var row in vEdges) {
      if (row.contains(false)) return false;
    }
    return true;
  }

  /// Count of boxes owned by each active player.
  /// Returns a map from Player → box count.
  /// NOTE: recomputes on each call; cache if you query this in tight loops.
  Map<Player, int> get scores {
    final counts = <Player, int>{ for (var p in players) p: 0 };
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
  /// Used by AI to simulate candidate moves. Safe to mutate the clone.
  Game clone() {
    final copy = Game(size, numPlayers: numPlayers)
      ..currentPlayerIndex = currentPlayerIndex
      ..hEdges = hEdges.map((r) => List<bool>.from(r)).toList()
      ..vEdges = vEdges.map((r) => List<bool>.from(r)).toList()
      ..boxes = boxes.map((r) => List<Player>.from(r)).toList();
    return copy;
  }

  /// All unplayed edges as `[x1, y1, x2, y2]` dot coordinates.
  /// Horizontal edges come first (row 0..size, col 0..size-1),
  /// then vertical edges (row 0..size-1, col 0..size).
  /// NOTE: this allocates a lot on large boards; for high-performance search,
  /// consider reusing a buffer or yielding an iterable.
  List<List<int>> availableEdges() {
    final moves = <List<int>>[];

    // Horizontal edges.
    for (var y = 0; y <= size; y++) {
      for (var x = 0; x < size; x++) {
        if (!hEdges[y][x]) moves.add([x, y, x + 1, y]);
      }
    }

    // Vertical edges.
    for (var y = 0; y < size; y++) {
      for (var x = 0; x <= size; x++) {
        if (!vEdges[y][x]) moves.add([x, y, x, y + 1]);
      }
    }

    return moves;
  }
}
