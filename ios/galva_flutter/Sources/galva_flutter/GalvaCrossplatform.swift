import Foundation
import Galva
import UIKit

/// The iOS side of Galva's cross-platform format (cross_platform.yaml): decodes a request's JSON,
/// calls the public API of galva-ios, and answers with `{"success": …}` or
/// `{"error": {code, message, detail}}`. Delivered in-app messages go to `emit` as
/// `in_app_message_received` events.
@MainActor
final class GalvaCrossplatform {
    private let emit: (_ event: String, _ json: String) -> Void
    private var messagesTask: Task<Void, Never>?
    private var configured = false

    /// The messages Galva delivered, by ID. `show_message` needs the SDK's own object: Dart only
    /// has its JSON, and the SDK can't show a message it didn't issue.
    private var messages: [String: Galva.InAppMessages.Message] = [:]

    init(emit: @escaping (_ event: String, _ json: String) -> Void) {
        self.emit = emit
    }

    func handle(method: String, arguments: String?) async -> String {
        do {
            let args = try Self.decode(arguments)
            let value = try await execute(method, args)
            return Self.encode(["success": value ?? NSNull()])
        } catch let error as CrossplatformError {
            return Self.errorResponse(error.code, error.message, error.detail)
        } catch {
            return Self.errorResponse(ErrorCode.internalPluginError, "\(method) failed", String(describing: error))
        }
    }

    // MARK: - Methods

    private func execute(_ method: String, _ args: [String: Any]) async throws -> Any? {
        switch method {
        case "configure":
            try configure(args.object("configuration"))
            return true
        case "is_configured":
            return configured
        case "set_log_level":
            // The iOS SDK takes its level at configure only.
            _ = try Self.logLevel(args.string("value"))
            return true

        case "identify":
            let token = try args.optionalString("ios_app_account_token").map { raw -> UUID in
                guard let uuid = UUID(uuidString: raw) else {
                    throw CrossplatformError(ErrorCode.invalidArguments, "ios_app_account_token isn't a UUID: \(raw)")
                }
                return uuid
            }
            Galva.AppUser.identify(userId: try args.string("user_id"), appAccountToken: token)
            if let email = try args.optionalString("email") {
                Galva.AppUser.set(.email, email)
            }
            return true
        case "logout":
            Galva.AppUser.logOut()
            return true
        case "get_identified_user_id":
            return Galva.AppUser.identifiedUserId
        case "set_attributes":
            try setAttributes(args.object("attributes"))
            return true
        case "track":
            Galva.AppEvents.track(try args.string("event_name"), attributes: args["attributes"] as? [String: Any])
            return true

        case "set_opt_out":
            Galva.setOptOut(try args.bool("value"))
            return true
        case "is_opted_out":
            return Galva.isOptedOut

        case "check_for_messages":
            Galva.InAppMessages.checkForMessages()
            return true
        case "show_message":
            try await showMessage(args.object("message"))
            return true
        case "handle_open_url":
            guard let url = URL(string: try args.string("url")) else {
                throw CrossplatformError(ErrorCode.invalidArguments, "Not a URL")
            }
            return Galva.handleOpenURL(url)

        case "set_apns_token":
            guard let token = Data(hex: try args.string("token")) else {
                throw CrossplatformError(ErrorCode.invalidArguments, "The APNs token isn't hex")
            }
            Galva.application(UIApplication.shared, didRegisterForRemoteNotificationsWithDeviceToken: token)
            return true
        case "is_galva_notification":
            return false
        case "set_push_token", "clear_push_token", "handle_push":
            throw CrossplatformError(ErrorCode.unsupportedPlatform, "\(method) is Android only")

        case "reconcile_transactions":
            Galva.reconcileTransactions()
            return true

        default:
            throw CrossplatformError(ErrorCode.methodNotImplemented, "Unknown method \(method)")
        }
    }

    private func configure(_ json: [String: Any]) throws {
        var autoTrack: Galva.AutoTrackCategory = []
        if (json["auto_track_sessions"] as? Bool) ?? true { autoTrack.insert(.lifecycle) }
        if (json["ios_apple_search_ads"] as? Bool) ?? true { autoTrack.insert(.appleSearchAds) }

        Galva.configure(
            apiKey: try json.string("api_key"),
            environment: try Self.environment(json["environment"] as? [String: Any]),
            inAppMessages: (json["in_app_messages"] as? String) == "manual" ? .manual : .automatic,
            autoTrackCategories: autoTrack,
            logLevel: try Self.logLevel((json["log_level"] as? String) ?? "warn")
        )
        configured = true

        // Once per Flutter engine: a second configure (hot restart, another engine) is ignored by
        // the SDK, but this engine still needs its messages.
        guard messagesTask == nil else { return }
        messagesTask = Task { @MainActor [weak self] in
            for await message in Galva.InAppMessages.messages {
                self?.deliver(message)
            }
        }
    }

    private func setAttributes(_ json: [String: Any]) throws {
        if let email = json["email"] as? String { Galva.AppUser.set(.email, email) }
        if let firstName = json["first_name"] as? String { Galva.AppUser.set(.firstName, firstName) }
        if let lastName = json["last_name"] as? String { Galva.AppUser.set(.lastName, lastName) }
        if let fullName = json["full_name"] as? String { Galva.AppUser.set(.fullName, fullName) }
        if let custom = json["custom"] as? [String: Any], !custom.isEmpty { Galva.AppUser.set(custom) }
    }

