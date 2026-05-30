class AppConfig {
  static const String backendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  static const String backendHost = String.fromEnvironment(
    'BACKEND_HOST',
    defaultValue: '10.0.2.2',
  );

  static const int backendPort = int.fromEnvironment(
    'BACKEND_PORT',
    defaultValue: 8000,
  );
}
