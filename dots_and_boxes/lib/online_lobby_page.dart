import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'game_page.dart';

/// Presents a simple Create / Join UI for an online room.
class OnlineLobbyPage extends StatefulWidget {
  final int gridSize;
  const OnlineLobbyPage({Key? key, required this.gridSize}) : super(key: key);

  @override
  State<OnlineLobbyPage> createState() => _OnlineLobbyPageState();
}

class _OnlineLobbyPageState extends State<OnlineLobbyPage> {
  final _roomController = TextEditingController();
  final _db = FirebaseDatabase.instance.ref();

  @override
  void dispose() {
    _roomController.dispose();
    super.dispose();
  }

  Future<void> _createRoom() async {
    final roomRef = _db.child('rooms').push();
    await roomRef.child('gridSize').set(widget.gridSize);
    await roomRef.child('moves').remove();
    final roomId = roomRef.key!;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => GamePage(
        gridSize: widget.gridSize,
        mode: GameMode.online,
        playerNames: ['Host', 'Guest'],
        roomId: roomId,
        isOnlineHost: true,
      ),
    ));
  }

  void _joinRoom() {
    final id = _roomController.text.trim();
    if (id.isEmpty) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => GamePage(
        gridSize: widget.gridSize,
        mode: GameMode.online,
        playerNames: ['Guest', 'Host'],
        roomId: id,
        isOnlineHost: false,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Online Lobby')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          ElevatedButton(onPressed: _createRoom, child: const Text('Create Room')),
          const SizedBox(height: 24),
          TextField(
            controller: _roomController,
            decoration: const InputDecoration(labelText: 'Enter Room ID'),
          ),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _joinRoom, child: const Text('Join Room')),
        ]),
      ),
    );
  }
}
