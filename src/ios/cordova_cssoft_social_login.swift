/********* cordova_cssoft_social_login.m Cordova Plugin Implementation *******/

// #import <Cordova/CDV.h>

// @interface cordova_cssoft_social_login : CDVPlugin {
//   // Member variables go here.
// }

// - (void)coolMethod:(CDVInvokedUrlCommand*)command;
// @end

// @implementation cordova_cssoft_social_login

// - (void)coolMethod:(CDVInvokedUrlCommand*)command
// {
//     CDVPluginResult* pluginResult = nil;
//     NSString* echo = [command.arguments objectAtIndex:0];

//     if (echo != nil && [echo length] > 0) {
//         pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:echo];
//     } else {
//         pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
//     }

//     [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
// }

// @end

import FBSDKLoginKit
import Foundation
import FirebaseAuth
import GoogleSignIn
import FirebaseCore
import UIKit
import AuthenticationServices
import CryptoKit

@objc(cordova_cssoft_social_login)
class cordova_cssoft_social_login: CDVPlugin {
    
    var linePlugin: SwiftLineSdkPlugin?;
    
    var firebaseLogin : FirebaseSocialLogin?;
    
    override func pluginInitialize() {
        super.pluginInitialize();
    }
    
    override init() {
        super.init()
        firebaseLogin = FirebaseSocialLogin(plugin: self);
    }
    
    @objc(login_apple:)
    func login_apple(command: CDVInvokedUrlCommand) {
        firebaseLogin?.loginApple(command: command);
    }
    
    @objc(login_google:)
    func login_google(command: CDVInvokedUrlCommand) {
        firebaseLogin?.loginGoogle(command: command);
    }
    
    @objc(login_facebook:)
    func login_facebook(command: CDVInvokedUrlCommand) {
        firebaseLogin?.loginFacebook(command: command);
    }
    
    @objc(login_twitter:)
    func login_twitter(command: CDVInvokedUrlCommand) {
        firebaseLogin?.loginTwitter(command: command);
    }
    
    @objc(login_line:)
    func login_line(command: CDVInvokedUrlCommand) {
        var channelId: String = "";
        let args = pareJsonArg(command)
        channelId = args["channelId"] as? String ?? ""
        firebaseLogin?.loginLine(command: command, channelId: channelId);
    }
    
    func pareJsonArg(_ command: CDVInvokedUrlCommand) -> [String: Any] {
        var json: String = "";
        if (command.arguments.count > 0) {
            json = command.arguments.first as? String ?? "";
        }
        var dictionary: [String: Any] = [:];
        if (!json.isEmpty) {
            let data = json.data(using: .utf8)!;
            do {
                dictionary = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] ?? [:];
            } catch {
                print(error.localizedDescription)
            }
        }
        return dictionary
    }
}


var twiterProvider = OAuthProvider(providerID: "twitter.com")

class FirebaseSocialLogin: NSObject, ASAuthorizationControllerDelegate  {

    var plugin: CDVPlugin;
    var command: CDVInvokedUrlCommand?;
    
    init(plugin: CDVPlugin) {
        self.plugin = plugin;
    }
    
    private func mainWindow() -> UIWindow? {
        if let applicationWindow = UIApplication.shared.delegate?.window ?? nil {
            return applicationWindow
        }
        
        
        if #available(iOS 13.0, *) {
            if let scene = UIApplication.shared.connectedScenes.first(where: { $0.session.role == .windowApplication }),
               let sceneDelegate = scene.delegate as? UIWindowSceneDelegate,
               let window = sceneDelegate.window as? UIWindow  {
                return window
            }
        }
        
