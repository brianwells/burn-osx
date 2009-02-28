#import <Cocoa/Cocoa.h>
#import <DiscRecording/DiscRecording.h>
#import <KWProgress.h>
#import <KWConverter.h>
#import <KWSVCDImager.h>
#import <KWDVDAuthorizer.h>
#import <KWBurner.h>

@interface videoController : NSObject
{
	//Main Window
    IBOutlet id mainWindow;
	IBOutlet id tableView;
	IBOutlet id tableViewPopup;
	IBOutlet id discName;
	IBOutlet id totalSizeText;
	IBOutlet id popupIcon;
	id tableData;
	
	//Options menu
	IBOutlet id accessOptions;
	//DVD
	IBOutlet id optionsPopupDVD;
	IBOutlet id optionsLoopDVD;
	IBOutlet id optionsForce43;
	IBOutlet id optionsForceMPEG2;
	IBOutlet id optionsMuxSeperate;
	IBOutlet id optionsRemuxMPEG2;
	IBOutlet id optionsUseTheme;
	//DivX
	IBOutlet id optionsPopupDIVX;
	IBOutlet id optionsForceDIVX;
		
	//Save View
	IBOutlet id saveView;
	IBOutlet id regionPopup;
	
	//Disc creation
	IBOutlet id myDiscCreationController;

	//Varables
	BOOL needToConvert;
	BOOL cancelAddingFiles;
	NSArray *allowedFileTypes;
	NSArray *protectedFiles;
	NSMutableArray *VCDTableData;
	NSMutableArray *SVCDTableData;
	NSMutableArray *DVDTableData;
	NSMutableArray *DIVXTableData;
	NSMutableArray *noRightVideoFiles;
	NSMutableArray *someProtected;
	int currentDropRow;
	KWProgress *progressPanel;
	KWConverter *converter;
	KWSVCDImager *SVCDImager;
	KWDVDAuthorizer *DVDAuthorizer;
	NSMutableArray *temporaryFiles;
}

//Main actions
- (IBAction)openFiles:(id)sender;
- (IBAction)deleteFiles:(id)sender;
- (void)addFile:(NSString *)path isSelfEncoded:(BOOL)selfEncoded;
- (void)addDVDFolder:(NSString *)path;
- (void)checkFiles:(NSArray *)paths;
- (void)setCancelAdding;
- (BOOL)isProtected:(NSString *)path;
- (void)startThread:(NSArray *)paths;
- (void)showAlert;

//Option menu actions
- (IBAction)accessOptions:(id)sender;
//DVD
- (IBAction)optionsLoopDVD:(id)sender;
- (IBAction)optionsForce43:(id)sender;
- (IBAction)optionsForceMPEG2:(id)sender;
- (IBAction)optionsMuxSeperate:(id)sender;
- (IBAction)optionsRemuxMPEG2:(id)sender;
- (IBAction)optionsUseTheme:(id)sender;
//DivX
- (IBAction)optionsForceDIVX:(id)sender;

//Disc creation actions
- (void)burn;
- (void)saveImage;
- (id)myTrack;
- (int)authorizeFolderAtPathIfNeededAtPath:(NSString *)path;

//Save actions
- (void)openBurnDocument:(NSString *)path;
- (void)saveDocument;

//Tableview actions
- (void)getTableView;
- (void)setTableViewState:(NSNotification *)notif;
- (IBAction)changePopup:(id)sender;
- (void)selectPopupTitle:(NSString *)title;
- (BOOL)hasRows;
-(id)myDataSource;

//Other actions
- (NSArray *)files;
- (NSString *)discName;
- (BOOL)isDVDVideo;
- (NSArray *)getQuickTimeTypes;
- (void)calculateTotalSize;
- (float)totalSize;
- (BOOL)isCombinable;
- (NSString *)getRealPath:(NSString *)inPath;
- (void)deleteTemporayFiles:(BOOL)needed;

@end
