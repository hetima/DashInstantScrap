//
//  DISDashInstantScrapCore.m
//  DashInstantScrap
//
//  Created by hetima on 2014/03/19.
//  Copyright (c) 2014 hetima. All rights reserved.
//

#import "DISDashInstantScrapCore.h"
#import "DISWebClipWinCtl.h"

#define kStoreDataFilename @"DashInstantScrapCache"
#define kStoreDataArchiveData @"ArchiveData"
#define kStoreDataClipWindowFrame @"ClipWindowFrame"

#pragma mark - Method Hook

IMP Replace_MethodImp_WithFunc(Class aClass, SEL origSel, const void* repFunc)
{
    Method origMethod;
    IMP oldImp = NULL;
    
    if (aClass && (origMethod = class_getInstanceMethod(aClass, origSel))){
        oldImp=method_setImplementation(origMethod, repFunc);
    }
    
    return oldImp;
}

IMP Replace_ClassMethodImp_WithFunc(Class aClass, SEL origSel, const void* repFunc)
{
    Method origMethod;
    IMP oldImp = NULL;
    
    if (aClass && (origMethod = class_getClassMethod(aClass, origSel))){
        oldImp=method_setImplementation(origMethod, repFunc);
    }
    
    return oldImp;
}

#ifndef REPFUNCDEFd
#define REPFUNCDEFd
#define RMF(aClass, origSel, repFunc) Replace_MethodImp_WithFunc(aClass, origSel, repFunc)
#define RCMF(aClass, origSel, repFunc) Replace_ClassMethodImp_WithFunc(aClass, origSel, repFunc)
#endif


#pragma mark -

@implementation DISDashInstantScrapCore{
    DISWebClipWinCtl* _webClipWinCtl;
}

static id (*orig_contextMenuItemsForElement)(id, SEL, ...);
static id DIS_contextMenuItemsForElement(id self, SEL _cmd, id webView, NSDictionary *element, NSArray* defaultMenuItems)
{
    
	NSMutableArray* originalItems=orig_contextMenuItemsForElement(self, _cmd, webView, element, defaultMenuItems);
    
    if([[element objectForKey:WebElementIsSelectedKey]boolValue]){
        WebFrame* elementWebFrame=[element objectForKey:WebElementFrameKey];
        NSMenuItem* itm=[[NSMenuItem alloc]initWithTitle:@"Instant Scrap from Selection"
            action:@selector(actClipWebViewSelection:) keyEquivalent:@""];
        [itm setTarget:[DISDashInstantScrapCore si]];
        [itm setRepresentedObject:elementWebFrame];
        [originalItems addObject:[NSMenuItem separatorItem]];
        [originalItems addObject:itm];
    }

	return originalItems;
}

static DISDashInstantScrapCore *sharedInstance;

//SIMBL
+ (void)install
{
    LOG(@"DISDashInstantScrap loaded");
    [[DISDashInstantScrapCore si]setup];
}

+ (DISDashInstantScrapCore *)si
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[DISDashInstantScrapCore alloc]init];
    });
    return sharedInstance;
}

#pragma mark - Dash.app

+ (id)DashSharedDHWindowController
{
    Class winCtlClass=NSClassFromString(@"DHWindowController");
    if (!winCtlClass || ![winCtlClass respondsToSelector:NSSelectorFromString(@"sharedWindow")]) return nil;

    id winCtl=objc_msgSend(winCtlClass, NSSelectorFromString(@"sharedWindow"));
    return winCtl;
}

+ (id)DashSharedDHWebViewController
{

    id winCtl=[DISDashInstantScrapCore DashSharedDHWindowController];
    if (!winCtl || ![winCtl respondsToSelector:NSSelectorFromString(@"webViewController")]) return nil;
    
    id webViewCtl=objc_msgSend(winCtl, NSSelectorFromString(@"webViewController"));
    return webViewCtl;
}

+ (id)DashCurrentWebView
{
    id webViewCtl=[DISDashInstantScrapCore DashSharedDHWebViewController];
    if (!webViewCtl || ![webViewCtl respondsToSelector:NSSelectorFromString(@"webView")]) return nil;
    
    id webView=objc_msgSend(webViewCtl, NSSelectorFromString(@"webView"));
    return webView;
    
}

// not stable
+ (void)DashOpenURLInDash:(NSURL*)link
{
    WebView* webView=[DISDashInstantScrapCore DashCurrentWebView];
    if (!webView) return;
    
    NSURLRequest *req=[NSURLRequest requestWithURL:link];
    [[webView mainFrame]loadRequest:req]; 
}

#pragma mark -

