//
//  MSTabStyle.m
//  MiniServo
//
//  Created by Patrick Walton on 11/25/14.
//  Copyright (c) 2014 Mozilla Corporation. All rights reserved.
//

#import "MSTabStyle.h"
#import <MMTabBarView/MMRolloverButtonCell.h>
#import <MMTabBarView/MMTabBarButtonCell.h>
#import <MMTabBarView/NSView+MMTabBarViewExtensions.h>

@implementation MSTabStyle

- (NSAttributedString *)attributedStringValueForTabCell:(MMTabBarButtonCell *)cell {
	NSMutableAttributedString *attrStr;
	NSString *contents = [cell title];
	attrStr = [[NSMutableAttributedString alloc] initWithString:contents];
	NSRange range = NSMakeRange(0, [contents length]);
    
	// Add font attribute
	[attrStr addAttribute:NSFontAttributeName value:[NSFont boldSystemFontOfSize:11.0] range:range];
	[attrStr addAttribute:NSForegroundColorAttributeName value:[[NSColor textColor] colorWithAlphaComponent:0.75] range:range];
    
	// Add shadow attribute
	NSShadow* shadow;
	shadow = [[NSShadow alloc] init];
	CGFloat shadowAlpha;
	if (([cell state] == NSOnState) || [cell mouseHovered]) {
		shadowAlpha = 0.8;
	} else {
		shadowAlpha = 0.5;
	}
	[shadow setShadowColor:[NSColor colorWithCalibratedWhite:1.0 alpha:shadowAlpha]];
	[shadow setShadowOffset:NSMakeSize(0, -1)];
	[shadow setShadowBlurRadius:1.0];
	[attrStr addAttribute:NSShadowAttributeName value:shadow range:range];
    
	// Paragraph Style for Truncating Long Text
	static NSMutableParagraphStyle *TruncatingTailParagraphStyle = nil;
	if (!TruncatingTailParagraphStyle) {
		TruncatingTailParagraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
		[TruncatingTailParagraphStyle setLineBreakMode:NSLineBreakByTruncatingTail];
		[TruncatingTailParagraphStyle setAlignment:NSCenterTextAlignment];
	}
	[attrStr addAttribute:NSParagraphStyleAttributeName value:TruncatingTailParagraphStyle range:range];
    
	return attrStr;
}

@end
