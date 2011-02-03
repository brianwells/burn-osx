//
//  KWSVCDImager.m
//  KWSVCDImager
//
//  Created by Maarten Foukhar on 14-3-07.
//  Copyright 2009 Kiwi Fruitware. All rights reserved.
//

#import "KWSVCDImager.h"

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

- (NSInteger)createSVCDImage:(NSString *)path withFiles:(NSArray *)files withLabel:(NSString *)label createVCD:(BOOL)VCD hideExtension:(NSNumber *)hide errorString:(NSString **)error
{
	NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
	NSFileManager *defaultManager = [NSFileManager defaultManager];
	NSString *cueFile = [path stringByAppendingPathExtension:@"cue"];
	NSString *binFile = [path stringByAppendingPathExtension:@"bin"];
	totalSize = 0;
	
		NSInteger i;
		for (i=0;i<[files count];i++)
		{
			totalSize = totalSize + [[[defaultManager fileAttributesAtPath:[files objectAtIndex:i] traverseLink:YES] objectForKey:NSFileSize] cgfloatValue] / 2048;
		}
		
	[defaultCenter postNotificationName:@"KWMaximumValueChanged" object:[NSNumber numberWithCGFloat:totalSize]];

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
	
	NSString *kind = @"svcd";
	if (VCD)
		kind = @"vcd2";
		
	NSMutableArray *arguments = [NSMutableArray arrayWithObjects:@"-t", kind, @"--update-scan-offsets", @"-l", label, [@"--cue-file=" stringByAppendingString:cueFile], [@"--bin-file=" stringByAppendingString:binFile], nil];
	[arguments addObjectsFromArray:files];

	vcdimager = [[NSTask alloc] init];
	[vcdimager setLaunchPath:[[NSBundle bundleForClass:[self class]] pathForResource:@"vcdimager" ofType:@""]];
	[vcdimager setArguments:arguments];
	NSPipe *pipe = [[NSPipe alloc] init];
	NSPipe *errorPipe = [[NSPipe alloc] init];
	[vcdimager setCurrentDirectoryPath:[path stringByDeletingLastPathComponent]];
	[vcdimager setStandardOutput:pipe];
	[vcdimager setStandardError:errorPipe];
	NSFileHandle *handle = [pipe fileHandleForReading];
	NSFileHandle *errorHandle = [errorPipe fileHandleForReading];
	[KWCommonMethods logCommandIfNeeded:vcdimager];
	[vcdimager launch];
	
	[defaultCenter postNotificationName:@"KWCancelNotificationChanged" object:@"KWStopVcdimager"];
	[self performSelectorOnMainThread:@selector(startTimer:) withObject:binFile waitUntilDone:NO];

	NSData *data;
	NSString *string;

	while([data = [handle availableData] length])
	{
		NSAutoreleasePool *subpool = [[NSAutoreleasePool alloc] init];
		if ([defaultManager fileExistsAtPath:cueFile])
			[defaultManager changeFileAttributes:[NSDictionary dictionaryWithObjectsAndKeys:hide, NSFileExtensionHidden,nil] atPath:cueFile];
		
		if ([defaultManager fileExistsAtPath:binFile])
			[defaultManager changeFileAttributes:[NSDictionary dictionaryWithObjectsAndKeys:hide, NSFileExtensionHidden,nil] atPath:binFile];

		string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	
		if ([[NSUserDefaults standardUserDefaults] boolForKey:@"Debug"])
			NSLog(@"%@", string);
			
		[string release];
		string = nil;
		
		[subpool release];
		subpool = nil;
	}
	
	[vcdimager waitUntilExit];
	
	NSString *errorString = [[[NSString alloc] initWithData:[errorHandle readDataToEndOfFile] encoding:NSUTF8StringEncoding] autorelease];
	
	[timer invalidate];

	[defaultCenter postNotificationName:@"KWCancelNotificationChanged" object:nil];

	NSInteger taskStatus = [vcdimager terminationStatus];
	
	[vcdimager release];
	vcdimager = nil;
	
	[pipe release];
	pipe = nil;
	   
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

	CGFloat currentSize = [[[[NSFileManager defaultManager] fileAttributesAtPath:[theTimer userInfo] traverseLink:YES] objectForKey:NSFileSize] cgfloatValue] / 2048;
	CGFloat percent = currentSize / totalSize * 100;
		
		if (percent < 101)
		[defaultCenter postNotificationName:@"KWStatusByAddingPercentChanged" object:[NSString stringWithFormat:@" (%.0f%@)", percent, @"%"]];

	[defaultCenter postNotificationName:@"KWValueChanged" object:[NSNumber numberWithCGFloat:currentSize]];
}

- (void)stopVcdimager
{
	userCanceled = YES;
	[vcdimager terminate];
}

@end