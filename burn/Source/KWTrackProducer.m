//
//  KWTrackProducer.m
//  Burn
//
//  Created by Maarten Foukhar on 26-11-08.
//  Copyright 2009 Kiwi Fruitware. All rights reserved.
//

#include <stdio.h>

#import "KWTrackProducer.h"
#import "NSScanner-Extra.h"
#import "KWCommonMethods.h"
#import "KWConverter.h"

@interface KWTrackProducer (DiscRecording)

- (BOOL) prepareTrack:(DRTrack*)track forBurn:(DRBurn*)burn toMedia:(NSDictionary*)mediaInfo;
- (uint32_t)producePreGapForTrack:(DRTrack *)track intoBuffer:(char *)buffer length:(uint32_t)bufferLength atAddress:(uint64_t)address blockSize:(uint32_t)blockSize ioFlags:(uint32_t *)flags;
- (uint32_t)produceDataForTrack:(DRTrack *)track intoBuffer:(char *)buffer length:(uint32_t)bufferLength atAddress:(uint64_t)address blockSize:(uint32_t)blockSize ioFlags:(uint32_t *)flags;

@end


@implementation KWTrackProducer (DiscRecording)

- (BOOL)prepareTrack:(DRTrack*)track forBurn:(DRBurn*)burn toMedia:(NSDictionary*)mediaInfo
{
	if (folderPath)
	{
	[self createImage];
	}
	else if ((type == 4 | type == 5) && createdTrack == NO)
	{
	[self createVcdImage];
	createdTrack = YES;
	}
	else if (type == 6)
	{
	NSMutableDictionary *trackProperties = [[track properties] mutableCopy];
	
	[trackProperties setObject:[NSNumber numberWithInt:[[trackProperties objectForKey:DRTrackLengthKey] intValue] + 1] forKey:DRTrackLengthKey]; 
	[track setProperties:trackProperties];
	[self createAudioTrack:[[track properties] objectForKey:@"KWAudioPath"] withTrackSize:[[[track properties] objectForKey:DRTrackLengthKey] intValue]];
	}

return YES;
}

- (uint32_t)producePreGapForTrack:(DRTrack *)track intoBuffer:(char *)buffer length:(uint32_t)bufferLength atAddress:(uint64_t)address blockSize:(uint32_t)blockSize ioFlags:(uint32_t *)flags
{
	if ([[[track properties] objectForKey:@"KWFirstTrack"] boolValue] == NO)
	{
	uint32_t i;
	unsigned char newbuffer[bufferLength];
	
		for (i = 0; i < bufferLength; i+= blockSize)
		{
		fread(newbuffer, 1, blockSize, file);
		}
	}

memset(buffer, 0, bufferLength);
	
return bufferLength;
}

- (uint32_t)produceDataForTrack:(DRTrack *)track intoBuffer:(char *)buffer length:(uint32_t)bufferLength atAddress:(uint64_t)address blockSize:(uint32_t)blockSize ioFlags:(uint32_t *)flags
{
	currentAudioTrack = [[track properties] objectForKey:@"KWAudioPath"];

	if (file)
	{
	uint32_t i;
	
		for (i = 0; i < bufferLength; i+= blockSize)
		{
		fread(buffer, 1, blockSize, file);
		buffer += blockSize;
		}
	}

return bufferLength;
}

- (void)cleanupTrackAfterBurn:(DRTrack*)track;
{
fclose(file);
	
	if (folderPath)
	{
	[folderPath release];
	folderPath = nil;
	}
	
	if (discName)
	{
	[discName release];
	discName = nil;
	}
	
	if (mpegFiles)
	{
	[mpegFiles release];
	mpegFiles = nil;
	}
}

@end

@implementation KWTrackProducer

///////////////////
// Track actions //
///////////////////

#pragma mark -
#pragma mark •• Track actions

- (NSArray *)getTracksOfCueFile:(NSString *)path
{
NSString *binPath= [[path stringByDeletingPathExtension] stringByAppendingPathExtension:@"bin"];
file = fopen([binPath fileSystemRepresentation], "r");

return [self getTracksOfLayout:[NSString stringWithContentsOfFile:path] withTotalSize:[[[NSFileManager defaultManager] fileAttributesAtPath:binPath traverseLink:YES] fileSize]];
}

