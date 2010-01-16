/* KWCopyView */

#import <Cocoa/Cocoa.h>
#import "KWCopyController.h"

@interface KWCopyView : NSView
{
	IBOutlet id imageControl;
}
- (void)setViewState:(NSNotification *)notif;
@end