//
//  MSTabStyle.h
//  MiniServo
//
//  Created by Patrick Walton on 11/25/14.
//  Copyright (c) 2014 Mozilla Corporation. All rights reserved.
//

#import <MMTabBarView/MMTabBarView.h>
#import <MMTabBarView/MMSafariTabStyle.h>

@interface MSTabStyle : MMSafariTabStyle

- (NSAttributedString *)attributedStringValueForTabCell:(MMTabBarButtonCell *)cell;

@end
