/* dataView */

#import <Cocoa/Cocoa.h>

@interface dataView : NSView
{
IBOutlet id myController;
}
- (void)setViewState:(NSNotification *)notif;
@end
