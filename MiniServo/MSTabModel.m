//
//  MSTabModel.m
//  MiniServo
//
//  Created by Patrick Walton on 11/25/14.
//  Copyright (c) 2014 Mozilla Corporation. All rights reserved.
//

#import "MSTabModel.h"

@implementation MSTabModel

@synthesize isProcessing = _isProcessing;

- (id)init {
    self = [super init];
    _isProcessing = NO;
    return self;
}

@dynamic icon;

- (NSImage *)icon {
    return nil;
}

@end