- (void)setup
{
    _webClipWinCtl=nil;
    
    id tmpClas=NSClassFromString(@"DHWebViewController");
    if(tmpClas){
        orig_contextMenuItemsForElement=(id(*)(id, SEL, ...))RMF(tmpClas,
                NSSelectorFromString(@"webView:contextMenuItemsForElement:defaultMenuItems:"),
                DIS_contextMenuItemsForElement);
    }
    
    //setup menu item
    NSMenu* mainMenu=[NSApp mainMenu];
    NSMenu* windowMenu=[[mainMenu itemWithTitle:@"Window"]submenu];
    
    NSMenuItem* anchorItem=[windowMenu itemWithTitle:@"Main Window"];
    NSInteger anchorIndex;
    if (anchorItem && [NSStringFromSelector([anchorItem action]) isEqualToString:@"showWindow:"]) {
        anchorIndex=[windowMenu indexOfItem:anchorItem]+1;
    }else{
        anchorIndex=[windowMenu numberOfItems];
    }
    NSMenuItem* myItem=[[NSMenuItem alloc]initWithTitle:@"Instant Scrap" action:@selector(actShowScrapWindow:) keyEquivalent:@""];
    [myItem setTarget:self];
    [windowMenu insertItem:myItem atIndex:anchorIndex];
    
    
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(appWillTerminate:) name:NSApplicationWillTerminateNotification object:nil];
}

- (void)appWillTerminate:(NSNotification*)note
{
    [self storeCacheData];
    [[NSNotificationCenter defaultCenter]removeObserver:self name:NSApplicationWillTerminateNotification object:nil];
}

- (NSString*)cacheDirectoryPath
{
    NSString* cachePath=[[@"~/Library/Caches" stringByStandardizingPath]stringByAppendingPathComponent:@"com.hetima.DashInstantScrap"];
    
    if (![[NSFileManager defaultManager]fileExistsAtPath:cachePath]) {
        [[NSFileManager defaultManager]createDirectoryAtPath:cachePath withIntermediateDirectories:YES attributes:nil error:nil];
    }

    return cachePath;
}

- (NSString*)cacheFilePath
{
    NSString* cacheFile=[[self cacheDirectoryPath]stringByAppendingPathComponent:kStoreDataFilename];
    return cacheFile;
}

- (DISWebClipWinCtl*)webClipWinCtl
{
    if (!_webClipWinCtl) {
        _webClipWinCtl=[[DISWebClipWinCtl alloc]initWithWindowNibName:@"DISWebClipWinCtl"];
        [self restoreCacheData];
        [[_webClipWinCtl window]setExcludedFromWindowsMenu:YES];
    }
    return _webClipWinCtl;
}

- (BOOL)isWebClipWinLoaded
{
    return (_webClipWinCtl!=nil);
}


- (void)storeCacheData
{
    if (![self isWebClipWinLoaded]) {
        return;
    }
    
    WebArchive* archive=[_webClipWinCtl webArchive];
    NSData* archiveData=[archive data];
    
    NSMutableDictionary* store=[NSMutableDictionary dictionaryWithCapacity:2];
    if (archiveData) {
        [store setObject:archiveData forKey:kStoreDataArchiveData];
    }
    NSRect frame=[[_webClipWinCtl window]frame];
    NSString* frameString=NSStringFromRect(frame);
    [store setObject:frameString forKey:kStoreDataClipWindowFrame];
    
    NSString* cacheFile=[self cacheFilePath];
    [store writeToFile:cacheFile atomically:YES];
}

- (void)restoreCacheData
{
    if (!_webClipWinCtl) {
        return;
    }
    
    NSString* cacheFile=[self cacheFilePath];
    NSDictionary* store=[NSDictionary dictionaryWithContentsOfFile:cacheFile];
    
    NSData* archiveData=[store objectForKey:kStoreDataArchiveData];
    WebArchive* archive=[[WebArchive alloc]initWithData:archiveData];
    if (archive) {
        //must before load window
        _webClipWinCtl.pendingArchive=archive;
    }
    
    NSRect frame=NSRectFromString([store objectForKey:kStoreDataClipWindowFrame]);
    //quick check frame size
    if (NSWidth(frame)>200 && NSHeight(frame)>200 && NSContainsRect([[NSScreen mainScreen]visibleFrame], frame)) {
        [[_webClipWinCtl window]setFrame:frame display:NO animate:NO];
    }
    
}

#pragma mark - action

- (void)actClipWebViewSelection:(id)sender
{
    WebFrame* frame=[sender representedObject];
    DOMRange* domRange=[[frame webView]selectedDOMRange];

    [[[self webClipWinCtl]window]makeKeyAndOrderFront:nil];
    NSString* markupString=[domRange markupString];
    NSURL* baseURL=[[[frame dataSource]request]URL];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[self webClipWinCtl]appendMarkupString:markupString baseURL:baseURL withLabel:[[frame webView]mainFrameTitle]];
    });
}


- (void)actShowScrapWindow:(id)sender
{
    [[self webClipWinCtl]showWindow:nil];
}


@end
