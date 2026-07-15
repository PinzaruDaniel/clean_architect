import 'package:path/path.dart' as p;

import '../config.dart';
import '../generated_file.dart';
import '../generator.dart';

List<GeneratedFile> authTemplates(TemplateContext context) {
  final files = <GeneratedFile>[
    ..._domain(context),
    ..._data(context),
    _di(context),
  ];

  if (!context.skipPresentation) {
    files.addAll(_presentation(context));
  }

  return files;
}

List<GeneratedFile> _domain(TemplateContext context) {
  final domain = context.paths.domain;

  return [
    GeneratedFile(
      path: p.join(domain, 'entities', 'auth_token_entity.dart'),
      content: _authTokenEntity(context.config),
    ),
    GeneratedFile(
      path: p.join(domain, 'entities', 'auth_credentials_entity.dart'),
      content: _authCredentialsEntity(context.config),
    ),
    GeneratedFile(
      path: p.join(domain, 'repositories', 'auth_repository.dart'),
      content: '''
${_injectableImport(context)}import '../entities/auth_credentials_entity.dart';
import '../entities/auth_token_entity.dart';

abstract interface class AuthRepository {
  Future<AuthTokenEntity> login(AuthCredentialsEntity credentials);

  Future<void> logout();

  Future<void> saveCredentials(AuthCredentialsEntity credentials);

  Future<AuthCredentialsEntity?> getCredentials();

  Future<void> clearCredentials();
}
''',
    ),
    _authUseCase(domain, 'login', '''
${_injectableImport(context)}import '../entities/auth_credentials_entity.dart';
import '../entities/auth_token_entity.dart';
import '../repositories/auth_repository.dart';

${_lazySingletonAnnotation(context)}class LoginUseCase {
  const LoginUseCase(this._repository);

  final AuthRepository _repository;

  Future<AuthTokenEntity> call(AuthCredentialsEntity credentials) {
    return _repository.login(credentials);
  }
}
'''),
    _authUseCase(domain, 'logout', '''
${_injectableImport(context)}import '../repositories/auth_repository.dart';

${_lazySingletonAnnotation(context)}class LogoutUseCase {
  const LogoutUseCase(this._repository);

  final AuthRepository _repository;

  Future<void> call() {
    return _repository.logout();
  }
}
'''),
    _authUseCase(domain, 'save_auth_credentials', '''
${_injectableImport(context)}import '../entities/auth_credentials_entity.dart';
import '../repositories/auth_repository.dart';

${_lazySingletonAnnotation(context)}class SaveAuthCredentialsUseCase {
  const SaveAuthCredentialsUseCase(this._repository);

  final AuthRepository _repository;

  Future<void> call(AuthCredentialsEntity credentials) {
    return _repository.saveCredentials(credentials);
  }
}
'''),
    _authUseCase(domain, 'get_auth_credentials', '''
${_injectableImport(context)}import '../entities/auth_credentials_entity.dart';
import '../repositories/auth_repository.dart';

${_lazySingletonAnnotation(context)}class GetAuthCredentialsUseCase {
  const GetAuthCredentialsUseCase(this._repository);

  final AuthRepository _repository;

  Future<AuthCredentialsEntity?> call() {
    return _repository.getCredentials();
  }
}
'''),
    _authUseCase(domain, 'clear_auth_credentials', '''
${_injectableImport(context)}import '../repositories/auth_repository.dart';

${_lazySingletonAnnotation(context)}class ClearAuthCredentialsUseCase {
  const ClearAuthCredentialsUseCase(this._repository);

  final AuthRepository _repository;

  Future<void> call() {
    return _repository.clearCredentials();
  }
}
'''),
  ];
}

GeneratedFile _authUseCase(String domain, String name, String content) {
  return GeneratedFile(
    path: p.join(domain, 'usecases', '${name}_use_case.dart'),
    content: content,
  );
}

