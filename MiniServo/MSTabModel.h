//
//  MSTabModel.h
//  MiniServo
//
//  Created by Patrick Walton on 11/25/14.
//  Copyright (c) 2014 Mozilla Corporation. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MMTabBarView/MMTabBarItem.h>

@interface MSTabModel : NSObject<MMTabBarItem> {
    BOOL _isProcessing;
}

@property (assign) BOOL isProcessing;
@property (strong) NSImage *icon;

@end
