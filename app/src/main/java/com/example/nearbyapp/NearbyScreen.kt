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
