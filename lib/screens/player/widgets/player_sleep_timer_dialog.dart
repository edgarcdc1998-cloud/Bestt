import 'package:flutter/material.dart';

class PlayerSleepTimerDialog extends StatelessWidget {
  final int? currentMinutes;
  final ValueChanged<int?> onSelected;

  const PlayerSleepTimerDialog({
    super.key,
    required this.currentMinutes,
    required this.onSelected,
  });

  static const List<int?> _options = [null, 15, 30, 45, 60, 90, 120];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined, color: Colors.redAccent, size: 24),
                  const SizedBox(width: 10),
                  const Text(
                    'Temporizador de Sono (Sleep Timer)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12),
            ..._options.map((mins) {
              final isSelected = currentMinutes == mins;
              final label = mins == null ? 'Desativado' : '$mins minutos';

              return ListTile(
                leading: Icon(
                  isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: isSelected ? Colors.redAccent : Colors.white54,
                ),
                title: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                onTap: () {
                  onSelected(mins);
                  Navigator.of(context).pop();
                },
              );
            }),
          ],
        ),
      ),
    );
  }
}
