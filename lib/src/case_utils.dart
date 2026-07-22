final _wordPattern = RegExp(r'[A-Za-z0-9]+');

class NameCases {
  NameCases(String input) : words = _splitWords(input);

  final List<String> words;

  String get snake => words.map((word) => word.toLowerCase()).join('_');

  String get pascal => words.map(_capitalize).join();

  String get camel {
    if (words.isEmpty) return '';
    final first = words.first.toLowerCase();
    return '$first${words.skip(1).map(_capitalize).join()}';
  }

  String get title => words.map(_capitalize).join(' ');
}

List<String> _splitWords(String input) {
  final spaced = input.replaceAllMapped(
    RegExp(r'([a-z0-9])([A-Z])'),
    (match) => '${match.group(1)} ${match.group(2)}',
  );
  return _wordPattern
      .allMatches(spaced)
      .map((match) => match.group(0)!)
      .where((word) => word.isNotEmpty)
      .toList(growable: false);
}

String _capitalize(String word) {
  if (word.isEmpty) return word;
  return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
}

int stableHiveTypeId(String input) {
  var hash = 0x811c9dc5;
  for (final codeUnit in input.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash % 65440;
}