- (DRTrack *)getTrackForImage:(NSString *)path withSize:(int)size
{
file = fopen([path fileSystemRepresentation], "r");

int fileSize;

	if (size > 0)
	fileSize = size;
	else
	fileSize = [[[NSFileManager defaultManager] fileAttributesAtPath:path traverseLink:YES] fileSize] / 2048;

return [self createDefaultTrackWithSize:fileSize];
}

- (DRTrack *)getTrackForFolder:(NSString *)path ofType:(int)imageType withDiscName:(NSString *)name
{
type = imageType;
folderPath = [path copy];
discName = [name copy];

return [self createDefaultTrackWithSize:[self imageSize]];
}

- (NSArray *)getTrackForVCDMPEGFiles:(NSArray *)files withDiscName:(NSString *)name ofType:(int)imageType
{
discName = [name copy];
mpegFiles = [files copy];
type = imageType;
createdTrack = NO;

return [self getTracksOfVcd];
}

- (NSArray *)getTracksOfLayout:(NSString *)layout withTotalSize:(int)size
{
NSMutableArray *array = [NSMutableArray array];
NSScanner *scanner   = [NSScanner scannerWithString:layout];
	
	int totalSize;
	if ([layout rangeOfString:@"2048"].length > 0)
	totalSize = size / 2048;
	else if ([layout rangeOfString:@"2336"].length > 0)
	totalSize = size / 2336;
	else if ([layout rangeOfString:@"2352"].length > 0)
	totalSize = size / 2336;
	
	if (![scanner skipPastString:@"BINARY"])
	{
		if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWDebug"] == YES)
		NSLog(@"Could not find BINARY marker.");
	return nil;
	}
						
BOOL done     = NO;
int  savedGap = 150;
BOOL firstTrack = YES;
	
	while (!done)
	{
	int m, s, f;
		
	int trackID;
	int length;
	int pregap = savedGap;
	int blockType;
	int dataForm;
	int trackMode;
	int sessionFormat;
	int blockSize = 0;
		
		if (![scanner skipPastString:@"TRACK"])
		break;
		
		if (![scanner scanInt:&trackID])
		{
			if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWDebug"] == YES)
			NSLog(@"Could not parse track number.");
		return nil;
		}
		
		if ([scanner scanString:@"MODE1" intoString:nil])
		{
			if ([scanner scanString:@"2048" intoString:nil])
			{
			blockType     = kDRBlockTypeMode1Data;
			dataForm      = kDRDataFormMode1Data;
			trackMode     = kDRTrackMode1Data;
			sessionFormat = kDRSessionFormatMode1Data;
			blockSize     = kDRBlockSizeMode1Data;
			}
			else
			{
			blockType     = 8;
			dataForm      = 17;
			trackMode     = 4;
			sessionFormat = 0;
			blockSize     = 2352;
			}
		
		}
		else if ([scanner scanString:@"MODE2" intoString:nil])
		{
			if ([scanner scanString:@"2336" intoString:nil])
			{
			blockType     = 9;
			dataForm      = 48;
			trackMode     = 4;
			sessionFormat = 32;
			blockSize     = 2336;
			}
			else
			{
			blockType     = 12;
			dataForm      = 33;
			trackMode     = 4;
			sessionFormat = 32;
			blockSize     = 2352;
			}
		}
		else
		{
			if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWDebug"] == YES)
			NSLog(@"Unknown track type.");
		return nil;
		}
			
		if (![scanner skipPastString:@"INDEX 01"])
		{
			if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWDebug"] == YES)
			NSLog(@"Could not determine track starting time.");
		return nil;
		}
		
		if (![scanner scanInt:&m]) break;
		if (![scanner skipPastString:@":"]) break;
		if (![scanner scanInt:&s]) break;
		if (![scanner skipPastString:@":"]) break;
		if (![scanner scanInt:&f]) break;
		
		int startTime = (m * 60 + s) * 75 + f;
		unsigned location = [scanner scanLocation];
		
		if ([scanner skipPastString:@"INDEX 00"])
		{
			if (![scanner scanInt:&m]) break;
			if (![scanner skipPastString:@":"]) break;
			if (![scanner scanInt:&s]) break;
			if (![scanner skipPastString:@":"]) break;
			if (![scanner scanInt:&f]) break;
			
		int time = (m * 60 + s) * 75 + f;
		length   = time - startTime;
			
			if ([scanner skipPastString:@"INDEX 01"])
			{
				if (![scanner scanInt:&m]) break;
				if (![scanner skipPastString:@":"]) break;
				if (![scanner scanInt:&s]) break;
				if (![scanner skipPastString:@":"]) break;
				if (![scanner scanInt:&f]) break;
				
			savedGap   = (m * 60 + s) * 75 + f - time;
			}
			
		[scanner setScanLocation:location];
		}
		else
		{
		length = totalSize - startTime;
		done = YES;
		}
		
	DRTrack *track = [[[DRTrack alloc] initWithProducer:self] autorelease];
	NSMutableDictionary *dict  = [NSMutableDictionary dictionary];
	[dict setObject:[DRMSF msfWithFrames:length] forKey:DRTrackLengthKey];
	[dict setObject:[DRMSF msfWithFrames:pregap] forKey:DRPreGapLengthKey];
	[dict setObject:[NSNumber numberWithInt:blockSize] forKey:DRBlockSizeKey];
	[dict setObject:[NSNumber numberWithInt:blockType] forKey:DRBlockTypeKey];
	[dict setObject:[NSNumber numberWithInt:dataForm] forKey:DRDataFormKey];
	[dict setObject:[NSNumber numberWithInt:sessionFormat] forKey:DRSessionFormatKey];
	[dict setObject:[NSNumber numberWithInt:trackMode] forKey:DRTrackModeKey];
	[dict setObject:DRSCMSCopyrightFree forKey:DRSerialCopyManagementStateKey];
	
		if (firstTrack == YES)
		{
		[dict setObject:[NSNumber numberWithBool:YES] forKey:@"KWFirstTrack"];
		firstTrack = NO;
		}
		
	[track setProperties:dict];
	[array addObject:track];

		if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWDebug"] == YES)
		NSLog(@"%@", [[track properties] description]);
	}

return array;
}

