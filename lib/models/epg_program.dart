class EpgProgram {
  final String id;
  final String channelId;
  final String title;
  final String? description;
  final DateTime startTime;
  final DateTime endTime;

  const EpgProgram({
    required this.id,
    required this.channelId,
    required this.title,
    this.description,
    required this.startTime,
    required this.endTime,
  });

  bool get isCurrentlyAiring {
    final now = DateTime.now();
    return now.isAfter(startTime) && now.isBefore(endTime);
  }

  double get progress {
    final now = DateTime.now();
    if (now.isBefore(startTime)) return 0.0;
    if (now.isAfter(endTime)) return 1.0;
    final total = endTime.difference(startTime).inSeconds;
    if (total <= 0) return 0.0;
    final elapsed = now.difference(startTime).inSeconds;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'channelId': channelId,
        'title': title,
        'description': description,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
      };

  factory EpgProgram.fromJson(Map<String, dynamic> json) => EpgProgram(
        id: json['id']?.toString() ?? '',
        channelId: json['channelId']?.toString() ?? '',
        title: json['title'] as String? ?? 'Sem Título',
        description: json['description'] as String?,
        startTime: DateTime.tryParse(json['startTime'] as String? ?? '') ?? DateTime.now(),
        endTime: DateTime.tryParse(json['endTime'] as String? ?? '') ?? DateTime.now(),
      );
}
