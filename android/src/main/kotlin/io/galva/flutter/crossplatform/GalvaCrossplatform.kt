package io.galva.flutter.crossplatform

import android.app.Activity
import android.content.Context
import android.net.Uri
import io.galva.sdk.Configuration
import io.galva.sdk.Environment
import io.galva.sdk.Galva
import io.galva.sdk.LogLevel
import io.galva.sdk.Message
import io.galva.sdk.ProfileProperty
import io.galva.sdk.PushProvider
import io.galva.sdk.WorkflowType
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import org.json.JSONException
import org.json.JSONObject

/**
 * The Android side of Galva's cross-platform format (cross_platform.yaml): decodes a request's
 * JSON, calls the public API of `io.galva.sdk:galva-sdk`, and answers with `{"success": …}` or
 * `{"error": {code, message, detail}}`. Delivered in-app messages go to [emit] as
 * `in_app_message_received` events.
 *
 * Everything runs on the main thread: `Galva.configure` must, and the SDK's other calls return
 * right away.
 */
internal class GalvaCrossplatform(
    private val context: Context,
    private val currentActivity: () -> Activity?,
    private val emit: (event: String, json: String) -> Unit,
) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private var messagesJob: Job? = null

    fun handle(method: String, arguments: String?, respond: (String) -> Unit) {
        scope.launch {
            val response = try {
                val args = JSONObject(arguments?.takeIf { it.isNotBlank() } ?: "{}")
                JSONObject().put(SUCCESS, execute(method, args) ?: JSONObject.NULL)
            } catch (e: CancellationException) {
                throw e
            } catch (e: CrossplatformException) {
                errorResponse(e.code, e.message, e.detail)
            } catch (e: JSONException) {
                errorResponse(ErrorCode.INVALID_ARGUMENTS, "Invalid arguments for $method", e.message)
            } catch (e: Exception) {
                errorResponse(ErrorCode.INTERNAL_PLUGIN_ERROR, "$method failed", e.toString())
            }
            respond(response.toString())
        }
    }

    fun release() {
        scope.cancel()
    }

    private fun execute(method: String, args: JSONObject): Any? = when (method) {
        Method.CONFIGURE -> configure(args.getJSONObject("configuration")).let { true }
        Method.IS_CONFIGURED -> Galva.instance.isConfigured
        Method.SET_LOG_LEVEL -> Galva.instance.setLogLevel(logLevel(args.getString("value"))).let { true }

        Method.IDENTIFY -> Galva.instance.identify(
            args.getString("user_id"),
            args.optStringOrNull("email"),
            args.optStringOrNull("android_obfuscated_account_id"),
        ).let { true }
        Method.LOGOUT -> Galva.instance.logout().let { true }
        Method.GET_IDENTIFIED_USER_ID -> Galva.instance.takeUnless { it.isAnonymous }?.currentUserId?.takeIf { it.isNotEmpty() }
        Method.SET_ATTRIBUTES -> setAttributes(args.getJSONObject("attributes")).let { true }
        Method.TRACK -> Galva.instance.track(
            args.getString("event_name"),
            args.optJSONObject("attributes")?.toMap(),
        ).let { true }

        Method.SET_OPT_OUT -> Galva.instance.setOptOut(args.getBoolean("value")).let { true }
        Method.IS_OPTED_OUT -> Galva.instance.isOptedOut

        Method.CHECK_FOR_MESSAGES -> Galva.instance.checkForMessages().let { true }
        Method.SHOW_MESSAGE -> showMessage(args.getJSONObject("message")).let { true }
        Method.HANDLE_OPEN_URL -> Galva.instance.handleOpenURL(Uri.parse(args.getString("url")))

        Method.SET_PUSH_TOKEN -> Galva.instance.setPushToken(
            args.getString("token"),
            pushProvider(args.optStringOrNull("provider")),
        ).let { true }
        Method.CLEAR_PUSH_TOKEN -> Galva.instance.clearPushToken().let { true }
        Method.IS_GALVA_NOTIFICATION -> Galva.instance.isGalvaNotification(args.getJSONObject("data").toStringMap())
        Method.HANDLE_PUSH -> Galva.instance.handlePush(args.getJSONObject("data").toStringMap()).let { true }
        Method.SET_APNS_TOKEN -> throw CrossplatformException(
            ErrorCode.UNSUPPORTED_PLATFORM,
            "set_apns_token is iOS only",
        )

        Method.RECONCILE_TRANSACTIONS -> Galva.instance.reconcileTransactions().let { true }

        else -> throw CrossplatformException(ErrorCode.METHOD_NOT_IMPLEMENTED, "Unknown method $method")
    }

    private fun configure(json: JSONObject) {
        val inAppMessages = json.optStringOrNull("in_app_messages") ?: "automatic"
        Galva.configure(
            // Dart configures once MainActivity is already on screen, so the SDK never sees that
            // activity resume; passing it lets automatic in-app messages show on it right away.
            currentActivity() ?: context,
            Configuration(
                apiKey = json.getString("api_key"),
                logLevel = logLevel(json.optStringOrNull("log_level") ?: "warn"),
                autoTrackSessions = json.optBoolean("auto_track_sessions", true),
                env = environment(json.optJSONObject("environment")),
                autoDisplayInAppMessages = inAppMessages == "automatic",
            ),
        )
        // Once per Flutter engine: a second configure (hot restart, another engine) is ignored by
        // the SDK, but this engine still needs its messages.
        if (messagesJob == null) {
            messagesJob = scope.launch {
                Galva.instance.getInAppMessage().collect { message ->
                    emit(Event.IN_APP_MESSAGE_RECEIVED, JSONObject().put("message", message.toJson()).toString())
                }
            }
        }
    }

    private fun setAttributes(json: JSONObject) {
        val properties = buildList {
            json.optStringOrNull("email")?.let { add(ProfileProperty.Email(it)) }
            json.optStringOrNull("first_name")?.let { add(ProfileProperty.FirstName(it)) }
            json.optStringOrNull("last_name")?.let { add(ProfileProperty.LastName(it)) }
            json.optStringOrNull("full_name")?.let { add(ProfileProperty.FullName(it)) }
            // The SDK takes no null value for a property, so a null leaves the attribute as it is.
            json.optJSONObject("custom")?.toMap()?.forEach { (key, value) ->
                if (value != null) add(ProfileProperty.Custom(key, value))
            }
        }
        if (properties.isNotEmpty()) Galva.instance.updateProperties(*properties.toTypedArray())
    }

    private fun showMessage(json: JSONObject) {
        val activity = currentActivity()
            ?: throw CrossplatformException(ErrorCode.NO_PRESENTER, "No activity to show the message on")
        // The SDK resolves the message by ID; the type and time only describe it.
        val message = Message(
            json.getString("id"),
            json.optStringOrNull("workflow_type")?.let(::workflowType),
            json.optStringOrNull("created_at"),
        )
        Galva.instance.showMessage(activity, message)
    }

    private fun Message.toJson(): JSONObject = JSONObject()
        .put("id", id)
        .putOpt("workflow_type", workflowType?.let(::workflowTypeRawValue))
        .putOpt("created_at", createdAt)

    private fun errorResponse(code: Int, message: String?, detail: String?): JSONObject = JSONObject().put(
        ERROR,
        JSONObject().put("code", code).put("message", message ?: "Unknown error").putOpt("detail", detail),
    )

    private companion object {
        const val SUCCESS = "success"
        const val ERROR = "error"

        fun logLevel(value: String): LogLevel = when (value) {
            "none" -> LogLevel.NONE
            "error" -> LogLevel.ERROR
            "warn" -> LogLevel.WARN
            "info" -> LogLevel.INFO
            "debug" -> LogLevel.DEBUG
            "verbose" -> LogLevel.VERBOSE
            else -> throw CrossplatformException(ErrorCode.INVALID_ARGUMENTS, "Unknown log level $value")
        }

        fun environment(json: JSONObject?): Environment = when (val type = json?.optStringOrNull("type") ?: "production") {
            "production" -> Environment.Production
            "development" -> Environment.Development
            "custom" -> Environment.Custom(json!!.getString("api_url"), json.getString("webview_url"))
            else -> throw CrossplatformException(ErrorCode.INVALID_ARGUMENTS, "Unknown environment $type")
        }

        fun pushProvider(value: String?): PushProvider = when (value ?: "fcm") {
            "fcm" -> PushProvider.FCM
            "hms" -> PushProvider.HMS
            "adm" -> PushProvider.ADM
            else -> throw CrossplatformException(ErrorCode.INVALID_ARGUMENTS, "Unknown push provider $value")
        }

        /** `trial-rescue` ↔ `TRIAL_RESCUE`; a type this SDK version doesn't know reads as `null`. */
        fun workflowType(rawValue: String): WorkflowType? =
            WorkflowType.entries.firstOrNull { workflowTypeRawValue(it) == rawValue }

        fun workflowTypeRawValue(type: WorkflowType): String = type.name.lowercase().replace('_', '-')
    }
}

