import Flutter
import Galva
import UIKit

/// Connects the `flutter.galva.io/galva` channel to `GalvaCrossplatform`, which does the work, and
/// forwards the APNs device token the app delegate receives to Galva.
public final class GalvaFlutterPlugin: NSObject, FlutterPlugin {
    private static let channelName = "flutter.galva.io/galva"

    private let crossplatform: GalvaCrossplatform

    private init(channel: FlutterMethodChannel) {
        crossplatform = GalvaCrossplatform { event, json in
            channel.invokeMethod(event, arguments: json)
        }
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
        let instance = GalvaFlutterPlugin(channel: channel)
        registrar.addMethodCallDelegate(instance, channel: channel)
        registrar.addApplicationDelegate(instance)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let method = call.method
        let arguments = call.arguments as? String
        Task { @MainActor in
            result(await crossplatform.handle(method: method, arguments: arguments))
        }
    }

    // Flutter's app delegate passes this to every plugin, so apps don't forward the token
    // themselves. Galva registers it again after a log out or a user switch.
    public func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Galva.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
    }
}
