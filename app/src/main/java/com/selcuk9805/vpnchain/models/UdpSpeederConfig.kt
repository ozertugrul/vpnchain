package com.selcuk9805.vpnchain.models

enum class UdpPreset {
    NORMAL, FEC
}

data class UdpSpeederConfig(
    val serverIp: String = "",
    val remotePort: String = "",
    val localPort: String = "1234",
    val preset: UdpPreset = UdpPreset.NORMAL
)
