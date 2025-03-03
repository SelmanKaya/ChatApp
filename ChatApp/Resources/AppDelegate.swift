import UIKit
import Firebase
import GoogleSignIn
import FirebaseAuth

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // Firebase yapılandırması
        FirebaseApp.configure()
        
        // Google Sign-In yapılandırması
        let signInConfig = GIDConfiguration(clientID: FirebaseApp.app()?.options.clientID ?? "")
        GIDSignIn.sharedInstance.configuration = signInConfig
        
        return true
    }
    
    // MARK: - Google Sign-In URL Handling
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        // Google Sign-In işlemi için URL'yi yönet
        return GIDSignIn.sharedInstance.handle(url)
    }

    // MARK: UISceneSession Lifecycle
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) { }
}
