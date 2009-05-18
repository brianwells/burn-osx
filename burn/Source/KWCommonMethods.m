//
//  KWCommonMethods.m
//  Burn
//
//  Created by Maarten Foukhar on 22-4-07.
//  Copyright 2009 Kiwi Fruitware. All rights reserved.
//

#import "KWCommonMethods.h"
#import "KWDRFolder.h"
#import "KWDocument.h"

@implementation KWCommonMethods

////////////////
// OS actions //
////////////////

#pragma mark -
#pragma mark •• OS actions

+ (BOOL)isPanther
{
	SInt32 MacVersion;
	if (Gestalt(gestaltSystemVersion, &MacVersion) == noErr)
	{
		if (MacVersion >= 0x1040)
		return NO;
		else
		return YES;
	}

return NO;
}

+ (BOOL)isQuickTimeSevenInstalled
{
long version;
OSErr result;

     result = Gestalt(gestaltQuickTime,&version);
     if ((result == noErr) && (version >= 0x07000000))
     return YES;
	 else
	 return NO;
}

///////////////////////////
// String format actions //
///////////////////////////

#pragma mark -
#pragma mark •• String format actions

+ (NSString *)commentString:(NSString *)string
{
return [[@"\"" stringByAppendingString:string] stringByAppendingString:@"\""];
}

+ (NSString *)formatTime:(int)totalSeconds
{
int hours = totalSeconds / 60 / 60;
int minutes = totalSeconds / 60 - (hours * 60);
int seconds = totalSeconds - (minutes * 60) - (hours * 60 * 60);
	
NSString *hourString = [[[NSNumber numberWithInt:hours] stringValue] stringByAppendingString:@":"];
	
	if (hours < 10)
	hourString = [@"0" stringByAppendingString:hourString];
	
NSString *minuteString = [[[NSNumber numberWithInt:minutes] stringValue] stringByAppendingString:@":"];
		
	if (minutes < 10)
	minuteString = [@"0" stringByAppendingString:minuteString];

NSString *secondString = [[NSNumber numberWithInt:seconds] stringValue];
	
	if (seconds < 10)
	secondString = [@"0" stringByAppendingString:secondString];
		
return [[hourString stringByAppendingString:minuteString] stringByAppendingString:secondString];
}

+ (NSString *)makeSizeFromFloat:(float)size
{
NSString *formattedSize = @"";

float floatSize = size;

	if (floatSize < 1024)
		if (floatSize > 0)
		formattedSize = NSLocalizedString(@"4 KB",@"Localized");
		else
		formattedSize = [[NSString localizedStringWithFormat: @"%.0f", size] stringByAppendingString:NSLocalizedString(@" KB",@"Localized")];
	
	if (floatSize > 1024)
	{
	floatSize = size / 1024;
	
	formattedSize = [[NSString localizedStringWithFormat: @"%.0f", floatSize] stringByAppendingString:NSLocalizedString(@" KB",@"Localized")];
	}
	
	if (floatSize > 1024)
	{
	floatSize = size  / 1024 / 1024;

	formattedSize = [NSString localizedStringWithFormat: @"%.1f", floatSize];

		if ([[formattedSize substringFromIndex:[formattedSize length] -1] isEqualTo:@"0"])
		formattedSize = [[NSString localizedStringWithFormat: @"%.0f", floatSize] stringByAppendingString:NSLocalizedString(@" MB",@"Localized")];
		else
		formattedSize = [formattedSize stringByAppendingString:NSLocalizedString(@" MB",@"Localized")];
	}
	
	if (floatSize > 1024)
	{
	floatSize = size  / 1024 / 1024 / 1024;
	
	formattedSize = [NSString localizedStringWithFormat: @"%.2f", floatSize];
		
		if ([[formattedSize substringFromIndex:[formattedSize length] -1] isEqualTo:@"0"])
		{
		formattedSize = [NSString localizedStringWithFormat: @"%.1f", floatSize];
		
			if ([[formattedSize substringFromIndex:[formattedSize length] -1] isEqualTo:@"0"])
			{
			formattedSize = [NSString localizedStringWithFormat: @"%.0f", floatSize];
			}
		}
		
	formattedSize = [formattedSize stringByAppendingString:NSLocalizedString(@" GB",@"Localized")];
	}
	
	if (floatSize > 1024)
	{
	floatSize = size / 1024 / 1024 / 1024 / 1024;
	
	formattedSize = [NSString localizedStringWithFormat: @"%.3f", floatSize];
	
		if ([[formattedSize substringFromIndex:[formattedSize length] -1] isEqualTo:@"0"])
		{
		formattedSize = [NSString localizedStringWithFormat: @"%.2f", floatSize];
		
			if ([[formattedSize substringFromIndex:[formattedSize length] -1] isEqualTo:@"0"])
			{
			formattedSize = [NSString localizedStringWithFormat: @"%.1f", floatSize];
			
				if ([[formattedSize substringFromIndex:[formattedSize length] -1] isEqualTo:@"0"])
				{
				formattedSize = [NSString localizedStringWithFormat: @"%.0f", floatSize];
				}
			}
		}
				
	formattedSize = [formattedSize stringByAppendingString:NSLocalizedString(@" TB",@"Localized")];
	}	

return formattedSize;
}