List<GeneratedFile> _data(TemplateContext context) {
  final data = context.paths.data;

  return [
    GeneratedFile(
      path: p.join(data, 'remote', 'models', 'auth_token_dto.dart'),
      content: _authTokenDto(context.config),
    ),
    GeneratedFile(
      path: p.join(data, 'remote', 'models', 'login_request_dto.dart'),
      content: _loginRequestDto(context.config),
    ),
    GeneratedFile(
      path: p.join(data, 'mappers', 'auth_token_mapper.dart'),
      content: '''
import '${_domainImport(context, 'entities/auth_token_entity.dart')}';
import '../remote/models/auth_token_dto.dart';

extension AuthTokenDtoMapper on AuthTokenDto {
  AuthTokenEntity toEntity() {
    return AuthTokenEntity(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt,
    );
  }
}
''',
    ),
    GeneratedFile(
      path: p.join(data, 'remote', 'auth_remote_data_source.dart'),
      content: _remoteSource(context),
    ),
    GeneratedFile(
      path: p.join(data, 'local', 'models', 'auth_box.dart'),
      content: _authBox(context),
    ),
    GeneratedFile(
      path: p.join(data, 'local', 'auth_local_data_source.dart'),
      content: _localSource(context),
    ),
    GeneratedFile(
      path: p.join(data, 'repositories', 'auth_repository_impl.dart'),
      content: '''
${_injectableImport(context)}import '${_domainImport(context, 'entities/auth_credentials_entity.dart')}';
import '${_domainImport(context, 'entities/auth_token_entity.dart')}';
import '${_domainImport(context, 'repositories/auth_repository.dart')}';
import '../mappers/auth_token_mapper.dart';
import '../remote/models/login_request_dto.dart';
import '../local/auth_local_data_source.dart';
import '../remote/auth_remote_data_source.dart';

${_lazySingletonAnnotation(context)}class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl({
    required AuthRemoteDataSource authRemoteDataSource,
    required AuthLocalDataSource localDataSource,
  })  : _authRemoteDataSource = authRemoteDataSource,
        _localDataSource = localDataSource;

  final AuthRemoteDataSource _authRemoteDataSource;
  final AuthLocalDataSource _localDataSource;

  @override
  Future<AuthTokenEntity> login(AuthCredentialsEntity credentials) async {
    final response = await _authRemoteDataSource.login(
      LoginRequestDto(
        username: credentials.username,
        password: credentials.password,
      ).toJson(),
    );
    return response.toEntity();
  }

  @override
  Future<void> logout() {
    // TODO: Call logout endpoint when your API supports it.
    return Future<void>.value();
  }

  @override
  Future<void> saveCredentials(AuthCredentialsEntity credentials) {
    return _localDataSource.saveCredentials(credentials);
  }

  @override
  Future<AuthCredentialsEntity?> getCredentials() {
    return _localDataSource.getCredentials();
  }

  @override
  Future<void> clearCredentials() {
    return _localDataSource.clearCredentials();
  }
}
''',
    ),
  ];
}

String _authTokenEntity(CleanArchitectConfig config) {
  if (config.models.useFreezed) {
    return '''
import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_token_entity.freezed.dart';

@freezed
class AuthTokenEntity with _\$AuthTokenEntity {
  const factory AuthTokenEntity({
    required String accessToken,
    String? refreshToken,
    DateTime? expiresAt,
  }) = _AuthTokenEntity;
}
''';
  }

  return '''
class AuthTokenEntity {
  const AuthTokenEntity({
    required this.accessToken,
    this.refreshToken,
    this.expiresAt,
  });

  final String accessToken;
  final String? refreshToken;
  final DateTime? expiresAt;

  bool get isExpired {
    final expiresAt = this.expiresAt;
    return expiresAt != null && DateTime.now().isAfter(expiresAt);
  }
}
''';
}

String _authCredentialsEntity(CleanArchitectConfig config) {
  if (config.models.useFreezed) {
    return '''
import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_credentials_entity.freezed.dart';

@freezed
class AuthCredentialsEntity with _\$AuthCredentialsEntity {
  const factory AuthCredentialsEntity({
    required String username,
    required String password,
  }) = _AuthCredentialsEntity;
}
''';
  }

  return '''
class AuthCredentialsEntity {
  const AuthCredentialsEntity({
    required this.username,
    required this.password,
  });

  final String username;
  final String password;
}
''';
}

