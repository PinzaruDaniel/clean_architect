# clean_architect

A configurable Dart CLI generator for clean architecture feature modules in Flutter and Dart projects.

The package is intentionally boring: it generates predictable files that you can edit immediately. The flexibility lives in `clean_architect.yaml`, not in complicated runtime abstractions.

## Install

```sh
dart pub global activate clean_architect
```

Use the global executable when generating into an empty folder:

```sh
mkdir my_app_architecture
cd my_app_architecture
clean_architect create architecture
```

Use `dart run clean_architect ...` only when you are developing this package from its own checkout or running inside a Dart project that already has a `pubspec.yaml`.

## Empty Folder Usage

`dart run clean_architect create architecture` cannot run in an empty folder because `dart run` requires a local `pubspec.yaml` before the CLI is started. After activation, use `clean_architect create architecture` directly.

## Commands

```sh
clean_architect init
clean_architect create architecture
clean_architect create auth
clean_architect create feature orders
clean_architect create usecase login --feature auth
clean_architect create repository auth
clean_architect doctor
```

Useful flags:

```sh
clean_architect create architecture --dry-run
clean_architect create auth --dry-run
clean_architect create auth --overwrite
clean_architect create feature profile --skip-presentation
clean_architect create auth --state getx --network dio --storage secure_storage
clean_architect create auth --di injectable
```

## Configuration

Run `clean_architect init` to create:

```yaml
clean_architect:
  structure: layered_packages # layered_packages or feature_first
  state_management: getx # getx or none
  network: dio # dio or abstract
  local_storage: secure_storage # secure_storage or abstract
  models:
    use_freezed: true
    use_json_serializable: true
  paths:
    domain: domain/lib
    data: data/lib/features
    presentation: presentation/lib
    di: di/lib
```

The default example layout generates:

```txt
domain/pubspec.yaml
domain/lib/features/auth
data/pubspec.yaml
data/lib/features/auth
di/pubspec.yaml
di/lib
presentation/pubspec.yaml
presentation/lib
```

## Architecture Output

`clean_architect create architecture` generates only layer packages and folders. The placeholder feature folder is named `base_feature` under `domain/lib/features/base_feature` and `data/lib/features/base_feature`. It does not generate auth code.

## Auth Output

`clean_architect create auth` generates entities, repository contracts, auth use cases, DTOs, mappers, remote/local data sources, repository implementation, DI builder, layer pubspecs, and a runnable Flutter presentation shell with a minimal login page/controller/view item when presentation is enabled.

## Supported In v0.1.0

- Structures: `feature_first`, `layered_packages`
- State management: `getx`, `none`
- Network: `dio`, `abstract`
- Local storage: `secure_storage`, `abstract`
- Model style: `freezed`/`json_serializable` by default, plain Dart fallback by config

## Doctor

```sh
clean_architect doctor
```

`doctor` validates that the configured paths exist and reminds you which dependencies the generated code expects, such as `dio`, `get`, or `flutter_secure_storage`.
