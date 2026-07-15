## 0.2.1

- Fixed injectable `data_module.dart` updates when adding another Hive/ObjectBox feature.

## 0.2.0

- Renamed generated remote API service templates to remote data source templates.
- Added Dio providers to injectable `data/lib/data_module.dart`.
- Updated local/cached operation generation to patch `data_module.dart` with new box providers.
- Added Bloc and Provider state management template support.
- Added Hive and ObjectBox local storage options.
- Added generated local box models and injectable `data/lib/data_module.dart` initialization for Hive and ObjectBox storage.

## 0.1.9

- Added optional Flutter presentation bootstrap with `flutter.create_presentation`, `flutter.platforms`, `--flutter-create`, and `--platforms`.

## 0.1.8

- Added remote/local/cached operation commands for extending existing features.
- Added `use_either_failure` configuration for `Future<Either<Failure, T>>` repository and use case return types.

## 0.1.7

- updated example/clean_architect.yaml and added build runner package for presentation

## 0.1.6

- Expanded README documentation with all supported configuration options and generated project structure examples.
- Aligned auth local source, controller, and page templates with the generic feature template style.

## 0.1.5

- Added a new configuration option, `use_asset_generator`, that enables the asset generator kit.

## 0.1.4

- local data source for auth and feature uses injectable package
- Updated auth presentation layer to use GetX

## 0.1.3

- Refactor packages versions for layers.
- Refactor initialization of feature controller and screen

## 0.1.2

- Generate freezed entities and DTOs by default.
- Generate Retrofit API service templates for remote data sources.
- Add injectable-style injector templates matching separated data/domain/di layers.
- Update GetX pages to initialize and retrieve controllers with `Get.put` and `Get.find`.

## 0.1.1

- Clarify empty-folder usage through the globally activated `clean_architect` executable.
- Document `create architecture` as the default clean architecture scaffold command.

## 0.1.0

- Add `clean_architect init`.
- Add `clean_architect create auth`.
- Add `clean_architect create feature <name>`.
- Add `--dry-run`, `--overwrite`, `--force`, and `--skip-presentation`.
- Support `feature_first` and `layered_packages` path layouts.
- Support `getx` and `none` state management templates.
- Support `dio` and `abstract` remote source templates.
- Support `secure_storage` and `abstract` local source templates.
- Add `clean_architect doctor`.
