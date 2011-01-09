/*
     File:       HFSPlusController.m
 
     Contains:   FSPropertyController subclass to handle the HFS+ filesystem.
 
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

#import "HFSPlusController.h"
#import "KWCommonMethods.h"

#import <Carbon/Carbon.h>

@implementation HFSPlusController

- (id) init
{
	if (self = [super init])
	{
		// Like in other places, we're doing an object tag -> property mapping to easily
		// convert between the two worlds.
		propertyMappings = [[NSArray alloc] initWithObjects:	DRCreationDate,						//0
																DRContentModificationDate,			//1
																DRAttributeModificationDate,		//2
																DRAccessDate,						//3
																DRBackupDate,						//4
																DRPosixFileMode,					//5
																DRPosixUID,							//6
																DRPosixGID,							//7
																DRHFSPlusTextEncodingHint,			//8
																DRHFSPlusCatalogNodeID,				//9
																DRMacFileType,						//10
																DRMacFileCreator,					//11
																DRMacWindowBounds,					//12
																DRMacIconLocation,					//13
																DRMacScrollPosition,				//14
																DRMacWindowView,					//15
																DRMacFinderFlags,					//16
																DRMacExtendedFinderFlags,			//17
																nil];
	}

	return self;
}

- (NSString*) filesystem
{
	// We're the controller for the HFS+ filesystem, so return the correct value.
	return DRHFSPlus;
}

- (DRFilesystemInclusionMask) mask
{
	// We're the controller for the HFS+ filesystem, so return the correct value.
	return DRFilesystemInclusionMaskHFSPlus;
}

- (void)updateNames
{
	DRFSObject *firstObject = [inspectedItems objectAtIndex:0];
	
	[specificName setStringValue:[firstObject specificNameForFilesystem:[self filesystem]]];

	NSString *tempMangledName = [firstObject mangledNameForFilesystem:[self filesystem]];
	
	if ([self extensionHiddenOfFSObject:firstObject])
		[mangledName setStringValue:[tempMangledName stringByDeletingPathExtension]];
	else
		[mangledName setStringValue:tempMangledName];
}

- (BOOL)extensionHiddenOfFSObject:(DRFSObject *)object
{
	BOOL hideExtension = NO;
	NSNumber *fFlags = [object propertyForKey:DRMacFinderFlags inFilesystem:[self filesystem] mergeWithOtherFilesystems:NO];
	unsigned short fndrFlags = [fFlags unsignedShortValue];

	if ([[[object baseName] pathExtension] isEqualTo:@"app"] && ![object isKindOfClass:[DRFile class]])
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

	return hideExtension;
}

- (BOOL)isFolder:(DRFSObject *)object
{
	if ([object isVirtual])
	{
		return YES;
	}
	else
	{
		BOOL isDir;
		[[NSFileManager defaultManager] fileExistsAtPath:[object sourcePath] isDirectory:&isDir];
		return isDir;
	}
}

- (void)updateSpecific
{
	Point*			iconPosition;
	Rect*			windowBounds;
	Point*			scrollPosition;
	NSData*			data;
	unsigned short	fndrFlags = 0;
	NSEnumerator*	iter;
	NSCell*			cell;
	NSInteger x;
	
	BOOL isDir = [self isFolder:[inspectedItems objectAtIndex:0]];
	BOOL multiEqual = YES;
	for (x=0;x<[inspectedItems count];x++)
	{
		BOOL isDirToo = [self isFolder:[inspectedItems objectAtIndex:x]];
		
		if (!isDirToo == isDir)
		multiEqual = NO;
	}
	
	BOOL enableState = (multiEqual | !isDir);
	
	[creator setEnabled:enableState];
	[type setEnabled:enableState];
	[tecHint setEnabled:enableState];
	[boundsTop setEnabled:!enableState];
	[boundsLeft setEnabled:!enableState];
	[boundsBottom setEnabled:!enableState];
	[boundsRight setEnabled:!enableState];
	[scrollPosX setEnabled:!enableState];
	[scrollPosY setEnabled:!enableState];
	[viewType setEnabled:!enableState];
	
	NSInteger state = NSOnState;
	for (x=0;x<[inspectedItems count];x++)
	{
		if (![self extensionHiddenOfFSObject:[inspectedItems objectAtIndex:x]])
		state = NSOffState;
	}
	
	[setHiddenExtension setState:state];
	
		if ([inspectedItems count] == 1)
		{
			if ([[[[inspectedItems objectAtIndex:0] baseName] pathExtension] isEqualTo:@""] | ([[[[inspectedItems objectAtIndex:0] baseName] pathExtension] isEqualTo:@"app"] && ![[inspectedItems objectAtIndex:0] isKindOfClass:[DRFile class]]) | (![KWCommonMethods isBundleExtension:[[[inspectedItems objectAtIndex:0] baseName] pathExtension]] && ![[inspectedItems objectAtIndex:0] isKindOfClass:[DRFile class]]) | ![specificName isEnabled])
				[setHiddenExtension setEnabled:NO];
			else
				[setHiddenExtension setEnabled:YES];
		}
		
		[tecHint setObjectValue:[self getPropertyForKey:DRHFSPlusTextEncodingHint]];
		[nodeID setObjectValue:[self getPropertyForKey:DRHFSPlusCatalogNodeID]];

		data = [self getPropertyForKey:DRMacFileCreator];
		if (data)
			#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_4
			[creator setStringValue:[NSString stringWithCString:[data bytes] encoding:NSASCIIStringEncoding]];
			#else
			[creator setStringValue:[NSString stringWithCString:[data bytes] length:4]];
			#endif
		else
			[creator setStringValue:@""];
		
		data = [self getPropertyForKey:DRMacFileType];
		if (data)
			#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_4
			[type setStringValue:[NSString stringWithCString:[data bytes] encoding:NSASCIIStringEncoding]];
			#else
			[type setStringValue:[NSString stringWithCString:[data bytes] length:4]];
			#endif
		else
			[type setStringValue:@""];
	
		data = [self getPropertyForKey:DRMacWindowBounds];
		if (data)
		{
			windowBounds = (Rect*)[data bytes];
	
			[boundsTop setIntValue:windowBounds->top];
			[boundsLeft setIntValue:windowBounds->left];
			[boundsBottom setIntValue:windowBounds->bottom];
			[boundsRight setIntValue:windowBounds->right];
		}
		else
		{
			[[NSArray arrayWithObjects:boundsTop, boundsLeft, boundsBottom, boundsRight,nil] makeObjectsPerformSelector:@selector(setStringValue:) withObject:@""];
		}
	
		data = [self getPropertyForKey:DRMacIconLocation];
		if (data)
		{
			iconPosition = (Point*)[data bytes];
		
			[iconPosX setIntValue:iconPosition->h];
			[iconPosY setIntValue:iconPosition->v];
		}
		else
		{
			[iconPosX setStringValue:@""];
			[iconPosY setStringValue:@""];
		}
	
		data = [self getPropertyForKey:DRMacScrollPosition];
		if (data)
		{
			scrollPosition = (Point*)[data bytes];
		
			[scrollPosX setIntValue:scrollPosition->h];
			[scrollPosY setIntValue:scrollPosition->v];
		}
		else
		{
			[scrollPosX setStringValue:@""];
			[scrollPosY setStringValue:@""];
		}
	
		[viewType setObjectValue:[self getPropertyForKey:DRMacWindowView]];
	

		fndrFlags = [[self getPropertyForKey:DRMacFinderFlags] unsignedShortValue];
		iter = [[finderFlags cells] objectEnumerator];
		while ((cell = [iter nextObject]) != nil)
		{
			[cell setState:([cell tag] & fndrFlags)];
		}


		fndrFlags = [[self getPropertyForKey:DRMacExtendedFinderFlags] unsignedShortValue];
		iter = [[extFinderFlags cells] objectEnumerator];
		while ((cell = [iter nextObject]) != nil)
		{
			[cell setState:([cell tag] & fndrFlags) == [cell tag]];
		}
	
		if ([[self getPropertyForKey:DRInvisible] boolValue])
		[[finderFlags cellWithTag:16384] setState:NSOnState];
		else
		[[finderFlags cellWithTag:16384] setState:NSOffState];
}

- (IBAction) setIconPositionProperty:(id)sender
{
	NSData*	positionData;
	Point	iconPosition;
	
	iconPosition.h = [iconPosX intValue];
	iconPosition.v = [iconPosY intValue];
	
	positionData = [NSData dataWithBytes:&iconPosition length:sizeof(iconPosition)];
	
	NSInteger x;
	for (x=0;x<[inspectedItems count];x++)
	{
		[[inspectedItems objectAtIndex:x] setProperty:positionData forKey:DRMacIconLocation inFilesystem:[self filesystem]];
	}
}

- (IBAction) setFlagsProperty:(id)sender
{
	unsigned short	fndrFlags = 0;
	NSEnumerator*	iter = [[sender cells] objectEnumerator];
	NSCell*			cell;
	BOOL invisible = NO;

	while ((cell = [iter nextObject]) != nil)
	{
		if ([cell state])
			fndrFlags |= [cell tag];
		
		if ([cell tag] == 16384)
			invisible = ([cell state] == NSOnState);
	}
	
	NSInteger x;
	for (x=0;x<[inspectedItems count];x++)
	{
		id currentItem = [inspectedItems objectAtIndex:x];
		
		[currentItem setProperty:[NSNumber numberWithBool:invisible] forKey:DRInvisible inFilesystem:[self filesystem]];
		[currentItem setProperty:[NSNumber numberWithUnsignedShort:fndrFlags] forKey:[propertyMappings objectAtIndex:[sender tag]] inFilesystem:[self filesystem]];
	}
	
	[self setHiddenExtension:self];

	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWReloadRequested" object:nil];
}

- (IBAction) setFolderBoundsProperty:(id)sender
{
	if ([boundsTop objectValue] && [boundsLeft objectValue] && [boundsBottom objectValue] && [boundsRight objectValue])
	{
		NSData*	boundsData;
		Rect	windowBounds;
	
		windowBounds.top = [boundsTop intValue];
		windowBounds.left = [boundsLeft intValue];
		windowBounds.bottom = [boundsBottom intValue];
		windowBounds.right = [boundsRight intValue];
	
		boundsData = [NSData dataWithBytes:&windowBounds length:sizeof(windowBounds)];
	
		NSInteger x;
		for (x=0;x<[inspectedItems count];x++)
		{
			[[inspectedItems objectAtIndex:x] setProperty:boundsData forKey:DRMacWindowBounds inFilesystem:[self filesystem]];
		}
	}

}

- (IBAction) setFolderScrollPositionProperty:(id)sender
{
	if ([scrollPosX objectValue] && [scrollPosY objectValue])
	{
		NSData*	positionData;
		Point	scrollPosition;
	
		scrollPosition.h = [scrollPosX intValue];
		scrollPosition.v = [scrollPosY intValue];
	
		positionData = [NSData dataWithBytes:&scrollPosition length:sizeof(scrollPosition)];
	
		NSInteger x;
		for (x=0;x<[inspectedItems count];x++)
		{
			[[inspectedItems objectAtIndex:x] setProperty:positionData forKey:DRMacScrollPosition inFilesystem:[self filesystem]];
		}
	}
}

- (IBAction)setTypeCreatorProperty:(id)sender
{
	NSData*	data = [[sender stringValue] dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingMacRoman) allowLossyConversion:YES];
										  
	data = [NSData dataWithBytes:[data bytes] length:4];
	
	NSInteger x;
	for (x=0;x<[inspectedItems count];x++)
	{
		[[inspectedItems objectAtIndex:x] setProperty:data forKey:[propertyMappings objectAtIndex:[sender tag]] inFilesystem:[self filesystem]];
	}
}

- (IBAction)setHiddenExtension:(id)sender
{
	NSInteger x;
	for (x=0;x<[inspectedItems count];x++)
	{
		DRFSObject *currentItem = [inspectedItems objectAtIndex:x];
	
		NSNumber *fFlags = [currentItem propertyForKey:DRMacFinderFlags inFilesystem:[self filesystem] mergeWithOtherFilesystems:NO];
		unsigned short flags = [fFlags unsignedShortValue];

		if ([setHiddenExtension state] == NSOnState)
		{
			if ([inspectedItems count] == 1)
				[mangledName setStringValue:[[currentItem mangledNameForFilesystem:[self filesystem]] stringByDeletingPathExtension]];
		
			flags = (flags | 0x0010);
		}
		else
		{
			if ([inspectedItems count] == 1)
				if ([KWCommonMethods isDRFolderIsLocalized:(DRFolder *)currentItem])
					[mangledName setStringValue:[[currentItem mangledNameForFilesystem:[self filesystem]] stringByDeletingPathExtension]];
				else
					[mangledName setStringValue:[currentItem mangledNameForFilesystem:[self filesystem]]];
		
			flags -= 0x0010;
		}

		[currentItem setProperty:[NSNumber numberWithUnsignedShort:flags] forKey:DRMacFinderFlags inFilesystem:[self filesystem]];
	}

	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWLeaveTab" object:nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWReloadRequested" object:nil];
}

@end