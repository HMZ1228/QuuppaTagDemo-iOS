//
//  AppDelegate.m
//  QuuppaTagDemo
//
//  Updated for modern iOS (iOS 13+)
//  Original created by Quuppa on 05/02/15.
//  Copyright (c) 2015 Quuppa. All rights reserved.
//
//  Changes from original:
//  - Added application:configurationForConnectingSceneSession: for iOS 13+ Scene lifecycle
//  - Added application:didDiscardSceneSessions: for iOS 13+ Scene lifecycle
//  - Legacy UIApplicationDelegate lifecycle methods kept for iOS 12 compatibility
//

#import "AppDelegate.h"

@interface AppDelegate ()
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    return YES;
}


#pragma mark - UISceneSession Lifecycle (iOS 13+)

- (UISceneConfiguration *)application:(UIApplication *)application
configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession
                               options:(UISceneConnectionOptions *)options
    API_AVAILABLE(ios(13.0)) {
    // Return the named scene configuration from Info.plist
    return [[UISceneConfiguration alloc] initWithName:@"Default Configuration"
                                          sessionRole:connectingSceneSession.role];
}

- (void)application:(UIApplication *)application
didDiscardSceneSessions:(NSSet<UISceneSession *> *)sceneSessions
    API_AVAILABLE(ios(13.0)) {
    // Release resources specific to discarded scenes
}


#pragma mark - Legacy App Lifecycle (iOS 12 and below)

- (void)applicationWillResignActive:(UIApplication *)application {
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
}

- (void)applicationWillTerminate:(UIApplication *)application {
}

@end
