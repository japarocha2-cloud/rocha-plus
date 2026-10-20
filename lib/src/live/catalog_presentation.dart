import 'channel.dart';
import 'channel_identity.dart';

const labCategories = [
  'TV ao Vivo',
  'Esportes',
  'Infantil',
  'Notícias',
  'Filmes',
  'Séries',
  'Documentários',
  'Música',
  'Educação',
  'Cultura',
  'Entretenimento',
  'Religiosos',
  'Futebol',
  'Outros',
];

String displayCategory(String group) =>
    group == 'TV aberta' ? 'TV ao Vivo' : group;
String repositoryCategory(String group) =>
    group == 'TV ao Vivo' ? 'TV aberta' : group;

// Editorial priority, never an assertion of measured audience ratings.
const _priority = <String, List<String>>{
  'TV ao Vivo': [
    r'globo|tv morena',
    r'sbt',
    r'record(?:tv)?',
    r'band',
    r'rede\s*tv',
    r'(?:tv )?cultura|cultura fast',
    r'tv brasil',
  ],
  'Esportes': [
    r'sportv',
    r'espn',
    r'premiere',
    r'caze\s*tv',
    r'combate',
    r'n sports',
  ],
  'Futebol': [r'premiere', r'sportv', r'espn', r'caze\s*tv'],
  'Infantil': [
    r'cartoon network',
    r'disney channel',
    r'nickelodeon',
    r'discovery kids',
    r'gloob',
    r'turma da monica',
    r'pluto tv kids',
    r'pluto tv junior',
    r'sbt kids',
    r'tooncast',
    r'babyfirst',
  ],
  'Notícias': [
    r'globo\s*news',
    r'cnn brasil',
    r'record news|pluto tv record news',
    r'band\s*news',
    r'jovem pan',
    r'sbt news',
  ],
  'Filmes': [
    r'telecine',
    r'hbo',
    r'megapix',
    r'tnt',
    r'space',
    r'cinemax',
    r'paramount',
    r'axn movies',
    r'star movies',
  ],
  'Séries': [r'warner', r'sony', r'axn', r'universal', r'star channel'],
  'Documentários': [
    r'discovery',
    r'national geographic|nat geo',
    r'history',
    r'animal planet',
  ],
  'Música': [r'mtv', r'bis', r'multishow', r'trace brazuca'],
};

int _rank(Channel c) {
  final rules = _priority[displayCategory(c.group)] ?? const <String>[];
  final name = channelIdentity(c.name);
  final index = rules.indexWhere(
    (r) => RegExp('^(?:$r)(?=\\W|\\d|\$)').hasMatch(name),
  );
  return index < 0 ? rules.length : index;
}

List<Channel> popularChannelsFirst(Iterable<Channel> channels) =>
    channels.toList()..sort((a, b) {
      final groupA = labCategories.indexOf(displayCategory(a.group));
      final groupB = labCategories.indexOf(displayCategory(b.group));
      final category = (groupA < 0 ? labCategories.length : groupA).compareTo(
        groupB < 0 ? labCategories.length : groupB,
      );
      if (category != 0) return category;
      final priority = _rank(a).compareTo(_rank(b));
      if (priority != 0) return priority;
      final name = channelIdentity(a.name).compareTo(channelIdentity(b.name));
      return name != 0 ? name : a.url.compareTo(b.url);
    });
