package cordova_cssoft_social_login;

import android.app.Activity;
import android.content.Intent;
import android.util.Log;

import androidx.annotation.NonNull;

import com.facebook.AccessToken;
import com.facebook.CallbackManager;
import com.facebook.FacebookCallback;
import com.facebook.FacebookException;
import com.facebook.login.LoginManager;
import com.facebook.login.LoginResult;
import com.google.android.gms.auth.api.signin.GoogleSignIn;
import com.google.android.gms.auth.api.signin.GoogleSignInAccount;
import com.google.android.gms.auth.api.signin.GoogleSignInClient;
import com.google.android.gms.auth.api.signin.GoogleSignInOptions;
import com.google.android.gms.common.api.ApiException;
import com.google.android.gms.tasks.OnCompleteListener;
import com.google.android.gms.tasks.OnFailureListener;
import com.google.android.gms.tasks.OnSuccessListener;
import com.google.android.gms.tasks.Task;
import com.google.firebase.auth.AuthCredential;
import com.google.firebase.auth.AuthResult;
import com.google.firebase.auth.FacebookAuthProvider;
import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.auth.FirebaseUser;
import com.google.firebase.auth.GetTokenResult;
import com.google.firebase.auth.GoogleAuthProvider;
import com.google.firebase.auth.OAuthCredential;
import com.google.firebase.auth.OAuthProvider;
import com.google.gson.Gson;
import com.linecorp.linesdk.LineIdToken;
import com.linecorp.linesdk.LineProfile;
import com.linecorp.linesdk.Scope;
import com.linecorp.linesdk.api.LineApiClient;
import com.linecorp.linesdk.api.LineApiClientBuilder;
import com.linecorp.linesdk.auth.LineAuthenticationParams;
import com.linecorp.linesdk.auth.LineLoginApi;
import com.linecorp.linesdk.auth.LineLoginResult;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaPlugin;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.Arrays;
import java.util.ArrayList;
import java.util.Collections;

/**
 * This class echoes a string called from JavaScript.
 */
public class CdvCsSoftSocialLogin extends CordovaPlugin {
    FirebaseSocialLogin firebaseLogin;

    void init() {
        if (firebaseLogin == null) {
            firebaseLogin = new FirebaseSocialLogin(this);
        }
    }

    @Override
    public boolean execute(String action, JSONArray args, CallbackContext callbackContext) throws JSONException {
        init();
        String jsonStr = args.length() > 0 ? args.getString(0) : null;
        JSONObject json = jsonStr == null ? new JSONObject() : new JSONObject(jsonStr);
        if (action.equals("login_google")) {
            firebaseLogin.googleLogin(callbackContext, json.getString("serverClientId"));
            return true;
        }
        if (action.equals("login_facebook")) {
            firebaseLogin.facebookLogin(callbackContext);
            return true;
        }
        if (action.equals("login_twitter")) {
            firebaseLogin.loginTwitter(callbackContext);
            return true;
        }
        if (action.equals("login_line")) {
            firebaseLogin.loginLine(callbackContext, json.getString("channelId"));
            return true;
        }
        if (action.equals("login_apple")) {
            firebaseLogin.loginApple(callbackContext);
            return true;
        }
        callbackContext.error("Not Implemented");
        return false;
    }

    @Override
    public void onActivityResult(int requestCode, int resultCode, Intent intent) {
        firebaseLogin.onActivityResult(requestCode, resultCode, intent);
        super.onActivityResult(requestCode, resultCode, intent);
    }

    public class FirebaseSocialLogin {
        String TAG = "FirebaseSocialLogin";
        CordovaPlugin plugin;
        LoginManager fbLoginManager;
        CallbackManager fbCallbackManager;
        FirebaseAuth firebaseAuth;
        OAuthProvider.Builder twitterProvider;
        LineLogin lineLoginSdk = new LineLogin();
        GoogleSignInClient googleSignInClient;
        CallbackContext callbackContext;

        private static final int requestCodeGoogle = 9001;
        Gson gson = new Gson();

