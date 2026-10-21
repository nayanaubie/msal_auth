## Unreleased
- Added `onCurrentAccountChanged` stream to `SingleAccountPca` that emits the signed-in account whenever it changes and `null` on sign-out. On Android it also reacts to sign-in and sign-out by other apps on devices in shared device mode. [#issue/65](https://github.com/nayanAubie/msal_auth/issues/65)

## 3.5.3
- Pin the Swift MSAL library to `2.14.1` and prevent updates beyond this version to avoid native min deployment target breaking changes. [#issue/151](https://github.com/nayanAubie/msal_auth/issues/151)

## 3.5.2
- Added optional `redirectUri` in `AppleConfig` for iOS/MacOS. When provided, MSAL uses it directly instead of deriving the default `msauth.<bundle-id>` redirect, which fails with `teamId is missing` on some managed devices. Keeping it `null` preserves the existing behaviour. [#issue/145](https://github.com/nayanAubie/msal_auth/issues/145)
- `AppleConfig.broker` is now applied on MacOS as well (earlier it was iOS only). Setting it to `webView` / `safariBrowser` disables the Microsoft SSO extension and routes authentication through the web view. [#issue/145](https://github.com/nayanAubie/msal_auth/issues/145)

## 3.5.1
- Fixed issue of `IllegalStateException: Reply already submitted` crash due to multiple account callback from Android to Dart. [#issue/116](https://github.com/nayanAubie/msal_auth/issues/116)
- Added `MsalNoCurrentAccountException` in Dart to handle absence of signed-in account. [#issue/141](https://github.com/nayanAubie/msal_auth/issues/141)

## 3.5.0
- Added support for `Swift Package Manager` on iOS and macOS. [#issue/132](https://github.com/nayanAubie/msal_auth/issues/132)
- Fixed the native Swift `getCurrentAccount` implementation so `acquireTokenSilent` and `signOut` correctly wait for the asynchronous callback. [#issue/129](https://github.com/nayanAubie/msal_auth/issues/129)

## 3.4.1
- Fixed an Android release build issue caused by missing ProGuard rule mappings in the Android library. [#issue/135](https://github.com/nayanAubie/msal_auth/issues/135)

## 3.4.0
- Updated native MSAL SDK versions: Android: `8.3.+` and iOS & macOS: `2.11.0`
- Migrated Android build scripts from Groovy to Kotlin DSL.
- Added automatic handling of `MSALPublicClientApplication.handleMSALResponse` for iOS URL callbacks via both `AppDelegate` and `SceneDelegate`, removing the need for manual integration in host apps.
- Added a shared device mode status check method to the `PublicClientApplication` class. [#issue/126](https://github.com/nayanAubie/msal_auth/issues/126)

## 3.3.0
- Created `AppTheme` style in the `example` app for MSAL WebView in Android. [#issue/119](https://github.com/nayanAubie/msal_auth/issues/119)
- Added support for customised webview in iOS and macOS. [#issue/90](https://github.com/nayanAubie/msal_auth/issues/90)

## 3.2.7
- Fixed issue of `authorityType` value assignment in iOS/MacOS. [#issue/118](https://github.com/nayanAubie/msal_auth/issues/118)

## 3.2.6
- Fixed MSAL error conversion in `Dart` due to `nil` details received from iOS/MacOS.
- Improved error codes in iOS/MacOS when a custom exception needs to be thrown.

## 3.2.5
- Fixed an issue on `iOS` where the Authenticator app did not open when switching the broker to `Authenticator`.
- Refactored error handling in **MSAL exceptions** to include correlation IDs and improve error detail mapping. iOS/MacOS now shows the proper exception message instead of `Operation couldn't be completed.`
- `AuthenticationResult (Android)`: Fixed username value in account mapping. `username` value will be `null` instead of `Missing from token response` if not found.

## 3.2.4
- Handle UI unavailable error in `acquireToken` method and adjust view controller retrieval logic. [#issue/101](https://github.com/nayanAubie/msal_auth/issues/101)
- Add `authority` parameter support for `acquireToken` and `acquireTokenSilent` methods. [#issue/91](https://github.com/nayanAubie/msal_auth/issues/91)

## 3.2.3
- Fixed an issue causing `MsalUiRequiredException` due to an internal call to `acquireTokenSilent` within the `acquireToken` method during native calls. [#issue/82](https://github.com/nayanAubie/msal_auth/issues/82)

## 3.2.2
- Fixed an issue of broker in iOS due to broker availability was set to auto in the `acquireToken` method.

## 3.2.1
- Updated `example` app to use the signature hash programmatically instead of hardcoding it in `AndroidManifest.xml`.
- Updated the `example/README` for detailed instructions on how to set up the `example` app.
- Update documentation for the following:
  - Internet and Network State permissions in `AndroidManifest.xml`.
  - Debug and release signature hash generation for Android.
  - `ProGuard` setup within this plugin.

## 3.2.0
- Upgrade MSAL native libraries:
  - Android: `6.0.1` (Version fixed to ensure each release of `msal_auth` consistently uses a specific native MSAL version)
  - Apple: `2.2.0`
- Used modern `Gradle` syntax with updated Kotlin and Gradle wrapper version.
- Migrated the Android example app from Groovy to Kotlin build scripts.

## 3.1.5
- Fixed an issue in iOS: "Unable to create public client application" when the app doesn't specify `LSApplicationQueriesSchemes` in `Info.plist`. [#issue/80](https://github.com/nayanAubie/msal_auth/issues/80)
- Added an `assertion` in the `acquireTokenSilent` method to ensure `identifier` is not null when using multiple account mode. [#issue/93](https://github.com/nayanAubie/msal_auth/issues/93)

## 3.1.4
- Upgrade MSAL native libraries:
  - Android: `5.10.+`
  - Apple: `1.7.0`
- Fixed an issue of casting `List<Object>` to `List<String>` in the `MsalDeclinedScopeException`. [#issue/83](https://github.com/nayanAubie/msal_auth/issues/83)
- Make `idToken`, `tenantId` and `correlationId` nullable in `AuthenticationResult`. [#issue/81](https://github.com/nayanAubie/msal_auth/issues/81)

## 3.1.3
- Fixed a crash when opening the app from TestFlight on iOS. [#issue/25](https://github.com/nayanAubie/msal_auth/issues/25)
- Allowed to extend the `SingleAccountPca` & `MultipleAccountPca` classes. [#issue/81](https://github.com/nayanAubie/msal_auth/issues/81)

## 3.1.2
- Upgrade Android configuration to support latest Gradle version.

## 3.1.1
- Made the `name` nullable in `Account` class because it may be null if the user is registered without setting a name.
- Used default authority in example's `msal_config.json`.

## 3.1.0
- Added support for the `macOS` platform.
- **BREAKING CHANGES:**
  - `IosConfig` class has been renamed to `AppleConfig` and now this configuration class supports iOS and macOS. `broker` property of this class is used only for iOS.

## 3.0.1
- Added `Account Mode` related instructions for Android in the README & fixed Dart analysis.

## 3.0.0
- Added support of `single` and `multiple` account mode.
- Added new classes & methods based on account mode:
  - SingleAccountPca (Single Account Mode):
    - currentAccount
    - signOut()
  - MultipleAccountPca (Multiple Account Mode):
    - getAccount()
    - getAccounts()
    - removeAccount()
- Added `redirectUri` in `AndroidConfig` class as a required parameter.
- Added `identifier` option in `acquireTokenSilent()` that is required for multiple account mode.
- Defined all the possible exceptions in Dart side that can be thrown by native MSAL SDK.
- `Example` app is completely re-written to showcase all the features.
  
- **BREAKING CHANGES:**
  - `MsalAuth.createPublicClientApplication` is removed and added 3 classes:
    - `PublicClientApplication` super class.
    - `SingleAccountPca` for single account mode.
      - `SingleAccountPca.create()` is used to create single account public client application.
    - `MultipleAccountPca` for multiple account mode.
      - `MultipleAccountPca.create()` is used to create multiple account public client application.
  - `tenantId` from `AndroidConfig` is removed because it can be set through JSON configuration file.
  - `AuthMiddleware` enum in `IosConfig` is renamed to `Broker`.
  - `TenantType` enum in `IosConfig` is renamed to `AuthorityType` with it's values:
    - `entraIDAndMicrosoftAccount` to `aad`.
    - `azureADB2C` to `b2c`.
  - `scopes` argument is moved to `acquireToken()` & `acquireTokenSilent()` methods. these methods are now part of `PublicClientApplication` class.
  - `logout()` is removed so `signOut()` or `removeAccount()` is used based on your account mode.
  - `MsalUser` class is replaced by `AuthenticationResult` with additional parameters.
  - `MsalUserCanceledException` is renamed to `MsalUserCancelException`.

## 2.2.1
- Added keychain group `com.microsoft.adalcache` in `example/ios` and updated instruction in README.

## 2.2.0

- Moved `loginHint` param to `acquireToken` function.
- Added support of `Prompt` option in `acquireToken` function.

## 2.1.1

- Updated README for login process stuck on iOS due to missing callback handling. issue#26, issue#33

## 2.1.0

- Fixed issue of `activity is null` when `FlutterFragmentActivity` is used in `MainActivity.kt`

## 2.0.2

- Added `idToken` param in `MsalUser` class.

## 2.0.1

- Added support of `loginHint`.

## 2.0.0

- Added support for authenticating against Azure AD B2C tenants on iOS.

## 1.0.8

- Fixed crash in Android when `MsalUiRequiredException` occurs.
- Added info about `authority` used in iOS.
- Updated `example` code.

## 1.0.7

- Fixed `Dart Analysis` in model classes.

## 1.0.6

- Added documentation for `How to setup app in Azure portal`.

## 1.0.5

- Added documentation for broker authentication.

## 1.0.4

- Added documentation.

## 1.0.3

- Fixed `Dart Analysis`

## 1.0.2

- Added `Dart Analysis`

## 1.0.1

- Set `tokenExpiresOn` value as a milliseconds since epoch.

## 1.0.0

- Initial release.
