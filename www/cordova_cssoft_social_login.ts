declare const cordova: any;

export class CordovaSocialLogin {

    static loginApple(success: (data: SocialLoginResult) => any, fail: (err: SocialLoginResult) => any) {
        var json = {};
        cordova.exec((result: any) => {
                success(CordovaSocialLogin.parseLoginResult(result));
            }, (error: any) => {
                fail(CordovaSocialLogin.parseLoginResult(error));
            }, 'cordova_cssoft_social_login', 'login_apple', [JSON.stringify(json)]);
    };

    static loginGoogle(success: (data: SocialLoginResult) => any, fail: (err: SocialLoginResult) => any) {
        var json = {
            // https://developers.google.com/identity/sign-in/android/start-integrating
            // Must use Web application type client ID
            serverClientId: "950162958461-i4rd262gnuna5qsu6tonnftchtk5oc7m.apps.googleusercontent.com",
        };
        cordova.exec((result: any) => {
                success(CordovaSocialLogin.parseLoginResult(result));
            }, (error: any) => {
                fail(CordovaSocialLogin.parseLoginResult(error));
            }, 'cordova_cssoft_social_login', 'login_google', [JSON.stringify(json)]);
    };

    static loginFacebook(success: (data: SocialLoginResult) => any, fail: (err: SocialLoginResult) => any) {
        var json = {
        };
        cordova.exec((result: any) => {
                success(CordovaSocialLogin.parseLoginResult(result));
            }, (error: any) => {
                fail(CordovaSocialLogin.parseLoginResult(error));
            }, 'cordova_cssoft_social_login', 'login_facebook', [JSON.stringify(json)]);
    };

    static loginTwitter(success: (data: SocialLoginResult) => any, fail: (err: SocialLoginResult) => any) {
        var json = {
        };
        cordova.exec((result: any) => {
                success(CordovaSocialLogin.parseLoginResult(result));
            }, (error: any) => {
                fail(CordovaSocialLogin.parseLoginResult(error));
            }, 'cordova_cssoft_social_login', 'login_twitter', [JSON.stringify(json)]);
    };

    static loginLine(success: (data: SocialLoginResult) => any, fail: (err: SocialLoginResult) => any) {
        var json = {
            channelId: "2000281205",
        };
        cordova.exec((result: any) => {
                success(CordovaSocialLogin.parseLoginResult(result));
            }, (error: any) => {
                fail(CordovaSocialLogin.parseLoginResult(error));
            }, 'cordova_cssoft_social_login', 'login_line', [JSON.stringify(json)]);
    };

    static parseLoginResult(jsonString: string): SocialLoginResult {
        try {
            const json = JSON.parse(jsonString);
            const loginResult = new SocialLoginResult();
            Object.assign(loginResult, json);
            
            return loginResult;
        } catch (error) {
            console.error("Error parseLoginResult: ", jsonString);
            const ret = new SocialLoginResult();
            ret.isSuccess = false;
            ret.errorMessage = error.toString();
            return ret;
        }
    }
}

export class SocialLoginResult {
    public static typeGoogle: string = "Google";
    public static typeApple: string = "Apple";
    public static typeFacebook: string = "Facebook";
    public static typeTwitter: string = "Twitter";
    public static typeLine: string = "Line";

    public idToken: string;
    public accessToken: string;
    public type: string;
    public userId: string;
    public email: string;
    public userName: string;
    public isSuccess: boolean;
    public errorMessage: string;

    public isFirebase: boolean = true;

    public toString(): string {
        return `SocialLoginResult{
            idToken='${this.idToken}',
            accessToken='${this.accessToken}',
            type='${this.type}',
            userId='${this.userId}',
            email='${this.email}',
            userName='${this.userName}',
            isSuccess=${this.isSuccess},
            isFirebase=${this.isFirebase},
            errorMessage='${this.errorMessage}'
        }`;
    }
}