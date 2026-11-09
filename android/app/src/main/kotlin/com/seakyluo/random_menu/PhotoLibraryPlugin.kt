package com.seakyluo.random_menu

import android.app.Activity
import android.Manifest
import android.content.pm.PackageManager
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.os.Build
import android.provider.MediaStore
import android.webkit.MimeTypeMap
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry.ActivityResultListener
import io.flutter.plugin.common.PluginRegistry.RequestPermissionsResultListener
import java.io.File
import java.util.concurrent.Executors

class PhotoLibraryPlugin : FlutterPlugin, ActivityAware, ActivityResultListener, RequestPermissionsResultListener {
    private lateinit var context: Context
    private lateinit var channel: MethodChannel
    private var binding: ActivityPluginBinding? = null
    private var selection: MethodChannel.Result? = null
    private var singleSelection = false
    private var readLocation = false
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "com.seakyluo.random_menu/photo_library")
        channel.setMethodCallHandler(::handle)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        worker.shutdown()
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        this.binding = binding
        binding.addActivityResultListener(this)
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() = detach()
    override fun onDetachedFromActivity() = detach()
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) = onAttachedToActivity(binding)
    private fun detach() {
        binding?.removeActivityResultListener(this)
        binding?.removeRequestPermissionsResultListener(this)
        binding = null
    }

    private fun execute(result: MethodChannel.Result, task: () -> Any?) {
        worker.execute {
            try {
                val value = task()
                main.post { result.success(value) }
            } catch (error: Exception) {
                main.post { result.error("photo_library", error.message, null) }
            }
        }
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pick" -> {
                selection = result
                singleSelection = call.argument<Boolean>("single")!!
                readLocation = call.argument<Boolean>("readLocation")!!
                if (readLocation && Build.VERSION.SDK_INT >= 29 &&
                    context.checkSelfPermission(Manifest.permission.ACCESS_MEDIA_LOCATION) != PackageManager.PERMISSION_GRANTED) {
                    binding!!.activity.requestPermissions(arrayOf(Manifest.permission.ACCESS_MEDIA_LOCATION), 52149)
                } else {
                    openPicker()
                }
            }
            "retainCapture" -> execute(result) {
                val file = File(call.argument<String>("path")!!)
                val values = ContentValues().apply {
                    put(MediaStore.Images.Media.DISPLAY_NAME, file.name)
                    put(MediaStore.Images.Media.MIME_TYPE, "image/jpeg")
                    put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/随机菜单")
                    put(MediaStore.Images.Media.IS_PENDING, 1)
                }
                val resolver = context.contentResolver
                val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)!!
                try {
                    resolver.openOutputStream(uri)!!.use { output -> file.inputStream().use { it.copyTo(output) } }
                    resolver.update(uri, ContentValues().apply { put(MediaStore.Images.Media.IS_PENDING, 0) }, null, null)
                    uri.toString()
                } catch (error: Exception) {
                    resolver.delete(uri, null, null)
                    throw error
                }
            }
            "original" -> execute(result) { copyToCache(Uri.parse(call.argument<String>("source")!!)) }
            else -> result.notImplemented()
        }
    }

    private fun openPicker() {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            type = "image/*"
            addCategory(Intent.CATEGORY_OPENABLE)
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, !singleSelection)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
        }
        binding!!.activity.startActivityForResult(intent, 52148)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray): Boolean {
        if (requestCode != 52149) return false
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            openPicker()
        } else {
            val result = selection!!
            selection = null
            result.error("photo_location_permission", "请允许读取照片位置信息，以便识别餐厅地址", null)
        }
        return true
    }

    private fun copyToCache(uri: Uri, includeLocation: Boolean = false): String {
        val resolver = context.contentResolver
        val extension = requireNotNull(MimeTypeMap.getSingleton().getExtensionFromMimeType(resolver.getType(uri))) {
            "无法识别图片格式"
        }
        val destination = File.createTempFile("original_", ".$extension", context.cacheDir)
        val source = if (includeLocation && Build.VERSION.SDK_INT >= 29) {
            val mediaUri = if (uri.authority == MediaStore.AUTHORITY) uri
                else MediaStore.getMediaUri(context, uri)
            // Other document providers supply their own file bytes, outside MediaStore.
            if (mediaUri != null) MediaStore.setRequireOriginal(mediaUri) else uri
        } else uri
        resolver.openInputStream(source)!!.use { input -> destination.outputStream().use { input.copyTo(it) } }
        return destination.path
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != 52148) return false
        val result = selection!!
        selection = null
        if (resultCode != Activity.RESULT_OK) {
            result.success(emptyList<Any>())
            return true
        }
        val picked = data!!
        val includeLocation = readLocation
        val uris = picked.clipData?.let { clips ->
            (0 until clips.itemCount).map { clips.getItemAt(it).uri }
        } ?: listOf(picked.data!!)
        execute(result) {
            uris.map { uri ->
                context.contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
                mapOf("path" to copyToCache(uri, includeLocation), "source" to uri.toString())
            }
        }
        return true
    }
}
