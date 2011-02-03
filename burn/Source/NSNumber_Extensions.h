//
//  NSNumber_Extensions.h
//  Burn
//
//  Created by Maarten Foukhar on 28-01-11.
//  Copyright 2011 Kiwi Fruitware. All rights reserved.
//

#import <Cocoa/Cocoa.h>


#if MAC_OS_X_VERSION_MAX_ALLOWED < 1050
typedef int NSInteger;
typedef unsigned int NSUInteger;
typedef float CGFloat;
#endif

@interface NSNumber (MyExtensions)
#if MAC_OS_X_VERSION_MAX_ALLOWED < 1050
+ (NSNumber *)numberWithInteger:(NSInteger)value;
+ (NSNumber *)numberWithUnsignedInteger:(NSUInteger)value;
- (NSInteger)integerValue;
- (NSUInteger)unsignedIntegerValue;
#endif
+ (NSNumber *)numberWithCGFloat:(CGFloat)value;
- (CGFloat)cgfloatValue;
@end