- (NSArray *)getTracksOfVcd
{
NSMutableArray *arguments = [NSMutableArray array];
[arguments addObject:@"-t"];
	if (type == 4)
	[arguments addObject:@"vcd2"];
	else if (type == 5)
	[arguments addObject:@"svcd"];
[arguments addObject:@"--update-scan-offsets"];
[arguments addObject:@"-l"];
[arguments addObject:discName];
[arguments addObject:[@"--cue-file=" stringByAppendingString:@"/dev/fd/1"]];
[arguments addObject:[@"--bin-file=" stringByAppendingString:@"/dev/fd/2"]];

	int i;
	for (i=0;i<[mpegFiles count];i++)
	{
	[arguments addObject:[mpegFiles objectAtIndex:i]];
	}

NSTask *vcdimager = [[NSTask alloc] init];
[vcdimager setLaunchPath:[[NSBundle bundleForClass:[self class]] pathForResource:@"vcdimager" ofType:@""]];
[vcdimager setArguments:arguments];
NSPipe *pipe=[[NSPipe alloc] init];
NSPipe *pipe2=[[NSPipe alloc] init];
[vcdimager setStandardError:pipe];
[vcdimager setStandardOutput:pipe2];
NSFileHandle *handle=[pipe fileHandleForReading];
NSFileHandle *handle2=[pipe2 fileHandleForReading];
[vcdimager launch];

NSData *data;
int size = 0;

NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];

	while([data=[handle availableData] length])
	{
	size = size + [data length];
	data = nil;
	
	[innerPool release];
	innerPool = [[NSAutoreleasePool alloc] init];
	}

NSString *string=[[NSString alloc] initWithData:[handle2 readDataToEndOfFile] encoding:NSASCIIStringEncoding];

[vcdimager waitUntilExit];

[pipe release];
[pipe2 release];
[vcdimager release];

