package com.selcuk9805.vpnchain.models

import android.content.Context
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken

class ProfileRepository(private val context: Context) {
    private val prefs = context.getSharedPreferences("vpn_profiles", Context.MODE_PRIVATE)
    private val gson = Gson()
    
    fun getProfiles(): List<VpnProfile> {
        val json = prefs.getString("profiles", null) ?: return emptyList()
        val type = object : TypeToken<List<VpnProfile>>() {}.type
        return gson.fromJson(json, type) ?: emptyList()
    }
    
    fun saveProfiles(profiles: List<VpnProfile>) {
        val json = gson.toJson(profiles)
        prefs.edit().putString("profiles", json).apply()
    }
    
    fun exportProfiles(): String {
        return gson.toJson(getProfiles())
    }
}