//////////////////
// File actions //
//////////////////

#pragma mark -
#pragma mark •• File actions

+ (BOOL)isSavediMovieProject:(NSString *)path
{
	if ([path rangeOfString:@".iMovieProject"].length > 0)
	{
		if (![[[path stringByDeletingLastPathComponent] lastPathComponent] isEqualTo:@"iDVD"])
		return NO;
	}

return YES;
}

+ (NSString *)uniquePathNameFromPath:(NSString *)path withLength:(unsigned int)length
{
	if ([[NSFileManager defaultManager] fileExistsAtPath:path])
	{
	NSString *newPath = [path stringByDeletingPathExtension];
	unsigned int fileLength;
	NSString *pathExtension;

		if ([[path pathExtension] isEqualTo:@""])
		pathExtension = @"";
		else
		pathExtension = [@"." stringByAppendingString:[path pathExtension]];

		if (length > 0)
		fileLength = 29 - [pathExtension length];

		int y = 0;
		while ([[NSFileManager defaultManager] fileExistsAtPath:[newPath stringByAppendingString:pathExtension]])
		{
			if (length > 0 && [[path lastPathComponent] length] > 31)
			newPath = [[path stringByDeletingLastPathComponent] stringByAppendingPathComponent:[[path lastPathComponent] substringWithRange:NSMakeRange(0,fileLength)]];
			else
			newPath = [path stringByDeletingPathExtension];
			
		y = y + 1;
		newPath = [[newPath stringByAppendingString:@" "] stringByAppendingString:[[NSNumber numberWithInt:y] stringValue]];
		}

	return [newPath stringByAppendingString:pathExtension];
	}
	else
	{
	return path;
	}
}

+ (NSString *)temporaryLocation:(NSString *)file saveDescription:(NSString *)description
{
	if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"KWTemporaryLocationPopup"] intValue] == 2)
	{
	NSSavePanel *sheet = [NSSavePanel savePanel];
	[sheet setMessage:description];
	[sheet setRequiredFileType:[file pathExtension]];
	[sheet setCanSelectHiddenExtension:NO];
		
	BOOL succes = [sheet runModalForDirectory:nil file:file];
	
		if (succes == YES)
		return [sheet filename];
		else
		return nil;
	}
	else
	{
	return [KWCommonMethods uniquePathNameFromPath:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWTemporaryLocation"] stringByAppendingPathComponent:file] withLength:0];
	}
}

+ (BOOL)isBundleExtension:(NSString *)extension
{
NSString *testFile = [@"/tmp/kiwiburntest" stringByAppendingPathExtension:extension];
BOOL isPackage;

[[NSFileManager defaultManager] createDirectoryAtPath:testFile attributes:nil];
isPackage = [[NSWorkspace sharedWorkspace] isFilePackageAtPath:testFile];
[[NSFileManager defaultManager] removeFileAtPath:testFile handler:nil];

return isPackage;
}

//////////////////
// Icon actions //
//////////////////

#pragma mark -
#pragma mark •• Icon actions

