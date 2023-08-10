import UIKit

import LineSDK

@objc public class SwiftLineSdkPlugin: NSObject {
    public func application(
        _ application: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool
    {
        return LoginManager.shared.application(application, open: url, options: options)
    }
    
    public func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([Any]) -> Void) -> Bool
    {
        return LoginManager.shared.application(application, open: userActivity.webpageURL)
    }
    
    static func login(channelId: String, completionHandler completion: @escaping (Result<LoginResult, LineSDKError>) -> Void) {
        if (!LoginManager.shared.isSetupFinished) {
            LoginManager.shared.setup(channelID: channelId, universalLinkURL: nil)
        }
        let scopes : [LoginPermission] = [.profile]
        var parameters = LoginManager.Parameters()
        parameters.onlyWebLogin = false
        // parameters.IDTokenNonce = args["idTokenNonce"] as? String
        parameters.botPromptStyle = .normal

        LoginManager.shared.login(
          permissions: Set(scopes),
          in: nil,
          parameters: parameters) { r in
              completion(r);
        }
    }
}