        // Google
        public void googleLogin(CallbackContext callback, String serverClientId) {
            this.callbackContext = callback;
            prepareActivityResultCallback();
            signOutFirebase();
            GoogleSignInOptions gso = new GoogleSignInOptions.Builder(GoogleSignInOptions.DEFAULT_SIGN_IN)
                    // https://developers.google.com/identity/sign-in/android/start-integrating
                    // "533504721823-fb2j6mo7mnqiv8rl32gglvj3u7pe70kh.apps.googleusercontent.com"
                    .requestIdToken(serverClientId)
                    .build();
            googleSignInClient = GoogleSignIn.getClient(cordova.getActivity(), gso);
            googleSignInClient.signOut();
            Intent signInIntent = googleSignInClient.getSignInIntent();
            cordova.getActivity().startActivityForResult(signInIntent, requestCodeGoogle);
        }

        // Apple
        public void loginApple(CallbackContext callback) {
            this.callbackContext = callback;
            prepareActivityResultCallback();
            signOutFirebase();
            OAuthProvider.Builder provider = OAuthProvider.newBuilder("apple.com");
            SocialLoginResult result = new SocialLoginResult(SocialLoginResult.typeApple, true);
            firebaseAuth.startActivityForSignInWithProvider(cordova.getActivity(), provider.build())
                    .addOnSuccessListener(
                            new OnSuccessListener<AuthResult>() {
                                @Override
                                public void onSuccess(AuthResult authResult) {
                                    // Sign-in successful!
                                    handleAuthResult(authResult, SocialLoginResult.typeApple);
                                }
                            })
                    .addOnFailureListener(
                            new OnFailureListener() {
                                @Override
                                public void onFailure(@NonNull Exception e) {
                                    result.isSuccess = false;
                                    result.errorMessage = e.getMessage();
                                    loginError(result);
                                }
                            });
        }

        // Facebook
        public void facebookLogin(CallbackContext callback) {
            if (fbLoginManager == null) {
                fbLoginManager = LoginManager.getInstance();
                fbCallbackManager = CallbackManager.Factory.create();
                SocialLoginResult result = new SocialLoginResult(SocialLoginResult.typeFacebook, true);
                fbLoginManager.registerCallback(fbCallbackManager, new FacebookCallback<LoginResult>() {
                    @Override
                    public void onSuccess(LoginResult loginResult) {
                        handleFacebookAccessToken(loginResult.getAccessToken());
                    }

                    @Override
                    public void onError(@NonNull FacebookException error) {
                        result.isSuccess = false;
                        result.errorMessage = error.getMessage();
                        loginError(result);
                    }

                    @Override
                    public void onCancel() {
                        result.isSuccess = false;
                        result.errorMessage = "User cancel";
                        loginError(result);
                    }
                });
            }
            this.callbackContext = callback;
            prepareActivityResultCallback();
            signOutFirebase();
            final boolean hasPreviousSession = AccessToken.getCurrentAccessToken() != null;
            if (hasPreviousSession) {
                if (AccessToken.isCurrentAccessTokenActive()) {
                    AccessToken.expireCurrentAccessToken();
                }
                fbLoginManager.logOut();
            }
            fbLoginManager.logIn(cordova.getActivity(), Arrays.asList("public_profile", "email"));
        }

        // Twitter
        void loginTwitter(CallbackContext callback) {
            if (twitterProvider == null) {
                twitterProvider = OAuthProvider.newBuilder("twitter.com");
            }
            this.callbackContext = callback;
            prepareActivityResultCallback();
            signOutFirebase();
            firebaseAuth.startActivityForSignInWithProvider(cordova.getActivity(), twitterProvider.build())
                    .addOnSuccessListener(
                            new OnSuccessListener<AuthResult>() {
                                @Override
                                public void onSuccess(AuthResult authResult) {
                                    handleAuthResult(authResult, SocialLoginResult.typeTwitter);
                                }
                            })
                    .addOnFailureListener(
                            new OnFailureListener() {
                                @Override
                                public void onFailure(@NonNull Exception e) {
                                    SocialLoginResult result = new SocialLoginResult(SocialLoginResult.typeTwitter, false);
                                    result.errorMessage = e.getMessage();
                                    loginError(result);
                                }
                            });
        }

