//
//  DSAppController.h
//
//  Created by Maarten Foukhar on 14-06-10.
//  Copyright 2010 Kiwi Fruitware. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface DSAppController : NSObject 
{
	//Main window
	IBOutlet id mainWindow;
	IBOutlet id mpegIcon;
	IBOutlet id mpegName;
	IBOutlet id subIcon;
	IBOutlet id subName;
	
	//Progress Sheet
	IBOutlet id progressSheet;
	IBOutlet id taskText;
	IBOutlet id progressIndicator;
	IBOutlet id statusText;
	
	//Subsettings
	IBOutlet id subSettingsView;
	IBOutlet id fontPopup;
	IBOutlet id fontSize;
	
	//Variables
	NSArray *mpegTypes;
	NSArray *subTypes;
	NSString *mpegPath;
	NSString *subPath;
	NSString *filePath;
	NSString *xmlPath;
	NSString *xmlContent;
	BOOL hiddenExtension;
	NSTask *spumux;
	NSTimer *timer;
}

//Main actions
- (IBAction)chooseMPEGFile:(id)sender;
- (void)openMpegFile:(NSString *)path;
- (IBAction)chooseSubFile:(id)sender;
- (void)openSubFile:(NSString *)path;
- (IBAction)saveFile:(id)sender;

//Sheet actions
- (IBAction)cancelProgress:(id)sender;

//Other actions
- (int)OSVersion;
- (void)openFiles:(NSArray *)files;

@end
