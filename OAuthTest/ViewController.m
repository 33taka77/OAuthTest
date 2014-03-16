//
//  ViewController.m
//  OAuthTest
//
//  Created by 相澤 隆志 on 2014/03/15.
//  Copyright (c) 2014年 相澤 隆志. All rights reserved.
//

#import "ViewController.h"
#import "GTMOAuthViewControllerTouch.h"

static NSString *const kHatenaKeychainItemName = @"OAuth Sample: Hatena";
static NSString *const kHatenaServiceName = @"Hatene Bookmark";

@interface ViewController ()
- (IBAction)loginButtonClicked:(id)sender;
- (IBAction)logoutButtonClicked:(id)sender;
- (IBAction)doAPI:(id)sender;

- (GTMOAuthAuthentication *)authForService;
- (void)doAnAuthenticatedAPIFetch;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(incrementNetworkActivity:) name:kGTMOAuthFetchStarted object:nil];
    [nc addObserver:self selector:@selector(decrementNetworkActivity:) name:kGTMOAuthFetchStopped object:nil];
    [nc addObserver:self selector:@selector(signInNetworkLostOrFound:) name:kGTMOAuthNetworkLost  object:nil];
    [nc addObserver:self selector:@selector(signInNetworkLostOrFound:) name:kGTMOAuthNetworkFound object:nil];

    // Get the saved authentication, if any, from the keychain.
    //
    // The view controller supports methods for saving and restoring
    // authentication under arbitrary keychain item names; see the
    // "keychainForName" methods in the interface.  The keychain item
    // names are up to the application, and may reflect multiple accounts for
    // one or more services.
    //
    
    // Perhaps we have a saved authorization for Twitter; try getting
    // that from the keychain
    GTMOAuthAuthentication *auth = [self authForService];
    if (auth) {
        BOOL didAuth = [GTMOAuthViewControllerTouch authorizeFromKeychainForName:kHatenaKeychainItemName
                                                                  authentication:auth];
        if (didAuth) {
            // Select the Twitter index
            //[mServiceSegments setSelectedSegmentIndex:1];
        }
    }
    
    // save the authentication object, which holds the auth tokens
    [self setAuthentication:auth];
    
    //[mShouldSaveInKeychainSwitch setOn:isRemembering];
    [self updateUI];

}

- (void)dealloc {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc removeObserver:self];
}

- (BOOL)isSignedIn {
    BOOL isSignedIn = [mAuth canAuthorize];
    return isSignedIn;
}
- (void)signOut {
    // remove the stored Twitter authentication from the keychain, if any
    [GTMOAuthViewControllerTouch removeParamsFromKeychainForName:kHatenaKeychainItemName];
    
    // Discard our retained authentication object.
    [self setAuthentication:nil];
    
    [self updateUI];
}

- (GTMOAuthAuthentication *)authForService {
    // Note: to use this sample, you need to fill in a valid consumer key and
    // consumer secret provided by Twitter for their API
    //
    // http://twitter.com/apps/
    //
    // The controller requires a URL redirect from the server upon completion,
    // so your application should be registered with Twitter as a "web" app,
    // not a "client" app
    NSString *myConsumerKey = @"J+iAZxiYsaHiuA==";
    NSString *myConsumerSecret = @"Mc8hpkZ7nlV6Ms4dBbeJRzUpaUI=";
    
    if ([myConsumerKey length] == 0 || [myConsumerSecret length] == 0) {
        return nil;
    }
    
    GTMOAuthAuthentication *auth;
    auth = [[GTMOAuthAuthentication alloc] initWithSignatureMethod:kGTMOAuthSignatureMethodHMAC_SHA1
                                                        consumerKey:myConsumerKey
                                                         privateKey:myConsumerSecret];
    
    // setting the service name lets us inspect the auth object later to know
    // what service it is for
    [auth setServiceProvider:kHatenaServiceName];
    
    return auth;
}