String _authTokenDto(CleanArchitectConfig config) {
  if (config.models.useFreezed) {
    return '''
import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_token_dto.freezed.dart';
part 'auth_token_dto.g.dart';

@freezed
class AuthTokenDto with _\$AuthTokenDto {
  const factory AuthTokenDto({
    @JsonKey(name: 'access_token') required String accessToken,
    @JsonKey(name: 'refresh_token') String? refreshToken,
    @JsonKey(name: 'expires_at') DateTime? expiresAt,
  }) = _AuthTokenDto;

  factory AuthTokenDto.fromJson(Map<String, dynamic> json) =>
      _\$AuthTokenDtoFromJson(json);
}
''';
  }

  if (config.models.useJsonSerializable) {
    return '''
import 'package:json_annotation/json_annotation.dart';

part 'auth_token_dto.g.dart';

@JsonSerializable()
class AuthTokenDto {
  const AuthTokenDto({
    required this.accessToken,
    this.refreshToken,
    this.expiresAt,
  });

  factory AuthTokenDto.fromJson(Map<String, dynamic> json) {
    return _\$AuthTokenDtoFromJson(json);
  }

  @JsonKey(name: 'access_token')
  final String accessToken;
  @JsonKey(name: 'refresh_token')
  final String? refreshToken;
  @JsonKey(name: 'expires_at')
  final DateTime? expiresAt;

  Map<String, dynamic> toJson() => _\$AuthTokenDtoToJson(this);
}
''';
  }

  return '''
class AuthTokenDto {
  const AuthTokenDto({
    required this.accessToken,
    this.refreshToken,
    this.expiresAt,
  });

  factory AuthTokenDto.fromJson(Map<String, dynamic> json) {
    return AuthTokenDto(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String?,
      expiresAt: json['expires_at'] == null
          ? null
          : DateTime.parse(json['expires_at'] as String),
    );
  }

  final String accessToken;
  final String? refreshToken;
  final DateTime? expiresAt;

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'expires_at': expiresAt?.toIso8601String(),
    };
  }
}
''';
}

String _loginRequestDto(CleanArchitectConfig config) {
  if (config.models.useFreezed) {
    return '''
import 'package:freezed_annotation/freezed_annotation.dart';

part 'login_request_dto.freezed.dart';
part 'login_request_dto.g.dart';

@freezed
class LoginRequestDto with _\$LoginRequestDto {
  const factory LoginRequestDto({
    required String username,
    required String password,
  }) = _LoginRequestDto;

  factory LoginRequestDto.fromJson(Map<String, dynamic> json) =>
      _\$LoginRequestDtoFromJson(json);
}
''';
  }

  if (config.models.useJsonSerializable) {
    return '''
import 'package:json_annotation/json_annotation.dart';

part 'login_request_dto.g.dart';

@JsonSerializable()
class LoginRequestDto {
  const LoginRequestDto({
    required this.username,
    required this.password,
  });

  factory LoginRequestDto.fromJson(Map<String, dynamic> json) {
    return _\$LoginRequestDtoFromJson(json);
  }

  final String username;
  final String password;

  Map<String, dynamic> toJson() => _\$LoginRequestDtoToJson(this);
}
''';
  }

  return '''
class LoginRequestDto {
  const LoginRequestDto({
    required this.username,
    required this.password,
  });

  final String username;
  final String password;

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'password': password,
    };
  }
}
''';
}

String _remoteSource(TemplateContext context) {
  return '''
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:retrofit/retrofit.dart';

import 'models/auth_token_dto.dart';

part 'auth_remote_data_source.g.dart';

@lazySingleton
@RestApi(baseUrl: '')
abstract class AuthRemoteDataSource {
  @factoryMethod
  factory AuthRemoteDataSource(@Named("auth_dio") Dio dio) = _AuthRemoteDataSource;

  @POST('/authorization/token/')
  Future<AuthTokenDto> login(@Body() Map<String, dynamic> body);
}
''';
}

String _authBox(TemplateContext context) {
  return switch (context.config.localStorage) {
    LocalStorage.hive => '''
import 'package:hive/hive.dart';

part 'auth_box.g.dart';

@HiveType(typeId: 0)
class AuthBox extends HiveObject {
  AuthBox({
    this.id = 0,
    required this.username,
    required this.password,
  });

  @HiveField(0)
  int id;

  @HiveField(1)
  String username;

  @HiveField(2)
  String password;
}
''',
    LocalStorage.objectbox => '''
import 'package:objectbox/objectbox.dart';

@Entity()
class AuthBox {
  AuthBox({
    this.id = 0,
    required this.username,
    required this.password,
  });

  @Id()
  int id;

  String username;

  String password;
}
''',
    _ => '''
class AuthBox {
  const AuthBox({
    this.id = 0,
    required this.username,
    required this.password,
  });

  final int id;
  final String username;
  final String password;
}
''',
  };
}

