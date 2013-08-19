//
//  SMDetailViewController.h
//  Feed Reader
//
//  Created by Eric Johnsen on 11/25/12.
//  Copyright (c) 2012 Eric S. Johnsen. All rights reserved.
//

#import <UIKit/UIKit.h>

@class SMFeedItem;

@interface SMDetailViewController : UIViewController <UIWebViewDelegate>{
    
    UIWebView *webView;
    UIActivityIndicatorView *activityIndicator;
    bool loaded;
}

@property (strong, nonatomic) SMFeedItem *feedItem;
@property(nonatomic,retain)IBOutlet UIWebView *webView;
@property(nonatomic,retain)IBOutlet UIActivityIndicatorView *activityIndicator;

@end
