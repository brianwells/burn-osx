//
//  KWCommonMethods.m
//  Burn
//
//  Created by Maarten Foukhar on 22-4-07.
//  Copyright 2009 Kiwi Fruitware. All rights reserved.
//

#import "KWCommonMethods.h"
#import "KWDRFolder.h"
#import "KWWindowController.h"
#import <QuickTime/QuickTime.h>
#import <QTKit/QTKit.h>

@interface NSFileManager (MyUndocumentedMethodsForNSTheClass)

- (BOOL)createDirectoryAtPath:(NSString *)path withIntermediateDirectories:(BOOL)createIntermediates attributes:(NSDictionary *)attributes error:(NSError **)error;
- (BOOL)copyItemAtPath:(NSString *)srcPath toPath:(NSString *)dstPath error:(NSError **)error;
- (BOOL)createSymbolicLinkAtPath:(NSString *)path withDestinationPath:(NSString *)destPath error:(NSError **)error;
- (BOOL)removeItemAtPath:(NSString *)path error:(NSError **)error;

@end

@interface NSString (NewMethodsForNSString)

- (BOOL)writeToFile:(NSString *)path atomically:(BOOL)useAuxiliaryFile encoding:(NSStringEncoding)enc error:(NSError **)error;

@end


@implementation KWCommonMethods

////////////////
// OS actions //
////////////////

#pragma mark -
#pragma mark •• OS actions

+ (int)OSVersion
{
	SInt32 MacVersion;
	
	Gestalt(gestaltSystemVersion, &MacVersion);
	
	return (int)MacVersion;
}

+ (BOOL)isQuickTimeSevenInstalled
{
	long version;
	OSErr result;

	result = Gestalt(gestaltQuickTime,&version);
	return ((result == noErr) && (version >= 0x07000000));
}

///////////////////////////
// String format actions //
///////////////////////////

#pragma mark -
#pragma mark •• String format actions

+ (NSString *)formatTime:(int)time
{
	float hours = time / 60 / 60;
	float minutes = time / 60 - (hours * 60);
	float seconds = time - (minutes * 60) - (hours * 60 * 60);

	return [NSString stringWithFormat:@"%02.0f:%02.0f:%02.0f", hours, minutes, seconds];
}

+ (NSString *)makeSizeFromFloat:(float)size
{
	float blockSize;
	
	if ([KWCommonMethods OSVersion] >= 4192)
		blockSize = 1000;
	else
		blockSize = 1024;

	if (size < blockSize)
	{
		if (size > 0)
			return [NSString localizedStringWithFormat: @"%.0f KB", 4];
		else
			return [NSString localizedStringWithFormat: @"%.0f KB", size];
	}
	
	
		
	BOOL isKB = (size < blockSize * blockSize);
	BOOL isMB = (size < blockSize * blockSize * blockSize);
	BOOL isGB = (size < blockSize * blockSize * blockSize * blockSize);
	BOOL isTB = (size < blockSize * blockSize * blockSize * blockSize * blockSize);
	
	if (isKB)
		return [NSString localizedStringWithFormat: @"%.0f KB", size / blockSize];
	
	if (isMB)
	{
		NSString *sizeString = [NSString localizedStringWithFormat: @"%.1f", size  / blockSize / blockSize];
		
			if ([[sizeString substringFromIndex:[sizeString length] - 1] isEqualTo:@"0"])
			sizeString = [sizeString substringWithRange:NSMakeRange(0, [sizeString length] - 2)];
	
		return [NSString localizedStringWithFormat: @"%@ MB", sizeString];
	}
	
	if (isGB)
	{
		NSString *sizeString = [NSString localizedStringWithFormat: @"%.2f", size  / blockSize / blockSize / blockSize];
		
			if ([[sizeString substringFromIndex:[sizeString length] - 1] isEqualTo:@"0"])
			sizeString = [sizeString substringWithRange:NSMakeRange(0, [sizeString length] - 1)];
			
			if ([[sizeString substringFromIndex:[sizeString length] - 1] isEqualTo:@"0"])
			sizeString = [sizeString substringWithRange:NSMakeRange(0, [sizeString length] - 2)];
	
		return [NSString localizedStringWithFormat: @"%@ GB", sizeString];
	}
	
	if (isTB)
	{
		NSString *sizeString = [NSString localizedStringWithFormat: @"%.2f", size  / blockSize / blockSize / blockSize / blockSize];
		
			if ([[sizeString substringFromIndex:[sizeString length] - 1] isEqualTo:@"0"])
			sizeString = [sizeString substringWithRange:NSMakeRange(0, [sizeString length] - 1)];
			
			if ([[sizeString substringFromIndex:[sizeString length] - 1] isEqualTo:@"0"])
			sizeString = [sizeString substringWithRange:NSMakeRange(0, [sizeString length] - 2)];
	
		return [NSString localizedStringWithFormat: @"%@ TB", sizeString];
	}	

	return [NSString localizedStringWithFormat: @"%.0f KB", 0];
}

