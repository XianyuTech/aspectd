#include "AppDelegate.h"
#include "GeneratedPluginRegistrant.h"
#import <GrowingAnalytics-cdp/GrowingAutotracker.h>

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    GrowingAutotrackConfiguration *configuration = [GrowingAutotrackConfiguration configurationWithProjectId:@"91eaf9b283361032"];
    configuration.debugEnabled = YES;
    configuration.dataSourceId = @"a6aa2345f7ce14ce";
    // configuration.dataCollectionServerHost = @"http://cdp.growingio.com";
    configuration.dataCollectionServerHost = @"https://run.mocky.io/v3/08999138-a180-431d-a136-051f3c6bd306";
    [GrowingAutotracker startWithConfiguration:configuration launchOptions:launchOptions];
    FlutterViewController *controller = (FlutterViewController*)self.window.rootViewController;
    FlutterMethodChannel* testChannel = [FlutterMethodChannel methodChannelWithName:@"samples.flutter.dev/goToNativePage" binaryMessenger:controller.binaryMessenger];
    
    [testChannel setMethodCallHandler:^(FlutterMethodCall* call, FlutterResult result) {
        
        NSLog(@"%@", call.method);
        //接收从flutter传递过来的参数
        NSLog(@"%@", call.arguments[@"test"]);
        if ([@"goToNativePage" isEqualToString:call.method]) {
            //实现跳转的代码
            NSString * storyboardName = @"Main";
            UIStoryboard *storyboard = [UIStoryboard storyboardWithName:storyboardName bundle: nil];
            UIViewController * vc = [storyboard instantiateViewControllerWithIdentifier:@"NativeViewController"];
            vc.navigationItem.title = call.arguments[@"test"];
            UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:vc];
            navigationController.modalPresentationStyle = UIModalPresentationFullScreen;
            [controller presentViewController:navigationController animated:true completion:nil];
        } else {
            result(FlutterMethodNotImplemented);
        }
    }];
    
    [GeneratedPluginRegistrant registerWithRegistry:self];
  // Override point for customization after application launch.
  return [super application:application didFinishLaunchingWithOptions:launchOptions];
}

@end
