package com.scyde.lumaauth

import android.net.Uri
import android.util.Log
import androidx.browser.customtabs.CustomTabsIntent
import androidx.credentials.ClearCredentialStateRequest
import androidx.credentials.CredentialManager
import androidx.credentials.CustomCredential
import androidx.credentials.GetCredentialRequest
import androidx.credentials.exceptions.GetCredentialCancellationException
import androidx.credentials.exceptions.GetCredentialException
import com.google.android.libraries.identity.googleid.GetSignInWithGoogleOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot
import org.json.JSONObject
import java.security.SecureRandom

/**
 * LUMA sign-in for Android, used by scripts/cloud/native_auth.gd as the "LumaAuth" singleton.
 *
 * Google: Credential Manager's "Sign in with Google" sheet; the ID token's audience is the
 * Google *web* client id, which the server accepts (GOOGLE_CLIENT_IDS).
 * Facebook: the Facebook login page in a Custom Tab; Facebook redirects to fb<app id>://authorize
 * with an access token, which the server checks with the Graph API.
 * Apple: not offered on Android.
 *
 * Every attempt ends with the signal sign_in_completed(provider, token, error).
 */
class LumaAuthPlugin(godot: Godot) : GodotPlugin(godot) {

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private var googleWebClientId = ""
    private var facebookAppId = ""
    private var facebookState = ""

    override fun getPluginName() = "LumaAuth"

    override fun getPluginSignals() = setOf(
        SignalInfo("sign_in_completed", String::class.java, String::class.java, String::class.java)
    )

    override fun onMainCreate(activity: android.app.Activity?): android.view.View? {
        instance = this
        return null
    }

    /** Settings from resources/cloud/cloud_config.json, as JSON. */
    @UsedByGodot
    fun configure(json: String) {
        try {
            val o = JSONObject(json)
            googleWebClientId = o.optString("google_web_client_id", "")
            facebookAppId = o.optString("facebook_app_id", "")
        } catch (e: Exception) {
            Log.w(TAG, "bad config", e)
        }
    }

    @UsedByGodot
    fun is_available(provider: String): Boolean = when (provider) {
        "google" -> googleWebClientId.isNotEmpty()
        "facebook" -> facebookAppId.isNotEmpty()
        else -> false
    }

    @UsedByGodot
    fun sign_in(provider: String, nonce: String) {
        when (provider) {
            "google" -> signInGoogle(nonce)
            "facebook" -> signInFacebook()
            else -> finish(provider, "", "unsupported")
        }
    }

    @UsedByGodot
    fun sign_out(provider: String) {
        if (provider != "google") return
        val act = activity ?: return
        scope.launch {
            try {
                CredentialManager.create(act).clearCredentialState(ClearCredentialStateRequest())
            } catch (e: Exception) {
                Log.w(TAG, "clear credential state", e)
            }
        }
    }

    private fun signInGoogle(nonce: String) {
        val act = activity ?: return finish("google", "", "no activity")
        val option = GetSignInWithGoogleOption.Builder(googleWebClientId).setNonce(nonce).build()
        val request = GetCredentialRequest.Builder().addCredentialOption(option).build()
        scope.launch {
            try {
                val result = CredentialManager.create(act).getCredential(act, request)
                val c = result.credential
                if (c is CustomCredential && c.type == GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL) {
                    finish("google", GoogleIdTokenCredential.createFrom(c.data).idToken, "")
                } else {
                    finish("google", "", "unexpected credential")
                }
            } catch (e: GetCredentialCancellationException) {
                finish("google", "", "cancelled")
            } catch (e: GetCredentialException) {
                finish("google", "", e.type)
            } catch (e: Exception) {
                finish("google", "", e.javaClass.simpleName)
            }
        }
    }

    private fun signInFacebook() {
        val act = activity ?: return finish("facebook", "", "no activity")
        val bytes = ByteArray(16).also { SecureRandom().nextBytes(it) }
        facebookState = bytes.joinToString("") { "%02x".format(it) }
        val uri = Uri.parse("https://www.facebook.com/v19.0/dialog/oauth").buildUpon()
            .appendQueryParameter("client_id", facebookAppId)
            .appendQueryParameter("redirect_uri", "fb$facebookAppId://authorize/")
            .appendQueryParameter("response_type", "token")
            .appendQueryParameter("scope", "public_profile")
            .appendQueryParameter("state", facebookState)
            .build()
        act.runOnUiThread { CustomTabsIntent.Builder().build().launchUrl(act, uri) }
    }

    /** Called by RedirectActivity with fb<app id>://authorize/#access_token=...&state=... */
    internal fun onFacebookRedirect(uri: Uri) {
        val params = Uri.parse("x://x?" + (uri.fragment ?: uri.query ?: ""))
        val token = params.getQueryParameter("access_token") ?: ""
        val state = params.getQueryParameter("state") ?: ""
        when {
            params.getQueryParameter("error") != null -> finish("facebook", "", params.getQueryParameter("error") ?: "error")
            state != facebookState || token.isEmpty() -> finish("facebook", "", "bad redirect")
            else -> finish("facebook", token, "")
        }
        facebookState = ""
    }

    private fun finish(provider: String, token: String, error: String) {
        runOnRenderThread { emitSignal("sign_in_completed", provider, token, error) }
    }

    companion object {
        private const val TAG = "LumaAuth"
        internal var instance: LumaAuthPlugin? = null
    }
}
