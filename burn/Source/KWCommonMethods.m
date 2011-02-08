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
#if MAC_OS_X_VERSION_MAX_ALLOWED < 1050
#import <QuickTime/QuickTime.h>
#endif
#ifdef USE_QTKIT
#import <QTKit/QTKit.h>
#endif

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

+ (NSInteger)OSVersion
{
	SInt32 MacVersion;
	
	Gestalt(gestaltSystemVersion, &MacVersion);
	
	return (NSInteger)MacVersion;
}

+ (BOOL)isQuickTimeSevenInstalled
{
	#ifdef USE_QTKIT
	if ([KWCommonMethods OSVersion] >= 0x1040)
		return YES;
		
	#if MAC_OS_X_VERSION_MAX_ALLOWED < 1050
	long version;
	OSErr result;

	result = Gestalt(gestaltQuickTime, &version);
	return ((result == noErr) && (version >= 0x07000000));
	#endif
	#endif
	
	return NO;
}

///////////////////////////
// String format actions //
///////////////////////////

#pragma mark -
#pragma mark •• String format actions

+ (NSString *)formatTime:(CGFloat)time withFrames:(BOOL)frames
{
	NSInteger hours = (NSInteger)time / 60 / 60;
	NSInteger minutes = (NSInteger)time / 60 - (hours * 60);
	NSInteger seconds = (NSInteger)time - (minutes * 60.0) - (hours * 60 * 60);

	if (frames)
	{
		CGFloat frames = (time - (NSInteger)time) * 100.0;
		return [NSString stringWithFormat:@"%02.0f:%02.0f:%02.0f.%02.0f", (CGFloat)hours, (CGFloat)minutes, (CGFloat)seconds, (CGFloat)frames];
	}
	else
	{
		return [NSString stringWithFormat:@"%02.0f:%02.0f:%02.0f", (CGFloat)hours, (CGFloat)minutes, (CGFloat)seconds];
	}
}

