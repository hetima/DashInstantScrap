//
//  DISWebClipWinCtl.m
//  DashInstantScrap
//
//  Created by hetima on 2014/03/19.
//  Copyright (c) 2014 hetima. All rights reserved.
//

#import "DISWebClipWinCtl.h"
#import "DISDashInstantScrapCore.h"

#define kHeaderDivClass @"com_hetima_DashInstantScrap_head"
#define kContainerDivClass @"com_hetima_DashInstantScrap_container"

@interface DISWebClipWinCtl ()

@end

@implementation DISWebClipWinCtl {
    id _firstLoadObserver;
    DOMElement* _pendingElement;
}

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        _pendingElement=nil;
        _firstLoadObserver=nil;
        self.pendingArchive=nil;
    }
    return self;
}

- (void)dealloc
{
    [self.oWebView setPolicyDelegate:nil];
    [self.oWebView setUIDelegate:nil];
    [self.oWebView setFrameLoadDelegate:nil];
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    [self.oWebView setPolicyDelegate:self];
    [self.oWebView setUIDelegate:self];
    [self.oWebView setFrameLoadDelegate:self];
    
    // 何か読み込んでおかないと、画像が表示されない
    if (self.pendingArchive) {
        [self loadWebArchive:self.pendingArchive];
        self.pendingArchive=nil;
    }else{
        [self clearContent];
    }
    
    // んで、読み込みは非同期なので読み込み完了前に追加すると上書きされて消されてしまう
    // 1回だけ observe する
    _firstLoadObserver=[[NSNotificationCenter defaultCenter]addObserverForName:WebViewProgressFinishedNotification object:self.oWebView queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        [[NSNotificationCenter defaultCenter]removeObserver:_firstLoadObserver];
        if (_pendingElement) {
            [[[self DOMDocument]body]appendChild:_pendingElement];
            _pendingElement=nil;
        }
        _firstLoadObserver=nil;
    }];

}

- (void)windowWillClose:(NSNotification *)aNotification
{

}

- (void)clearContent
{
    NSString* html=@"<html><body style=\"margin:0;padding:0;\"></body></html>";
    [[self.oWebView mainFrame]loadHTMLString:html baseURL:nil];
}

- (DOMHTMLDocument*)DOMDocument
{
    DOMHTMLDocument* doc=(DOMHTMLDocument*)[[self.oWebView mainFrame]DOMDocument];
    return doc;
}


- (WebArchive*)webArchive
{
    return [[self DOMDocument]webArchive];
}

- (void)loadWebArchive:(WebArchive*)archive
{
    if(archive){
        [[self.oWebView mainFrame]loadArchive:archive];
    }
}


- (DOMElement*)headerHTMLElementWithLabel:(NSString*)label
{
    DOMHTMLDocument* doc=[self DOMDocument];
    DOMHTMLElement* header=(DOMHTMLElement*)[doc createElement:@"div"];
    [header setAttribute:@"style" value:@"clear:both; margin:0; padding:2px 8px; border-top:1px solid #ddd; border-bottom:1px solid #ddd; background:#efefef;"];
    [header setInnerText:label];
    header.className=kHeaderDivClass;
    
    return header;
}

- (void)appendMarkupString:(NSString*)string baseURL:(NSURL*)baseURL withLabel:(NSString*)label
{
    DOMHTMLDocument* doc=[self DOMDocument];
    //This method resolves relative path.
    DOMDocumentFragment *frgmnt=[doc createDocumentFragmentWithMarkupString:string baseURL:baseURL];
    
    DOMNodeList* childNodes=[frgmnt childNodes];
    unsigned i, cnt=[childNodes length];
    
    if (cnt>0) {
        DOMElement* content=[doc createElement:@"div"];
        [content setAttribute:@"style" value:@"padding:4px 16px 4px 16px;"];
        id header=[self headerHTMLElementWithLabel:label];
        
        for (i=0; i<cnt; i++) {
            DOMElement* node=(DOMElement*)[childNodes item:0];
            [content appendChild:node];
        }
        
        //dashCopy() does not work. remove UI
        DOMNodeList *declarations=[content getElementsByClassName:@"declaration"];
        cnt=[declarations length];
        for (i=0; i<cnt; i++) {
            DOMElement* node=(DOMElement*)[declarations item:0];
            node.className=@"";
        }
        
        DOMElement* wrapper=[doc createElement:@"div"];
        wrapper.className=kContainerDivClass;

        [wrapper appendChild:header];
        [wrapper appendChild:content];
        
        if (_firstLoadObserver) {
            _pendingElement=wrapper;
        }else{
            [[doc body]appendChild:wrapper];
            [header scrollIntoView:YES];
        }
    }
}

#pragma mark - action
- (void)openURLInDash:(NSURL*)link
{
    [DISDashInstantScrapCore DashOpenURLInDash:link];
}

- (void)openURLInBrowser:(NSURL*)link
{
    [[NSWorkspace sharedWorkspace]openURL:link];
}

- (void)clearSection:(DOMElement*)node
{
    [[node parentElement]removeChild:node];
}


- (IBAction)actClearContent:(id)sender
{
    [self clearContent];
}

- (IBAction)actExport:(id)sender
{
    
}

- (IBAction)actFind:(id)sender
{

}