        return nil
    }
    
    func loginSuccess(result: SocialLoginResult) {
        print("Social login success: \(result.description())");
        if (command != nil) {
            let data: String = result.toJsonString() ?? "";
            let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: data)
            plugin.commandDelegate.send(pluginResult, callbackId: command!.callbackId)
        }
        command = nil;
    }

    func loginError(result: SocialLoginResult) {
        print("Social login error: \(result.description())");
        if (command != nil) {
            let data: String = result.toJsonString() ?? "";
            let pluginResult = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: data)
            plugin.commandDelegate.send(pluginResult, callbackId: command!.callbackId)
        }
        command = nil;
    }
    
    func handleFirebaseAuthDataResult(authResult: AuthDataResult?,
                                      error: Error?, type: String) {
        let errorResult = SocialLoginResult(type: type, success: false);
        if (error != nil || authResult == nil) {
            errorResult.errorMessage = error?.localizedDescription
            self.loginError(result: errorResult)
            return
        }
        // User is signed in to Firebase
        let result = SocialLoginResult(type: type, success: true);
        
        // let credential: AuthCredential? = authResult!.credential;
        // let oauth: OAuthCredential? = credential as? OAuthCredential;
        
        let user = authResult!.user;
        user.getIDToken() {token, tokenError in
            if (tokenError != nil || token == nil) {
                result.setGoogleAuthResult(authResult: authResult!)
                self.loginSuccess(result: result)
                return
            } else {
                result.setGoogleAuthResultWithToken(authResult: authResult!, idToken: token)
                self.loginSuccess(result: result)
                return
            }
        }
    }
    
    // Apple
    // Unhashed nonce.
    var currentNonce: String?
    
    @available(iOS 13, *)
    func loginApple(command: CDVInvokedUrlCommand) {
        self.command = command;
        signOutFirebase();
        let nonce = randomNonceString()
        currentNonce = nonce
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        // authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError(
                "Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)"
            )
        }
        
        let charset: [Character] =
        Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        
        let nonce = randomBytes.map { byte in
            // Pick a random character from the set, wrapping around if needed.
            charset[Int(byte) % charset.count]
        }
        
        return String(nonce)
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
    
    public func authorizationController(
        controller _: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            let errorResult = SocialLoginResult(type: SocialLoginResult.typeApple, success: false);
            guard let nonce = currentNonce else {
                errorResult.errorMessage = "Invalid state: A login callback was received, but no login request was sent."
                self.loginError(result: errorResult)
                return;
            }
            guard let appleIDToken = appleIDCredential.identityToken else {
                errorResult.errorMessage = "Unable to fetch identity token"
                self.loginError(result: errorResult)
                return
            }
            guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                errorResult.errorMessage = "Unable to serialize token string from data: \(appleIDToken.debugDescription)"
                self.loginError(result: errorResult)
                return
            }
            // Initialize a Firebase credential, including the user's full name.
            let credential = OAuthProvider.appleCredential(withIDToken: idTokenString,
                                                           rawNonce: nonce,
                                                           fullName: appleIDCredential.fullName)
            // Sign in with Firebase.
            Auth.auth().signIn(with: credential) { (authResult, error) in
                self.handleFirebaseAuthDataResult(authResult: authResult, error: error, type: SocialLoginResult.typeApple)
            }
        }
    }
    
    public func authorizationController(
        controller _: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        let errorResult = SocialLoginResult(type: SocialLoginResult.typeApple, success: false);
        errorResult.errorMessage = error.localizedDescription;
        self.loginError(result: errorResult)
    }
    
    func signOutFirebase() {
        do {
            try Auth.auth().signOut();
        } catch {
            print("Firebase SignOut error: \(error)")
        }
    }
    
    /// Google
    func loginGoogle(command: CDVInvokedUrlCommand) {
        self.command = command;
        signOutFirebase();
        let errorResult = SocialLoginResult(type: SocialLoginResult.typeGoogle, success: false);
        guard let clientID = FirebaseApp.app()?.options.clientID else { return }
        // Create Google Sign In configuration object.
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        // Start the sign in flow!
        GIDSignIn.sharedInstance.signIn(withPresenting: mainWindow()!.rootViewController!) { result, error in
            guard error == nil else {
                errorResult.errorMessage = error?.localizedDescription;
                self.loginError(result: errorResult)
                return;
            }
            
            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString
            else {
                errorResult.errorMessage = "idToken is null";
                self.loginError(result: errorResult)
                return;
            }
            
            let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                           accessToken: user.accessToken.tokenString)
            Auth.auth().signIn(with: credential) { authResult, error in
                self.handleFirebaseAuthDataResult(authResult: authResult, error: error, type: SocialLoginResult.typeGoogle)
            }
        }
    }
    
    /// Facebook
    let fbLoginManager : LoginManager = LoginManager()
    
    func loginFacebook(command: CDVInvokedUrlCommand) {
        self.command = command;
        signOutFirebase();
        fbLoginManager.logOut();
        let nonce = self.randomNonceString()
        let configuration = LoginConfiguration(
            permissions:["public_profile", "email"],
            nonce: sha256(nonce)
        );
        fbLoginManager.logIn(configuration: configuration) { result in
            let errorResult = SocialLoginResult(type: SocialLoginResult.typeFacebook, success: false);
            switch result {
            case .cancelled:
                self.loginError(result: errorResult)
                break
            case .failed(let error):
                errorResult.errorMessage = error.localizedDescription;
                self.loginError(result: errorResult)
                break
            case .success:
                let idTokenString = AuthenticationToken.current?.tokenString
                
                let credential: OAuthCredential = OAuthProvider.credential(withProviderID: "facebook.com",
                                                                           idToken: idTokenString!,
                                                                           rawNonce: nonce)
                Auth.auth().signIn(with: credential) { authResult, error in
                    self.handleFirebaseAuthDataResult(authResult: authResult, error: error, type: SocialLoginResult.typeFacebook)
                }
            }
        }
    }
    
    /// Twitter
    
    func loginTwitter(command: CDVInvokedUrlCommand) {
        self.command = command;
        signOutFirebase();
        twiterProvider.getCredentialWith(nil) { credential, error in
            let errorResult = SocialLoginResult(type: SocialLoginResult.typeTwitter, success: false);
            if error != nil {
                errorResult.errorMessage = error?.localizedDescription;
                self.loginError(result: errorResult)
                return;
            }
            if credential != nil {
                Auth.auth().signIn(with: credential!) { authResult, error in
                    self.handleFirebaseAuthDataResult(authResult: authResult, error: error, type: SocialLoginResult.typeTwitter)
                }
            }
        }
    }

    /// Line
    
    func loginLine(command: CDVInvokedUrlCommand, channelId: String) {
        self.command = command;
        let errorResult = SocialLoginResult(type: SocialLoginResult.typeLine, success: false);
        if (channelId.isEmpty) {
            errorResult.errorMessage = "channelId is empty";
            self.loginError(result: errorResult)
            return;
        }
        SwiftLineSdkPlugin.login(channelId: channelId) { r in
            switch r {
                case .success(let value):
                    let result = SocialLoginResult(type: SocialLoginResult.typeLine, success: true);
                    if (value.userProfile != nil) {
                        result.userName = value.userProfile?.displayName;
                        result.userId = value.userProfile?.userID;
                    }
                    result.accessToken = value.accessToken.value;
                    self.loginSuccess(result: result)
                    break;
                case .failure(let error):
                    errorResult.errorMessage = error.localizedDescription;
                    self.loginError(result: errorResult)
                    break;
            }
        }
    }
}


