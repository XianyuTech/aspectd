#include "AppDelegate.h"
#include "GeneratedPluginRegistrant.h"
#import <GrowingAnalytics/GrowingAutotracker.h>

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    GrowingAutotrackConfiguration *configuration = [GrowingTrackConfiguration configurationWithProjectId:@"0a1b4118dd954ec3bcc69da5138bdb96"];
    configuration.debugEnabled = YES;
    configuration.dataCollectionServerHost = @"https://run.mocky.io/v3/08999138-a180-431d-a136-051f3c6bd306";
    [GrowingAutotracker startWithConfiguration:configuration launchOptions:launchOptions];
    [GeneratedPluginRegistrant registerWithRegistry:self];
  // Override point for customization after application launch.
  return [super application:application didFinishLaunchingWithOptions:launchOptions];
}

@end
