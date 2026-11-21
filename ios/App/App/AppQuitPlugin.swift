import Foundation
import UIKit
import Capacitor

/// The app's own plugin, "AppQuit" in JavaScript (src/core/native.ts), as on Android
/// (QuitPlugin.java). iOS apps do not close themselves, so `quit` is unavailable and the game
/// shows its goodbye card instead; `openUrl` opens a web link in Safari.
@objc(AppQuitPlugin)
public class AppQuitPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "AppQuitPlugin"
    public let jsName = "AppQuit"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "quit", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "openUrl", returnType: CAPPluginReturnPromise),
    ]

    @objc func quit(_ call: CAPPluginCall) {
        call.unavailable("iOS apps do not close themselves")
    }

    @objc func openUrl(_ call: CAPPluginCall) {
        guard let text = call.getString("url"), let url = URL(string: text),
              url.scheme == "https" || url.scheme == "http" else {
            call.reject("not a web link")
            return
        }
        DispatchQueue.main.async {
            UIApplication.shared.open(url, options: [:]) { opened in
                if opened {
                    call.resolve()
                } else {
                    call.reject("could not open the link")
                }
            }
        }
    }
}