return [self getTracksOfLayout:string withTotalSize:size];
}

- (NSArray *)getTracksOfAudioCD:(NSString *)path withToc:(NSDictionary *)toc
{
file = fopen([path fileSystemRepresentation], "r");
NSArray *sessions = [toc objectForKey:@"Sessions"];
NSMutableArray *mySessions = [NSMutableArray array];
NSMutableArray *myTracks = [NSMutableArray array];

	int i = 0;
	for (i=0;i<[sessions count];i++)
	{
	NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
	
	NSNumber *leadout = [[sessions objectAtIndex:i] objectForKey:@"Leadout Block"]; 
	NSArray *tracks = [[sessions objectAtIndex:i] objectForKey:@"Track Array"];
	
		int x = 0;
		for (x=0;x<[tracks count];x++)
		{
		NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
		
		int size;
		
			if (x + 1 < [tracks count])
			size = [[[tracks objectAtIndex:x + 1] objectForKey:@"Start Block"] intValue] - [[[tracks objectAtIndex:x] objectForKey:@"Start Block"] intValue];
			else
			size = [leadout intValue] -  [[[tracks objectAtIndex:x] objectForKey:@"Start Block"] intValue];
		
		DRTrack *track = [[DRTrack alloc] initWithProducer:self];
		NSMutableDictionary *dict = [NSMutableDictionary dictionary];
		
			if (x == 0)
			{
			[dict setObject:[NSNumber numberWithBool:YES] forKey:@"KWFirstTrack"];
			[dict setObject:[DRMSF msfWithFrames:150] forKey:DRPreGapLengthKey];
			}
			else
			{
			[dict setObject:[NSNumber numberWithBool:YES] forKey:@"KWFirstTrack"];
			[dict setObject:[DRMSF msfWithFrames:0] forKey:DRPreGapLengthKey];
			}
		
		[dict setObject:[DRMSF msfWithFrames:size] forKey:DRTrackLengthKey];
		[dict setObject:[NSNumber numberWithInt:2352] forKey:DRBlockSizeKey];
		[dict setObject:[NSNumber numberWithInt:0] forKey:DRBlockTypeKey];
		[dict setObject:[NSNumber numberWithInt:0] forKey:DRDataFormKey];
		[dict setObject:[NSNumber numberWithInt:0] forKey:DRSessionFormatKey];
		[dict setObject:[NSNumber numberWithInt:0] forKey:DRTrackModeKey];
		[dict setObject:[[tracks objectAtIndex:x] objectForKey:@"Pre-Emphasis Enabled"] forKey:DRAudioPreEmphasisKey];
		
		[track setProperties:dict];
		
		[myTracks addObject:track];
		
		[innerPool release];
		}
	
	[mySessions addObject:myTracks];
	
	[innerPool release];
	}

return myTracks;
}

- (DRTrack *)getAudioTrackForPath:(NSString *)path
{
//Set disc: type 6 = custom audio cd
type = 6;

//Create our audio track
DRTrack *track = [[DRTrack alloc] initWithProducer:self];
NSMutableDictionary *properties = [NSMutableDictionary dictionary];
		
[properties setObject:[DRMSF msfWithString:[[KWConverter alloc] mediaTimeString:path]] forKey:DRTrackLengthKey];
[properties setObject:[NSNumber numberWithInt:2352] forKey:DRBlockSizeKey];
[properties setObject:[NSNumber numberWithInt:0] forKey:DRBlockTypeKey];
[properties setObject:[NSNumber numberWithInt:0] forKey:DRDataFormKey];
[properties setObject:[NSNumber numberWithInt:0] forKey:DRSessionFormatKey];
[properties setObject:[NSNumber numberWithInt:0] forKey:DRTrackModeKey];
[properties setObject:path forKey:@"KWAudioPath"];
[properties setObject:[NSNumber numberWithBool:YES] forKey:@"KWFirstTrack"];
[properties setObject:DRVerificationTypeNone forKey:DRVerificationTypeKey];
		
[track setProperties:properties];

return track;
}

////////////////////
// Stream actions //
////////////////////

#pragma mark -
#pragma mark •• Stream actions

