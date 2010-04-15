/* copyTab */

#import <Cocoa/Cocoa.h>
#import <DiscRecording/DiscRecording.h>
#import <KWProgress.h>
#import <KWDiscScanner.h>
#import <KWBurner.h>

@interface KWCopyController : NSObject
{
    //Main Window
	IBOutlet id mainWindow;
	IBOutlet id nameField;
	IBOutlet id iconView;
	IBOutlet id sizeField;
	IBOutlet id fileSystemField;
	IBOutlet id mountButton;
	IBOutlet id dropView;
	IBOutlet id dropText;
	IBOutlet id clearDisk;
	IBOutlet id dropIcon;
	IBOutlet id browseButton;
	IBOutlet id mountMenu;
	
	//Disc creation
	IBOutlet id myDiscCreationController;
	
	//Variables
	unsigned long blocks;
	NSTask *hdiutil;
	NSTask *cp;
	BOOL userCanceled;
	BOOL shouldBurn;
	BOOL awakeFromNib;
	NSTimer *timer;
	//Strings
	NSString *currentPath;
	NSString *mountedPath;
	NSString *imageMountedPath;
	NSString *savedPath;
	//Out little helpers
	KWProgress *progressPanel;
	KWDiscScanner* scanner;
	KWBurner *burner;
	
	NSMutableArray *temporaryFiles;
}

//Main actions
- (IBAction)openFiles:(id)sender;
- (IBAction)mountDisc:(id)sender;
- (void)mount:(NSString *)path;
- (IBAction)scanDisks:(id)sender;
- (IBAction)clearDisk:(id)sender;
- (BOOL)checkImage:(NSString *)path;
- (BOOL)isImageMounted:(NSString *)path;

//Disc creation actions
- (void)burn:(id)sender;
- (void)saveImage:(id)sender;
- (id)myTrackWithErrorString:(NSString **)error andLayerBreak:(NSNumber**)layerBreak;
- (void)remount:(id)object;

//Other actions
- (NSString *)myDisc;
- (NSNumber *)totalSize;
- (int)numberOfRows;
- (BOOL)isMounted;
- (BOOL)isRealDisk;
- (BOOL)isCompatible;
- (NSString *)getRealDevicePath:(NSString *)path;
- (void)changeMountState:(BOOL)state forDevicePath:(NSString *)path;
- (void)deviceUnmounted:(NSNotification *)notif;
- (void)deviceMounted:(NSNotification *)notif;
- (void)deleteTemporayFiles:(BOOL)needed;
- (BOOL)isCueFile;
- (BOOL)isAudioCD;
- (int)cueImageSizeAtPath:(NSString *)path;
- (NSString *)getIsoForDvdFileAtPath:(NSString *)path;
- (NSNumber *)getLayerBreakForDvdFileAtPath:(NSString *)path;

@end