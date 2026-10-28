package com.selcuk9805.vpnchain.vpn

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import com.selcuk9805.vpnchain.MainActivity
import com.selcuk9805.vpnchain.R
import com.selcuk9805.vpnchain.ui.screens.formatBytes
import com.selcuk9805.vpnchain.models.ProcessState
import com.selcuk9805.vpnchain.models.VpnStateManager
import com.selcuk9805.vpnchain.models.VpnStats
import com.selcuk9805.vpnchain.native.UDPspeederClient
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class ConnectionService : Service() {

    companion object {
        const val ACTION_CONNECT = "com.selcuk9805.vpnchain.CONNECT"
        const val ACTION_DISCONNECT = "com.selcuk9805.vpnchain.DISCONNECT"
        const val EXTRA_WG_CONFIG = "extra_wg_config"
        const val EXTRA_UDP_PARAMS = "extra_udp_params"
        const val EXTRA_LOCAL_PORT = "extra_local_port"
        const val NOTIFICATION_ID = 9805
        const val CHANNEL_ID = "vpnchain_channel"
    }

    private val serviceScope = CoroutineScope(Dispatchers.IO + Job())
    private lateinit var wireGuardEngine: WireGuardEngine
    private var logcatProcess: Process? = null

    private var baseAllTimeTx = 0L
    private var baseAllTimeRx = 0L
    private var statsJob: Job? = null

    override fun onCreate() {
        super.onCreate()
        wireGuardEngine = WireGuardEngine(applicationContext)
        createNotificationChannel()

        val prefs = getSharedPreferences("vpn_stats", MODE_PRIVATE)
        baseAllTimeTx = prefs.getLong("all_time_tx", 0L)
        baseAllTimeRx = prefs.getLong("all_time_rx", 0L)

        try {
            UDPspeederClient.init(applicationContext)
            UDPspeederClient.onLogListener = { log -> VpnStateManager.addLog(log) }
        } catch (e: Throwable) {
            VpnStateManager.addLog("Error initializing UDPspeederClient: ${android.util.Log.getStackTraceString(e)}")
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null) return START_NOT_STICKY

        when (intent.action) {
            ACTION_CONNECT -> {
                val wgConfig = intent.getStringExtra(EXTRA_WG_CONFIG) ?: return START_NOT_STICKY
                val udpParams = intent.getStringExtra(EXTRA_UDP_PARAMS) ?: return START_NOT_STICKY
                val localPort = intent.getIntExtra(EXTRA_LOCAL_PORT, 1234)

                val notification = createNotification("Connecting...")
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    startForeground(NOTIFICATION_ID, notification, android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
                } else {
                    startForeground(NOTIFICATION_ID, notification)
                }
                startConnection(wgConfig, udpParams, localPort)
            }
            ACTION_DISCONNECT -> {
                stopConnection()
                stopForeground(true)
                stopSelf()
            }
        }
        return START_NOT_STICKY
    }

    private fun startConnection(wgConfig: String, udpParams: String, localPort: Int) {
        serviceScope.launch {
            try {
                VpnStateManager.updateUdpSpeederState(ProcessState.STARTING)
                UDPspeederClient.startSpeeder(udpParams)
                VpnStateManager.updateUdpSpeederState(ProcessState.RUNNING)
                VpnStateManager.addLog("UDPspeeder running. Starting WireGuard...")

                delay(500)
                
                VpnStateManager.updateWireGuardState(ProcessState.STARTING)
                startWireGuardLogcat()
                
                withContext(Dispatchers.IO) {
                    wireGuardEngine.connect(wgConfig, localPort)
                }
                
                VpnStateManager.updateWireGuardState(ProcessState.RUNNING)
                VpnStateManager.addLog("WireGuard connected successfully.")
                updateNotification("Connected")
                startStatsLoop()
                
            } catch (e: Exception) {
                VpnStateManager.addLog("Error: ${android.util.Log.getStackTraceString(e)}")
                VpnStateManager.updateUdpSpeederState(ProcessState.ERROR)
                VpnStateManager.updateWireGuardState(ProcessState.ERROR)
                updateNotification("Connection Failed")
                delay(2000)
                stopSelf()
            }
        }
    }

    private fun startStatsLoop() {
        statsJob?.cancel()
        statsJob = serviceScope.launch {
            var connectionStartTime = System.currentTimeMillis()
            var lastTxBytes = 0L
            var lastRxBytes = 0L
            
            while(true) {
                try {
                    val stats = wireGuardEngine.getStatistics()
                    if (stats != null) {
                        val currentTx = stats.txBytes
                        val currentRx = stats.rxBytes
                        val speedTx = currentTx - lastTxBytes
                        val speedRx = currentRx - lastRxBytes
                        lastTxBytes = currentTx
                        lastRxBytes = currentRx
                        val uptime = (System.currentTimeMillis() - connectionStartTime) / 1000
                        
                        val currentAllTimeTx = baseAllTimeTx + currentTx
                        val currentAllTimeRx = baseAllTimeRx + currentRx
                        
                        VpnStateManager.updateVpnStats(VpnStats(currentTx, currentRx, speedTx, speedRx, uptime, currentAllTimeTx, currentAllTimeRx))
                        
                        updateNotification("Connected - \u2193 ${formatBytes(speedRx)}/s \u2191 ${formatBytes(speedTx)}/s")
                    }
                } catch(e: Exception) {}
                delay(1000)
            }
        }
    }

    private fun stopConnection() {
        statsJob?.cancel()
        
        // Save final stats
        val currentStats = VpnStateManager.vpnStats.value
        if (currentStats.txBytes > 0 || currentStats.rxBytes > 0) {
            baseAllTimeTx += currentStats.txBytes
            baseAllTimeRx += currentStats.rxBytes
            getSharedPreferences("vpn_stats", MODE_PRIVATE).edit()
                .putLong("all_time_tx", baseAllTimeTx)
                .putLong("all_time_rx", baseAllTimeRx)
                .apply()
        }
        VpnStateManager.updateVpnStats(VpnStats(allTimeTxBytes = baseAllTimeTx, allTimeRxBytes = baseAllTimeRx))

        VpnStateManager.updateUdpSpeederState(ProcessState.STOPPED)
        VpnStateManager.updateWireGuardState(ProcessState.STOPPED)
        logcatProcess?.destroy()
        UDPspeederClient.stopSpeeder()
        wireGuardEngine.disconnect()
        VpnStateManager.addLog("Connection stopped.")
    }

    private fun startWireGuardLogcat() {
        Thread {
            try {
                Runtime.getRuntime().exec("logcat -c").waitFor()
                logcatProcess = ProcessBuilder("logcat", "-v", "raw", "-s", "WireGuard/GoBackend:V", "*:S")
                    .redirectErrorStream(true)
                    .start()
                
                val reader = java.io.BufferedReader(java.io.InputStreamReader(logcatProcess!!.inputStream))
                var line: String?
                while (reader.readLine().also { line = it } != null) {
                    line?.takeIf { it.isNotBlank() }?.let { VpnStateManager.addLog("[WireGuard] $it") }
                }
            } catch (e: Exception) {
                // Ignore
            }
        }.start()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "VPN Connection",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }
    }

    private fun createNotification(contentText: String): Notification {
        val intent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val disconnectIntent = Intent(this, ConnectionService::class.java).apply {
            action = ACTION_DISCONNECT
        }
        val disconnectPendingIntent = PendingIntent.getService(
            this, 1, disconnectIntent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("VPNChain Service")
            .setContentText(contentText)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(pendingIntent)
            .addAction(0, "Disconnect", disconnectPendingIntent)
            .setOngoing(true)
            .build()
    }

    private fun updateNotification(contentText: String) {
        val manager = getSystemService(NotificationManager::class.java)
        manager?.notify(NOTIFICATION_ID, createNotification(contentText))
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        stopConnection()
    }
}
