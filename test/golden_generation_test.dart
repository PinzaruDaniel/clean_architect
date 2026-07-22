import 'dart:io';

import 'package:clean_architect/clean_architect.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  final generator = CleanArchitectGenerator(CleanArchitectConfig.defaults());

  test('default auth output matches its golden snapshot', () {
    _expectGolden('default_auth.golden', _snapshot(generator.auth()));
  });

  test('default feature output matches its golden snapshot', () {
    _expectGolden(
      'default_orders_feature.golden',
      _snapshot(generator.feature('orders')),
    );
  });

  test('operation outputs match their golden snapshot', () {
    final sections = <String>[
      for (final kind in OperationKind.values) ...[
        '######## ${kind.name} ########',
        _snapshot(
          generator.operation('loadDetails', feature: 'orders', kind: kind),
        ),
      ],
    ];
    _expectGolden('default_operations.golden', '${sections.join('\n')}\n');
  });
}

String _snapshot(List<GeneratedFile> files) {
  final sorted = [...files]
    ..sort((left, right) => left.path.compareTo(right.path));
  return [
    for (final file in sorted)
      '===== ${p.posix.normalize(file.path)} =====\n'
          '${file.content.replaceAll('\r\n', '\n').trimRight()}\n',
  ].join('\n');
}

void _expectGolden(String name, String actual) {
  final file = File(p.join('test', 'goldens', name));
  if (Platform.environment['UPDATE_GOLDENS'] == 'true') {
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(actual);
  }

  expect(
    file.existsSync(),
    isTrue,
    reason: 'Missing ${file.path}. Run with UPDATE_GOLDENS=true.',
  );
  expect(
    actual,
    file.readAsStringSync(),
    reason: 'Golden changed: ${file.path}',
  );
}