    private func showMessage(_ json: [String: Any]) async throws {
        let id = try json.string("id")
        guard let message = messages[id] else {
            throw CrossplatformError(ErrorCode.messageNotFound, "Galva didn't deliver message \(id) in this session")
        }
        do {
            try await message.show()
        } catch let error as Galva.InAppMessages.Error {
            throw Self.crossplatformError(error, messageId: id)
        }
    }

    private func deliver(_ message: Galva.InAppMessages.Message) {
        messages[message.id] = message
        var json: [String: Any] = [
            "id": message.id,
            "created_at": Self.dateFormatter.string(from: message.createdAt),
        ]
        if let workflowType = message.workflowType { json["workflow_type"] = workflowType.rawValue }
        emit("in_app_message_received", Self.encode(["message": json]))
    }

    // MARK: - Mapping

    private static let dateFormatter = ISO8601DateFormatter()

    private static func logLevel(_ value: String) throws -> Galva.LogLevel {
        switch value {
        case "none": return .off
        case "error": return .error
        case "warn": return .warning
        case "info": return .info
        case "debug", "verbose": return .debug
        default: throw CrossplatformError(ErrorCode.invalidArguments, "Unknown log level \(value)")
        }
    }

    private static func environment(_ json: [String: Any]?) throws -> Galva.Environment {
        switch (json?["type"] as? String) ?? "production" {
        case "production":
            return .production
        case "development":
            return .development
        case "custom":
            guard let api = (json?["api_url"] as? String).flatMap(URL.init(string:)),
                  let webview = (json?["webview_url"] as? String).flatMap(URL.init(string:)) else {
                throw CrossplatformError(ErrorCode.invalidArguments, "A custom environment needs api_url and webview_url")
            }
            return .custom(apiBaseURL: api, webviewBundleCDN: webview)
        case let type:
            throw CrossplatformError(ErrorCode.invalidArguments, "Unknown environment \(type)")
        }
    }

    private static func crossplatformError(_ error: Galva.InAppMessages.Error, messageId: String) -> CrossplatformError {
        let detail = String(describing: error)
        switch error {
        case .notConfigured:
            return CrossplatformError(ErrorCode.notConfigured, "Galva isn't configured", detail)
        case .noPresentingViewController:
            return CrossplatformError(ErrorCode.noPresenter, "No window to show message \(messageId) on", detail)
        case .messageNotFound:
            return CrossplatformError(ErrorCode.messageNotFound, "Galva no longer offers message \(messageId)", detail)
        case .requestFailed, .bundleUnavailable:
            return CrossplatformError(ErrorCode.messageUnavailable, "Message \(messageId) couldn't load", detail)
        @unknown default:
            return CrossplatformError(ErrorCode.internalPluginError, "Message \(messageId) couldn't show", detail)
        }
    }

    // MARK: - JSON

    private static func decode(_ arguments: String?) throws -> [String: Any] {
        guard let arguments, !arguments.isEmpty else { return [:] }
        guard let data = arguments.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CrossplatformError(ErrorCode.invalidArguments, "Arguments aren't a JSON object")
        }
        return object
    }

    private static func encode(_ object: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: object),
              let string = String(data: data, encoding: .utf8) else {
            return #"{"error":{"code":9,"message":"Couldn't encode the response"}}"#
        }
        return string
    }

    private static func errorResponse(_ code: Int, _ message: String, _ detail: String?) -> String {
        var error: [String: Any] = ["code": code, "message": message]
        if let detail { error["detail"] = detail }
        return encode(["error": error])
    }
}

/// Error codes, as in GalvaErrorCode in lib/src/models/galva_error.dart.
enum ErrorCode {
    static let invalidArguments = 2
    static let methodNotImplemented = 3
    static let unsupportedPlatform = 4
    static let notConfigured = 5
    static let noPresenter = 6
    static let messageNotFound = 7
    static let messageUnavailable = 8
    static let internalPluginError = 9
}

struct CrossplatformError: Error {
    let code: Int
    let message: String
    let detail: String?

    init(_ code: Int, _ message: String, _ detail: String? = nil) {
        self.code = code
        self.message = message
        self.detail = detail
    }
}

private extension Dictionary where Key == String, Value == Any {
    func string(_ key: String) throws -> String {
        guard let value = self[key] as? String else {
            throw CrossplatformError(ErrorCode.invalidArguments, "Missing \(key)")
        }
        return value
    }

    func optionalString(_ key: String) throws -> String? {
        switch self[key] {
        case nil, is NSNull: return nil
        case let value as String: return value
        default: throw CrossplatformError(ErrorCode.invalidArguments, "\(key) isn't a string")
        }
    }

    func bool(_ key: String) throws -> Bool {
        guard let value = self[key] as? Bool else {
            throw CrossplatformError(ErrorCode.invalidArguments, "Missing \(key)")
        }
        return value
    }

    func object(_ key: String) throws -> [String: Any] {
        guard let value = self[key] as? [String: Any] else {
            throw CrossplatformError(ErrorCode.invalidArguments, "Missing \(key)")
        }
        return value
    }
}

private extension Data {
    /// Bytes from a hex string, such as an APNs token from `firebase_messaging`.
    init?(hex: String) {
        let characters = Array(hex.lowercased().filter { !$0.isWhitespace })
        guard characters.count.isMultiple(of: 2), !characters.isEmpty else { return nil }
        var bytes = [UInt8]()
        bytes.reserveCapacity(characters.count / 2)
        for index in stride(from: 0, to: characters.count, by: 2) {
            guard let byte = UInt8(String(characters[index...index + 1]), radix: 16) else { return nil }
            bytes.append(byte)
        }
        self.init(bytes)
    }
}
