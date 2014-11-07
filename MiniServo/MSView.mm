//
//  MSView.m
//  MiniServo
//
//  Created by Patrick Walton on 11/6/14.
//  Copyright (c) 2014 Mozilla Foundation. All rights reserved.
//

#import "MSAppDelegate.h"
#import "MSView.h"
#include <OpenGL/gl.h>

@implementation MSView

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (!self)
        return nil;
    
    appDelegate = nil;
    surface = nil;
    texture = 0;
    
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(viewFrameDidChange:)
                                                 name: NSViewFrameDidChangeNotification
                                               object: self];
    
    return self;
}

- (void)drawRect:(NSRect)dirtyRect
{
    [super drawRect:dirtyRect];
    
    glClearColor(0.0, 0.0, 0.0, 1.0);
    glClear(GL_COLOR_BUFFER_BIT);
    
    glViewport(0, 0, [self frame].size.width, [self frame].size.height);
    glEnable(GL_TEXTURE_2D);
    glEnable(GL_TEXTURE_RECTANGLE_ARB);
    
    if (texture != 0)
        glBindTexture(GL_TEXTURE_RECTANGLE_ARB, texture);
    
    glBegin(GL_QUADS);
    glTexCoord2f(0.0, [self frame].size.height);
    glVertex3f(-1.0, -1.0, 0.0);
    glTexCoord2f([self frame].size.width, [self frame].size.height);
    glVertex3f(1.0, -1.0, 0.0);
    glTexCoord2f([self frame].size.width, 0);
    glVertex3f(1.0, 1.0, 0.0);
    glTexCoord2f(0.0, 0.0);
    glVertex3f(-1.0, 1.0, 0.0);
    glEnd();
    
    if (texture != 0)
        glBindTexture(GL_TEXTURE_2D, 0);
    
    glFlush();
    
    [[self openGLContext] flushBuffer];
    
    NSLog(@"drawn!");
}

-(void)paint:(const void*)buffer withSize:(NSSize)size {
    if (surface == nil ||
            IOSurfaceGetWidth(surface) != size.width ||
            IOSurfaceGetHeight(surface) != size.height) {
        if (surface != nil) {
            CFRelease(surface);
            surface = nil;
        }
        surface = IOSurfaceCreate((__bridge CFDictionaryRef)
                                  ([NSDictionary dictionaryWithObjectsAndKeys:
                                   [NSNumber numberWithInt: size.width], kIOSurfaceWidth,
                                   [NSNumber numberWithInt: size.height], kIOSurfaceHeight,
                                   [NSNumber numberWithInt: size.width * 4], kIOSurfaceBytesPerRow,
                                   [NSNumber numberWithInt: 4], kIOSurfaceBytesPerElement,
                                   nil]));
    }
    if (IOSurfaceLock(surface, 0, NULL) != kIOReturnSuccess) {
        NSLog(@"failed to lock I/O surface");
        return;
    }
    memcpy(IOSurfaceGetBaseAddress(surface), buffer, (int)size.width * (int)size.height * 4);
    IOSurfaceUnlock(surface, 0, NULL);
    
    [[self openGLContext] makeCurrentContext];
    
    if (texture != 0) {
        glDeleteTextures(1, &texture);
        texture = 0;
    }
    glGenTextures(1, &texture);
    glBindTexture(GL_TEXTURE_RECTANGLE_ARB, texture);
    CGLError cglError = CGLTexImageIOSurface2D((CGLContextObj)[[self openGLContext] CGLContextObj],
                                               GL_TEXTURE_RECTANGLE_ARB,
                                               GL_RGBA,
                                               size.width,
                                               size.height,
                                               GL_BGRA,
                                               GL_UNSIGNED_INT_8_8_8_8_REV,
                                               surface,
                                               0);
    if (cglError != kCGLNoError)
        NSLog(@"failed to upload!");
    
    NSLog(@"painted!");
    [self setNeedsDisplay: YES];
}

- (void)viewFrameDidChange:(id)sender {
    [appDelegate browserViewDidResize];
}

- (void)setAppDelegate:(MSAppDelegate *)newDelegate {
    appDelegate = newDelegate;
}

@end
