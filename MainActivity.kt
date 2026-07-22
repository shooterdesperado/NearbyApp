package com.example.nearbyapp

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.material3.MaterialTheme

class MainActivity : ComponentActivity() {

    private lateinit var nearbyManager: NearbyManager

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        nearbyManager = NearbyManager(this)

        // Set isTablet = true when building/running on the tablet,
        // false for the phone build.
        val isTablet = false

        setContent {
            MaterialTheme {
                NearbyScreen(nearbyManager, isTablet)
            }
        }
    }
}
