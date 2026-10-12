import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
    #if WATCH_BETA
    override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        let remaining = URLContexts.filter { !PKGarminBridge.handleURL($0.url) }
        if !remaining.isEmpty { super.scene(scene, openURLContexts: Set(remaining)) }
    }
    override func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        super.scene(scene, willConnectTo: session, options: connectionOptions)
        for context in connectionOptions.urlContexts { _ = PKGarminBridge.handleURL(context.url) }
    }
    #endif
}