+ (NSString *)makeSizeFromFloat:(CGFloat)size
{
	CGFloat blockSize;
	
	if ([KWCommonMethods OSVersion] >= 4192)
		blockSize = 1000;
	else
		blockSize = 1024;

	if (size < blockSize)
	{
		if (size > 0)
			return [NSString localizedStringWithFormat:NSLocalizedString(@"%.0f KB", nil), 4.0];
		else
			return [NSString localizedStringWithFormat:NSLocalizedString(@"%.0f KB", nil), size];
	}
		
	BOOL isKB = (size < blockSize * blockSize);
	BOOL isMB = (size < blockSize * blockSize * blockSize);
	BOOL isGB = (size < blockSize * blockSize * blockSize * blockSize);
	BOOL isTB = (size < blockSize * blockSize * blockSize * blockSize * blockSize);
	
	if (isKB)
		return [NSString localizedStringWithFormat:NSLocalizedString(@"%.0f KB", nil), size / blockSize];
	
	if (isMB)
	{
		NSString *sizeString = [NSString localizedStringWithFormat: @"%.1f", size  / blockSize / blockSize];
		
		if ([[sizeString substringFromIndex:[sizeString length] - 1] isEqualTo:@"0"])
			sizeString = [sizeString substringWithRange:NSMakeRange(0, [sizeString length] - 2)];
	
		return [NSString localizedStringWithFormat:NSLocalizedString(@"%@ MB", nil), sizeString];
	}
	
	if (isGB)
	{
		NSString *sizeString = [NSString localizedStringWithFormat: @"%.2f", size  / blockSize / blockSize / blockSize];
		
			if ([[sizeString substringFromIndex:[sizeString length] - 1] isEqualTo:@"0"])
			sizeString = [sizeString substringWithRange:NSMakeRange(0, [sizeString length] - 1)];
			
			if ([[sizeString substringFromIndex:[sizeString length] - 1] isEqualTo:@"0"])
			sizeString = [sizeString substringWithRange:NSMakeRange(0, [sizeString length] - 2)];
	
		return [NSString localizedStringWithFormat:NSLocalizedString(@"%@ GB", nil), sizeString];
	}
	
	if (isTB)
	{
		NSString *sizeString = [NSString localizedStringWithFormat: @"%.2f", size  / blockSize / blockSize / blockSize / blockSize];
		
			if ([[sizeString substringFromIndex:[sizeString length] - 1] isEqualTo:@"0"])
			sizeString = [sizeString substringWithRange:NSMakeRange(0, [sizeString length] - 1)];
			
			if ([[sizeString substringFromIndex:[sizeString length] - 1] isEqualTo:@"0"])
			sizeString = [sizeString substringWithRange:NSMakeRange(0, [sizeString length] - 2)];
	
		return [NSString localizedStringWithFormat:NSLocalizedString(@"%@ TB", nil), sizeString];
	}	

	return [NSString localizedStringWithFormat:NSLocalizedString(@"%.0f KB", nil), 0];
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
		NSString *pathExtension = @"";

		if (![[path pathExtension] isEqualTo:@""])
			pathExtension = [@"." stringByAppendingString:[path pathExtension]];

		NSInteger i = 0;
		while ([[NSFileManager defaultManager] fileExistsAtPath:[newPath stringByAppendingString:pathExtension]])
		{
			newPath = [path stringByDeletingPathExtension];
			
			i = i + 1;
			newPath = [NSString stringWithFormat:@"%@ %i", newPath, i];
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
	NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];

	if ([[standardDefaults objectForKey:@"KWTemporaryLocationPopup"] integerValue] == 2)
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
		NSString *temporaryFile =  [KWCommonMethods uniquePathNameFromPath:[[standardDefaults objectForKey:@"KWTemporaryLocation"] stringByAppendingPathComponent:file]];
		
		//Save the temporary files, when they should be deleted
		if ([[standardDefaults objectForKey:@"KWCleanTemporaryFolderAction"] integerValue] == 1 && [[standardDefaults objectForKey:@"KWTemporaryLocationPopup"] integerValue] != 2)
		{
			NSMutableArray *temporaryFiles = [NSMutableArray arrayWithArray:[standardDefaults objectForKey:@"KWTemporaryFiles"]];
			[temporaryFiles addObject:temporaryFile];
			[standardDefaults setObject:temporaryFiles forKey:@"KWTemporaryFiles"];
		}
		
		return temporaryFile;
	}
}

