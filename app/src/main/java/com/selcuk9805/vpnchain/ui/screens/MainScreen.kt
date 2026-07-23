package com.selcuk9805.vpnchain.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Menu
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.text.AnnotatedString
import java.io.InputStreamReader
import com.selcuk9805.vpnchain.models.UdpPreset
import com.selcuk9805.vpnchain.models.UdpSpeederConfig
import com.selcuk9805.vpnchain.models.VpnProfile
import com.selcuk9805.vpnchain.models.WireGuardConfig
import com.selcuk9805.vpnchain.models.ProcessState
import com.selcuk9805.vpnchain.viewmodels.MainViewModel
import com.selcuk9805.vpnchain.models.VpnStats
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MainScreen(viewModel: MainViewModel = viewModel()) {
    val udpConfig by viewModel.udpSpeederConfig.collectAsState()
    val wgConfig by viewModel.wireGuardConfig.collectAsState()
    val udpState by viewModel.udpSpeederState.collectAsState()
    val wgState by viewModel.wireGuardState.collectAsState()
    val vpnStats by viewModel.vpnStats.collectAsState()
    val logs by viewModel.logs.collectAsState()
    val profiles by viewModel.profiles.collectAsState()

    val drawerState = rememberDrawerState(initialValue = DrawerValue.Closed)
    val scope = rememberCoroutineScope()
    var showSaveDialog by remember { mutableStateOf(false) }

    val context = androidx.compose.ui.platform.LocalContext.current
    val notificationPermissionLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { isGranted ->
        if (!isGranted) {
            viewModel.addLog("Warning: Notification permission denied. Persistent notification won't be shown.")
        }
    }

    LaunchedEffect(Unit) {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
            notificationPermissionLauncher.launch(android.Manifest.permission.POST_NOTIFICATIONS)
        }
    }

    val vpnPermissionLauncher = rememberLauncherForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
        if (result.resultCode == android.app.Activity.RESULT_OK) {
            viewModel.toggleConnection()
        } else {
            viewModel.addLog("Error: VPN permission denied by user.")
        }
    }

    val onConnectClick = {
        if (viewModel.isConnectedOrConnecting) {
            viewModel.toggleConnection()
        } else {
            val intent = android.net.VpnService.prepare(context)
            if (intent != null) {
                vpnPermissionLauncher.launch(intent)
            } else {
                viewModel.toggleConnection()
            }
        }
    }

    val exportLauncher = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("*/*")) { uri ->
        uri?.let { viewModel.exportToUri(it) }
    }
    
    val importLauncher = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        uri?.let { viewModel.importFromUri(it) }
    }

    ModalNavigationDrawer(
        drawerState = drawerState,
        drawerContent = {
            ModalDrawerSheet {
                Spacer(Modifier.height(12.dp))
                Text(
                    "VPNChain Menu",
                    modifier = Modifier.padding(16.dp),
                    style = MaterialTheme.typography.headlineSmall
                )
                Divider()
                
                Text(
                    "Saved Profiles",
                    modifier = Modifier.padding(16.dp),
                    style = MaterialTheme.typography.titleMedium
                )
                
                LazyColumn(modifier = Modifier.weight(1f)) {
                    items(profiles) { profile ->
                        NavigationDrawerItem(
                            label = { Text(profile.name) },
                            selected = false,
                            onClick = {
                                viewModel.loadProfile(profile)
                                scope.launch { drawerState.close() }
                            },
                            modifier = Modifier.padding(NavigationDrawerItemDefaults.ItemPadding)
                        )
                    }
                }
                
                Divider()
                NavigationDrawerItem(
                    label = { Text("Export Profiles (.selconf)") },
                    selected = false,
                    onClick = {
                        exportLauncher.launch("backup.selconf")
                        scope.launch { drawerState.close() }
                    },
                    modifier = Modifier.padding(NavigationDrawerItemDefaults.ItemPadding)
                )
                NavigationDrawerItem(
                    label = { Text("Import Profiles (.selconf)") },
                    selected = false,
                    onClick = {
                        importLauncher.launch("*/*")
                        scope.launch { drawerState.close() }
                    },
                    modifier = Modifier.padding(NavigationDrawerItemDefaults.ItemPadding)
                )
                
                Divider()
                var showResetDialog by remember { mutableStateOf(false) }
                NavigationDrawerItem(
                    label = { Text("Reset All-Time Traffic", color = MaterialTheme.colorScheme.error) },
                    selected = false,
                    onClick = { showResetDialog = true },
                    modifier = Modifier.padding(NavigationDrawerItemDefaults.ItemPadding)
                )
                
                if (showResetDialog) {
                    AlertDialog(
                        onDismissRequest = { showResetDialog = false },
                        title = { Text("Reset Traffic?") },
                        text = { Text("Are you sure you want to reset your all-time traffic statistics? This cannot be undone.") },
                        confirmButton = {
                            TextButton(onClick = {
                                viewModel.resetAllTimeStats()
                                showResetDialog = false
                                scope.launch { drawerState.close() }
                            }) {
                                Text("Reset", color = MaterialTheme.colorScheme.error)
                            }
                        },
                        dismissButton = {
                            TextButton(onClick = { showResetDialog = false }) { Text("Cancel") }
                        }
                    )
                }
                
                Spacer(Modifier.height(16.dp))
                Text(
                    text = "Developed by Selcuk Sercan",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(16.dp).align(Alignment.CenterHorizontally)
                )
            }
        }
    ) {
        Scaffold(
            topBar = {
                TopAppBar(
                    title = { Text("VPNChain") },
                    navigationIcon = {
                        IconButton(onClick = { scope.launch { drawerState.open() } }) {
                            Icon(Icons.Default.Menu, contentDescription = "Menu")
                        }
                    },
                    colors = TopAppBarDefaults.topAppBarColors(
                        containerColor = MaterialTheme.colorScheme.primaryContainer,
                        titleContentColor = MaterialTheme.colorScheme.onPrimaryContainer
                    ),
                    actions = {
                        Button(onClick = { showSaveDialog = true }) {
                            Text("Save Profile")
                        }
                    }
                )
            }
        ) { padding ->
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding)
                    .verticalScroll(rememberScrollState())
                    .padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                ConnectionCard(
                    udpState = udpState,
                    wgState = wgState,
                    stats = vpnStats,
                    isConnectedOrConnecting = viewModel.isConnectedOrConnecting,
                    onToggle = onConnectClick
                )

                UdpSpeederCard(
                    config = udpConfig,
                    onConfigChange = { viewModel.updateUdpSpeederConfig(it) },
                    enabled = !viewModel.isConnectedOrConnecting
                )

                WireGuardCard(
                    config = wgConfig,
                    localPort = udpConfig.localPort,
                    onConfigChange = { viewModel.updateWireGuardConfig(it) },
                    enabled = !viewModel.isConnectedOrConnecting
                )

                LogsCard(
                    logs = logs,
                    onClear = { viewModel.clearLogs() }
                )
            }
        }
    }

    if (showSaveDialog) {
        var profileName by remember { mutableStateOf("") }
        AlertDialog(
            onDismissRequest = { showSaveDialog = false },
            title = { Text("Save Profile") },
            text = {
                OutlinedTextField(
                    value = profileName,
                    onValueChange = { profileName = it },
                    label = { Text("Profile Name") }
                )
            },
            confirmButton = {
                TextButton(onClick = {
                    if (profileName.isNotBlank()) {
                        viewModel.saveCurrentAsProfile(profileName)
                        showSaveDialog = false
                    }
                }) {
                    Text("Save")
                }
            },
            dismissButton = {
                TextButton(onClick = { showSaveDialog = false }) { Text("Cancel") }
            }
        )
    }
}

