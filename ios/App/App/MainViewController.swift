import UIKit
import Capacitor

/// The game's bridge view controller (the iOS counterpart of MainActivity.java): registers the
/// app's own plugin, keeps the screen on while playing, hides the status bar and stays in
/// portrait. (Capacitor's controller does not let subclasses override
/// prefersHomeIndicatorAutoHidden; the game is laid out above the home indicator instead.)
class MainViewController: CAPBridgeViewController {
    override open func capacitorDidLoad() {
        bridge?.registerPluginInstance(AppQuitPlugin())
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIApplication.shared.isIdleTimerDisabled = true
    }

    override var prefersStatusBarHidden: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }
}
