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
      content: '''
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
''',
    ),
    GeneratedFile(
      path: p.join(domain, 'entities', 'auth_credentials_entity.dart'),
      content: '''
class AuthCredentialsEntity {
  const AuthCredentialsEntity({
    required this.username,
    required this.password,
  });

  final String username;
  final String password;
}
''',
    ),
    GeneratedFile(
      path: p.join(domain, 'repositories', 'auth_repository.dart'),
      content: '''
import '../entities/auth_credentials_entity.dart';
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
import '../entities/auth_credentials_entity.dart';
import '../entities/auth_token_entity.dart';
import '../repositories/auth_repository.dart';

class LoginUseCase {
  const LoginUseCase(this._repository);

  final AuthRepository _repository;

  Future<AuthTokenEntity> call(AuthCredentialsEntity credentials) {
    return _repository.login(credentials);
  }
}
'''),
    _authUseCase(domain, 'logout', '''
import '../repositories/auth_repository.dart';

class LogoutUseCase {
  const LogoutUseCase(this._repository);

  final AuthRepository _repository;

  Future<void> call() {
    return _repository.logout();
  }
}
'''),
    _authUseCase(domain, 'save_auth_credentials', '''
import '../entities/auth_credentials_entity.dart';
import '../repositories/auth_repository.dart';

class SaveAuthCredentialsUseCase {
  const SaveAuthCredentialsUseCase(this._repository);

  final AuthRepository _repository;

  Future<void> call(AuthCredentialsEntity credentials) {
    return _repository.saveCredentials(credentials);
  }
}
'''),
    _authUseCase(domain, 'get_auth_credentials', '''
import '../entities/auth_credentials_entity.dart';
import '../repositories/auth_repository.dart';

class GetAuthCredentialsUseCase {
  const GetAuthCredentialsUseCase(this._repository);

  final AuthRepository _repository;

  Future<AuthCredentialsEntity?> call() {
    return _repository.getCredentials();
  }
}
'''),
    _authUseCase(domain, 'clear_auth_credentials', '''
import '../repositories/auth_repository.dart';

class ClearAuthCredentialsUseCase {
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
      content: _remoteSource(context.config),
    ),
    GeneratedFile(
      path: p.join(data, 'local', 'models', '.gitkeep'),
      content: '',
    ),
    GeneratedFile(
      path: p.join(data, 'local', 'auth_local_data_source.dart'),
      content: _localSource(context),
    ),
    GeneratedFile(
      path: p.join(data, 'repositories', 'auth_repository_impl.dart'),
      content: '''
import '${_domainImport(context, 'entities/auth_credentials_entity.dart')}';
import '${_domainImport(context, 'entities/auth_token_entity.dart')}';
import '${_domainImport(context, 'repositories/auth_repository.dart')}';
import '../mappers/auth_token_mapper.dart';
import '../remote/models/login_request_dto.dart';
import '../local/auth_local_data_source.dart';
import '../remote/auth_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required AuthLocalDataSource localDataSource,
  })  : _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource;

  final AuthRemoteDataSource _remoteDataSource;
  final AuthLocalDataSource _localDataSource;

  @override
  Future<AuthTokenEntity> login(AuthCredentialsEntity credentials) async {
    final response = await _remoteDataSource.login(
      LoginRequestDto(
        username: credentials.username,
        password: credentials.password,
      ),
    );
    return response.toEntity();
  }

  @override
  Future<void> logout() {
    return _remoteDataSource.logout();
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

String _authTokenDto(CleanArchitectConfig config) {
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

  final String accessToken;
  final String? refreshToken;
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

String _remoteSource(CleanArchitectConfig config) {
  final dioImport = config.network == NetworkClient.dio
      ? "import 'package:dio/dio.dart';\n"
      : '';
  final field = config.network == NetworkClient.dio
      ? '''
  AuthRemoteDataSource(this._dio);

  final Dio _dio;
'''
      : '''
  const AuthRemoteDataSource();
''';
  final login = config.network == NetworkClient.dio
      ? '''
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: request.toJson(),
    );
    return AuthTokenDto.fromJson(response.data ?? <String, dynamic>{});
'''
      : '''
    // TODO: Call your auth API.
    throw UnimplementedError();
''';

  return '''
${dioImport}import '../remote/models/auth_token_dto.dart';
import '../remote/models/login_request_dto.dart';

class AuthRemoteDataSource {
$field
  Future<AuthTokenDto> login(LoginRequestDto request) async {
$login  }

  Future<void> logout() async {
    // TODO: Call logout endpoint when your API supports it.
  }
}
''';
}

String _localSource(TemplateContext context) {
  final config = context.config;
  final secure = config.localStorage == LocalStorage.secureStorage;
  final import = secure
      ? "import 'package:flutter_secure_storage/flutter_secure_storage.dart';\n"
      : '';
  final constructor = secure
      ? '''
  AuthLocalDataSource(this._storage);

  final FlutterSecureStorage _storage;
'''
      : '''
  const AuthLocalDataSource();
''';
  final body = secure
      ? '''
  static const _usernameKey = 'auth_username';
  static const _passwordKey = 'auth_password';

  Future<void> saveCredentials(AuthCredentialsEntity credentials) async {
    await _storage.write(key: _usernameKey, value: credentials.username);
    await _storage.write(key: _passwordKey, value: credentials.password);
  }

  Future<AuthCredentialsEntity?> getCredentials() async {
    final username = await _storage.read(key: _usernameKey);
    final password = await _storage.read(key: _passwordKey);
    if (username == null || password == null) return null;

    return AuthCredentialsEntity(
      username: username,
      password: password,
    );
  }

  Future<void> clearCredentials() async {
    await _storage.delete(key: _usernameKey);
    await _storage.delete(key: _passwordKey);
  }
'''
      : '''
  Future<void> saveCredentials(AuthCredentialsEntity credentials) async {
    // TODO: Save credentials using your local storage.
  }

  Future<AuthCredentialsEntity?> getCredentials() async {
    // TODO: Read credentials using your local storage.
    return null;
  }

  Future<void> clearCredentials() async {
    // TODO: Clear credentials using your local storage.
  }
''';

  return '''
${import}import '${_domainImport(context, 'entities/auth_credentials_entity.dart')}';

class AuthLocalDataSource {
$constructor$body}
''';
}

GeneratedFile _di(TemplateContext context) {
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
  required AuthRemoteDataSource remoteDataSource,
  required AuthLocalDataSource localDataSource,
}) {
  final repository = AuthRepositoryImpl(
    remoteDataSource: remoteDataSource,
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
      content: _loginPage(context.config),
    ),
    GeneratedFile(
      path: p.join(presentation, 'widgets', 'login_view_item.dart'),
      content: '''
class LoginViewItem {
  const LoginViewItem({
    this.username = '',
    this.password = '',
    this.isLoading = false,
    this.errorMessage,
  });

  final String username;
  final String password;
  final bool isLoading;
  final String? errorMessage;

  LoginViewItem copyWith({
    String? username,
    String? password,
    bool? isLoading,
    String? errorMessage,
  }) {
    return LoginViewItem(
      username: username ?? this.username,
      password: password ?? this.password,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}
''',
    ),
  ];
}

