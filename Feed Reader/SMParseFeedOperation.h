//
//  SMParseFeedOperation.h
//  Feed Reader
//
//  Created by Eric Johnsen on 11/24/12.
//  Copyright (c) 2012 Eric S. Johnsen. All rights reserved.
//

// These are the keys used in our custom feed item notifications posted from
// this operation.
extern NSString *kAddFeedItemsNotif;
extern NSString *kFeedItemResultsKey;
extern NSString *kFeedItemsErrorNotif;
extern NSString *kFeedItemsMsgErrorKey;

@interface SMParseFeedOperation : NSOperation {
    
    NSManagedObjectContext *managedObjectContext;
}

@property (copy, readonly) NSData *feedItemsData;
@property (strong) NSManagedObjectContext *managedObjectContext;

- (id)initWithData:(NSData *)data;

@end
