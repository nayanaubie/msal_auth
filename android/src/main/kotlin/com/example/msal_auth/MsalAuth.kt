package com.example.msal_auth

import android.app.Activity
import android.content.Context
import com.microsoft.identity.client.AuthenticationCallback
import com.microsoft.identity.client.IAccount
import com.microsoft.identity.client.IAuthenticationResult
import com.microsoft.identity.client.IMultipleAccountPublicClientApplication
import com.microsoft.identity.client.IMultipleAccountPublicClientApplication.GetAccountCallback
import com.microsoft.identity.client.IMultipleAccountPublicClientApplication.RemoveAccountCallback
import com.microsoft.identity.client.IPublicClientApplication
import com.microsoft.identity.client.IPublicClientApplication.IMultipleAccountApplicationCreatedListener
import com.microsoft.identity.client.IPublicClientApplication.ISingleAccountApplicationCreatedListener
import com.microsoft.identity.client.IPublicClientApplication.LoadAccountsCallback
import com.microsoft.identity.client.ISingleAccountPublicClientApplication
import com.microsoft.identity.client.ISingleAccountPublicClientApplication.CurrentAccountCallback
import com.microsoft.identity.client.ISingleAccountPublicClientApplication.SignOutCallback
import com.microsoft.identity.client.SilentAuthenticationCallback
import com.microsoft.identity.client.configuration.AccountMode
import com.microsoft.identity.client.exception.MsalArgumentException
import com.microsoft.identity.client.exception.MsalClientException
import com.microsoft.identity.client.exception.MsalDeclinedScopeException
import com.microsoft.identity.client.exception.MsalException
import com.microsoft.identity.client.exception.MsalIntuneAppProtectionPolicyRequiredException
import com.microsoft.identity.client.exception.MsalServiceException
import com.microsoft.identity.client.exception.MsalUiRequiredException
import com.microsoft.identity.client.exception.MsalUnsupportedBrokerException
import com.microsoft.identity.client.exception.MsalUserCancelException
import com.microsoft.identity.common.java.util.SchemaUtil
import io.flutter.plugin.common.MethodChannel

/**
 * Class that manages every async callbacks for method that is called from auth handler.
 * Sets the appropriate result for Dart.
 */
class MsalAuth(internal val context: Context) {

    internal lateinit var activity: Activity

    lateinit var iPublicClientApplication: IPublicClientApplication
    var iSingleAccountPca: ISingleAccountPublicClientApplication? = null
    var iMultipleAccountPca: IMultipleAccountPublicClientApplication? = null

    fun setActivity(activity: Activity) {
        this.activity = activity
    }

    /**
     * Checks if the public client application is initialized.
     */
    internal fun isPcaInitialized(): Boolean = ::iPublicClientApplication.isInitialized

    /**
     * Gets the account mode of the public client application.
     */
    internal fun getAccountMode(): AccountMode = iPublicClientApplication.configuration.accountMode

    /**
     * Listener for creating a single account public client application.
     */
    internal fun singleAccountApplicationCreatedListener(result: MethodChannel.Result): ISingleAccountApplicationCreatedListener {
        return object : ISingleAccountApplicationCreatedListener {
            override fun onCreated(application: ISingleAccountPublicClientApplication) {
                iSingleAccountPca = application
                iPublicClientApplication = application
                result.success(true)
            }

            override fun onError(exception: MsalException) {
                setMsalException(exception, result)
            }
        }
    }

    /**
     * Listener for creating a multiple account public client application.
     */
    internal fun multipleAccountApplicationCreatedListener(result: MethodChannel.Result): IMultipleAccountApplicationCreatedListener {
        return object : IMultipleAccountApplicationCreatedListener {
            override fun onCreated(application: IMultipleAccountPublicClientApplication) {
                iMultipleAccountPca = application
                iPublicClientApplication = application
                result.success(true)
            }

            override fun onError(exception: MsalException) {
                setMsalException(exception, result)
            }
        }
    }

