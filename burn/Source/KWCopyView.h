/* dropImageView */

#import <Cocoa/Cocoa.h>
#import "copyController.h"

@interface dropImageView : NSView
{
IBOutlet id imageControl;
}
- (void)setViewState:(NSNotification *)notif;
@end
