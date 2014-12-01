//
//  MSSplendidBarResultView.h
//  MiniServo
//
//  Created by Patrick Walton on 11/30/14.
//  Copyright (c) 2014 Mozilla Corporation. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface MSSplendidBarResultView : NSTextView

@property (strong) id splendidBarResultDelegate;
@property (strong) NSObject *representedObject;

@end
