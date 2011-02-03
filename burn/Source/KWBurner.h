/* KWBurner */

#import <Cocoa/Cocoa.h>
#import <DiscRecording/DiscRecording.h>
#import "KWCommonMethods.h"

@interface KWBurner : NSWindowController
{
	//Main Sheet outlets
    IBOutlet id burnButton;
    IBOutlet id burnerPopup;
    IBOutlet id closeButton;
    IBOutlet id eraseCheckBox;
    IBOutlet id sessionsCheckBox;
    IBOutlet id speedPopup;
    IBOutlet id statusText;
	IBOutlet id combineCheckBox;
	IBOutlet id numberOfCopiesText;
	IBOutlet id numberOfCopiesBox;
	
	//Session Panel Outlets
	IBOutlet id sessionsPanel;
	IBOutlet id sessions;
	IBOutlet id dataSession;
	IBOutlet id audioSession;
	IBOutlet id videoSession;
	
	//Variables
	BOOL shouldClose;
	NSInteger size;
	NSInteger trackNumber; //Must delete
	DRDevice *savedDevice;
	NSDictionary *properties;
	DRBurn *burn;
	NSDictionary *extraBurnProperties;
	BOOL userCanceled;
	NSInteger currentType;
	NSArray *combinableTypes;
	NSString *imagePath;
	id currentCombineCheckBox;
	BOOL ignoreMode;
	BOOL isOverwritable;
	NSNumber *layerBreak;
}

//Main actions
- (void)beginBurnSetupSheetForWindow:(NSWindow *)window modalDelegate:(id)delegate didEndSelector:(SEL)selector contextInfo:(void *)contextInfo;
- (void)burnDiskImageAtPath:(NSString *)path;
- (void)writeTrack:(id)track;
- (void)setLayerBreak:(id)layerBreak;
- (void)burnTrack:(id)track;
- (void)burnTrackToImage:(NSDictionary *)dict;
- (NSInteger)getImageSizeAtPath:(NSString *)path;
- (void)updateDevice:(DRDevice *)device;
//Main Sheet actions
- (IBAction)burnButton:(id)sender;
- (IBAction)burnerPopup:(id)sender;
- (IBAction)cancelButton:(id)sender;
- (IBAction)closeButton:(id)sender;
- (IBAction)combineSessions:(id)sender;
//Session Panel actions
- (IBAction)okSession:(id)sender;
- (IBAction)cancelSession:(id)sender;
//Notification actions
- (void)statusChanged:(NSNotification *)notif;
- (void)mediaChanged:(NSNotification *)notification;
- (void)burnNotification:(NSNotification*)notification;
//Other actions
- (void)setIgnoreMode:(BOOL)mode;
- (void)prepareTypes;
- (void)setCombineBox:(id)box;
- (DRDevice *)currentDevice;
- (void)populateSpeeds:(DRDevice *)device;
- (DRDevice *)savedDevice;
- (BOOL)canBurn;
- (void)stopBurning:(NSNotification *)notif;
- (BOOL)isCD;
- (void)setType:(NSInteger)type;
- (void)setCombinableTypes:(NSArray *)types;
- (NSArray *)types;
- (NSInteger)currentType;
- (void)addBurnProperties:(NSDictionary *)properties;
- (NSDictionary *)properties;

@end

@interface DRCallbackDevice : DRDevice {}
- (void)initWithConsumer:(id)consumer;

@end