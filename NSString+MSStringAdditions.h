//
//  NSString+MSStringAdditions.h
//  MiniServo
//
//  Created by Patrick Walton on 11/30/14.
//  Copyright (c) 2014 Mozilla Corporation. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <include/cef_base.h>

@interface NSString (MSStringAdditions)

+ (NSString *)stringWithCEFString: (CefString)cefString;

@end
