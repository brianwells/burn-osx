//
//  KWDiscCreator.h
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


@interface KWDiscCreator : NSObject 
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
	NSString *errorString;
}

//Sessions actions
- (IBAction)saveCombineSessions:(id)sender;

//Image actions
- (void)saveImageWithName:(NSString *)name withType:(NSInteger)type withFileSystem:(NSString *)fileSystem;
- (void)createImage:(NSDictionary *)dict;
- (void)showAuthorFailedOfType:(NSInteger)type;
- (void)imageFinished:(id)object;

//Burn actions
- (void)burnDiscWithName:(NSString *)name withType:(NSInteger)type;
- (void)burnSetupPanelEnded:(KWBurner *)myBurner returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;
- (void)burnTracks;
- (void)burnFinished:(NSNotification*)notif;

//Other actions
- (NSArray *)getCombinableFormats:(BOOL)needAudioCDCheck;
- (DRFSObject *)newDRFSObject:(DRFSObject *)object;
- (BOOL)waitForMediaIfNeeded;
- (void)stopWaiting;
- (void)restoreHiddenExtensions;
- (void)deleteTemporaryFiles;

@end