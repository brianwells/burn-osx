/* dataView */

#import <Cocoa/Cocoa.h>

@interface KWDataView : NSView
{
	IBOutlet id myController;
}

- (void)setViewState:(NSNotification *)notif;

@end
