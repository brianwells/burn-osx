/*
     File:       FSTreeNode.m
 
     Contains:   Tree node data structure carrying DRFSObject data (FSTreeNode, and FSNodeData).
 
     Version:    Technology: Mac OS X
                 Release:    Mac OS X
 
     Copyright:  (c) 2002 by Apple Computer, Inc., all rights reserved
 
     Bugs?:      For bug reports, consult the following page on
                 the World Wide Web:
 
                     http://developer.apple.com/bugreporter/
*/

/*
 IMPORTANT:  This Apple software is supplied to you by Apple Computer, Inc. ("Apple") in
 consideration of your agreement to the following terms, and your use, installation, 
 modification or redistribution of this Apple software constitutes acceptance of these 
 terms.  If you do not agree with these terms, please do not use, install, modify or 
 redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and subject to these 
 terms, Apple grants you a personal, non-exclusive license, under Apple‚Äôs copyrights in 
 this original Apple software (the "Apple Software"), to use, reproduce, modify and 
 redistribute the Apple Software, with or without modifications, in source and/or binary 
 forms; provided that if you redistribute the Apple Software in its entirety and without 
 modifications, you must retain this notice and the following text and disclaimers in all 
 such redistributions of the Apple Software.  Neither the name, trademarks, service marks 
 or logos of Apple Computer, Inc. may be used to endorse or promote products derived from 
 the Apple Software without specific prior written permission from Apple. Except as expressly
 stated in this notice, no other rights or licenses, express or implied, are granted by Apple
 herein, including but not limited to any patent rights that may be infringed by your 
 derivative works or by other works in which the Apple Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE MAKES NO WARRANTIES, 
 EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, 
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS 
 USE AND OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL OR CONSEQUENTIAL 
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS 
 OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, 
 REPRODUCTION, MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED AND 
 WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE), STRICT LIABILITY OR 
 OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#import "FSTreeNode.h"
#import "KWCommonMethods.h"
#import "KWDRFolder.h"

@implementation FSNodeData

- (id)initWithFSObject:(DRFSObject*)obj
{
	if (self = [super init])
	{
		fsObj = [obj retain];
	
		if (![fsObj isVirtual])
		{
			NSFileManager *defaultManager = [NSFileManager defaultManager];
			NSString *sourcePath = [fsObj sourcePath];
		
			if (![KWCommonMethods isDRFSObjectVisible:fsObj])
			{
				NSNumber *yesNumber = [NSNumber numberWithBool:YES];
			
				[fsObj setProperty:yesNumber forKey:DRInvisible inFilesystem:DRHFSPlus];
				[fsObj setProperty:yesNumber forKey:DRInvisible inFilesystem:DRISO9660];
				[fsObj setProperty:yesNumber forKey:DRInvisible inFilesystem:DRJoliet];
				#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1050
				[fsObj setProperty:yesNumber forKey:DRInvisible inFilesystem:DRUDF];
				#else
				if ([KWCommonMethods OSVersion] >= 0x1040)
					[fsObj setProperty:yesNumber forKey:DRInvisible inFilesystem:@"DRUDF"];
				#endif
			}
			
			NSDictionary *atributes = [defaultManager fileAttributesAtPath:sourcePath traverseLink:YES];
			unsigned long permissions = [[atributes objectForKey:NSFilePosixPermissions] unsignedLongValue];
			NSNumber *permissionNumber = [NSNumber numberWithUnsignedLong:permissions];
			
			[fsObj setProperty:permissionNumber forKey:DRPosixFileMode inFilesystem:DRHFSPlus];
			[fsObj setProperty:permissionNumber forKey:DRPosixFileMode inFilesystem:DRISO9660];
			[fsObj setProperty:permissionNumber forKey:DRPosixFileMode inFilesystem:DRJoliet];
			#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1050
			[fsObj setProperty:permissionNumber forKey:DRPosixFileMode inFilesystem:DRUDF];
			#else
			if ([KWCommonMethods OSVersion] >= 0x1040)
				[fsObj setProperty:permissionNumber forKey:DRPosixFileMode inFilesystem:@"DRUDF"];
			#endif
			
			[fsObj setProperty:[NSNumber numberWithUnsignedShort:[KWCommonMethods getFinderFlagsAtPath:sourcePath]] forKey:DRMacFinderFlags inFilesystem:DRHFSPlus];
		
			if ([atributes objectForKey:NSFileHFSCreatorCode])
			{
				OSType type = [[atributes objectForKey:NSFileHFSCreatorCode] unsignedLongValue];
				NSData *data = [NSData dataWithBytes:&type length:4];
				[fsObj setProperty:data forKey:DRMacFileCreator inFilesystem:DRHFSPlus];
				type = [[atributes objectForKey:NSFileHFSTypeCode] unsignedLongValue];
				data = [NSData dataWithBytes:&type length:4];
				[fsObj setProperty:data forKey:DRMacFileType inFilesystem:DRHFSPlus];
			}
		
			BOOL isDir;
			[defaultManager fileExistsAtPath:sourcePath isDirectory:&isDir];
			if (isDir)
			{
				[(KWDRFolder *)fsObj setIsFilePackage:[[NSWorkspace sharedWorkspace] isFilePackageAtPath:sourcePath]];
				
				NSString *baseName = [fsObj baseName];
				if ([[baseName pathExtension] isEqualTo:@"app"] | [KWCommonMethods isDRFolderIsLocalized:(DRFolder *)fsObj])
				{
					[(KWDRFolder *)fsObj setDisplayName:[defaultManager displayNameAtPath:sourcePath]];
					[(KWDRFolder *)fsObj setOriginalName:baseName];
				}
			}
		}
	}	

	return self;
}

- (void)dealloc
{
	[[fsObj parent] removeChild:fsObj];
	[fsObj release];
	fsObj = nil;
	
	[super dealloc];
}

+ (FSNodeData*) nodeDataWithPath:(NSString*)path;
{
	FSNodeData*	nodeData = nil;
	BOOL		isDir;
	
	if ([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir])
	{
		if (isDir)
			nodeData = [[FSFolderNodeData alloc] initWithPath:path];
		else
			nodeData = [[FSFileNodeData alloc] initWithPath:path];
	}
	
	return [nodeData autorelease];
}

+ (FSNodeData*) nodeDataWithName:(NSString*)name
{
	return [[[FSFolderNodeData alloc] initWithName:name] autorelease];
}

+ (FSNodeData*) nodeDataWithFSObject:(DRFSObject*)obj
{
	if ([obj isKindOfClass:[DRFile class]])
		return [[[FSFileNodeData alloc] initWithFSObject:obj] autorelease];
	else
		return [[[FSFolderNodeData alloc] initWithFSObject:obj] autorelease];
}

- (DRFSObject*) fsObject
{
	return fsObj;
}

- (void)setName:(NSString *)str 
{
	KWDRFolder *parent = (KWDRFolder *)[fsObj parent];
	NSString *newName = str;
	NSString *baseName = [fsObj baseName];

	if ([baseName isEqualTo:@"Icon\r"] && parent)
		[parent setFolderIcon:nil];
	
	if ([[baseName pathExtension] isEqualTo:@"app"] && ![fsObj isKindOfClass:[DRFile class]] && ![[str pathExtension] isEqualTo:@"app"])
		newName = [str stringByAppendingPathExtension:@"app"];
	
	if (![fsObj isKindOfClass:[DRFile class]] && [KWCommonMethods isBundleExtension:[newName pathExtension]])
		[(KWDRFolder *)fsObj setIsFilePackage:YES];
	else if (![fsObj isKindOfClass:[DRFile class]])
		[(KWDRFolder *)fsObj setIsFilePackage:NO];
	
	[fsObj setBaseName:newName];
}

- (NSString*)name 
{
	return [KWCommonMethods fsObjectFileName:fsObj];
}

- (NSString*) kind
{
	return @"Unknown";
}

- (NSImage*)icon 
{
    return nil;
}

- (BOOL)isExpandable 
{
    return NO;
}

- (NSString*)description 
{ 
    return [self name]; 
}

- (NSComparisonResult)compare:(TreeNodeData*)other 
{
	return [[self name] caseInsensitiveCompare:[(FSNodeData *)other name]];
}

@end

@implementation FSFileNodeData

- (id) initWithPath:(NSString*)path
{
	return [super initWithFSObject:[DRFile fileWithPath:path]];
}

- (NSImage*)icon
{
	return [KWCommonMethods getIcon:fsObj];
}

- (NSString *)kind
{
	return [KWCommonMethods makeSizeFromFloat:[[[[NSFileManager defaultManager] fileAttributesAtPath:[fsObj sourcePath] traverseLink:YES] objectForKey:NSFileSize] cgfloatValue]];
}

@end

@implementation FSFolderNodeData

- (id) initWithPath:(NSString*)path
{
	return [super initWithFSObject:[[[KWDRFolder alloc] initWithPath:path] autorelease]];
}

- (id) initWithName:(NSString*)name
{
	return [super initWithFSObject:[[[KWDRFolder alloc] initWithName:name] autorelease]];
}

- (NSImage*)icon
{
	return [KWCommonMethods getIcon:fsObj];
}

- (NSString*) kind
{
	if (([self isExpandable] && [[NSUserDefaults standardUserDefaults] boolForKey:@"KWCalculateFolderSizes"] == YES) | (![self isExpandable] && [[NSUserDefaults standardUserDefaults] boolForKey:@"KWCalculateFilePackageSizes"] == YES))
	{
		if ([(KWDRFolder *)fsObj folderSize])
			return [(KWDRFolder *)fsObj folderSize];
		else
			return @"--";
	}
	else
	{
		return @"--";
	}
}

- (BOOL)isExpandable 
{
	if (![(KWDRFolder *)fsObj isFilePackage] | [[NSUserDefaults standardUserDefaults] boolForKey:@"KWShowFilePackagesAsFolder"] == YES | ([[[self name] pathExtension] isEqualTo:@""] && ![[[fsObj baseName] stringByDeletingPathExtension] isEqualTo:[self name]] && ![[self name] isEqualTo:[(KWDRFolder *)fsObj displayName]]))
		return YES;

	return NO;
}

@end

@implementation FSTreeNode

- (void)addChild:(TreeNode*)child
{
	KWDRFolder*	selfObj = (KWDRFolder*)[(FSNodeData*)nodeData fsObject];
	DRFSObject*	childObj = [(FSNodeData*)[child nodeData] fsObject];
	BOOL emptyFolder = NO;
		
		if ([childObj isVirtual])
		{
			NSString *folderSize = [(KWDRFolder *)childObj folderSize];
			
			if (folderSize && [folderSize isEqualTo:[NSString localizedStringWithFormat:NSLocalizedString(@"%.0f KB", nil), 0]])
				emptyFolder = YES;
		}
	
	if (!emptyFolder)
		[selfObj setFolderSize:nil];

	if (![childObj isVirtual] && [[[[NSFileManager defaultManager] fileAttributesAtPath:[childObj sourcePath] traverseLink:YES] objectForKey:NSFileSize] unsignedLongLongValue] / 1024 / 1024 > 2048 && [[(FSNodeData*)nodeData fsObject] effectiveFilesystemMask] & DRFilesystemInclusionMaskJoliet | [[(FSNodeData*)nodeData fsObject] effectiveFilesystemMask] & DRFilesystemInclusionMaskISO9660)
	{
		if ([[NSApp mainWindow] attachedSheet] == nil)
		{
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle:NSLocalizedString(@"OK",nil)];
		[alert setMessageText:NSLocalizedString(@"Some files are to large",nil)];
		[alert setInformativeText:NSLocalizedString(@"The PC (Joliet) or ISO9660 filesystem can only handle files smaller than 2GB",nil)];
		[alert setAlertStyle:NSWarningAlertStyle];
		[alert beginSheetModalForWindow:[NSApp mainWindow] modalDelegate:self didEndSelector:nil contextInfo:nil];
		}
	}
	else
	{
		NSArray *children = [selfObj children];
		NSMutableArray *baseNames = [NSMutableArray array];
		NSString *newName = [NSString stringWithString:[childObj baseName]];
		
		NSInteger i = 0;
		for (i = 0; i < [children count]; i ++)
		{
			[baseNames addObject:[[children objectAtIndex:i] baseName]];
		}
			
		NSInteger x = 1;
		while ([baseNames containsObject:newName])
		{
			newName = [NSString stringWithFormat:@"%@ %ld", newName, (long)x];
			x = x + 1;
		}
		
		[childObj setBaseName:newName];
	
			if (!emptyFolder)
			{
				TreeNode *node = self;
				
				while ([node nodeParent])
				{
					[(KWDRFolder *)[(FSNodeData*)[[node nodeParent] nodeData] fsObject] setFolderSize:nil];
					node = [node nodeParent];
				}
			}
		
		[self children];
		
		[selfObj addChild:childObj];	
		[super addChild:child];
	}
}

- (void)removeChild:(TreeNode*)child
{
	KWDRFolder*	selfObj = (KWDRFolder*)[(FSNodeData*)nodeData fsObject];
	DRFSObject* childObj = [(FSNodeData*)[child nodeData] fsObject];
	
	if ([[childObj baseName] isEqualTo:@"Icon\r"])
		[selfObj setFolderIcon:nil];
		
	[selfObj setFolderSize:nil];
		
		TreeNode *node = self;
		while ([node nodeParent])
		{
			[(KWDRFolder *)[(FSNodeData*)[[node nodeParent] nodeData] fsObject] setFolderSize:nil];
			node = [node nodeParent];
		}

	[selfObj removeChild:childObj];
	[super removeChild:child];
}

- (NSArray *)children
{
	KWDRFolder*	selfObj = (KWDRFolder*)[(FSNodeData*)nodeData fsObject];
	if ([selfObj isVirtual] == NO)
	{
		NSString *currentName = [selfObj baseName];
		NSImage *folderIcon = nil;
		if ([KWCommonMethods hasCustomIcon:selfObj])
			folderIcon = [[NSWorkspace sharedWorkspace] iconForFile:[selfObj sourcePath]];
		[selfObj makeVirtual];
		[selfObj setBaseName:currentName];
		if (folderIcon)
			[selfObj setFolderIcon:folderIcon];
		
		NSFileManager *defaultManager = [NSFileManager defaultManager];
		NSArray *objects = [selfObj children];

		NSInteger i;
		for (i = 0; i < [objects count]; i ++)
		{
			NSAutoreleasePool *subPool = [[NSAutoreleasePool alloc] init];
			
			id object = [objects objectAtIndex:i];
			NSString *sourcePath = [object sourcePath];
		
			BOOL isDir;
			if ([defaultManager fileExistsAtPath:sourcePath isDirectory:&isDir] && isDir)
			{
				KWDRFolder *folder = [[KWDRFolder alloc] initWithPath:sourcePath];
				[selfObj addChild:folder];
				FSTreeNode*	child = [FSTreeNode treeNodeWithData:[FSNodeData nodeDataWithFSObject:folder]];
				[super addChild:child];
				[selfObj removeChild:object];
			}
			else
			{
				FSTreeNode*	child = [FSTreeNode treeNodeWithData:[FSNodeData nodeDataWithFSObject:(DRFSObject *)object]];
				[super addChild:child];
			}
			
			[subPool release];
			subPool = nil;
		}
	}

	return [super children];
}

- (NSInteger) numberOfChildren
{
	KWDRFolder*	selfObj = (KWDRFolder*)[(FSNodeData*)nodeData fsObject];

	if ([selfObj isVirtual])
	{
		return [super numberOfChildren];
	}
	else
	{
		const char *	fsRep = [[[(FSNodeData*)nodeData fsObject] sourcePath] fileSystemRepresentation];
		CFURLRef		tempURL = CFURLCreateFromFileSystemRepresentation(kCFAllocatorDefault, (const UInt8 *)fsRep, strlen(fsRep), true);
		FSRef			theRef;
		FSCatalogInfo	catInfo;

		CFURLGetFSRef(tempURL, &theRef);
		CFRelease(tempURL);
		
		if (FSGetCatalogInfo(&theRef, kFSCatInfoValence, &catInfo, NULL, NULL, NULL) == noErr)
			return catInfo.valence;
		else
			return 0;
	}
}

- (id)initWithCoder:(NSCoder *)pCoder;
{
	if ((self = [super init]) == nil)
		return self;
	
	[pCoder decodeValueOfObjCType:@encode(NSInteger) at:&myNumber]; 
	
	if (myNumber)
		myNumber++;
	else
		myNumber = 1;
	
	return self;
	
}

- (void)encodeWithCoder:(NSCoder *)pCoder;
{
	[pCoder encodeValueOfObjCType:@encode(NSInteger) at:&myNumber];
}

- (NSInteger) myNumber
{
	return myNumber;
}

@end