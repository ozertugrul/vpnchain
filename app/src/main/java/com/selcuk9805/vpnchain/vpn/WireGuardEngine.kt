package com.selcuk9805.vpnchain.vpn

import android.content.Context
import android.util.Log
import com.wireguard.android.backend.GoBackend
import com.wireguard.android.backend.Tunnel
import com.wireguard.config.Config
import com.wireguard.config.InetEndpoint
import java.io.ByteArrayInputStream

class WireGuardEngine(private val context: Context) {
    private val backend = GoBackend(context)
    private var currentTunnel: Tunnel? = null
    private var activeConfig: Config? = null

    fun connect(rawConfig: String, localSpeederPort: Int) {
        try {
            val originalConfig = Config.parse(ByteArrayInputStream(rawConfig.toByteArray()))
            
            val newConfigBuilder = Config.Builder()
            
            val ifaceBuilder = com.wireguard.config.Interface.Builder()
            originalConfig.getInterface().addresses.forEach { ifaceBuilder.addAddress(it) }
            ifaceBuilder.parsePrivateKey(originalConfig.getInterface().keyPair.privateKey.toBase64())
            originalConfig.getInterface().dnsServers.forEach { ifaceBuilder.addDnsServer(it) }
            
            // Set MTU to 1280 to account for UDPspeeder FEC headers
            ifaceBuilder.setMtu(1280)
            
            newConfigBuilder.setInterface(ifaceBuilder.build())

            originalConfig.peers.forEach { peer ->
                val peerBuilder = com.wireguard.config.Peer.Builder()
                peerBuilder.parsePublicKey(peer.publicKey.toBase64())
                peer.preSharedKey.ifPresent { peerBuilder.parsePreSharedKey(it.toBase64()) }
                peer.allowedIps.forEach { peerBuilder.addAllowedIp(it) }
                
                // Reroute the endpoint to the local UDPspeeder instance
                peerBuilder.setEndpoint(InetEndpoint.parse("127.0.0.1:$localSpeederPort"))
                peer.persistentKeepalive.ifPresent { peerBuilder.setPersistentKeepalive(it) }
                
                newConfigBuilder.addPeer(peerBuilder.build())
            }

            val finalConfig = newConfigBuilder.build()
            activeConfig = finalConfig
            
            val tunnel = object : Tunnel {
                override fun getName() = "vpnchain"
                override fun onStateChange(newState: Tunnel.State) {
                    Log.i("WireGuardEngine", "State changed: $newState")
                }
            }
            
            backend.setState(tunnel, Tunnel.State.UP, finalConfig)
            currentTunnel = tunnel
            Log.i("WireGuardEngine", "WireGuard connected successfully to local UDPspeeder!")
            
        } catch (e: Exception) {
            Log.e("WireGuardEngine", "Failed to start WireGuard", e)
            throw e
        }
    }

    fun disconnect() {
        currentTunnel?.let {
            try {
                backend.setState(it, Tunnel.State.DOWN, null)
                Log.i("WireGuardEngine", "WireGuard disconnected.")
            } catch (e: Exception) {
                Log.e("WireGuardEngine", "Error disconnecting WireGuard", e)
            } finally {
                currentTunnel = null
                activeConfig = null
            }
        }
    }

    fun getStatistics(): com.selcuk9805.vpnchain.models.VpnStats? {
        val tunnel = currentTunnel ?: return null
        val config = activeConfig ?: return null
        return try {
            val stats = backend.getStatistics(tunnel)
            var rx = 0L
            var tx = 0L
            config.peers.forEach { peer ->
                rx += stats.peerRx(peer.publicKey)
                tx += stats.peerTx(peer.publicKey)
            }
            com.selcuk9805.vpnchain.models.VpnStats(txBytes = tx, rxBytes = rx)
        } catch (e: Exception) {
            null
        }
    }
}
