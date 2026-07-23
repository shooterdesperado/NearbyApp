#!/bin/bash
set -e

echo "=== Cleaning up misplaced files ==="
rm -f AndroidManifest.xml MainActivity.kt NearbyManager.kt build.gradle.kts

echo "=== Creating folder structure ==="
mkdir -p app/src/main/java/com/example/nearbyapp

echo "=== Writing settings.gradle.kts ==="
cat > settings.gradle.kts << 'EOF'
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
    }
}
rootProject.name = "nearby-connections-app"
include(":app")
EOF

echo "=== Writing root build.gradle.kts ==="
cat > build.gradle.kts << 'EOF'
plugins {
    id("com.android.application") version "8.2.0" apply false
    id("org.jetbrains.kotlin.android") version "1.9.20" apply false
}
EOF

echo "=== Writing app/build.gradle.kts ==="
cat > app/build.gradle.kts << 'EOF'
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.example.nearbyapp"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.example.nearbyapp"
        minSdk = 24
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"
    }

    buildFeatures {
        compose = true
    }
    composeOptions {
        kotlinCompilerExtensionVersion = "1.5.4"
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
}

dependencies {
    implementation("com.google.android.gms:play-services-nearby:19.3.0")
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.activity:activity-compose:1.8.2")
    implementation(platform("androidx.compose:compose-bom:2024.02.00"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.ui:ui-tooling-preview")
}
EOF

echo "=== Writing app/src/main/AndroidManifest.xml ==="
cat > app/src/main/AndroidManifest.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <uses-permission android:name="android.permission.BLUETOOTH_ADVERTISE" />
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
    <uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
    <uses-permission android:name="android.permission.CHANGE_WIFI_STATE" />
    <uses-permission android:name="android.permission.NEARBY_WIFI_DEVICES" />
    <uses-permission android:name="android.permission.INTERNET" />

    <application
        android:allowBackup="true"
        android:label="Nearby App"
        android:theme="@style/Theme.Material3.DayNight">
        <activity
            android:name=".MainActivity"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
EOF

echo "=== Writing MainActivity.kt ==="
cat > app/src/main/java/com/example/nearbyapp/MainActivity.kt << 'EOF'
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

        val isTablet = false

        setContent {
            MaterialTheme {
                NearbyScreen(nearbyManager, isTablet)
            }
        }
    }
}
EOF

echo "=== Writing NearbyManager.kt ==="
cat > app/src/main/java/com/example/nearbyapp/NearbyManager.kt << 'EOF'
package com.example.nearbyapp

import android.content.Context
import android.util.Log
import com.google.android.gms.nearby.Nearby
import com.google.android.gms.nearby.connection.*
import java.io.File

class NearbyManager(private val context: Context) {

    private val TAG = "NearbyManager"
    private val SERVICE_ID = "com.example.nearbyapp.SERVICE_ID"
    private val connectionsClient: ConnectionsClient = Nearby.getConnectionsClient(context)
    private val connectionStrategy = Strategy.P2P_POINT_TO_POINT

    private var activeEndpointId: String? = null

    interface NearbyUiListener {
        fun onConnectionRequestReceived(endpointName: String, token: String, endpointId: String)
        fun onConnected(endpointId: String)
        fun onDisconnected()
    }
    var uiListener: NearbyUiListener? = null

    private val connectionLifecycleCallback = object : ConnectionLifecycleCallback() {
        override fun onConnectionInitiated(endpointId: String, info: ConnectionInfo) {
            val secureToken = info.authenticationToken ?: "0000"
            Log.d(TAG, "Incoming connection from: ${info.endpointName}")
            Log.d(TAG, "VERIFICATION TOKEN IS: $secureToken")
            uiListener?.onConnectionRequestReceived(info.endpointName, secureToken, endpointId)
        }

        override fun onConnectionResult(endpointId: String, result: ConnectionResolution) {
            if (result.status.statusCode == ConnectionsStatusCodes.STATUS_OK) {
                Log.d(TAG, "Secure channel opened with token authentication!")
                activeEndpointId = endpointId
                uiListener?.onConnected(endpointId)
            } else {
                Log.e(TAG, "Connection handshake rejected or failed.")
            }
        }

        override fun onDisconnected(endpointId: String) {
            if (activeEndpointId == endpointId) activeEndpointId = null
            uiListener?.onDisconnected()
        }
    }

