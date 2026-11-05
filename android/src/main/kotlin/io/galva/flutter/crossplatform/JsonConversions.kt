package io.galva.flutter.crossplatform

import org.json.JSONArray
import org.json.JSONObject

/** The string at [key], or null when it's missing or JSON `null`. */
internal fun JSONObject.optStringOrNull(key: String): String? =
    if (isNull(key)) null else optString(key)

/** A JSON object as the plain Kotlin values the Galva SDK takes: maps, lists, strings, numbers, booleans and null. */
internal fun JSONObject.toMap(): Map<String, Any?> =
    keys().asSequence().associateWith { key -> opt(key).toPlainValue() }

/** Push data: every value as a string, as FCM delivers it. */
internal fun JSONObject.toStringMap(): Map<String, String> =
    keys().asSequence().associateWith { key -> optString(key) }

private fun Any?.toPlainValue(): Any? = when (this) {
    null, JSONObject.NULL -> null
    is JSONObject -> toMap()
    is JSONArray -> (0 until length()).map { opt(it).toPlainValue() }
    else -> this
}
