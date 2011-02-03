//
//  NSNumber_Extensions.m
//  Burn
//
//  Created by Maarten Foukhar on 28-01-11.
//  Copyright 2011 Kiwi Fruitware. All rights reserved.
//

#import "NSNumber_Extensions.h"


@implementation NSNumber (MyExtensions)

#if MAC_OS_X_VERSION_MAX_ALLOWED < 1050
+ (NSNumber *)numberWithInteger:(NSInteger)value
{
	return [NSNumber numberWithInt:value];
}

+ (NSNumber *)numberWithUnsignedInteger:(NSUInteger)value
{
	return [NSNumber numberWithUnsignedInt:value];
}

- (NSInteger)integerValue
{
	return [self intValue];
}

- (NSUInteger)unsignedIntegerValue
{
	return [self unsignedIntValue];
}
#endif

+ (NSNumber *)numberWithCGFloat:(CGFloat)value
{
	#if __LP64__ || NS_BUILD_32_LIKE_64
	return [NSNumber numberWithDouble:value];
	#else
	return [NSNumber numberWithFloat:value];
	#endif
}

- (CGFloat)cgfloatValue
{
	#if __LP64__ || NS_BUILD_32_LIKE_64
	return [self doubleValue];
	#else
	return [self floatValue];
	#endif
}

@end
