/* copyTab */

#import <Cocoa/Cocoa.h>
#import <DiscRecording/DiscRecording.h>
#import <KWProgress.h>
#import <KWDiskScanner.h>
#import <KWBurner.h>

@interface copyController : NSObject
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
	
	//Disc creation
	IBOutlet id myDiscCreationController;
	
	//Variables
	unsigned long blocks;
	NSTask *hdiutil;
	NSTask *cp;
	BOOL userCanceled;
	BOOL shouldBurn;
	NSTimer *timer;
	//Strings
	NSString *currentPath;
	NSString *mountedPath;
	NSString *imageMountedPath;
	NSString *savedPath;
	//Out little helpers
	KWProgress *progressPanel;
	KWDiskScanner* scanner;
	KWBurner *burner;
	
	NSMutableArray *temporaryFiles;
}

//Main actions
- (IBAction)openFiles:(id)sender;
- (IBAction)mountImage:(id)sender;
- (void)mount:(NSString *)path;
- (IBAction)scanDisks:(id)sender;
- (IBAction)clearDisk:(id)sender;
- (BOOL)checkImage:(NSString *)path;
- (BOOL)isImageMounted:(NSString *)path;
- (NSString *)formatDescription:(NSString *)format;

//Disc creation actions
- (void)burn;
- (void)saveImage;
- (id)myTrack;
- (void)remount:(id)object;

//Other actions
- (NSString *)myDisc;
- (float)totalSize;
- (BOOL)hasRows;
- (BOOL)isMounted;
- (BOOL)isRealDisk;
- (BOOL)isCompatible;
- (NSString *)getRealDevicePath:(NSString *)path;
- (void)stopHdiutil;
- (void)deviceUnmounted:(NSNotification *)notif;
- (void)deviceMounted:(NSNotification *)notif;
- (void)deleteTemporayFiles:(BOOL)needed;
- (BOOL)isCueFile;
- (BOOL)isAudioCD;

@end
