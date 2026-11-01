package com.seakyluo.random_menu

import android.location.Geocoder
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale
import java.util.concurrent.Executors
import java.util.regex.Pattern
import java.util.regex.PatternSyntaxException

class MainActivity : FlutterActivity() {
    private val geocoding = Executors.newSingleThreadExecutor()
    private val tagMatching = Executors.newSingleThreadExecutor()
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
                    val found = Geocoder(this, Locale.SIMPLIFIED_CHINESE)
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

    override fun onDestroy() {
        geocoding.shutdown()
        tagMatching.shutdown()
        super.onDestroy()
    }
}
