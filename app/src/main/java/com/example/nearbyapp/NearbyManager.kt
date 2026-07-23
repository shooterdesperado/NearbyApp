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
        val targetId = activeEndpointId ?: run {
            Log.e(TAG, "No active peer connected to send data to.")
            return
        }
        val payload = Payload.fromBytes(message.toByteArray(Charsets.UTF_8))

        connectionsClient.sendPayload(targetId, payload)
            .addOnSuccessListener { Log.d(TAG, "Text payload sent out successfully.") }
            .addOnFailureListener { e -> Log.e(TAG, "Payload transmission failed.", e) }
    }

    fun sendSecureFile(originFile: File) {
        val targetId = activeEndpointId ?: run {
            Log.e(TAG, "No active peer connected to send file.")
            return
        }

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
