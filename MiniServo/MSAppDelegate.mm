//
//  MSAppDelegate.mm
//  MiniServo
//
//  Created by Patrick Walton on 11/6/14.
//  Copyright (c) 2014 Mozilla Foundation. All rights reserved.
//

#import "MSAppDelegate.h"
#import "MSCEFClient.h"
#import "MSTabStyle.h"
#import "MSView.h"
#include <include/cef_app.h>
#include <include/cef_base.h>
#include <include/cef_browser.h>
#include <include/cef_client.h>

#include <dlfcn.h>

#define BACK_SEGMENT    0
#define FORWARD_SEGMENT 1

@implementation MSAppDelegate

- (IBAction)changeFrameworkPath:(id)sender
{
    NSString *newFrameworkPath = [self promptForNewFrameworkPath];
    if (newFrameworkPath != nil) {
        [[NSUserDefaults standardUserDefaults] setObject: newFrameworkPath
                                                  forKey: @"ServoFrameworkPath"];
    }
}

- (NSString *)promptForNewFrameworkPath
{
    NSOpenPanel *openPanel = [[NSOpenPanel alloc] init];
    [openPanel setCanChooseDirectories:NO];
    [openPanel setCanChooseFiles:YES];
    [openPanel setTreatsFilePackagesAsDirectories:YES];
    [openPanel setAllowedFileTypes: [NSArray arrayWithObject: @"dylib"]];
    if ([openPanel runModal] != NSFileHandlingPanelOKButton)
        return nil;
    return [[[openPanel URLs] objectAtIndex:0] path];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [self.window setDelegate:self];
    [self.browserView setAppDelegate:self];
    [self.urlBar setDelegate:self];

    self.window.titleBarView = self.titleBarView;
    self.window.centerTrafficLightButtons = NO;
    self.window.centerFullScreenButton = NO;
    self.window.trafficLightButtonsLeftMargin =
        self.window.trafficLightButtonsTopMargin =
        self.window.fullScreenButtonRightMargin =
        self.window.fullScreenButtonTopMargin = 14.0;
    [self.window setTitleBarHeight: [self.titleBarView frame].size.height + 20.0];
    [self.tabBar setButtonMaxWidth:9999];
    [self.tabBar setButtonOptimumWidth:9999];
    [self.tabBar setShowAddTabButton:YES];
    [self.tabBar setAutomaticallyAnimates:YES];
    [self.tabBar setStyle: [[MSTabStyle alloc] init]];

    while (true) {
        NSString *frameworkPath =
        [[NSUserDefaults standardUserDefaults] stringForKey: @"ServoFrameworkPath"];
        if (frameworkPath != nil && [frameworkPath length] > 0) {
            if (dlopen([frameworkPath cStringUsingEncoding:NSUTF8StringEncoding],
                       RTLD_LAZY) == nullptr) {
                NSRunAlertPanel(@"Failed to open Servo library.",
                                @"%s",
                                @"OK",
                                nil,
                                nil,
                                dlerror());
            } else {
                break;
            }
        }

        NSString *newFrameworkPath = [self promptForNewFrameworkPath];
        if (newFrameworkPath == nil)
            exit(0);
        [[NSUserDefaults standardUserDefaults] setObject: newFrameworkPath
                                                  forKey: @"ServoFrameworkPath"];
    }
    
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

    [self.browserView initializeCompositing];

    [NSEvent addLocalMonitorForEventsMatchingMask:NSAnyEventMask handler:^(NSEvent* event){
        [self performSelectorOnMainThread: @selector(spinCEFEventLoop:) withObject: nil waitUntilDone: false];
        return event;
    }];
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
}
     
- (void)spinCEFEventLoop:(id) nothing {
    CefDoMessageLoopWork();
}

- (IBAction)goBackOrForward:(id)sender {
    NSSegmentedControl* control = (NSSegmentedControl*)sender;
    switch ([control selectedSegment]) {
    case BACK_SEGMENT:
        [self goBack:sender];
        break;
    case FORWARD_SEGMENT:
        [self goForward:sender];
        break;
    }
}

- (IBAction)goBack:(id)sender {
    mBrowser->GoBack();
}

- (IBAction)goForward:(id)sender {
    mBrowser->GoForward();
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
    if (mBrowser == nullptr)
        return;
    [self.browserView updateGLContext];
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

- (void)sendCEFScrollEventWithDelta:(NSPoint)delta origin:(NSPoint)origin {
    cef_mouse_event_t cCefMouseEvent;
    cCefMouseEvent.x = origin.x;
    cCefMouseEvent.y = origin.y;
    CefMouseEvent cefMouseEvent(cCefMouseEvent);
    mBrowser->GetHost()->SendMouseWheelEvent(cefMouseEvent, delta.x, delta.y);
}

- (void)sendCEFKeyboardEventForKey:(short)keyCode character:(char16)character {
    cef_key_event_t cCefKeyEvent;
    cCefKeyEvent.type = KEYEVENT_RAWKEYDOWN;
    cCefKeyEvent.character = character;
    cCefKeyEvent.modifiers = 0;
    cCefKeyEvent.windows_key_code = keyCode;    // FIXME(pcwalton)
    cCefKeyEvent.native_key_code = keyCode;
    cCefKeyEvent.is_system_key = false;
    cCefKeyEvent.focus_on_editable_field = false;
    CefKeyEvent keyEvent(cCefKeyEvent);
    mBrowser->GetHost()->SendKeyEvent(keyEvent);
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
                                                 encoding:NSUTF16LittleEndianStringEncoding];
        [self.urlBar setStringValue: nsURL];
    }
}

- (void)initializeCompositing {
    mBrowser->GetHost()->WasResized();
    mBrowser->GetHost()->InitializeCompositing();
}

@end
