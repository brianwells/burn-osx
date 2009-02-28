/* KWEjecter */

#import <Cocoa/Cocoa.h>
#import <DiscRecording/DiscRecording.h>

@interface KWEjecter : NSWindowController
{
    IBOutlet id popupButton;
}
- (IBAction)cancelEject:(id)sender;
- (IBAction)ejectDisk:(id)sender;
- (void)startEjectSheetForWindow:(NSWindow *)atachWindow forDevice:(DRDevice *)device;
@end
