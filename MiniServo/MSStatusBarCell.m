//
//  MSStatusBarCell.m
//  MiniServo
//
//  Created by Patrick Walton on 11/26/14.
//  Copyright (c) 2014 Mozilla Corporation. All rights reserved.
//

#import "MSStatusBarCell.h"

@implementation MSStatusBarCell

-(void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    [NSGraphicsContext saveGraphicsState];
    
    NSBezierPath *boundingPath =
    [NSBezierPath bezierPathWithRoundedRect:NSMakeRect(cellFrame.origin.x - 16.0,
                                                       cellFrame.origin.y + 1.0,
                                                       cellFrame.size.width + 15.0,
                                                       cellFrame.size.height + 16.0)
                                    xRadius:3.0
                                    yRadius:3.0];
    
    [NSGraphicsContext saveGraphicsState];
    [boundingPath addClip];
    [[[NSGradient alloc] initWithColors:
     [NSArray arrayWithObjects:
      [NSColor whiteColor],
      [NSColor colorWithCalibratedRed:220.0/255.0 green:220.0/255.0 blue:220.0/255.0 alpha:1.0],
      nil]] drawInRect:cellFrame angle:90.0];
    [NSGraphicsContext restoreGraphicsState];
    
    [[NSColor colorWithCalibratedRed:204.0/255.0 green:204.0/255.0 blue:204.0/255.0 alpha:1.0] set];
    [boundingPath stroke];
    [NSGraphicsContext restoreGraphicsState];
    
    [super drawInteriorWithFrame:NSMakeRect(cellFrame.origin.x,
                                            cellFrame.origin.y + 3.0,
                                            cellFrame.size.width,
                                            cellFrame.size.height - 3.0)
                          inView:controlView];
}

@end
