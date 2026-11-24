import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsx_plus/iconsx_plus.dart';
import 'package:Orvia/blocs/media_player/orvia_player_cubit.dart';
import 'package:Orvia/core/theme/app_theme.dart';

void showTempoPitchSheet(BuildContext context) {
  final player = context.read<OrviaPlayerCubit>().orviaPlayer;

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (modalContext) {
      return _TempoPitchSheetContent(player: player);
    },
  );
}

class _TempoPitchSheetContent extends StatefulWidget {
  final dynamic player;

  const _TempoPitchSheetContent({required this.player});

  @override
  State<_TempoPitchSheetContent> createState() => _TempoPitchSheetContentState();
}

class _TempoPitchSheetContentState extends State<_TempoPitchSheetContent> {
  late double _currentSpeed;
  late double _currentPitch;

  @override
  void initState() {
    super.initState();
    _currentSpeed = widget.player.speed;
    _currentPitch = widget.player.pitch;
  }

  // Convert pitch factor (0.5..2.0) to approximate semitones (-12..+12)
  int get _semitones => (12.0 * (math.log(_currentPitch) / math.ln2)).round();

  double _semitonesToPitch(int semitones) => math.pow(2.0, semitones / 12.0).toDouble();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: Default_Theme.themeColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: Default_Theme.primaryColor1.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Default_Theme.primaryColor1.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header with Reset button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.speed_rounded,
                      color: Default_Theme.accentColor2,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Tempo & Pitch',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Default_Theme.primaryColor1,
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _currentSpeed = 1.0;
                      _currentPitch = 1.0;
                    });
                    widget.player.setSpeed(1.0);
                    widget.player.setPitch(1.0);
                  },
                  icon: const Icon(MingCute.refresh_3_line, size: 16),
                  label: const Text('Reset'),
                  style: TextButton.styleFrom(
                    foregroundColor: Default_Theme.accentColor2,
                    textStyle: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Speed (Tempo) Section ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Playback Speed (Tempo)',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Default_Theme.primaryColor1,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Default_Theme.accentColor2.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_currentSpeed.toStringAsFixed(2)}x',
                    style: const TextStyle(
                      color: Default_Theme.accentColor2,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            Slider(
              value: _currentSpeed.clamp(0.5, 2.0),
              min: 0.5,
              max: 2.0,
              divisions: 30,
              activeColor: Default_Theme.accentColor2,
              inactiveColor: Default_Theme.primaryColor1.withValues(alpha: 0.2),
              onChanged: (val) {
                setState(() => _currentSpeed = val);
                widget.player.setSpeed(val);
              },
            ),
            // Speed Preset Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [0.75, 1.0, 1.25, 1.5, 2.0].map((spd) {
                  final isSelected = (_currentSpeed - spd).abs() < 0.04;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('${spd}x'),
                      selected: isSelected,
                      selectedColor: Default_Theme.accentColor2,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Default_Theme.primaryColor1,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      onSelected: (_) {
                        setState(() => _currentSpeed = spd);
                        widget.player.setSpeed(spd);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),

            // ── Pitch Section ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Pitch Shift',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Default_Theme.primaryColor1,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Default_Theme.accentColor2.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _semitones == 0 ? 'Normal' : '${_semitones > 0 ? "+" : ""}$_semitones st',
                    style: const TextStyle(
                      color: Default_Theme.accentColor2,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            Slider(
              value: _semitones.toDouble().clamp(-12.0, 12.0),
              min: -12.0,
              max: 12.0,
              divisions: 24,
              activeColor: Default_Theme.accentColor2,
              inactiveColor: Default_Theme.primaryColor1.withValues(alpha: 0.2),
              onChanged: (val) {
                final st = val.round();
                final p = _semitonesToPitch(st);
                setState(() => _currentPitch = p);
                widget.player.setPitch(p);
              },
            ),
            // Pitch Preset Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [-4, -2, 0, 2, 4].map((st) {
                  final isSelected = _semitones == st;
                  final label = st == 0 ? 'Normal (0)' : '${st > 0 ? "+" : ""}$st st';
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: isSelected,
                      selectedColor: Default_Theme.accentColor2,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Default_Theme.primaryColor1,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      onSelected: (_) {
                        final p = _semitonesToPitch(st);
                        setState(() => _currentPitch = p);
                        widget.player.setPitch(p);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
