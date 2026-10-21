import 'package:flutter_test/flutter_test.dart';
import 'package:msal_auth/msal_auth.dart';

void main() {
  const redirectUri = 'msauth://com.example/hash';

  test('AndroidConfig takes either configFilePath or config', () {
    expect(
      AndroidConfig(
        configFilePath: 'assets/msal_config.json',
        redirectUri: redirectUri,
      ).configFilePath,
      'assets/msal_config.json',
    );
    expect(
      AndroidConfig(
        config: {'account_mode': 'SINGLE'},
        redirectUri: redirectUri,
      ).config,
      {'account_mode': 'SINGLE'},
    );
    expect(() => AndroidConfig(redirectUri: redirectUri), throwsAssertionError);
    expect(
      () => AndroidConfig(
        configFilePath: 'assets/msal_config.json',
        config: {'account_mode': 'SINGLE'},
        redirectUri: redirectUri,
      ),
      throwsAssertionError,
    );
  });
}