String _localSource(TemplateContext context) {
  final config = context.config;
  final annotation = _lazySingletonAsAnnotation(context, 'AuthLocalDataSource');

  if (config.localStorage == LocalStorage.secureStorage) {
    return '''
${_injectableImport(context)}import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '${_domainImport(context, 'entities/auth_credentials_entity.dart')}';

abstract class AuthLocalDataSource {
  Future<void> saveCredentials(AuthCredentialsEntity credentials);

  Future<AuthCredentialsEntity?> getCredentials();

  Future<void> clearCredentials();
}

$annotation
class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  AuthLocalDataSourceImpl(this._storage);

  final FlutterSecureStorage _storage;

  static Future<AuthLocalDataSource> init() async {
    return AuthLocalDataSourceImpl(const FlutterSecureStorage());
  }

  static const _usernameKey = 'auth_username';
  static const _passwordKey = 'auth_password';

  @override
  Future<void> saveCredentials(AuthCredentialsEntity credentials) async {
    await _storage.write(key: _usernameKey, value: credentials.username);
    await _storage.write(key: _passwordKey, value: credentials.password);
  }

  @override
  Future<AuthCredentialsEntity?> getCredentials() async {
    final username = await _storage.read(key: _usernameKey);
    final password = await _storage.read(key: _passwordKey);
    if (username == null || password == null) return null;

    return AuthCredentialsEntity(
      username: username,
      password: password,
    );
  }

  @override
  Future<void> clearCredentials() async {
    await _storage.delete(key: _usernameKey);
    await _storage.delete(key: _passwordKey);
  }
}
''';
  }

  if (config.localStorage == LocalStorage.hive) {
    return '''
${_injectableImport(context)}import 'package:hive/hive.dart';

import '${_domainImport(context, 'entities/auth_credentials_entity.dart')}';
import 'models/auth_box.dart';

abstract class AuthLocalDataSource {
  Future<void> saveCredentials(AuthCredentialsEntity credentials);

  Future<AuthCredentialsEntity?> getCredentials();

  Future<void> clearCredentials();
}

$annotation
class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  const AuthLocalDataSourceImpl(this._box);

  final Box<AuthBox> _box;

  static Future<AuthLocalDataSource> init() async {
    final box = await Hive.openBox<AuthBox>('auth_box');
    return AuthLocalDataSourceImpl(box);
  }

  @override
  Future<void> saveCredentials(AuthCredentialsEntity credentials) async {
    await _box.put(
      'credentials',
      AuthBox(username: credentials.username, password: credentials.password),
    );
  }

  @override
  Future<AuthCredentialsEntity?> getCredentials() async {
    final box = _box.get('credentials');
    if (box == null) return null;
    return AuthCredentialsEntity(username: box.username, password: box.password);
  }

  @override
  Future<void> clearCredentials() async {
    await _box.delete('credentials');
  }
}
''';
  }

  if (config.localStorage == LocalStorage.objectbox) {
    return '''
${_injectableImport(context)}import 'package:objectbox/objectbox.dart';

import '${_domainImport(context, 'entities/auth_credentials_entity.dart')}';
import 'models/auth_box.dart';

abstract class AuthLocalDataSource {
  Future<void> saveCredentials(AuthCredentialsEntity credentials);

  Future<AuthCredentialsEntity?> getCredentials();

  Future<void> clearCredentials();
}

$annotation
class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  const AuthLocalDataSourceImpl(this._box);

  final Box<AuthBox> _box;

  static AuthLocalDataSource init(Store store) {
    return AuthLocalDataSourceImpl(Box<AuthBox>(store));
  }

  @override
  Future<void> saveCredentials(AuthCredentialsEntity credentials) async {
    _box.put(AuthBox(username: credentials.username, password: credentials.password));
  }

  @override
  Future<AuthCredentialsEntity?> getCredentials() async {
    final boxes = _box.getAll();
    if (boxes.isEmpty) return null;
    final box = boxes.first;
    return AuthCredentialsEntity(username: box.username, password: box.password);
  }

  @override
  Future<void> clearCredentials() async {
    _box.removeAll();
  }
}
''';
  }

  return '''
${_injectableImport(context)}import '${_domainImport(context, 'entities/auth_credentials_entity.dart')}';
import 'models/auth_box.dart';

abstract class AuthLocalDataSource {
  Future<void> saveCredentials(AuthCredentialsEntity credentials);

  Future<AuthCredentialsEntity?> getCredentials();

  Future<void> clearCredentials();
}

$annotation
class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  const AuthLocalDataSourceImpl();

  static Future<AuthLocalDataSource> init() async {
    return const AuthLocalDataSourceImpl();
  }

  @override
  Future<void> saveCredentials(AuthCredentialsEntity credentials) async {
    final placeholder = AuthBox(username: credentials.username, password: credentials.password);
    // TODO: Save credentials using your local storage. Remove placeholder when implemented.
    placeholder.id;
  }

  @override
  Future<AuthCredentialsEntity?> getCredentials() async {
    // TODO: Read credentials using your local storage.
    return null;
  }

  @override
  Future<void> clearCredentials() async {
    // TODO: Clear credentials using your local storage.
  }
}
''';
}

