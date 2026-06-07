//
//  SceneDelegate.m
//  QuuppaTagDemo
//
//  Created for modern iOS (iOS 13+)
//  Copyright (c) 2015 Quuppa. All rights reserved.
//
//  Handles the window/scene lifecycle introduced in iOS 13.
//  The app's UI is set up here rather than in AppDelegate on iOS 13+.
//

#import "SceneDelegate.h"

API_AVAILABLE(ios(13.0))
@implementation SceneDelegate

- (void)scene:(UIScene *)scene
willConnectToSession:(UISceneSession *)session
      options:(UISceneConnectionOptions *)connectionOptions {
    // If using a Storyboard, UIKit automatically creates the window and root view controller.
    // No additional setup needed here unless constructing the UI programmatically.
}

- (void)sceneDidDisconnect:(UIScene *)scene {
    // Called when the scene has been disconnected from the app.
    // The scene may reconnect later — release resources that can be recreated.
}

- (void)sceneDidBecomeActive:(UIScene *)scene {
    // Called when the scene moves from an inactive to active state.
}

- (void)sceneWillResignActive:(UIScene *)scene {
    // Called when the scene will move from an active to inactive state.
    // May occur due to temporary interruptions (e.g., incoming call).
}

- (void)sceneWillEnterForeground:(UIScene *)scene {
    // Called as the scene transitions from background to foreground.
}

- (void)sceneDidEnterBackground:(UIScene *)scene {
    // Called as the scene transitions from foreground to background.
    // Save data, release shared resources, store enough scene-specific state
    // information to restore the scene back to its current state.
}

@end
