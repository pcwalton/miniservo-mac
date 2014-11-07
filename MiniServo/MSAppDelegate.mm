//
//  MSAppDelegate.mm
//  MiniServo
//
//  Created by Patrick Walton on 11/6/14.
//  Copyright (c) 2014 Mozilla Foundation. All rights reserved.
//

#import "MSAppDelegate.h"
#import "MSCEFClient.h"
#import "MSView.h"
#include <include/cef_app.h>
#include <include/cef_base.h>
#include <include/cef_browser.h>
#include <include/cef_client.h>

#define BACK_SEGMENT    0
#define FORWARD_SEGMENT 1

@implementation MSAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [self.window setDelegate:self];
    [self.browserView setAppDelegate:self];
    [self.urlBar setDelegate:self];
    
    NSArray *arguments = [[NSProcessInfo processInfo] arguments];
    char **cArguments = new char *[[arguments count]];
    for (size_t i = 0; i < [arguments count]; i++)
        cArguments[i] = strdup([[arguments objectAtIndex: i] cString]);
    CefMainArgs mainArgs((int)[arguments count], cArguments);
    
    CefSettings settings;
    settings.single_process = true;
    CefInitialize(mainArgs, settings, nullptr, nullptr);

    mCEFClient = new MSCEFClient(self, self.browserView);
    
    CefWindowInfo windowInfo;
    windowInfo.SetAsWindowless([self browserView], false);
    CefBrowserSettings browserSettings;
    mBrowser = CefBrowserHost::CreateBrowserSync(windowInfo, mCEFClient, INITIAL_URL, browserSettings, nullptr);
    
    [NSEvent addLocalMonitorForEventsMatchingMask:NSAnyEventMask handler:^(NSEvent* event){
        [self performSelectorOnMainThread: @selector(spinCEFEventLoop:) withObject: nil waitUntilDone: false];
        return event;
    }];
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    // Avoid a nasty shutdown crash in a C++ destructor. Lovely!
    _exit(0);
}
     
- (void)spinCEFEventLoop:(id) nothing {
    if (mDoingWork)
        return;
    mDoingWork = YES;
    CefDoMessageLoopWork();
    mDoingWork = NO;
}

- (IBAction)goBackOrForward:(id)sender {
    NSSegmentedControl* control = (NSSegmentedControl*)sender;
    switch ([control selectedSegment]) {
    case BACK_SEGMENT:
        mBrowser->GoBack();
        break;
    case FORWARD_SEGMENT:
        mBrowser->GoForward();
        break;
    }
}

- (IBAction)stopOrReload:(id)sender {
    if (mBrowser->IsLoading())
        mBrowser->StopLoad();
    else
        mBrowser->Reload();
}

- (void)controlTextDidEndEditing:(NSNotification *)notification
{
    if ([[[notification userInfo] objectForKey:@"NSTextMovement"] intValue] != NSReturnTextMovement)
        return;
    if ([[self.urlBar stringValue] length] == 0)
        return;
    CefString url([[self.urlBar stringValue] UTF8String]);
    if (mBrowser == nullptr)
        return;
    if (mBrowser->GetMainFrame() == nullptr)
        return;
    mBrowser->GetMainFrame()->LoadURL(url);
}

- (void)windowDidResize:(NSNotification*)notification {
    mBrowser->GetHost()->WasResized();
    mBrowser->GetHost()->Invalidate(PET_VIEW);
}

- (void)sendCEFMouseEventForButton:(int)button up:(BOOL)up point:(NSPoint)point {
    cef_mouse_event_t cCefMouseEvent;
    cCefMouseEvent.x = point.x;
    cCefMouseEvent.y = point.y;
    CefMouseEvent cefMouseEvent(cCefMouseEvent);
    mBrowser->GetHost()->SendMouseClickEvent(cefMouseEvent, MBT_LEFT, up, 1);
}

- (void)setCanGoBack:(BOOL)canGoBack forward:(BOOL)canGoForward {
    [self.backForwardButton setEnabled:canGoBack forSegment:BACK_SEGMENT];
    [self.backForwardButton setEnabled:canGoForward forSegment:FORWARD_SEGMENT];
    if (mBrowser == nullptr)
        return;
    if (mBrowser->IsLoading())
        [self.stopReloadButton setStringValue:@"✕"];
    else
        [self.stopReloadButton setStringValue:@"⟲"];
    if ([self.window firstResponder] != self.urlBar || [[self.urlBar stringValue] length] == 0) {
        CefString url = mBrowser->GetMainFrame()->GetURL();
        NSString *nsURL = [[NSString alloc] initWithBytes:url.c_str()
                                                   length:url.length() * 2
                                                 encoding:NSUTF16StringEncoding];
        [self.urlBar setStringValue: nsURL];
    }
}

@end