String _authController(TemplateContext context) {
  final config = context.config;
  if (config.stateManagement == StateManagement.getx) {
    return '''
import 'package:get/get.dart';

import '${_domainImport(context, 'entities/auth_credentials_entity.dart')}';
import '${_domainImport(context, 'usecases/login_use_case.dart')}';
import '../widgets/login_view_item.dart';

class AuthController extends GetxController {
  AuthController(this._loginUseCase);

  final LoginUseCase _loginUseCase;
  final viewItem = const LoginViewItem().obs;

  Future<void> login() async {
    viewItem.value = viewItem.value.copyWith(isLoading: true);
    try {
      await _loginUseCase(
        AuthCredentialsEntity(
          username: viewItem.value.username,
          password: viewItem.value.password,
        ),
      );
      viewItem.value = viewItem.value.copyWith(isLoading: false);
    } catch (error) {
      viewItem.value = viewItem.value.copyWith(
        isLoading: false,
        errorMessage: error.toString(),
      );
    }
  }
}
''';
  }

  return '''
import '${_domainImport(context, 'entities/auth_credentials_entity.dart')}';
import '${_domainImport(context, 'usecases/login_use_case.dart')}';
import '../widgets/login_view_item.dart';

class AuthController {
  AuthController(this._loginUseCase);

  final LoginUseCase _loginUseCase;
  LoginViewItem viewItem = const LoginViewItem();

  Future<void> login() async {
    viewItem = viewItem.copyWith(isLoading: true);
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
  }
}
''';
}

String _loginPage(CleanArchitectConfig config) {
  if (config.stateManagement == StateManagement.getx) {
    return '''
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'auth_controller.dart';

class LoginPage extends GetView<AuthController> {
  const LoginPage({super.key});

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
