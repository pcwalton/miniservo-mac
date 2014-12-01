//
//  MSSplendidBarResultView.m
//  MiniServo
//
//  Created by Patrick Walton on 11/30/14.
//  Copyright (c) 2014 Mozilla Corporation. All rights reserved.
//

#import "MSSplendidBarResultView.h"

@implementation MSSplendidBarResultView

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
    }
    return self;
}

- (void)mouseDown:(NSEvent *)theEvent {
    if (self.splendidBarResultDelegate != nil &&
        [self.splendidBarResultDelegate respondsToSelector:
         @selector(splendidBarResultViewReceivedClick:)]) {
            [self.splendidBarResultDelegate
             performSelector:@selector(splendidBarResultViewReceivedClick:)
             withObject:self];
    }
}

@end