    /**
     * Authentication callback for acquiring tokens using interactively.
     */
    internal fun authenticationCallback(result: MethodChannel.Result): AuthenticationCallback {
        return object : AuthenticationCallback {
            override fun onSuccess(authenticationResult: IAuthenticationResult) {
                setAuthenticationResult(authenticationResult, result)
            }

            override fun onError(exception: MsalException) {
                setMsalException(exception, result)
            }

            override fun onCancel() {
                setMsalException(MsalUserCancelException(), result)
            }
        }
    }

    /**
     * Authentication callback for acquiring tokens using silently.
     */
    internal fun silentAuthenticationCallback(result: MethodChannel.Result): SilentAuthenticationCallback {
        return object : SilentAuthenticationCallback {
            override fun onSuccess(authenticationResult: IAuthenticationResult) {
                setAuthenticationResult(authenticationResult, result)
            }

            override fun onError(exception: MsalException) {
                setMsalException(exception, result)
            }
        }
    }

    /**
     * Returns the current account map. this is used to send result to Dart.
     *
     * @param account Microsoft account
     */
    private fun getCurrentAccountMap(account: IAccount): Map<String, Any?> {
        return mutableMapOf<String, Any?>().apply {
            put("id", account.id)
            put(
                "username",
                if (account.username == SchemaUtil.MISSING_FROM_THE_TOKEN_RESPONSE) null else account.username
            )
            put("name", account.claims?.get("name"))
        }
    }

    /**
     * Sets the authentication result for Dart.
     *
     * @param authenticationResult authentication result received from token acquisition.
     * @param result the result of the method call.
     */
    private fun setAuthenticationResult(
        authenticationResult: IAuthenticationResult,
        result: MethodChannel.Result
    ) {
        val authResult = mutableMapOf<String, Any?>().apply {
            put("accessToken", authenticationResult.accessToken)
            put("authenticationScheme", authenticationResult.authenticationScheme)
            put("expiresOn", authenticationResult.expiresOn.time)
            put("idToken", authenticationResult.account.idToken)
            put("authority", authenticationResult.account.authority)
            put("tenantId", authenticationResult.tenantId)
            put("scopes", authenticationResult.scope.toList())
            put("correlationId", authenticationResult.correlationId.toString())
            put("account", getCurrentAccountMap(authenticationResult.account))
        }

        result.success(authResult)
    }

    /**
     * Callback for getting the current account.
     */
    internal fun currentAccountCallback(result: MethodChannel.Result): CurrentAccountCallback {
        // MSAL may invoke multiple callbacks (`onAccountLoaded` and `onAccountChanged`) when logged-in user clears
        // the app storage and try to call `getCurrentAccount` method directly after opening the app. #issue/116
        var replied = false

        return object : CurrentAccountCallback {
            override fun onAccountLoaded(activeAccount: IAccount?) {
                if (replied) return
                replied = true

                if (activeAccount == null) {
                    setNoCurrentAccountException(result)
                    return
                }
                result.success(getCurrentAccountMap(activeAccount))
            }

            override fun onAccountChanged(priorAccount: IAccount?, currentAccount: IAccount?) {
                if (replied) return
                replied = true

                if (currentAccount == null) {
                    setNoCurrentAccountException(result)
                    return
                }
                result.success(getCurrentAccountMap(currentAccount))
            }

            override fun onError(exception: MsalException) {
                if (replied) return
                replied = true

                setMsalException(exception, result)
            }
        }
    }

    /**
     * Callback for signing out the current account.
     */
    internal fun signOutCallback(result: MethodChannel.Result): SignOutCallback {
        return object : SignOutCallback {
            override fun onSignOut() {
                result.success(true)
            }

            override fun onError(exception: MsalException) {
                setMsalException(exception, result)
            }
        }
    }