- (void)signInToHatena {
    
    [self signOut];
    
    NSURL *requestURL = [NSURL URLWithString:@"https://www.hatena.com/oauth/initiate"];
    NSURL *accessURL = [NSURL URLWithString:@"https://www.hatena.ne.jp/touch/oauth/token"];
    NSURL *authorizeURL = [NSURL URLWithString:@"https://www.hatena.com/oauth/authorize"];
    NSString *scope = @"write_public";
    
    GTMOAuthAuthentication *auth = [self authForService];
    if (auth == nil) {
        // perhaps display something friendlier in the UI?
        NSAssert(NO, @"A valid consumer key and consumer secret are required for signing in to Twitter");
    }
    
    // set the callback URL to which the site should redirect, and for which
    // the OAuth controller should look to determine when sign-in has
    // finished or been canceled
    //
    // This URL does not need to be for an actual web page; it will not be
    // loaded
    [auth setCallback:@"http://www.example.com/OAuthCallback"];
    
    NSString *keychainItemName = nil;
//    if ([self shouldSaveInKeychain]) {
        keychainItemName = kHatenaKeychainItemName;
//    }
    
    // Display the autentication view.
    GTMOAuthViewControllerTouch *viewController;
    viewController = [[GTMOAuthViewControllerTouch alloc] initWithScope:scope
                                                                language:nil
                                                         requestTokenURL:requestURL
                                                       authorizeTokenURL:authorizeURL
                                                          accessTokenURL:accessURL
                                                          authentication:auth
                                                          appServiceName:keychainItemName
                                                                delegate:self
                                                        finishedSelector:@selector(viewController:finishedWithAuth:error:)];
    
    // We can set a URL for deleting the cookies after sign-in so the next time
    // the user signs in, the browser does not assume the user is already signed
    // in
    [viewController setBrowserCookiesURL:[NSURL URLWithString:@"http://api.twitter.com/"]];
    
    // You can set the title of the navigationItem of the controller here, if you want.
    
    [[self navigationController] pushViewController:viewController animated:YES];
}
- (void)viewController:(GTMOAuthViewControllerTouch *)viewController
      finishedWithAuth:(GTMOAuthAuthentication *)auth
                 error:(NSError *)error {
    if (error != nil) {
        // Authentication failed (perhaps the user denied access, or closed the
        // window before granting access)
        NSLog(@"Authentication error: %@", error);
        NSData *responseData = [[error userInfo] objectForKey:@"data"]; // kGTMHTTPFetcherStatusDataKey
        if ([responseData length] > 0) {
            // show the body of the server's authentication failure response
            NSString *str = [[NSString alloc] initWithData:responseData
                                                   encoding:NSUTF8StringEncoding];
            NSLog(@"%@", str);
        }
        
        [self setAuthentication:nil];
    } else {
        // Authentication succeeded
        //
        // At this point, we either use the authentication object to explicitly
        // authorize requests, like
        //
        //   [auth authorizeRequest:myNSURLMutableRequest]
        //
        // or store the authentication object into a GTM service object like
        //
        //   [[self contactService] setAuthorizer:auth];
        
        // save the authentication object
        [self setAuthentication:auth];
        
        // Just to prove we're signed in, we'll attempt an authenticated fetch for the
        // signed-in user
        //[self doAnAuthenticatedAPIFetch];
    }
    
    [self updateUI];
}
- (void)doAnAuthenticatedAPIFetch {
    // Twitter status feed
    NSString *urlStr = @"https://www.hatena.com/oauth/token";
    
    NSURL *url = [NSURL URLWithString:urlStr];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [mAuth authorizeRequest:request];
    
    // Note that for a request with a body, such as a POST or PUT request, the
    // library will include the body data when signing only if the request has
    // the proper content type header:
    //
    //   [request setValue:@"application/x-www-form-urlencoded"
    //  forHTTPHeaderField:@"Content-Type"];
    
    // Synchronous fetches like this are a really bad idea in Cocoa applications
    //
    // For a very easy async alternative, we could use GTMHTTPFetcher
    NSError *error = nil;
    NSURLResponse *response = nil;
    NSData *data = [NSURLConnection sendSynchronousRequest:request
                                         returningResponse:&response
                                                     error:&error];
    if (data) {
        // API fetch succeeded
        NSString *str = [[NSString alloc] initWithData:data
                                               encoding:NSUTF8StringEncoding];
        NSLog(@"API response: %@", str);
    } else {
        // fetch failed
        NSLog(@"API fetch error: %@", error);
    }
}
- (void)incrementNetworkActivity:(NSNotification *)notify {
    ++mNetworkActivityCounter;
    if (1 == mNetworkActivityCounter) {
        UIApplication *app = [UIApplication sharedApplication];
        [app setNetworkActivityIndicatorVisible:YES];
    }
}

