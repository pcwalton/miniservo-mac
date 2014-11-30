//
//  MSSplendidBarView.m
//  MiniServo
//
//  Created by Patrick Walton on 11/29/14.
//  Copyright (c) 2014 Mozilla Corporation. All rights reserved.
//

#import "MSSplendidBarView.h"

@implementation MSSplendidBarView

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
    }
    return self;
}

- (void)drawRect:(NSRect)dirtyRect
{
    [super drawRect:dirtyRect];
    
    [NSGraphicsContext saveGraphicsState];
    [[NSColor colorWithCalibratedRed:255.0/255.0
                               green:255.0/255.0
                                blue:255.0/255.0
                               alpha:0.97] set];
    [[NSBezierPath bezierPathWithRoundedRect:[self frame]
                                     xRadius:6.0
                                     yRadius:6.0] fill];
    [NSGraphicsContext restoreGraphicsState];
}

@end