//////////////////
// File actions //
//////////////////

#pragma mark -
#pragma mark •• File actions

+ (NSString *)uniquePathNameFromPath:(NSString *)path
{
	if ([[NSFileManager defaultManager] fileExistsAtPath:path])
	{
		NSString *newPath = [path stringByDeletingPathExtension];
		NSString *pathExtension;

		if ([[path pathExtension] isEqualTo:@""])
			pathExtension = @"";
		else
			pathExtension = [@"." stringByAppendingString:[path pathExtension]];

		int y = 0;
		while ([[NSFileManager defaultManager] fileExistsAtPath:[newPath stringByAppendingString:pathExtension]])
		{
			newPath = [path stringByDeletingPathExtension];
			
			y = y + 1;
			newPath = [NSString stringWithFormat:@"%@ %i", newPath, y];
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
		
		if ([sheet runModalForDirectory:nil file:file] == NSFileHandlingPanelOKButton)
			return [sheet filename];
		else
			return nil;
	}
	else
	{
		return [KWCommonMethods uniquePathNameFromPath:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWTemporaryLocation"] stringByAppendingPathComponent:file]];
	}
}

+ (BOOL)isBundleExtension:(NSString *)extension
{
	NSString *testFile = [@"/tmp/kiwiburntest" stringByAppendingPathExtension:extension];
	BOOL isPackage;
	
	if ([KWCommonMethods createDirectoryAtPath:testFile errorString:nil])
	{
		isPackage = [[NSWorkspace sharedWorkspace] isFilePackageAtPath:testFile];
		[KWCommonMethods removeItemAtPath:testFile];
	}
	else
	{
		isPackage = NO;
	}

	return isPackage;
}

//////////////////
// Icon actions //
//////////////////

#pragma mark -
#pragma mark •• Icon actions

+ (BOOL)hasCustomIcon:(DRFSObject *)object
{
	if ([object isVirtual])
	return NO;

	FSRef possibleCustomIcon;
	FSCatalogInfo catalogInfo;
	OSStatus errStat;
	errStat = FSPathMakeRef((unsigned char *)[[object sourcePath] fileSystemRepresentation], &possibleCustomIcon, nil);
	FSGetCatalogInfo(&possibleCustomIcon, kFSCatInfoFinderInfo, &catalogInfo, nil, nil, nil);
		
	if (((FileInfo*)catalogInfo.finderInfo)->finderFlags & kHasCustomIcon)
		return YES;
	
	NSString *pathExtension = [[object baseName] pathExtension];
	BOOL isFile = [object isKindOfClass:[DRFile class]];
	
	if ([pathExtension isEqualTo:@"app"] && !isFile | [pathExtension isEqualTo:@"prefPane"] && !isFile)
		return YES;

	return NO;
}

+ (NSImage *)getIcon:(DRFSObject *)fsObj
{
	NSImage *img;
	NSWorkspace *sharedWorkspace = [NSWorkspace sharedWorkspace];
	NSString *baseName = [fsObj baseName];
	NSString *pathExtension = [baseName pathExtension];
	NSString *sourcePath;
	BOOL containsHFS = [KWCommonMethods fsObjectContainsHFS:fsObj];
	BOOL hasCustomIcon = [KWCommonMethods hasCustomIcon:fsObj];

	if (![fsObj isVirtual])
		sourcePath = [fsObj sourcePath];

	if ([fsObj isKindOfClass:[DRFile class]])
	{
		if (containsHFS && hasCustomIcon)
		{
			img = [sharedWorkspace iconForFile:sourcePath];
		}
		else
		{
			NSString *fileType = @"";
		
			if (containsHFS)
				fileType = NSFileTypeForHFSTypeCode([[[[NSFileManager defaultManager] fileAttributesAtPath:sourcePath traverseLink:YES] objectForKey:NSFileHFSTypeCode] longValue]);
	
			if (![KWCommonMethods isBundleExtension:pathExtension] && ![pathExtension isEqualTo:@""])
				img = [sharedWorkspace iconForFileType:pathExtension];
			else
				img = [sharedWorkspace iconForFileType:fileType];
		}
	}
	else
	{
		NSString *fsObjectFileName = [KWCommonMethods fsObjectFileName:fsObj];
		NSString *displayName = [(KWDRFolder *)fsObj displayName];
		NSImage *folderIcon = [(KWDRFolder *)fsObj folderIcon];
		BOOL isFilePackage = [(KWDRFolder *)fsObj isFilePackage];
		
		if ([fsObj isVirtual])
		{
			if (containsHFS && folderIcon)
			{
				img = folderIcon;
			}
			else if (isFilePackage && [baseName isEqualTo:fsObjectFileName] | [[baseName stringByDeletingPathExtension] isEqualTo:fsObjectFileName] | [fsObjectFileName isEqualTo:displayName])
			{
				if ([pathExtension isEqualTo:@"app"])
					img = folderIcon;
				else
					img = [sharedWorkspace iconForFileType:pathExtension];
			}
			else
			{
				//Just a folder kGenericFolderIcon creates weird folders on Intel
				img = [sharedWorkspace iconForFile:@"/bin"];
			}
		}
		else
		{
			if (containsHFS && hasCustomIcon)
			{
				img = [sharedWorkspace iconForFile:sourcePath];
			}
			else if (isFilePackage && [baseName isEqualTo:fsObjectFileName] | [[baseName stringByDeletingPathExtension] isEqualTo:fsObjectFileName] | [fsObjectFileName isEqualTo:displayName])
			{
				img = [sharedWorkspace iconForFile:sourcePath];
			}
			else
			{
				//Just a folder kGenericFolderIcon creates weird folders on Intel
				img = [sharedWorkspace iconForFile:@"/bin"];
			}
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

	return [img retain];
}

////////////////////////
// Filesystem actions //
////////////////////////

#pragma mark -
#pragma mark •• Filesystem actions

+ (BOOL)isDRFSObjectVisible:(DRFSObject *)object 
{
	NSString *fileSystemType = nil;

	if ([[object parent] effectiveFilesystemMask] & DRFilesystemInclusionMaskHFSPlus)
		fileSystemType = DRHFSPlus;
	else if ([[object parent] effectiveFilesystemMask] & DRFilesystemInclusionMaskJoliet)
		fileSystemType = DRJoliet;
	else if ([[object parent] effectiveFilesystemMask] & DRFilesystemInclusionMaskISO9660)
		fileSystemType = DRISO9660;
	else if ([[object parent] effectiveFilesystemMask] & 1<<2)
		fileSystemType = @"DRUDF";

	NSNumber *invisible = nil;
		
	if (fileSystemType)
		invisible = [object propertyForKey:DRInvisible inFilesystem:fileSystemType mergeWithOtherFilesystems:NO];

	if (invisible)
		return ![invisible boolValue];

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
	NSString *baseName = [object baseName];
	NSString *pathExtension = [baseName pathExtension];

	if ([KWCommonMethods fsObjectContainsHFS:object])
	{
		BOOL hideExtension = NO;
		NSNumber *fFlags = [object propertyForKey:DRMacFinderFlags inFilesystem:DRHFSPlus mergeWithOtherFilesystems:NO];
		unsigned short fndrFlags = [fFlags unsignedShortValue];
	
		if (([pathExtension isEqualTo:@"app"] | [KWCommonMethods isDRFolderIsLocalized:(DRFolder *)object]) && ![object isKindOfClass:[DRFile class]])
		{
			if ([baseName isEqualTo:[(KWDRFolder *)object originalName]])
				return [(KWDRFolder *)object displayName];
			else
				hideExtension = YES;
		}
		else if ([pathExtension isEqualTo:nil])
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
		
		if ([[object parent] effectiveFilesystemMask] & (1<<4))
		{
			if ([baseName hasPrefix:@"."]) 
			{
				baseName = [baseName substringWithRange:NSMakeRange(1,[baseName length] - 1)];
			}
				
			if ([baseName length] > 31)
			{
				NSString *newPathExtension;

				if ([pathExtension isEqualTo:@""])
					newPathExtension = @"";
				else
					newPathExtension = [@"." stringByAppendingString:pathExtension];

	
				unsigned int fileLength = 31 - [newPathExtension length];

				baseName = [[baseName substringWithRange:NSMakeRange(0,fileLength)] stringByAppendingString:newPathExtension];
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
		if (([pathExtension isEqualTo:@"app"] | [KWCommonMethods isDRFolderIsLocalized:(DRFolder *)object]) && ![object isKindOfClass:[DRFile class]])
		{
			NSString *displayName = [(KWDRFolder *)object displayName];
			if ([baseName isEqualTo:[(KWDRFolder *)object originalName]])
				return displayName;
			else
				return [baseName stringByDeletingPathExtension];
		}
		else if ([pathExtension isEqualTo:nil])
		{
			return [baseName stringByDeletingPathExtension];
		}
		else
		{
			return baseName;
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

+ (int)maxLabelLength:(DRFolder *)folder
{
	if ([folder explicitFilesystemMask] == DRFilesystemInclusionMaskHFSPlus)
		return 255;
	else if ([folder explicitFilesystemMask] == 1<<2)
		return 126;
	else if ([folder explicitFilesystemMask] == 1<<4)
		return 32;
	else if ([folder explicitFilesystemMask] == DRFilesystemInclusionMaskISO9660)
		return 30;
	else if ([folder explicitFilesystemMask] == DRFilesystemInclusionMaskJoliet)
		return 16;
		
	return 32;
}

///////////////////
// Error actions //
///////////////////

#pragma mark -
#pragma mark •• Error actions

+ (BOOL)createDirectoryAtPath:(NSString *)path errorString:(NSString **)error
{
	BOOL succes = YES;
	NSString *details;
	NSFileManager *defaultManager = [NSFileManager defaultManager];
	
	if (![defaultManager fileExistsAtPath:path])
	{
		if ([KWCommonMethods OSVersion] >= 0x1050)
		{
			NSError *myError;
			succes = [defaultManager createDirectoryAtPath:path withIntermediateDirectories:NO attributes:nil error:&myError];
			
			if (!succes)
				details = [myError localizedDescription];
		}
		else
		{
			succes = [defaultManager createDirectoryAtPath:path attributes:nil];
			NSString *folder = [defaultManager displayNameAtPath:path];
			NSString *parent = [defaultManager displayNameAtPath:[path stringByDeletingLastPathComponent]];
			details = [NSString stringWithFormat:@"Failed to create folder '%@' in '%@'.", folder, parent];
		}
		
		if (!succes)
			*error = details;
	}

	return succes;
}

+ (BOOL)copyItemAtPath:(NSString *)inPath toPath:(NSString *)newPath errorString:(NSString **)error
{
	BOOL succes = YES;
	NSString *details = @"";
	NSFileManager *defaultManager = [NSFileManager defaultManager];

	if ([KWCommonMethods OSVersion] >= 0x1050)
	{
		NSError *myError;
		succes = [defaultManager copyItemAtPath:inPath toPath:newPath error:&myError];
			
		if (!succes)
			details = [myError localizedDescription];
	}
	else
	{
		succes = [defaultManager copyPath:inPath toPath:newPath handler:nil];
	}
		
	if (!succes)
	{
		NSString *inFile = [defaultManager displayNameAtPath:inPath];
		NSString *outFile = [defaultManager displayNameAtPath:[newPath stringByDeletingLastPathComponent]];
		details = [NSString stringWithFormat:NSLocalizedString(@"Failed to copy '%@' to '%@'. %@", nil), inFile, outFile, details];
		*error = details;
	}
		

	return succes;
}

+ (BOOL)createSymbolicLinkAtPath:(NSString *)path withDestinationPath:(NSString *)dest errorString:(NSString **)error;
{
	BOOL succes;
	NSFileManager *defaultManager = [NSFileManager defaultManager];
	
	NSError *tempError;
	
	if ([KWCommonMethods OSVersion] >= 0x1050)
		succes = [defaultManager createSymbolicLinkAtPath:path withDestinationPath:dest error:&tempError];
	else
		succes = [defaultManager createSymbolicLinkAtPath:path pathContent:dest];
		
	if (!succes)
	{
		NSLog(@"Path: %@, Destination: %@", path, dest);
		NSLog([tempError localizedDescription]);
		succes = [KWCommonMethods copyItemAtPath:path toPath:dest errorString:&*error];
	}
	
	return succes;
}

+ (BOOL)removeItemAtPath:(NSString *)path
{
	BOOL succes = YES;
	NSString *details;
	NSFileManager *defaultManager = [NSFileManager defaultManager];
	
	if ([defaultManager fileExistsAtPath:path])
	{
		if ([KWCommonMethods OSVersion] >= 0x1050)
		{
			NSError *myError;
			succes = [defaultManager removeItemAtPath:path error:&myError];
			
			if (!succes)
				details = [myError localizedDescription];
		}
		else
		{
			succes = [defaultManager removeFileAtPath:path handler:nil];
			details = [NSString stringWithFormat:NSLocalizedString(@"File path: %@", nil), path];
		}
		
		if (!succes)
		{
			NSString *file = [defaultManager displayNameAtPath:path];
			[KWCommonMethods standardAlertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Failed to delete '%@'.", nil), file ] withInformationText:details withParentWindow:nil];
		}
	}

	return succes;
}

+ (BOOL)writeString:(NSString *)string toFile:(NSString *)path errorString:(NSString **)error
{
	BOOL succes;
	NSString *details;
	
	if ([KWCommonMethods OSVersion] >= 0x1040)
	{
		NSError *myError;
		succes = [string writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&myError];
			
			if (!succes)
			details = [myError localizedDescription];
	}
	else
	{
		succes = [string writeToFile:path atomically:YES];
		NSFileManager *defaultManager = [NSFileManager defaultManager];
		NSString *file = [defaultManager displayNameAtPath:path];
		NSString *parent = [defaultManager displayNameAtPath:[path stringByDeletingLastPathComponent]];
		details = [NSString stringWithFormat:NSLocalizedString(@"Failed to write '%@' to '%@'", nil), file, parent];
	}

	if (!succes)
		*error = details;

	return succes;
}

+ (BOOL)writeDictionary:(NSDictionary *)dictionary toFile:(NSString *)path errorString:(NSString **)error
{
	if (![dictionary writeToFile:path atomically:YES])
	{
		NSFileManager *defaultManager = [NSFileManager defaultManager];
		NSString *file = [defaultManager displayNameAtPath:path];
		NSString *parent = [defaultManager displayNameAtPath:[path stringByDeletingLastPathComponent]];
		*error = [NSString stringWithFormat:NSLocalizedString(@"Failed to write '%@' to '%@'", nil), file, parent];
	
		return NO;
	}

	return YES;
}

+ (BOOL)saveImage:(NSImage *)image toPath:(NSString *)path errorString:(NSString **)error
{
	NSData *tiffData = [image TIFFRepresentation];
	NSBitmapImageRep *bitmap = [NSBitmapImageRep imageRepWithData:tiffData];
	NSData *imageData = [bitmap representationUsingType:NSPNGFileType properties:nil];
	
	BOOL succes;
	NSString *details;
	
	if ([KWCommonMethods OSVersion] >= 0x1040)
	{
		NSError *writeError;
		succes = [imageData writeToFile:path options:NSAtomicWrite error:&writeError];
			
		if (!succes)
			details = [writeError localizedDescription];
	}
	else
	{
		succes = [imageData writeToFile:path atomically:YES];
		details = [NSString stringWithFormat:@"Failed to save image to Path: %@", path];
	}
	
	if (!succes)
		*error = details;
	
	return succes;
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
	[KWCommonMethods logCommandIfNeeded:du];
	[du launch];
	string=[[NSString alloc] initWithData:[handle readDataToEndOfFile] encoding:NSUTF8StringEncoding];
	
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWDebug"])
		NSLog(string);

	[du waitUntilExit];
	[pipe release];
	[du release];

	float size = [[[string componentsSeparatedByString:@" "] objectAtIndex:0] floatValue] / 4;
	
	[string release];

	return size;
}

+ (float)calculateVirtualFolderSize:(DRFSObject *)obj
{
	float size = 0;
	
	NSArray *children = [(DRFolder *)obj children];
	int i = 0;
	for (i=0;i<[children count];i++)
	{
		NSAutoreleasePool *subPool = [[NSAutoreleasePool alloc] init];
		
		DRFSObject *child = [children objectAtIndex:i];
	
		if (![child isVirtual])
		{
			BOOL isDir;
			NSString *sourcePath = [child sourcePath];
			NSFileManager *defaultManager = [NSFileManager defaultManager];
			
			if ([defaultManager fileExistsAtPath:sourcePath isDirectory:&isDir] && isDir)
				size = size + [KWCommonMethods calculateRealFolderSize:sourcePath];
			else
				size = size + [[[defaultManager fileAttributesAtPath:sourcePath traverseLink:YES] objectForKey:NSFileSize] floatValue] / 2048;
		}
		else
		{
			size = size + [self calculateVirtualFolderSize:child];
		}
	
		[subPool release];
	}

	return size;
}

+ (NSArray*)allSelectedItemsInTableView:(NSTableView *)tableView fromArray:(NSArray *)array
{
	NSMutableArray *items = [NSMutableArray array];
	NSIndexSet *indexSet = [tableView selectedRowIndexes];
	
	unsigned current_index = [indexSet firstIndex];
    while (current_index != NSNotFound)
    {
		if ([array objectAtIndex:current_index]) 
			[items addObject:[array objectAtIndex:current_index]];
			
        current_index = [indexSet indexGreaterThanIndex: current_index];
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
		DRDevice *device = [devices objectAtIndex:i];
		
			if ([[[device info] objectForKey:@"DRDeviceProductNameKey"] isEqualTo:[[[NSUserDefaults standardUserDefaults] dictionaryForKey:@"KWDefaultDeviceIdentifier"] objectForKey:@"Product"]])
				return device;
		}
	
		return [devices objectAtIndex:0];
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
	[KWCommonMethods logCommandIfNeeded:df];
	[df launch];

	string=[[NSString alloc] initWithData:[handle readDataToEndOfFile] encoding:NSUTF8StringEncoding];
	
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWDebug"] == YES)
		NSLog(string);

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

+ (NSString *)defaultSizeForMedia:(NSString *)media
{
	NSArray *sizes;

	if ([media isEqualTo:@"KWDefaultCDMedia"])
		sizes = [NSArray arrayWithObjects:@"63", @"74", @"80", @"90", @"99", nil];
	else
		sizes = [NSArray arrayWithObjects:@"4506", @"8110", @"8960", @"12687", @"16321", nil];

	return [sizes objectAtIndex:[[[NSUserDefaults standardUserDefaults] objectForKey:media] intValue]];
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
	if ([KWCommonMethods OSVersion] < 0x1040)
		return [NSArray arrayWithObjects:@"sparseimage",@"toast",@"img", @"dmg", @"iso", @"cue",@"cdr", nil];
	else
		return [NSArray arrayWithObjects:@"sparseimage",@"toast", @"img", @"dmg", @"iso", @"cue", @"toc",@"cdr", nil];
}

//Create an array with indexes of selected rows in a tableview
+ (NSArray *)selectedRowsAtRowIndexes:(NSIndexSet *)indexSet
{
	//Get the selected rows and save them
	NSMutableArray *selectedRows = [NSMutableArray array];
	
	unsigned current_index = [indexSet lastIndex];
    while (current_index != NSNotFound)
    {
		[selectedRows addObject:[NSNumber numberWithUnsignedInt:current_index]];
		current_index = [indexSet indexLessThanIndex: current_index];
    }
	
	return selectedRows;
}

//Return an array of QuickTime and ffmpeg filetypes
+ (NSArray *)mediaTypes
{
	NSMutableArray *addFileTypes = [NSMutableArray arrayWithArray:[KWCommonMethods quicktimeTypes]];
	NSArray *extraExtensions = [NSArray arrayWithObjects:@"vob",@"wma",@"wmv",@"asf",@"asx",@"ogg",@"flv",@"rm",@"flac",nil];
		
	int i;
	for (i=0;i<[extraExtensions count];i++)
	{
		NSString *extension = [extraExtensions objectAtIndex:i];
		
		if ([addFileTypes indexOfObject:extension] == NSNotFound)
			[addFileTypes addObject:extension];
	}
	
	return addFileTypes;
}

//Return an array of QuickTime filetypes
+ (NSArray *)quicktimeTypes
{
	NSMutableArray *filetypes = [NSMutableArray array];

	if ([KWCommonMethods isQuickTimeSevenInstalled])
	{
		[filetypes addObjectsFromArray:[QTMovie movieFileTypes:QTIncludeCommonTypes]];
	}
	else
	{
		NSMutableArray *qtTypes = [NSMutableArray array];
		ComponentDescription findCD = {0, 0, 0, 0, 0};
		ComponentDescription infoCD = {0, 0, 0, 0, 0};
		Component comp = NULL;
		OSErr err = noErr;

		findCD.componentType = MovieImportType;
		findCD.componentFlags = 0;

		while (comp = FindNextComponent(comp, &findCD)) 
		{
			err = GetComponentInfo(comp, &infoCD, nil, nil, nil);
			if (err == noErr) 
			{
				if (infoCD.componentFlags & movieImportSubTypeIsFileExtension)
					[qtTypes addObject:[[[NSString stringWithCString:(char *)&infoCD.componentSubType length:sizeof(OSType)] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] lowercaseString]];
				else 
					[qtTypes addObject:[NSString stringWithFormat:@"\'%@\'", [NSString stringWithCString:(char *)&infoCD.componentSubType length:sizeof(OSType)]]];
			}
		}
	
		[filetypes addObjectsFromArray:qtTypes];
	}

	//Remove midi since it doesn't work
	if ([filetypes indexOfObject:@"'Midi'"] != NSNotFound)
		[filetypes removeObjectAtIndex:[filetypes indexOfObject:@"'Midi'"]];
	if ([filetypes indexOfObject:@"mid"] != NSNotFound)
		[filetypes removeObjectAtIndex:[filetypes indexOfObject:@"mid"]];
	if ([filetypes indexOfObject:@"midi"] != NSNotFound)
		[filetypes removeObjectAtIndex:[filetypes indexOfObject:@"midi"]];
	
	return filetypes;
}

+ (int)createDVDFolderAtPath:(NSString *)path ofType:(int)type fromTableData:(id)tableData errorString:(NSString **)error
{
	int succes;
	int x, z = 0;
	NSArray *files;
	NSPredicate *trackPredicate;

	if (type == 0)
	{
		files = [NSArray arrayWithObjects:@"AUDIO_TS.IFO", @"AUDIO_TS.VOB", @"AUDIO_TS.BUP", @"AUDIO_PP.IFO",
													@"AUDIO_SV.IFO", @"AUDIO_SV.VOB", @"AUDIO_SV.BUP", nil];
		trackPredicate = [NSPredicate predicateWithFormat:@"SELF MATCHES 'ATS_\\\\d\\\\d_\\\\d\\\\.(?:IFO|AOB|BUP)'"];
	}
	else
	{
		files = [NSArray arrayWithObjects:@"VIDEO_TS.IFO", @"VIDEO_TS.VOB", @"VIDEO_TS.BUP", @"VTS.IFO", @"VTS.BUP", nil];
		trackPredicate = [NSPredicate predicateWithFormat:@"SELF MATCHES 'VTS_\\\\d\\\\d_\\\\d\\\\.(?:IFO|VOB|BUP)'"];
	}

	NSDictionary *currentData = [tableData objectAtIndex:0];
	
	NSFileManager *defaultManager = [NSFileManager defaultManager];
	
	if (![KWCommonMethods createDirectoryAtPath:path errorString:&*error])
		return 1;
		
	// create DVD folder
	if (![KWCommonMethods createDirectoryAtPath:[path stringByAppendingPathComponent:@"AUDIO_TS"] errorString:&*error])
		return 1;
	if (![KWCommonMethods createDirectoryAtPath:[path stringByAppendingPathComponent:@"VIDEO_TS"] errorString:&*error])
		return 1;
	
	// folderName should be AUDIO_TS or VIDEO_TS depending on the type
	NSString *folderPath = [currentData objectForKey:@"Path"];
	NSString *folderName = [currentData objectForKey:@"Name"];
		
	// copy or link contents that conform to standard
	succes = 0;
	NSArray *folderContents = [defaultManager directoryContentsAtPath:folderPath];
		
	for (x = 0; x < [folderContents count]; x++) 
	{
		NSString *fileName = [[folderContents objectAtIndex:x] uppercaseString];
		NSString *filePath = [folderPath stringByAppendingPathComponent:[folderContents objectAtIndex:x]];
		BOOL isDir;
			
		if ([defaultManager fileExistsAtPath:filePath isDirectory:&isDir] && !isDir) 
		{
				// normal file... check name
			if ([files containsObject:fileName] || [trackPredicate evaluateWithObject:fileName]) 
			{
					// proper name... link or copy
				NSString *dstPath = [[path stringByAppendingPathComponent:folderName] stringByAppendingPathComponent:fileName];
				BOOL result = [KWCommonMethods createSymbolicLinkAtPath:dstPath withDestinationPath:filePath errorString:&*error];
					
				if (result == NO)
					succes = 1;
				if (succes == 1)
					break; 
				z++;
			}
		}
	}
		
	if (z == 0)
		succes = 1;
		
	return succes;
}

+ (void)logCommandIfNeeded:(NSTask *)command
{
	//Set environment to UTF-8
	NSMutableDictionary *environment = [NSMutableDictionary dictionaryWithDictionary:[[NSProcessInfo processInfo] environment]];
	[environment setObject:@"en_US.UTF-8" forKey:@"LC_ALL"];
	[command setEnvironment:environment];

	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWDebug"] == YES)
	{
		NSArray *showArgs = [command arguments];
		NSString *commandString = [command launchPath];

		int i;
		for (i=0;i<[showArgs count];i++)
		{
			commandString = [NSString stringWithFormat:@"%@ %@", commandString, [showArgs objectAtIndex:i]];
		}
	
		NSLog(commandString);
	}
}

+ (BOOL)launchNSTaskAtPath:(NSString *)path withArguments:(NSArray *)arguments outputError:(BOOL)error outputString:(BOOL)string output:(id *)data
{
	id output;
	NSTask *task = [[NSTask alloc] init];
	NSPipe *pipe =[ [NSPipe alloc] init];
	NSPipe *outputPipe = [[NSPipe alloc] init];
	NSFileHandle *handle;
	NSFileHandle *outputHandle;
	NSString *errorString = @"";
	[task setLaunchPath:path];
	[task setArguments:arguments];
	[task setStandardError:pipe];
	handle = [pipe fileHandleForReading];
	
	if (!error)
	{
		[task setStandardOutput:outputPipe];
		outputHandle=[outputPipe fileHandleForReading];
	}
	
	[KWCommonMethods logCommandIfNeeded:task];
	[task launch];
	
	if (error)
		output = [handle readDataToEndOfFile];
	else
		output = [outputHandle readDataToEndOfFile];
		
	if (string)
	{
		output = [[[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding] autorelease];
		
		if (!error)
			errorString = [[[NSString alloc] initWithData:[handle readDataToEndOfFile] encoding:NSUTF8StringEncoding] autorelease];

		if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWDebug"])
			NSLog(@"%@\n%@", output, errorString);
	}
		
	[task waitUntilExit];
	
	int result = [task terminationStatus];

	if (!error && result != 0)
		output = errorString;
	
	[pipe release];
	[outputPipe release];
	[task release];

	*data = output;
	
	return (result == 0);
}

+ (void)standardAlertWithMessageText:(NSString *)message withInformationText:(NSString *)information withParentWindow:(NSWindow *)parent
{
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert addButtonWithTitle:NSLocalizedString(@"OK", Localized)];
	[alert setMessageText:message];
	[alert setInformativeText:information];
	
	if (parent)
		[alert beginSheetModalForWindow:parent modalDelegate:self didEndSelector:nil contextInfo:nil];
	else
		[alert runModal];
}

@end