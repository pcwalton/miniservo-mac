//
//  NSString+MSStringAdditions.m
//  MiniServo
//
//  Created by Patrick Walton on 11/30/14.
//  Copyright (c) 2014 Mozilla Corporation. All rights reserved.
//

#import "NSString+MSStringAdditions.h"
#include <include/cef_base.h>

@implementation NSString (MSStringAdditions)

+ (NSString *)stringWithCEFString: (CefString)cefString {
    return [[NSString alloc] initWithBytes:cefString.c_str()
                                    length:cefString.length() * 2
                                  encoding:NSUTF16LittleEndianStringEncoding];
}

@end
