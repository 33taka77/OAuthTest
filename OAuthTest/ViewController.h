//
//  ViewController.h
//  OAuthTest
//
//  Created by 相澤 隆志 on 2014/03/15.
//  Copyright (c) 2014年 相澤 隆志. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "GTMOAuthViewControllerTouch.h"

@interface ViewController : UIViewController
{
    GTMOAuthAuthentication *mAuth;
    int mNetworkActivityCounter;

}

- (void)updateUI;

- (void)setAuthentication:(GTMOAuthAuthentication *)auth;
- (void)signInToHatena;
- (void)signOut;
- (BOOL)isSignedIn;

@end
