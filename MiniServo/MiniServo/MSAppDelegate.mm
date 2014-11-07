//
//  MSAppDelegate.m
//  MiniServo
//
//  Created by Patrick Walton on 11/6/14.
//  Copyright (c) 2014 Mozilla Foundation. All rights reserved.
//

#import "MSAppDelegate.h"

@implementation MSAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    NSArray *arguments = [[NSProcessInfo processInfo] arguments];
    const char **cArguments = malloc(sizeof(const char *) * [arguments count]);
    for (size_t i = 0; i < [arguments count]; i++)
        cArguments[i] = [[arguments objectAtIndex: i] cString];
    CefSettings settings;
    settings.single
}

@end
