class Channel {
  final String id;
  final String name;
  final String streamUrl;
  final String? logoUrl;
  final String? categoryId;
  final String? categoryName;
  final String? tvgId;
  final String? tvgName;
  final int? streamId;

  const Channel({
    required this.id,
    required this.name,
    required this.streamUrl,
    this.logoUrl,
    this.categoryId,
    this.categoryName,
    this.tvgId,
    this.tvgName,
    this.streamId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'streamUrl': streamUrl,
        'logoUrl': logoUrl,
        'categoryId': categoryId,
        'categoryName': categoryName,
        'tvgId': tvgId,
        'tvgName': tvgName,
        'streamId': streamId,
      };

  factory Channel.fromJson(Map<String, dynamic> json) => Channel(
        id: json['id']?.toString() ?? '',
        name: json['name'] as String? ?? 'Sem Nome',
        streamUrl: json['streamUrl'] as String? ?? '',
        logoUrl: json['logoUrl'] as String?,
        categoryId: json['categoryId']?.toString(),
        categoryName: json['categoryName'] as String?,
        tvgId: json['tvgId'] as String?,
        tvgName: json['tvgName'] as String?,
        streamId: json['streamId'] is int
            ? json['streamId'] as int
            : int.tryParse(json['streamId']?.toString() ?? ''),
      );
}
