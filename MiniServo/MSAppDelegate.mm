//
//  MSAppDelegate.mm
//  MiniServo
//
//  Created by Patrick Walton on 11/6/14.
//  Copyright (c) 2014 Mozilla Foundation. All rights reserved.
//

#import "MSAppDelegate.h"
#import "MSCEFClient.h"
#import "MSTabModel.h"
#import "MSTabStyle.h"
#import "MSView.h"
#import <MMTabBarView/MMAttachedTabBarButton.h>
#include <include/cef_app.h>
#include <include/cef_base.h>
#include <include/cef_browser.h>
#include <include/cef_client.h>
#include <sys/sysctl.h>
#include <sys/types.h>
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
    
    NSURL *helpURL = [[NSBundle mainBundle] URLForResource:@"ServoLibrarySelectionHelp.rtf"
                                             withExtension:nil];
    NSTextView *helpLabel =
        [[NSTextView alloc] initWithFrame: NSMakeRect(0.0, 0.0, 600.0, 100.0)];
    [helpLabel replaceCharactersInRange: NSMakeRange(0, 0)
                                withRTF:[NSData dataWithContentsOfURL: helpURL]];
    [helpLabel setEditable:NO];
    [helpLabel setDrawsBackground:NO];
    [helpLabel sizeToFit];
    [openPanel setAccessoryView:helpLabel];
    
    if ([openPanel runModal] != NSFileHandlingPanelOKButton)
        return nil;
    return [[[openPanel URLs] objectAtIndex:0] path];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [[NSUserDefaults standardUserDefaults] registerDefaults:
     [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:1]
                                 forKey:@"ServoRenderingThreads"]];
    
    [self.window setDelegate:self];
    [self.browserView setAppDelegate:self];
    [self.urlBar setDelegate:self];

    [self.tabView addTabViewItem:[[NSTabViewItem alloc] initWithIdentifier:
                                  [[MSTabModel alloc] init]]];

    self.window.titleBarView = self.titleBarView;
    self.window.centerTrafficLightButtons = NO;
    self.window.centerFullScreenButton = NO;
    self.window.trafficLightButtonsLeftMargin =
        self.window.trafficLightButtonsTopMargin =
        self.window.fullScreenButtonRightMargin =
        self.window.fullScreenButtonTopMargin = 14.0;
    [self.window setTitleBarHeight: [self.titleBarView frame].size.height + 20.0];

    [self.statusBarWindow setStyleMask:NSBorderlessWindowMask];
    [self.statusBarWindow setOpaque:NO];
    [self.statusBarWindow setBackgroundColor:[NSColor clearColor]];
    [self.window addChildWindow:self.statusBarWindow ordered:NSWindowAbove];
    
    // Set up the tab bar.
    [self.tabBar setButtonMaxWidth:9999];
    [self.tabBar setButtonOptimumWidth:9999];
    [self.tabBar setShowAddTabButton:YES];
    [self.tabBar setAutomaticallyAnimates:YES];
    [self.tabBar setStyle: [[MSTabStyle alloc] init]];
    
    // Set up preferences.
    int hyperthreadCount;
    size_t hyperthreadCountSize = sizeof(hyperthreadCount);
    sysctlbyname("hw.ncpu", &hyperthreadCount, &hyperthreadCountSize, nullptr, 0);
    for (int i = 1; i <= hyperthreadCount; i++)
        [self.renderingThreadsView addItemWithObjectValue:[NSNumber numberWithInt: i]];
    
    NSProgressIndicator *indicator = [[self.tabBar lastAttachedButton] indicator];
    NSLog(@"tab indicator frame is %gx%g",
          [indicator frame].size.width,
          [indicator frame].size.height);
    [indicator setAutoresizingMask: NSViewNotSizable];
    [indicator setFrameSize:NSMakeSize(5.0, 5.0)];

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
    settings.rendering_threads =
        (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"ServoRenderingThreads"];
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

- (IBAction)openFile:(id)sender {
    NSOpenPanel *openPanel = [[NSOpenPanel alloc] init];
    [openPanel setCanChooseDirectories:NO];
    [openPanel setCanChooseFiles:YES];
    [openPanel setTreatsFilePackagesAsDirectories:YES];
    [openPanel setAllowedFileTypes: [NSArray arrayWithObjects: @"htm", @"html", nil]];
    if ([openPanel runModal] != NSFileHandlingPanelOKButton)
        return;
    NSURL *url = [[openPanel URLs] objectAtIndex:0];
    [self.urlBar setStringValue: [url description]];
    [self navigateToEnteredURL];
}

- (void)controlTextDidEndEditing:(NSNotification *)notification
{
    if ([[[notification userInfo] objectForKey:@"NSTextMovement"] intValue] != NSReturnTextMovement)
        return;
    
    [self navigateToEnteredURL];
}

