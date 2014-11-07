//
//  MSView.h
//  MiniServo
//
//  Created by Patrick Walton on 11/6/14.
//  Copyright (c) 2014 Mozilla Foundation. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <IOSurface/IOSurface.h>
#include <OpenGL/gl.h>
#include <include/cef_client.h>
#import "MSAppDelegate.h"

class MSCEFClient;

@interface MSView : NSOpenGLView {
    IOSurfaceRef surface;
    GLuint texture;
    MSAppDelegate* appDelegate;
}

-(void)setAppDelegate:(MSAppDelegate*)newDelegate;
-(void)paint:(const void*)buffer withSize:(NSSize)size;

@end