GeneratedFile _di(TemplateContext context) {
  if (context.config.dependencyInjection == DependencyInjection.injectable) {
    return GeneratedFile(
      path: p.join(context.paths.di, '.gitkeep'),
      content: '',
    );
  }

  return GeneratedFile(
    path: p.join(context.paths.di, 'auth_di.dart'),
    content: '''
import '${_dataImport(context, 'repositories/auth_repository_impl.dart')}';
import '${_dataImport(context, 'local/auth_local_data_source.dart')}';
import '${_dataImport(context, 'remote/auth_remote_data_source.dart')}';
import '${_domainImport(context, 'repositories/auth_repository.dart')}';
import '${_domainImport(context, 'usecases/clear_auth_credentials_use_case.dart')}';
import '${_domainImport(context, 'usecases/get_auth_credentials_use_case.dart')}';
import '${_domainImport(context, 'usecases/login_use_case.dart')}';
import '${_domainImport(context, 'usecases/logout_use_case.dart')}';
import '${_domainImport(context, 'usecases/save_auth_credentials_use_case.dart')}';

class AuthDependencies {
  const AuthDependencies({
    required this.repository,
    required this.loginUseCase,
    required this.logoutUseCase,
    required this.saveAuthCredentialsUseCase,
    required this.getAuthCredentialsUseCase,
    required this.clearAuthCredentialsUseCase,
  });

  final AuthRepository repository;
  final LoginUseCase loginUseCase;
  final LogoutUseCase logoutUseCase;
  final SaveAuthCredentialsUseCase saveAuthCredentialsUseCase;
  final GetAuthCredentialsUseCase getAuthCredentialsUseCase;
  final ClearAuthCredentialsUseCase clearAuthCredentialsUseCase;
}

AuthDependencies buildAuthDependencies({
  required AuthRemoteDataSource authRemoteDataSource,
  required AuthLocalDataSource localDataSource,
}) {
  final repository = AuthRepositoryImpl(
    authRemoteDataSource: authRemoteDataSource,
    localDataSource: localDataSource,
  );

  return AuthDependencies(
    repository: repository,
    loginUseCase: LoginUseCase(repository),
    logoutUseCase: LogoutUseCase(repository),
    saveAuthCredentialsUseCase: SaveAuthCredentialsUseCase(repository),
    getAuthCredentialsUseCase: GetAuthCredentialsUseCase(repository),
    clearAuthCredentialsUseCase: ClearAuthCredentialsUseCase(repository),
  );
}
''',
  );
}

List<GeneratedFile> _presentation(TemplateContext context) {
  final presentation = context.paths.presentation;

  return [
    GeneratedFile(
      path: p.join(presentation, 'controllers', 'auth_controller.dart'),
      content: _authController(context),
    ),
    GeneratedFile(
      path: p.join(presentation, 'pages', 'login_page.dart'),
      content: _loginPage(context),
    ),
  ];
}