- (void)decrementNetworkActivity:(NSNotification *)notify {
    --mNetworkActivityCounter;
    if (0 == mNetworkActivityCounter) {
        UIApplication *app = [UIApplication sharedApplication];
        [app setNetworkActivityIndicatorVisible:NO];
    }
}

- (void)signInNetworkLostOrFound:(NSNotification *)notify {
    if ([[notify name] isEqual:kGTMOAuthNetworkLost]) {
        // network connection was lost; alert the user, or dismiss
        // the sign-in view with
        //   [[[notify object] delegate] cancelSigningIn];
    } else {
        // network connection was found again
    }
}

- (void)updateUI {
    // update the text showing the signed-in state and the button title
    // A real program would use NSLocalizedString() for strings shown to the user.
    if ([self isSignedIn]) {
        // signed in
//        NSString *email = [mAuth userEmail];
//        NSString *token = [mAuth token];
        
//        [mEmailField setText:email];
//        [mTokenField setText:token];
//        [mSignInOutButton setTitle:@"Sign Out"];
    } else {
        // signed out
//        [mEmailField setText:@"Not signed in"];
//        [mTokenField setText:@"No authorization token"];
//        [mSignInOutButton setTitle:@"Sign In..."];
    }
//    BOOL isRemembering = [self shouldSaveInKeychain];
//    [mShouldSaveInKeychainSwitch setOn:isRemembering];
}
- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
- (void)setAuthentication:(GTMOAuthAuthentication *)auth {
    mAuth = auth;
}
- (IBAction)loginButtonClicked:(id)sender
{
    if (![self isSignedIn]) {
        // sign in
        [self signInToHatena];
    } else {
        // sign out
        [self signOut];
    }
    [self updateUI];
    
}
- (IBAction)logoutButtonClicked:(id)sender {
    
}

- (IBAction)doAPI:(id)sender {
    // 認証してなければ、OAuthを開始する。
	if (![self isSignedIn]) {
		[self loginButtonClicked:nil];
		return;
	}
    // はてブを登録するAPIをコールしてみる。
    // 参考URL
    //    http://developer.hatena.ne.jp/ja/documents/bookmark/apis/atom
    
    // 対象URL
    NSURL *url = [NSURL URLWithString:@"http://b.hatena.ne.jp/atom/post"];
    
    // リクエストの作成
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    
    // 2013.03.13 追記
    // 以下のヘッダーを付け忘れてました。
    // 付与しないと、signiture_invalidになる場合があります。
    [request setValue:@"application/x.atom+xml" forHTTPHeaderField:@"Content-Type"];
    
    // 送信データ
    NSString *bodyString
    = [NSString stringWithFormat:@"%@%@%@%@",
       @"<entry xmlns=\"http://purl.org/atom/ns#\"><title>dummy</title>",
       @"<link rel=\"related\" type=\"text/html\" href=\"http://www.yoheim.net/\" />",
       @"<summary type=\"text/plain\">サンプルコメントです</summary>",
       @"</entry>"
       ];
    NSLog(@"xml = %@", bodyString);
    [request setHTTPBody:[bodyString dataUsingEncoding:NSUTF8StringEncoding]];
    // ★★ここがgtm-oauthを使った場合のポイントです！！
    // 認証情報の追加
    // この作業は、HTTPBodyやHTTP Headerなどの付与が終わった最後に行う必要があります。
    // これを行った後にリクエストにデータを追加すると、シグニチャ（署名）不正のエラーがかえってきます。
    [request setHTTPMethod:@"POST"];
    [mAuth authorizeRequest:request];
    
    NSError *error;
    NSURLResponse *response;
    NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    
    NSLog(@"error = %@", error);
    NSLog(@"statusCode = %d", ((NSHTTPURLResponse *)response).statusCode);
    NSLog(@"responseText = %@", [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding]);
    
    
    // 認証できていない場合には、認証を始めるように実装してみる。
    if (error && error.code == kCFURLErrorUserCancelledAuthentication) {
        NSLog(@"未認証っぽいよー。認証を始めます。");
        [self loginButtonClicked:nil];
    }


}
@end