- (void)navigateToEnteredURL {
    NSString *string = [self.urlBar stringValue];
    if ([string length] == 0)
        return;
    NSURL *url = [NSURL URLWithString:string];
    if ([url scheme] == nil) {
        string = [@"http://" stringByAppendingString:string];
        url = [NSURL URLWithString:string];
    }

    NSDictionary *dimmedAttributes = [NSDictionary
                                      dictionaryWithObjectsAndKeys:
                                      [NSColor disabledControlTextColor],
                                      NSForegroundColorAttributeName,
                                      [NSFont systemFontOfSize:12.0],
                                      NSFontAttributeName,
                                      nil];
    NSDictionary *darkAttributes = [NSDictionary
                                    dictionaryWithObjectsAndKeys:
                                    [NSColor controlTextColor],
                                    NSForegroundColorAttributeName,
                                    [NSFont systemFontOfSize:12.0],
                                    NSFontAttributeName,
                                    nil];
    NSMutableAttributedString *formattedURL = [[NSMutableAttributedString alloc] init];
    [formattedURL appendAttributedString:
     [[NSAttributedString alloc] initWithString:[[url scheme] stringByAppendingString:@"://"]
                                     attributes:dimmedAttributes]];
    // TODO(pcwalton): username, password, port
    NSString *host = [url host];
    if (host == nil)
        host = [[NSString alloc] init];
    [formattedURL appendAttributedString:
     [[NSAttributedString alloc] initWithString:host
                                     attributes:darkAttributes]];
    [formattedURL appendAttributedString:
     [[NSAttributedString alloc] initWithString:[url path]
                                     attributes:dimmedAttributes]];
    [self.urlBar setAttributedStringValue: formattedURL];
    
    CefString cefString([string UTF8String]);
    if (mBrowser == nullptr)
        return;
    if (mBrowser->GetMainFrame() == nullptr)
        return;
    mBrowser->GetMainFrame()->LoadURL(cefString);
}

- (void)repositionStatusBar {
    [self.statusBarWindow setFrame:NSMakeRect([self.window frame].origin.x,
                                              [self.window frame].origin.y,
                                              [self.window frame].size.width,
                                              [self.statusBarWindow frame].size.height)
                           display:YES];
    
}

- (void)windowDidResize:(NSNotification*)notification {
    [self repositionStatusBar];
    
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

- (void)setIsLoading:(BOOL)isLoading {
    [[[self.tabView selectedTabViewItem] identifier] setValue:[NSNumber numberWithBool:isLoading]
                                                   forKeyPath:@"isProcessing"];
    
    // For some reason the tab view will sometimes make the progress indicator be one pixel too
    // tall. This is really ugly, so we fix that manually by hammering in a square shape.
    NSProgressIndicator *indicator = [[self.tabBar lastAttachedButton] indicator];
    NSSize indicatorSize = [indicator frame].size;
    CGFloat indicatorLength = MIN(indicatorSize.width, indicatorSize.height);
    [indicator setFrameSize:NSMakeSize(indicatorLength, indicatorLength)];
    
    if (!isLoading) {
        [self.statusBarWindow orderOut:self];
        return;
    }
    
    [self.statusBar setStringValue:@"Loading…"];
    [self.statusBar sizeToFit];
    NSSize statusBarSize = NSMakeSize([self.statusBar frame].size.width + 8.0,
                                      [self.statusBar frame].size.height + 6.0);
    [self.statusBar setFrameSize: statusBarSize];
    [self.statusBarWindow setFrame:NSMakeRect([self.statusBarWindow frame].origin.x,
                                              [self.statusBarWindow frame].origin.y,
                                              statusBarSize.width,
                                              statusBarSize.height)
                           display:YES];
    [self.statusBarWindow orderFront:self];
}

- (void)setCanGoBack:(BOOL)canGoBack forward:(BOOL)canGoForward {
    [self.backForwardButton setEnabled:canGoBack forSegment:BACK_SEGMENT];
    [self.backForwardButton setEnabled:canGoForward forSegment:FORWARD_SEGMENT];
    if (mBrowser == nullptr)
        return;
    // FIXME(pcwalton)
    if (mBrowser->IsLoading())
        [self.stopReloadButton setStringValue:@"✕"];
    else
        [self.stopReloadButton setStringValue:@"⟲"];
    if ([self.window firstResponder] != self.urlBar || [[self.urlBar stringValue] length] == 0) {
        CefString url = mBrowser->GetMainFrame()->GetURL();
        NSString *nsURL = [[NSString alloc] initWithBytes:url.c_str()
                                                   length:url.length() * 2
                                                 encoding:NSUTF16LittleEndianStringEncoding];
        if (nsURL != nil && [nsURL length] > 0)
            [self.urlBar setStringValue: nsURL];
    }
}

- (void)initializeCompositing {
    mBrowser->GetHost()->InitializeCompositing();
    mBrowser->GetHost()->WasResized();
}

- (IBAction)zoomIn:(id)sender {
    // TODO(pcwalton)
}

- (IBAction)zoomOut:(id)sender {
    // TODO(pcwalton)
}

@end
