/* appController */

#import <Cocoa/Cocoa.h>
#import <DiscRecording/DiscRecording.h>
#import <KWEraser.h>
#import <KWProgress.h>
#import "KWPreferences.h"
#import "KWRecorderInfo.h"
#import "KWDiskInfo.h"
#import "KWEjecter.h"
#import "KWInspector.h"

@interface appController : NSObject
{
    //Menu Items
	//Burn Menu
	IBOutlet id preferencesBurn;
	//File Menu
	IBOutlet id fileMenu;
	IBOutlet id openFile;
	IBOutlet id closeFile;
	IBOutlet id saveAsFile;
    IBOutlet id saveImageFile;
	//Recorder Menu
	IBOutlet id eraseRecorder;
	IBOutlet id ejectRecorder;
	IBOutlet id burnRecorder;
	//Items Menu
	IBOutlet id addItems;
	IBOutlet id deleteItems;
	IBOutlet id createFolderItems;
	IBOutlet id mountImageItems;
	IBOutlet id scanDisksItems;
	//Window Menu
	IBOutlet id windowMenu;
	IBOutlet id minimizeWindow;
	IBOutlet id zoomWindow;
	IBOutlet id returnToDefaultSizeWindow;
	IBOutlet id burnWindow;
	IBOutlet id inspectorWindow;
	IBOutlet id mediaBrowserWindow;
	IBOutlet id recorderInfoWindow;
	IBOutlet id diskInfoWindow;
	IBOutlet id bringAllToFrontWindow;
    //Help Menu
	IBOutlet id itemHelp;
    
    //Variables
	KWPreferences *preferences;
	KWRecorderInfo *recorderInfo;
	KWDiskInfo *diskInfo;
	KWEjecter *ejecter;
	KWInspector *inspector;
	
	id currentObject;
	NSString *currentType;
}

//Menu Actions
//Burn Menu
- (IBAction)preferencesBurn:(id)sender;
//File Menu
- (IBAction)openFile:(id)sender;
//Recorder Menu
- (IBAction)eraseRecorder:(id)sender;
- (IBAction)ejectRecorder:(id)sender;
//Window Menu
- (IBAction)burnWindow:(id)sender;
- (IBAction)inspectorWindow:(id)sender;
- (IBAction)recorderInfoWindow:(id)sender;
- (IBAction)diskInfoWindow:(id)sender;
//Help Menu
- (IBAction)itemHelp:(id)sender;

//Notification Actions
- (void)controlMenus:(NSNotification *)notif;
- (void)closeWindow:(NSNotification *)notif;
- (void)changeBurnStatus:(NSNotification *)notif;
- (void)openPreferencesAndAddTheme:(NSNotification *)notif;

@end