    /**
     * Callback for getting account details of given identifier.
     */
    internal fun accountCallback(result: MethodChannel.Result): GetAccountCallback {
        return object : GetAccountCallback {
            override fun onTaskCompleted(account: IAccount) {
                result.success(getCurrentAccountMap(account))
            }

            override fun onError(exception: MsalException) {
                setMsalException(exception, result)
            }
        }
    }

    /**
     * Callback for getting all accounts.
     */
    internal fun loadAccountsCallback(result: MethodChannel.Result): LoadAccountsCallback {
        return object : LoadAccountsCallback {
            override fun onTaskCompleted(accounts: MutableList<IAccount>) {
                result.success(accounts.map { getCurrentAccountMap(it) })
            }

            override fun onError(exception: MsalException) {
                setMsalException(exception, result)
            }
        }
    }

    /**
     * Callback for removing an account.
     */
    internal fun removeAccountCallback(result: MethodChannel.Result): RemoveAccountCallback {
        return object : RemoveAccountCallback {
            override fun onRemoved() {
                result.success(true)
            }

            override fun onError(exception: MsalException) {
                setMsalException(exception, result)
            }
        }
    }

    /**
     * Sets no current account exception.
     */
    internal fun setNoCurrentAccountException(result: MethodChannel.Result) {
        // Send the exception "NO_CURRENT_ACCOUNT" directly to Flutter
        result.error(
            MsalClientException.NO_CURRENT_ACCOUNT.uppercase(),
            MsalClientException.NO_CURRENT_ACCOUNT_ERROR_MESSAGE,
            null
        )
    }

    /**
     * Common [MsalException] handling function that returns error to Dart.
     */
    internal fun setMsalException(exception: MsalException, result: MethodChannel.Result) {
        lateinit var flutterErrorCode: String
        val errorDetails = mutableMapOf<String, Any?>().apply {
            put("correlationId", exception.correlationId)
        }

        when (exception) {
            is MsalUserCancelException -> flutterErrorCode = "USER_CANCEL"

            is MsalDeclinedScopeException -> {
                flutterErrorCode = "DECLINED_SCOPE"
                errorDetails.apply {
                    put("grantedScopes", exception.grantedScopes)
                    put("declinedScopes", exception.declinedScopes)
                }
            }

            is MsalIntuneAppProtectionPolicyRequiredException -> {
                flutterErrorCode = "PROTECTION_POLICY_REQUIRED"
                errorDetails.apply {
                    put("accountUpn", exception.accountUpn)
                    put("accountUserId", exception.accountUserId)
                    put("tenantId", exception.tenantId)
                    put("authorityUrl", exception.authorityUrl)
                }
            }

            is MsalUiRequiredException -> {
                flutterErrorCode = "UI_REQUIRED"
                errorDetails.apply {
                    put("oauthSubErrorCode", exception.oauthSubErrorCode)
                }
            }

            is MsalArgumentException -> {
                flutterErrorCode = "INVALID_ARGUMENT"
                errorDetails.apply {
                    put("argumentName", exception.argumentName)
                    put("operationName", exception.operationName)
                }
            }

            is MsalClientException -> {
                flutterErrorCode = "CLIENT_ERROR"
                errorDetails.apply {
                    put("errorCode", exception.errorCode)
                }
            }

            is MsalServiceException -> {
                flutterErrorCode = "SERVICE_ERROR"
                errorDetails.apply {
                    put("errorCode", exception.errorCode)
                    put("httpStatusCode", exception.httpStatusCode)
                }
            }

            is MsalUnsupportedBrokerException -> {
                flutterErrorCode = "UNSUPPORTED_BROKER"
                errorDetails.apply {
                    put("activeBrokerPackageName", exception.activeBrokerPackageName)
                }
            }

            else -> flutterErrorCode = exception.errorCode
        }

        result.error(flutterErrorCode, exception.localizedMessage, errorDetails)
    }
}

