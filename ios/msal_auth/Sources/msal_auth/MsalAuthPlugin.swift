import Flutter
import MSAL
import UIKit

/// This is the main entry point for the Flutter plugin.
/// It manages the method calls from Flutter & sets results accordingly.
public class MsalAuthPlugin: NSObject, FlutterPlugin, FlutterSceneLifeCycleDelegate {

    /// Initializes method channel and register method call delegate.
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "msal_auth", binaryMessenger: registrar.messenger())
        let instance = MsalAuthPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)

        // Register AppDelegate to handle URL callback.
        registrar.addApplicationDelegate(instance)

        // Register SceneDelegate to handle URL callback.
        registrar.addSceneDelegate(instance)
    }

    /// Handles the URL callback from the browser / third party app.
    /// Used when iOS app uses `AppDelegate`.
    public func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        return MSALPublicClientApplication.handleMSALResponse(
            url,
            sourceApplication: options[UIApplication.OpenURLOptionsKey.sourceApplication] as? String
        )
    }

    /// Handles the URL callback from the browser / third party app.
    /// Used when iOS app uses `SceneDelegate`.
    public func scene(
    _ scene: UIScene,
    openURLContexts URLContexts: Set<UIOpenURLContext>
    ) -> Bool {
        guard let url = URLContexts.first?.url else { return false }
        return MSALPublicClientApplication.handleMSALResponse(
            url,
            sourceApplication: URLContexts.first?.options.sourceApplication
        )
    }

    /// Handles method calls received from Dart.
    public func handle(
        _ call: FlutterMethodCall, result: @escaping FlutterResult
    ) {
        switch call.method {
        case "createSingleAccountPca", "createMultipleAccountPca":
            guard let dict = call.arguments as? NSDictionary,
                let pcaType: PublicClientApplicationType = {
                    switch call.method {
                    case "createSingleAccountPca": return .single
                    default: return .multiple
                    }
                }(),
                let clientId = dict["clientId"] as? String,
                let broker = dict["broker"] as? String,
                let authorityType: AuthorityType = {
                    switch dict["authorityType"] as? String {
                    case "b2c": return .b2c
                    default: return .aad
                    }
                }()
            else {
                setInternalError(methodName: call.method, result: result)
                return
            }

            MsalAuth.broker = broker
            MsalAuth.authorityType = authorityType
            let authority = dict["authority"] as? String
            let redirectUri = dict["redirectUri"] as? String
            let keychainSharingGroup = dict["keychainSharingGroup"] as? String

            createPublicClientApplication(
                pcaType: pcaType,
                clientId: clientId, authority: authority,
                authorityType: authorityType,
                redirectUri: redirectUri,
                keychainSharingGroup: keychainSharingGroup,
                result: result)
        case "acquireToken":
            guard let dict = call.arguments as? NSDictionary,
                let scopes = dict["scopes"] as? [String],
                let prompt = dict["prompt"] as? String,
                let promptType: MSALPromptType = {
                    switch prompt {
                    case "selectAccount": return .selectAccount
                    case "login": return .login
                    case "consent": return .consent
                    case "create": return .create
                    case "whenRequired": return .promptIfNecessary
                    default: return .default
                    }
                }()
            else {
                setInternalError(methodName: call.method, result: result)
                return
            }

            let loginHint = dict["loginHint"] as? String
            let authority = dict["authority"] as? String
            
            let customWebViewConfig = dict["customWebViewConfig"] as? [String: Any]

            acquireToken(
                scopes: scopes, promptType: promptType, loginHint: loginHint, authority: authority,
                customWebViewConfig: customWebViewConfig,
                result: result)
        case "acquireTokenSilent":
            guard let dict = call.arguments as? NSDictionary,
                let scopes = dict["scopes"] as? [String]
            else {
                setInternalError(methodName: call.method, result: result)
                return
            }

            let identifier = dict["identifier"] as? String
            let authority = dict["authority"] as? String
            let forceRefresh = dict["forceRefresh"] as? Bool ?? false

            acquireTokenSilent(
                scopes: scopes, identifier: identifier, authority: authority,
                forceRefresh: forceRefresh, result: result)

        case "currentAccount": getCurrentAccount(result: result)

        case "signOut": signOut(result: result)

        case "getAccount":
            guard let identifier = call.arguments as? String else {
                setInternalError(methodName: call.method, result: result)
                return
            }

            if let account = getAccount(identifier: identifier, result: result) {
                result(getCurrentAccountDic(account))
            }

        case "getAccounts": getAccounts(result: result)

        case "removeAccount":
            guard let identifier = call.arguments as? String else {
                setInternalError(methodName: call.method, result: result)
                return
            }
            removeAccount(identifier: identifier, result: result)
            
        case "isSharedDevice": isSharedDevice(result: result)

        default: result(FlutterMethodNotImplemented)
        }
    }

    /// Creates public client application object.
    /// - Parameters:
    ///   - pcaType: Public client application type.
    ///   - clientId: Client ID from Azure Portal.
    ///   - authority: Authority URL.
    ///   - authorityType: Authority type.
    ///   - redirectUri: Redirect URI. When nil, MSAL derives the default.
    ///   - keychainSharingGroup: Keychain group of the token cache. When nil, MSAL uses its default group.
    ///   - result: Result of the method call.
    private func createPublicClientApplication(
        pcaType: PublicClientApplicationType,
        clientId: String, authority: String?,
        authorityType: AuthorityType,
        redirectUri: String?,
        keychainSharingGroup: String?,
        result: @escaping FlutterResult
    ) {
        // Sets broker availability. this is required to avoid error on PCA creation
        // when 'LSApplicationQueriesSchemes' is not defined in 'Info.plist'.
        switch MsalAuth.broker {
        case "webView", "safariBrowser":
            MSALGlobalConfig.brokerAvailability = .none
        default:
            MSALGlobalConfig.brokerAvailability = .auto
        }
        
        var pcaConfig: MSALPublicClientApplicationConfig!

        if authority != nil {
            guard let authorityUrl = URL(string: authority!) else {
                result(
                    FlutterError(
                        code: "INVALID_AUTHORITY",
                        message: "invalid authority URL has been provided",
                        details: nil))
                return
            }

            do {
                switch authorityType {
                case .b2c:
                    let b2cAuthority = try MSALB2CAuthority(url: authorityUrl)
                    pcaConfig = MSALPublicClientApplicationConfig(
                        clientId: clientId, redirectUri: redirectUri,
                        authority: b2cAuthority)
                    pcaConfig.knownAuthorities = [b2cAuthority]
                default:
                    let defaultAuthority = try MSALAuthority(url: authorityUrl)
                    pcaConfig = MSALPublicClientApplicationConfig(
                        clientId: clientId, redirectUri: redirectUri,
                        authority: defaultAuthority)
                }
            } catch let error as NSError {
                setMsalError(error: error, result: result)
                return
            }
        } else {
            pcaConfig = MSALPublicClientApplicationConfig(
                clientId: clientId, redirectUri: redirectUri, authority: nil)
        }

        if let keychainSharingGroup {
            pcaConfig.cacheConfig.keychainSharingGroup = keychainSharingGroup
        }

        do {
            let application = try MSALPublicClientApplication(
                configuration: pcaConfig)
            // We will only have a public client application object. Apple MSAL does not have specific class for different account mode (Single & multiple). So we just assigned type that we receives from Dart and then call methods as per the type.
            MsalAuth.publicClientApplication = application
            MsalAuth.pcaType = pcaType
            result(true)
        } catch let error as NSError {
            // Sets initialization error. This is a custom exception created at Dart side.
            result(
                FlutterError(
                    code: "PCA_INIT",
                    message: "Unable to create public client application: \(error.localizedDescription)",
                    details: nil))
        }
    }

    /// Acquires token from public client application.
    /// - Parameters:
    ///   - scopes: Scopes to be requested.
    ///   - promptType: Prompt type.
    ///   - loginHint: Login hint.
    ///   - authority: Authority URL to override default authority.
    ///   - result: Result of the method call.
    private func acquireToken(
        scopes: [String], promptType: MSALPromptType, loginHint: String?, authority: String?,
        customWebViewConfig: [String: Any]?,
        result: @escaping FlutterResult
    ) {
        guard let pca = MsalAuth.publicClientApplication else {
            setPcaInitError(methodName: "acquireToken", result: result)
            return
        }

        guard let viewController = UIViewController.keyViewController else {
            result(
                FlutterError(
                    code: "UI_UNAVAILABLE",
                    message: "Cannot present authentication UI. The view controller is not available. This may occur during app launch transitions. Retry with putting a delay of 500 ms.",
                    details: nil))
            return
        }
        let webViewParameters = MSALWebviewParameters(
            authPresentationViewController: viewController)

        if #available(iOS 13.0, *) {
            webViewParameters.prefersEphemeralWebBrowserSession = true
            switch MsalAuth.broker {
            case "webView":
                webViewParameters.webviewType = .wkWebView
                
                if let customWebViewConfig {
                    let customWebviewController = CustomWebviewController(config: customWebViewConfig)
                    customWebviewController.modalPresentationStyle = .fullScreen
                    viewController.present(customWebviewController, animated: true, completion: nil)
                    
                    webViewParameters.customWebview = customWebviewController.getWebView()
                }
            case "safariBrowser":
                webViewParameters.webviewType = .safariViewController
            default:
                webViewParameters.webviewType = .default
            }
        }

        let tokenParams = MSALInteractiveTokenParameters(
            scopes: scopes, webviewParameters: webViewParameters)

        tokenParams.promptType = promptType
        tokenParams.loginHint = loginHint
        
        if let authority = authority {
            do {
                let msalAuthority = try getMsalAuthority(authority: authority)
                tokenParams.authority = msalAuthority
            } catch let error as NSError {
                setMsalError(error: error, result: result)
                return
            }
        }
        
        pca.acquireToken(
            with: tokenParams,
            completionBlock: { (msalresult, error) in
                guard let msalResult = msalresult else {

                    guard let error = error as NSError? else { return }

                    self.setMsalError(error: error, result: result)

                    return
                }

                result(self.getAuthResult(msalResult))
            })
    }

    /// Acquires token from public client application.
    /// - Parameters:
    ///   - scopes: Scopes to be requested.
    ///   - identifier: Account identifier.
    ///   - authority: Authority URL to override cached account's authority.
    ///   - forceRefresh: Whether to skip the cached access token and refresh it.
    ///   - result: Result of the method call.
    private func acquireTokenSilent(
        scopes: [String], identifier: String? = nil, authority: String?,
        forceRefresh: Bool, result: @escaping FlutterResult
    ) {
        guard let pca = MsalAuth.publicClientApplication else {
            setPcaInitError(methodName: "acquireTokenSilent", result: result)
            return
        }

        if MsalAuth.pcaType == PublicClientApplicationType.single {
            getCurrentAccount { currentAccount, error in
                guard let currentAccount else {
                    if let error {
                        self.setMsalError(error: error, result: result)
                    } else {
                        self.setNoCurrentAccountError(result: result)
                    }
                    return
                }
                self.executeSilentRequest(pca: pca, account: currentAccount, scopes: scopes, authority: authority, forceRefresh: forceRefresh, result: result)
            }
            return
        }
        
        guard let account = getAccount(identifier: identifier!) else {
            setNoCurrentAccountError(result: result)
            return
        }
        
        executeSilentRequest(pca: pca, account: account, scopes: scopes, authority: authority, forceRefresh: forceRefresh, result: result)
    }

    /// Returns current account. used with single account mode.
    /// `completion` receives the MSAL error when the account lookup fails, so callers
    /// do not report it as "no current account".
    private func getCurrentAccount(
        result: FlutterResult? = nil,
        completion: ((MSALAccount?, NSError?) -> Void)? = nil
    ) {
        guard let pca = MsalAuth.publicClientApplication else {
            if let result {
                setPcaInitError(methodName: "getCurrentAccount", result: result)
            }
            completion?(nil, nil)
            return
        }

        pca.getCurrentAccount(with: MSALParameters()) {
            current, previous, error in
            if let current {
                result?(self.getCurrentAccountDic(current))
                completion?(current, nil)
                return
            }

            if let result {
                if let error = error as NSError? {
                    self.setMsalError(error: error, result: result)
                } else {
                    self.setNoCurrentAccountError(result: result)
                }
            }
            completion?(nil, error as NSError?)
        }
    }

    /// Signs out from public client application. used with single account mode.
    /// - Parameter result: Result of the method call.
    private func signOut(result: @escaping FlutterResult) {
        guard let pca = MsalAuth.publicClientApplication else {
            setPcaInitError(methodName: "signOut", result: result)
            return
        }
        
        getCurrentAccount { currentAccount, error in
            guard let currentAccount else {
                if let error {
                    self.setMsalError(error: error, result: result)
                } else {
                    self.setNoCurrentAccountError(result: result)
                }
                return
            }
            
            pca.signout(
                with: currentAccount, signoutParameters: MSALSignoutParameters()
            ) { success, error in
                guard let error else {
                    result(success)
                    return
                }

                if let error = error as NSError? {
                    self.setMsalError(error: error, result: result)
                }
            }
        }
    }

    /// Returns account with given identifier. used with multiple account mode.
    /// - Parameters:
    ///   - identifier: Account identifier.
    ///   - result: Result of the method call.
    @discardableResult
    private func getAccount(identifier: String, result: FlutterResult? = nil)
        -> MSALAccount?
    {
        guard let pca = MsalAuth.publicClientApplication else {
            if result != nil {
                setPcaInitError(methodName: "getAccount", result: result!)
            }
            return nil
        }

        do {
            return try pca.account(forIdentifier: identifier)
        } catch let error as NSError {
            if result != nil {
                setMsalError(error: error, result: result!)
            }
            return nil
        }
    }

    /// Returns all accounts from public client application. used with multiple account mode.
    /// - Parameter result: Result of the method call.
    private func getAccounts(result: @escaping FlutterResult) {
        guard let pca = MsalAuth.publicClientApplication else {
            setPcaInitError(methodName: "getAccounts", result: result)
            return
        }

        do {
            let accounts = try pca.allAccounts()
            result(accounts.map { getCurrentAccountDic($0) })
        } catch let error as NSError {
            setMsalError(error: error, result: result)
        }
    }

    /// Removes account from public client application. used with multiple account mode.
    /// - Parameters: 
    ///   - identifier: Account identifier.
    ///   - result: Result of the method call.
    private func removeAccount(
        identifier: String, result: @escaping FlutterResult
    ) {
        let account = getAccount(identifier: identifier)

        guard let account else {
            setNoCurrentAccountError(result: result)
            return
        }

        do {
            try MsalAuth.publicClientApplication.remove(account)
            result(true)
        } catch let error as NSError {
            setMsalError(error: error, result: result)
        }
    }
    
    private func isSharedDevice(result: @escaping FlutterResult) {
        guard let pca = MsalAuth.publicClientApplication else {
            setPcaInitError(methodName: "isSharedDevice", result: result)
            return
        }
        
        pca.getDeviceInformation(with: nil) { deviceInformation, _ in
            result(deviceInformation?.deviceMode == .shared)
        }
    }
}