@Composable
fun ConnectionCard(udpState: ProcessState, wgState: ProcessState, stats: VpnStats, isConnectedOrConnecting: Boolean, onToggle: () -> Unit) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceEvenly) {
                StatusIndicator(title = "UDPspeeder", state = udpState)
                StatusIndicator(title = "WireGuard", state = wgState)
            }
            if (wgState == ProcessState.RUNNING) {
                Spacer(modifier = Modifier.height(16.dp))
                Card(colors = CardDefaults.cardColors(containerColor = Color(0xFF1E1E1E)), modifier = Modifier.fillMaxWidth()) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Text("Live Statistics", color = Color.Green, style = MaterialTheme.typography.titleMedium)
                        Spacer(modifier = Modifier.height(12.dp))
                        
                        val uptimeMins = stats.uptimeSeconds / 60
                        val uptimeSecs = stats.uptimeSeconds % 60
                        Text("Uptime: ${String.format("%02d:%02d", uptimeMins, uptimeSecs)}", color = Color.White)
                        
                        Spacer(modifier = Modifier.height(8.dp))
                        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                            Column {
                                Text("Download", color = Color.Gray, style = MaterialTheme.typography.labelMedium)
                                Text("${formatBytes(stats.rxSpeed)}/s", color = Color.Cyan)
                                Text("Session: ${formatBytes(stats.rxBytes)}", color = Color.LightGray, style = MaterialTheme.typography.labelSmall)
                            }
                            Column(horizontalAlignment = Alignment.End) {
                                Text("Upload", color = Color.Gray, style = MaterialTheme.typography.labelMedium)
                                Text("${formatBytes(stats.txSpeed)}/s", color = Color.Magenta)
                                Text("Session: ${formatBytes(stats.txBytes)}", color = Color.LightGray, style = MaterialTheme.typography.labelSmall)
                            }
                        }
                        
                        Spacer(modifier = Modifier.height(12.dp))
                        Divider(color = Color.DarkGray)
                        Spacer(modifier = Modifier.height(8.dp))
                        
                        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                            Text("All-Time Download:", color = Color.Gray, style = MaterialTheme.typography.labelSmall)
                            Text(formatBytes(stats.allTimeRxBytes), color = Color.Cyan, style = MaterialTheme.typography.labelSmall)
                        }
                        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                            Text("All-Time Upload:", color = Color.Gray, style = MaterialTheme.typography.labelSmall)
                            Text(formatBytes(stats.allTimeTxBytes), color = Color.Magenta, style = MaterialTheme.typography.labelSmall)
                        }
                    }
                }
            } else {
                Spacer(modifier = Modifier.height(16.dp))
                Card(colors = CardDefaults.cardColors(containerColor = Color(0xFF1E1E1E)), modifier = Modifier.fillMaxWidth()) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Text("All-Time Traffic", color = Color.Gray, style = MaterialTheme.typography.titleSmall)
                        Spacer(modifier = Modifier.height(8.dp))
                        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                            Text("Total Download:", color = Color.Gray, style = MaterialTheme.typography.labelMedium)
                            Text(formatBytes(stats.allTimeRxBytes), color = Color.Cyan, style = MaterialTheme.typography.labelMedium)
                        }
                        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                            Text("Total Upload:", color = Color.Gray, style = MaterialTheme.typography.labelMedium)
                            Text(formatBytes(stats.allTimeTxBytes), color = Color.Magenta, style = MaterialTheme.typography.labelMedium)
                        }
                    }
                }
            }
            Spacer(modifier = Modifier.height(16.dp))
            Button(onClick = onToggle, modifier = Modifier.fillMaxWidth()) {
                Text(if (isConnectedOrConnecting) "DISCONNECT" else "CONNECT")
            }
        }
    }
}

