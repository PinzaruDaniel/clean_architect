## 0.6.0

- Replaced doctor reminders with real validation of all configured layer pubspecs and package roots.
- Added required dependency and compatible version-constraint checks.
- Added Dart and Flutter SDK compatibility checks plus per-package build_runner availability checks.
- Added detection for missing referenced `.g.dart` files.
- Made `clean_architect doctor` return exit code 1 when project checks fail.
- Added doctor coverage to the generated-project integration matrix.

## 0.5.0

- Added `clean_architect --version` and command-specific help.
- Added strict validation for names, Flutter platforms, layer paths, YAML value types, and incompatible CLI settings.
- Added concise malformed YAML errors without stack traces.
- Added plan-first transactional generation with complete conflict preflight.
- Required existing features before remote, local, or cached operation commands can patch them.
- Made repeated feature, operation, architecture, and scaffolding commands idempotent.
- Added `config_version: 1` for future configuration migrations.

## 0.4.0

- Added a generated-project integration matrix covering five representative configurations, both structure modes, auth, generic features, and all operation commands.
- Added real `pub get`, `build_runner`, and per-layer analysis validation for generated temporary projects.
- Added a sharded GitHub Actions workflow for unit and generated-project verification.
- Fixed plain-Dart operation entities to use the same String ID contract as DTOs and Freezed entities.
- Fixed package-root `Failure` imports for Either-enabled feature and operation files.
- Fixed GetX Either fold syntax and made operation-added controller dependencies final.
- Separated local integer box IDs from API-provided remote IDs in generated feature and operation models.

## 0.3.0

- Updated package and generated-project dependencies to current compatible releases.
- Switched generated Hive storage to the maintained Hive CE packages.
- Made generated dependency sections conditional so unused frameworks and builders are omitted.
- Added Freezed 3-compatible entity and DTO declarations.
- Fixed injectable repository interface registration, async initialization, Dio providers, and Hive box providers.
- Added stable Hive type IDs and per-box adapter registration for features and operation commands.
- Made `feature_first` place presentation and DI files under feature-specific folders.
- Fixed `Either<Failure, T>` handling in generated controllers.
- Generated real asset directories with `.gitkeep` files.

## 0.2.3

- Kept one-off feature item widgets inside their pages and moved auth form state into the controller instead of generating standalone view-item files.

## 0.2.2

- Updated cached operations and use cases to use `sync<Name>` remotely and `stream<Name>` locally across generated layers.

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
