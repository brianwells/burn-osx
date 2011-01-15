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
		[self createAudioTrack:[[track properties] objectForKey:@"KWAudioPath"]];
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
		[folderPath release];
	
	if (discName)
		[discName release];
	
	if (mpegFiles)
		[mpegFiles release];
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
	
	#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_4
	return [self getTracksOfLayout:[NSString stringWithContentsOfFile:path usedEncoding:nil error:nil] withTotalSize:[[[NSFileManager defaultManager] fileAttributesAtPath:binPath traverseLink:YES] fileSize]];
	#else
	return [self getTracksOfLayout:[NSString stringWithContentsOfFile:path] withTotalSize:[[[NSFileManager defaultManager] fileAttributesAtPath:binPath traverseLink:YES] fileSize]];
	#endif
}

- (DRTrack *)getTrackForImage:(NSString *)path withSize:(NSInteger)size
{
	file = fopen([path fileSystemRepresentation], "r");

	NSInteger fileSize;

	if (size > 0)
		fileSize = size;
	else
		fileSize = [[[NSFileManager defaultManager] fileAttributesAtPath:path traverseLink:YES] fileSize] / 2048;

	return [self createDefaultTrackWithSize:fileSize];
}

- (DRTrack *)getTrackForFolder:(NSString *)path ofType:(NSInteger)imageType withDiscName:(NSString *)name
{
	type = imageType;
	folderPath = [path copy];
	discName = [name copy];

	return [self createDefaultTrackWithSize:[self imageSize]];
}

- (NSArray *)getTrackForVCDMPEGFiles:(NSArray *)files withDiscName:(NSString *)name ofType:(NSInteger)imageType
{
	discName = [name copy];
	mpegFiles = [files copy];
	type = imageType;
	createdTrack = NO;

	return [self getTracksOfVcd];
}

