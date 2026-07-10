import 'package:clean_architect/src/config.dart';
import 'package:clean_architect/src/path_resolver.dart';
import 'package:test/test.dart';

void main() {
  test('resolves default example package paths', () {
    final paths = PathResolver(CleanArchitectConfig.defaults()).resolve('auth');

    expect(paths.domain, 'domain/lib/features/auth');
    expect(paths.data, 'data/lib/features/auth');
    expect(paths.presentation, 'presentation/lib');
    expect(paths.di, 'di/lib');
  });

  test('resolves layered package paths', () {
    const config = CleanArchitectConfig(
      structure: ProjectStructure.layeredPackages,
      stateManagement: StateManagement.none,
      network: NetworkClient.abstract,
      localStorage: LocalStorage.abstract,
      dependencyInjection: DependencyInjection.manual,
      models: ModelConfig(
        useFreezed: false,
        useJsonSerializable: false,
      ),
      paths: PathConfig(
        domain: 'domain/lib',
        data: 'data/lib/features',
        presentation: 'curier_rapid/lib',
        di: 'di/lib',
      ),
    );

    final paths = PathResolver(config).resolve('auth');

    expect(paths.domain, 'domain/lib/features/auth');
    expect(paths.data, 'data/lib/features/auth');
    expect(paths.presentation, 'curier_rapid/lib');
    expect(paths.di, 'di/lib');
  });
}
