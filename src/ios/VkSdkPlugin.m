//
//  VkSdkPlugin.m

#import "VkSdkPlugin.h"
#import <VKSdkFramework/VKBundle.h>

@implementation VkSdkPlugin {
    NSString * pluginCallbackId;
    CDVInvokedUrlCommand *savedCommand;
    void (^vkCallBackBlock)(NSString *, NSString *, NSString *);
    BOOL inited;
    NSMutableDictionary *loginDetails;
}

@synthesize clientId;

- (void) initVkSdk:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;
    
    if (pluginCallbackId == nil) {
        NSString *appId = [[NSString alloc] initWithString:[command.arguments objectAtIndex:0]];
        sdkInstance = [VKSdk initializeWithAppId:appId];
        [sdkInstance registerDelegate:self];
        [sdkInstance setUiDelegate:self];
        
        NSLog(@"VkSdkPlugin Plugin initalized");
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(myOpenUrl:) name:CDVPluginHandleOpenURLNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(myOpenUrl:) name:CDVPluginHandleOpenURLWithAppSourceAndAnnotationNotification object:nil];

        
        NSDictionary *errorObject = @{
            @"eventType" : @"initialized",
            @"eventData" : @"success"
        };
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:errorObject];
        pluginCallbackId = command.callbackId;
        
        [VKSdk wakeUpSession:@[@"email"] completeBlock:^(VKAuthorizationState state, NSError *error) {
            if (state == VKAuthorizationAuthorized) {
                NSLog(@"VkSdkPlugin Plugin Wake UP OK");
            } else if (error) {
                // Some error happened, but you may try later
            }
        }];
    } else {
        NSDictionary *errorObject = @{
            @"code" : @"initError",
            @"message" : @"Plugin was already initialized"
        };
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:errorObject];
    }
    
    pluginResult.keepCallback = [NSNumber numberWithBool:true];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) loginVkSdk:(CDVInvokedUrlCommand*)command
{
    NSArray *permissions = [command.arguments objectAtIndex:0];
    [self vkLoginWithBlock:permissions block:^(NSString *token, NSString *userId, NSString *expiresIn) {
        CDVPluginResult* pluginResult = nil;
        if(token) {
            NSLog(@"Acquired new VK token");
            NSDictionary *result = @{
                @"eventType" : @"newToken",
                @"eventData" : @{
                    @"accessToken" : token,
                    @"userId" : userId,
                    @"expiresIn": expiresIn,
                    @"secret": @""
                }
            };
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:result];
            
        } else {
            NSLog(@"Cant login to VKontakte");
            NSDictionary *errorObject = @{
                @"code" : @"loginError",
                @"message" : @"Cant login to VKontakte"
            };
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:errorObject];
        }
        pluginResult.keepCallback = [NSNumber numberWithBool:true];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:self->pluginCallbackId];
    }];

}

-(UIViewController*)findViewController
{
    id vc = self.webView;
    do {
        vc = [vc nextResponder];
    } while([vc isKindOfClass:UIView.class]);
    return vc;
}

-(void)myOpenUrl:(NSNotification*)notification
{
    NSURL *url;
    
    if ([notification.object isKindOfClass:NSDictionary.class]) {
        if ([[notification.object valueForKey:@"url"] isKindOfClass:NSURL.class]) {
            url = [notification.object valueForKey:@"url"];
        } else {
            return;
        }
    } else if ([notification.object isKindOfClass:NSURL.class]) {
        url = notification.object;
    } else {
        return;
    }
    
    BOOL wasHandled = [VKSdk processOpenURL:url fromApplication:nil];
    if (!wasHandled) {
        NSLog(@"Error handling token URL");
    }
}

-(void)vkLoginWithBlock:(NSArray *)permissions block:(void (^)(NSString *, NSString *, NSString *))block
{
    vkCallBackBlock = [block copy];
    [VKSdk authorize: permissions];
}

-(void)logout:(CDVInvokedUrlCommand *)command
{
    [VKSdk forceLogout];
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)getUser:(CDVInvokedUrlCommand*)command;
{
    NSDictionary *reqParams = @{
        VK_API_USER_ID: [[NSString alloc] initWithString:[command.arguments objectAtIndex:0]],
        VK_API_FIELDS: @"id, first_name, sex, bdate"
    };
    VKRequest * userGetReq = [[VKApi users] get:reqParams];
    [userGetReq executeWithResultBlock:^(VKResponse * response) {
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:response.json];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        NSLog(@"Json result: %@", response.json);
    } errorBlock:^(NSError * error) {
        if (error.code != VK_API_ERROR) {
            [error.vkError.request repeat];
        } else {
            NSLog(@"VK error: %@", error);
            NSDictionary *errorObject = @{
                @"code" : @"loginError",
                @"message" : @"Cant get user",
                @"details": error.domain
            };
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:errorObject];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        } 
    }];
}

#pragma mark - VKSdkDelegate

/**
 Notifies about authorization was completed, and returns authorization result with new token or error.
 
 @param result contains new token or error, retrieved after VK authorization.
 */
- (void)vkSdkAccessAuthorizationFinishedWithResult:(VKAuthorizationResult *)result {
    if (result.state == VKAuthorizationAuthorized) {
        if(vkCallBackBlock) vkCallBackBlock(result.token.accessToken, result.token.userId, @"");
    }
}

/**
 Notifies about access error. For example, this may occurs when user rejected app permissions through VK.com
 */
- (void)vkSdkUserAuthorizationFailed {
    if(vkCallBackBlock) vkCallBackBlock(nil, nil, nil);
}

/**
 Notifies about authorization state was changed, and returns authorization result with new token or error.
 
 If authorization was successfull, also contains user info.
 
 @param result contains new token or error, retrieved after VK authorization
 */
- (void)vkSdkAuthorizationStateUpdatedWithResult:(VKAuthorizationResult *)result {
    if (result.state == VKAuthorizationAuthorized) {
        if(vkCallBackBlock) vkCallBackBlock(result.token.accessToken, result.token.userId, @"");
    }
}

/**
 Notifies about existing token has expired (by timeout). This may occurs if you requested token without no_https scope.
 
 @param expiredToken old token that has expired.
 */
- (void)vkSdkTokenHasExpired:(VKAccessToken *)expiredToken {
    NSLog(@"VK Token Expired: %@", expiredToken.accessToken);
}

#pragma mark - VKSDKUIDelegate

-(void) vkSdkShouldPresentViewController:(UIViewController *)controller
{
    [[self findViewController] presentViewController:controller animated:YES completion:nil];
}

- (void)vkSdkDidDismissViewController:(UIViewController *)controller {
    NSLog(@"Error!");
}

- (void)vkSdkNeedCaptchaEnter:(VKError *)captchaError {
    NSLog(@"Captcha Error: %@", captchaError);
}


@end
