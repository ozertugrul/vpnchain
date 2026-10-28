package com.selcuk9805.vpnchain.models

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

enum class ProcessState {
    STOPPED, STARTING, RUNNING, ERROR
}

data class VpnStats(
    val txBytes: Long = 0, 
    val rxBytes: Long = 0,
    val txSpeed: Long = 0,
    val rxSpeed: Long = 0,
    val uptimeSeconds: Long = 0,
    val allTimeTxBytes: Long = 0,
    val allTimeRxBytes: Long = 0
)

object VpnStateManager {
    private val _vpnStats = MutableStateFlow(VpnStats())
    val vpnStats: StateFlow<VpnStats> = _vpnStats.asStateFlow()

    private val _udpSpeederState = MutableStateFlow(ProcessState.STOPPED)
    val udpSpeederState: StateFlow<ProcessState> = _udpSpeederState.asStateFlow()

    private val _wireGuardState = MutableStateFlow(ProcessState.STOPPED)
    val wireGuardState: StateFlow<ProcessState> = _wireGuardState.asStateFlow()

    private val _logs = MutableStateFlow<List<String>>(emptyList())
    val logs: StateFlow<List<String>> = _logs.asStateFlow()

    fun updateUdpSpeederState(state: ProcessState) {
        _udpSpeederState.value = state
    }

    fun updateWireGuardState(state: ProcessState) {
        _wireGuardState.value = state
    }

    fun addLog(message: String) {
        _logs.update { currentLogs -> 
            (currentLogs + message).takeLast(200)
        }
    }

    fun clearLogs() {
        _logs.value = emptyList()
    }

    fun updateVpnStats(stats: VpnStats) {
        _vpnStats.value = stats
    }
}
