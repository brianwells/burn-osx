/* KWEraser */

#import <Cocoa/Cocoa.h>
#import <DiscRecording/DiscRecording.h>

@interface KWEraser : NSWindowController
{
    //Interface outlets
	IBOutlet id burnerPopup;
    IBOutlet id closeButton;
    IBOutlet id completelyErase;
    IBOutlet id eraseButton;
    IBOutlet id quicklyErase;
    IBOutlet id statusText;
	
	//Variables
	BOOL shouldClose;
	SEL endSelector;
	id endDelegate;
}
//Main actions
- (void)beginEraseSheetForWindow:(NSWindow *)window modalDelegate:(id)delegate didEndSelector:(SEL)selector;
- (int)beginEraseWindow;
- (void)erase;
- (void)updateDevice:(DRDevice *)device;
//Interface actions
- (IBAction)burnerPopup:(id)sender;
- (IBAction)cancelButton:(id)sender;
- (IBAction)closeButton:(id)sender;
- (IBAction)eraseButton:(id)sender;
//Notification actions
- (void)statusChanged:(NSNotification *)notif;
- (void)eraseNotification:(NSNotification*)notification;
//Other actions
- (DRDevice *)currentDevice;
- (DRDevice *)savedDevice;
@end
