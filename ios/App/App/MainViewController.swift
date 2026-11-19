import UIKit
import Capacitor

/// The game's bridge view controller (the iOS counterpart of MainActivity.java): registers the
/// app's own plugin, keeps the screen on while playing, hides the status bar and the home
/// indicator, and stays in portrait.
class MainViewController: CAPBridgeViewController {
    override open func capacitorDidLoad() {
        bridge?.registerPluginInstance(AppQuitPlugin())
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIApplication.shared.isIdleTimerDisabled = true
    }

    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }
}
