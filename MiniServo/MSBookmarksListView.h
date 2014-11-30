//
//  MSBookmarksListView.h
//  MiniServo
//
//  Created by Patrick Walton on 11/29/14.
//  Copyright (c) 2014 Mozilla Corporation. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MSAppDelegate.h"

@interface MSBookmarksListView : NSTableView

@property (assign) IBOutlet MSAppDelegate *appDelegate;

@end
