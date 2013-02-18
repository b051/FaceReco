//
//  FRAppDelegate.m
//  FaceReco
//
//  Created by Rex Sheng on 2/18/13.
//  Copyright (c) 2013 lognllc.com. All rights reserved.
//

#import "FRAppDelegate.h"
#import "FRAssetsGroupViewController.h"

@implementation FRAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    // Override point for customization after application launch.
    self.window.backgroundColor = [UIColor whiteColor];
	UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:[[FRAssetsGroupViewController alloc] init]];
	nav.navigationBar.translucent = YES;

	self.window.rootViewController = nav;
    [self.window makeKeyAndVisible];
    return YES;
}

@end
