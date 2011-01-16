//
//  KWAudioController.h
//  Burn
//
//  Created by Maarten Foukhar on 13-09-09.
//  Copyright 2009 Kiwi Fruitware. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KWMediaListController.h"
#import <KWDVDAuthorizer.h>
#ifdef USE_QTKIT
#import <QTKit/QTKit.h>
#endif

@interface KWAudioController : KWMediaListController {

	//Main Window
	IBOutlet id previousButton;
	IBOutlet id playButton;
	IBOutlet id nextButton;
	IBOutlet id stopButton;
	
	//Options menu
	IBOutlet id audioOptionsPopup;
	IBOutlet id mp3OptionsPopup;
	
	//Variables
	NSMutableArray *audioTableData;
	NSMutableArray *mp3TableData;
	NSMutableArray *dvdTableData;
	#ifdef QTKIT_EXTERN
	QTMovie *movie;
	#endif
	NSInteger playingSong;
	NSInteger display;
	BOOL pause;
	NSTimer *displayTimer;
	KWDVDAuthorizer *DVDAuthorizer;
	
	NSArray *audioOptionsMappings;
	NSArray *mp3OptionsMappings;
	NSDictionary *cueMappings;
	
	NSMutableArray *tracks;
	#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_4
	DRCDTextBlock *cdtext;
	#endif
}

//Main actions
- (void)addFile:(id)file isSelfEncoded:(BOOL)selfEncoded;
- (IBAction)changeDiscName:(id)sender;

//Disc creation actions
//Create a track for burning
- (id)myTrackWithBurner:(KWBurner *)burner errorString:(NSString **)error;
- (NSInteger)authorizeFolderAtPathIfNeededAtPath:(NSString *)path errorString:(NSString **)error;

//Player actions
- (IBAction)play:(id)sender;
- (IBAction)stop:(id)sender;
- (IBAction)back:(id)sender;
- (IBAction)forward:(id)sender;
- (IBAction)setDisplay:(id)sender;
- (void)setDisplayText;

//Other actions
//Set total size or time
- (void)setTotal;
//Calculate and return total time as string
- (NSString *)totalTime;
//Get movie duration using NSMovie so it works in Panther too
- (NSInteger)getMovieDuration:(NSString *)path;
//Check if the disc can be combined
- (BOOL)isCombinable;
//Check if the disc is a Audio CD disc
- (BOOL)isAudioCD;
//Change the inspector when selecting volume label
- (void)volumeLabelSelected:(NSNotification *)notif;
//Get string which can be saved as cue file
- (NSString *)cueStringWithBinFile:(NSString *)binFile;

//External actions
#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_4
- (BOOL)hasCDText;
- (DRCDTextBlock *)myTextBlock;
#endif
- (NSMutableArray *)myTracks;

@end