/** Method names, as in cross_platform.yaml and lib/src/constants/method.dart. */
internal object Method {
    const val CONFIGURE = "configure"
    const val IS_CONFIGURED = "is_configured"
    const val SET_LOG_LEVEL = "set_log_level"
    const val IDENTIFY = "identify"
    const val LOGOUT = "logout"
    const val GET_IDENTIFIED_USER_ID = "get_identified_user_id"
    const val SET_ATTRIBUTES = "set_attributes"
    const val TRACK = "track"
    const val SET_OPT_OUT = "set_opt_out"
    const val IS_OPTED_OUT = "is_opted_out"
    const val CHECK_FOR_MESSAGES = "check_for_messages"
    const val SHOW_MESSAGE = "show_message"
    const val HANDLE_OPEN_URL = "handle_open_url"
    const val SET_PUSH_TOKEN = "set_push_token"
    const val SET_APNS_TOKEN = "set_apns_token"
    const val CLEAR_PUSH_TOKEN = "clear_push_token"
    const val IS_GALVA_NOTIFICATION = "is_galva_notification"
    const val HANDLE_PUSH = "handle_push"
    const val RECONCILE_TRANSACTIONS = "reconcile_transactions"
}

/** Event names, as in cross_platform.yaml and lib/src/constants/event.dart. */
internal object Event {
    const val IN_APP_MESSAGE_RECEIVED = "in_app_message_received"
}

/** Error codes, as in GalvaErrorCode in lib/src/models/galva_error.dart. */
internal object ErrorCode {
    const val INVALID_ARGUMENTS = 2
    const val METHOD_NOT_IMPLEMENTED = 3
    const val UNSUPPORTED_PLATFORM = 4
    const val NO_PRESENTER = 6
    const val INTERNAL_PLUGIN_ERROR = 9
}

internal class CrossplatformException(
    val code: Int,
    override val message: String,
    val detail: String? = null,
) : Exception(message)
