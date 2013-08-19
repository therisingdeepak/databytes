//
//  SMAppDelegate.h
//  Feed Reader
//
//  Created by Eric Johnsen on 11/23/12.
//  Copyright (c) 2012 Eric S. Johnsen. All rights reserved.
//

#import <UIKit/UIKit.h>

@class SMRootViewController;

@interface SMAppDelegate : NSObject <UIApplicationDelegate, UINavigationControllerDelegate> {
    
    NSManagedObjectModel *managedObjectModel;
    NSManagedObjectContext *managedObjectContext;
    NSPersistentStoreCoordinator *persistentStoreCoordinator;
}

@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) UINavigationController *navigationController;
@property (strong, nonatomic) SMRootViewController *rootViewController;

@property (strong, nonatomic, readonly) NSManagedObjectModel *managedObjectModel;
@property (strong, nonatomic, readonly) NSManagedObjectContext *managedObjectContext;
@property (strong, nonatomic, readonly) NSPersistentStoreCoordinator *persistentStoreCoordinator;


- (void)fetchData;

@end