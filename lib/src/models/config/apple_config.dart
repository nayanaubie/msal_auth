/// Configuration class for iOS & MacOS platform.
final class AppleConfig {
  /// Required when using B2C authority.
  /// For more information, follow:
  /// https://learn.microsoft.com/en-us/entra/msal/objc/configure-authority#b2c
  final String? authority;

  /// Type of authority to authenticate against.
  final AuthorityType authorityType;

  /// Authentication middleware that is used to perform authentication.
  /// Used on both iOS and macOS. Disabling the broker (`webView` /
  /// `safariBrowser`) routes auth through the web view instead of the
  /// Microsoft SSO extension, which is required on managed Macs where the
  /// broker cannot resolve the app's Team ID.
  final Broker broker;

  /// Redirect URI registered for this app in the Azure portal
  /// (Authentication → Mobile and desktop, e.g.
  /// `msauth.<team-id>.<bundle-id>://auth`). When provided, MSAL uses this
  /// URI directly instead of deriving the default `msauth.<bundle-id>`
  /// redirect and resolving the Apple Team ID via keychain — which fails on
  /// some managed devices with "teamId is missing". Optional; when null,
  /// upstream default-derivation behavior is preserved.
  final String? redirectUri;

  /// Keychain group in which MSAL stores the token cache, without the Team ID
  /// prefix. MSAL defaults to `com.microsoft.adalcache` on iOS and
  /// `com.microsoft.identity.universalstorage` on macOS, which every app of the
  /// same Apple team shares: apps using the same client ID then see each
  /// other's accounts, and signing out in one app signs out the others. Set a
  /// group that only your app declares in its entitlements (e.g. the bundle
  /// identifier) to keep its cache private. Optional; when null, the MSAL
  /// default is used.
  final String? keychainSharingGroup;

  AppleConfig({
    this.authority,
    this.authorityType = AuthorityType.aad,
    this.broker = Broker.msAuthenticator,
    this.redirectUri,
    this.keychainSharingGroup,
  });
}

/// Type of authority to authenticate against.
enum AuthorityType {
  /// Microsoft Entra ID (formerly Azure Active Directory).
  aad,

  /// Business-to-Consumer.
  b2c
}

/// Types of broker that is used while authenticating user.
enum Broker {
  /// MS Authenticator app will be used if installed on a device, otherwise
  /// Safari browser will be used.
  msAuthenticator,

  /// Safari browser will be used.
  safariBrowser,

  /// WebView will be used.
  webView
}
