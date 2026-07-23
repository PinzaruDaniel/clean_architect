import 'dart:io';

import 'package:clean_architect/clean_architect.dart';
import 'package:test/test.dart';

void main() {
  test('README configuration and output manifests match the generator', () {
    final generator = CleanArchitectGenerator(CleanArchitectConfig.defaults());
    final contracts = <String, String>{
      'default-config': _fence(
        'yaml',
        CleanArchitectConfig.defaultYaml().trim(),
      ),
      'architecture': _manifest(generator.architecture()),
      'auth': _manifest(generator.auth()),
      'feature-orders': _manifest(generator.feature('orders')),
      'remote-operation': _manifest(
        generator.operation(
          'loadDetails',
          feature: 'orders',
          kind: OperationKind.remote,
        ),
      ),
      'local-operation': _manifest(
        generator.operation(
          'readDraft',
          feature: 'orders',
          kind: OperationKind.local,
        ),
      ),
      'cached-operation': _manifest(
        generator.operation(
          'syncDetails',
          feature: 'orders',
          kind: OperationKind.cached,
        ),
      ),
    };

    final readmeFile = File('README.md');
    var readme = readmeFile.readAsStringSync();
    if (Platform.environment['UPDATE_README_CONTRACTS'] == 'true') {
      for (final entry in contracts.entries) {
        readme = _replaceSection(readme, entry.key, entry.value);
      }
      readmeFile.writeAsStringSync(readme);
    }

    for (final entry in contracts.entries) {
      expect(
        _section(readme, entry.key),
        entry.value,
        reason: 'README generated section "${entry.key}" is stale.',
      );
    }
  });
}

String _manifest(List<GeneratedFile> files) {
  final paths = files.map((file) => file.path).toSet().toList()..sort();
  return _fence('txt', paths.join('\n'));
}

String _fence(String language, String content) {
  return '```$language\n$content\n```';
}

String _section(String readme, String id) {
  final start = '<!-- BEGIN GENERATED:$id -->';
  final end = '<!-- END GENERATED:$id -->';
  final startIndex = readme.indexOf(start);
  final endIndex = readme.indexOf(end);
  if (startIndex == -1 || endIndex == -1 || endIndex < startIndex) {
    fail('README is missing generated section "$id".');
  }

  return readme.substring(startIndex + start.length, endIndex).trim();
}

String _replaceSection(String readme, String id, String content) {
  final start = '<!-- BEGIN GENERATED:$id -->';
  final end = '<!-- END GENERATED:$id -->';
  final startIndex = readme.indexOf(start);
  final endIndex = readme.indexOf(end);
  if (startIndex == -1 || endIndex == -1 || endIndex < startIndex) {
    fail('README is missing generated section "$id".');
  }

  return '${readme.substring(0, startIndex + start.length)}\n'
      '$content\n'
      '${readme.substring(endIndex)}';
}