String _authController(TemplateContext context) {
  final config = context.config;
  final loginState = _loginState();

  if (config.stateManagement == StateManagement.bloc) {
    return '''
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '${_domainImport(context, 'entities/auth_credentials_entity.dart')}';
import '${_domainImport(context, 'usecases/login_use_case.dart')}';
$loginState

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthUsernameChanged extends AuthEvent {
  const AuthUsernameChanged(this.value);

  final String value;

  @override
  List<Object?> get props => [value];
}

class AuthPasswordChanged extends AuthEvent {
  const AuthPasswordChanged(this.value);

  final String value;

  @override
  List<Object?> get props => [value];
}

class AuthSubmitted extends AuthEvent {
  const AuthSubmitted();
}

class AuthController extends Bloc<AuthEvent, LoginState> {
  AuthController()
      : _loginUseCase = GetIt.instance.get<LoginUseCase>(),
        super(const LoginState()) {
    on<AuthUsernameChanged>((event, emit) {
      emit(state.copyWith(username: event.value));
    });
    on<AuthPasswordChanged>((event, emit) {
      emit(state.copyWith(password: event.value));
    });
    on<AuthSubmitted>(_onSubmitted);
  }

  final LoginUseCase _loginUseCase;

  Future<void> _onSubmitted(
    AuthSubmitted event,
    Emitter<LoginState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));
    try {
      await _loginUseCase(
        AuthCredentialsEntity(
          username: state.username,
          password: state.password,
        ),
      );
      emit(state.copyWith(isLoading: false));
    } catch (error) {
      emit(state.copyWith(isLoading: false, errorMessage: error.toString()));
    }
  }
}
''';
  }

  if (config.stateManagement == StateManagement.provider) {
    return '''
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import '${_domainImport(context, 'entities/auth_credentials_entity.dart')}';
import '${_domainImport(context, 'usecases/login_use_case.dart')}';
$loginState

class AuthController extends ChangeNotifier {
  var _loginUseCase = GetIt.instance.get<LoginUseCase>();
  var viewItem = const LoginState();

  void setUsername(String value) {
    viewItem = viewItem.copyWith(username: value);
    notifyListeners();
  }

  void setPassword(String value) {
    viewItem = viewItem.copyWith(password: value);
    notifyListeners();
  }

  Future<void> login() async {
    viewItem = viewItem.copyWith(isLoading: true);
    notifyListeners();
    try {
      await _loginUseCase(
        AuthCredentialsEntity(
          username: viewItem.username,
          password: viewItem.password,
        ),
      );
      viewItem = viewItem.copyWith(isLoading: false);
    } catch (error) {
      viewItem = viewItem.copyWith(
        isLoading: false,
        errorMessage: error.toString(),
      );
    }
    notifyListeners();
  }
}
''';
  }

  final getxImport = config.stateManagement == StateManagement.getx
      ? "import 'package:get/get.dart';\n"
      : '';
  final baseClass = config.stateManagement == StateManagement.getx
      ? ' extends GetxController'
      : '';
  final viewItemDeclaration = config.stateManagement == StateManagement.getx
      ? 'final viewItem = const LoginState().obs;'
      : 'LoginState viewItem = const LoginState();';
  final readUsername = config.stateManagement == StateManagement.getx
      ? 'viewItem.value.username'
      : 'viewItem.username';
  final readPassword = config.stateManagement == StateManagement.getx
      ? 'viewItem.value.password'
      : 'viewItem.password';
  final setLoading = config.stateManagement == StateManagement.getx
      ? 'viewItem.value = viewItem.value.copyWith(isLoading: true);'
      : 'viewItem = viewItem.copyWith(isLoading: true);';
  final setLoaded = config.stateManagement == StateManagement.getx
      ? 'viewItem.value = viewItem.value.copyWith(isLoading: false);'
      : 'viewItem = viewItem.copyWith(isLoading: false);';
  final setError = config.stateManagement == StateManagement.getx
      ? '''viewItem.value = viewItem.value.copyWith(
        isLoading: false,
        errorMessage: error.toString(),
      );'''
      : '''viewItem = viewItem.copyWith(
        isLoading: false,
        errorMessage: error.toString(),
      );''';

  return '''
${getxImport}import '${_domainImport(context, 'entities/auth_credentials_entity.dart')}';
import '${_domainImport(context, 'usecases/login_use_case.dart')}';
import 'package:get_it/get_it.dart';
$loginState

class AuthController$baseClass {
  var _loginUseCase = GetIt.instance.get<LoginUseCase>();
  $viewItemDeclaration

  Future<void> login() async {
    $setLoading
    try {
      await _loginUseCase(
        AuthCredentialsEntity(
          username: $readUsername,
          password: $readPassword,
        ),
      );
      $setLoaded
    } catch (error) {
      $setError
    }
  }
}
''';
}