@Composable
fun StatusIndicator(title: String, state: ProcessState) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(title, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Bold)
        Text(
            text = state.name,
            style = MaterialTheme.typography.bodySmall,
            color = when (state) {
                ProcessState.RUNNING -> Color(0xFF4CAF50)
                ProcessState.STARTING -> Color(0xFFFF9800)
                ProcessState.ERROR -> Color(0xFFF44336)
                ProcessState.STOPPED -> Color.Gray
            }
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun UdpSpeederCard(config: UdpSpeederConfig, onConfigChange: (UdpSpeederConfig) -> Unit, enabled: Boolean) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text("UDPspeeder Configuration", style = MaterialTheme.typography.titleMedium)
            OutlinedTextField(
                value = config.serverIp, onValueChange = { onConfigChange(config.copy(serverIp = it)) },
                label = { Text("Server IP") }, modifier = Modifier.fillMaxWidth(), enabled = enabled
            )
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(
                    value = config.remotePort, onValueChange = { onConfigChange(config.copy(remotePort = it)) },
                    label = { Text("Remote Port") }, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                    modifier = Modifier.weight(1f), enabled = enabled
                )
                OutlinedTextField(
                    value = config.localPort, onValueChange = { onConfigChange(config.copy(localPort = it)) },
                    label = { Text("Local Port") }, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                    modifier = Modifier.weight(1f), enabled = enabled
                )
            }
            Text("Preset Profile", style = MaterialTheme.typography.labelLarge)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
                FilterChip(
                    selected = config.preset == UdpPreset.NORMAL,
                    onClick = { onConfigChange(config.copy(preset = UdpPreset.NORMAL)) },
                    label = { Text("Normal Mode") },
                    enabled = enabled
                )
                FilterChip(
                    selected = config.preset == UdpPreset.FEC,
                    onClick = { onConfigChange(config.copy(preset = UdpPreset.FEC)) },
                    label = { Text("FEC Mode") },
                    enabled = enabled
                )
            }
        }
    }
}

