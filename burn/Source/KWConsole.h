/* KWConsole */

#import <Cocoa/Cocoa.h>

@interface KWConsole : NSWindowController
{
    IBOutlet id textView;
}
- (IBAction)clear:(id)sender;
- (void)show;
- (void)addText:(NSNotification *)notif;
@end
