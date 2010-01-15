/* KWEjecter */

#import <Cocoa/Cocoa.h>
#import <DiscRecording/DiscRecording.h>

@interface KWEjecter : NSWindowController
{
    IBOutlet id popupButton;
}

//Main actions
- (void)startEjectSheetForWindow:(NSWindow *)atachWindow forDevice:(DRDevice *)device;

//Interface actions
- (IBAction)cancelEject:(id)sender;
- (IBAction)ejectDisk:(id)sender;
@end
