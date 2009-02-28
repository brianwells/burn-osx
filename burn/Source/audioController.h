/* audioController */

#import <Cocoa/Cocoa.h>
#import <DiscRecording/DiscRecording.h>
#import <QTKit/QTKit.h>
#import <KWProgress.h>
#import <KWConverter.h>
#import <KWDVDAuthorizer.h>
#import <KWBurner.h>

@interface audioController : NSObject
{
	//Main Window
	IBOutlet id mainWindow;
	IBOutlet id popupIcon;
	IBOutlet id discName;
	IBOutlet id totalTimeText;
	IBOutlet id previousButton;
	IBOutlet id playButton;
	IBOutlet id nextButton;
	IBOutlet id stopButton;
	IBOutlet id tableViewPopup;
	IBOutlet id tableView;
	id tableData;
	
	//Options menu
	IBOutlet id accessOptions;
	IBOutlet id audioOptionsPopup;
	IBOutlet id mp3OptionsPopup;
	
	//Disc creation
	IBOutlet id myDiscCreationController;
	
	//Variables
	NSArray *allowedFileTypes;
	NSArray *protectedFiles;
	NSMutableArray *AudioCDTableData;
	NSMutableArray *Mp3TableData;
	NSMutableArray *DVDAudioTableData;
	NSMutableArray *notCompatibleFiles;
	NSMutableArray *someProtected;
	#ifdef QTKIT_EXTERN
	QTMovie *movie;
	#endif
	int playingSong;
	int display;
	BOOL pause;
	BOOL cancelAddingFiles;
	NSTimer *displayTimer;
	int currentDropRow;
	KWProgress *progressPanel;
	KWConverter *converter;
	NSMutableDictionary *CDTextDict;
	KWDVDAuthorizer *DVDAuthorizer;
	NSMutableArray *temporaryFiles;
	
	NSArray *audioOptionsMappings;
	NSArray *mp3OptionsMappings;
}
//Main actions
- (IBAction)openFiles:(id)sender;
- (IBAction)deleteFiles:(id)sender;
- (void)addFile:(NSString *)path;
- (void)addDVDFolder:(NSString *)path;
- (void)checkFiles:(NSArray *)paths;
- (void)setCancelAdding;
- (BOOL)isProtected:(NSString *)path;
- (void)startThread:(NSArray *)paths;
- (void)showAlert;
- (void)convertFiles:(NSString *)path;
- (void)showConvertFailAlert:(NSArray *)descriptions;

//Option menu actions
- (IBAction)accessOptions:(id)sender;
- (IBAction)setOption:(id)sender;

//Disc creation actions
- (void)burn;
- (void)saveImage;
- (id)myTrackWithBurner:(KWBurner *)burner;
- (int)authorizeFolderAtPathIfNeededAtPath:(NSString *)path;

//Save actions
- (void)openBurnDocument:(NSString *)path;
- (void)saveDocument;

//Tableview actions
- (void)getTableView;
- (void)setTableViewState:(NSNotification *)notif;
- (IBAction)tableViewPopup:(id)sender;
- (BOOL)hasRows;
-(id)myDataSource;
- (NSString *) getRealPath:(NSString*)inPath;

//Player actions
- (IBAction)play:(id)sender;
- (IBAction)stop:(id)sender;
- (IBAction)back:(id)sender;
- (IBAction)forward:(id)sender;
- (IBAction)setDisplay:(id)sender;

//Other actions
- (NSArray *)getQuickTimeTypes;
- (BOOL)isMp3;
- (BOOL)isDVDAudio;
- (void)setTotal;
- (NSString *)totalTime;
- (float)totalSize;
- (int)getMovieDuration:(NSString *)path;
- (id)myCDTextDict;
- (DRFolder *)checkArray:(NSArray *)array forFolderWithName:(NSString *)name;
- (void)createVirtualFolderAtPath:(NSString *)path;
- (NSArray *)getSavePantherAudioCDArray;
- (BOOL)isCompatible;
- (BOOL)isCombinable:(BOOL)needAudioCDCheck;
- (BOOL)isAudioCD;
- (void)deleteTemporayFiles:(BOOL)needed;

//CD-Text actions
- (NSDictionary *)getBurnProperties;
- (id)createLayoutForBurn;
- (NSData*)mcnDataForDisc;
- (NSData*)isrcDataForTrack:(unsigned)index;
- (NSArray *)createCDTextArray;
- (NSDictionary *)getTrackInfo:(int)index;
- (NSDictionary *)getDiscInfo;

@end