class SocialLoginResult : Codable {
    static let typeGoogle = "Google"
    static let typeApple = "Apple"
    static let typeFacebook = "Facebook"
    static let typeTwitter = "Twitter"
    static let typeLine = "Line"

    var idToken: String?
    var accessToken: String?
    var type: String
    var userId: String?
    var email: String?
    var userName: String?
    var isSuccess: Bool
    var errorMessage: String?
    var isFirebase = true

    init(type: String, success: Bool) {
        self.type = type
        self.isSuccess = success
    }

    func setGoogleAuthResult(authResult: AuthDataResult) {
        let credential: AuthCredential? = authResult.credential;
        
        let oauth: OAuthCredential? = credential as? OAuthCredential;
        self.idToken = oauth?.idToken;
        self.accessToken = oauth?.accessToken;
        let user = authResult.user;
        self.userId = user.uid;
        self.userName = user.displayName;
        self.email = user.email;
    }
    
    func setGoogleAuthResultWithToken(authResult: AuthDataResult, idToken: String?) {
        setGoogleAuthResult(authResult: authResult);
        if (idToken != nil) {
            self.idToken = idToken;
        }
    }
    
    func toJsonString() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted // Optional: For pretty-printed JSON

        do {
            let jsonData = try encoder.encode(self)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                return jsonString
            }
        } catch {
            print("Error converting to JSON: \(error.localizedDescription)")
        }

        return nil
    }
    
    func description() -> String {
        return "SocialLoginResult{" +
               "idToken='\(idToken ?? "")', \n" +
               "accessToken='\(accessToken ?? "")', \n" +
               "type='\(type)', \n" +
               "userId='\(userId ?? "")', \n" +
               "email='\(email ?? "")', \n" +
               "userName='\(userName ?? "")', \n" +
               "isSuccess=\(isSuccess), \n" +
               "isFirebase=\(isFirebase), \n" +
               "errorMessage='\(errorMessage ?? "")'" +
               "}"
    }
}
