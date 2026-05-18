class HomeBannerItem {
  const HomeBannerItem({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.actionType,
    required this.sortOrder,
    this.subtitle,
    this.actionValue,
  });

  final String id;
  final String title;
  final String? subtitle;
  final String imageUrl;
  final String actionType;
  final String? actionValue;
  final int sortOrder;

  bool get hasAction => actionType.trim().isNotEmpty && actionType != 'none';

  String resolvedImageUrl(String apiBaseUrl) {
    final parsed = Uri.tryParse(imageUrl);
    if (parsed?.hasScheme == true) {
      return imageUrl;
    }

    final normalizedBaseUrl = apiBaseUrl.endsWith('/')
        ? apiBaseUrl
        : '$apiBaseUrl/';
    return Uri.parse(normalizedBaseUrl).resolve(imageUrl).toString();
  }

  factory HomeBannerItem.fromJson(Map<String, dynamic> json) {
    return HomeBannerItem(
      id: '${json['id'] ?? ''}',
      title: _normalizedString(json['title']) ?? 'GESIT',
      subtitle: _normalizedString(json['subtitle']),
      imageUrl: _normalizedString(json['image_url']) ?? '',
      actionType: _normalizedString(json['action_type']) ?? 'none',
      actionValue: _normalizedString(json['action_value']),
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}

List<HomeBannerItem> homeBannerItemsFromPayload(Object? payload) {
  if (payload is! List) {
    return const [];
  }

  return payload
      .whereType<Map<String, dynamic>>()
      .map(HomeBannerItem.fromJson)
      .where(
        (banner) =>
            banner.id.trim().isNotEmpty && banner.imageUrl.trim().isNotEmpty,
      )
      .toList(growable: false);
}

String? _normalizedString(Object? value) {
  final normalized = value?.toString().trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }

  return normalized;
}
