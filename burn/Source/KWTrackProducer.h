//
//  KWTrackProducer.h
//  Burn
//
//  Created by Maarten Foukhar on 26-11-08.
//  Copyright 2009 Kiwi Fruitware. All rights reserved.
//

#include <stdio.h>

#import <Cocoa/Cocoa.h>
#import <DiscRecording/DiscRecording.h>

@interface KWTrackProducer : NSObject 
{
	FILE     *file;
	NSFileHandle *readHandle;
	NSFileHandle *writeHandle;
	NSFileHandle *calcHandle;
	NSPipe *calcPipe;
	NSString *folderPath;
	NSString *discName;
	NSArray *mpegFiles;
	//Types 1 = hfsstandard; 2 = udf; 3 = dvd-video; 4 = vcd; 5 = svcd; 6 = audiocd 7 = dvd-audio
	int	type;
	BOOL createdTrack;
	NSTask *trackCreator;
	NSPipe *trackPipe;
	int currentImageSize;
	NSTimer *prepareTimer;
	NSString *currentAudioTrack;
}

//Track actions
- (NSArray *)getTracksOfCueFile:(NSString *)path;
- (DRTrack *)getTrackForImage:(NSString *)path withSize:(int)size;
- (DRTrack *)getTrackForFolder:(NSString *)path ofType:(int)imageType withDiscName:(NSString *)name withGlobalSize:(int)globalSize;
- (NSArray *)getTrackForVCDMPEGFiles:(NSArray *)files withDiscName:(NSString *)name ofType:(int)imageType;
- (NSArray *)getTracksOfLayout:(NSString *)layout withTotalSize:(int)size;
- (NSArray *)getTracksOfVcd;
- (NSArray *)getTracksOfAudioCD:(NSString *)path withToc:(NSDictionary *)toc;
- (DRTrack *)getAudioTrackForPath:(NSString *)path;

//Stream actions
- (void)createImage;
- (void)createVcdImage;
- (void)createAudioTrack:(NSString *)path withTrackSize:(int)trackSize;

//Other
- (float)imageSize;
- (DRTrack *)createDefaultTrackWithSize:(int)size;

@end
