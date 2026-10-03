import 'dart:async';
import 'package:flutter/material.dart';

class PlayerGestureDetector extends StatefulWidget {
  final Widget child;
  final bool isLocked;
  final bool isLive;
  final VoidCallback onTap;
  final VoidCallback onDoubleTapLeft;
  final VoidCallback onDoubleTapRight;
  final ValueChanged<double> onVolumeChange;
  final ValueChanged<double> onBrightnessChange;
  final double currentVolume;
  final double currentBrightness;

  const PlayerGestureDetector({
    super.key,
    required this.child,
    required this.isLocked,
    required this.isLive,
    required this.onTap,
    required this.onDoubleTapLeft,
    required this.onDoubleTapRight,
    required this.onVolumeChange,
    required this.onBrightnessChange,
    required this.currentVolume,
    required this.currentBrightness,
  });

  @override
  State<PlayerGestureDetector> createState() => _PlayerGestureDetectorState();
}

class _PlayerGestureDetectorState extends State<PlayerGestureDetector> {
  // HUD Indicators
  bool _showVolumeIndicator = false;
  bool _showBrightnessIndicator = false;
  bool _showSeekLeftIndicator = false;
  bool _showSeekRightIndicator = false;

  double _gestureVolume = 1.0;
  double _gestureBrightness = 0.5;

  Timer? _hideIndicatorsTimer;
  Timer? _hideSeekTimer;

  @override
  void initState() {
    super.initState();
    _gestureVolume = widget.currentVolume;
    _gestureBrightness = widget.currentBrightness;
  }

  void _showFeedback({bool isVolume = false, bool isBrightness = false}) {
    _hideIndicatorsTimer?.cancel();
    setState(() {
      if (isVolume) _showVolumeIndicator = true;
      if (isBrightness) _showBrightnessIndicator = true;
    });

    _hideIndicatorsTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() {
          _showVolumeIndicator = false;
          _showBrightnessIndicator = false;
        });
      }
    });
  }

  void _triggerSeekFeedback({required bool isLeft}) {
    _hideSeekTimer?.cancel();
    setState(() {
      if (isLeft) {
        _showSeekLeftIndicator = true;
        _showSeekRightIndicator = false;
      } else {
        _showSeekRightIndicator = true;
        _showSeekLeftIndicator = false;
      }
    });

    _hideSeekTimer = Timer(const Duration(milliseconds: 650), () {
      if (mounted) {
        setState(() {
          _showSeekLeftIndicator = false;
          _showSeekRightIndicator = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _hideIndicatorsTimer?.cancel();
    _hideSeekTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLocked) {
      return widget.child;
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Touch detector
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: widget.onTap,
          onDoubleTapDown: (details) {
            final screenWidth = MediaQuery.of(context).size.width;
            if (details.globalPosition.dx < screenWidth / 2) {
              if (!widget.isLive) {
                _triggerSeekFeedback(isLeft: true);
                widget.onDoubleTapLeft();
              }
            } else {
              if (!widget.isLive) {
                _triggerSeekFeedback(isLeft: false);
                widget.onDoubleTapRight();
              }
            }
          },
          onVerticalDragUpdate: (details) {
            final screenWidth = MediaQuery.of(context).size.width;
            final isLeft = details.globalPosition.dx < screenWidth / 2;
            final delta = -details.primaryDelta! / 200.0;

            if (isLeft) {
              // Brightness (Left side)
              _gestureBrightness = (_gestureBrightness + delta).clamp(0.0, 1.0);
              widget.onBrightnessChange(_gestureBrightness);
              _showFeedback(isBrightness: true);
            } else {
              // Volume (Right side)
              _gestureVolume = (_gestureVolume + delta).clamp(0.0, 1.0);
              widget.onVolumeChange(_gestureVolume);
              _showFeedback(isVolume: true);
            }
          },
          child: widget.child,
        ),

        // Seek -10s Ripple Feedback
        if (_showSeekLeftIndicator)
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.only(left: 60),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white38),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.replay_10, color: Colors.white, size: 40),
                  SizedBox(height: 4),
                  Text('-10s', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ),
          ),

        // Seek +10s Ripple Feedback
        if (_showSeekRightIndicator)
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              margin: const EdgeInsets.only(right: 60),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white38),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.forward_10, color: Colors.white, size: 40),
                  SizedBox(height: 4),
                  Text('+10s', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ),
          ),

        // Volume HUD Center-Right
        if (_showVolumeIndicator)
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _gestureVolume == 0
                        ? Icons.volume_off
                        : (_gestureVolume < 0.5 ? Icons.volume_down : Icons.volume_up),
                    color: Colors.white,
                    size: 36,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: 120,
                    child: LinearProgressIndicator(
                      value: _gestureVolume,
                      backgroundColor: Colors.white24,
                      color: Colors.redAccent,
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${(_gestureVolume * 100).toInt()}%',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),

        // Brightness HUD Center-Left
        if (_showBrightnessIndicator)
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _gestureBrightness < 0.3
                        ? Icons.brightness_low
                        : (_gestureBrightness < 0.7 ? Icons.brightness_medium : Icons.brightness_high),
                    color: Colors.amberAccent,
                    size: 36,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: 120,
                    child: LinearProgressIndicator(
                      value: _gestureBrightness,
                      backgroundColor: Colors.white24,
                      color: Colors.amberAccent,
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${(_gestureBrightness * 100).toInt()}%',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
