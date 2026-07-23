package com.selcuk9805.vpnchain.native

import android.content.Context
import android.util.Log
import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader

object UDPspeederClient {
    private const val TAG = "UDPspeederClient"
    private var appContext: Context? = null
    private var speederProcess: Process? = null
    
    var onLogListener: ((String) -> Unit)? = null

    fun init(context: Context) {
        appContext = context.applicationContext
        val binaryFile = File(context.applicationInfo.nativeLibraryDir, "libspeederv2.so")
        if (binaryFile.exists() && binaryFile.canExecute()) {
            Log.i(TAG, "Successfully located UDPspeeder binary in nativeLibraryDir")
        } else {
            Log.e(TAG, "UDPspeeder binary NOT found or NOT executable at ${binaryFile.absolutePath}")
        }
    }

    fun startSpeeder(configParams: String) {
        val context = appContext ?: throw IllegalStateException("UDPspeederClient not initialized")
        stopSpeeder() // Ensure any previous instance is stopped

        val binaryFile = File(context.applicationInfo.nativeLibraryDir, "libspeederv2.so")
        if (!binaryFile.exists() || !binaryFile.canExecute()) {
            throw IllegalStateException("UDPspeeder binary is missing or not executable at ${binaryFile.absolutePath}")
        }

        try {
            val commandList = mutableListOf(binaryFile.absolutePath)
            commandList.addAll(configParams.split(Regex("\\s+")))

            Log.i(TAG, "Starting UDPspeeder with command: $commandList")
            val processBuilder = ProcessBuilder(commandList)
            processBuilder.redirectErrorStream(true) // Merge stderr and stdout
            
            val process = processBuilder.start()
            speederProcess = process

            // Read logs asynchronously
            Thread {
                try {
                    BufferedReader(InputStreamReader(process.inputStream)).use { reader ->
                        var line: String?
                        while (reader.readLine().also { line = it } != null) {
                            line?.let { 
                                Log.d(TAG, it)
                                onLogListener?.invoke("[UDPspeeder] $it")
                            }
                        }
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error reading UDPspeeder output", e)
                }
                onLogListener?.invoke("[UDPspeeder] Process terminated.")
            }.start()
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start UDPspeeder process", e)
            throw e
        }
    }

    fun stopSpeeder() {
        speederProcess?.let {
            try {
                it.destroy()
                Log.i(TAG, "UDPspeeder process destroyed")
            } catch (e: Exception) {
                Log.e(TAG, "Error destroying UDPspeeder process", e)
            } finally {
                speederProcess = null
            }
        }
    }
}
