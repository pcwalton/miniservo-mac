//
//  MSAppDelegate.h
//  MiniServo
//
//  Created by Patrick Walton on 11/6/14.
//  Copyright (c) 2014 Mozilla Foundation. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#include <include/cef_app.h>
#include <include/cef_base.h>

#define INITIAL_URL "http://asdf.com/"

@class MSView;

class CefBrowser;
class MSCEFClient;

@interface MSAppDelegate : NSObject <NSApplicationDelegate> {
    CefRefPtr<CefBrowser> mBrowser;
    CefRefPtr<MSCEFClient> mCEFClient;
}

@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet NSSegmentedControl *backForwardButton;
@property (assign) IBOutlet NSButton *stopReloadButton;
@property (assign) IBOutlet MSView *browserView;

-(IBAction)goBackOrForward:(id)sender;
-(IBAction)stopOrReload:(id)sender;
-(IBAction)navigateToURL:(id)sender;
-(void)browserViewDidResize;

@end
