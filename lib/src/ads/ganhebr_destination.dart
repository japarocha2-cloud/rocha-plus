import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// GanheBR destination for the approved *mobile-only* commercial slot.
/// Never launches automatically. The caller must confirm adult eligibility
/// and invoke this only from an intentional tap on the banner artwork.
const ganheBrReferralUrl = 'http://www.ganhebr35.com/?r=arp0240';

Future<bool> openGanheBrBanner({
  required bool verifiedAdult,
  required bool mobilePhoneLayout,
}) async {
  if (!verifiedAdult || !mobilePhoneLayout || kIsWeb) return false;
  final uri = Uri.parse(ganheBrReferralUrl);
  if (uri.host != 'www.ganhebr35.com' ||
      uri.queryParameters['r'] != 'arp0240') return false;
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
