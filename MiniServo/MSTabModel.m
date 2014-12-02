//
//  MSTabModel.m
//  MiniServo
//
//  Created by Patrick Walton on 11/25/14.
//  Copyright (c) 2014 Mozilla Corporation. All rights reserved.
//

#import "MSTabModel.h"
#import "MSHistoryEntry.h"

@implementation MSTabModel

@synthesize isProcessing = mIsProcessing;
@synthesize title = mTitle;
@synthesize historyEntry = mHistoryEntry;

- (id)init {
    self = [super init];
    mIsProcessing = NO;
    mTitle = nil;
    mHistoryEntry = nil;
    return self;
}

@dynamic icon;

- (NSImage *)icon {
    return nil;
}

@end
