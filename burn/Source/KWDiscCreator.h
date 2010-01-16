//
//  discCreationController.h
//  Burn
//
//  Created by Maarten Foukhar on 15-11-08.
//  Copyright 2009 Kiwi Fruitware. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <DiscRecording/DiscRecording.h>
#import <KWBurner.h>
#import <KWProgress.h>
#import "KWDRFolder.h"


@interface discCreationController : NSObject 
{
//Main outlets
	IBOutlet id mainWindow;
	IBOutlet id mainTabView;
	
	//Controllers
	IBOutlet id dataControllerOutlet;
	IBOutlet id audioControllerOutlet;
	IBOutlet id videoControllerOutlet;
	IBOutlet id copyControllerOutlet;
	
	//Sessions outlets
	IBOutlet id saveCombineSessions;
	IBOutlet id saveImageView;
	
	//Variables
	KWBurner *burner;
	KWProgress *progressPanel;
	BOOL isBurning;
	NSString *discName;
	NSString *imagePath;
	BOOL hiddenExtension;
	NSMutableArray *extensionHiddenArray;
	BOOL shouldWait;
}

//Sessions actions
- (IBAction)saveCombineSessions:(id)sender;

//Image actions
- (void)saveImageWithName:(NSString *)name withType:(int)type withFileSystem:(NSString *)fileSystem;
- (void)createImage:(NSDictionary *)dict;
- (void)showAuthorFailedOfType:(int)type;
- (void)imageFinished:(id)object;

//Burn actions
- (void)burnDiscWithName:(NSString *)name withType:(int)type;
- (void)burnSetupPanelEnded:(KWBurner *)myBurner returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void)burnTracks;
- (void)burnFinished:(NSNotification*)notif;

//Other actions
- (NSArray *)getCombinableFormats:(BOOL)needAudioCDCheck;
- (DRFSObject *)newDRFSObject:(DRFSObject *)object;
- (BOOL)waitForMediaIfNeeded;
- (void)stopWaiting;

@end
