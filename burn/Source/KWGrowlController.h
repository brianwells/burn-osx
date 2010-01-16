/* KWGrowlController */

#import <Cocoa/Cocoa.h>
#import "Growl/Growl.h"

@interface KWGrowlController : NSObject<GrowlApplicationBridgeDelegate>
{
	NSArray *notifications;
	NSArray *notificationNames;
}

@end