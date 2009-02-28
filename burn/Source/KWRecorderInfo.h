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
}
//Interface actions
- (IBAction)recorderPopup:(id)sender;

//Own actions
- (void)startRecorderPanelwithDevice:(DRDevice *)device;
- (void)setRecorderInfo:(DRDevice *)device;
- (void)updateRecorderInfo;

@end
