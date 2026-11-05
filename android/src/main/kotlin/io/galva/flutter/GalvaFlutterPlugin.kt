package io.galva.flutter

import android.app.Activity
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.galva.flutter.crossplatform.GalvaCrossplatform

/**
 * Connects the `flutter.galva.io/galva` channel to [GalvaCrossplatform], which does the work: the
 * plugin only passes method calls through and keeps track of the activity in-app messages show on.
 */
class GalvaFlutterPlugin : FlutterPlugin, ActivityAware, MethodCallHandler {

    companion object {
        private const val CHANNEL_NAME = "flutter.galva.io/galva"
    }

    private var channel: MethodChannel? = null
    private var crossplatform: GalvaCrossplatform? = null
    private var activity: Activity? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME).also { this.channel = it }
        crossplatform = GalvaCrossplatform(
            context = binding.applicationContext,
            currentActivity = { activity },
            // Events are emitted on the main thread, which MethodChannel requires.
            emit = { event, json -> channel.invokeMethod(event, json) },
        )
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val crossplatform = crossplatform ?: return result.notImplemented()
        crossplatform.handle(call.method, call.arguments as? String) { json -> result.success(json) }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        crossplatform?.release()
        crossplatform = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }
}