- (void)createImage
{
trackCreator = [[NSTask alloc] init];
trackPipe=[[NSPipe alloc] init];
NSFileHandle *handle2 = [NSFileHandle fileHandleWithNullDevice];
[trackCreator setStandardError:handle2];
[trackCreator setLaunchPath:[[NSBundle mainBundle] pathForResource:@"mkisofs" ofType:@""]];

NSArray *options;

	if (type == 1)
	options = [NSArray arrayWithObjects:@"-V",discName,@"-f",@"-hfs",@"--osx-hfs",@"-r",@"-joliet",folderPath,nil];
	else if (type == 2)
	options = [NSArray arrayWithObjects:@"-V",discName,@"-f",@"-udf",folderPath,nil];
	else if (type == 3)
	options = [NSArray arrayWithObjects:@"-V",discName,@"-f",@"-dvd-video",folderPath,nil];
	else if (type == 7)
	options = [NSArray arrayWithObjects:@"-V",discName,@"-f",@"-dvd-audio",folderPath,nil];
	
[trackCreator setArguments:options];
[trackCreator setStandardOutput:trackPipe];
readHandle=[trackPipe fileHandleForReading];
file = fdopen([readHandle fileDescriptor], "r");

[NSThread detachNewThreadSelector:@selector(startCreating) toTarget:self withObject:nil];
}

- (void)createVcdImage
{
NSMutableArray *arguments = [NSMutableArray array];
[arguments addObject:@"-t"];
	if (type == 4)
	[arguments addObject:@"vcd2"];
	else if (type == 5)
	[arguments addObject:@"svcd"];
[arguments addObject:@"--update-scan-offsets"];
[arguments addObject:@"-l"];
[arguments addObject:discName];
[arguments addObject:[@"--cue-file=" stringByAppendingString:@"/dev/fd/1"]];
[arguments addObject:[@"--bin-file=" stringByAppendingString:@"/dev/fd/2"]];

	int i;
	for (i=0;i<[mpegFiles count];i++)
	{
	[arguments addObject:[mpegFiles objectAtIndex:i]];
	}

trackCreator = [[NSTask alloc] init];
[trackCreator setLaunchPath:[[NSBundle bundleForClass:[self class]] pathForResource:@"vcdimager" ofType:@""]];
[trackCreator setArguments:arguments];
trackPipe=[[NSPipe alloc] init];
NSFileHandle *handle2 = [NSFileHandle fileHandleWithNullDevice];
[trackCreator setStandardError:trackPipe];
[trackCreator setStandardOutput:handle2];
readHandle=[trackPipe fileHandleForReading];
file = fdopen([readHandle fileDescriptor], "r");

[NSThread detachNewThreadSelector:@selector(startCreating) toTarget:self withObject:nil];
}

- (void)startCreating
{
NSAutoreleasePool *pool=[[NSAutoreleasePool alloc] init];

[trackCreator launch];
[trackCreator waitUntilExit];
[readHandle closeFile];
readHandle = nil;
[trackPipe release];
[trackCreator release];

[pool release];
}

- (void)createAudioTrack:(NSString *)path withTrackSize:(int)trackSize
{
trackCreator = [[NSTask alloc] init];

calcPipe = [[NSPipe alloc] init];
trackPipe = [[NSPipe alloc] init];

calcHandle = [calcPipe fileHandleForReading];
writeHandle = [trackPipe fileHandleForWriting];
readHandle = [trackPipe fileHandleForReading];

[trackCreator setLaunchPath:[KWCommonMethods ffmpegPath]];
[trackCreator setArguments:[NSArray arrayWithObjects:@"-i",path,@"-f",@"s16le",@"-",nil]];
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWDebug"] == NO)
	[trackCreator setStandardError:[NSFileHandle fileHandleWithNullDevice]];
[trackCreator setStandardOutput:calcPipe];

file = fdopen([readHandle fileDescriptor], "r");

[NSThread detachNewThreadSelector:@selector(startAudioTrackCreation:) toTarget:self withObject:[NSNumber numberWithInt:trackSize]];
}

