/*
     File:       DiscInfoController.m
 
     Contains:   Settings panel controller that provides control over volume
                 properties of the burn hierarchy root.
 
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

#import "KWDataDiscInspector.h"
#import "KWCommonMethods.h"

static NSArray*	propertyTagMappings = nil;
static NSArray* filesystemNameTagMappings = nil;

@implementation KWDataDiscInspector

+ (void) initialize
{
	// Through clever arrangement of the tags of objects in the info panel,
	// we use these tags to index into an array of the filesystem properties.
	// When one of out UI items changes and sends it's action, we look up that
	// objects tag in this array, which gives us back the proper property to 
	// use as the dictionary key for the object value of the UI object.
	propertyTagMappings = [[NSArray alloc] initWithObjects:	DRISOMacExtensions,						//1
															DRISORockRidgeExtensions,				//2
															DRISOLevel,								//3
															DRVolumeSet,							//4
															DRPublisher,							//5
															DRDataPreparer,							//6
															DRApplicationIdentifier,				//7
															DRSystemIdentifier,						//8
															DRVolumeExpirationDate,					//9
															DRVolumeEffectiveDate,					//10
															DRCopyrightFile,						//11
															DRBibliographicFile,					//12
															DRAbstractFile,							//13
															DRDefaultDate,							//14
															DRVolumeCreationDate,					//15
															DRVolumeModificationDate,				//16
															DRVolumeCheckedDate,					//17
															@"DRUDFVolumeSetIdentifier",			//18
															@"DRUDFVolumeSetTimestamp",				//19
															DRApplicationIdentifier,				//20
															@"DRUDFPrimaryVolumeDescriptorNumber",	//21
															@"DRUDFVolumeSequenceNumber",			//22
															@"DRUDFMaxVolumeSequenceNumber",		//23
															@"DRUDFInterchangeLevel",				//24
															@"DRUDFMaxInterchangeLevel",			//25
															@"DRUDFApplicationIdentifierSuffix",	//26
															@"DRUDFVolumeSetImplementationUse",		//27
															DRPosixFileMode,						//28
															DRPosixUID,								//29
															DRPosixGID,								//30
															nil];
															
	// In a similar arrangement to above, we do the same object tag -> index mappings
	// for the filesystem names.
	filesystemNameTagMappings = [[NSArray alloc] initWithObjects:	DRAllFilesystems,			//31
																	DRISO9660,					//32
																	DRISO9660LevelOne,			//33
																	DRISO9660LevelTwo,			//34
																	DRJoliet,					//35
																	DRHFSPlus,					//36
																	@"DRUDF",					//37
																	nil];
}

- (id) init
{
	if (self = [super init])
	{
		fsProperties = [[NSMutableDictionary alloc] initWithCapacity:1];
	}
	
	return self;
}

- (void) dealloc
{
	[fsProperties release];
	
	[super dealloc];
}

- (void)awakeFromNib
{
	[mainIconView setImage:[[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(kGenericCDROMIcon)]];

	if ([KWCommonMethods OSVersion] < 0x1040)
		[tabView removeTabViewItem:[tabView tabViewItemAtIndex:3]];
	
	[fileList setDoubleAction:@selector(ok:)];

	//Needs to be set in Tiger (Took me a while to figure out since it worked since Jaguar without target)
	[fileList setTarget:self];
}

- (IBAction)ok:(id)sender
{
	if ([fileList selectedRow] > -1)
		[NSApp stopModalWithCode:NSOKButton];
}

- (IBAction)cancel:(id)sender
{
	[NSApp stopModalWithCode:NSCancelButton];
}

- (IBAction)setVolumeProperty:(id)sender
{
	int currentIndex = [sender tag] - 1;
	NSString *propertyTag = [propertyTagMappings objectAtIndex:[sender tag] - 1];
	id objectValue = [sender objectValue];

	if ([DRISOLevel isEqualTo:propertyTag])
	{
		// The ISO level needs special handling since the objectValue of a popup menu is the index of the
		// menu item, which starts at zero. We need it to start at 1.
		if ([NSNumber numberWithInt:[sender indexOfSelectedItem] + 1])
		{
			[fsProperties setObject:[NSNumber numberWithInt:[sender indexOfSelectedItem] + 1] forKey:DRISOLevel];
			[[NSNotificationCenter defaultCenter] postNotificationName:@"KWDiscPropertiesChanged" object:[fsProperties retain]];
		}
	}
	else
	{
		// But in every other case, we can just ask for the object value. Since everything is a date
		// or plain string, this can be handled by asking for the object value and 
		// passing that along.
		if ([sender objectValue])
		{
			if (currentIndex == 27 | currentIndex == 28)
				[fsProperties setObject:[objectValue dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES] forKey:propertyTag];
			else
				[fsProperties setObject:objectValue forKey:propertyTag];
		
			[[NSNotificationCenter defaultCenter] postNotificationName:@"KWDiscPropertiesChanged" object:[fsProperties retain]];
		}
	}
}

- (IBAction)selectRootDirFile:(id)sender
{
	int	returnCode;
	
	// Get the current list of root files from the mail app controller. This will be the 
	// list of files that you can choose from. For any of the special ISO root files 
	// (copyright, bibliographic, abstract), these file MUST exist in the root directory
	// of the ISO volume. This is in the spec, it's not negotiable.
	
	NSArray *rootChildren = [filesystemRoot children];
	NSMutableArray*	mutableRootFiles = [NSMutableArray arrayWithCapacity:1];
	
	int i;
	for (i=0;i<[rootChildren count];i++)
	{
		id currentObject = [rootChildren objectAtIndex:i];
	
		// A cheap (but somewhat lame) way of identifing a file is to check to see if it's expandable.
		// If not, it's a file.
		if ([currentObject isKindOfClass:[DRFile class]])
		{
			if (![[currentObject baseName] isEqualTo:@".VolumeIcon.icns"])
			{
				NSMutableDictionary *rowData = [NSMutableDictionary dictionary];
				[rowData setObject:[currentObject baseName] forKey:@"name"];
				[rowData setObject:currentObject forKey:@"drfsobject"];
				[mutableRootFiles addObject:rowData];
			}
		}
	}
	
	rootFiles = mutableRootFiles;
	[fileList reloadData];
	
	// setup and run the modal dialog.
	[okButton setEnabled:NO];
	[fileList selectRowIndexes:[NSIndexSet indexSetWithIndex:-1] byExtendingSelection:NO];
	returnCode = [NSApp runModalForWindow:fileChooser];
	[fileChooser orderOut:self];

	// User clicked OK, so we need to update display of the filename
	// as well as update the property we're setting.
	if (returnCode == NSOKButton)
	{
		// We know which text field to simulate an action from by looking at the tag of the
		// button that was pressed and subtracting off 100. Then we look up the text field
		// in the info window using viewWithTag:. We use this to set the text shown in the 
		// field to let the user know what file they selected.
		NSTextField* propertyView = [myView viewWithTag:[sender tag] - 99];
		
		[propertyView setObjectValue:[selectedItem valueForKey:@"name"]];
		[fsProperties setObject:[selectedItem valueForKey:@"drfsobject"] forKey:[propertyTagMappings objectAtIndex:[propertyView tag] - 1]];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"KWDiscPropertiesChanged" object:[fsProperties retain]];
	}

	// we don't need to hold onto this anymore. We'll grab it again next time.
	rootFiles = nil;
	[fileList reloadData];
}

- (IBAction)setVolumeName:(id)sender
{
	// The correct filesystem is encoded in the tag of the object.
	NSString*	filesystem;
	NSString*	volumeName;
	int			index = [sender tag] - 31;
	
	// If it's index 1 (that's ISO), we need to look at the ISO level popup.
	// For the filesystem names, we need to get specific since while we're 
	// creating an ISO filesystem, we can only get/set item/volume names
	// based on DRISO9660LevelOne or DRISO9660LevelTwo naming. The reason for
	// this is that ISO has two different methods of handling filenames on the volume
	// Each one has different characters that are valid and lengths of the strings
	// used. Other volume formats don't have this quirk, so we only need to do it
	// for ISO.
	if (index == 1)
	{
		int isoLevelInt = [[fsProperties objectForKey:DRISOLevel] intValue];
		index = index + (isoLevelInt ? isoLevelInt : 1);
	}

	// Get the correct filesystem based on the index we got from the object tag.
	filesystem = [filesystemNameTagMappings objectAtIndex:index];
	
	[filesystemRoot setSpecificName:[sender stringValue] forFilesystem:filesystem];
	volumeName = [filesystemRoot specificNameForFilesystem:filesystem];
	
	// Now, on the other end, we need to do some work if we're changing the Joliet 
	// volume name. Normally Joliet has a length limit of 64 UTF-16 characters. But for 
	// the volume name, there's not enough space, in fact there's only 32 bytes of space
	// so we can have at most 16 characters in the name. This unfortunately can't be handled
	// in the framework since there's no way to distinguish a file/folder that simply hasn't
	// been added to a hierarchy and the root of the filesystem (which doesn't have a parent)
	if (index == 4)
	{
		if ([volumeName length] > 16)
		{
			NSRange	jolietVolumeRange = NSMakeRange(0, 16);
			volumeName = [volumeName substringWithRange:jolietVolumeRange];
			[filesystemRoot setSpecificName:volumeName forFilesystem:filesystem];
		}
	}
	
	// reset what the user typed in since they might have used illegal characters.
	[sender setStringValue:volumeName];
}

- (IBAction)userSelectedISOLevel:(id)sender
{
	[self setVolumeProperty:sender];
	
	// When the user selects the ISO level popup menu, we'll switch the volume name shown.
	[isoName setStringValue:[filesystemRoot specificNameForFilesystem:[filesystemNameTagMappings objectAtIndex:[sender indexOfSelectedItem] + 2]]];
}

- (IBAction)setUDFVersion:(id)sender
{
	if ([sender indexOfSelectedItem] == 0)
		[filesystemRoot setProperty:DRUDFVersion102 forKey:DRUDFWriteVersion inFilesystem:@"DRUDF"];
	else
		[filesystemRoot setProperty:DRUDFVersion150 forKey:DRUDFWriteVersion inFilesystem:@"DRUDF"];
}

- (void)updateView:(KWDRFolder *)object
{
	NSDictionary *properties = [object discProperties];
	BOOL containsHFS = ([filesystemRoot effectiveFilesystemMask] & DRFilesystemInclusionMaskHFSPlus);
	BOOL containsISO = ([filesystemRoot effectiveFilesystemMask] & DRFilesystemInclusionMaskISO9660);
	BOOL containsJoliet = ([filesystemRoot effectiveFilesystemMask] & DRFilesystemInclusionMaskJoliet);
	BOOL containsUDF = NO;
		
	if (properties)
	{
		NSMutableDictionary *tempDict = [NSMutableDictionary dictionary];
		[tempDict addEntriesFromDictionary:properties];
		
		NSArray *fileKeys = [NSArray arrayWithObjects:DRCopyrightFile, DRBibliographicFile, DRAbstractFile,nil];
		
		int x;
		for (x=0;x<[fileKeys count];x++)
		{
			NSString *currentKey = [fileKeys objectAtIndex:x];
			NSString *currentFile = [properties objectForKey:currentKey];
			
			if (currentFile)
			{
				if ([[NSFileManager defaultManager] fileExistsAtPath:currentFile])
					[tempDict setObject:[DRFile fileWithPath:currentFile] forKey:currentKey];
			}
		}
	
		[fsProperties addEntriesFromDictionary:tempDict];
	}

	if (fsProperties)
	{
			if ([KWCommonMethods OSVersion] >= 0x1040)
			containsUDF = ([filesystemRoot effectiveFilesystemMask] & 1<<2);
	
		[self setOptionsForViews:[[hfsOptions contentView] subviews] setEnabled:containsHFS];
		[self setOptionsForViews:[[isoOptions contentView] subviews] setEnabled:containsISO];
		[self setOptionsForViews:[[jolietOptions contentView] subviews] setEnabled:containsJoliet];
			if ([KWCommonMethods OSVersion] >= 0x1040)
			[self setOptionsForViews:[[udfOptions contentView] subviews] setEnabled:containsUDF];
		[self setOptionsForViews:[[allOptions contentView] subviews] setEnabled:YES];
		
		//Set ISO level
		int isoLevelNumber = [[fsProperties objectForKey:DRISOLevel] intValue] - 1;
		[isoLevel selectItemAtIndex:isoLevelNumber];
	}
	
	[object setDiscProperties:nil];
	
	if ([KWCommonMethods OSVersion] >= 0x1040)
	{
		//Set UDF version
		int udfVersionNumber = [[NSNumber numberWithBool:[[[filesystemRoot propertiesForFilesystem:@"DRUDF" mergeWithOtherFilesystems:NO] objectForKey:DRUDFWriteVersion] isEqualTo:DRUDFVersion150]] intValue] + 1;
		[udfVersion selectItemAtIndex:udfVersionNumber];
	}

	if (containsHFS)
		[tabView selectTabViewItemWithIdentifier:@"HFS+"];
	else if (containsISO)
		[tabView selectTabViewItemWithIdentifier:@"ISO"];
	else if (containsJoliet)
		[tabView selectTabViewItemWithIdentifier:@"Joliet"];
	else if (containsUDF)
		[tabView selectTabViewItemWithIdentifier:@"UDF"];

	NSString*	volumeName;
	
	filesystemRoot = (DRFolder*)object;
	
	[nameField setStringValue:[filesystemRoot baseName]];
	
	DRTrack* track = [DRTrack trackForRootFolder:filesystemRoot];
	
	[sizeField setStringValue:[KWCommonMethods makeSizeFromFloat:[track estimateLength] * 2048]];

	// when we update the filesystem root, make sure that the text fields for the 
	// different filesystem names are all in sync.
	[hfsName setStringValue:[filesystemRoot specificNameForFilesystem:DRHFSPlus]];
		if ([KWCommonMethods OSVersion] >= 0x1040)
			[udfName setStringValue:[filesystemRoot specificNameForFilesystem:@"DRUDF"]];
	
	if ([[fsProperties objectForKey:DRISOLevel] intValue] == 1)
	{
		[isoName setStringValue:[filesystemRoot specificNameForFilesystem:DRISO9660LevelOne]];
	}
	else
	{
		[isoName setStringValue:[filesystemRoot specificNameForFilesystem:DRISO9660LevelTwo]];
	}
	
	volumeName = [filesystemRoot specificNameForFilesystem:DRJoliet];
	if ([volumeName length] > 16)
	{
		NSRange	jolietVolumeRange = NSMakeRange(0, 16);
		volumeName = [volumeName substringWithRange:jolietVolumeRange];
		[filesystemRoot setSpecificName:volumeName forFilesystem:DRJoliet];
	}

	[jolietName setStringValue:volumeName];

	[uid setObjectValue:[filesystemRoot propertyForKey:[propertyTagMappings objectAtIndex:[uid tag] - 1] inFilesystem:DRAllFilesystems mergeWithOtherFilesystems:NO]];
	[gid setObjectValue:[filesystemRoot propertyForKey:[propertyTagMappings objectAtIndex:[gid tag] - 1] inFilesystem:DRAllFilesystems mergeWithOtherFilesystems:NO]];

	unsigned short mode = [[filesystemRoot propertyForKey:[propertyTagMappings objectAtIndex:27] inFilesystem:DRAllFilesystems mergeWithOtherFilesystems:NO] unsignedShortValue];

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

	NSData *data = [filesystemRoot propertyForKey:DRMacWindowBounds inFilesystem:DRHFSPlus mergeWithOtherFilesystems:NO];
	if (data)
	{
		Rect *windowBounds = (Rect*)[data bytes];
	
		[hfsBoundsT setIntValue:windowBounds->top];
		[hfsBoundsL setIntValue:windowBounds->left];
		[hfsBoundsB setIntValue:windowBounds->bottom];
		[hfsBoundsR setIntValue:windowBounds->right];
	}
	else
	{
		[[NSArray arrayWithObjects:hfsBoundsT, hfsBoundsL, hfsBoundsB, hfsBoundsR,nil] makeObjectsPerformSelector:@selector(setStringValue:) withObject:@""];
	}
	
	data = [filesystemRoot propertyForKey:DRMacScrollPosition inFilesystem:DRHFSPlus mergeWithOtherFilesystems:NO];
	if (data)
	{
		Point *scrollPosition = (Point*)[data bytes];
		
		[hfsScrollX setIntValue:scrollPosition->h];
		[hfsScrollY setIntValue:scrollPosition->v];
	}
	else
	{
		[hfsScrollX setStringValue:@""];
		[hfsScrollY setStringValue:@""];
	}

	[hfsViewType setObjectValue:[filesystemRoot propertyForKey:DRMacWindowView inFilesystem:DRHFSPlus mergeWithOtherFilesystems:NO]];

	//Check for disc icon
	NSArray *rootChildren = [(DRFolder *)object children];
	int i;
	for (i=0;i<[rootChildren count];i++)
	{
		if ([[[rootChildren objectAtIndex:i] baseName] isEqualTo:@".VolumeIcon.icns"])
		{
			NSImage *icon = [[[NSImage alloc] initWithContentsOfFile:[[rootChildren objectAtIndex:i] sourcePath]] autorelease];
			[iconView setImage:icon];
		}
	}
}

- (IBAction)setPermissions:(id)sender
{
	unsigned short mode = 0;

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

	[filesystemRoot setProperty:[NSNumber numberWithUnsignedShort:mode] forKey:[propertyTagMappings objectAtIndex:[sender tag] -1] inFilesystem:DRAllFilesystems];
}

- (NSDictionary*)volumeProperties
{
	return [[fsProperties retain] autorelease];
}

- (IBAction)setIcon:(id)sender;
{
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	
	[openPanel setCanChooseDirectories:NO];
	[openPanel setCanChooseFiles:YES];
	[openPanel setAllowsMultipleSelection:NO];
	[openPanel setResolvesAliases:YES];

	[openPanel beginSheetForDirectory:nil file:nil types:[NSArray arrayWithObject:@"icns"] modalForWindow:[myView window] modalDelegate:self didEndSelector:@selector(openFileEnded:returnCode:contextInfo:) contextInfo:nil];
}

- (void)openFileEnded:(NSOpenPanel*)panel returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[panel orderOut:self];

	if (returnCode == NSOKButton)
	{
		[self deleteIcon:self];
		DRFile *icon = [DRFile fileWithPath:[panel filename]];
		[icon setBaseName:@".VolumeIcon.icns"];
		[icon setExplicitFilesystemMask:DRFilesystemInclusionMaskHFSPlus];
		[filesystemRoot addChild:icon];
		[filesystemRoot setProperty:[NSNumber numberWithUnsignedShort:1024] forKey:DRMacFinderFlags inFilesystem:DRHFSPlus];
		[iconView setImage:[[NSImage alloc] initWithContentsOfFile:[panel filename]]];
	}
}

- (IBAction)deleteIcon:(id)sender
{
	NSArray *rootChildren = [filesystemRoot children];
	
	int i;
	for (i=0;i<[rootChildren count];i++)
	{
		if ([[[rootChildren objectAtIndex:i] baseName] isEqualTo:@".VolumeIcon.icns"])
		{
			[filesystemRoot removeChild:[rootChildren objectAtIndex:i]];
			[iconView setImage:nil];
		}
	}
}

- (IBAction)setHFSBounds:(id)sender
{
	NSData*	boundsData;
	Rect	windowBounds;
	
	windowBounds.top = [hfsBoundsT intValue];
	windowBounds.left = [hfsBoundsL intValue];
	windowBounds.bottom = [hfsBoundsB intValue];
	windowBounds.right = [hfsBoundsR intValue];
	
	boundsData = [NSData dataWithBytes:&windowBounds length:sizeof(windowBounds)];

	[filesystemRoot setProperty:boundsData forKey:DRMacWindowBounds inFilesystem:DRHFSPlus];
}

- (IBAction)setHFSScroll:(id)sender
{
	NSData*	positionData;
	Point	scrollPosition;
	
	scrollPosition.h = [hfsScrollX intValue];
	scrollPosition.v = [hfsScrollY intValue];
	
	positionData = [NSData dataWithBytes:&scrollPosition length:sizeof(scrollPosition)];

	[filesystemRoot setProperty:positionData forKey:DRMacScrollPosition inFilesystem:DRHFSPlus];
}

- (IBAction)setHFSViewType:(id)sender
{
	if ([sender objectValue])
	[filesystemRoot setProperty:[sender objectValue] forKey:DRMacWindowView inFilesystem:DRHFSPlus];
}

- (IBAction)setUID:(id)sender
{
	if ([sender objectValue])
	[filesystemRoot setProperty:[sender objectValue] forKey:DRPosixUID inFilesystem:DRAllFilesystems];
}

- (IBAction)setGID:(id)sender
{
	if ([sender objectValue])	
	[filesystemRoot setProperty:[sender objectValue] forKey:DRPosixGID inFilesystem:DRAllFilesystems];
}

#pragma mark -
#pragma mark •• Data source methods
- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return [rootFiles count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)rowIndex
{
	return [[rootFiles objectAtIndex:rowIndex]valueForKey:[tableColumn identifier]];
}

#pragma mark -
#pragma mark •• Table delegate methods
- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	NSTableView*	tv = [aNotification object];
	BOOL rowSelected = ([tv selectedRow] != -1); 
	
	if (rowSelected)
		selectedItem = [rootFiles objectAtIndex:[tv selectedRow]];
	
	[okButton setEnabled:rowSelected];
}

- (id)myView
{
	return myView;
}

#pragma mark -
#pragma mark •• Convenience methods

- (void)setOptionsForViews:(NSArray *)views setEnabled:(BOOL)enabled
{
	NSEnumerator *iter = [views objectEnumerator];
	id cntl;
	
	while ((cntl = [iter nextObject]) != NULL)
	{
		if ([cntl isKindOfClass:[NSTabView class]])
		{
			NSArray *views = [tabView subviews];
			
			int x;
			for (x=0;x<[views count];x++)
			{
				id currentView = [views objectAtIndex:x];
				[self setOptionsForViews:[currentView subviews] setEnabled:enabled];
			}
		}
		else
		{
			int index = [cntl tag] - 1;
		
			if (index > -1 && index < 30)
			{
				id property;
			
				id currentTag = [propertyTagMappings objectAtIndex:index];
				property = [fsProperties objectForKey:currentTag];
			
				if ([currentTag isEqualTo:DRCopyrightFile] | [currentTag isEqualTo:DRBibliographicFile] | [currentTag isEqualTo:DRAbstractFile])
					property = [property baseName];
					
				if (property)
					[cntl setObjectValue:property];
			}
		
				if ([cntl respondsToSelector:@selector(setEnabled:)])
				[cntl setEnabled:enabled];
		}
	}
}

@end