+ (BOOL)hasCustomIcon:(DRFSObject *)object
{
FSRef possibleCustomIcon;
FSCatalogInfo catalogInfo;
OSStatus errStat;
errStat = FSPathMakeRef((unsigned char *)[[object sourcePath] fileSystemRepresentation], &possibleCustomIcon, nil);
FSGetCatalogInfo(&possibleCustomIcon, kFSCatInfoFinderInfo, &catalogInfo, nil, nil, nil);
		
	if (((FileInfo*)catalogInfo.finderInfo)->finderFlags & kHasCustomIcon)
	return YES;

	if ([[[object baseName] pathExtension] isEqualTo:@"app"] && ![object isKindOfClass:[DRFile class]] | [[[object baseName] pathExtension] isEqualTo:@"prefPane"] && ![object isKindOfClass:[DRFile class]])
	return YES;

return NO;
}

+ (NSImage *)getFolderIcon:(DRFSObject *)fsObj
{
NSImage *img;

	if ([fsObj isVirtual])
	{
		if ([KWCommonMethods fsObjectContainsHFS:fsObj] && [(KWDRFolder *)fsObj folderIcon])
		{
		img = [(KWDRFolder *)fsObj folderIcon];
		}
		else if ([(KWDRFolder *)fsObj isFilePackage] && [[fsObj baseName] isEqualTo:[KWCommonMethods fsObjectFileName:fsObj]] | [[[fsObj baseName] stringByDeletingPathExtension] isEqualTo:[KWCommonMethods fsObjectFileName:fsObj]] | [[KWCommonMethods fsObjectFileName:fsObj] isEqualTo:[(KWDRFolder *)fsObj displayName]])
		// && (![[[KWCommonMethods fsObjectFileName:fsObj] pathExtension] isEqualTo:@""] | [[[fsObj baseName] stringByDeletingPathExtension] isEqualTo:[KWCommonMethods fsObjectFileName:fsObj]] | [[KWCommonMethods fsObjectFileName:fsObj] isEqualTo:[(KWDRFolder *)fsObj displayName]]))
		{
			if ([[[(KWDRFolder *)fsObj baseName] pathExtension] isEqualTo:@"app"])
			{
			img = [(KWDRFolder *)fsObj folderIcon];
			}
			else
			{
			img = [[NSWorkspace sharedWorkspace] iconForFileType:[[(KWDRFolder *)fsObj baseName] pathExtension]];
			}
		}
		else
		{
		//Just a folder kGenericFolderIcon creates weird folders on Intel
		img = [[NSWorkspace sharedWorkspace] iconForFile:@"/bin"];
		}
	}
	else
	{
		if ([KWCommonMethods hasCustomIcon:fsObj])
		{
		[(KWDRFolder *)fsObj setFolderIcon:[[NSWorkspace sharedWorkspace] iconForFile:[fsObj sourcePath]]];
		}
	
		if ([KWCommonMethods fsObjectContainsHFS:fsObj] && [(KWDRFolder *)fsObj folderIcon])
		{
		img = [(KWDRFolder *)fsObj folderIcon];
		}
		else if ([(KWDRFolder *)fsObj isFilePackage] && [[fsObj baseName] isEqualTo:[KWCommonMethods fsObjectFileName:fsObj]] | [[[fsObj baseName] stringByDeletingPathExtension] isEqualTo:[KWCommonMethods fsObjectFileName:fsObj]] | [[KWCommonMethods fsObjectFileName:fsObj] isEqualTo:[(KWDRFolder *)fsObj displayName]])
		{
			if ([[[(KWDRFolder *)fsObj baseName] pathExtension] isEqualTo:@"app"])
			{
			img = [(KWDRFolder *)fsObj folderIcon];
			}
			else
			{
			img = [[NSWorkspace sharedWorkspace] iconForFileType:[[(KWDRFolder *)fsObj baseName] pathExtension]];
			}
		}
		else
		{
		//Just a folder kGenericFolderIcon creates weird folders on Intel
		img = [[NSWorkspace sharedWorkspace] iconForFile:@"/bin"];
		}
	}
	
	if (![KWCommonMethods isDRFSObjectVisible:fsObj])
	{
	NSImage* dragImage=[[[NSImage alloc] initWithSize:[img size]] autorelease];
			
	[dragImage lockFocus];
	[img dissolveToPoint: NSZeroPoint fraction: .5];
	[dragImage unlockFocus];
			
	[dragImage setScalesWhenResized:YES];
			
	return dragImage;
	}

return img;
}

