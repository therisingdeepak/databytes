//
//  SMAppDelegate.m
//  Feed Reader
//
//  Created by Eric Johnsen on 11/23/12.
//  Copyright (c) 2012 Eric S. Johnsen. All rights reserved.
//

#import "SMAppDelegate.h"
#import "SMRootViewController.h"
#import "SMParseFeedOperation.h"

//#define FEED_URL @"http://feeds2.feedburner.com/TheTechnologyEdge"
#define FEED_URL @"http://deepakdhakal.com/ddc/feeddc.xml"

@interface SMAppDelegate ()

@property (strong, nonatomic) NSURLConnection  *feedConnection;
@property (strong, nonatomic) NSMutableData    *feedData;
@property (strong, nonatomic) NSOperationQueue *parseQueue;

@end

@implementation SMAppDelegate

@synthesize window;
@synthesize navigationController;
@synthesize rootViewController;
@synthesize feedConnection;
@synthesize feedData;
@synthesize parseQueue;

#pragma mark -
#pragma mark Application lifecycle

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.rootViewController = [[SMRootViewController alloc] initWithStyle:UITableViewStylePlain];
    self.rootViewController.managedObjectContext = self.managedObjectContext;    
    
    self.navigationController = [[UINavigationController alloc] initWithRootViewController:self.rootViewController];  
    self.navigationController.navigationBar.barStyle = UIBarStyleBlack;
    self.navigationController.title = @"Data.com: Data Byte";
    
    [self.window setRootViewController:self.navigationController];
    [self.window makeKeyAndVisible];
    
    // Asynchronously download the feed data. We're not blocking the main thread and the
    // app's user interface will remain responsive to the user.
    NSURLRequest *feedURLRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:FEED_URL]];
    self.feedConnection = [[NSURLConnection alloc] initWithRequest:feedURLRequest delegate:self];

    // A simple error check. This is not 'release-level' error handling.
    NSAssert(self.feedConnection != nil, @"Failed to create URL connection.");
    parseQueue = [NSOperationQueue new];
    
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;    
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(addFeedItems:) 
                                                 name:kAddFeedItemsNotif object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self 
                                             selector:@selector(feedItemsError:) 
                                                 name:kFeedItemsErrorNotif object:nil];
    
    return YES;
}

// Ensure we save the changes to our managed object context before the application
// terminates.
- (void)applicationWillTerminate:(UIApplication *)application {
    
    NSError *error;
    if (managedObjectContext != nil) {
        if ([managedObjectContext hasChanges] && ![managedObjectContext save:&error]) {
            // Abort application execution and create an entry in the crash log.
            // This isn't 'release-level' error checking, but convienient while developing.
            NSLog(@"Unresolved error %@, %@", error, error.userInfo);
            abort();
        }
    }
}

- (void)fetchData
{
    // Asynchronously download the feed data. We're not blocking the main thread and the
    // app's user interface will remain responsive to the user.
    NSURLRequest *feedURLRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:FEED_URL]];
    self.feedConnection = [[NSURLConnection alloc] initWithRequest:feedURLRequest delegate:self];
    
    // A simple error check. This is not 'release-level' error handling.
    NSAssert(self.feedConnection != nil, @"Failed to create URL connection.");
    parseQueue = [NSOperationQueue new];
    
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(addFeedItems:)
                                                 name:kAddFeedItemsNotif object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(feedItemsError:)
                                                 name:kFeedItemsErrorNotif object:nil];
    
}

#pragma mark -
#pragma mark NSURLConnection delegate methods

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    if ((([httpResponse statusCode] / 100) == 2) && [[response MIMEType] isEqual:@"application/atom+xml"]) {
        feedData = [NSMutableData data];
    } else {
        // Handle errors as appropriate here.
        // This isn't 'release-level' error checking.        
    }
    feedData = [NSMutableData data];
}

// Append received data as it streams in.
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    
    [feedData appendData:data];
}

// A 'release-level' application would implement logic to alert the user and
// handle the error appropriately. 
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    self.feedConnection = nil;
}

// After our NSURLConnection finished receiving the request's data, spawn our
// custom parsing NSOperation. See SMParseFeedOperation, it is verbosly commented.
- (void)connectionDidFinishLoading:(NSURLConnection *)connection {

    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO; 
    
    self.feedConnection = nil;
    
    // Parse the XML on a secondary thread so we don't block the UI.
    SMParseFeedOperation *parseOperation = [[SMParseFeedOperation alloc] initWithData:self.feedData];
    [self.parseQueue addOperation:parseOperation];
    
    // Our ParseOperation posts this notification when a batch of feed items is ready
    // to be added to the root view controller's table.
    [[NSNotificationCenter defaultCenter] addObserver:self.rootViewController 
                                             selector:@selector(mergeChanges:) 
                                                 name:NSManagedObjectContextDidSaveNotification 
                                               object:parseOperation.managedObjectContext];
    
    // Our operation has a reference to the data, we no longer need one here.
    self.feedData = nil;
}

- (void)handleError:(NSError *)error {
    // Because we're in the application development stage, nothing is implemented here.
    // This is not 'release-level' error handling.
}

// Our XML parsing operation encountered a parsing error.
// This is not 'release-level' error handling.
- (void)feedItemsError:(NSNotification *)note {
    
    [self handleError:[note.userInfo valueForKey:kFeedItemsMsgErrorKey]];
}

#pragma mark -
#pragma mark Core Data

- (NSString *)applicationDocumentsDirectory {
    
    return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
}

// Create and bind the managed object context to the persistent store coordinator.
- (NSManagedObjectContext *)managedObjectContext {
    
    if (managedObjectContext != nil) {
        return managedObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = self.persistentStoreCoordinator;
    if (coordinator != nil) {
        managedObjectContext = [NSManagedObjectContext new];
        [managedObjectContext setPersistentStoreCoordinator:coordinator];
    }
    return managedObjectContext;
}

// Create the managed object model by merging all models found in the app's bundle.
- (NSManagedObjectModel *)managedObjectModel {
    
    if (managedObjectModel != nil) {
        return managedObjectModel;
    }
    
    managedObjectModel = [NSManagedObjectModel mergedModelFromBundles:nil];
    return managedObjectModel;
}


- (NSPersistentStoreCoordinator *)persistentStoreCoordinator {
    
    if (persistentStoreCoordinator != nil) {
        return persistentStoreCoordinator;
    }
    
    NSString *storePath = [[self applicationDocumentsDirectory] stringByAppendingPathComponent:@"SMFeedItems.sqlite"];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    // If the expected store doesn't exist, copy the default store.
    if (![fm fileExistsAtPath:storePath]) {
        NSString *defaultStorePath = [[NSBundle mainBundle] pathForResource:@"SMFeedItems" ofType:@"sqlite"];
        if (defaultStorePath) {
            [fm copyItemAtPath:defaultStorePath toPath:storePath error:NULL];
        }
    }
    
    NSURL *storeURL = [NSURL fileURLWithPath:storePath];
    
    NSError *error;
    persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:self.managedObjectModel];
    if (![persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:nil error:&error]) {
        // Abort application execution and create an entry in the crash log.
        // This isn't 'release-level' error checking, but convienient while developing.        
        NSLog(@"Unresolved error %@, %@", error, error.userInfo);
        abort();
    }
    
    return persistentStoreCoordinator;
}

@end