// MARK: - MsalAuthPlugin
extension MsalAuthPlugin {
    /// Returns the object of MSAL Authority based on the authority type.
    /// - Parameter authority: authority URL in string.
    /// - Returns: `MSALAuthority`.
    fileprivate func getMsalAuthority(authority: String) throws -> MSALAuthority {
        switch (MsalAuth.authorityType) {
            case .b2c:
            return try MSALB2CAuthority(url: URL(string: authority)!)
        default:
            return try MSALAuthority(url: URL(string: authority)!)
        }
    }
    
    /// Performs a silent token request with the given account.
    /// - Parameters:
    ///   - pca: Public client application.
    ///   - account: Account to acquire token for.
    ///   - scopes: Scopes to be requested.
    ///   - authority: Authority URL to override cached account's authority.
    ///   - forceRefresh: Whether to skip the cached access token and refresh it.
    ///   - result: Result of the method call.
    fileprivate func executeSilentRequest(
        pca: MSALPublicClientApplication,
        account: MSALAccount,
        scopes: [String],
        authority: String?,
        forceRefresh: Bool,
        result: @escaping FlutterResult
    ) {
        let silentParams = MSALSilentTokenParameters(scopes: scopes, account: account)
        silentParams.forceRefresh = forceRefresh

        if let authority {
            do {
                silentParams.authority = try getMsalAuthority(authority: authority)
            } catch let error as NSError {
                setMsalError(error: error, result: result)
                return
            }
        }

        pca.acquireTokenSilent(with: silentParams) { msalResult, error in
            guard let msalResult else {
                guard let error = error as NSError? else { return }
                self.setMsalError(error: error, result: result)
                return
            }
            result(self.getAuthResult(msalResult))
        }
    }
    
