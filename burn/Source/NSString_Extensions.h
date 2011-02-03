//
//  NSString_Extensions.h
//  Burn
//
//  Created by Maarten Foukhar on 03-02-11.
//  Copyright 2011 Kiwi Fruitware. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KWDefines.h"


@interface NSString (MyExtensions)
#if MAC_OS_X_VERSION_MAX_ALLOWED < 1050
- (NSInteger)integerValue;
#endif
- (CGFloat)cgfloatValue;
@end