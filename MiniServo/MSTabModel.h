//
//  MSTabModel.h
//  MiniServo
//
//  Created by Patrick Walton on 11/25/14.
//  Copyright (c) 2014 Mozilla Corporation. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MMTabBarView/MMTabBarItem.h>

@class MSHistoryEntry;

@interface MSTabModel : NSObject<MMTabBarItem> {
    BOOL mIsProcessing;
    NSString *mTitle;
    MSHistoryEntry *mHistoryEntry;
}

@property (assign) BOOL isProcessing;
@property (strong) NSImage *icon;
@property (copy) NSString *title;
@property (strong) MSHistoryEntry *historyEntry;

@end