    /// Returns auth result dictionary. used to set result to Dart.
    /// - Parameter authResult: Auth result.
    /// - Returns: Auth result dictionary.
    fileprivate func getAuthResult(_ authResult: MSALResult) -> [String: Any] {
        var authResultDic = [String: Any]()
        authResultDic["accessToken"] = authResult.accessToken
        authResultDic["authenticationScheme"] = authResult.authenticationScheme
        authResultDic["expiresOn"] = Int(
            authResult.expiresOn!.timeIntervalSince1970 * 1000.0)
        authResultDic["idToken"] = authResult.idToken
        authResultDic["authority"] = authResult.authority.url.absoluteString
        authResultDic["tenantId"] = authResult.tenantProfile.tenantId
        authResultDic["scopes"] = authResult.scopes
        authResultDic["correlationId"] = authResult.correlationId.uuidString
        authResultDic["account"] = getCurrentAccountDic(authResult.account)

        return authResultDic
    }

    /// Returns current account dictionary.
    /// - Parameter account: Current account.
    /// - Returns: Current account dictionary.
    fileprivate func getCurrentAccountDic(_ account: MSALAccount) -> [String:
        Any]
    {
        var accountDic = [String: Any]()
        accountDic["id"] = account.identifier
        accountDic["username"] = account.username
        accountDic["name"] = account.accountClaims?["name"]
        return accountDic
    }
}