- (void)startAudioTrackCreation:(NSNumber *)trackSize
{
NSAutoreleasePool *pool= [[NSAutoreleasePool alloc] init];

	while (![currentAudioTrack isEqualTo:[[trackCreator arguments] objectAtIndex:1]]) 
	{
	//Stop don't loop that fast (our processor doesn't like that
	usleep(1000000);
	}

[trackCreator launch];

NSData *data;
NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
int bytes = 0;

		while([data=[calcHandle availableData] length])
		{
		bytes = bytes + [data length];
		
		[writeHandle writeData:data];
		
		[innerPool release];
		innerPool = [[NSAutoreleasePool alloc] init];
		}
		
[trackCreator waitUntilExit];

	//Write overhead
	if ([trackSize intValue] * 2352 > bytes)
	{
	NSTask *dd = [[NSTask alloc] init];
	[dd setLaunchPath:@"/bin/dd"];
	[dd setArguments:[NSArray arrayWithObjects:@"if=/dev/zero",[@"count=" stringByAppendingString:[[NSNumber numberWithInt:([trackSize intValue] * 2352) - bytes] stringValue]], @"bs=1", nil]];
		if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWDebug"] == NO)
		[dd setStandardError:[NSFileHandle fileHandleWithNullDevice]];
	[dd setStandardOutput:writeHandle];
	[dd launch];
	[dd waitUntilExit];
	[dd release];
	dd = nil;
	}

[writeHandle closeFile];
writeHandle = nil;
[calcPipe release];
[trackPipe release];
[trackCreator release];

[pool release];
}

///////////////////
// Other actions //
///////////////////

#pragma mark -
#pragma mark •• Other actions

- (float)imageSize
{
NSTask *mkisofs = [[NSTask alloc] init];
NSPipe *pipe=[[NSPipe alloc] init];
NSFileHandle *handle;
[mkisofs setLaunchPath:[[NSBundle mainBundle] pathForResource:@"mkisofs" ofType:@""]];

NSArray *options;

	if (type == 1)
	options = [NSArray arrayWithObjects:@"-print-size", @"-V",discName,@"-f",@"-hfs",@"--osx-hfs",@"-r",@"-joliet",folderPath,nil];
	else if (type == 2)
	options = [NSArray arrayWithObjects:@"-print-size", @"-V",discName,@"-f",@"-udf",folderPath,nil];
	else if (type == 3)
	options = [NSArray arrayWithObjects:@"-print-size", @"-V",discName,@"-f",@"-dvd-video",folderPath,nil];
	else if (type == 7)
	options = [NSArray arrayWithObjects:@"-print-size", @"-V",discName,@"-f",@"-dvd-audio",folderPath,nil];

[mkisofs setArguments:options];
[mkisofs setStandardError:[NSFileHandle fileHandleWithNullDevice]];
[mkisofs setStandardOutput:pipe];
handle = [pipe fileHandleForReading];
[mkisofs launch];

NSData *data = [handle readDataToEndOfFile];
NSString *string = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
float size = [string intValue];
[string release];

[mkisofs waitUntilExit];
[pipe release];
[mkisofs release];

return size;
}

- (DRTrack *)createDefaultTrackWithSize:(int)size
{
DRTrack *track = [[DRTrack alloc] initWithProducer:self];
NSMutableDictionary *dict = [NSMutableDictionary dictionary];
		
[dict setObject:[DRMSF msfWithFrames:size] forKey:DRTrackLengthKey];
[dict setObject:[NSNumber numberWithInt:kDRBlockSizeMode1Data] forKey:DRBlockSizeKey];
[dict setObject:[NSNumber numberWithInt:kDRBlockTypeMode1Data] forKey:DRBlockTypeKey];
[dict setObject:[NSNumber numberWithInt:kDRDataFormMode1Data] forKey:DRDataFormKey];
[dict setObject:[NSNumber numberWithInt:kDRSessionFormatMode1Data] forKey:DRSessionFormatKey];
[dict setObject:[NSNumber numberWithInt:kDRTrackMode1Data] forKey:DRTrackModeKey];
[dict setObject:[NSNumber numberWithBool:YES] forKey:@"KWFirstTrack"];
		
[track setProperties:dict];

return track;
}

@end
