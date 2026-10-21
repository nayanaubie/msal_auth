package com.example.msal_auth

import android.annotation.SuppressLint
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import com.google.gson.Gson
import com.microsoft.identity.client.AcquireTokenParameters
import com.microsoft.identity.client.AcquireTokenSilentParameters
import com.microsoft.identity.client.MultipleAccountPublicClientApplication
import com.microsoft.identity.client.Prompt
import com.microsoft.identity.client.SingleAccountPublicClientApplication
import com.microsoft.identity.client.configuration.AccountMode
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Handler for the plugin. manages the method calls from Flutter.
 */
class MsalAuthHandler(private val msal: MsalAuth) : MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel

    /**
     * Notifies Dart when the account of a device in shared device mode changes, e.g. when another
     * app signs the user in or out. Dart reads the current account again in response.
     */
    private val accountChangedReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            channel.invokeMethod("currentAccountChanged", null)
        }
    }

    /**
     * Initializes the method channel & sets the handler.
     *
     * @param messenger the binary messenger from Engine.
     */
    fun initialize(messenger: BinaryMessenger) {
        channel = MethodChannel(messenger, "msal_auth")
        channel.setMethodCallHandler(this)
        registerAccountChangedReceiver()
    }

    /**
     * Removes the method call handler.
     */
    fun dispose() {
        channel.setMethodCallHandler(null)
        msal.context.unregisterReceiver(accountChangedReceiver)
    }

    /**
     * Registers [accountChangedReceiver] for the broadcast sent on account changes in shared device mode.
     * https://learn.microsoft.com/entra/msal/android/shared-devices
     */
    @SuppressLint("UnspecifiedRegisterReceiverFlag")
    private fun registerAccountChangedReceiver() {
        val filter = IntentFilter(CURRENT_ACCOUNT_CHANGED_BROADCAST)
        // The broadcast is sent by the broker app, so the receiver has to be exported.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            msal.context.registerReceiver(accountChangedReceiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            msal.context.registerReceiver(accountChangedReceiver, filter)
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "createSingleAccountPca", "createMultipleAccountPca" -> {
                val config = call.argument<HashMap<String, Any>>("config")!!
                val configFile = File(msal.context.cacheDir, "msal_config.json").apply {
                    writeText(Gson().toJson(config))
                }
                if (call.method == "createSingleAccountPca") {
                    createSingleAccountPca(configFile, result)
                } else {
                    createMultipleAccountPca(configFile, result)
                }
            }

            "acquireToken" -> {
                val scopes: List<String> = call.argument<List<String>>("scopes")!!.toList()
                val promptArg: String? = call.argument("prompt")
                val loginHint: String? = call.argument("loginHint")
                val authority: String? = call.argument("authority")

                val prompt: Prompt = when (promptArg) {
                    "selectAccount" -> Prompt.SELECT_ACCOUNT
                    "login" -> Prompt.LOGIN
                    "consent" -> Prompt.CONSENT
                    "create" -> Prompt.CREATE
                    else -> Prompt.WHEN_REQUIRED
                }
                Thread { acquireToken(scopes, prompt, loginHint, authority, result) }.start()
            }

            "acquireTokenSilent" -> {
                val scopes: List<String> = call.argument<List<String>>("scopes")!!.toList()
                val identifier: String? = call.argument("identifier")
                val authority: String? = call.argument("authority")
                Thread { acquireTokenSilent(scopes, identifier, authority, result) }.start()
            }

            "currentAccount" -> getCurrentAccount(result)

            "signOut" -> signOut(result)

            "getAccount" -> {
                val identifier = call.arguments as String
                getAccount(identifier, result)
            }

            "getAccounts" -> getAccounts(result)

            "removeAccount" -> {
                val identifier = call.arguments as String
                Thread { removeAccount(identifier, result) }.start()
            }

            "isSharedDevice" -> isSharedDevice(result)

            else -> result.notImplemented()
        }
    }

    /**
     * Creates a single account public client application.
     *
     * @param configFile the JSON configuration file.
     * @param result the result of the method call.
     */
    private fun createSingleAccountPca(configFile: File, result: MethodChannel.Result) {
        if (msal.isPcaInitialized() && msal.getAccountMode() == AccountMode.SINGLE) {
            result.success(true)
            return
        }

        SingleAccountPublicClientApplication.createSingleAccountPublicClientApplication(
            msal.context,
            configFile,
            msal.singleAccountApplicationCreatedListener(result)
        )
    }

    /**
     * Creates a multiple account public client application.
     *
     * @param configFile the JSON configuration file.
     * @param result the result of the method call.
     */
    private fun createMultipleAccountPca(configFile: File, result: MethodChannel.Result) {
        if (msal.isPcaInitialized() && msal.getAccountMode() == AccountMode.MULTIPLE) {
            result.success(true)
            return
        }

        MultipleAccountPublicClientApplication.createMultipleAccountPublicClientApplication(
            msal.context,
            configFile,
            msal.multipleAccountApplicationCreatedListener(result)
        )
    }

    /**
     * Acquires a token using the provided scopes, prompt and login hint.
     *
     * @param scopes the list of scopes.
     * @param prompt the prompt to use.
     * @param loginHint username, email or unique identifier.
     * @param authority authority URL to override default authority.
     * @param result the result of the method call.
     */
    private fun acquireToken(
        scopes: List<String>,
        prompt: Prompt,
        loginHint: String?,
        authority: String?,
        result: MethodChannel.Result
    ) {
        if (!msal.isPcaInitialized()) {
            setPcaInitError("acquireToken", result)
            return
        }

        msal.activity.let {
            val builder = AcquireTokenParameters.Builder()
            builder.startAuthorizationFromActivity(it)
                .withScopes(scopes.toList())
                .withPrompt(prompt)
                .withLoginHint(loginHint)
                .apply {
                    // If authority is provided, set it to the builder
                    if (authority != null) fromAuthority(authority)
                }
                .withCallback(msal.authenticationCallback(result))

            val acquireTokenParameters = builder.build()
            msal.iPublicClientApplication.acquireToken(acquireTokenParameters)
        }
    }

    /**
     * Acquire token silently.
     *
     * @param scopes the list of scopes.
     * @param identifier Account identifier.
     * @param authority authority URL to override cached account's authority.
     * @param result the result of the method call.
     */
    private fun acquireTokenSilent(
        scopes: List<String>,
        identifier: String? = null,
        authority: String?,
        result: MethodChannel.Result
    ) {
        if (!msal.isPcaInitialized()) {
            setPcaInitError("acquireTokenSilent", result)
            return
        }

        if (msal.iSingleAccountPca != null) {
            msal.iSingleAccountPca!!.currentAccount?.let { accountResult ->
                val currentAccount = accountResult.currentAccount
                if (currentAccount != null) {
                    val builder = AcquireTokenSilentParameters.Builder()
                    builder.withScopes(scopes.toList())
                        .forAccount(currentAccount)
                        .fromAuthority(authority ?: currentAccount.authority)
                        .withCallback(msal.silentAuthenticationCallback(result))
                    val acquireTokenParameters = builder.build()
                    msal.iPublicClientApplication.acquireTokenSilentAsync(acquireTokenParameters)
                } else {
                    msal.setNoCurrentAccountException(result)
                }
            }
        } else if (msal.iMultipleAccountPca != null) {
            msal.iMultipleAccountPca!!.getAccount(identifier!!)?.let { account ->
                val builder = AcquireTokenSilentParameters.Builder()
                builder.withScopes(scopes.toList())
                    .forAccount(account)
                    .fromAuthority(authority ?: account.authority)
                    .withCallback(msal.silentAuthenticationCallback(result))
                val acquireTokenParameters = builder.build()
                msal.iPublicClientApplication.acquireTokenSilentAsync(acquireTokenParameters)
            }
        }
    }

    /**
     * Get current signed in account. only applicable for single account mode.
     *
     * @param result the result of the method call.
     */
    private fun getCurrentAccount(result: MethodChannel.Result) {
        if (!msal.isPcaInitialized()) {
            setPcaInitError("currentAccount", result)
            return
        }

        msal.iSingleAccountPca?.getCurrentAccountAsync(msal.currentAccountCallback(result))
    }

    /**
     * Sign outs the current account. only applicable for single account mode.
     *
     * @param result the result of the method call.
     */
    private fun signOut(result: MethodChannel.Result) {
        if (!msal.isPcaInitialized()) {
            setPcaInitError("signOut", result)
            return
        }

        msal.iSingleAccountPca?.signOut(msal.signOutCallback(result))
    }

    /**
     * Get account details of given identifier. only applicable for multiple account mode.
     *
     * @param identifier Account identifier.
     * @param result the result of the method call.
     */
    private fun getAccount(identifier: String, result: MethodChannel.Result) {
        if (!msal.isPcaInitialized()) {
            setPcaInitError("getAccount", result)
            return
        }

        msal.iMultipleAccountPca?.getAccount(identifier, msal.accountCallback(result))
    }

    /**
     * Get all accounts. only applicable for multiple account mode.
     *
     * @param result the result of the method call.
     */
    private fun getAccounts(result: MethodChannel.Result) {
        if (!msal.isPcaInitialized()) {
            setPcaInitError("getAccounts", result)
            return
        }

        msal.iMultipleAccountPca?.getAccounts(msal.loadAccountsCallback(result))
    }

    /**
     * Remove account of given identifier. only applicable for multiple account mode.
     *
     * @param identifier Account identifier.
     * @param result the result of the method call.
     */
    private fun removeAccount(identifier: String, result: MethodChannel.Result) {
        if (!msal.isPcaInitialized()) {
            setPcaInitError("removeAccount", result)
            return
        }

        val account = msal.iMultipleAccountPca?.getAccount(identifier)
        msal.iMultipleAccountPca?.removeAccount(account, msal.removeAccountCallback(result))
    }

    /**
     * Check if the device is shared.
     *
     * @param result the result of the method call.
     */
    private fun isSharedDevice(result: MethodChannel.Result) {
        if (!msal.isPcaInitialized()) {
            setPcaInitError("isSharedDevice", result)
            return
        }

        result.success(msal.iPublicClientApplication.isSharedDevice)
    }

    /**
     * Set the error for public client app is not initialized.
     * This is a custom exception created at Dart side.
     *
     * @param methodName the name of the method called.
     * @param result the result of the method call.
     */
    private fun setPcaInitError(methodName: String, result: MethodChannel.Result) {
        result.error(
            "PCA_INIT",
            "PublicClientApplication should be initialized to call $methodName.",
            null
        )
    }

    companion object {
        private const val CURRENT_ACCOUNT_CHANGED_BROADCAST =
            "com.microsoft.identity.client.sharedmode.CURRENT_ACCOUNT_CHANGED"
    }
}