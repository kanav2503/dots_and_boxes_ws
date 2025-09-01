// lib/home_page.dart
import 'package:flutter/material.dart';
import 'game_page.dart';           // owns GamePage + GameMode
import 'online_lobby_page.dart';  // online matchmaking / room join

/// Landing screen:
/// - lets you pick grid size
/// - collect local player names (2–4)
/// - jump into local, vs-AI, or online modes
class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _gridSize = 4;     // boxes per side; 4×4 default is a good quick test
  int _playerCount = 2;  // local play supports up to 4 here

  // Keep simple text controllers; we clean them up in dispose().
  final _nameControllers = List.generate(
    4,
    (i) => TextEditingController(text: 'Player ${i + 1}'),
  );

  @override
  void dispose() {
    for (final c in _nameControllers) c.dispose();
    super.dispose();
  }

  // Start hot-seat local multiplayer with N names (2–4).
  void _startLocal() {
    final names = _nameControllers
        .take(_playerCount)
        // fall back to "Player" if the field is blank
        .map((c) => c.text.trim().isEmpty ? 'Player' : c.text.trim())
        .toList();

    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => GamePage(
        gridSize: _gridSize,
        mode: GameMode.twoPlayer, // NOTE: extend if you later support 3–4 in engine
        playerNames: names,
      ),
    ));
  }

  // Start a single-player game against one of the AIs.
  void _startAi(GameMode mode) {
    final humanName = _nameControllers[0].text.trim().isEmpty
        ? 'Player'
        : _nameControllers[0].text.trim();

    // Minimal mapping to friendly AI names.
    String aiName;
    switch (mode) {
      case GameMode.singlePlayerRandom:
        aiName = 'Random AI';
        break;
      case GameMode.singlePlayerHeuristic:
        aiName = 'Heuristic AI';
        break;
      case GameMode.singlePlayerHeuristic2:
        aiName = 'Deep Heuristic AI';
        break;
      default:
        aiName = 'AI';
    }

    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => GamePage(
        gridSize: _gridSize,
        mode: mode,
        playerNames: [humanName, aiName],
      ),
    ));
  }

  // Navigate to online lobby / room creation.
  void _gotoOnline() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => OnlineLobbyPage(gridSize: _gridSize),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dots & Boxes')),
      body: SingleChildScrollView(
        // Scroll avoids overflow on small screens / landscape keyboards.
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Grid size (boxes per side):'),
            const SizedBox(height: 8),
            DropdownButton<int>(
              value: _gridSize,
              items: [
                for (var n = 2; n <= 12; n++)
                  DropdownMenuItem(
                    value: n,
                    child: Text('$n × $n'),
                  )
              ],
              onChanged: (n) => setState(() => _gridSize = n!),
            ),
            const SizedBox(height: 24),

            const Text('Number of players (Local only):'),
            const SizedBox(height: 8),
            DropdownButton<int>(
              value: _playerCount,
              items: [2, 3, 4]
                  .map((n) => DropdownMenuItem(value: n, child: Text('$n Players')))
                  .toList(),
              onChanged: (n) => setState(() => _playerCount = n!),
            ),
            const SizedBox(height: 16),

            // Show name fields for the selected number of players.
            for (var i = 0; i < _playerCount; i++) ...[
              TextField(
                controller: _nameControllers[i],
                decoration: InputDecoration(labelText: 'Name of Player ${i + 1}'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 24),

            // Local multiplayer (hot seat).
            ElevatedButton(
              onPressed: _startLocal,
              child: Text('Local Multiplayer ($_playerCount)'),
            ),
            const SizedBox(height: 16),

            // Single-player vs the three AI variants.
            ElevatedButton(
              onPressed: () => _startAi(GameMode.singlePlayerRandom),
              child: const Text('Vs Random AI'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _startAi(GameMode.singlePlayerHeuristic),
              child: const Text('Vs Heuristic AI'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _startAi(GameMode.singlePlayerHeuristic2),
              child: const Text('Vs Deep AI'),
            ),
            const SizedBox(height: 24),

            // Online lobby / matchmaking.
            ElevatedButton(
              onPressed: _gotoOnline,
              child: const Text('Online Multiplayer'),
            ),
          ],
        ),
      ),
    );
  }
}

// NOTE:
// - Grid size is capped at 12×12 here for UI sanity/perf. Adjust if engine scales.
// - If you want persistence, store _gridSize/_playerCount and names in SharedPreferences.
// - Consider named routes if this list grows, or a Router if you add deep links.
