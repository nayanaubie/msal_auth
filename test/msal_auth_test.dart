import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:msal_auth/msal_auth.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  Map<String, dynamic> account(String id) =>
      {'id': id, 'username': '$id@contoso.com', 'name': id};

  Map<String, dynamic> authResult(String id) => {
        'accessToken': 'token',
        'authenticationScheme': 'Bearer',
        'expiresOn': 0,
        'idToken': null,
        'authority': 'https://login.microsoftonline.com/common',
        'tenantId': null,
        'scopes': ['User.Read'],
        'correlationId': null,
        'account': account(id),
      };

  test('onCurrentAccountChanged emits on every account change', () async {
    // Account returned by the native `currentAccount` call, null if none.
    String? nativeAccount = 'a';
    messenger.setMockMethodCallHandler(kMethodChannel, (call) async {
      switch (call.method) {
        case 'currentAccount':
          if (nativeAccount == null) {
            throw PlatformException(code: 'NO_CURRENT_ACCOUNT');
          }
          return account(nativeAccount);
        case 'acquireToken':
        case 'acquireTokenSilent':
          return authResult(nativeAccount!);
        case 'signOut':
          return true;
      }
      return true;
    });

    final pca = await SingleAccountPca.create(
      clientId: 'client-id',
      androidConfig: AndroidConfig(
        configFilePath: 'assets/msal_config.json',
        redirectUri: 'msauth://com.example/hash',
      ),
      appleConfig: AppleConfig(),
    );
    final emitted = <String?>[];
    final subscription =
        pca.onCurrentAccountChanged.listen((a) => emitted.add(a?.id));

    await pca.currentAccount;
    await pca.acquireTokenSilent(scopes: ['User.Read']);

    // Another app signed the user out of the shared device.
    nativeAccount = null;
    await messenger.handlePlatformMessage(
      kMethodChannel.name,
      kMethodChannel.codec
          .encodeMethodCall(const MethodCall('currentAccountChanged')),
      (_) {},
    );

    nativeAccount = 'b';
    await pca.acquireToken(scopes: ['User.Read']);
    await pca.signOut();
    await Future<void>.delayed(Duration.zero);

    expect(emitted, ['a', null, 'b', null]);
    await subscription.cancel();
  });
}
