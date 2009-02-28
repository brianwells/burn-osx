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

- (int)createSVCDImage:(NSString *)path withFiles:(NSArray *)files withLabel:(NSString *)label createVCD:(BOOL)VCD hideExtension:(NSNumber *)hide
{
totalSize = 0;
	
		int i;
		for (i=0;i<[files count];i++)
		{
		totalSize = totalSize + [[[[NSFileManager defaultManager] fileAttributesAtPath:[files objectAtIndex:i] traverseLink:YES] objectForKey:NSFileSize] floatValue] / 2048;
		}
		
[[NSNotificationCenter defaultCenter] postNotificationName:@"KWMaximumValueChanged" object:[NSNumber numberWithFloat:totalSize]];

	if ([[NSFileManager defaultManager] fileExistsAtPath:[path stringByAppendingPathExtension:@"cue"]])
	{
	[[NSFileManager defaultManager] removeFileAtPath:[path stringByAppendingPathExtension:@"cue"] handler:nil];
	[[NSFileManager defaultManager] removeFileAtPath:[path stringByAppendingPathExtension:@"bin"] handler:nil];
	}
	
	if ([files count] > 1)
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWStatusChanged" object:NSLocalizedString(@"Writing tracks", Localized)];
	else
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWStatusChanged" object:NSLocalizedString(@"Writing track", Localized)];

NSMutableArray *arguments = [NSMutableArray array];

[arguments addObject:@"-t"];
	if (VCD == YES)
	[arguments addObject:@"vcd2"];
	else
	[arguments addObject:@"svcd"];
[arguments addObject:@"--update-scan-offsets"];
[arguments addObject:@"-l"];
[arguments addObject:label];
[arguments addObject:[@"--cue-file=" stringByAppendingString:[path stringByAppendingPathExtension:@"cue"]]];
[arguments addObject:[@"--bin-file=" stringByAppendingString:[path stringByAppendingPathExtension:@"bin"]]];

	for (i=0;i<[files count];i++)
	{
	[arguments addObject:[files objectAtIndex:i]];
	}

vcdimager = [[NSTask alloc] init];
	
[vcdimager setLaunchPath:[[NSBundle bundleForClass:[self class]] pathForResource:@"vcdimager" ofType:@""]];
[vcdimager setArguments:arguments];
NSPipe *pipe=[[NSPipe alloc] init];
[vcdimager setCurrentDirectoryPath:[path stringByDeletingLastPathComponent]];
[vcdimager setStandardOutput:pipe];
NSFileHandle *handle=[pipe fileHandleForReading];
[vcdimager launch];
[[NSNotificationCenter defaultCenter] postNotificationName:@"KWCancelNotificationChanged" object:@"KWStopVcdimager"];
[self performSelectorOnMainThread:@selector(startTimer:) withObject:[path stringByAppendingPathExtension:@"bin"] waitUntilDone:NO];

	NSData *data;
	while([data=[handle availableData] length])
	{
		if ([[NSFileManager defaultManager] fileExistsAtPath:[path stringByAppendingPathExtension:@"cue"]])
		[[NSFileManager defaultManager] changeFileAttributes:[NSDictionary dictionaryWithObjectsAndKeys:hide, NSFileExtensionHidden,nil] atPath:[path stringByAppendingPathExtension:@"cue"]];
		
		if ([[NSFileManager defaultManager] fileExistsAtPath:[path stringByAppendingPathExtension:@"bin"]])
		[[NSFileManager defaultManager] changeFileAttributes:[NSDictionary dictionaryWithObjectsAndKeys:hide, NSFileExtensionHidden,nil] atPath:[path stringByAppendingPathExtension:@"bin"]];

	NSString *string=[[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
	
		if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWDebug"] == YES)
		NSLog(string);
		
	[string release];
	}
	
[vcdimager waitUntilExit];
[timer invalidate];

[[NSNotificationCenter defaultCenter] postNotificationName:@"KWCancelNotificationChanged" object:nil];

	int taskStatus = [vcdimager terminationStatus];
	
	[vcdimager release];
	[pipe release];
	   
	if (taskStatus == 0)
	{
	return 0;
	}
	else if (userCanceled == YES)
	{
	[[NSFileManager defaultManager] removeFileAtPath:[path stringByAppendingString:@".cue"] handler:nil];
	[[NSFileManager defaultManager] removeFileAtPath:[path stringByAppendingString:@".bin"] handler:nil];
	return 2;
	}
	else
	{
	[[NSFileManager defaultManager] removeFileAtPath:[path stringByAppendingString:@".cue"] handler:nil];
	[[NSFileManager defaultManager] removeFileAtPath:[path stringByAppendingString:@".bin"] handler:nil];
	return 1;
	}
}

- (void)startTimer:(NSArray *)object
{
timer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(imageProgress:) userInfo:object repeats:YES];
}

- (void)imageProgress:(NSTimer *)theTimer
{
	float currentSize = [[[[NSFileManager defaultManager] fileAttributesAtPath:[theTimer userInfo] traverseLink:YES] objectForKey:NSFileSize] floatValue] / 2048;
	double percent = [[[[[NSNumber numberWithDouble:currentSize / totalSize * 100] stringValue] componentsSeparatedByString:@"."] objectAtIndex:0] doubleValue];
		if (percent < 101)
		[[NSNotificationCenter defaultCenter] postNotificationName:@"KWStatusByAddingPercentChanged" object:[[@" (" stringByAppendingString:[[NSNumber numberWithDouble:percent] stringValue]] stringByAppendingString:@"%)"]];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWValueChanged" object:[NSNumber numberWithFloat:currentSize]];
}

- (void)stopVcdimager
{
userCanceled = YES;
[vcdimager terminate];
}

@end