    fun acceptPeer(endpointId: String) {
        connectionsClient.acceptConnection(endpointId, payloadCallback)
    }

    fun rejectPeer(endpointId: String) {
        connectionsClient.rejectConnection(endpointId)
    }

    fun startAdvertising(displayName: String) {
        val advertisingOptions = AdvertisingOptions.Builder()
            .setStrategy(connectionStrategy)
            .build()

        connectionsClient.startAdvertising(
            displayName,
            SERVICE_ID,
            connectionLifecycleCallback,
            advertisingOptions
        )
            .addOnSuccessListener { Log.d(TAG, "Successfully started advertising as: $displayName") }
            .addOnFailureListener { exception -> Log.e(TAG, "Advertising failed to start", exception) }
    }

    fun stopAdvertising() {
        connectionsClient.stopAdvertising()
        Log.d(TAG, "Stopped advertising.")
    }

    fun startDiscovery() {
        val discoveryOptions = DiscoveryOptions.Builder()
            .setStrategy(connectionStrategy)
            .build()

        connectionsClient.startDiscovery(
            SERVICE_ID,
            endpointDiscoveryCallback,
            discoveryOptions
        )
            .addOnSuccessListener { Log.d(TAG, "Successfully started discovery mode.") }
            .addOnFailureListener { exception -> Log.e(TAG, "Discovery failed to start", exception) }
    }

    fun stopDiscovery() {
        connectionsClient.stopDiscovery()
        Log.d(TAG, "Stopped discovery.")
    }

    private val endpointDiscoveryCallback = object : EndpointDiscoveryCallback() {
        override fun onEndpointFound(endpointId: String, info: DiscoveredEndpointInfo) {
            Log.d(TAG, "Device discovered! Name: ${info.endpointName} | ID: $endpointId")

            connectionsClient.requestConnection(
                "MediaTek Tablet",
                endpointId,
                connectionLifecycleCallback
            )
                .addOnSuccessListener {
                    Log.d(TAG, "Connection request sent successfully to $endpointId")
                    stopDiscovery()
                }
                .addOnFailureListener { exception ->
                    Log.e(TAG, "Failed to send connection request", exception)
                    startDiscovery()
                }
        }

        override fun onEndpointLost(endpointId: String) {
            Log.d(TAG, "Endpoint lost sight: $endpointId")
        }
    }

    fun sendTextMessage(message: String) {
        val targetId = activeEndpointId ?: return Log.e(TAG, "No active peer connected to send data to.")
        val payload = Payload.fromBytes(message.toByteArray(Charsets.UTF_8))

        connectionsClient.sendPayload(targetId, payload)
            .addOnSuccessListener { Log.d(TAG, "Text payload sent out successfully.") }
            .addOnFailureListener { e -> Log.e(TAG, "Payload transmission failed.", e) }
    }

    fun sendSecureFile(originFile: File) {
        val targetId = activeEndpointId ?: return Log.e(TAG, "No active peer connected to send file.")

        val internalSecureFile = File(context.cacheDir, "shared_transfer_${System.currentTimeMillis()}.tmp")
        originFile.copyTo(internalSecureFile, overwrite = true)

        val filePayload = Payload.fromFile(internalSecureFile)

        connectionsClient.sendPayload(targetId, filePayload)
            .addOnSuccessListener { Log.d(TAG, "File payload ID ${filePayload.id} sent successfully.") }
            .addOnFailureListener { e -> Log.e(TAG, "File payload stream failed.", e) }
    }

    private val incomingFilesMap = mutableMapOf<Long, Payload.File>()

    private val payloadCallback = object : PayloadCallback() {
        override fun onPayloadReceived(endpointId: String, payload: Payload) {
            when (payload.type) {
                Payload.Type.BYTES -> {
                    val text = String(payload.asBytes()!!, Charsets.UTF_8)
                    Log.i(TAG, "Secure text received: $text")
                }
                Payload.Type.FILE -> {
                    payload.asFile()?.let { incomingFilesMap[payload.id] = it }
                    Log.i(TAG, "Incoming file stream chunk processing for ID: ${payload.id}")
                }
            }
        }

        override fun onPayloadTransferUpdate(endpointId: String, update: PayloadTransferUpdate) {
            if (update.status == PayloadTransferUpdate.Status.SUCCESS) {
                val completedPayload = incomingFilesMap.remove(update.payloadId)
                completedPayload?.asJavaFile()?.let { tempFile ->
                    val finalDestinationFile = File(context.filesDir, "received_asset_${System.currentTimeMillis()}.dat")
                    tempFile.renameTo(finalDestinationFile)
                    Log.i(TAG, "File completely received and saved at: ${finalDestinationFile.absolutePath}")
                }
            }
        }
    }
}
EOF

