/// Configuration class for Android platform.
class AndroidConfig {
  /// Asset path of JSON configuration file.
  final String? configFilePath;

  /// Content of the JSON configuration file, for configurations that are only
  /// known at runtime (e.g. received from an MDM). Used instead of
  /// [configFilePath].
  final Map<String, dynamic>? config;

  /// Redirect URI of android application. available in authentication settings
  /// in Azure portal.
  final String redirectUri;

  AndroidConfig({
    this.configFilePath,
    this.config,
    required this.redirectUri,
  }) : assert(
          (configFilePath == null) != (config == null),
          'Provide either configFilePath or config',
        );
}
