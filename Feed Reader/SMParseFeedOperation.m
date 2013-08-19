//
//  SMParseFeedOperation.m
//  Feed Reader
//
//  Created by Eric Johnsen on 11/24/12.
//  Copyright (c) 2012 Eric S. Johnsen. All rights reserved.
//

#import "SMParseFeedOperation.h"
#import "SMFeedItem.h"
#import "SMAppDelegate.h"

// Define the keys we will use when posting our custom notifications.
// The application delegate listenes for these four particular notifications.
NSString *kAddFeedItemsNotif    = @"AddFeedItemsNotif";
NSString *kFeedItemResultsKey   = @"FeedItemResultsKey";
NSString *kFeedItemsErrorNotif  = @"FeedItemsErrorNotif";
NSString *kFeedItemsMsgErrorKey = @"FeedItemsMsgErrorKey";

// Declare some hidden instance variables and additional properties. Also
// adopt the NSXMLParserDelegate protocol so we can receive appropriate parsing
// messages.
@interface SMParseFeedOperation () <NSXMLParserDelegate> {
    
    // A flag used to control what character data we accumulate when our
    // NSXMLParser sends it's parser:foundCharacters: delegate method.
    BOOL accumulatingParsedCharacterData;

    // A flag used to prevent posting an error when we deliberately abort parsing.
    // See comments in parser:parseErrorOccurred:
    BOOL didAbortParsing;
    
    // We're liming the number of feed items that we're going to parse, this
    // variable helps us keep track of how many we've parsed.
    NSUInteger parsedFeedItemCounter;
    
    // Reusing one NSDateFormatter object is more efficient than creating one
    // for each date we want to format. Especially important in the context of
    // this application where we're dealing with a lot of dates.
    NSDateFormatter *dateFormatter;
}

// Since the NSXMLParser executes event based parsing, it is necessary to keep
// track of which particular SMFeedItem we're currently constructing.
// See comments in parser:didStartElement: and parser:didEndElement: methods.
@property (strong, nonatomic) SMFeedItem        *currentFeedItemObject;

// We're delivering feed items to the main thread is batches for performance reasons.
// We accumulate them in this array until we're ready to ship them off to the
// SMRootViewController. See comments in parser:didEndElement:.
@property (strong, nonatomic) NSMutableArray    *currentParseBatch;

// Again, because NSXMLParser parsing is event based, it is necessary to accumulate
// all character data parsed between starting and ending element tags into one 'string'.
@property (strong, nonatomic) NSMutableString   *currentParsedCharacterData;

@end

@implementation SMParseFeedOperation

// Synthesize our accessors and mutators.
@synthesize feedItemsData;
@synthesize currentFeedItemObject;
@synthesize currentParseBatch;
@synthesize currentParsedCharacterData;
@synthesize managedObjectContext;

