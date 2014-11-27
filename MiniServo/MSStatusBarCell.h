//
//  MSStatusBarCell.h
//  MiniServo
//
//  Created by Patrick Walton on 11/26/14.
//  Copyright (c) 2014 Mozilla Corporation. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface MSStatusBarCell : NSTextFieldCell

-(void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView;

@end
