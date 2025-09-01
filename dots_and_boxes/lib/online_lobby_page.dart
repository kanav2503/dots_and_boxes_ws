// lib/online_lobby_page.dart
//
// Minimal lobby for creating/joining a room in RTDB.
// - Host creates a room and waits.
// - Guest joins by Room ID.
// - When host flips `started: true`, both navigate into GamePage.
//
// Assumes 2-player online games even though the lobby allows up to 4 names.
// (GamePage.online currently uses exactly two players: host + first guest.)

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'game_page.dart';

class OnlineLobbyPage extends StatefulWidget {
  final int gridSize;
  const OnlineLobbyPage({Key? key, required this.gridSize}) : super(key: key);

  @override
  State<OnlineLobbyPage> createState() => _OnlineLobbyPageState();
}

class _OnlineLobbyPageState extends State<OnlineLobbyPage> {
  final _nameController = TextEditingController();
  final _roomController = TextEditingController();

  String? _myUid;
  String? _hostUid;
  String? _currentRoomId;
  bool _amHost = false;
  bool _isLoading = false;
  bool _hasNavigated = false; // prevents double navigation on multiple events

  @override
  void initState() {
    super.initState();
    // Grab a UID for RTDB rules. Keeps this screen self-contained.
    // NOTE: If the app already signed in in main(), this re-sign is harmless.
    FirebaseAuth.instance.signInAnonymously().then((cred) {
      setState(() => _myUid = cred.user!.uid);
    }).catchError((e) {
      // TO DO: surface auth failures nicely.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Auth failed: $e')),
      );
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roomController.dispose();
    // TO DO: If you keep any StreamSubscription references, cancel them here.
    super.dispose();
  }

  Future<void> _createRoom() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name.')),
      );
      return;
    }
    setState(() => _isLoading = true);

    final roomsRef = FirebaseDatabase.instance.ref('rooms');
    final newRoomRef = roomsRef.push();
    final roomId = newRoomRef.key!;

    // Initial room payload. `moves` starts empty; players is a map uid->name.
    await newRoomRef.set({
      'started': false,
      'players': { _myUid!: name },
      'moves': null,
    });

    // Host state.
    setState(() {
      _isLoading = false;
      _currentRoomId = roomId;
      _amHost = true;
      _hostUid = _myUid;
      _roomController.text = roomId; // show/shareable ID
    });

    _listenForStart(roomId);
  }

  Future<void> _joinRoom() async {
    final name = _nameController.text.trim();
    final roomId = _roomController.text.trim();
    if (name.isEmpty || roomId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter both name and Room ID.')),
      );
      return;
    }
    setState(() => _isLoading = true);

    final roomRef = FirebaseDatabase.instance.ref('rooms/$roomId');
    final snap = await roomRef.get();
    if (!snap.exists) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Room not found.')));
      return;
    }

    // `snap.value` can be a LinkedMap; treat loosely.
    final data = snap.value as Map?;
    final rawPlayers = data?['players'] as Map?;
    final count = rawPlayers?.length ?? 0;

    // NOTE: Lobby UI says up to 4, but GamePage.online uses 2 players.
    // You may want to cap to 2 here to avoid confusion.
    if (count >= 4) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Room is full.')));
      return;
    }

    // Host is the first key that created the room.
    final hostUid = rawPlayers!.keys.first.toString();

    // Register this user.
    await roomRef.child('players/$_myUid').set(name);

    setState(() {
      _isLoading = false;
      _currentRoomId = roomId;
      _amHost = false;
      _hostUid = hostUid;
    });

    _listenForStart(roomId);
  }

  void _listenForStart(String roomId) {
    // Listen to /rooms/{id}/started; once it flips true, navigate.
    // NOTE: We don't keep the subscription handle; rely on _hasNavigated to avoid duplicates.
    FirebaseDatabase.instance
        .ref('rooms/$roomId/started')
        .onValue
        .listen((event) {
      final started = event.snapshot.value;
      if (started == true && !_hasNavigated) {
        _hasNavigated = true;
        _navigateToGame();
      }
    });
  }

  Future<void> _startGame() async {
    final roomId = _currentRoomId;
    if (roomId == null) return;

    // Host flips the flag. Guests will also see it and navigate via listener.
    await FirebaseDatabase.instance
        .ref('rooms/$roomId')
        .update({'started': true});

    // Navigation happens via _listenForStart for both sides.
  }

  Future<void> _navigateToGame() async {
    final roomId = _currentRoomId!;
    final hostUid = _hostUid!;

    // Pull the final players map so we can pass names into GamePage.
    final playersSnap =
        await FirebaseDatabase.instance.ref('rooms/$roomId/players').get();
    final raw = playersSnap.value as Map;

    // Normalize to <String,String>
    final players = <String, String>{};
    raw.forEach((k, v) => players[k.toString()] = v.toString());

    final hostName = players[hostUid]!;
    // For two-player: guest is whoever isn't the host.
    final guestUid = players.keys.firstWhere((u) => u != hostUid);
    final guestName = players[guestUid]!;

    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => GamePage(
        gridSize: widget.gridSize,
        mode: GameMode.online,
        playerNames: [hostName, guestName],
        roomId: roomId,
        isOnlineHost: _amHost,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final inRoom = _currentRoomId != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Online Lobby')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Always ask for a display name.
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Your name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Room ID input (join) or display (created room).
            TextField(
              controller: _roomController,
              decoration: InputDecoration(
                labelText: inRoom ? 'Room ID' : 'Enter Room ID to join',
                border: const OutlineInputBorder(),
              ),
              readOnly: inRoom,
            ),
            const SizedBox(height: 16),

            // Create / Join or live player list + Start button (host only).
            if (!inRoom) ...[
              ElevatedButton(
                onPressed: _isLoading ? null : _createRoom,
                child: const Text('Create Room'),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _isLoading ? null : _joinRoom,
                child: const Text('Join Room'),
              ),
            ] else ...[
              // Live players list for the current room.
              StreamBuilder<DatabaseEvent>(
                stream: FirebaseDatabase.instance
                    .ref('rooms/$_currentRoomId/players')
                    .onValue,
                builder: (ctx, snap) {
                  final raw = snap.hasData && snap.data!.snapshot.value is Map
                      ? Map<dynamic, dynamic>.from(
                          snap.data!.snapshot.value as Map)
                      : <dynamic, dynamic>{};

                  final names = raw.values.map((v) => v.toString()).toList();
                  final count = names.length;

                  return Column(
                    children: [
                      Text('Players: ${names.join(', ')}'),
                      const SizedBox(height: 12),
                      if (_amHost)
                        // Only host can start; require >= 2 players.
                        ElevatedButton(
                          onPressed: count >= 2 ? _startGame : null,
                          child: Text('Start Game ($count/4)'),
                        )
                      else
                        const Text(
                          'Waiting for host to start…',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontStyle: FontStyle.italic),
                        ),
                    ],
                  );
                },
              ),
            ],

            if (_isLoading) ...[
              const SizedBox(height: 20),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }
}

// NOTES:
// - Security rules: ensure only room members can read/write for that room.
// - Cleanup: consider deleting empty rooms or stale players on back/timeout.
// - Two-player assumption: GamePage.online uses exactly 2 names. If you keep
//   lobby at 4 players, decide which 2 get into the match or spin up sub-rooms.
// - Subscriptions: If you add more listeners, keep references and cancel them
//   in dispose() to avoid leaks when navigating back/forth.
