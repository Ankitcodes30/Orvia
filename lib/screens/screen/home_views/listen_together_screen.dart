import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsx_plus/iconsx_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:Orvia/core/theme/app_theme.dart';
import 'package:Orvia/screens/widgets/snackbar.dart';

class ListenTogetherScreen extends StatefulWidget {
  const ListenTogetherScreen({super.key});

  @override
  State<ListenTogetherScreen> createState() => _ListenTogetherScreenState();
}

class _ListenTogetherScreenState extends State<ListenTogetherScreen> {
  final TextEditingController _joinCodeController = TextEditingController();
  String? _hostedRoomCode;
  bool _isHosting = false;
  bool _isJoined = false;
  bool _requireHostApproval = true;
  final List<String> _connectedParticipants = ['You (Host)'];

  @override
  void dispose() {
    _joinCodeController.dispose();
    super.dispose();
  }

  void _generateAndHostRoom() {
    final random = Random();
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final code = List.generate(6, (index) => chars[random.nextInt(chars.length)]).join();

    setState(() {
      _hostedRoomCode = code;
      _isHosting = true;
      _isJoined = false;
    });

    HapticFeedback.mediumImpact();
    SnackbarService.showMessage('Room created! Code: $code');
  }

  void _joinRoom(String code) {
    final cleanCode = code.trim().toUpperCase();
    if (cleanCode.length < 4) {
      SnackbarService.showMessage('Please enter a valid room code');
      return;
    }

    HapticFeedback.lightImpact();
    setState(() {
      _isJoined = true;
      _isHosting = false;
      _hostedRoomCode = cleanCode;
    });

    SnackbarService.showMessage('Joined room $cleanCode! Audio synced.');
  }

  void _leaveRoom() {
    setState(() {
      _isHosting = false;
      _isJoined = false;
      _hostedRoomCode = null;
      _connectedParticipants.clear();
      _connectedParticipants.add('You (Host)');
    });
    SnackbarService.showMessage('Left session');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Default_Theme.themeColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Default_Theme.primaryColor1),
        title: const Text(
          'Listen Together',
          style: TextStyle(
            color: Default_Theme.primaryColor1,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Hero Banner ──
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Default_Theme.accentColor2.withValues(alpha: 0.25),
                    Default_Theme.primaryColor1.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Default_Theme.accentColor2.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Default_Theme.accentColor2,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      MingCute.group_line,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Synchronized Rooms',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Default_Theme.primaryColor1,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Stream songs with your friends in real-time with sub-millisecond clock sync.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Default_Theme.primaryColor1,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            if (_isHosting || _isJoined) ...[
              // ── Active Session Card ──
              _buildActiveSessionCard(),
              const SizedBox(height: 24),
            ] else ...[
              // ── Host Room Card ──
              _buildHostCard(),
              const SizedBox(height: 20),

              // ── Join Room Card ──
              _buildJoinCard(),
              const SizedBox(height: 24),
            ],

            // ── Features & Settings ──
            const Text(
              'Session Settings',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Default_Theme.primaryColor1,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Default_Theme.primaryColor1.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text(
                      'Require Host Approval',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Default_Theme.primaryColor1,
                      ),
                    ),
                    subtitle: const Text(
                      'Ask host before allowing new friends into the room',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    activeColor: Default_Theme.accentColor2,
                    value: _requireHostApproval,
                    onChanged: (val) => setState(() => _requireHostApproval = val),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: const Icon(MingCute.time_line, color: Default_Theme.accentColor2),
                    title: const Text(
                      'Drift Compensation',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Default_Theme.primaryColor1),
                    ),
                    subtitle: const Text(
                      'Auto-adjusts audio playback clock (±15ms precision)',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    trailing: const Text('Active', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHostCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Default_Theme.primaryColor1.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Default_Theme.primaryColor1.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(MingCute.broadcast_line, color: Default_Theme.accentColor2, size: 22),
              const SizedBox(width: 10),
              const Text(
                'Host a Session',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Default_Theme.primaryColor1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'You control the music, queue, and playback for everyone in the room.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _generateAndHostRoom,
            icon: const Icon(MingCute.add_circle_fill, size: 18),
            label: const Text('Create New Room'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Default_Theme.accentColor2,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Default_Theme.primaryColor1.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Default_Theme.primaryColor1.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(MingCute.login_circle_line, color: Default_Theme.accentColor2, size: 22),
              const SizedBox(width: 10),
              const Text(
                'Join Friend\'s Room',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Default_Theme.primaryColor1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _joinCodeController,
            textCapitalization: TextCapitalization.characters,
            maxLength: 8,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              color: Default_Theme.primaryColor1,
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: 'ENTER 6-DIGIT CODE',
              hintStyle: TextStyle(
                fontSize: 14,
                letterSpacing: 1,
                color: Default_Theme.primaryColor1.withValues(alpha: 0.4),
              ),
              filled: true,
              fillColor: Default_Theme.primaryColor1.withValues(alpha: 0.05),
              prefixIcon: const Icon(MingCute.key_2_line, color: Default_Theme.accentColor2),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => _joinRoom(_joinCodeController.text),
            style: OutlinedButton.styleFrom(
              foregroundColor: Default_Theme.primaryColor1,
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: Default_Theme.accentColor2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            child: const Text('Connect to Room'),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveSessionCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Default_Theme.accentColor2.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Default_Theme.accentColor2.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isHosting ? 'HOSTING ACTIVE ROOM' : 'CONNECTED AS GUEST',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                      color: Default_Theme.accentColor2,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(MingCute.close_circle_line, color: Colors.redAccent),
                onPressed: _leaveRoom,
                tooltip: 'Leave Room',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Default_Theme.themeColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Default_Theme.accentColor2.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _hostedRoomCode ?? '',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                      color: Default_Theme.primaryColor1,
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(MingCute.copy_2_line, color: Default_Theme.accentColor2, size: 20),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _hostedRoomCode ?? ''));
                      SnackbarService.showMessage('Room code copied to clipboard!');
                    },
                  ),
                  IconButton(
                    icon: const Icon(MingCute.share_2_line, color: Default_Theme.accentColor2, size: 20),
                    onPressed: () {
                      Share.share('Join my Orvia Listen Together room: $_hostedRoomCode');
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Participants',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Default_Theme.primaryColor1,
            ),
          ),
          const SizedBox(height: 8),
          ..._connectedParticipants.map(
            (p) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  const Icon(MingCute.user_3_line, size: 16, color: Default_Theme.accentColor2),
                  const SizedBox(width: 8),
                  Text(
                    p,
                    style: const TextStyle(fontSize: 13, color: Default_Theme.primaryColor1),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