echo "=== Writing NearbyScreen.kt ==="
cat > app/src/main/java/com/example/nearbyapp/NearbyScreen.kt << 'EOF'
package com.example.nearbyapp

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
fun NearbyScreen(
    nearbyManager: NearbyManager,
    isTablet: Boolean
) {
    var currentStatus by remember { mutableStateOf("Idle. Waiting to start...") }
    var incomingRequestName by remember { mutableStateOf<String?>(null) }
    var connectionToken by remember { mutableStateOf<String?>(null) }
    var activePeerId by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(Unit) {
        nearbyManager.uiListener = object : NearbyManager.NearbyUiListener {
            override fun onConnectionRequestReceived(endpointName: String, token: String, endpointId: String) {
                incomingRequestName = endpointName
                connectionToken = token
                activePeerId = endpointId
                currentStatus = "Verifying Identity Token..."
            }

            override fun onConnected(endpointId: String) {
                incomingRequestName = null
                connectionToken = null
                currentStatus = "Securely Connected to Peer!"
            }

            override fun onDisconnected() {
                activePeerId = null
                incomingRequestName = null
                connectionToken = null
                currentStatus = "Disconnected."
            }
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text(
            text = if (isTablet) "MediaTek Tablet Mode" else "Phone Mode",
            fontSize = 24.sp,
            fontWeight = FontWeight.Bold
        )

        Spacer(modifier = Modifier.height(16.dp))

        Text(text = "Status: $currentStatus", fontSize = 16.sp, color = Color.Gray)

        Spacer(modifier = Modifier.height(32.dp))

        if (incomingRequestName != null && connectionToken != null && activePeerId != null) {
            Card(
                modifier = Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
            ) {
                Column(
                    modifier = Modifier.padding(16.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Text(text = "Incoming Request From:", fontSize = 14.sp)
                    Text(text = incomingRequestName!!, fontSize = 20.sp, fontWeight = FontWeight.Bold)

                    Spacer(modifier = Modifier.height(16.dp))

                    Text(text = "SECURE MATCHING TOKEN", fontSize = 12.sp, color = Color.Gray)
                    Text(
                        text = connectionToken!!,
                        fontSize = 36.sp,
                        fontWeight = FontWeight.ExtraBold,
                        color = MaterialTheme.colorScheme.primary,
                        letterSpacing = 4.sp
                    )

                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = "Verify this exact sequence matches on both screens before accepting.",
                        fontSize = 12.sp,
                        color = Color.DarkGray
                    )

                    Spacer(modifier = Modifier.height(24.dp))

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceEvenly
                    ) {
                        Button(
                            onClick = {
                                nearbyManager.rejectPeer(activePeerId!!)
                                incomingRequestName = null
                                connectionToken = null
                            },
                            colors = ButtonDefaults.buttonColors(containerColor = Color.Red)
                        ) {
                            Text("Decline", color = Color.White)
                        }

                        Button(
                            onClick = { nearbyManager.acceptPeer(activePeerId!!) },
                            colors = ButtonDefaults.buttonColors(containerColor = Color.Green)
                        ) {
                            Text("Accept Connection", color = Color.Black)
                        }
                    }
                }
            }
        } else {
            Button(
                onClick = {
                    if (isTablet) {
                        nearbyManager.startDiscovery()
                        currentStatus = "Scanning for phone..."
                    } else {
                        nearbyManager.startAdvertising("Developer Phone")
                        currentStatus = "Broadcasting visibility..."
                    }
                },
                modifier = Modifier.fillMaxWidth(0.7f)
            ) {
                Text(text = if (isTablet) "Start Scanning" else "Make Discoverable")
            }
        }
    }
}
EOF

echo "=== Done! Project structure created. ==="
find . -type f -not -path "./.git/*"0

