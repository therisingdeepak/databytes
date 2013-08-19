//
//  SMDetailViewController.m
//  Feed Reader
//
//  Created by Eric Johnsen on 11/25/12.
//  Copyright (c) 2012 Eric S. Johnsen. All rights reserved.
//

#import "SMDetailViewController.h"
#import "SMFeedItem.h"

@implementation SMDetailViewController

@synthesize feedItem;
@synthesize webView;
@synthesize activityIndicator;

- (void)viewDidLoad {
 [self startWebViewLoad];
    [super viewDidLoad];

    // Set the nav. bar's title to the title of the feed item we're showing.
    self.title = self.feedItem.itemTitle;
    
    // Create the web view and tell it to load this feed item's HTML content.
    //
    // I was originally setting it's frame to [self.view bounds] but was having
    // an issue where the last bit of content was being hidden because the web view
    // is contained within a scroll view. My simple solution was to make the
    // web view's CGRect 50. pixels shorter than [self.view bounds].
    
    //start an animator symbol for the webpage loading to follow
//	UIActivityIndicatorView *progressWheel = [[UIActivityIndicatorView alloc]
                                              //initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    
	//makes activity indicator disappear when it is stopped
	//progressWheel.hidesWhenStopped = YES;
	
    //used to locate position of activity indicator
	//progressWheel.center = CGPointMake(160, 160);
    
	//self.activityIndicator = progressWheel;
	//[self.view addSubview: self.activityIndicator];
	//[self.activityIndicator startAnimating];
    
	//[progressWheel release];
	//[super viewDidLoad];
	
	//call another method to do the webpage loading
	//[self performSelector:@selector(startWebViewLoad) withObject:nil afterDelay:0];
   
      
}

//programmer defined method to load the webpage
-(void)startWebViewLoad{
    
    
    if(loaded==false)
    {
	//webView = [[UIWebView alloc] initWithFrame:CGRectMake(0.0, 0.0, self.view.bounds.size.width, self.view.bounds.size.height - 50.)];
        
        CGRect webFrame = [[UIScreen mainScreen] applicationFrame];
        webView = [[UIWebView alloc] initWithFrame:webFrame];
    }
    webView.userInteractionEnabled = YES;
    webView.dataDetectorTypes = UIDataDetectorTypeAll;
    //[webView loadHTMLString:@"Loading..Please wait" baseURL:nil];
    webView.delegate=self;    // Add the web view as a subview of this view controller.
    
    //webView.dete
    
    
    NSString *urlAddress = @"http://www.deepakdhakal.com/dcshowinfo.aspx?id=";
    
    urlAddress=[urlAddress stringByAppendingString:self.feedItem.itemTitle];
    urlAddress=[urlAddress stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    
    //Create a URL object.
    // NSURL *url = ;
    
    //URL Requst Object
    NSURLRequest *requestObj = [NSURLRequest requestWithURL:[NSURL URLWithString:urlAddress]];
    
    

    
    NSURL *tempURL = [NSURL URLWithString:urlAddress]; // myURL is a NSString in my shared class
    [webView loadRequest:[NSURLRequest requestWithURL:tempURL]];
    
    
    [self.view addSubview:webView];
    loaded=true;
    //Load the request in the UIWebView.
   // [webView loadRequest:requestObj];
	
}

-(BOOL)webView:(UIWebView*)webView shouldStartLoadWithRequest:(NSURLRequest*)request navigationType:(UIWebViewNavigationType)navigationType
{
    NSURL* url = [request URL];
    if (UIWebViewNavigationTypeLinkClicked == navigationType)
    {
        //[[UIApplication sharedApplication] openURL:url];
        //return NO;
    }
}

- (void)webViewDidStartLoad:(UIWebView *)webView {
    NSLog(@"page is loading");
}

-(void)webViewDidFinishLoad:(UIWebView *)webView {
    NSLog(@"finished loading");
    //stop the activity indicator when done loading
	[self.activityIndicator stopAnimating];
    
}
- (void)viewDidUnload {

    [super viewDidUnload];

    // Make sure we nil our reference to our subview.
    webView = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {

    // The style delivered to us in the feed's content sets the width of the content to 
    // the width of an iPhone screen in portrait orientation. Therefore, we only support 
    // portrait orientation.
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

@end
