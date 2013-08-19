//
//  SMFeedItem.h
//  Feed Reader
//
//  Created by Eric Johnsen on 11/24/12.
//  Copyright (c) 2012 Eric S. Johnsen. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SMFeedItem : NSManagedObject

@property (strong, nonatomic) NSString *itemTitle;
@property (strong, nonatomic) NSString *pubDate;
@property (strong, nonatomic) NSString *authorName;
@property (strong, nonatomic) NSString *itemContent;
@property (strong, nonatomic) NSString *moreInfo;

@end