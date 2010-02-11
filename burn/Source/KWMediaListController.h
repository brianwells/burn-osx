//
//  KWMediaListController.h
//  Burn
//
//  Created by Maarten Foukhar on 13-09-09.
//  Copyright 2009 Kiwi Fruitware. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <KWProgress.h>
#import <KWConverter.h>
#import <KWBurner.h>
#import "KWMediaListController.h"
#import "KWTextField.h"

@interface KWMediaListController : NSObject {

	//Main Window
	IBOutlet id mainWindow;
	IBOutlet id popupIcon;
	IBOutlet id discName;
	IBOutlet id discLabel;
	IBOutlet id totalText;
	IBOutlet id tableViewPopup;
	IBOutlet id tableView;
	IBOutlet id accessOptions;
	
	//Disc creation
	IBOutlet id myDiscCreationController;
	
	//Save View
	IBOutlet id saveView;
	IBOutlet id regionPopup;
	
	//Variables
	NSMutableArray *tableData;
	NSMutableArray *incompatibleFiles;
	NSMutableArray *protectedFiles;
	NSMutableArray *knownProtectedFiles;
	NSMutableArray *temporaryFiles;
	NSArray *allowedFileTypes;
	NSArray *optionsMappings;
	NSString *dvdFolderName;
	NSString *convertExtension;
	int convertKind;
	NSString *currentFileSystem;
	BOOL useRegion;
	BOOL isDVD;
	BOOL canBeReorderd;
	BOOL cancelAddingFiles;
	int currentDropRow;
	int currentType;
	KWProgress *progressPanel;
	KWConverter *converter;
	id optionsPopup;
}

//Main actions
//Show a open panel to add files
- (IBAction)openFiles:(id)sender;
//Delete the selected row(s)
- (IBAction)deleteFiles:(id)sender;
//Bogusmethod used in subclass
- (void)addFile:(NSString *)path isSelfEncoded:(BOOL)selfEncoded;
//Add a DVD-Folder and delete the rest
- (void)addDVDFolder:(NSString *)path;
//Check files in a seperate thread
- (void)checkFiles:(NSArray *)paths;
//Set our BOOL to stop the checking thread
- (void)setCancelAdding;
//Check if it is QuickTime protected file
- (BOOL)isProtected:(NSString *)path;

//Option menu actions
//Setup options menu and open the right popup
- (IBAction)accessOptions:(id)sender;
//Set option in the preferences
- (IBAction)setOption:(id)sender;

//Convert actions
//Convert files to path
- (void)convertFiles:(NSString *)path;
//Show an alert if needed (protected or no default files
- (void)showAlert;
//Show an alert if some files failed to be converted
- (void)showConvertFailAlert:(NSString *)errorString;

//Disc creation actions
//Burn the disc
- (void)burn:(id)sender;
//Save a image
- (void)saveImage:(id)sender;
//Bogusmethod used in subclass
- (id)myTrackWithBurner:(KWBurner *)burner errorString:(NSString **)error;

//Save actions
//Open .burn document
- (void)openBurnDocument:(NSString *)path;
//Save .burn document
- (void)saveDocument:(id)sender;

//Tableview actions
//Bogusmethod used in subclass
- (IBAction)tableViewPopup:(id)sender;
//Method used in subclass to sort if needed
- (void)sortIfNeeded;

//Other actions
//Check for rows
- (int)numberOfRows;
//Use QuickTime c method to get filetypes (works for Panther)
- (NSArray *)getQuickTimeTypes;
//Set total size or time
- (void)setTotal;
//Get the total size
- (NSNumber *)totalSize;
//Find name in array of folders
- (DRFolder *)checkArray:(NSArray *)array forFolderWithName:(NSString *)name;
//Use some c to get the real path
- (NSString *)getRealPath:(NSString *)inPath;
//Return tableData to external objects
- (NSMutableArray *)myDataSource;

@end
