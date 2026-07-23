package com.selcuk9805.vpnchain.models

data class VpnProfile(
    val id: String,
    val name: String,
    val udpSpeederConfig: UdpSpeederConfig,
    val wireGuardConfig: WireGuardConfig
)
