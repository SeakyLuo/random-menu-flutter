package com.seakyluo.random_menu

import android.location.Geocoder
import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel
import java.util.Locale
import java.util.concurrent.Executors
import java.util.regex.Pattern
import java.util.regex.PatternSyntaxException

class MainActivity : FlutterActivity() {
    override fun provideFlutterEngine(context: Context): FlutterEngine? = FlutterEngineCache.getInstance().get("random_menu")
    override fun shouldDestroyEngineWithHost() = false
    private var notificationResult: MethodChannel.Result? = null
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != 52147) return
        val result = notificationResult!!
        notificationResult = null
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            setMcpEnabled(true)
            result.success(null)
        } else result.error("notification_permission", "请允许通知，以便在后台连接时关闭服务", null)
    }

    private fun setMcpEnabled(enabled: Boolean) {
        val service = Intent(this, McpConnectionService::class.java)
        if (!enabled) stopService(service)
        else if (Build.VERSION.SDK_INT >= 26) startForegroundService(service)
        else startService(service)
    }

    companion object {
        // The cached Flutter engine keeps serving MCP after its Activity closes.
        private val geocoding = Executors.newSingleThreadExecutor()
        private val tagMatching = Executors.newSingleThreadExecutor()
    }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        if (!flutterEngine.plugins.has(PhotoLibraryPlugin::class.java)) {
            flutterEngine.plugins.add(PhotoLibraryPlugin())
        }
        FlutterEngineCache.getInstance().put("random_menu", flutterEngine)
        val mcp = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.seakyluo.random_menu/mcp")
        McpConnectionService.channel = mcp
        mcp.setMethodCallHandler { call, result ->
            if (call.method != "setEnabled") { result.notImplemented(); return@setMethodCallHandler }
            val enabled = call.argument<Boolean>("enabled")!!
            if (enabled && Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                notificationResult = result
                requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 52147)
            } else {
                setMcpEnabled(enabled)
                result.success(null)
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "com.seakyluo.random_menu/tag_patterns").setMethodCallHandler { call, result ->
            if (call.method != "validate" && call.method != "match") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val patterns = call.argument<List<String>>("patterns")!!
            val main = Handler(Looper.getMainLooper())
            tagMatching.execute {
                try {
                    val compiled = patterns.map { it to Pattern.compile(it) }
                    if (call.method == "validate") {
                        main.post { result.success(null) }
                    } else {
                        val text = call.argument<String>("text")!!
                        val matched = compiled.filter { (source, expression) ->
                            text.contains(source) || expression.matcher(text).matches()
                        }.map { it.first }
                        main.post { result.success(matched) }
                    }
                } catch (error: PatternSyntaxException) {
                    main.post { result.error("invalid_pattern", error.description, null) }
                } catch (error: Exception) {
                    main.post { result.error("pattern_failed", error.message, null) }
                }
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "com.seakyluo.random_menu/photo_location").setMethodCallHandler { call, result ->
            if (call.method != "reverseGeocode") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val latitude = call.argument<Double>("latitude")!!
            val longitude = call.argument<Double>("longitude")!!
            val main = Handler(Looper.getMainLooper())
            geocoding.execute {
                try {
                    @Suppress("DEPRECATION")
                    val found = Geocoder(applicationContext, Locale.SIMPLIFIED_CHINESE)
                        .getFromLocation(latitude, longitude, 1)?.firstOrNull()
                    val address = found?.let {
                        mapOf("province" to (it.adminArea ?: ""),
                            "city" to (it.locality ?: ""),
                            "county" to (it.subLocality ?: it.subAdminArea ?: ""),
                            "detail" to listOfNotNull(it.thoroughfare, it.subThoroughfare)
                                .joinToString(""))
                    }
                    main.post { result.success(address) }
                } catch (error: Exception) {
                    main.post { result.error("geocode_failed", error.message, null) }
                }
            }
        }
    }

}