+ (NSImage *)getFileIcon:(DRFSObject *)fsObj
{
NSImage *img;
	
	if ([KWCommonMethods fsObjectContainsHFS:fsObj] && [KWCommonMethods hasCustomIcon:fsObj])
	{
	img = [[NSWorkspace sharedWorkspace] iconForFile:[fsObj sourcePath]];
	}
	else
	{
	NSString *fileType = @"";
		
		if ([KWCommonMethods fsObjectContainsHFS:fsObj])
		fileType = NSFileTypeForHFSTypeCode([[[[NSFileManager defaultManager] fileAttributesAtPath:[fsObj sourcePath] traverseLink:YES] objectForKey:NSFileHFSTypeCode] longValue]);
	
		if (![KWCommonMethods isBundleExtension:[[(KWDRFolder *)fsObj baseName] pathExtension]] && ![[[(KWDRFolder *)fsObj baseName] pathExtension] isEqualTo:@""])
		img = [[NSWorkspace sharedWorkspace] iconForFileType:[[(KWDRFolder *)fsObj baseName] pathExtension]];
		else
		img = [[NSWorkspace sharedWorkspace] iconForFileType:fileType];
	}
	
	if (![KWCommonMethods isDRFSObjectVisible:fsObj])
	{
	NSImage* dragImage=[[[NSImage alloc] initWithSize:[img size]] autorelease];
			
	[dragImage lockFocus];
	[img dissolveToPoint: NSZeroPoint fraction: .5];
	[dragImage unlockFocus];
			
	return dragImage;
	}

return img;
}

////////////////////////
// Filesystem actions //
////////////////////////

#pragma mark -
#pragma mark •• Filesystem actions

+ (BOOL)isDRFSObjectVisible:(DRFSObject *)object 
{
	if ([[object parent] effectiveFilesystemMask] & DRFilesystemInclusionMaskHFSPlus)
	{
		if ([[object baseName] hasPrefix:@"."])
		return NO;

		if ([object propertyForKey:DRInvisible inFilesystem:DRHFSPlus mergeWithOtherFilesystems:NO])
		{
			if ([[object propertyForKey:DRInvisible inFilesystem:DRHFSPlus mergeWithOtherFilesystems:NO] boolValue])
			{
			return NO;
			}
			else
			{
			return YES;
			}
		}
	}
	else if ([[object parent] effectiveFilesystemMask] & DRFilesystemInclusionMaskJoliet)
	{
		if ([object propertyForKey:DRInvisible inFilesystem:DRJoliet mergeWithOtherFilesystems:NO])
		{
			if ([[object propertyForKey:DRInvisible inFilesystem:DRJoliet mergeWithOtherFilesystems:NO] boolValue])
			return NO;
			else
			return YES;
		}
	}
	else if ([[object parent] effectiveFilesystemMask] & DRFilesystemInclusionMaskISO9660)
	{
		if ([object propertyForKey:DRInvisible inFilesystem:DRISO9660 mergeWithOtherFilesystems:NO])
		{
			if ([[object propertyForKey:DRInvisible inFilesystem:DRISO9660 mergeWithOtherFilesystems:NO] boolValue])
			return NO;
			else
			return YES;
		}
	}
	else if (![KWCommonMethods isPanther])
	{
		if ([[object parent] effectiveFilesystemMask] & DRFilesystemInclusionMaskUDF)
		{
			if ([object propertyForKey:DRInvisible inFilesystem:DRUDF mergeWithOtherFilesystems:NO])
			{
				if ([[object propertyForKey:DRInvisible inFilesystem:DRUDF mergeWithOtherFilesystems:NO] boolValue])
				return NO;
				else
				return YES;
			}
		}
	}
	
	if ([object isVirtual])
	{
	return YES;
	}
	else
	{
	NSString *path = [object sourcePath];

		if ([[path lastPathComponent] hasPrefix:@"."]) 
		{
		return NO;
		}
		else 
		{
		// check if file is in .hidden
		NSString *hiddenFile = [NSString stringWithContentsOfFile:@"/.hidden"];
		NSArray *dotHiddens = [hiddenFile componentsSeparatedByString:@"\n"];
		
			if ([dotHiddens containsObject:[path lastPathComponent]])
			return NO;
		// use Carbon to check if file has kIsInvisible finder flag
		FSRef possibleInvisibleFile;
		FSCatalogInfo catalogInfo;
		OSStatus errStat;
		errStat = FSPathMakeRef((unsigned char *)[path fileSystemRepresentation], &possibleInvisibleFile, nil);
		FSGetCatalogInfo(&possibleInvisibleFile, kFSCatInfoFinderInfo, &catalogInfo, nil, nil, nil);
		
			if (((FileInfo*)catalogInfo.finderInfo)->finderFlags & kIsInvisible)
			return NO;
		}
	}

return YES;
}