#pragma mark - context menu action

- (void)actClearSection:(id)sender
{
    DOMElement* node=[sender representedObject];
    [self clearSection:node];
}

- (void)actOpenInBrowser:(id)sender
{
    NSURL* link=[sender representedObject];
    [self openURLInBrowser:link];
}

- (void)actOpenInDash:(id)sender
{
    NSURL* link=[sender representedObject];
    [self openURLInDash:link];
}

#pragma mark - PolicyDelegate

- (void)webView:(WebView *)webView decidePolicyForNavigationAction:(NSDictionary *)actionInformation
        request:(NSURLRequest *)request
          frame:(WebFrame *)frame
decisionListener:(id<WebPolicyDecisionListener>)listener
{
    NSURL* url=[actionInformation objectForKey:WebActionOriginalURLKey];
    if ([[url scheme]isEqualToString:@"about"]||[[url scheme]isEqualToString:@"applewebdata"]) {
        NSInteger navType=[[actionInformation objectForKey:WebActionNavigationTypeKey]integerValue];
        // prevent reload etc.
        if (navType!=WebNavigationTypeOther) {
            [listener ignore];
        }else{
            [listener use];
        }
    }else if ([[url scheme]hasPrefix:@"http"]) {
        [self openURLInBrowser:url];
        [listener ignore];
    }else if ([[url scheme]isEqualToString:@"file"]) {
        [self openURLInDash:url];
        [listener ignore];
    }else{
        [listener ignore];
    }
}

- (void)webView:(WebView *)webView decidePolicyForNewWindowAction:(NSDictionary *)actionInformation
        request:(NSURLRequest *)request
   newFrameName:(NSString *)frameName
decisionListener:(id<WebPolicyDecisionListener>)listener
{
    [listener ignore];
}


#pragma mark - FrameLoadDelegate

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
    //WebView* webView = self.oWebView;
    
    DOMNodeList *headers=[[[self DOMDocument]body]getElementsByClassName:kHeaderDivClass];

    DOMElement* lastHeader=(DOMElement*)[headers item:[headers length]-1];
    if (lastHeader) {
        [lastHeader scrollIntoView:YES];
    }
}

#pragma mark - UIDelegate

- (void)webView:(WebView *)sender setStatusText:(NSString *)text
{
    
    
}

- (NSArray *)webView:(WebView *)sender contextMenuItemsForElement:(NSDictionary *)element defaultMenuItems:(NSArray *)defaultMenuItems
{

#define DISAddSeparatorIfNeeded(ary,itm) if(itm){[ary addObject:itm];itm=nil;}
#define DISNeedsSeparatorNext(itm) if(!itm){itm=[NSMenuItem separatorItem];}

    NSMutableArray* result=[NSMutableArray array];
    NSMenuItem* separatorItem=nil;
    NSMenuItem* itm=nil;
    NSMenuItem* deleteSectionItem=({
        DOMElement* node=[element objectForKey:WebElementDOMNodeKey];
        DOMElement* containerNode=nil;
        NSMenuItem* itm=nil;
        do {
            if ([node.className isEqualToString:kContainerDivClass]) {
                containerNode=node;
                break;
            }
        } while ((node=[node parentElement]));
        
        if (containerNode) {
            itm=[[NSMenuItem alloc]initWithTitle:@"Delete Section"
                                          action:@selector(actClearSection:) keyEquivalent:@""];
            [itm setTarget:self];
            [itm setRepresentedObject:containerNode];
        }
        itm;
    });

    if(![[element objectForKey:WebElementIsSelectedKey]boolValue]){
        
        if (deleteSectionItem) {
            [result addObject:deleteSectionItem];
            DISNeedsSeparatorNext(separatorItem);
        }
        
        itm=[[NSMenuItem alloc]initWithTitle:@"Delete All" action:@selector(actClearContent:) keyEquivalent:@""];
        [itm setTarget:self];
        
        DISAddSeparatorIfNeeded(result,separatorItem);
        [result addObject:itm];
        
    }else{
        itm=nil;
        NSURL* link=[element objectForKey:WebElementLinkURLKey];
        if ([[link scheme]isEqualTo:@"file"]) {
            itm=[[NSMenuItem alloc]initWithTitle:@"Open in Dash" action:@selector(actOpenInDash:) keyEquivalent:@""];
            [itm setTarget:self];
            [itm setRepresentedObject:link];
            
        }else if ([[link scheme]hasPrefix:@"http"]) {
            itm=[[NSMenuItem alloc]initWithTitle:@"Open in Browser" action:@selector(actOpenInBrowser:) keyEquivalent:@""];
            [itm setTarget:self];
            [itm setRepresentedObject:link];
            
        }
        if (itm) {
            [result addObject:itm];
        }
        
        //tag is
        //Copy Link 3
        //Copy 8
        //Look Up 21
        //Google 20
        
        for (NSMenuItem* itm in defaultMenuItems) {
            if ([itm tag]==3||[itm tag]==8) {
                [result addObject:itm];
                DISNeedsSeparatorNext(separatorItem);
            }
        }

        if (deleteSectionItem) {
            DISAddSeparatorIfNeeded(result,separatorItem);
            [result addObject:deleteSectionItem];
        }
    }
    return result;
}

@end
