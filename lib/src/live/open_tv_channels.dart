import 'channel_identity.dart';

// The remote directory describes genres, not terrestrial distribution.
// Keep known open-TV identities separate from News/Kids/Sports brands.
class OpenTvChannels {
  static const _ids = <String>{
    'redeglobo', 'tvglobosaopaulo', 'tvmorena', 'globo', 'globoms',
    'sbtnacional', 'sbt', 'sbtms', 'sbtinterior', 'sbtcuiaba',
    'sbtnovamutum', 'sbtrondonopolis',
    'record', 'recordms', 'recordrs', 'band', 'bandms',
    'redetv', 'redetvparana', 'tvbrasil', 'tvcultura',
    'tvpantanalms', 'tvguanandi', 'tvms',
  };

  static const _names = <String>{
    'globo', 'rede globo', 'tv globo sao paulo', 'tv morena',
    'globo ms', 'sbt', 'sbt nacional', 'sbt ms', 'sbt interior',
    'sbt cuiaba', 'sbt nova mutum', 'sbt rondonopolis',
    'record', 'record tv', 'record ms', 'record rs',
    'band', 'band ms', 'rede tv!', 'redetv!', 'redetv! parana',
    'tv brasil', 'tv cultura', 'tv pantanal ms', 'tv guanandi', 'tv ms',
  };

  static bool matches({required String name, String? tvgId}) {
    final id = tvgId?.split('@').first.split('.').first.toLowerCase();
    if (id != null && _ids.contains(id)) return true;
    final normalized = channelIdentity(name)
        .replaceAll(RegExp(r'\s*\[geo-blocked\]'), '').trim();
    return _names.contains(normalized);
  }
}
