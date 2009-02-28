#import <Cocoa/Cocoa.h>
#import <DiscRecording/DiscRecording.h>
#import <KWProgress.h>
#import <KWBurner.h>
#import "KWDRFolder.h"
#import "KWTrackProducer.h"

@class TreeNode;

@interface dataController : NSObject 
{	
    //Main Window
	IBOutlet id	mainWindow;
	IBOutlet id	outlineView;
	IBOutlet id	fileSystemPopup;
	IBOutlet id	discName;
	IBOutlet id	totalSizeText;
	IBOutlet id	iconView;
	
	//Options menu
	IBOutlet id optionsPopup;
	
	//New folder sheet
	IBOutlet id	newFolderSheet;
	IBOutlet id	folderName;
	//Add to local
	IBOutlet id folderIcon;
	
	//Advanced Sheet
	IBOutlet id	advancedSheet;
	IBOutlet id	hfsSheet;
	IBOutlet id	isoSheet;
	IBOutlet id	jolietSheet;
	IBOutlet id	udfSheet;
	IBOutlet id	hfsStandardSheet;
	IBOutlet id	okSheet;
	
	//Disc creation
	IBOutlet id myDiscCreationController;
	
	//Variables
	TreeNode *treeData;
    NSArray *draggedNodes;
	NSString *lastSelectedItem;
	NSDictionary *discProperties;
	BOOL loadingBurnFile;
	NSArray *optionsMappings;
	NSMutableArray *temporaryFiles;
}

//Main actions
- (IBAction)openFiles:(id)sender;
- (void)addDroppedOnIconFiles:(NSArray *)paths;
- (void)addFiles:(NSArray *)paths removeFiles:(BOOL)remove;
- (IBAction)deleteFiles:(id)sender;
- (IBAction)newVirtualFolder:(id)sender;
- (void)setTotalSize;
- (float)totalSize;
- (void)updateFileSystem;
- (IBAction)dataPopupChanged:(id)sender;
- (IBAction)changeBaseName:(id)sender;

//Option menu actions
- (IBAction)accessOptions:(id)sender;
- (IBAction)setOption:(id)sender;

//New Folder Sheet actions
- (IBAction)ok:(id)sender;
- (IBAction)cancel:(id)sender;

//Advanced Sheet actions
- (IBAction)filesystemSelectionChanged:(id)sender;
- (IBAction)okSheet:(id)sender;
- (IBAction)cancelSheet:(id)sender;

//Disc creation actions
- (void)burn;
- (void)saveImage;
- (id)myTrack;
- (void)createVirtualFolder:(NSArray *)inputItems atPath:(NSString *)path;

//Save actions
- (void)saveDocument;
- (NSDictionary *)getSaveDictionary;
- (NSArray *)getFileArray:(NSArray *)items;
- (void)openBurnDocument:(NSString *)path;
- (void)loadSaveDictionary:(NSDictionary *)savedDictionary;
- (void)loadOutlineItems:(NSArray *)ar originalArray:(NSArray *)orAr;
- (NSDictionary *)saveDictionaryForObject:(DRFSObject *)object;
- (void)setPropertiesFor:(DRFSObject *)object fromDictionary:(NSDictionary *)dict;

//Other actions
- (void)setDiskName:(NSString *)name;
- (BOOL)isCombinable;
- (BOOL)isCompatible;
- (BOOL)isOnlyHFSPlus;
- (BOOL)isHFSStandardSupportedFile:(NSString *)file;
- (void)deleteTemporayFiles:(BOOL)needed;

//Outside variables
- (NSWindow*)window;
- (NSArray*)rootFiles;
- (KWDRFolder*)filesystemRoot;

//Outline actions
- (void)reloadOutlineView;
- (NSArray *)selectedDRFSObjects;
- (void)setOutlineViewState:(NSNotification *)notif;
- (IBAction)outlineViewAction:(id)sender;
- (BOOL)hasRows;

@end
