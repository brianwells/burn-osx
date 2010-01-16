/* KWRecorderInfo */

#import <Cocoa/Cocoa.h>
#import <DiscRecording/DiscRecording.h>

@interface KWRecorderInfo : NSWindowController
{
    IBOutlet id recorderBuffer;
    IBOutlet id recorderCache;
    IBOutlet id recorderConnection;
    IBOutlet id recorderPopup;
    IBOutlet id recorderProduct;
    IBOutlet id recorderVendor;
    IBOutlet id recorderWrites;
	
	NSDictionary *discTypes;
}

//Main actions
- (void)startRecorderPanelwithDevice:(DRDevice *)device;

//Interface actions
- (IBAction)recorderPopup:(id)sender;

//Internal actions
- (void)setRecorderInfo:(DRDevice *)device;
- (void)updateRecorderInfo;
- (void)saveFrame;

@end