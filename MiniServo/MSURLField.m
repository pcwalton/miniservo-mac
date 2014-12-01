//
//  MSURLField.m
//  MiniServo
//
//  Created by Patrick Walton on 11/30/14.
//  Copyright (c) 2014 Mozilla Corporation. All rights reserved.
//

#import "MSURLField.h"

@implementation MSURLField

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
    
    // Drawing code here.
}

- (void)mouseDown:(NSEvent *)theEvent {
    [super mouseDown:theEvent];
    if ([self currentEditor] == nil || [[self currentEditor] selectedRange].length == 0) {
        [self selectText:self];
    }
}

@end
