//
//  DISWebClipWinCtl.h
//  DashInstantScrap
//
//  Created by hetima on 2014/03/19.
//  Copyright (c) 2014 hetima. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@interface DISWebClipWinCtl : NSWindowController

@property (weak) IBOutlet WebView *oWebView;
@property (nonatomic, strong)WebArchive* pendingArchive;

- (WebArchive*)webArchive;
- (void)loadWebArchive:(WebArchive*)archive;
- (void)appendMarkupString:(NSString*)string baseURL:(NSURL*)baseURL withLabel:(NSString*)label;

- (IBAction)actClearContent:(id)sender;
- (IBAction)actExport:(id)sender;
- (IBAction)actFind:(id)sender;

@end
