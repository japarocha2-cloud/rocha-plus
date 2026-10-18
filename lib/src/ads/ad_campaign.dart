enum AdPlacement { homePremium, newsRegional }

class AdCampaign {
  final String id;
  final String advertiser;
  final String title;
  final String imageUrl;
  final String destinationUrl;
  final AdPlacement placement;
  final DateTime startsAt;
  final DateTime endsAt;

  const AdCampaign({
    required this.id,
    required this.advertiser,
    required this.title,
    required this.imageUrl,
    required this.destinationUrl,
    required this.placement,
    required this.startsAt,
    required this.endsAt,
  });

  bool isActiveAt(DateTime now) =>
      !now.isBefore(startsAt) && now.isBefore(endsAt);
}
