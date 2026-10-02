import 'package:flutter/material.dart';

class PlayerGradients {
  static const topGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Colors.black87,
      Colors.black45,
      Colors.transparent,
    ],
  );

  static const bottomGradient = LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    colors: [
      Colors.black87,
      Colors.black54,
      Colors.transparent,
    ],
  );
}
