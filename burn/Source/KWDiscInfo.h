/* KWDiscInfo */

#import <Cocoa/Cocoa.h>
#import <DiscRecording/DiscRecording.h>

@interface KWDiscInfo : NSWindowController
{
    IBOutlet id freeSpaceDisk;
    IBOutlet id kindDisk;
    IBOutlet id recorderPopup;
    IBOutlet id usedSpaceDisk;
    IBOutlet id writableDisk;
	
	NSDictionary *discTypes;
}

//Main actions
- (void)startDiskPanelwithDevice:(DRDevice *)device;

//Interface actions
- (IBAction)recorderPopup:(id)sender;

//Internal actions
- (void)setDiskInfo:(DRDevice *)device;
- (void)updateDiskInfo;
- (void)saveFrame;

@end