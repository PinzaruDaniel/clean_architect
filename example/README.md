# clean_architect example

Create the config:

```sh
dart run clean_architect init
```

Generate a feature-first auth module:

```sh
dart run clean_architect create architecture --dry-run
dart run clean_architect create architecture
dart run clean_architect create auth --dry-run
dart run clean_architect create auth
```

Generate a layered package feature:

```yaml
clean_architect:
  structure: layered_packages
  state_management: none
  network: abstract
  local_storage: abstract
  models:
    use_freezed: false
    use_json_serializable: false
  paths:
    domain: domain/lib
    data: data/lib/features
    presentation: presentation/lib
    di: di/lib
```

```sh
dart run clean_architect create feature orders
```