+ (BOOL)isBundleExtension:(NSString *)extension
{
	NSString *testFile = [@"/tmp/kiwiburntest" stringByAppendingPathExtension:extension];
	BOOL isPackage = NO;
	
	if ([KWCommonMethods createDirectoryAtPath:testFile errorString:nil])
	{
		isPackage = [[NSWorkspace sharedWorkspace] isFilePackageAtPath:testFile];
		[KWCommonMethods removeItemAtPath:testFile];
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
		BOOL genericFolder = (!(isFilePackage && [baseName isEqualTo:fsObjectFileName] | [[baseName stringByDeletingPathExtension] isEqualTo:fsObjectFileName] | [fsObjectFileName isEqualTo:displayName]));
		
		if ([fsObj isVirtual])
		{
			if (containsHFS && folderIcon)
			{
				img = folderIcon;
			}
			else if (!genericFolder)
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
			else if (!genericFolder)
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
		NSImage *dragImage = [[[NSImage alloc] initWithSize:[img size]] autorelease];
			
		[dragImage lockFocus];
		[img dissolveToPoint: NSZeroPoint fraction: .5];
		[dragImage unlockFocus];
			
		[dragImage setScalesWhenResized:YES];
			
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
			NSString *hiddenFile = [KWCommonMethods stringWithContentsOfFile:@"/.hidden"];
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
		NSInteger i;
		for (i = 0; i < [[folder children] count]; i ++)
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

+ (NSInteger)maxLabelLength:(DRFolder *)folder
{
	if ([folder explicitFilesystemMask] == DRFilesystemInclusionMaskHFSPlus)
		return 255;
	else if ([folder explicitFilesystemMask] == 1<<2 && [KWCommonMethods OSVersion] >= 0x1040)
		return 126;
	else if ([folder explicitFilesystemMask] == 1<<4)
		return 32;
	else if ([folder explicitFilesystemMask] == DRFilesystemInclusionMaskISO9660)
		return 30;
	else if (([folder explicitFilesystemMask] == DRFilesystemInclusionMaskJoliet) | [folder explicitFilesystemMask] == 1<<5)
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
	#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1050
	NSFileManager *defaultManager = [NSFileManager defaultManager];
	NSError *myError;
	BOOL succes = [defaultManager createDirectoryAtPath:path withIntermediateDirectories:NO attributes:nil error:&myError];
			
	if (!succes)
		*error = [myError localizedDescription];
	#else
	
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
	#endif
	
	return succes;
}

+ (BOOL)copyItemAtPath:(NSString *)inPath toPath:(NSString *)newPath errorString:(NSString **)error
{
	#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1050
	NSFileManager *defaultManager = [NSFileManager defaultManager];
	BOOL succes;
	NSError *myError;
	succes = [defaultManager copyItemAtPath:inPath toPath:newPath error:&myError];
			
	if (!succes)
		*error = [myError localizedDescription];
	
	return succes;
	#else

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
	#endif

	return succes;
}

+ (BOOL)createSymbolicLinkAtPath:(NSString *)path withDestinationPath:(NSString *)dest errorString:(NSString **)error;
{
	#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1050
	BOOL succes;
	NSFileManager *defaultManager = [NSFileManager defaultManager];
	
	NSError *tempError;
	
	succes = [defaultManager createSymbolicLinkAtPath:path withDestinationPath:dest error:&tempError];
	
	if (!succes)
		succes = [KWCommonMethods copyItemAtPath:path toPath:dest errorString:&*error];
	#else
	
	BOOL succes;
	NSFileManager *defaultManager = [NSFileManager defaultManager];
	
	NSError *tempError;
	
	if ([KWCommonMethods OSVersion] >= 0x1050)
		succes = [defaultManager createSymbolicLinkAtPath:path withDestinationPath:dest error:&tempError];
	else
		succes = [defaultManager createSymbolicLinkAtPath:path pathContent:dest];
		
	if (!succes)
		succes = [KWCommonMethods copyItemAtPath:path toPath:dest errorString:&*error];
	#endif
	
	return succes;
}

+ (BOOL)removeItemAtPath:(NSString *)path
{
	#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1050
	NSFileManager *defaultManager = [NSFileManager defaultManager];
	BOOL succes = YES;
	NSString *details;
	
	if ([defaultManager fileExistsAtPath:path])
	{
		NSError *myError;
		succes = [defaultManager removeItemAtPath:path error:&myError];
			
		if (!succes)
			details = [myError localizedDescription];
		
		if (!succes)
		{
			NSString *file = [defaultManager displayNameAtPath:path];
			[KWCommonMethods standardAlertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Failed to delete '%@'.", nil), file ] withInformationText:details withParentWindow:nil];
		}
	}
	#else
	
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
	#endif

	return succes;
}

+ (BOOL)writeString:(NSString *)string toFile:(NSString *)path errorString:(NSString **)error
{
	#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1050
	BOOL succes;
	NSError *myError;
	succes = [string writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&myError];
			
	if (!succes)
		*error = [myError localizedDescription];
	#else

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
		
	#endif

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
	#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1050
	NSData *tiffData = [image TIFFRepresentation];
	NSBitmapImageRep *bitmap = [NSBitmapImageRep imageRepWithData:tiffData];
	NSData *imageData = [bitmap representationUsingType:NSPNGFileType properties:nil];
	
	BOOL succes;
	NSString *details;
	
	NSError *writeError;
	succes = [imageData writeToFile:path options:NSAtomicWrite error:&writeError];
			
	if (!succes)
		*error = [writeError localizedDescription];
	#else
	
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
		
	#endif
	
	return succes;
}

+ (BOOL)createFileAtPath:(NSString *)path attributes:(NSDictionary *)attributes errorString:(NSString **)error
{
	NSFileManager *defaultManager = [NSFileManager defaultManager];
	NSString *file = [defaultManager displayNameAtPath:path];
	NSString *destination = [defaultManager displayNameAtPath:[path stringByDeletingLastPathComponent]];
	
	if ([defaultManager fileExistsAtPath:path])
	{
		*error = [NSString stringWithFormat:NSLocalizedString(@"Can't overwrite '%@' in '%@'", nil), file, destination];
		return NO;
	}
	
	BOOL succes = [defaultManager createFileAtPath:path contents:[NSData data] attributes:attributes];
		
		if (!succes)
			*error = [NSString stringWithFormat:NSLocalizedString(@"Can't create '%@' in '%@'", nil), file, destination];
	
	return succes;
}

////////////////////////
// Compatible actions //
////////////////////////

#pragma mark -
#pragma mark •• Compatible actions

+ (id)stringWithContentsOfFile:(NSString *)path
{
	#if MAC_OS_X_VERSION_MAX_ALLOWED < 1050
	if ([KWCommonMethods OSVersion] < 0x1040)
		return [NSString stringWithContentsOfFile:path];
	else
	#endif
		return [NSString stringWithContentsOfFile:path usedEncoding:nil error:nil];
}

+ (id)stringWithCString:(const char *)cString length:(NSUInteger)length
{
	#if MAC_OS_X_VERSION_MAX_ALLOWED < 1050
	if ([KWCommonMethods OSVersion] < 0x1040)
		return [NSString stringWithCString:cString length:length];
	else
	#endif
		return [NSString stringWithCString:cString encoding:NSASCIIStringEncoding];
	
}

///////////////////
// Other actions //
///////////////////

#pragma mark -
#pragma mark •• Other actions

+ (CGFloat)calculateRealFolderSize:(NSString *)path
{
	NSTask *du = [[NSTask alloc] init];
	NSPipe *pipe = [[NSPipe alloc] init];
	NSFileHandle *handle;
	NSString *string;
	[du setLaunchPath:@"/usr/bin/du"];
	[du setArguments:[NSArray arrayWithObjects:@"-s",path,nil]];
	[du setStandardOutput:pipe];
	[du setStandardError:[NSFileHandle fileHandleWithNullDevice]];
	handle = [pipe fileHandleForReading];
	[KWCommonMethods logCommandIfNeeded:du];
	[du launch];
	string = [[NSString alloc] initWithData:[handle readDataToEndOfFile] encoding:NSUTF8StringEncoding];
	
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWDebug"])
		NSLog(@"%@", string);

	[du waitUntilExit];
	
	[pipe release];
	pipe = nil;
	
	[du release];
	du = nil;

	CGFloat size = [[[string componentsSeparatedByString:@" "] objectAtIndex:0] cgfloatValue] / 4;
	
	[string release];
	string = nil;

	return size;
}

+ (CGFloat)calculateVirtualFolderSize:(DRFSObject *)obj
{
	NSFileManager *defaultManager = [NSFileManager defaultManager];
	CGFloat size = 0;
	
	NSArray *children = [(DRFolder *)obj children];
	NSInteger i;
	for (i = 0; i < [children count]; i ++)
	{
		NSAutoreleasePool *subPool = [[NSAutoreleasePool alloc] init];
		
		DRFSObject *child = [children objectAtIndex:i];
	
		if (![child isVirtual])
		{
			BOOL isDir;
			NSString *sourcePath = [child sourcePath];
			
			if ([defaultManager fileExistsAtPath:sourcePath isDirectory:&isDir] && isDir)
				size = size + [KWCommonMethods calculateRealFolderSize:sourcePath];
			else
				size = size + [[[defaultManager fileAttributesAtPath:sourcePath traverseLink:YES] objectForKey:NSFileSize] cgfloatValue] / 2048;
		}
		else
		{
			size = size + [self calculateVirtualFolderSize:child];
		}
	
		[subPool release];
		subPool = nil;
	}

	return size;
}

+ (NSArray*)allSelectedItemsInTableView:(NSTableView *)tableView fromArray:(NSArray *)array
{
	NSMutableArray *items = [NSMutableArray array];
	NSIndexSet *indexSet = [tableView selectedRowIndexes];
	
	NSUInteger current_index = [indexSet firstIndex];
    while (current_index != NSNotFound)
    {
		if ([array objectAtIndex:current_index]) 
			[items addObject:[array objectAtIndex:current_index]];
			
        current_index = [indexSet indexGreaterThanIndex:current_index];
    }

	return items;
}

+ (DRDevice *)getCurrentDevice
{
	NSArray *devices = [NSArray arrayWithArray:[DRDevice devices]];
	
	if ([devices count] > 0)
	{
		NSInteger i;
		for (i = 0; i < [devices count]; i ++)
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

	NSInteger i;
	for (i = 0; i < [lines count]; i ++)
	{
		NSArray *elements = [[lines objectAtIndex:i] componentsSeparatedByString:@":"];
	
		if ([elements count] > 1)
		{
			NSString *key = [[elements objectAtIndex:0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
			id value = [[elements objectAtIndex:1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
			
			if ([[value lowercaseString] isEqualTo:@"yes"])
				value = [NSNumber numberWithBool:YES];
			else if ([[value lowercaseString] isEqualTo:@"no"])
				value = [NSNumber numberWithBool:NO];
			
			[dictionary setObject:value forKey:key];
		}
	}
	
	return dictionary;
}

+ (NSInteger)getSizeFromMountedVolume:(NSString *)mountPoint
{
	NSTask *df = [[NSTask alloc] init];
	NSPipe *pipe = [[NSPipe alloc] init];
	NSFileHandle *handle;
	NSString *string;
	[df setLaunchPath:@"/bin/df"];
	[df setArguments:[NSArray arrayWithObject:mountPoint]];
	[df setStandardOutput:pipe];
	handle = [pipe fileHandleForReading];
	[KWCommonMethods logCommandIfNeeded:df];
	[df launch];

	string = [[NSString alloc] initWithData:[handle readDataToEndOfFile] encoding:NSUTF8StringEncoding];
	
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWDebug"] == YES)
		NSLog(@"%@", string);

	[df waitUntilExit];
	
	[pipe release];
	pipe = nil;
	
	[df release];
	df = nil;

	NSArray *objects = [[[string componentsSeparatedByString:@"\n"] objectAtIndex:1] componentsSeparatedByString:@" "];

	NSInteger size = 0;
	NSInteger i = 1;

	while (size == 0)
	{
		NSString *object = [objects objectAtIndex:i];
	
		if (![object isEqualTo:@""])
			size = [object integerValue];
		
		i = i + 1;
	}
	
	[string release];
	string = nil;

	return size;
}

+ (DRDevice *)savedDevice
{
	NSArray *devices = [DRDevice devices];
	
	NSInteger i;
	for (i = 0; i < [devices count]; i ++)
	{
		if ([[[[devices objectAtIndex:i] info] objectForKey:@"DRDeviceProductNameKey"] isEqualTo:[[[NSUserDefaults standardUserDefaults] dictionaryForKey:@"KWDefaultDeviceIdentifier"] objectForKey:@"Product"]])
			return [devices objectAtIndex:i];
	}
	
	return [devices objectAtIndex:0];
}

+ (CGFloat)defaultSizeForMedia:(NSString *)media
{
	NSArray *sizes;

	if ([media isEqualTo:@"KWDefaultCDMedia"])
		sizes = [NSArray arrayWithObjects:@"", @"81000", @"94500", @"", @"283500", @"333000", @"360000", @"405000", @"445500", nil];
	else
		sizes = [NSArray arrayWithObjects:@"", @"712891", @"1298828", @"", @"2295104", @"4171712", nil];

	return [[sizes objectAtIndex:[[[NSUserDefaults standardUserDefaults] objectForKey:media] integerValue]] cgfloatValue];
}

+ (NSImage *)getImageForName:(NSString *)name
{
	NSDictionary *customImageDictionary = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSImage imageNamed:@"General"], [NSImage imageNamed:@"Burn"], [[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(kGenericCDROMIcon)], [NSImage imageNamed:@"Audio CD"], [NSImage imageNamed:@"DVD"], [NSImage imageNamed:@"Advanced"], nil] forKeys:[NSArray arrayWithObjects:@"General", @"Burner",@"Data",@"Audio",@"Video",@"Advanced",nil]];

	return [customImageDictionary objectForKey:name];
}

+ (void)setupBurnerPopup:(NSPopUpButton *)popup
{
	[popup removeAllItems];
		
	NSInteger i;
	NSArray *devices = [DRDevice devices];
	for (i = 0; i < [devices count]; i ++)
	{
		[popup addItemWithTitle:[[devices objectAtIndex:i] displayName]];
	}
		
	if ([devices count] > 0)
	{
		NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];
	
		if ([standardDefaults dictionaryForKey:@"KWDefaultDeviceIdentifier"])
		{
			[popup selectItemWithTitle:[[KWCommonMethods getCurrentDevice] displayName]];
		}
		else
		{
			NSMutableDictionary *burnDict = [NSMutableDictionary dictionary];
			DRDevice *firstDevce = [devices objectAtIndex:0];
			NSDictionary *deviceInfo = [firstDevce info];
	
			[burnDict setObject:[deviceInfo objectForKey:@"DRDeviceProductNameKey"] forKey:@"Product"];
			[burnDict setObject:[deviceInfo objectForKey:@"DRDeviceVendorNameKey"] forKey:@"Vendor"];
			[burnDict setObject:@"" forKey:@"SerialNumber"];

			[standardDefaults setObject:burnDict forKey:@"KWDefaultDeviceIdentifier"];
		
			[[NSNotificationCenter defaultCenter] postNotificationName:@"KWMediaChanged" object:nil];
	
			[popup selectItemWithTitle:[firstDevce displayName]];
		}
	}
}

+ (NSString *)ffmpegPath
{
	NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];

	if ([standardDefaults boolForKey:@"KWUseCustomFFMPEG"] == YES && [[NSFileManager defaultManager] fileExistsAtPath:[standardDefaults objectForKey:@"KWCustomFFMPEG"]])
		return [standardDefaults objectForKey:@"KWCustomFFMPEG"];
	else
		return [[NSBundle mainBundle] pathForResource:@"ffmpeg" ofType:@""];
}

+ (NSArray *)diskImageTypes
{
	#if MAC_OS_X_VERSION_MAX_ALLOWED < 1050
	if ([KWCommonMethods OSVersion] < 0x1040)
		return [NSArray arrayWithObjects:@"isoInfo", @"sparseimage",@"toast",@"img", @"dmg", @"iso", @"cue",@"cdr",@"dvd", @"loxi", nil];
	else
	#endif
		return [NSArray arrayWithObjects:@"isoInfo", @"sparseimage",@"toast", @"img", @"dmg", @"iso", @"cue", @"toc",@"cdr", @"dvd", @"loxi", nil];
}

//Create an array with indexes of selected rows in a tableview
+ (NSArray *)selectedRowsAtRowIndexes:(NSIndexSet *)indexSet
{
	//Get the selected rows and save them
	NSMutableArray *selectedRows = [NSMutableArray array];
	
	NSUInteger current_index = [indexSet lastIndex];
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
	NSArray *extraExtensions = [NSArray arrayWithObjects:@"vob",@"wma",@"wmv",@"asf",@"asx",@"ogg",@"flv",@"rm",@"rmvb",@"flac",@"mts",nil];
		
	NSInteger i;
	for (i = 0; i < [extraExtensions count]; i ++)
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
		#ifdef USE_QTKIT
		[filetypes addObjectsFromArray:[QTMovie movieFileTypes:QTIncludeCommonTypes]];
		#endif
	}
	else
	{
		#if MAC_OS_X_VERSION_MAX_ALLOWED < 1050
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
		#else
		[filetypes addObjectsFromArray:[NSArray arrayWithObjects:@"mp2", @"'dvc!'", @"adts", @"mp3", @"ogg", @"m2p", @"scc", @"spx", @"'.WAV'", @"mp4", @"m1s", @"qhtm", @"'WAVE'", @"m2s", @"vro", @"mpa", @"m4p", @"qtz", @"gsm", @"'mxfd'", @"aiff", @"axv", @"m1v", @"wmv", @"gvi", @"'rtsp'", @"qt", @"'MooV'", @"aif", @"ogm", @"m2v", @"'Sd2f'", @"m3u", @"midi", @"'MPG3'", @"'sdp '", @"'GSM '", @"'qhtm'", @"'ac-3'", @"mpg", @"m4v", @"amc", @"'ASF_'", @"'MkvF'", @"mpeg", @"qtpf", @"'MP3 '", @"cel", @"'SwaT'", @"'ULAW'", @"'AVI_'", @"flac", @"3gp", @"'M1A '", @"'sdv '", @"dif", @"QT", @"dat", @"ogv", @"sdp", @"3gpp", @"mpm", @"'grip'", @"rtsp", @"mkv", @"'M2S '", @"'caff'", @"ogx", @"'cdda'", @"'GIFf'", @"MOV", @"'MPGv'", @"'MPG '", @"au", @"snd", @"fla", @"'M2V '", @"smf", @"qht", @"'AIFF'", @"'amc '", @"sdv", @"'PDF '", @"'fLaC'", @"wvx", @"'MPGa'", @"flc", @"MQV", @"'attr'", @"asf", @"mov", @"gif", @"dv", @"pls", @"smi", @"'MPG2'", @"'SMIL'", @"skin", @"mpv", @"amr", @"m15", @"cdda", @"'3gp2'", @"3gp2", @"axa", @"mqv", @"m1a", @"sml", @"wma", @"'AIFC'", @"wav", @"'FLI '", @"m2a", @"fli", @"vob", @"vp6", @"xfl", @"'OggS'", @"'MPGx'", @"wax", @"tta", @"ac3", @"avi", @"'mpg4'", @"m4a", @"'MPGV'", @"swa", @"'.SMI'", @"bwf", @"aac", @"anx", @"kar", @"m4b", @"'MPEG'", @"'MPGA'", @"vfw", @"dvd", @"'3gpp'", @"divx", @"m75", @"nuv", @"3g2", @"smil", @"'VfW '", @"'Mp3 '", @"'adts'", @"atr", @"oga", @"'embd'", @"'M1V '", @"mid", @"mka", @"'amr '", @"sd2", @"pdf", @"'Midi'", @"'CLCP'", @"asx", @"caf", @"flv", @"aifc", @"ulw", @"'PLAY'", @"'WMV '", nil]];
		#endif
	}

	//Remove midi and playlist files since they doesn't work
	if ([filetypes indexOfObject:@"'Midi'"] != NSNotFound)
		[filetypes removeObjectAtIndex:[filetypes indexOfObject:@"'Midi'"]];
	if ([filetypes indexOfObject:@"mid"] != NSNotFound)
		[filetypes removeObjectAtIndex:[filetypes indexOfObject:@"mid"]];
	if ([filetypes indexOfObject:@"midi"] != NSNotFound)
		[filetypes removeObjectAtIndex:[filetypes indexOfObject:@"midi"]];
	if ([filetypes indexOfObject:@"pls"] != NSNotFound)
		[filetypes removeObjectAtIndex:[filetypes indexOfObject:@"pls"]];
	if ([filetypes indexOfObject:@"m3u"] != NSNotFound)
		[filetypes removeObjectAtIndex:[filetypes indexOfObject:@"m3u"]];
	if ([filetypes indexOfObject:@"pdf"] != NSNotFound)
		[filetypes removeObjectAtIndex:[filetypes indexOfObject:@"pdf"]];
	
	return filetypes;
}

+ (NSInteger)createDVDFolderAtPath:(NSString *)path ofType:(NSInteger)type fromTableData:(id)tableData errorString:(NSString **)error
{
	#if MAC_OS_X_VERSION_MAX_ALLOWED < 1050
	if ([KWCommonMethods OSVersion] >= 0x1040)
	{
	#endif
		NSInteger succes;
		NSInteger x, z = 0;
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
			NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
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
			
			[pool release];
			pool = nil;
		}
		
		if (z == 0)
		{
			*error = @"Missing files in the VIDEO_TS Folder";
			succes = 1;
		}
		
		return succes;
	#if MAC_OS_X_VERSION_MAX_ALLOWED < 1050
	}
	else
	{
		NSDictionary *currentData = [tableData objectAtIndex:0];
		NSString *inPath = [currentData objectForKey:@"Path"];
		NSString *outPath = [path stringByAppendingPathComponent:[currentData objectForKey:@"Name"]];
	
		if ([KWCommonMethods createSymbolicLinkAtPath:outPath withDestinationPath:inPath errorString:&*error])
			return 0;
		else
			return 1;
	}
	#endif
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

		NSInteger i;
		for (i = 0; i < [showArgs count]; i ++)
		{
			commandString = [NSString stringWithFormat:@"%@ %@", commandString, [showArgs objectAtIndex:i]];
		}
	
		NSLog(@"%@", commandString);
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
	
	NSInteger result = [task terminationStatus];

	if (!error && result != 0)
		output = errorString;
	
	[pipe release];
	pipe = nil;
	
	[outputPipe release];
	outputPipe = nil;
	
	[task release];
	task = nil;

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

+ (NSMutableArray *)quicktimeChaptersFromFile:(NSString *)path
{
	NSMutableArray *chapters = [NSMutableArray array];
	
	#ifdef USE_QTKIT
	if ([KWCommonMethods isQuickTimeSevenInstalled] && [KWCommonMethods OSVersion] >= 0x1050)
	{
		if ([QTMovie canInitWithFile:path])
		{
			QTMovie *movie = [QTMovie movieWithFile:path error:nil];
			NSArray *qtChapters = [movie chapters];
			
			if (qtChapters)
			{
				NSInteger i;
				for (i = 0; i < [qtChapters count]; i ++)
				{
					NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
				
					NSDictionary *qtChapter = [qtChapters objectAtIndex:i];
					NSString *title = [qtChapter objectForKey:@"QTMovieChapterName"];
					QTTime qtTime = [[qtChapter objectForKey:@"QTMovieChapterStartTime"] QTTimeValue];
					CGFloat seconds = qtTime.timeValue / qtTime.timeScale;
					CGFloat frames = ((qtTime.timeValue / qtTime.timeScale) - seconds) * (qtTime.timeScale / 1000) / 2;
					CGFloat time = seconds + frames;
				
					NSMutableDictionary *rowData = [NSMutableDictionary dictionary];

					[rowData setObject:[KWCommonMethods formatTime:time withFrames:NO] forKey:@"Time"];
					[rowData setObject:title forKey:@"Title"];
					[rowData setObject:[NSNumber numberWithCGFloat:time] forKey:@"RealTime"];
					[rowData setObject:[[movie frameImageAtTime:qtTime] TIFFRepresentationUsingCompression:NSTIFFCompressionLZW factor:0] forKey:@"Image"];
					
					[chapters addObject:rowData];
					
					[pool release];
					pool = nil;
				}
			}
		}
	}
	#endif
	
	return chapters;
}

@end