part of 'public_client_application.dart';

/// This class is used to create public client application for single account
/// mode.
class SingleAccountPca extends PublicClientApplication {
  SingleAccountPca._create();

  static final _currentAccountController =
      StreamController<Account?>.broadcast();

  /// Id of the account last emitted by [onCurrentAccountChanged].
  static String? _currentAccountId;

  /// Creates single account public client application.
  static Future<SingleAccountPca> create({
    /// Client id of the application.
    required String clientId,

    /// Android configuration, required for android platform.
    AndroidConfig? androidConfig,

    /// Apple configuration, required for iOS & MacOS platform.
    AppleConfig? appleConfig,
  }) async {
    try {
      final arguments = await Utils.createPcaArguments(
        clientId: clientId,
        androidConfig: androidConfig,
        appleConfig: appleConfig,
      );
      await kMethodChannel.invokeMethod('createSingleAccountPca', arguments);
      kMethodChannel.setMethodCallHandler(_handleMethodCall);
      return SingleAccountPca._create();
    } on PlatformException catch (e) {
      throw e.convertToMsalException();
    }
  }

  /// Emits the signed-in account whenever it changes, and `null` once it is
  /// signed out. The first account found after the app starts is emitted too.
  ///
  /// Changes are picked up by [currentAccount], [acquireToken],
  /// [acquireTokenSilent] and [signOut]. On Android, the stream also updates
  /// when another app signs the account in or out of a device in shared
  /// device mode.
  Stream<Account?> get onCurrentAccountChanged =>
      _currentAccountController.stream;

  /// Gets the current account from the cache. if no account is available, it
  /// will throw an exception.
  Future<Account> get currentAccount => _loadCurrentAccount();

  @override
  Future<AuthenticationResult> acquireToken({
    required List<String> scopes,
    Prompt prompt = Prompt.whenRequired,
    String? loginHint,
    String? authority,
    CustomWebViewConfig? customWebViewConfig,
  }) async {
    final result = await super.acquireToken(
      scopes: scopes,
      prompt: prompt,
      loginHint: loginHint,
      authority: authority,
      customWebViewConfig: customWebViewConfig,
    );
    _updateCurrentAccount(result.account);
    return result;
  }

  @override
  Future<AuthenticationResult> acquireTokenSilent({
    required List<String> scopes,
    String? identifier,
    String? authority,
  }) async {
    try {
      final result = await super.acquireTokenSilent(
        scopes: scopes,
        identifier: identifier,
        authority: authority,
      );
      _updateCurrentAccount(result.account);
      return result;
    } on MsalNoCurrentAccountException {
      _updateCurrentAccount(null);
      rethrow;
    }
  }

  /// Signs out the current account and credentials (tokens).
  /// NOTE: If a device is marked as a shared device within broker,
  /// sign out will be device wide.
  Future<bool> signOut() async {
    try {
      final result = await kMethodChannel.invokeMethod('signOut');
      _updateCurrentAccount(null);
      return result;
    } on PlatformException catch (e) {
      throw e.convertToMsalException();
    }
  }

  static Future<Account> _loadCurrentAccount() async {
    try {
      final result = await kMethodChannel.invokeMethod('currentAccount');
      final account = Account.fromJson((result as Map).cast<String, dynamic>());
      _updateCurrentAccount(account);
      return account;
    } on PlatformException catch (e) {
      final exception = e.convertToMsalException();
      if (exception is MsalNoCurrentAccountException) {
        _updateCurrentAccount(null);
      }
      throw exception;
    }
  }

  static void _updateCurrentAccount(Account? account) {
    if (account?.id == _currentAccountId) return;
    _currentAccountId = account?.id;
    _currentAccountController.add(account);
  }

  /// Handles calls from the native side.
  static Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method == 'currentAccountChanged') {
      // The native side only reports that something changed, so read the
      // current account again.
      try {
        await _loadCurrentAccount();
      } on MsalException {
        // A missing account was already emitted as `null`, other errors leave
        // the stream unchanged.
      }
    }
  }
}