String _loginState() {
  return '''
class LoginState {
  const LoginState({
    this.username = '',
    this.password = '',
    this.isLoading = false,
    this.errorMessage,
  });

  final String username;
  final String password;
  final bool isLoading;
  final String? errorMessage;

  LoginState copyWith({
    String? username,
    String? password,
    bool? isLoading,
    String? errorMessage,
  }) {
    return LoginState(
      username: username ?? this.username,
      password: password ?? this.password,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}
''';
}

String _loginPage(TemplateContext context) {
  final config = context.config;
  if (config.stateManagement == StateManagement.bloc) {
    return '''
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../controllers/auth_controller.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AuthController(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Login')),
        body: BlocBuilder<AuthController, LoginState>(
          builder: (context, viewItem) {
            final controller = context.read<AuthController>();
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    decoration: const InputDecoration(labelText: 'Username'),
                    onChanged: (value) => controller.add(AuthUsernameChanged(value)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                    onChanged: (value) => controller.add(AuthPasswordChanged(value)),
                  ),
                  if (viewItem.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(viewItem.errorMessage!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: viewItem.isLoading
                        ? null
                        : () => controller.add(const AuthSubmitted()),
                    child: Text(viewItem.isLoading ? 'Signing in...' : 'Sign in'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
''';
  }

  if (config.stateManagement == StateManagement.provider) {
    return '''
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthController(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Login')),
        body: Consumer<AuthController>(
          builder: (context, controller, child) {
            final viewItem = controller.viewItem;
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    decoration: const InputDecoration(labelText: 'Username'),
                    onChanged: controller.setUsername,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                    onChanged: controller.setPassword,
                  ),
                  if (viewItem.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(viewItem.errorMessage!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: viewItem.isLoading ? null : controller.login,
                    child: Text(viewItem.isLoading ? 'Signing in...' : 'Sign in'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
''';
  }

  if (config.stateManagement == StateManagement.getx) {
    return '''
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/auth_controller.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late final AuthController controller;

  @override
  void initState() {
    super.initState();
    Get.put(AuthController());
    controller = Get.find<AuthController>();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Obx(() {
        final viewItem = controller.viewItem.value;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'Username'),
                onChanged: (value) {
                  controller.viewItem.value = viewItem.copyWith(username: value);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
                onChanged: (value) {
                  controller.viewItem.value = viewItem.copyWith(password: value);
                },
              ),
              if (viewItem.errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(viewItem.errorMessage!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: viewItem.isLoading ? null : controller.login,
                child: Text(viewItem.isLoading ? 'Signing in...' : 'Sign in'),
              ),
            ],
          ),
        );
      }),
    );
  }
}
''';
  }

  return '''
import 'package:flutter/material.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Placeholder(),
      ),
    );
  }
}
''';
}

String _lazySingletonAsAnnotation(TemplateContext context, String typeName) {
  return context.config.dependencyInjection == DependencyInjection.injectable
      ? '@LazySingleton(as: $typeName)'
      : '';
}

String _domainImport(TemplateContext context, String path) {
  return _packageImport(context.paths.domain, path);
}

String _dataImport(TemplateContext context, String path) {
  return _packageImport(context.paths.data, path);
}

String _packageImport(String basePath, String path) {
  final parts = p.split(p.normalize(basePath));
  final libIndex = parts.indexOf('lib');
  if (libIndex <= 0) return path;

  final packageName = parts[libIndex - 1];
  final libPath = p.url.joinAll(parts.skip(libIndex + 1).followedBy([path]));
  return 'package:$packageName/$libPath';
}

String _injectableImport(TemplateContext context) {
  return context.config.dependencyInjection == DependencyInjection.injectable
      ? "import 'package:injectable/injectable.dart';\n"
      : '';
}

String _lazySingletonAnnotation(TemplateContext context) {
  return context.config.dependencyInjection == DependencyInjection.injectable
      ? '@lazySingleton\n'
      : '';
}
