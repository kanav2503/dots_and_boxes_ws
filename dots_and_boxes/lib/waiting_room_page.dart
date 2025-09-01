// lib/waiting_room_page.dart
//
// Simple waiting room around a Firebase RTDB room.
// - Host creates the room elsewhere and lands here with roomId/isHost.
// - Guest lands here, writes their name into players/{uid}, and waits.
// - When host sets `started: true`, both sides navigate into GamePage.
//
// Assumes a 2-player match once started.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'game_page.dart';

class WaitingRoomPage extends StatefulWidget {
  final int gridSize;
  final String roomId;
  final bool isHost;
  final String playerName;

  const WaitingRoomPage({
    Key? key,
    required this.gridSize,
    required this.roomId,
    required this.isHost,
    required this.playerName,
  }) : super(key: key);

  @override
  State<WaitingRoomPage> createState() => _WaitingRoomPageState();
}

class _WaitingRoomPageState extends State<WaitingRoomPage> {
  late final DatabaseReference _roomRef;
  Map<String, String> _players = {};
  bool _started = false;
  // TO DO: keep a StreamSubscription handle and cancel in dispose().

  @override
  void initState() {
    super.initState();

    // RTDB reference for this room.
    _roomRef = FirebaseDatabase.instance.ref('rooms/${widget.roomId}');

    // Guest registers their display name under players/{uid}.
    if (!widget.isHost) {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      debugPrint('[WaitingRoom] Guest writing: $uid → ${widget.playerName}');
      _roomRef
          .child('players/$uid')
          .set(widget.playerName)
          .then((_) => debugPrint('[WaitingRoom] Guest write succeeded'))
          .catchError((e) => debugPrint('[WaitingRoom] Guest write failed: $e'));
      // NOTE: last write wins if a user re-enters with a different name.
    }

    // Listen to the entire room snapshot; keeps players + started in sync.
    _roomRef.onValue.listen((event) {
      final raw = event.snapshot.value;
      debugPrint('[WaitingRoom:onValue] raw snapshot.value: $raw');

      // Defensive map parsing (snapshot.value can be LinkedMap etc.).
      final data = <String, dynamic>{};
      if (raw is Map) {
        raw.forEach((k, v) => data[k.toString()] = v);
      }

      // Extract players as <String, String>.
      final Map<String, String> newPlayers = {};
      final playersRaw = data['players'];
      if (playersRaw is Map) {
        playersRaw.forEach((k, v) {
          newPlayers[k.toString()] = v.toString();
        });
      }

      // Extract started flag (treat strict true as started).
      final bool newStarted = data['started'] == true;

      setState(() {
        _players = newPlayers;
        _started = newStarted;
      });

      debugPrint('[WaitingRoom] Parsed players=$_players started=$_started');

      // Host pressed Start → navigate to game.
      if (_started) {
        // NOTE: Map iteration order is not guaranteed; if host must be index 0,
        // derive names in host/guest order explicitly instead of values.toList().
        final names = _players.values.toList();
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => GamePage(
            gridSize: widget.gridSize,
            mode: GameMode.online,
            playerNames: names,
            roomId: widget.roomId,
            isOnlineHost: widget.isHost,
          ),
        ));
      }
    }, onError: (err) {
      debugPrint('[WaitingRoom:onValue] ERROR: $err');
    });
  }

  Future<void> _startGame() async {
    if (_players.length < 2) {
      debugPrint('[WaitingRoom] Cannot start: only ${_players.length} player(s)');
      return;
    }
    debugPrint('[WaitingRoom] Host starting game');
    await _roomRef.child('started').set(true);
    // NOTE: Navigation happens via the onValue listener above.
    // TO DO: Consider also writing a canonical host/guest order to the room
    // (e.g., {hostUid, guestUid}) so GamePage gets consistent indexing.
  }

  @override
  Widget build(BuildContext context) {
    final names = _players.values.toList();
    final canStart = widget.isHost && !_started && names.length >= 2;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Waiting Room'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy Room ID',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: widget.roomId));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Room ID copied!')),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            SelectableText(
              'Room ID:\n${widget.roomId}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 24),

            const Text('Players Joined:', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            if (names.isEmpty)
              const Text('None yet…', style: TextStyle(fontSize: 18))
            else
              for (var name in names)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(name, style: const TextStyle(fontSize: 18)),
                ),

            const Spacer(),

            if (canStart)
              ElevatedButton(
                onPressed: _startGame,
                child: const Text('Start Game'),
              )
            else if (widget.isHost)
              Text(
                names.length < 2
                    ? 'Waiting for at least 2 players…'
                    : 'Ready to start when you are',
                style: const TextStyle(fontSize: 16),
              )
            else
              const Text(
                'Waiting for host to start…',
                style: TextStyle(fontSize: 16),
              ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// NOTES:
// - Listener lifetime: store the StreamSubscription and cancel in dispose()
//   if this page can be popped without starting the game.
// - Ordering: if GamePage expects host=0/guest=1, write those explicitly to RTDB
//   (or pass a sorted list) rather than relying on map value order.
// - Security rules: restrict read/write to room members; consider TTL/cleanup
//   for abandoned rooms.