// An NSXMLParser can download data from a passed NSURL. In our case, we're using
// an NSURLConneciton in the application delegate to download the data. This separates
// network errors from parsing errors, making handling each easier.
- (id)initWithData:(NSData *)parseData {
    
    if (self = [super init]) {
        
        // Copy the parseData downloaded in the appliation delegate into our
        // readonly NSData property.
        feedItemsData = [parseData copy];
        
        // Initialize our dateFormatter here and configure it to our needs.
        // It is more efficient to reuse one date formatter object than to create 
        // one each time we need to format a date.
        dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
        [dateFormatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
        
        // Note that the feed we're parsing delivers more date information than this.
        // A substring of the date character data is created which matches this pattern.
        // See the comments the date portion of the parser:didEndElement: delegate method.
        [dateFormatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss'"];
        
        // Setup our store context and store coordinator.
        managedObjectContext = [[NSManagedObjectContext alloc] init];
        [self.managedObjectContext setUndoManager:nil];
        
        SMAppDelegate *appDelegate = (SMAppDelegate *)[[UIApplication sharedApplication] delegate];
        [self.managedObjectContext setPersistentStoreCoordinator:appDelegate.persistentStoreCoordinator];
        
        parsedFeedItemCounter = 0;
    }
    return self;
}

// This method is called when we're ready to send parsed feed items to our main thread.
- (void)addFeedItemsToList:(NSArray *)feedItems {
    
    assert([NSThread isMainThread]);
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"SMFeedItem" inManagedObjectContext:self.managedObjectContext];
    fetchRequest.entity = entity;
    
    // We only query these two properties. Querying the content property would have significant overhead.
    fetchRequest.propertiesToFetch = [NSArray arrayWithObjects:@"itemTitle", @"pubDate", nil];
    
    NSError *error = nil;
    SMFeedItem *feedItem = nil;
    
    for (feedItem in feedItems) {
        fetchRequest.predicate = [NSPredicate predicateWithFormat:@"itemTitle = %@ AND pubDate = %@", feedItem.itemTitle, feedItem.pubDate];
        // Check to see if this entry is already in our persistent data store.
        NSArray *fetchedItems = [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];
       if (fetchedItems.count == 0)
        {
            // We didn't find this feed item in our data store. Add it

            [self.managedObjectContext insertObject:feedItem];
            
        }
    }
    
    // Save any changes we made above.
    if (![managedObjectContext save:&error]) {
        NSLog(@"Unresolved error %@, %@", error, error.userInfo);
        abort();
    }
}

// The main method for this operation. It defines what this NSOperation will do.
- (void)main {
    
    // Initialize our properties.
    self.currentParseBatch = [NSMutableArray array];
    self.currentParsedCharacterData = [NSMutableString string];
    
    // Create a parser instance, set ourselves as it's delegate and begin parsing.
    // Note that we have already downloaded the data through an NSURLConnection in
    // the application delegate.
    NSXMLParser *parser = [[NSXMLParser alloc] initWithData:self.feedItemsData];
    [parser setDelegate:self];
    [parser parse];
    
    // Since we're passing feed items to the main thread in batches, we could
    // potentially encounter less than a full batch of feed items. If this is the
    // case, we send them to the main thread here.
    if (![self isCancelled]) {
        if ([self.currentParseBatch count] > 0) {
            [self performSelectorOnMainThread:@selector(addFeedItemsToList:) 
                                   withObject:self.currentParseBatch 
                                waitUntilDone:NO];
        }        
    }
    
    // Nil our property references.
    self.currentParseBatch = nil;
    self.currentFeedItemObject = nil;
    self.currentParsedCharacterData = nil;
}

#pragma mark -
#pragma mark Parser constants

// Limit the maximum number of feed items the application will parse.
// There may be more than 25, but we're telling the application we're only
// interested in the first 25.
static const const NSUInteger kMaximumNumberOfFeedItemsToParse = 25;

// When a SMFeedItem object has been fully constructed, it must be passed to the
// main thread and the table view in SMRootViewController must be reloaded to
// display it. Since the overhead of communicating between threads and reloading
// the table view is fairly high, we pass our feed items in batches, sized by
// this constant.
static NSUInteger const kSizeOfFeedItemsBatch = 10;

// Below are the element names we're interested in for this application. Declaring
// them here reduces potential parsing errors.
static NSString * const kEntryElementName       = @"entry";
static NSString * const kTitleElementName       = @"title";
static NSString * const kPublishedElementName   = @"published";
static NSString * const kUpdatedElementName     = @"updated";
static NSString * const kContentElementName     = @"content";
static NSString * const kAuthorElementName      = @"author";
static NSString * const kNameElementName        = @"name";
static NSString * const kMoreInfoElementName    = @"moreinfo";

#pragma mark -
#pragma mark NSXMLParser delegate methods

/**
 *This is where the 'heavy-lifting' of this application occurs. Since we're dealing
 * with XML data, we're interested in data contained between certain elements. Since
 * we're a registered NSXMLParser delegate, we receive these messages when the parser
 * encounters starting and ending elements, allowing us to extract the data we're
 * interested in.
 */

// The parser encounted an opening element tag.
- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName 
                                                        namespaceURI:(NSString *)namespaceURI 
                                                        qualifiedName:(NSString *)qName 
                                                        attributes:(NSDictionary *)attributeDict {

    // Tell the parser to abort parsing if we have already parsed our defined 
    // maximum number of feed items.
    if (parsedFeedItemCounter >= kMaximumNumberOfFeedItemsToParse) {
        // We set this flag to ensure we don't post an unwanted error. See 
        // comments in parser:parseErrorOccurred:
        didAbortParsing = YES;
        [parser abortParsing];
    }
    
    // All feed items are contained within <entry>...</entry> elements.
    if ([elementName isEqualToString:kEntryElementName]) {
        
        NSEntityDescription *entityDesc = [NSEntityDescription entityForName:@"SMFeedItem" inManagedObjectContext:self.managedObjectContext];
        
        // Create a new SMFeedItem managed object.
        SMFeedItem *feedItem = [[SMFeedItem alloc] initWithEntity:entityDesc insertIntoManagedObjectContext:nil];
        self.currentFeedItemObject = feedItem;
    } else if ([elementName isEqualToString:kTitleElementName]
               || [elementName isEqualToString:kPublishedElementName]
               || [elementName isEqualToString:kUpdatedElementName]
               || [elementName isEqualToString:kContentElementName]
               || [elementName isEqualToString:kAuthorElementName]
               || [elementName isEqualToString:kMoreInfoElementName]
               || [elementName isEqualToString:kNameElementName]) {
        
        // For all these elements we should begin accumulating parsed character data.
        // The contents are collected in parser:foundCharacters:
        accumulatingParsedCharacterData = YES;
        
        // Make sure to reset the mutable string into which our character data accumulates.
        [currentParsedCharacterData setString:@""];
    }
}

// The parser encounted an ending element tag.
- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName 
                                                        namespaceURI:(NSString *)namespaceURI 
                                                        qualifiedName:(NSString *)qName {
    
    // We've reached the end of an article entry.
    if ([elementName isEqualToString:kEntryElementName]) {
        // Add our completely parsed feed item to our parse batch.
        [self.currentParseBatch addObject:self.currentFeedItemObject];
        parsedFeedItemCounter++;
        // We are only delivering 10 feed items to the view controller at a time.
        // With this simple application this isn't completely necessary, but good
        // practice as we don't want to cause performance issues to the UI.
        if ([self.currentParseBatch count] >= kMaximumNumberOfFeedItemsToParse) {
            // Message ourselves to post a notification to the application delegate
            // that we're ready to add the new elements to our view controller's array.
            [self performSelectorOnMainThread:@selector(addFeedItemsToList:) 
                                   withObject:self.currentParseBatch
                                waitUntilDone:NO];
            self.currentParseBatch = [NSMutableArray array];
        }
    // For all the following cases, we've reached the end of an element that we're
    // interested in and will handle the accumulated character data as needed.
    } 
    else if ([elementName isEqualToString:kPublishedElementName]) {
        // We set the publish date here, note that we check the 'updated' element
        // after this, overriding the publish date if necessary.
        //
        // The feed is providing us with more date information than we require. We
        // simply create a substring with the content we're interested in before we
        // pass the string to our date formatter.
        NSString *dateSubStr = [self.currentParsedCharacterData substringToIndex:19];
        self.currentFeedItemObject.pubDate = [dateFormatter dateFromString:dateSubStr];
    } 
    else if ([elementName isEqualToString:kUpdatedElementName]) {
        // See comments in the else if check above this one.
        NSString *dateSubStr = [self.currentParsedCharacterData substringToIndex:19];
        self.currentFeedItemObject.pubDate = [dateFormatter dateFromString:dateSubStr];
    } 
    else if ([elementName isEqualToString:kTitleElementName]) {
        // Set our item's title to the character we've accumulated between these element
        // tags. Note that we make a deep copy of the data. If we didn't, the title
        // of all our feed items would be mutated as the parser moves to a new feed item.
        self.currentFeedItemObject.itemTitle = [self.currentParsedCharacterData copy];
    } 
    else if ([elementName isEqualToString:kContentElementName]) {
        // Note that we make a deep copy of the data to prevent unintended mutation of
        // previously parsed feed items.
        self.currentFeedItemObject.itemContent = [self.currentParsedCharacterData copy];
    } 
    else if ([elementName isEqualToString:kNameElementName]) {
        // Note that we make a deep copy of the data to prevent unintended mutation of
        // previously parsed feed items.
        self.currentFeedItemObject.authorName = [self.currentParsedCharacterData copy];
    }
    else if ([elementName isEqualToString:kMoreInfoElementName]) {
        // Note that we make a deep copy of the data to prevent unintended mutation of
        // previously parsed feed items.
        self.currentFeedItemObject.moreInfo = [self.currentParsedCharacterData copy];
    }
    
    // Stop accumulating parsed character data.
    accumulatingParsedCharacterData = NO;
}

// This is a delegate method called when the NSXMLParser finds character data within
// an element. The parser does not necessarily deliver all the data at once, so we
// must accumulate the character data until the parser finds the ending element tag.
- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
    
    if (accumulatingParsedCharacterData) {
        // Our NSMutableString into which we're accumulating this character data
        // is re-initialized to @"" for each element. This allows us to append
        // all character data to the mutable string instance.
        [self.currentParsedCharacterData appendString:string];
    }
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError {
    
    // Since we're limiting the amount of feed items to pull, make sure the error isn't
    // caused by us explicitly telling the parser to abort parsing.
    if ([parseError code] != NSXMLParserDelegateAbortedParseError && !didAbortParsing) {
        [self performSelectorOnMainThread:@selector(handleFeedItemsError:) 
                               withObject:parseError 
                            waitUntilDone:NO];
    }
}

// Notify the application delegate (who's a registered listener for this notification)
// that there was an error while parsing the feed data.
- (void)handleFeedItemsError:(NSError *)parseError {
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kFeedItemsErrorNotif
                                                        object:self
                                                      userInfo:[NSDictionary dictionaryWithObject:parseError
                                                                                           forKey:kFeedItemsMsgErrorKey]];
}

@end