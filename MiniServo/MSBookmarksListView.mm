//
//  MSBookmarksListView.mm
//  MiniServo
//
//  Created by Patrick Walton on 11/29/14.
//  Copyright (c) 2014 Mozilla Corporation. All rights reserved.
//

#import "MSBookmarksListView.h"

@implementation MSBookmarksListView

- (void)mouseDown:(NSEvent *)theEvent {
    NSInteger clickedRow = [self rowAtPoint:[self convertPoint:[theEvent locationInWindow]
                                                      fromView:nil]];

    [super mouseDown:theEvent];
    
    if (clickedRow >= 0)
        [self.appDelegate navigateToBookmarkAtIndex:clickedRow];
}

@end
