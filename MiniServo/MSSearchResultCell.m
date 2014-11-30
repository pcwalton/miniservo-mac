//
//  MSSearchResultCell.m
//  MiniServo
//
//  Created by Patrick Walton on 11/29/14.
//  Copyright (c) 2014 Mozilla Corporation. All rights reserved.
//

#import "MSSearchResultCell.h"

@implementation MSSearchResultCell

// See: http://www.dejal.com/blog/2007/11/cocoa-custom-attachment-text-view

#define FONT_SIZE           12.0
#define HORIZONTAL_PADDING  6.0
#define VERTICAL_PADDING    3.0
#define BORDER_RADIUS       3.0

- (NSDictionary *)textAttributes {
    return [NSDictionary dictionaryWithObjectsAndKeys:
            [NSFont systemFontOfSize:FONT_SIZE],
            NSFontAttributeName,
            nil];
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    [NSGraphicsContext saveGraphicsState];
    
    [[NSColor colorWithCalibratedRed:236.0/255.0
                               green:236.0/255.0
                                blue:236.0/255.0
                               alpha:1.0] set];
    [[NSBezierPath bezierPathWithRoundedRect:cellFrame
                                     xRadius:BORDER_RADIUS
                                     yRadius:BORDER_RADIUS] fill];
    [[NSColor blackColor] set];
    [self.text drawInRect:NSInsetRect(cellFrame, HORIZONTAL_PADDING, VERTICAL_PADDING)
           withAttributes:[self textAttributes]];
    
    [NSGraphicsContext restoreGraphicsState];
}

- (void)drawWithFrame:(NSRect)cellFrame
               inView:(NSView *)controlView
       characterIndex:(NSUInteger)charIndex {
    [self drawWithFrame:cellFrame inView:controlView];
}

- (void)drawWithFrame:(NSRect)cellFrame
               inView:(NSView *)controlView
       characterIndex:(NSUInteger)charIndex
        layoutManager:(NSLayoutManager *)layoutManager {
    [self drawWithFrame:cellFrame inView:controlView characterIndex:charIndex];
}

- (NSSize)cellSize {
    NSSize textSize = [self.text boundingRectWithSize:NSMakeSize(99999.0, 99999.0)
                                              options:0
                                           attributes:[self textAttributes]].size;
    return NSMakeSize(textSize.width + HORIZONTAL_PADDING * 2.0,
                      textSize.height + VERTICAL_PADDING * 2.0);
}

- (NSRect)cellFrameForTextContainer:(NSTextContainer *)textContainer
               proposedLineFragment:(NSRect)lineFrag
                      glyphPosition:(NSPoint)position
                     characterIndex:(NSUInteger)charIndex {
    NSSize cellSize = [self cellSize];
    return NSMakeRect(position.x, position.y, cellSize.width, cellSize.height);
}

@end