+ (BOOL)fsObjectContainsHFS:(DRFSObject *)object
{
	if ([[object parent] effectiveFilesystemMask] & DRFilesystemInclusionMaskHFSPlus | [[object parent] effectiveFilesystemMask] & (1<<4))
	return YES;
	else if ([object effectiveFilesystemMask] & DRFilesystemInclusionMaskHFSPlus | [object effectiveFilesystemMask] & (1<<4))
	return YES;
	
return NO;
}

+ (NSString *)fsObjectFileName:(DRFSObject *)object
{
	if ([KWCommonMethods fsObjectContainsHFS:object])
	{
	BOOL hideExtension = NO;
	NSNumber *fFlags = [object propertyForKey:DRMacFinderFlags inFilesystem:DRHFSPlus mergeWithOtherFilesystems:NO];
	unsigned short fndrFlags = [fFlags unsignedShortValue];
	
		if (([[[object baseName] pathExtension] isEqualTo:@"app"] | [KWCommonMethods isDRFolderIsLocalized:(DRFolder *)object]) && ![object isKindOfClass:[DRFile class]])
		{
			if ([[object baseName] isEqualTo:[(KWDRFolder *)object originalName]])
			return [(KWDRFolder *)object displayName];
			else
			hideExtension = YES;
		}
		else if ([[[object baseName] pathExtension] isEqualTo:@"localized"])
		{
		hideExtension = YES;
		}
		else if ([object isVirtual])
		{
		hideExtension = (0x0010 & fndrFlags);
		}
		else
		{
			if (fFlags)
			hideExtension = (0x0010 & fndrFlags);
			else
			hideExtension = [[[[NSFileManager defaultManager] fileAttributesAtPath:[object sourcePath] traverseLink:YES] objectForKey:NSFileExtensionHidden] boolValue];
		}
		
		NSString *baseName = [object baseName];
		
			if ([[object parent] effectiveFilesystemMask] & (1<<4))
			{
				if ([[baseName substringWithRange:NSMakeRange(0,1)] isEqualTo:@"."])
				{
				baseName = [baseName substringWithRange:NSMakeRange(1,[baseName length] - 1)];
				}
				
				if ([baseName length] > 31)
				{
				NSString *pathExtension;

					if ([[baseName pathExtension] isEqualTo:@""])
					pathExtension = @"";
					else
					pathExtension = [@"." stringByAppendingString:[baseName pathExtension]];

	
				unsigned int fileLength = 31 - [pathExtension length];

				baseName = [[baseName substringWithRange:NSMakeRange(0,fileLength)] stringByAppendingString:pathExtension];
				}
			}
		
		if (hideExtension)
		return [baseName stringByDeletingPathExtension];
		else
		return baseName;
	}
	else if ([[object parent] effectiveFilesystemMask] & DRFilesystemInclusionMaskISO9660)
	{
	return [object mangledNameForFilesystem:DRISO9660LevelTwo];
	}
	else
	{
		if (([[[object baseName] pathExtension] isEqualTo:@"app"] | [KWCommonMethods isDRFolderIsLocalized:(DRFolder *)object]) && ![object isKindOfClass:[DRFile class]])
		{
			NSString *displayName = [(KWDRFolder *)object displayName];
			if ([[object baseName] isEqualTo:[(KWDRFolder *)object originalName]])
			return displayName;
			else
			return [[object baseName] stringByDeletingPathExtension];
		}
		else if ([[[object baseName] pathExtension] isEqualTo:@"localized"])
		{
		return [[object baseName] stringByDeletingPathExtension];
		}
		else
		{
		return [object baseName];
		}
	}
}

