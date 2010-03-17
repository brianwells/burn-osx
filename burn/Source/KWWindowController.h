//
//  KWWindowController.h
//  Burn
//
//  Created by Maarten Foukhar on 08-10-09.
//  Copyright 2009 Kiwi Fruitware. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <DiscRecording/DiscRecording.h>
#import "KWEraser.h"
#import "KWEjecter.h"
#import "KWProgress.h"

@interface KWWindowController : NSObject 
{
	//Main outlets
	IBOutlet id burnButton;
	IBOutlet id defaultBurner;
	IBOutlet id mainTabView;
	IBOutlet id mainWindow;
	IBOutlet id newTabView;
	IBOutlet id itemHelp;
	
	//Toolbar related
	NSToolbar *toolbar;
	NSToolbarItem *mainItem;
	
	//Variables
	NSDictionary *myDeviceIdentifier;
	KWEraser *eraser;
	KWEjecter *ejecter;
	KWProgress *progressPanel;
	BOOL discInserted;
}

//Main window actions
- (IBAction)changeRecorder:(id)sender;
- (IBAction)showItemHelp:(id)sender;
- (IBAction)newTabViewAction:(id)sender;

//Menu actions
//File menu
- (IBAction)openFile:(id)sender;
//Recorder menu
- (IBAction)eraseRecorder:(id)sender;
- (IBAction)ejectRecorder:(id)sender;
//Window menu
- (IBAction)returnToDefaultSizeWindow:(id)sender;

//Notification actions
- (void)closeWindow:(NSNotification *)notification;
- (void)changeBurnStatus:(NSNotification *)notification;
- (void)mediaChanged:(NSNotification *)notification;

//Toolbar actions
- (void)setupToolbar;

//Other actions
- (NSString *)getRecorderDisplayNameForDevice:(DRDevice *)device;
- (void)open:(NSString *)pathname;

@end
