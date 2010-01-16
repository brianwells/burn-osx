/*
     File:       ISO9660Controller.m
 
     Contains:   FSPropertyController subclass to handle the ISO9660 filesystem.
 
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
 terms, Apple grants you a personal, non-exclusive license, under Apple’s copyrights in 
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

#import "ISO9660Controller.h"


@implementation ISO9660Controller

- (NSString*) filesystem
{
	// We're the controller for the ISO 9660 filesystem, so return the correct value.
	return DRISO9660;
}

- (DRFilesystemInclusionMask) mask
{
	// We're the controller for the ISO 9660 filesystem, so return the correct value.
	return DRFilesystemInclusionMaskISO9660;
}

- (void) updateNames
{
	DRFSObject *firstItem = [inspectedItems objectAtIndex:0];

	[baseName setObjectValue:[firstItem baseName]];

	// Ah ha! It's this troublesome ISO filesystem issue with the filenames. Instead of being able
	// to just get the simple specific/mangled filename for the object, we need to specialze
	// for the ISO Level 1 or Level 2 name as appropriate
	[level1SpecificName setObjectValue:[firstItem specificNameForFilesystem:DRISO9660LevelOne]];
	[level1MangledName setObjectValue:[firstItem mangledNameForFilesystem:DRISO9660LevelOne]];

	[level2SpecificName setObjectValue:[firstItem specificNameForFilesystem:DRISO9660LevelTwo]];
	[level2MangledName setObjectValue:[firstItem mangledNameForFilesystem:DRISO9660LevelTwo]];
}

- (IBAction) setFileName:(id)sender
{
	DRFSObject *firstItem = [inspectedItems objectAtIndex:0];

	// Same this as in updateNames, we need to specialize the filename for the correct 
	// ISO Level.
	if (sender == level2SpecificName)
	{
		[firstItem setSpecificName:[sender objectValue] forFilesystem:DRISO9660LevelTwo];
	}
	else if (sender == level1SpecificName)
	{
		[firstItem setSpecificName:[sender objectValue] forFilesystem:DRISO9660LevelOne];
	}
	
	[self updateNames];
}

- (void)clearForMultipleSelection
{
	[[NSArray arrayWithObjects:level1SpecificName, level2SpecificName, level1MangledName, level2MangledName, nil] makeObjectsPerformSelector:@selector(setStringValue:) withObject:@""];
	[level1SpecificName setEnabled:NO];
	[level2SpecificName setEnabled:NO];
}

@end