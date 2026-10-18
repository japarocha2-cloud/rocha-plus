import 'package:shared_preferences/shared_preferences.dart';

class AdMetricsRepository {
  static String _impressionKey(String campaignId) =>
      'ad.$campaignId.impressions';
  static String _clickKey(String campaignId) => 'ad.$campaignId.clicks';

  Future<void> recordImpression(String campaignId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _impressionKey(campaignId);
    await prefs.setInt(key, (prefs.getInt(key) ?? 0) + 1);
  }

  Future<void> recordClick(String campaignId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _clickKey(campaignId);
    await prefs.setInt(key, (prefs.getInt(key) ?? 0) + 1);
  }

  Future<({int impressions, int clicks})> read(String campaignId) async {
    final prefs = await SharedPreferences.getInstance();
    return (
      impressions: prefs.getInt(_impressionKey(campaignId)) ?? 0,
      clicks: prefs.getInt(_clickKey(campaignId)) ?? 0,
    );
  }
}
