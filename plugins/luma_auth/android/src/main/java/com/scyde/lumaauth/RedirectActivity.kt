package com.scyde.lumaauth

import android.app.Activity
import android.os.Bundle

/** Receives Facebook's redirect (fb<app id>://authorize/...) from the Custom Tab and hands it back. */
class RedirectActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        intent?.data?.let { LumaAuthPlugin.instance?.onFacebookRedirect(it) }
        finish()
    }
}