        /// Line
        void loginLine(CallbackContext callback, String channelId) {
            this.callbackContext = callback;
            prepareActivityResultCallback();
            lineLoginSdk.loginLine(cordova.getActivity(), channelId);
        }

        void loginSuccess(SocialLoginResult result) {
            Log.i(TAG, "Social login success: " + result.toString());
            if (callbackContext != null) {
                callbackContext.success(gson.toJson(result));
            }
            callbackContext = null;
        }

        void loginError(SocialLoginResult result) {
            Log.e(TAG, "Social login error: " + result.toString());
            if (callbackContext != null) {
                callbackContext.error(gson.toJson(result));
            }
            callbackContext = null;
        }

        public void onActivityResult(int requestCode, int resultCode, Intent data) {
            if (requestCode == requestCodeGoogle) {
                try {
                    Task<GoogleSignInAccount> task = GoogleSignIn.getSignedInAccountFromIntent(data);
                    GoogleSignInAccount account = task.getResult(ApiException.class);
                    firebaseAuthWithGoogle(account);
                } catch (Exception e) {
                    SocialLoginResult result = new SocialLoginResult(SocialLoginResult.typeGoogle, false);
                    result.errorMessage = e.getMessage();
                    loginError(result);
                }
            }
            if (fbCallbackManager != null) {
                fbCallbackManager.onActivityResult(requestCode, resultCode, data);
            }
            if (lineLoginSdk != null) {
                LineLoginResult lineResult = lineLoginSdk.onActivityResult(requestCode, resultCode, data);
                if (lineResult != null) {
                    SocialLoginResult result = new SocialLoginResult(SocialLoginResult.typeLine, true);
                    result.isFirebase = false;
                    switch (lineResult.getResponseCode()) {
                        case SUCCESS:
                            LineProfile profile = lineResult.getLineProfile();
                            if (profile != null) {
                                result.userName = profile.getDisplayName();
                                result.userId = profile.getUserId();
                            }
                            if (lineResult.getLineIdToken() != null) {
                                LineIdToken idToken = lineResult.getLineIdToken();
                                result.email = idToken.getEmail();
                                result.userName = idToken.getName();
                            }
                            if (lineResult.getLineCredential() != null) {
                                result.accessToken = lineResult.getLineCredential().getAccessToken().getTokenString();
                            }
                            loginSuccess(result);
                            break;
                        default:
                            result.isSuccess = false;
                            if (lineResult.getErrorData() != null) {
                                result.errorMessage = lineResult.getErrorData().getMessage();
                            }
                            loginError(result);
                            break;
                    }
                }
            }
        }

        FirebaseSocialLogin(CordovaPlugin plugin) {
            this.plugin = plugin;
            firebaseAuth = FirebaseAuth.getInstance();
        }

        private void handleFacebookAccessToken(AccessToken token) {
            AuthCredential credential = FacebookAuthProvider.getCredential(token.getToken());
            firebaseAuth.signInWithCredential(credential)
                    .addOnCompleteListener(cordova.getActivity(), new OnCompleteListener<AuthResult>() {
                        @Override
                        public void onComplete(@NonNull Task<AuthResult> task) {
                            handleAuthResultTask(task, SocialLoginResult.typeFacebook);
                        }
                    });
        }

        void prepareActivityResultCallback() {
            cordova.setActivityResultCallback(plugin);
        }

        void signOutFirebase() {
            if (firebaseAuth.getCurrentUser() != null) {
                firebaseAuth.signOut();
            }
        }

        private void firebaseAuthWithGoogle(GoogleSignInAccount acct) {
            AuthCredential credential = GoogleAuthProvider.getCredential(acct.getIdToken(), null);
            firebaseAuth.signInWithCredential(credential)
                    .addOnCompleteListener(cordova.getActivity(), new OnCompleteListener<AuthResult>() {
                        @Override
                        public void onComplete(@NonNull Task<AuthResult> task) {
                            handleAuthResultTask(task, SocialLoginResult.typeGoogle);
                        }
                    });
        }