@Composable
fun WireGuardCard(config: WireGuardConfig, localPort: String, onConfigChange: (WireGuardConfig) -> Unit, enabled: Boolean) {
    val context = LocalContext.current
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        if (uri != null) {
            try {
                context.contentResolver.openInputStream(uri)?.use { stream ->
                    var text = InputStreamReader(stream).readText()
                    val regex = Regex("Endpoint\\s*=\\s*.*", RegexOption.IGNORE_CASE)
                    text = text.replace(regex, "Endpoint = 127.0.0.1:$localPort")
                    onConfigChange(config.copy(rawConfigText = text))
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text("WireGuard Configuration (.conf)", style = MaterialTheme.typography.titleMedium)
            Button(
                onClick = { launcher.launch("*/*") },
                enabled = enabled,
                modifier = Modifier.fillMaxWidth()
            ) {
                Text("Import Config File")
            }
            OutlinedTextField(
                value = config.rawConfigText, onValueChange = { onConfigChange(config.copy(rawConfigText = it)) },
                label = { Text("Paste config here") }, modifier = Modifier.fillMaxWidth().height(150.dp),
                enabled = enabled, textStyle = LocalTextStyle.current.copy(fontFamily = FontFamily.Monospace)
            )
        }
    }
}

@Composable
fun LogsCard(logs: List<String>, onClear: () -> Unit) {
    val clipboardManager = LocalClipboardManager.current
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                Text("Live Logs", style = MaterialTheme.typography.titleMedium)
                Row {
                    TextButton(onClick = onClear) {
                        Text("Clear")
                    }
                    TextButton(onClick = {
                        clipboardManager.setText(AnnotatedString(logs.joinToString("\n")))
                    }) {
                        Text("Copy")
                    }
                }
            }
            Spacer(modifier = Modifier.height(8.dp))
            Box(
                modifier = Modifier.fillMaxWidth().height(150.dp).background(Color.Black).padding(8.dp)
            ) {
                LazyColumn(reverseLayout = true, modifier = Modifier.fillMaxSize()) {
                    items(logs.reversed()) { log ->
                        Text(
                            text = log, color = Color.Green,
                            style = MaterialTheme.typography.bodySmall.copy(fontFamily = FontFamily.Monospace)
                        )
                    }
                }
            }
        }
    }
}

fun formatBytes(bytes: Long): String {
    if (bytes < 1024) return "$bytes B"
    val exp = (Math.log(bytes.toDouble()) / Math.log(1024.0)).toInt()
    val pre = "KMGTPE"[exp - 1]
    return String.format("%.1f %cB", bytes / Math.pow(1024.0, exp.toDouble()), pre)
}
