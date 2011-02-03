/*
     File:       FSPropertiesController.m
 
     Contains:   Base class providing most of the functionality needed to handle
                 setting the various properties associated with the files/folders
                 in a burn hierarchy.
 
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

#import "FSPropertiesController.h"
#import "KWCommonMethods.h"

@interface NSView (EnablingHelper)

- (void)setEnabled:(BOOL)enabledFlag deep:(BOOL)goDeep;

@end

@implementation NSView (EnablingHelper)

- (void)setEnabled:(BOOL)enabledFlag deep:(BOOL)goDeep
{
	// Dis/Enable ourselfs first.
	if ([self respondsToSelector:@selector(setEnabled:)])
		[(id)self setEnabled:enabledFlag];
	
	if (goDeep)
	{
		NSEnumerator*	iter = [[self subviews] objectEnumerator];
		NSControl*		subView;

		// Iiterate over all of the subviews. If they respond to the 
		// -setEnabled: method, call it to enable/disable the item.
		// Then recurse to handle that object's subviews.
		while ((subView = [iter nextObject]) != NULL)
		{
			[subView setEnabled:enabledFlag deep:goDeep];
		}
	}
}

@end

@implementation FSPropertiesController

- (NSString*) filesystem
{
	return @"";
}

- (DRFilesystemInclusionMask) mask
{
	return 0xFFFFFFFF;
}

- (void)inspect:(NSArray *)items
{
	inspectedItems = items;

	[included setEnabled:[self checkForFileSystemMasksInParentsOfObjects:inspectedItems]];
	[included setState:[self checkForFileSystemMasksInObjects:inspectedItems]];
	[contentView setEnabled:([included state] && [included isEnabled]) deep:YES];

	if ([inspectedItems count] == 1)
		[self updateNames];
	else
		[self clearForMultipleSelection];

	[self updateDates];
	[self updatePOSIX];
	[self updateSpecific];
}

- (BOOL)checkForFileSystemMasksInObjects:(NSArray *)objects
{
	NSInteger x;
	for (x = 0; x < [objects count]; x ++)
	{
		if ([[objects objectAtIndex:x] explicitFilesystemMask] & [self mask])
			return YES;
	}
	
	return NO;
}

- (BOOL)checkForFileSystemMasksInParentsOfObjects:(NSArray *)objects
{
	NSInteger x;
	for (x = 0; x < [objects count]; x ++)
	{
		if ([[(DRFSObject *)[objects objectAtIndex:x] parent] effectiveFilesystemMask] & [self mask])
			return YES;
	}
	
	return NO;
}

- (id)getPropertyForKey:(NSString *)key
{
	id object = [[inspectedItems objectAtIndex:0] propertyForKey:key inFilesystem:[self filesystem] mergeWithOtherFilesystems:NO];

	NSInteger x;
	for ( x = 0; x < [inspectedItems count]; x ++)
	{
		if (![object isEqualTo:[[inspectedItems objectAtIndex:x] propertyForKey:key inFilesystem:[self filesystem] mergeWithOtherFilesystems:NO]])
			return nil;
	}
	
	return object;
}

- (IBAction)setIncludedBit:(id)sender
{
	NSInteger x;
	for (x = 0; x < [inspectedItems count]; x ++)
	{
		id currentItem = [inspectedItems objectAtIndex:x];
	
		DRFilesystemInclusionMask	mask = [currentItem explicitFilesystemMask];
	
	if ([sender state])
		mask |= [self mask];
	else
		mask &= ~[self mask];
	
		[currentItem setExplicitFilesystemMask:mask];
	}
	
	[contentView setEnabled:([sender state]) deep:YES];

	NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
	[defaultCenter postNotificationName:@"KWLeaveTab" object:nil];
	[defaultCenter postNotificationName:@"KWReloadRequested" object:nil];
}

- (void)clearForMultipleSelection
{
	[specificName setStringValue:@""];
	[mangledName setStringValue:@""];
	[specificName setEnabled:NO];
}

- (void)updateNames
{	
	DRFSObject *firstItem = [inspectedItems objectAtIndex:0];
	
	[baseName setStringValue:[firstItem baseName]];
	
	NSString *fileSystem = [self filesystem];
	[specificName setStringValue:[firstItem specificNameForFilesystem:fileSystem]];
	[mangledName setStringValue:[firstItem mangledNameForFilesystem:fileSystem]];
}

- (void)updateDates
{
	// Each subclass sets up an array of property keys. Tags of the object in the view 
	// hierarchy are set to the index of the tag that corresponds to the particular item
	// in the property array. So we go and look up the correct property to set by
	// querying this array by using the tag obtained from the object whose value we need to set
	// [propertyMappings objectAtIndex:[foo tag]]

	[creationDate setObjectValue:[self getPropertyForKey:[propertyMappings objectAtIndex:[creationDate tag]]]];
	
	[contentModDate setObjectValue:[self getPropertyForKey:[propertyMappings objectAtIndex:[contentModDate tag]]]];
	
	[attributeModDate setObjectValue:[self getPropertyForKey:[propertyMappings objectAtIndex:[attributeModDate tag]]]];
	
	[lastAccessedDate setObjectValue:[self getPropertyForKey:[propertyMappings objectAtIndex:[lastAccessedDate tag]]]];
	
	[backupDate setObjectValue:[self getPropertyForKey:[propertyMappings objectAtIndex:[backupDate tag]]]];
}

- (void)updatePOSIX
{
	unsigned short	mode;
	
	// Each subclass sets up an array of property keys. Tags of the object in the view 
	// hierarchy are set to the index of the tag that corresponds to the particular item
	// in the property array. So we go and look up the correct property to set by
	// querying this array by using the tag obtained from the object whose value we need to set
	// [propertyMappings objectAtIndex:[foo tag]]

	[uid setObjectValue:[self getPropertyForKey:[propertyMappings objectAtIndex:[uid tag]]]];
	[gid setObjectValue:[self getPropertyForKey:[propertyMappings objectAtIndex:[gid tag]]]];

	mode = [[self getPropertyForKey:[propertyMappings objectAtIndex:[perms tag]]] unsignedShortValue];
	
	// All we're doing here is breaking out the bits of the POSIX mode into
	// descrete pieces so we can set the checkboxes in the tab.
	[[perms cellWithTag:2] setState:(0x0001 & (mode >> 6))];
	[[perms cellWithTag:1] setState:(0x0001 & (mode >> 7))];
	[[perms cellWithTag:0] setState:(0x0001 & (mode >> 8))];

	[[perms cellWithTag:5] setState:(0x0001 & (mode >> 3))];	
	[[perms cellWithTag:4] setState:(0x0001 & (mode >> 4))];
	[[perms cellWithTag:3] setState:(0x0001 & (mode >> 5))];
	
	[[perms cellWithTag:8] setState:(0x0001 & (mode >> 0))];
	[[perms cellWithTag:7] setState:(0x0001 & (mode >> 1))];
	[[perms cellWithTag:6] setState:(0x0001 & (mode >> 2))];

	[[perms cellWithTag:11] setState:(0x0001 & (mode >> 9))];
	[[perms cellWithTag:10] setState:(0x0001 & (mode >> 10))];
	[[perms cellWithTag:9] setState:(0x0001 & (mode >> 11))];
}

- (void)updateSpecific
{
	// nothing to do, this is for subclasses to handle their specific needs
}

- (IBAction)setFileName:(id)sender
{
	// Each subclass sets up an array of property keys. Tags of the object in the view 
	// hierarchy are set to the index of the tag that corresponds to the particular item
	// in the property array. So we go and look up the correct property to set by
	// querying this array by using the tag obtained from the sender
	// [propertyMappings objectAtIndex:[sender tag]]
	
	[[inspectedItems objectAtIndex:0] setSpecificName:[sender objectValue] forFilesystem:[self filesystem]];
	
	[self updateNames];
}

- (IBAction)setProperty:(id)sender
{
	id objValue = [sender objectValue];
	
	if (!objValue && [sender isKindOfClass:[NSTextField class]])
		objValue = @"";

	if (objValue)
	{
		NSInteger x;
		for (x = 0; x < [inspectedItems count]; x ++)
		{
			[[inspectedItems objectAtIndex:x] setProperty:objValue forKey:[propertyMappings objectAtIndex:[sender tag]] inFilesystem:[self filesystem]];
		}
	}
	
	if ([[propertyMappings objectAtIndex:[sender tag]] isEqualTo:DRInvisible])
	{
		NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
		[defaultCenter postNotificationName:@"KWLeaveTab" object:nil];
		[defaultCenter postNotificationName:@"KWReloadRequested" object:nil];
	}
}

- (IBAction) setPOSIXModeProperty:(id)sender
{
	unsigned short mode = 0;
	
	// combine all of the checkbox states into bit values for the POSIX mode.
	mode |= [[sender cellWithTag:2] intValue] << 6;
	mode |= [[sender cellWithTag:1] intValue] << 7;
	mode |= [[sender cellWithTag:0] intValue] << 8;

	mode |= [[sender cellWithTag:5] intValue] << 3;	
	mode |= [[sender cellWithTag:4] intValue] << 4;
	mode |= [[sender cellWithTag:3] intValue] << 5;
	
	mode |= [[sender cellWithTag:8] intValue] << 0;
	mode |= [[sender cellWithTag:7] intValue] << 1;
	mode |= [[sender cellWithTag:6] intValue] << 2;

	mode |= [[sender cellWithTag:11] intValue] << 9;
	mode |= [[sender cellWithTag:10] intValue] << 10;
	mode |= [[sender cellWithTag:9] intValue] << 11;
	
	// Each subclass sets up an array of property keys. Tags of the object in the view 
	// hierarchy are set to the index of the tag that corresponds to the particular item
	// in the property array. So we go and look up the correct property to set by
	// querying this array by using the tag obtained from the sender
	// [propertyMappings objectAtIndex:[sender tag]]

	NSInteger x;
	for (x = 0; x < [inspectedItems count]; x ++)
	{
		[[inspectedItems objectAtIndex:x] setProperty:[NSNumber numberWithUnsignedShort:mode] forKey:[propertyMappings objectAtIndex:[sender tag]] inFilesystem:[self filesystem]];
	}
}
	
@end