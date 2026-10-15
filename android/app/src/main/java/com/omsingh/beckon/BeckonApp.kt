package com.omsingh.beckon

import android.app.Application
import com.omsingh.beckon.service.BeckonConnectionService

/**
 * Application class. Eagerly creates the foreground service notification
 * channel so it exists before any connect() call.
 */
class BeckonApp : Application() {

    companion object {
        @Volatile
        lateinit var instance: BeckonApp
            private set
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        BeckonConnectionService.ensureNotificationChannel(this)
    }
}
