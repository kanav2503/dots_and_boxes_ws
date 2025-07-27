// lib/home_page.dart

import 'package:flutter/material.dart';
import 'game_page.dart';
import 'online_lobby_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _gridSize = 4;
  int _playerCount = 2;
  final _nameControllers = List.generate(
    4,
    (i) => TextEditingController(text: 'Player ${i + 1}'),
  );

  @override
  void dispose() {
    for (final c in _nameControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _startLocal() {
    final names = _nameControllers
        .take(_playerCount)
        .map((c) => c.text.trim().isEmpty ? 'Player' : c.text.trim())
        .toList();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => GamePage(
        gridSize: _gridSize,
        mode: GameMode.twoPlayer,
        playerNames: names,
      ),
    ));
  }

  void _startAi(GameMode mode) {
    final humanName = _nameControllers[0].text.trim().isEmpty
        ? 'Player'
        : _nameControllers[0].text.trim();
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
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Grid size (boxes per side):',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            DropdownButton<int>(
              value: _gridSize,
              items: [
                for (var n = 2; n <= 12; n++)
                  DropdownMenuItem(value: n, child: Text('$n × $n')),
              ],
              onChanged: (n) => setState(() => _gridSize = n!),
            ),
            const SizedBox(height: 24),
            const Text(
              'Number of players (Local only):',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            DropdownButton<int>(
              value: _playerCount,
              items: [2, 3, 4]
                  .map((n) => DropdownMenuItem(value: n, child: Text('$n Players')))
                  .toList(),
              onChanged: (n) => setState(() => _playerCount = n!),
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < _playerCount; i++) ...[
              TextField(
                controller: _nameControllers[i],
                decoration: InputDecoration(labelText: 'Name of Player ${i + 1}'),
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _startLocal,
              child: Text('Local Multiplayer ($_playerCount)'),
            ),
            const SizedBox(height: 16),
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
              child: const Text('Vs Deep Heuristic AI'),
            ),
            const SizedBox(height: 16),
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
