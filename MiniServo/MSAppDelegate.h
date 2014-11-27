//
//  MSAppDelegate.h
//  MiniServo
//
//  Created by Patrick Walton on 11/6/14.
//  Copyright (c) 2014 Mozilla Foundation. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <MMTabBarView/MMTabBarView.h>
#include <include/cef_app.h>
#include <include/cef_base.h>
#import "INAppStoreWindow.h"

#define INITIAL_URL "http://asdf.com/"

@class MSView;

class CefBrowser;
class MSCEFClient;

@interface MSAppDelegate : NSObject <NSApplicationDelegate, NSTextFieldDelegate, NSWindowDelegate> {
    CefRefPtr<CefBrowser> mBrowser;
    CefRefPtr<MSCEFClient> mCEFClient;
    BOOL mDoingWork;
}

@property (assign) IBOutlet INAppStoreWindow *window;
@property (assign) IBOutlet NSSegmentedControl *backForwardButton;
@property (assign) IBOutlet NSButton *stopReloadButton;
@property (assign) IBOutlet NSTextField *urlBar;
@property (assign) IBOutlet MSView *browserView;
@property (assign) IBOutlet MMTabBarView *tabBar;
@property (assign) IBOutlet NSTabView *tabView;
@property (assign) IBOutlet NSView *titleBarView;
@property (assign) IBOutlet NSWindow *statusBarWindow;
@property (assign) IBOutlet NSTextField *statusBar;
@property (assign) IBOutlet NSComboBox *renderingThreadsView;
@property (assign) IBOutlet NSMenuItem *zoomInMenuItem;
@property (assign) IBOutlet NSMenuItem *zoomOutMenuItem;

- (IBAction)changeFrameworkPath:(id)sender;
- (IBAction)goBackOrForward:(id)sender;
- (IBAction)goBack:(id)sender;
- (IBAction)goForward:(id)sender;
- (IBAction)stopOrReload:(id)sender;
- (IBAction)openFile:(id)sender;
- (IBAction)zoomIn:(id)sender;
- (IBAction)zoomOut:(id)sender;
- (NSString *)promptForNewFrameworkPath;
- (void)navigateToEnteredURL;
- (void)spinCEFEventLoop:(id)nothing;
- (void)repositionStatusBar;
- (void)windowDidResize:(NSNotification*)notification;
- (void)sendCEFMouseEventForButton:(int)button up:(BOOL)up point:(NSPoint)point;
- (void)sendCEFScrollEventWithDelta:(NSPoint)delta origin:(NSPoint)origin;
- (void)sendCEFKeyboardEventForKey:(short)keyCode character:(char16)character;
- (void)setIsLoading:(BOOL)isLoading;
- (void)setCanGoBack:(BOOL)canGoBack forward:(BOOL)canGoForward;
- (void)initializeCompositing;

@end
