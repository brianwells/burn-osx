/* KWDiskInfo */

#import <Cocoa/Cocoa.h>
#import <DiscRecording/DiscRecording.h>

@interface KWDiskInfo : NSWindowController
{
    IBOutlet id freeSpaceDisk;
    IBOutlet id kindDisk;
    IBOutlet id recorderPopup;
    IBOutlet id usedSpaceDisk;
    IBOutlet id writableDisk;
}
//Interface actions
- (IBAction)recorderPopup:(id)sender;

//Own actions
- (void)startDiskPanelwithDevice:(DRDevice *)device;
- (void)setDiskInfo:(DRDevice *)device;
- (void)updateDiskInfo;

@end
