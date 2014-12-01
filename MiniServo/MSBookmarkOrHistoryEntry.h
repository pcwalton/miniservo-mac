//
//  MSBookmarkOrHistoryEntry.h
//  MiniServo
//
//  Created by Patrick Walton on 11/30/14.
//  Copyright (c) 2014 Mozilla Corporation. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol MSBookmarkOrHistoryEntry <NSObject>

@property (nonatomic, retain) NSString * url;
@property (nonatomic, retain) NSString * title;

@end
