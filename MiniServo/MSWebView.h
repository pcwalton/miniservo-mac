//
//  MSWebView.h
//  MiniServo
//
//  Created by Patrick Walton on 11/6/14.
//  Copyright (c) 2014 Mozilla Foundation. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#include <OpenGL/gl.h>
#include <include/cef_client.h>
#import "MSAppDelegate.h"

class MSCEFClient;

@interface MSWebView : NSView {
    MSAppDelegate* appDelegate;
    NSOpenGLContext *glContext;
}

-(id)initWithFrame:(NSRect)frame;
-(void)initializeCompositing;
-(void)setAppDelegate:(MSAppDelegate*)newDelegate;
-(void)paint:(const void*)buffer withSize:(NSSize)size;
-(void)present;
-(void)updateGLContext;

@end
