import 'package:flutter/material.dart';

class PlayerIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final Color color;

  const PlayerIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.size = 28.0,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: onPressed == null ? Colors.white24 : color, size: size),
      onPressed: onPressed,
      tooltip: tooltip,
      splashRadius: 24,
    );
  }
}
