//
//  KWAlert.h
//  Burn
//
//  Created by Maarten Foukhar on 07-01-10.
//  Copyright 2010 Kiwi Fruitware. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface KWAlert : NSAlert {
	BOOL expanded;
}
- (void)setDetails:(NSString *)details;
- (void)showDetails;

@end
