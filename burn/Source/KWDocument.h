/* KWDocument */

#import <Cocoa/Cocoa.h>
#import <DiscRecording/DiscRecording.h>
#import <KWEraser.h>
#import <KWProgress.h>

@interface KWDocument : NSDocument
{
    //Main outlets
	IBOutlet id burnButton;
	IBOutlet id defaultBurner;
	IBOutlet id mainTabView;
	IBOutlet id mainWindow;
	NSToolbar *toolbar;
	NSToolbarItem *mainItem;
	IBOutlet id tabView;
	IBOutlet id newTabView;
	
	//Controllers
	IBOutlet id dataControllerOutlet;
	IBOutlet id audioControllerOutlet;
	IBOutlet id videoControllerOutlet;
	IBOutlet id copyControllerOutlet;
	
	//Variables
	NSDictionary *myDeviceIdentifier;
	KWEraser *eraser;
	KWProgress *progressPanel;
	BOOL discInserted;
}
//Main window actions
- (IBAction)changeRecorder:(id)sender;
- (IBAction)showItemHelp:(id)sender;
- (IBAction)newTabViewAction:(id)sender;

//Menu actions
//File menu
- (void)openFile:(id)sender;
- (void)saveAsFile:(id)sender;
- (void)saveImage:(id)sender;
//Recorder menu
- (void)eraseRecorder:(id)sender;
- (IBAction)burnRecorder:(id)sender;
//Items menu
- (void)addItems:(id)sender;
- (void)deleteItems:(id)sender;
- (void)createFolderItems:(id)sender;
- (void)mountImageItems:(id)sender;
- (void)scanDiscsItems:(id)sender;
//Window menu
- (void)returnToDefaultSize:(id)sender;

//Notification actions
- (void)closeWindow:(NSNotification *)notification;
- (void)changeBurnStatus:(NSNotification *)notification;
- (void)mediaChanged:(NSNotification *)notification;

//Application actions
- (BOOL)isAudioMP3;
- (BOOL)isImageCompatible;
- (BOOL)isImageMounted;
- (BOOL)isImageRealDisk;
- (BOOL)dataHasRows;
- (BOOL)audioHasRows;
- (BOOL)videoHasRows;
- (BOOL)copyHasRows;

//Toolbar actions
- (void)setupToolbar;

//Other actions
- (NSString *)getRecorderDisplayNameForDevice:(DRDevice *)device;
- (void)openDocument:(NSString *)pathname;
- (NSString *)currentTabviewItem;
- (id)currentController;

@end
