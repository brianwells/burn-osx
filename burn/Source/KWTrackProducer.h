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
	NSFileHandle *fileHandle;
	NSString *folderPath;
	NSString *discName;
	NSArray *mpegFiles;
	//Types 1 = hfsstandard; 2 = udf; 3 = dvd-video; 4 = vcd; 5 svcd
	int	type;
	BOOL createdTrack;
	NSTask *imageCreator;
	NSPipe *imagePipe;
}

//Track actions
- (NSArray *)getTracksOfCueFile:(NSString *)path;
- (DRTrack *)getTrackForImage:(NSString *)path withSize:(int)size;
- (DRTrack *)getTrackForFolder:(NSString *)path ofType:(int)imageType withDiscName:(NSString *)name;
- (NSArray *)getTrackForVCDMPEGFiles:(NSArray *)files withDiscName:(NSString *)name ofType:(int)imageType;
- (NSArray *)getTracksOfLayout:(NSString *)layout withTotalSize:(int)size;
- (NSArray *)getTracksOfVcd;

- (NSArray *)getTracksOfAudioCD:(NSString *)path withToc:(NSDictionary *)toc;

//Stream actions
- (void)createImage;
- (void)createVcdImage;

//Other
- (int)imageSize;
- (DRTrack *)createDefaultTrackWithSize:(int)size;

@end
