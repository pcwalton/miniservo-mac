//
//  MSURLView.m
//  MiniServo
//
//  Created by Patrick Walton on 11/21/14.
//  Copyright (c) 2014 Mozilla Corporation. All rights reserved.
//

#import "MSURLView.h"

@implementation NSBezierPath (BezierPathQuartzUtilities)

// This method works only in OS X v10.2 and later.
- (CGPathRef)quartzPath
{
    int i, numElements;
    
    // Need to begin a path here.
    CGPathRef           immutablePath = NULL;
    
    // Then draw the path elements.
    numElements = (int)[self elementCount];
    if (numElements > 0)
    {
        CGMutablePathRef    path = CGPathCreateMutable();
        NSPoint             points[3];
        BOOL                didClosePath = YES;
        
        for (i = 0; i < numElements; i++)
        {
            switch ([self elementAtIndex:i associatedPoints:points])
            {
                case NSMoveToBezierPathElement:
                    CGPathMoveToPoint(path, NULL, points[0].x, points[0].y);
                    break;
                    
                case NSLineToBezierPathElement:
                    CGPathAddLineToPoint(path, NULL, points[0].x, points[0].y);
                    didClosePath = NO;
                    break;
                    
                case NSCurveToBezierPathElement:
                    CGPathAddCurveToPoint(path, NULL, points[0].x, points[0].y,
                                          points[1].x, points[1].y,
                                          points[2].x, points[2].y);
                    didClosePath = NO;
                    break;
                    
                case NSClosePathBezierPathElement:
                    CGPathCloseSubpath(path);
                    didClosePath = YES;
                    break;
            }
        }
        
        // Be sure the path is closed or Quartz may not do valid hit detection.
        if (!didClosePath)
            CGPathCloseSubpath(path);
        
        immutablePath = CGPathCreateCopy(path);
        CGPathRelease(path);
    }
    
    return immutablePath;
}
@end

@implementation MSURLView

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

    [[NSColor whiteColor] set];
    
    // Create outer path.
    NSRect bounds = NSInsetRect([self bounds], 1.0, 1.7);
    NSRect outerBounds = NSMakeRect(bounds.origin.x,
                                    bounds.origin.y - 1,
                                    bounds.size.width,
                                    bounds.size.height + 1);
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:outerBounds xRadius:3.0 yRadius:3.0];
    [[NSColor colorWithCalibratedRed:255./255. green:255./255. blue:255./255. alpha:0.3] set];
    [path fill];
    
    // Create inner path.
    path = [NSBezierPath bezierPathWithRoundedRect:bounds
                                           xRadius:3.0
                                           yRadius:3.0];
    
    // Clip to inner path and draw inner gradient.
    [NSGraphicsContext saveGraphicsState];
    [[NSColor whiteColor] set];
    [path addClip];
    [path fill];
    NSGradient *gradient = [[NSGradient alloc] initWithColors:
                            [NSArray arrayWithObjects:
                             [NSColor colorWithCalibratedRed:230./255. green:230./255. blue:230./255. alpha:1.],
                             [NSColor whiteColor],
                             nil]];
    [gradient drawFromPoint:NSMakePoint(bounds.origin.x, bounds.origin.y + bounds.size.height)
                    toPoint:NSMakePoint(bounds.origin.x, bounds.origin.y + bounds.size.height - 5.0)
                    options:0];
    [NSGraphicsContext restoreGraphicsState];

    [[NSColor whiteColor] set];

    // Draw main border.
    CGContextRef quartzContext = [[NSGraphicsContext currentContext] graphicsPort];
    CGContextSaveGState(quartzContext);
    CGPathRef quartzPath = [path quartzPath];
    CGContextAddPath(quartzContext, quartzPath);
    CGContextSetLineWidth(quartzContext, 0.8);
    CGContextReplacePathWithStrokedPath(quartzContext);
    CGContextClip(quartzContext);
    gradient = [[NSGradient alloc]
                initWithColors:
                [NSArray arrayWithObjects:
                 [NSColor colorWithCalibratedRed:159./255. green:159./255. blue:159./255. alpha:1.],
                 [NSColor colorWithCalibratedRed:191./255. green:191./255. blue:191./255. alpha:1.],
                 nil]];
    [gradient drawFromPoint: NSMakePoint(bounds.origin.x, bounds.origin.y + bounds.size.height)
                    toPoint: bounds.origin
                    options: 0];
    CGContextRestoreGState(quartzContext);
}

@end