- (NSArray *)getTracksOfLayout:(NSString *)layout withTotalSize:(NSInteger)size
{
	NSMutableArray *array = [NSMutableArray array];
	NSScanner *scanner   = [NSScanner scannerWithString:layout];
	
	NSInteger totalSize;
	if ([layout rangeOfString:@"2048"].length > 0)
		totalSize = size / 2048;
	else if ([layout rangeOfString:@"2336"].length > 0)
		totalSize = size / 2336;
	else if ([layout rangeOfString:@"2352"].length > 0)
		totalSize = size / 2336;
	
	if (![scanner skipPastString:@"BINARY"])
	{
		//NSLog(@"Could not find BINARY marker.");
		return nil;
	}
						
	BOOL done     = NO;
	NSInteger  savedGap = 150;
	BOOL firstTrack = YES;
	
	while (!done)
	{
		NSInteger m, s, f;
		
		NSInteger trackID;
		NSInteger length;
		NSInteger pregap = savedGap;
		NSInteger blockType;
		NSInteger dataForm;
		NSInteger trackMode;
		NSInteger sessionFormat;
		NSInteger blockSize = 0;
		
		if (![scanner skipPastString:@"TRACK"])
			break;
		
		if (![scanner scanInteger:&trackID])
		{
			//NSLog(@"Could not parse track number.");
		
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
			//NSLog(@"Unknown track type.");
		
			return nil;
		}
			
		if (![scanner skipPastString:@"INDEX 01"])
		{
			//NSLog(@"Could not determine track starting time.");
		
			return nil;
		}
		
		if (![scanner scanInteger:&m]) break;
		if (![scanner skipPastString:@":"]) break;
		if (![scanner scanInteger:&s]) break;
		if (![scanner skipPastString:@":"]) break;
		if (![scanner scanInteger:&f]) break;
		
		NSInteger startTime = (m * 60 + s) * 75 + f;
		unsigned location = [scanner scanLocation];
		
		if ([scanner skipPastString:@"INDEX 00"])
		{
			if (![scanner scanInteger:&m]) break;
			if (![scanner skipPastString:@":"]) break;
			if (![scanner scanInteger:&s]) break;
			if (![scanner skipPastString:@":"]) break;
			if (![scanner scanInteger:&f]) break;
			
			NSInteger time = (m * 60 + s) * 75 + f;
			length   = time - startTime;
			
			if ([scanner skipPastString:@"INDEX 01"])
			{
				if (![scanner scanInteger:&m]) break;
				if (![scanner skipPastString:@":"]) break;
				if (![scanner scanInteger:&s]) break;
				if (![scanner skipPastString:@":"]) break;
				if (![scanner scanInteger:&f]) break;
				
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
		//[dict setObject:DRVerificationTypeProduceAgain forKey:DRVerificationTypeKey];
	
		if (firstTrack == YES)
		{
			[dict setObject:[NSNumber numberWithBool:YES] forKey:@"KWFirstTrack"];
			firstTrack = NO;
		}
		
		[track setProperties:dict];
		[array addObject:track];

		//NSLog(@"%@", [[track properties] description]);
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

	NSInteger i;
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
	
	[KWCommonMethods logCommandIfNeeded:vcdimager];
	[vcdimager launch];

	NSData *data;
	NSInteger size = 0;

	NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];

	while([data=[handle availableData] length])
	{
		size = size + [data length];
		data = nil;
	
		[innerPool release];
		innerPool = [[NSAutoreleasePool alloc] init];
	}

	NSString *string=[[NSString alloc] initWithData:[handle2 readDataToEndOfFile] encoding:NSUTF8StringEncoding];

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

	NSInteger i = 0;
	for (i=0;i<[sessions count];i++)
	{
		NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
		
		NSDictionary *session = [sessions objectAtIndex:i];
		
		NSNumber *leadout = [session objectForKey:@"Leadout Block"]; 
		NSArray *tracks = [session objectForKey:@"Track Array"];
	
		NSInteger x = 0;
		for (x=0;x<[tracks count];x++)
		{
			NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
			
			NSDictionary *currentTrack = [tracks objectAtIndex:x];
		
			NSInteger size;
		
			if (x + 1 < [tracks count])
				size = [[[tracks objectAtIndex:x + 1] objectForKey:@"Start Block"] intValue] - [[currentTrack objectForKey:@"Start Block"] intValue];
			else
				size = [leadout intValue] - [[currentTrack objectForKey:@"Start Block"] intValue];
		
			DRTrack *track = [[[DRTrack alloc] initWithProducer:self] autorelease];
			NSMutableDictionary *dict = [NSMutableDictionary dictionary];
			
			[dict setObject:[NSNumber numberWithBool:YES] forKey:@"KWFirstTrack"];
			
			if (x == 0)
				[dict setObject:[DRMSF msfWithFrames:150] forKey:DRPreGapLengthKey];
			else
				[dict setObject:[DRMSF msfWithFrames:0] forKey:DRPreGapLengthKey];
		
			[dict setObject:[DRMSF msfWithFrames:size] forKey:DRTrackLengthKey];
			[dict setObject:[NSNumber numberWithInt:2352] forKey:DRBlockSizeKey];
			[dict setObject:[NSNumber numberWithInt:0] forKey:DRBlockTypeKey];
			[dict setObject:[NSNumber numberWithInt:0] forKey:DRDataFormKey];
			[dict setObject:[NSNumber numberWithInt:0] forKey:DRSessionFormatKey];
			[dict setObject:[NSNumber numberWithInt:0] forKey:DRTrackModeKey];
			[dict setObject:[currentTrack objectForKey:@"Pre-Emphasis Enabled"] forKey:DRAudioPreEmphasisKey];
			//[dict setObject:DRVerificationTypeProduceAgain forKey:DRVerificationTypeKey];
		
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
	DRTrack *track = [[[DRTrack alloc] initWithProducer:self] autorelease];
	NSMutableDictionary *properties = [NSMutableDictionary dictionary];
		
	[properties setObject:[NSNumber numberWithFloat:[self audioTrackSizeAtPath:path]] forKey:DRTrackLengthKey];
	[properties setObject:[NSNumber numberWithInt:2352] forKey:DRBlockSizeKey];
	[properties setObject:[NSNumber numberWithInt:0] forKey:DRBlockTypeKey];
	[properties setObject:[NSNumber numberWithInt:0] forKey:DRDataFormKey];
	[properties setObject:[NSNumber numberWithInt:0] forKey:DRSessionFormatKey];
	[properties setObject:[NSNumber numberWithInt:0] forKey:DRTrackModeKey];
	[properties setObject:path forKey:@"KWAudioPath"];
	[properties setObject:[NSNumber numberWithBool:YES] forKey:@"KWFirstTrack"];
	//[properties setObject:DRVerificationTypeProduceAgain forKey:DRVerificationTypeKey];
		
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
	
	NSMutableArray *options = [NSMutableArray arrayWithObjects:@"-V", discName, @"-f", nil];
	
	if (type == 1)
		[options addObjectsFromArray:[NSArray arrayWithObjects:@"-hfs", @"--osx-hfs", @"-r", @"-joliet", @"-input-hfs-charset", [[NSBundle mainBundle] pathForResource:@"iso8859-1" ofType:@""],nil]];
	else if (type == 2)
		[options addObject:@"-udf"];
	else if (type == 3)
		[options addObject:@"-dvd-video"];
	else if (type == 7)
		[options addObject:@"-dvd-audio"];
	else if (type == 8)
		[options addObjectsFromArray:[NSArray arrayWithObjects:@"-r", @"-joliet", @"-joliet-long", nil]];
		
	[options addObject:folderPath];
	
	[trackCreator setArguments:options];
	[trackCreator setStandardOutput:trackPipe];
	readHandle=[trackPipe fileHandleForReading];
	[KWCommonMethods logCommandIfNeeded:trackCreator];
	
	file = fdopen([readHandle fileDescriptor], "r");

	[NSThread detachNewThreadSelector:@selector(startCreating) toTarget:self withObject:nil];
}

- (void)createVcdImage
{
	NSMutableArray *arguments = [NSMutableArray arrayWithObject:@"-t"];
	
	if (type == 4)
		[arguments addObject:@"vcd2"];
	else if (type == 5)
		[arguments addObject:@"svcd"];
	
	[arguments addObjectsFromArray:[NSArray arrayWithObjects:@"--update-scan-offsets", @"-l", discName, [@"--cue-file=" stringByAppendingString:@"/dev/fd/1"], [@"--bin-file=" stringByAppendingString:@"/dev/fd/2"], nil]];

	NSInteger i;
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
	
	[KWCommonMethods logCommandIfNeeded:trackCreator];
	[trackCreator launch];
	
	[trackCreator waitUntilExit];
	[readHandle closeFile];
	readHandle = nil;
	[trackPipe release];
	[trackCreator release];

	[pool release];
}

- (void)createAudioTrack:(NSString *)path
{
	trackCreator = [[NSTask alloc] init];

	calcPipe = [[NSPipe alloc] init];
	trackPipe = [[NSPipe alloc] init];

	calcHandle = [calcPipe fileHandleForReading];
	writeHandle = [trackPipe fileHandleForWriting];
	readHandle = [trackPipe fileHandleForReading];

	[trackCreator setLaunchPath:[KWCommonMethods ffmpegPath]];
	
	NSArray *arguments = [NSArray arrayWithObjects:@"-i", path, @"-f", @"s16le", @"-ac", @"2", @"-", nil];
	
	if ([[KWConverter alloc] isAudioCDFile:path])
		arguments = [NSArray arrayWithObjects:@"-i", path, @"-f", @"s16le", @"-acodec", @"copy", @"-", nil];
	
	[trackCreator setArguments:arguments];
	[trackCreator setStandardOutput:calcPipe];
	
	if (![[NSUserDefaults standardUserDefaults] boolForKey:@"KWDebug"])
		[trackCreator setStandardError:[NSFileHandle fileHandleWithNullDevice]];
	
	[KWCommonMethods logCommandIfNeeded:trackCreator];

	file = fdopen([readHandle fileDescriptor], "r");

	[NSThread detachNewThreadSelector:@selector(startAudioTrackCreation) toTarget:self withObject:nil];
}

- (void)startAudioTrackCreation
{
	NSAutoreleasePool *pool= [[NSAutoreleasePool alloc] init];

	while (![currentAudioTrack isEqualTo:[[trackCreator arguments] objectAtIndex:1]]) 
	{
		//Stop, don't loop that fast (our processor doesn't like that)
		usleep(1000000);
	}
	
	[KWCommonMethods logCommandIfNeeded:trackCreator];
	[trackCreator launch];

	NSData *data;
	NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];

		while([data=[calcHandle availableData] length])
		{
			[writeHandle writeData:data];
		
			[innerPool release];
			innerPool = [[NSAutoreleasePool alloc] init];
		}
		
	[trackCreator waitUntilExit];

	[writeHandle closeFile];
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
	
	NSMutableArray *options = [NSMutableArray arrayWithObjects:@"-print-size", @"-V", discName, @"-f", nil];
	
	if (type == 1)
		[options addObjectsFromArray:[NSArray arrayWithObjects:@"-hfs", @"--osx-hfs", @"-r", @"-joliet", @"-input-hfs-charset", [[NSBundle mainBundle] pathForResource:@"iso8859-1" ofType:@""],nil]];
	else if (type == 2)
		[options addObject:@"-udf"];
	else if (type == 3)
		[options addObject:@"-dvd-video"];
	else if (type == 7)
		[options addObject:@"-dvd-audio"];
	else if (type == 8)
		[options addObjectsFromArray:[NSArray arrayWithObjects:@"-r", @"-joliet", @"-joliet-long", nil]];
		
	[options addObject:folderPath];

	[mkisofs setArguments:options];
	[mkisofs setStandardError:[NSFileHandle fileHandleWithNullDevice]];
	[mkisofs setStandardOutput:pipe];
	handle = [pipe fileHandleForReading];
	[KWCommonMethods logCommandIfNeeded:mkisofs];
	[mkisofs launch];

	NSData *data = [handle readDataToEndOfFile];
	NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	float size = [string intValue];
	[string release];

	[mkisofs waitUntilExit];
	[pipe release];
	[mkisofs release];

	return size;
}

- (DRTrack *)createDefaultTrackWithSize:(NSInteger)size
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
	//[dict setObject:DRVerificationTypeProduceAgain forKey:DRVerificationTypeKey];
		
	[track setProperties:dict];

	return track;
}

- (float)audioTrackSizeAtPath:(NSString *)path
{
	NSTask *ffmpeg = [[NSTask alloc] init];
	NSPipe *outPipe = [[NSPipe alloc] init];
	NSFileHandle *outHandle = [outPipe fileHandleForReading];
	[ffmpeg setLaunchPath:[KWCommonMethods ffmpegPath]];
	
	NSArray *arguments = [NSArray arrayWithObjects:@"-i", path, @"-f", @"s16le", @"-ac", @"2", @"-", nil];
	
	if ([[KWConverter alloc] isAudioCDFile:path])
		arguments = [NSArray arrayWithObjects:@"-i", path, @"-f", @"s16le", @"-acodec", @"copy", @"-", nil];
	
	[trackCreator setArguments:arguments];
	
	[ffmpeg setArguments:arguments];
	[ffmpeg setStandardOutput:outPipe];
	
	if (![[NSUserDefaults standardUserDefaults] boolForKey:@"KWDebug"])
		[ffmpeg setStandardError:[NSFileHandle fileHandleWithNullDevice]];
	
	[KWCommonMethods logCommandIfNeeded:ffmpeg];
	[ffmpeg launch];
	float size = 0;
	
	NSData *data;
	NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];

	while([data=[outHandle availableData] length])
	{
		size = size + [data length];
		
		[innerPool release];
		innerPool = [[NSAutoreleasePool alloc] init];
	}
	
	[innerPool release];
	[ffmpeg waitUntilExit];
	[ffmpeg release];
	[outPipe release];

	return size /  2352;
}

@end