+ (unsigned long)getFinderFlagsAtPath:(NSString *)path
{
FSRef possibleInvisibleFile;
FSCatalogInfo catalogInfo;
OSStatus errStat;
errStat = FSPathMakeRef((unsigned char *)[path fileSystemRepresentation], &possibleInvisibleFile, nil);
FSGetCatalogInfo(&possibleInvisibleFile, kFSCatInfoFinderInfo, &catalogInfo, nil, nil, nil);
		
return ((FileInfo*)catalogInfo.finderInfo)->finderFlags;
}

+ (BOOL)isDRFolderIsLocalized:(DRFolder *)folder
{
	if ([folder isVirtual])
	{
		int i=0;
		for (i=0;i<[[folder children] count];i++)
		{
			if ([[[[folder children] objectAtIndex:i] baseName] isEqualTo:@".localized"])
			return YES;
		}
	}
	else
	{
	return [[NSFileManager defaultManager] fileExistsAtPath:[[folder sourcePath] stringByAppendingPathComponent:@".localized"]];
	}
	
return NO;
}

///////////////////
// Other actions //
///////////////////

#pragma mark -
#pragma mark •• Other actions

+ (float)calculateRealFolderSize:(NSString *)path
{
NSTask *du = [[NSTask alloc] init];
NSPipe *pipe = [[NSPipe alloc] init];
NSFileHandle *handle;
NSString *string;
[du setLaunchPath:@"/usr/bin/du"];
[du setArguments:[NSArray arrayWithObjects:@"-s",path,nil]];
[du setStandardOutput:pipe];
[du setStandardError:[NSFileHandle fileHandleWithNullDevice]];
handle=[pipe fileHandleForReading];
[du launch];
string=[[NSString alloc] initWithData:[handle readDataToEndOfFile] encoding:NSASCIIStringEncoding];

	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWConsoleEnabled"] == YES)
	{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWConsoleNotification" object:string];
	NSLog(string);
	}

[du waitUntilExit];
[pipe release];
[du release];

float size = [[[string componentsSeparatedByString:@" "] objectAtIndex:0] floatValue] / 4;
	
[string release];

return size;
}

+ (float)calculateVirtualFolderSize:(DRFSObject *)obj
{
NSArray *children = [(DRFolder *)obj children];
float size = 0;

	int i = 0;
	for (i=0;i<[children count];i++)
	{
	NSAutoreleasePool *subPool = [[NSAutoreleasePool alloc] init];
	
		if (![[children objectAtIndex:i] isVirtual])
		{
			BOOL isDir;
			if ([[NSFileManager defaultManager] fileExistsAtPath:[[children objectAtIndex:i] sourcePath] isDirectory:&isDir] && isDir)
			size = size + [KWCommonMethods calculateRealFolderSize:[[children objectAtIndex:i] sourcePath]];
			else
			size = size + [[[[NSFileManager defaultManager] fileAttributesAtPath:[[children objectAtIndex:i] sourcePath] traverseLink:YES] objectForKey:NSFileSize] floatValue]/2048;
		}
		else
		{
		size = size + [self calculateVirtualFolderSize:[children objectAtIndex:i]];
		}
	
	[subPool release];
	}

return size;
}

+ (NSArray*)allSelectedItemsInTableView:(NSTableView *)tableView fromArray:(NSArray *)array
{
NSMutableArray *items = [NSMutableArray array];
NSEnumerator *selectedRows = [tableView selectedRowEnumerator];
    
	NSNumber *selRow = nil;
    while( (selRow = [selectedRows nextObject]) ) 
	{
        if ([array objectAtIndex:[selRow intValue]]) 
		[items addObject: [array objectAtIndex:[selRow intValue]]];
    }

return items;
}

