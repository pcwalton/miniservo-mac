//
//  MSView.m
//  MiniServo
//
//  Created by Patrick Walton on 11/6/14.
//  Copyright (c) 2014 Mozilla Foundation. All rights reserved.
//

#import "MSAppDelegate.h"
#import "MSView.h"

#include <CoreServices/CoreServices.h>
#include <OpenGL/gl.h>
#include <mach/mach_time.h>

@implementation MSView

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (!self)
        return nil;
    
    appDelegate = nil;
    glContext = nil;

    [self setWantsBestResolutionOpenGLSurface:YES];
    
    return self;
}

- (void)initializeCompositing
{
    NSOpenGLPixelFormatAttribute pixelFormatAttributes[] = {
        NSOpenGLPFADoubleBuffer,
        NSOpenGLPFAAccelerated,
        NSOpenGLPFAColorSize, (NSOpenGLPixelFormatAttribute)24,
        (NSOpenGLPixelFormatAttribute)0
    };
    NSOpenGLPixelFormat *pixelFormat = [[NSOpenGLPixelFormat alloc]
                                        initWithAttributes:pixelFormatAttributes];
    if (pixelFormat == nil) {
        fprintf(stderr, "couldn't choose a pixel format!\n");
        abort();
    }
    CGLContextObj cglContext;
    CGLCreateContext((CGLPixelFormatObj)[pixelFormat CGLPixelFormatObj], nullptr, &cglContext);
    CGLSetCurrentContext(cglContext);
    GLint swapInterval = 1;
    CGLSetParameter(cglContext, kCGLCPSwapInterval, &swapInterval);
    glContext = [[NSOpenGLContext alloc] initWithCGLContextObj:cglContext];
    [glContext setView: self];

    [appDelegate initializeCompositing];
}

-(void)paint:(const void*)buffer withSize:(NSSize)size {
    [glContext makeCurrentContext];
}

-(void)present {
    [glContext flushBuffer];
    [NSOpenGLContext clearCurrentContext];
}

- (void)setAppDelegate:(MSAppDelegate *)newDelegate {
    appDelegate = newDelegate;
}

- (void)updateGLContext {
    [glContext update];
}

- (void)handleMouseEvent:(NSEvent*)event {
    int button = MBT_LEFT;
    switch ([event type]) {
    case NSOtherMouseDown:
    case NSOtherMouseUp:
        button = MBT_MIDDLE;
        break;
    case NSRightMouseDown:
    case NSRightMouseUp:
        button = MBT_RIGHT;
    }
    
    BOOL up = [event type] == NSOtherMouseUp || [event type] == NSRightMouseUp ||
        [event type] == NSLeftMouseUp;

    NSPoint point = [self convertPoint: [event locationInWindow] fromView:nil];
    point.y = [self frame].size.height - point.y;
    point = [self convertPointToBacking: point];
    [appDelegate sendCEFMouseEventForButton: button up: up point: point];
}

- (void)mouseDown:(NSEvent*)event {
    [self handleMouseEvent: event];
}

- (void)mouseUp:(NSEvent*)event {
    [self handleMouseEvent: event];
}

- (void)keyDown:(NSEvent*)event {
    NSString *characters = [event characters];
    char16 character = 0;
    if ([characters length] > 0)
        character = [characters characterAtIndex:0];
    [appDelegate sendCEFKeyboardEventForKey: [event keyCode] character: character];
}

- (void)scrollWheel:(NSEvent*)event {
    // Code for precise scrolling referenced from GLFW.
    NSPoint delta;
    if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_6) {
        delta = NSMakePoint([event scrollingDeltaX], [event scrollingDeltaY]);
        if ([event hasPreciseScrollingDeltas]) {
            delta.x *= 0.1;
            delta.y *= 0.1;
        }
    } else {
        delta = NSMakePoint([event deltaX], [event deltaY]);
    }
    
    if (fabs(delta.x) <= 0.0 && fabs(delta.y) <= 0.0)
        return;
    
    delta.x *= 30.0;
    delta.y *= 30.0;
    
    NSPoint origin = [self convertPoint: [event locationInWindow] fromView:nil];
    origin.y = [self frame].size.height - origin.y;
    [appDelegate sendCEFScrollEventWithDelta:delta origin:origin];
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

@end
