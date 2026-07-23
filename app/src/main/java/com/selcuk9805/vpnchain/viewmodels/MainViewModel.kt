package com.selcuk9805.vpnchain.viewmodels

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import com.selcuk9805.vpnchain.models.ProfileRepository
import com.selcuk9805.vpnchain.models.UdpSpeederConfig
import com.selcuk9805.vpnchain.models.VpnProfile
import com.selcuk9805.vpnchain.models.WireGuardConfig
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.delay
import androidx.lifecycle.viewModelScope
import android.content.Intent
import com.selcuk9805.vpnchain.models.ProcessState
import com.selcuk9805.vpnchain.models.VpnStateManager
import com.selcuk9805.vpnchain.vpn.ConnectionService
import java.util.UUID

import com.selcuk9805.vpnchain.models.VpnStats

class MainViewModel(application: Application) : AndroidViewModel(application) {
    private val repository = ProfileRepository(application)

    private val _udpSpeederConfig = MutableStateFlow(UdpSpeederConfig())
    val udpSpeederConfig: StateFlow<UdpSpeederConfig> = _udpSpeederConfig.asStateFlow()

    private val _wireGuardConfig = MutableStateFlow(WireGuardConfig())
    val wireGuardConfig: StateFlow<WireGuardConfig> = _wireGuardConfig.asStateFlow()

    val udpSpeederState: StateFlow<ProcessState> = VpnStateManager.udpSpeederState
    val wireGuardState: StateFlow<ProcessState> = VpnStateManager.wireGuardState
    val logs: StateFlow<List<String>> = VpnStateManager.logs
    val vpnStats: StateFlow<VpnStats> = VpnStateManager.vpnStats

    private val _profiles = MutableStateFlow<List<VpnProfile>>(emptyList())
    val profiles: StateFlow<List<VpnProfile>> = _profiles.asStateFlow()

    init {
        val crashPrefs = application.getSharedPreferences("crash_logs", android.content.Context.MODE_PRIVATE)
        val lastCrash = crashPrefs.getString("last_crash", null)
        if (lastCrash != null) {
            addLog("FATAL CRASH DETECTED ON PREVIOUS RUN:\n$lastCrash")
            crashPrefs.edit().remove("last_crash").apply()
        }

        loadProfiles()
    }

    fun resetAllTimeStats() {
        val prefs = getApplication<Application>().getSharedPreferences("vpn_stats", android.content.Context.MODE_PRIVATE)
        prefs.edit().putLong("all_time_tx", 0L).putLong("all_time_rx", 0L).apply()
        
        val currentStats = VpnStateManager.vpnStats.value
        VpnStateManager.updateVpnStats(currentStats.copy(allTimeTxBytes = 0L, allTimeRxBytes = 0L))
        VpnStateManager.addLog("All-time traffic statistics reset.")
    }

    private fun loadProfiles() {
        _profiles.value = repository.getProfiles()
    }

    fun updateUdpSpeederConfig(config: UdpSpeederConfig) {
        _udpSpeederConfig.value = config
    }

    fun updateWireGuardConfig(config: WireGuardConfig) {
        _wireGuardConfig.value = config
    }

    fun saveCurrentAsProfile(name: String) {
        val newProfile = VpnProfile(
            id = UUID.randomUUID().toString(),
            name = name,
            udpSpeederConfig = _udpSpeederConfig.value,
            wireGuardConfig = _wireGuardConfig.value
        )
        val currentList = repository.getProfiles().toMutableList()
        currentList.add(newProfile)
        repository.saveProfiles(currentList)
        loadProfiles()
        addLog("Profile '$name' saved.")
    }

    fun loadProfile(profile: VpnProfile) {
        _udpSpeederConfig.value = profile.udpSpeederConfig
        _wireGuardConfig.value = profile.wireGuardConfig
        addLog("Profile '${profile.name}' loaded.")
    }

    fun exportToUri(uri: android.net.Uri) {
        try {
            val json = repository.exportProfiles()
            getApplication<Application>().contentResolver.openOutputStream(uri)?.use { stream ->
                stream.write(json.toByteArray())
            }
            addLog("Profiles exported successfully.")
        } catch (e: Exception) {
            addLog("Export Error: ${e.message}")
        }
    }

    fun importFromUri(uri: android.net.Uri) {
        try {
            getApplication<Application>().contentResolver.openInputStream(uri)?.use { stream ->
                val json = java.io.InputStreamReader(stream).readText()
                val listType = object : com.google.gson.reflect.TypeToken<List<VpnProfile>>() {}.type
                val importedProfiles: List<VpnProfile> = com.google.gson.Gson().fromJson(json, listType)
                
                val currentProfiles = repository.getProfiles().toMutableList()
                currentProfiles.addAll(importedProfiles)
                repository.saveProfiles(currentProfiles.distinctBy { it.id })
                loadProfiles()
                addLog("Profiles imported successfully.")
            }
        } catch (e: Exception) {
            addLog("Import Error: ${e.message}")
        }
    }

    val isConnectedOrConnecting: Boolean
        get() = udpSpeederState.value != ProcessState.STOPPED || wireGuardState.value != ProcessState.STOPPED

    fun toggleConnection() {
        if (isConnectedOrConnecting) {
            val intent = Intent(getApplication(), ConnectionService::class.java).apply {
                action = ConnectionService.ACTION_DISCONNECT
            }
            getApplication<Application>().startService(intent)
        } else {
            val config = _udpSpeederConfig.value
            if (config.serverIp.isBlank() || config.remotePort.isBlank() || config.localPort.isBlank()) {
                addLog("Error: Server IP, Remote Port or Local Port cannot be empty.")
                return
            }

            val presetParams = if (config.preset == com.selcuk9805.vpnchain.models.UdpPreset.FEC) {
                "-f1:2 --mode 1 --timeout 5"
            } else {
                "--mode 1 --timeout 5"
            }
            val params = "-c -l 0.0.0.0:${config.localPort} -r ${config.serverIp}:${config.remotePort} $presetParams"

            val intent = Intent(getApplication(), ConnectionService::class.java).apply {
                action = ConnectionService.ACTION_CONNECT
                putExtra(ConnectionService.EXTRA_WG_CONFIG, _wireGuardConfig.value.rawConfigText)
                putExtra(ConnectionService.EXTRA_UDP_PARAMS, params)
                putExtra(ConnectionService.EXTRA_LOCAL_PORT, config.localPort.toIntOrNull() ?: 1234)
            }

            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                getApplication<Application>().startForegroundService(intent)
            } else {
                getApplication<Application>().startService(intent)
            }
        }
    }

    fun addLog(message: String) {
        VpnStateManager.addLog(message)
    }

    fun clearLogs() {
        VpnStateManager.clearLogs()
    }

    override fun onCleared() {
        super.onCleared()
    }
}