+ (DRDevice *)getCurrentDevice
{
NSArray *devices = [NSArray arrayWithArray:[DRDevice devices]];

	if ([devices count] > 0)
	{
		int i;
		for (i=0;i< [devices count];i++)
		{
			if ([[[[devices objectAtIndex:i] info] objectForKey:@"DRDeviceProductNameKey"] isEqualTo:[[[NSUserDefaults standardUserDefaults] dictionaryForKey:@"KWDefaultDeviceIdentifier"] objectForKey:@"Product"]])
			return [devices objectAtIndex:i];
		}
	
	return [devices objectAtIndex:0];
	}

return nil;
}

+ (NSWindow *)firstBurnWindow
{
NSArray *windows = [NSApp orderedWindows];

	int x;
	for (x=0;x<[windows count];x++)
	{
		if ([[[windows objectAtIndex:x] delegate] isKindOfClass:[KWDocument class]])
		return [windows objectAtIndex:x];
	}

return nil;
}

+ (NSDictionary *)getDictionaryFromString:(NSString *)string
{
NSArray *lines = [string componentsSeparatedByString:@"\n"];
NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];

	int x;
	for (x=0;x<[lines count];x++)
	{
	NSArray *elements = [[lines objectAtIndex:x] componentsSeparatedByString:@":"];
	
		if ([elements count] > 1)
		{
		NSString *key = [[elements objectAtIndex:0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		id value = [[elements objectAtIndex:1]stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	
			if ([[value lowercaseString] isEqualTo:@"yes"])
			value = [NSNumber numberWithBool:YES];
			else if ([[value lowercaseString] isEqualTo:@"no"])
			value = [NSNumber numberWithBool:NO];
			
		[dictionary setObject:value forKey:key];
		}
	}
	
return dictionary;
}

+ (int)getSizeFromMountedVolume:(NSString *)mountPoint
{
NSTask *df = [[NSTask alloc] init];
NSPipe *pipe = [[NSPipe alloc] init];
NSFileHandle *handle;
NSString *string;
[df setLaunchPath:@"/bin/df"];

[df setArguments:[NSArray arrayWithObject:mountPoint]];
[df setStandardOutput:pipe];
handle=[pipe fileHandleForReading];
[df launch];
string=[[NSString alloc] initWithData:[handle readDataToEndOfFile] encoding:NSASCIIStringEncoding];

	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWConsoleEnabled"] == YES)
	{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWConsoleNotification" object:string];
	NSLog(string);
	}

[df waitUntilExit];
[pipe release];
[df release];

NSArray *objects = [[[string componentsSeparatedByString:@"\n"] objectAtIndex:1] componentsSeparatedByString:@" "];

int size = 0;
int x = 1;

	while (size == 0)
	{
	NSString *object = [objects objectAtIndex:x];
	
		if (![object isEqualTo:@""])
		size = [object intValue];
		
	x = x + 1;
	}
	
[string release];

return size;
}

+ (void)writeLogWithFilePath:(NSString *)path withCommand:(NSString *)command withLog:(NSString *)log
{
NSString *errorLog;
errorLog = [@"File: " stringByAppendingString:[[NSFileManager defaultManager] displayNameAtPath:path]];
errorLog = [errorLog stringByAppendingString:[@"\rPath: " stringByAppendingString:path]];
errorLog = [errorLog stringByAppendingString:[@"\rTask: " stringByAppendingString:command]];
errorLog = [errorLog stringByAppendingString:[@"\rDate and Time: " stringByAppendingString:[[NSDate date] description]]];
errorLog = [errorLog stringByAppendingString:@"\rLog:\r"];
errorLog = [errorLog stringByAppendingString:log];
		
NSString *logFile = [NSHomeDirectory() stringByAppendingString:@"/Library/Logs/Burn Errors.log"];
			
	if ([[NSFileManager defaultManager] fileExistsAtPath:logFile])
	errorLog = [[[NSString stringWithContentsOfFile:logFile] stringByAppendingString:@"-------------------------------------------------------\r\r"] stringByAppendingString:errorLog];
			
[errorLog writeToFile:logFile atomically:YES];
}

+ (DRDevice *)savedDevice
{
	NSArray *devices = [DRDevice devices];
	
	int i;
	for (i=0;i< [devices count];i++)
	{
		if ([[[[devices objectAtIndex:i] info] objectForKey:@"DRDeviceProductNameKey"] isEqualTo:[[[NSUserDefaults standardUserDefaults] dictionaryForKey:@"KWDefaultDeviceIdentifier"] objectForKey:@"Product"]])
		return [devices objectAtIndex:i];
	}
	
return [devices objectAtIndex:0];
}

+ (NSString *)defaultSizeForMedia:(int)media
{
NSArray *sizes;

	if (media == 1)
	{
	sizes = [NSArray arrayWithObjects:@"63", @"74", @"80", @"90", @"99", nil];
		
	return [sizes objectAtIndex:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultCDMedia"] intValue]];
	}
	else
	{
	sizes = [NSArray arrayWithObjects:@"4506", @"8110", @"8960", @"12687", @"16321", nil];
	
	return [sizes objectAtIndex:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultDVDMedia"] intValue]];
	}
}

+ (NSImage *)getImageForName:(NSString *)name
{
NSDictionary *customImageDictionary = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSImage imageNamed:@"General"], [NSImage imageNamed:@"Burn"], [[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(kGenericCDROMIcon)], [NSImage imageNamed:@"Audio CD"], [NSImage imageNamed:@"DVD"], [NSImage imageNamed:@"Advanced"], nil] forKeys:[NSArray arrayWithObjects:@"General", @"Burner",@"Data",@"Audio",@"Video",@"Advanced",nil]];

return [customImageDictionary objectForKey:name];
}

+ (void)setupBurnerPopup:(NSPopUpButton *)popup
{
[popup removeAllItems];
		
	int i;
	NSArray *devices = [DRDevice devices];
	for (i=0;i< [devices count];i++)
	{
	[popup addItemWithTitle:[[devices objectAtIndex:i] displayName]];
	}
		
	if ([devices count] > 0)
	{
		if ([[NSUserDefaults standardUserDefaults] dictionaryForKey:@"KWDefaultDeviceIdentifier"])
		{
		[popup selectItemWithTitle:[[KWCommonMethods getCurrentDevice] displayName]];
		}
		else
		{
		NSMutableDictionary *burnDict = [[NSMutableDictionary alloc] init];
	
		[burnDict setObject:[[[devices objectAtIndex:0] info] objectForKey:@"DRDeviceProductNameKey"] forKey:@"Product"];
		[burnDict setObject:[[[devices objectAtIndex:0] info] objectForKey:@"DRDeviceVendorNameKey"] forKey:@"Vendor"];
		[burnDict setObject:@"" forKey:@"SerialNumber"];

		[[NSUserDefaults standardUserDefaults] setObject:[burnDict copy] forKey:@"KWDefaultDeviceIdentifier"];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:@"KWMediaChanged" object:nil];
	
		[popup selectItemWithTitle:[[devices objectAtIndex:0] displayName]];

		[burnDict release];
		}
	}
}

+ (NSString *)ffmpegPath
{
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWUseCustomFFMPEG"] == YES && [[NSFileManager defaultManager] fileExistsAtPath:[[NSUserDefaults standardUserDefaults] objectForKey:@"KWCustomFFMPEG"]])
	return [[NSUserDefaults standardUserDefaults] objectForKey:@"KWCustomFFMPEG"];
	else
	return [[NSBundle mainBundle] pathForResource:@"ffmpeg" ofType:@""];
}

+ (NSArray *)diskImageTypes
{
	if ([KWCommonMethods isPanther])
	return [NSArray arrayWithObjects:@"sparseimage",@"toast",@"img", @"dmg", @"iso", @"cue",@"cdr", nil];
	else
	return [NSArray arrayWithObjects:@"sparseimage",@"toast", @"img", @"dmg", @"iso", @"cue", @"toc",@"cdr", nil];
}

@end