// MARK: - MsalAuthPlugin
extension MsalAuthPlugin {
    /// Sets internal error to result due to provided invalid data from Dart.
    /// - Parameters:
    ///   - methodName: Method name.
    ///   - result: Result of the method call.
    fileprivate func setInternalError(
        methodName: String, result: @escaping FlutterResult
    ) {
        result(
            FlutterError(
                code: "INVALID_DATA",
                message: "Invalid data has been provided on method \(methodName).",
                details: nil))
    }

    /// Sets public client application initialization error to result. This is a custom exception created at Dart side.
    /// - Parameters:
    ///   - methodName: Method name.
    ///   - result: Result of the method call.
    fileprivate func setPcaInitError(
        methodName: String, result: @escaping FlutterResult
    ) {
        result(
            FlutterError(
                code: "PCA_INIT",
                message:
                    "PublicClientApplication should be initialized to call \(methodName).",
                details: nil))
    }

    /// Sets no current account error to result.
    /// - Parameter result: Result of the method call.
    fileprivate func setNoCurrentAccountError(result: @escaping FlutterResult) {
        result(
            FlutterError(
                code: "NO_CURRENT_ACCOUNT",
                message: "There is no currently signed in account.",
                details: nil))
    }

    /// Common MSAL error handling function that returns error to Dart.
    /// - Parameters:
    ///   - error: MSAL error.
    ///   - result: Result of the method call.
    fileprivate func setMsalError(
        error: NSError, result: @escaping FlutterResult
    ) {
        var flutterErrorCode: String!
        var errorMessage: Any?
        var errorDetails = [String: Any]()

        if error.domain == MSALErrorDomain,
            let errorCode = MSALError(rawValue: error.code)
        {
            errorMessage = error.userInfo[MSALErrorDescriptionKey]
            errorDetails["correlationId"] = error.userInfo[MSALCorrelationIDKey]
            
            switch errorCode {
            case .userCanceled:
                flutterErrorCode = "USER_CANCEL"
            case .serverDeclinedScopes:
                flutterErrorCode = "DECLINED_SCOPE"
                errorDetails["grantedScopes"] = error.userInfo[MSALGrantedScopesKey]
                errorDetails["declinedScopes"] = error.userInfo[MSALDeclinedScopesKey]
            case .serverProtectionPoliciesRequired:
                flutterErrorCode = "PROTECTION_POLICY_REQUIRED"
            case .interactionRequired:
                flutterErrorCode = "UI_REQUIRED"
                errorDetails["oauthError"] = error.userInfo[MSALOAuthErrorKey]
                errorDetails["oauthErrorDescription"] = error.userInfo[MSALOAuthSubErrorDescriptionKey]
            case .internal:
                flutterErrorCode = "INTERNAL_ERROR"
                errorDetails["internalErrorCode"] = error.userInfo[MSALInternalErrorCodeKey]
            case .workplaceJoinRequired:
                flutterErrorCode = "WORKPLACE_JOIN_REQUIRED"
            case .serverError:
                flutterErrorCode = "SERVER_ERROR"
            case .insufficientDeviceStrength:
                flutterErrorCode = "INSUFFICIENT_DEVICE_STRENGTH"
            default:
                flutterErrorCode = error.domain
            }
        } else {
            flutterErrorCode = error.domain
            errorMessage = error.localizedDescription
        }

        result(
            FlutterError(
                code: flutterErrorCode, message: errorMessage as? String,
                details: errorDetails))
    }
}

// MARK: - UIViewController
extension UIViewController {
    static var keyViewController: UIViewController? {
        if #available(iOS 15, *) {
            return
                (UIApplication.shared.connectedScenes.filter({
                    $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive
                }).compactMap({ $0 as? UIWindowScene }).first?.windows.filter({
                    $0.isKeyWindow
                }).first?.rootViewController)
        } else {
            return UIApplication.shared.windows.first(where: { $0.isKeyWindow }
            )?.rootViewController
        }
    }
}
