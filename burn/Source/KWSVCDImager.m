//
//  KWSVCDImager.m
//  KWSVCDImager
//
//  Created by Maarten Foukhar on 14-3-07.
//  Copyright 2009 Kiwi Fruitware. All rights reserved.
//

#import "KWSVCDImager.h"
#import "KWCommonMethods.h"

@implementation KWSVCDImager

- (id) init
{
	self = [super init];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stopVcdimager) name:@"KWStopVcdimager" object:nil];
	userCanceled = NO;
	
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[super dealloc];
}

- (int)createSVCDImage:(NSString *)path withFiles:(NSArray *)files withLabel:(NSString *)label createVCD:(BOOL)VCD hideExtension:(NSNumber *)hide errorString:(NSString **)error
{
	NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
	NSFileManager *defaultManager = [NSFileManager defaultManager];
	NSString *cueFile = [path stringByAppendingPathExtension:@"cue"];
	NSString *binFile = [path stringByAppendingPathExtension:@"bin"];
	totalSize = 0;
	
		int i;
		for (i=0;i<[files count];i++)
		{
			totalSize = totalSize + [[[defaultManager fileAttributesAtPath:[files objectAtIndex:i] traverseLink:YES] objectForKey:NSFileSize] floatValue] / 2048;
		}
		
	[defaultCenter postNotificationName:@"KWMaximumValueChanged" object:[NSNumber numberWithFloat:totalSize]];

	if ([defaultManager fileExistsAtPath:cueFile])
	{
		[KWCommonMethods removeItemAtPath:cueFile];
		[KWCommonMethods removeItemAtPath:binFile];
	}
	
	NSString *status;
	if ([files count] > 1)
		status = NSLocalizedString(@"Writing tracks", Localized);
	else
		status = NSLocalizedString(@"Writing track", Localized);
	
	[defaultCenter postNotificationName:@"KWStatusChanged" object:status];

	NSMutableArray *arguments = [NSMutableArray array];

	[arguments addObject:@"-t"];
	
	if (VCD)
		[arguments addObject:@"vcd2"];
	else
		[arguments addObject:@"svcd"];
		
	[arguments addObject:@"--update-scan-offsets"];
	[arguments addObject:@"-l"];
	[arguments addObject:label];
	[arguments addObject:[@"--cue-file=" stringByAppendingString:cueFile]];
	[arguments addObject:[@"--bin-file=" stringByAppendingString:binFile]];
	[arguments addObjectsFromArray:files];

	vcdimager = [[NSTask alloc] init];
	[vcdimager setLaunchPath:[[NSBundle bundleForClass:[self class]] pathForResource:@"vcdimager" ofType:@""]];
	[vcdimager setArguments:arguments];
	NSPipe *pipe=[[NSPipe alloc] init];
	NSPipe *errorPipe=[[NSPipe alloc] init];
	[vcdimager setCurrentDirectoryPath:[path stringByDeletingLastPathComponent]];
	[vcdimager setStandardOutput:pipe];
	[vcdimager setStandardError:errorPipe];
	NSFileHandle *handle=[pipe fileHandleForReading];
	NSFileHandle *errorHandle=[errorPipe fileHandleForReading];
	[KWCommonMethods logCommandIfNeeded:vcdimager];
	[vcdimager launch];
	
	[defaultCenter postNotificationName:@"KWCancelNotificationChanged" object:@"KWStopVcdimager"];
	[self performSelectorOnMainThread:@selector(startTimer:) withObject:binFile waitUntilDone:NO];
	
	NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];

	NSData *data;
	NSString *string;

	while([data=[handle availableData] length])
	{
		if ([defaultManager fileExistsAtPath:cueFile])
			[defaultManager changeFileAttributes:[NSDictionary dictionaryWithObjectsAndKeys:hide, NSFileExtensionHidden,nil] atPath:cueFile];
		
		if ([defaultManager fileExistsAtPath:binFile])
			[defaultManager changeFileAttributes:[NSDictionary dictionaryWithObjectsAndKeys:hide, NSFileExtensionHidden,nil] atPath:binFile];

		string=[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	
		if ([[NSUserDefaults standardUserDefaults] boolForKey:@"Debug"])
			NSLog(string);
			
		[string release];
		
		[innerPool release];
		innerPool = [[NSAutoreleasePool alloc] init];
	}
	
	[vcdimager waitUntilExit];
	
	NSString *errorString = [[[NSString alloc] initWithData:[errorHandle readDataToEndOfFile] encoding:NSUTF8StringEncoding] autorelease];
	
	[timer invalidate];

	[defaultCenter postNotificationName:@"KWCancelNotificationChanged" object:nil];

	int taskStatus = [vcdimager terminationStatus];
	
		[vcdimager release];
		[pipe release];
	   
	if (taskStatus == 0)
	{
		return 0;
	}
	else
	{
		*error = [NSString stringWithFormat:@"KWConsole:\nTask: vcdimager\n%@", errorString];
		
		[KWCommonMethods removeItemAtPath:cueFile];
		[KWCommonMethods removeItemAtPath:binFile];
		
		if (userCanceled)
			return 2;
		else
			return 1;
	}
}

- (void)startTimer:(NSArray *)object
{
	timer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(imageProgress:) userInfo:object repeats:YES];
}

- (void)imageProgress:(NSTimer *)theTimer
{
	NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];

	float currentSize = [[[[NSFileManager defaultManager] fileAttributesAtPath:[theTimer userInfo] traverseLink:YES] objectForKey:NSFileSize] floatValue] / 2048;
	float percent = currentSize / totalSize * 100;
		
		if (percent < 101)
		[defaultCenter postNotificationName:@"KWStatusByAddingPercentChanged" object:[NSString stringWithFormat:@" (%.0f%@)", percent, @"%"]];

	[defaultCenter postNotificationName:@"KWValueChanged" object:[NSNumber numberWithFloat:currentSize]];
}

- (void)stopVcdimager
{
	userCanceled = YES;
	[vcdimager terminate];
}

@end