        private void handleAuthResultTask(Task<AuthResult> task, String loginType) {
            if (task.isSuccessful()) {
                AuthResult authResult = task.getResult();
                handleAuthResult(authResult, loginType);
            } else {
                SocialLoginResult result = new SocialLoginResult(loginType, false);
                if (task.getException() != null) {
                    result.errorMessage = task.getException().toString();
                }
                loginError(result);
            }
        }

        private void handleAuthResult(AuthResult authResult, String loginType) {
            AuthCredential credential = authResult.getCredential();
            OAuthCredential oauth = ((OAuthCredential) credential);
            String idToken = oauth.getIdToken();
            FirebaseUser user = authResult.getUser();
            SocialLoginResult result = new SocialLoginResult(loginType, true);
            if (idToken == null && user != null) {
                user.getIdToken(true).addOnCompleteListener(new OnCompleteListener<GetTokenResult>() {
                                                                @Override
                                                                public void onComplete(@NonNull Task<GetTokenResult> tokenTask) {
                                                                    String token = null;
                                                                    if (tokenTask.isSuccessful()) {
                                                                        token = tokenTask.getResult().getToken();
                                                                    }
                                                                    result.setGoogleAuthResultWithToken(authResult, token);
                                                                    loginSuccess(result);
                                                                }
                                                            }
                );
            } else {
                result.setGoogleAuthResult(authResult);
                loginSuccess(result);
            }
        }
    }

    public static class LineLogin {

        static final int loginRequestCode = 9950;
        LineApiClient lineApiClient;
        String channelId;

        private void setup(Activity activity, String channelId) {
            lineApiClient = new LineApiClientBuilder(activity, channelId).build();
            this.channelId = channelId;
        }

        void loginLine(
                Activity activity,
                String channelId
        ) {
            setup(activity, channelId);
            LineAuthenticationParams lineAuthenticationParams = new LineAuthenticationParams.Builder()
                    .scopes(Scope.convertToScopeList(Collections.singletonList("profile")))
                    .botPrompt(LineAuthenticationParams.BotPrompt.valueOf("normal"))
                    .build();
            Intent loginIntent = LineLoginApi.getLoginIntent(activity, channelId, lineAuthenticationParams);
            activity.startActivityForResult(loginIntent, loginRequestCode);
        }

        public LineLoginResult onActivityResult(int requestCode, int resultCode, Intent intent) {
            if (requestCode != loginRequestCode)
                return null;

            if (resultCode != Activity.RESULT_OK || intent == null) {
                return null;
            }

            return LineLoginApi.getLoginResultFromIntent(intent);
        }
    }

    public static class SocialLoginResult {
        public static String typeGoogle = "Google";
        public static String typeApple = "Apple";
        public static String typeFacebook = "Facebook";
        public static String typeTwitter = "Twitter";
        public static String typeLine = "Line";

        // https://www.googleapis.com/oauth2/v3/tokeninfo?id_token=
        public String idToken;
        public String accessToken;
        public String type;
        public String userId;
        public String email;
        public String userName;
        public boolean isSuccess;
        public String errorMessage;

        public boolean isFirebase = true;

        public SocialLoginResult(String type, boolean success) {
            this.type = type;
            this.isSuccess = success;
        }

        void setGoogleAuthResult(AuthResult authResult) {
            AuthCredential credential = authResult.getCredential();
            OAuthCredential oauth = ((OAuthCredential) credential);
            this.idToken = oauth.getIdToken();
            this.accessToken = oauth.getAccessToken();
            FirebaseUser user = authResult.getUser();
            this.userId = user.getUid();
            this.userName = user.getDisplayName();
            this.email = user.getEmail();;
        }

        void setGoogleAuthResultWithToken(AuthResult authResult, String idToken) {
            setGoogleAuthResult(authResult);
            if (idToken != null) {
                this.idToken = idToken;
            }
        }

        @Override
        public String toString() {
            return "SocialLoginResult{" +
                    "token='" + idToken + '\'' +
                    ", type='" + type + '\'' +
                    ", userId='" + userId + '\'' +
                    ", email='" + email + '\'' +
                    ", userName='" + userName + '\'' +
                    ", isSuccess=" + isSuccess +
                    ", isFirebase=" + isFirebase +
                    ", errorMessage='" + errorMessage + '\'' +
                    '}';
        }
    }
}
