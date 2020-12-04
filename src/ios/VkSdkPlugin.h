//
//  VkSdkPlugin.h

#import <Cordova/CDV.h>
#import <VKSdkFramework/VKSdk.h>

@interface VkSdkPlugin : CDVPlugin <VKSdkDelegate>
{
    NSString*     clientId;
}

@property (nonatomic, retain) NSString*     clientId;

- (void)initVkSdk:(CDVInvokedUrlCommand*)command;
- (void)loginVkSdk:(CDVInvokedUrlCommand*)command;
- (void)logout:(CDVInvokedUrlCommand*)command;
- (void)getUser:(CDVInvokedUrlCommand*)command;


@end
