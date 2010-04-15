//
//  KWDiscCreator.m
//  Burn
//
//  Created by Maarten Foukhar on 15-11-08.
//  Copyright 2009 Kiwi Fruitware. All rights reserved.
//

#import "KWDiscCreator.h"
#import "KWDataController.h"
#import "KWAudioController.h"
#import "KWVideoController.h"
#import "KWCopyController.h"
#import "KWCommonMethods.h"
#import "KWTrackProducer.h"
#import "KWSVCDImager.h"
#import "KWAlert.h"

@implementation KWDiscCreator

- (id)init
{
	self = [super init];

	burner = nil;
	
	return self;
}

//////////////////////
// Sessions actions //
//////////////////////

#pragma mark -
#pragma mark •• Sessions actions

- (IBAction)saveCombineSessions:(id)sender
{
	[burner combineSessions:sender];
}

///////////////////
// Image actions //
///////////////////

#pragma mark -
#pragma mark •• Image actions

- (void)saveImageWithName:(NSString *)name withType:(int)type withFileSystem:(NSString *)fileSystem
{
	NSString *extension;
	NSArray *info;
	discName = [name retain];
	
	if ([fileSystem isEqualTo:@"-vcd"] | [fileSystem isEqualTo:@"-svcd"] | [fileSystem isEqualTo:@"-audio-cd"])
		extension = @"cue";
	else
		extension = @"iso";

	//Setup save sheet
	NSSavePanel *sheet = [NSSavePanel savePanel];
	[sheet setMessage:NSLocalizedString(@"Choose a location to save the image file",nil)];
	[sheet setRequiredFileType:extension];
	[sheet setCanSelectHiddenExtension:YES];
	[saveCombineSessions setState:NSOffState];

	if (type < 4)
	{
		//Setup image burner
		burner = [[KWBurner alloc] init];
		[burner setType:type];
	
		//Setup combining options
		NSArray *types = [self getCombinableFormats:YES];

		if ([types count] > 1 && [types containsObject:[NSNumber numberWithInt:type]])
		{
			[burner setCombinableTypes:types];
			[burner prepareTypes];
			[burner setCombineBox:saveCombineSessions];
			[sheet setAccessoryView:saveImageView];
		}
	
		info = [[NSArray alloc] initWithObjects:name, nil];
	}
	else
	{
		info = [[NSArray alloc] initWithObjects:name, fileSystem, nil];
	}

	//Show save sheet
	[sheet beginSheetForDirectory:nil file:name modalForWindow:mainWindow modalDelegate:self didEndSelector:@selector(saveImageSavePanelDidEnd:returnCode:contextInfo:) contextInfo:info];
}

- (void)saveImageSavePanelDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[sheet orderOut:self];
	
	NSArray *infoArray = contextInfo;

	if (returnCode == NSOKButton)
	{
		imagePath = [[NSString alloc] initWithString:[sheet filename]];
	
		progressPanel = [[KWProgress alloc] init];
		[progressPanel setTask:NSLocalizedString(@"Creating image file",nil)];
		[progressPanel setStatus:NSLocalizedString(@"Preparing...",nil)];
		[progressPanel setIcon:[[NSWorkspace sharedWorkspace] iconForFileType:[imagePath pathExtension]]];
		[progressPanel setMaximumValue:[NSNumber numberWithDouble:0]];
		[progressPanel beginSheetForWindow:mainWindow];
		
		if ([infoArray count] == 1)
		{
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(imageFinished:) name:@"KWBurnFinished" object:burner];
			hiddenExtension = [sheet isExtensionHidden];
			[NSThread detachNewThreadSelector:@selector(burnTracks) toTarget:self withObject:nil];
		}
		else
		{
			[NSThread detachNewThreadSelector:@selector(createImage:) toTarget:self withObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:imagePath, [infoArray objectAtIndex:1], [infoArray  objectAtIndex:0],[NSNumber numberWithBool:[sheet isExtensionHidden]], nil] forKeys:[NSArray arrayWithObjects:@"Path", @"Filesystem", @"Name", @"Hidden Extension", nil]]];
		}
	}
	
	[infoArray release];
}

- (void)createImage:(NSDictionary *)dict
{
	NSAutoreleasePool *pool=[[NSAutoreleasePool alloc] init];

	int succes = 0;

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(imageFinished:) name:@"KWBurnFinished" object:burner];
	
	KWSVCDImager *SVCDImager = [[KWSVCDImager alloc] init];
	succes = [SVCDImager createSVCDImage:[[dict objectForKey:@"Path"] stringByDeletingPathExtension] withFiles:[videoControllerOutlet files] withLabel:discName createVCD:[[dict objectForKey:@"Filesystem"] isEqualTo:@"-vcd"] hideExtension:[dict objectForKey:@"Hidden Extension"] errorString:&errorString];
	[SVCDImager release];
	
    if (succes == 0)
		[self imageFinished:@"KWSucces"];
	else if (succes == 1)
		[self imageFinished:@"KWFailure"];
	else
		[self imageFinished:@"KWCanceled"];

	[pool release];
}

- (void)showAuthorFailedOfType:(int)type
{	
	[progressPanel endSheet];
	[progressPanel release];
	[burner release];

	KWAlert *alert = [[[KWAlert alloc] init] autorelease];
	[alert addButtonWithTitle:NSLocalizedString(@"OK",nil)];
	
	if (type == 0)
		[alert setMessageText:NSLocalizedString(@"Failed to create temporary folder",nil)];
	else
		[alert setMessageText:NSLocalizedString(@"Authoring failed",nil)];
	
	if (type < 3)
		[alert setInformativeText:NSLocalizedString(@"There was a problem authoring the DVD",nil)];
	else
		[alert setInformativeText:NSLocalizedString(@"There was a problem copying the disc",nil)];
	
	if ([errorString rangeOfString:@"KWConsole:"].length > 0)
		[alert setDetails:errorString];
	else
		[alert setInformativeText:errorString];
	
	[alert setAlertStyle:NSWarningAlertStyle];
	
	[alert beginSheetModalForWindow:mainWindow modalDelegate:self didEndSelector:nil contextInfo:nil];
}

- (void)imageFinished:(id)object
{
	if (extensionHiddenArray)
	{
		int x;
		for (x=0;x<[extensionHiddenArray count];x++)
		{
			[[NSFileManager defaultManager] changeFileAttributes:[NSDictionary dictionaryWithObject:[[extensionHiddenArray objectAtIndex:x] objectForKey:@"Extension Hidden"] forKey:NSFileExtensionHidden] atPath:[[extensionHiddenArray objectAtIndex:x] objectForKey:@"Path"]];
		}
		
		[extensionHiddenArray release];
		extensionHiddenArray = nil;
	}

	NSString *returnCode;
	if ([object superclass] == [NSNotification class])
		returnCode = [[object userInfo] objectForKey:@"ReturnCode"];
	else
		returnCode = object;

	if (!isBurning | [returnCode isEqualTo:@"KWFailure"] | [returnCode isEqualTo:@"KWCanceled"])
	{
		[progressPanel endSheet];
		[progressPanel release];
	}
	
	if ([returnCode isEqualTo:@"KWSucces"])
	{
		if ([[imagePath pathExtension] isEqualTo:@"cue"] && burner)
			[KWCommonMethods writeString:[audioControllerOutlet cueStringWithBinFile:[[[imagePath lastPathComponent] stringByDeletingPathExtension] stringByAppendingPathExtension:@"bin"]] toFile:imagePath errorString:nil];
	
		[[NSNotificationCenter defaultCenter] postNotificationName:@"growlCreateImage" object:NSLocalizedString(@"Succesfully created a disk image",nil)];
	}
	else if ([returnCode isEqualTo:@"KWFailure"])
	{
		if (burner)
			[KWCommonMethods removeItemAtPath:imagePath];
	
		[[NSNotificationCenter defaultCenter] postNotificationName:@"growlFailedImage" object:[NSString stringWithFormat:NSLocalizedString(@"Failed to create '%@'", nil), [[NSFileManager defaultManager] displayNameAtPath:imagePath]]];
		KWAlert *alert = [[[KWAlert alloc] init] autorelease];
		[alert addButtonWithTitle:NSLocalizedString(@"OK",nil)];
		[alert setMessageText:NSLocalizedString(@"Image failed",nil)];
		[alert setAlertStyle:NSWarningAlertStyle];
		
		if (burner)
			[alert setInformativeText:[[object userInfo] objectForKey:@"Error"]];
		else
			[alert setInformativeText:NSLocalizedString(@"There was a problem creating the image",nil)];
	
		
		if ([errorString rangeOfString:@"KWConsole:"].length > 0)
			[alert setDetails:errorString];
		else
			[alert setInformativeText:errorString];
		
		[alert beginSheetModalForWindow:mainWindow modalDelegate:self didEndSelector:nil contextInfo:nil];
	}
	else if ([returnCode isEqualTo:@"KWCanceled"])
	{
		if (burner)
			[KWCommonMethods removeItemAtPath:imagePath];
	}
	
	if (burner)
	{
		[[NSNotificationCenter defaultCenter] removeObserver:self name:@"KWBurnFinished" object:burner];
	
		[burner release];
	}
	else
	{
		[[NSNotificationCenter defaultCenter] removeObserver:self name:@"KWImagerFinished" object:nil];
	}

	[imagePath release];
	imagePath = nil;
	[discName release];
	discName = nil;

	[dataControllerOutlet deleteTemporayFiles:([[[NSUserDefaults standardUserDefaults] objectForKey:@"KWCleanTemporaryFolderAction"] intValue] == 2)];
	[audioControllerOutlet deleteTemporayFiles:([[[NSUserDefaults standardUserDefaults] objectForKey:@"KWCleanTemporaryFolderAction"] intValue] == 2)];
	[videoControllerOutlet deleteTemporayFiles:([[[NSUserDefaults standardUserDefaults] objectForKey:@"KWCleanTemporaryFolderAction"] intValue] == 2)];
	[copyControllerOutlet deleteTemporayFiles:([[[NSUserDefaults standardUserDefaults] objectForKey:@"KWCleanTemporaryFolderAction"] intValue] == 2)];
}

//////////////////
// Burn actions //
//////////////////

#pragma mark -
#pragma mark •• Burn actions

- (void)burnDiscWithName:(NSString *)name withType:(int)type
{
	burner = [[KWBurner alloc] init];
	discName = [name retain];

	//Check if the user wants to copy the disc in the burning device
	[burner setIgnoreMode:(type == 3 && [[[KWCommonMethods savedDevice] status] objectForKey:DRDeviceMediaInfoKey] && [[copyControllerOutlet myDisc] isEqualTo:[@"/dev/" stringByAppendingString:[[[[KWCommonMethods savedDevice] status] objectForKey:DRDeviceMediaInfoKey] objectForKey:DRDeviceMediaBSDNameKey]]])];

	[burner setType:type];
	[burner setCombinableTypes:[self getCombinableFormats:NO]];
	[burner beginBurnSetupSheetForWindow:mainWindow modalDelegate:self didEndSelector:@selector(burnSetupPanelEnded:returnCode:contextInfo:) contextInfo:nil];
}

- (void)burnSetupPanelEnded:(KWBurner *)myBurner returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode == NSOKButton)
	{
		if ((([copyControllerOutlet isCueFile] | [copyControllerOutlet isAudioCD] && [[[mainTabView selectedTabViewItem] identifier] isEqualTo:@"Copy"]) | ([audioControllerOutlet isAudioCD] && [[[mainTabView selectedTabViewItem] identifier] isEqualTo:@"Audio"])) && ![burner isCD])
		{
			NSAlert *alert = [[[NSAlert alloc] init] autorelease];
			[alert addButtonWithTitle:NSLocalizedString(@"OK",nil)];
			[alert setMessageText:NSLocalizedString(@"No CD",nil)];
			[alert setAlertStyle:NSWarningAlertStyle];
			
			if ([copyControllerOutlet isCueFile])
				[alert setInformativeText:NSLocalizedString(@"A cue/bin file needs to be burned on a CD",nil)];
			else
				[alert setInformativeText:NSLocalizedString(@"To burn a Audio-CD the media should be a CD",nil)];
		
			[alert beginSheetModalForWindow:mainWindow modalDelegate:self didEndSelector:nil contextInfo:nil];
		}
		else
		{
			progressPanel = [[KWProgress alloc] init];
			[progressPanel setIcon:[NSImage imageNamed:@"Burn"]];
			[progressPanel setTask:[NSString stringWithFormat:NSLocalizedString(@"Burning '%@'", nil), discName]];
			[progressPanel setStatus:NSLocalizedString(@"Preparing...",nil)];
			[progressPanel setMaximumValue:[NSNumber numberWithDouble:0]];
			[progressPanel beginSheetForWindow:mainWindow];
			
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(burnFinished:) name:@"KWBurnFinished" object:burner];
			[NSThread detachNewThreadSelector:@selector(burnTracks) toTarget:self withObject:nil];
		}
	}
}

- (void)burnTracks
{
	NSAutoreleasePool *pool=[[NSAutoreleasePool alloc] init];

	NSMutableArray *tracks = [NSMutableArray array];
	int result = 0;
	BOOL maskSet = NO;
	NSNumber *layerBreak = nil;

	DRFolder *rootFolder = [[DRFolder alloc] initWithName:discName];
	[rootFolder setExplicitFilesystemMask:nil];

	if ([[burner types] containsObject:[NSNumber numberWithInt:1]])
	{
		id audioTracks = [audioControllerOutlet myTrackWithBurner:burner errorString:&errorString];
		
		if (audioTracks)
		{
			if ([audioTracks isKindOfClass:[DRFSObject class]])
			{
				[rootFolder setExplicitFilesystemMask:([audioTracks explicitFilesystemMask])];
				maskSet = YES;
					
				if ([audioTracks isVirtual])
				{
					int x;
					for (x=0;x<[[audioTracks children] count];x++)
					{
						[rootFolder addChild:[self newDRFSObject:[[audioTracks children] objectAtIndex:x]]];
					}
				}
				else
				{
					[rootFolder addChild:[self newDRFSObject:audioTracks]];
				}
			}
			else if ([audioTracks isKindOfClass:[NSNumber class]])
			{
				result = [audioTracks intValue];
			}
			else if ([audioTracks isKindOfClass:[NSArray class]])
			{
				[tracks addObjectsFromArray:audioTracks];
			}
			else
			{
				[tracks addObject:audioTracks];
			}
		}
	}
	
	if ([[burner types] containsObject:[NSNumber numberWithInt:2]] && result == 0)
	{
		id videoTracks = [videoControllerOutlet myTrackWithBurner:burner errorString:&errorString];

		if (videoTracks)
		{
			if ([videoTracks isKindOfClass:[DRFSObject class]])
			{
				if (maskSet)
				{
					[rootFolder setExplicitFilesystemMask:([rootFolder explicitFilesystemMask] | [videoTracks explicitFilesystemMask])];
				}
				else
				{
					[rootFolder setExplicitFilesystemMask:([videoTracks explicitFilesystemMask])];
					maskSet = YES;
				}
					
				if ([videoTracks isVirtual])
				{
					int x;
					for (x=0;x<[[videoTracks children] count];x++)
					{
						[rootFolder addChild:[self newDRFSObject:[[videoTracks children] objectAtIndex:x]]];
					}
				}
				else
				{
					[rootFolder addChild:[self newDRFSObject:videoTracks]];
				}
			}
			else if ([videoTracks isKindOfClass:[NSNumber class]])
			{
				result = [videoTracks intValue];
			}
			else if ([videoTracks isKindOfClass:[NSArray class]])
			{
				[tracks addObjectsFromArray:videoTracks];
			}
			else
			{
				[tracks addObject:videoTracks];
			}
		}
	}

	if ([[burner types] containsObject:[NSNumber numberWithInt:0]] && result == 0)
	{
		id dataTracks = [dataControllerOutlet myTrackWithErrorString:&errorString];
	
		if ([dataTracks isKindOfClass:[DRFSObject class]])
		{
			if (maskSet)
			{
				[rootFolder setExplicitFilesystemMask:([rootFolder explicitFilesystemMask] | [dataTracks explicitFilesystemMask])];
			}
			else
			{
				[rootFolder setExplicitFilesystemMask:([dataTracks explicitFilesystemMask])];
				maskSet = YES;
			}
			
			if ([dataTracks isVirtual])
			{
				if ([KWCommonMethods fsObjectContainsHFS:dataTracks])
				{
					extensionHiddenArray = [[NSMutableArray alloc] init];
				}
			
				int x;
				for (x=0;x<[[dataTracks children] count];x++)
				{
					NSAutoreleasePool *subPool = [[NSAutoreleasePool alloc] init];
				
					if ([[[[dataTracks children] objectAtIndex:x] baseName] isEqualTo:@".VolumeIcon.icns"])
						[rootFolder setProperty:[NSNumber numberWithUnsignedShort:1024] forKey:DRMacFinderFlags inFilesystem:DRHFSPlus];
				
					[rootFolder addChild:[self newDRFSObject:[[dataTracks children] objectAtIndex:x]]];

					[subPool release];
				}
			}
			else
			{
				[rootFolder addChild:[self newDRFSObject:dataTracks]];
			}
		}
		else if ([dataTracks isKindOfClass:[NSNumber class]])
		{
			result = [dataTracks intValue];
		}
		else if ([dataTracks isKindOfClass:[NSArray class]])
		{
			[tracks addObjectsFromArray:dataTracks];
		}
		else
		{
			[tracks addObject:dataTracks];
		}
	}
	
	if ([[burner types] containsObject:[NSNumber numberWithInt:3]] && result == 0)
	{
		id copyTracks = [copyControllerOutlet myTrackWithErrorString:&errorString andLayerBreak:&layerBreak];
	
		if ([copyTracks isKindOfClass:[NSNumber class]])
			result = [copyTracks intValue];
		else if ([copyTracks isKindOfClass:[NSArray class]])
			[tracks addObjectsFromArray:copyTracks];
		else
			[tracks addObject:copyTracks];
	}

	if (result == 0)
	{
		if (maskSet)
			[tracks addObject:[DRTrack trackForRootFolder:rootFolder]];

		if (imagePath)
		{
			[progressPanel performSelectorOnMainThread:@selector(setMaximumValue:) withObject:[NSNumber numberWithDouble:0] waitUntilDone:NO];
			[progressPanel setTask:[NSString stringWithFormat:NSLocalizedString(@"Creating image file '%@'", nil), [[NSFileManager defaultManager] displayNameAtPath:imagePath]]];
			[progressPanel setStatus:NSLocalizedString(@"Preparing...",nil)];
			
			if ([KWCommonMethods createFileAtPath:imagePath attributes:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:hiddenExtension], NSFileExtensionHidden,nil] errorString:&errorString])
			{	
				[burner performSelectorOnMainThread:@selector(burnTrackToImage:) withObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:imagePath, tracks, nil] forKeys:[NSArray arrayWithObjects:@"Path",@"Track",nil]] waitUntilDone:YES];
			}
			else
			{
				[burner release];
				burner = nil;
				[self performSelectorOnMainThread:@selector(imageFinished:) withObject:@"KWFailure" waitUntilDone:YES];
			}
		}
		else
		{
			[progressPanel performSelectorOnMainThread:@selector(setMaximumValue:) withObject:[NSNumber numberWithDouble:0] waitUntilDone:NO];
			shouldWait = YES;
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stopWaiting) name:@"KWStopWaiting" object:nil];
			[progressPanel setCancelNotification:@"KWStopWaiting"];
		
			if ([self waitForMediaIfNeeded] == YES)
			{
				[progressPanel setCancelNotification:nil];
				[progressPanel setTask:[NSString stringWithFormat:NSLocalizedString(@"Burning '%@'", nil), discName]];
				[progressPanel setStatus:NSLocalizedString(@"Preparing...",nil)];
				[burner performSelectorOnMainThread:@selector(setLayerBreak:) withObject:layerBreak waitUntilDone:YES];
				[burner performSelectorOnMainThread:@selector(burnTrack:) withObject:tracks waitUntilDone:YES];
			}
			else
			{
				[progressPanel endSheet];
				[progressPanel release];
				[burner release];
			}
		
			[[NSNotificationCenter defaultCenter] removeObserver:self name:@"KWStopWaiting" object:nil];
		
			shouldWait = NO;
		}
	}
	else if (result == 1)
	{
		[self showAuthorFailedOfType:[burner currentType]];
	}
	else
	{
		[progressPanel endSheet];
		[progressPanel release];
		[burner release];
		[imagePath release];
		imagePath = nil;
		[discName release];
		discName = nil;
	}

	[pool release];
}

- (void)burnFinished:(NSNotification*)notif
{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWDoneBurning" object:nil];

	if (extensionHiddenArray)
	{
		int x;
		for (x=0;x<[extensionHiddenArray count];x++)
		{
			[[NSFileManager defaultManager] changeFileAttributes:[NSDictionary dictionaryWithObject:[[extensionHiddenArray objectAtIndex:x] objectForKey:@"Extension Hidden"] forKey:NSFileExtensionHidden] atPath:[[extensionHiddenArray objectAtIndex:x] objectForKey:@"Path"]];
		}
		[extensionHiddenArray release];
		extensionHiddenArray = nil;
	}

	isBurning = NO;

	NSString *returnCode = [[notif userInfo] objectForKey:@"ReturnCode"];

	[progressPanel endSheet];
	[progressPanel release];
	[burner release];

	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"KWBurnFinished" object:burner];
	
	if ([returnCode isEqualTo:@"KWSucces"])
	{
		[[NSNotificationCenter defaultCenter] postNotificationName:@"growlFinishedBurning" object:[NSString stringWithFormat:NSLocalizedString(@"'%@' was burned succesfully", nil), discName]];
	}
	else if ([returnCode isEqualTo:@"KWFailure"])
	{
		[[NSNotificationCenter defaultCenter] postNotificationName:@"growlFailedBurning" object:[NSString stringWithFormat:NSLocalizedString(@"Failed to burn '%@'", nil), discName]];
		KWAlert *alert = [[[KWAlert alloc] init] autorelease];
		[alert addButtonWithTitle:NSLocalizedString(@"OK",nil)];
		[alert setMessageText:NSLocalizedString(@"Burning failed",nil)];
		[alert setInformativeText:[[notif userInfo] objectForKey:@"Error"]];
		[alert setAlertStyle:NSWarningAlertStyle];
		[alert setDetails:errorString];
	
		[alert beginSheetModalForWindow:mainWindow modalDelegate:self didEndSelector:nil contextInfo:nil];
	}
	
	[discName release];

	[dataControllerOutlet deleteTemporayFiles:([[[NSUserDefaults standardUserDefaults] objectForKey:@"KWCleanTemporaryFolderAction"] intValue] == 2)];
	[audioControllerOutlet deleteTemporayFiles:([[[NSUserDefaults standardUserDefaults] objectForKey:@"KWCleanTemporaryFolderAction"] intValue] == 2)];
	[videoControllerOutlet deleteTemporayFiles:([[[NSUserDefaults standardUserDefaults] objectForKey:@"KWCleanTemporaryFolderAction"] intValue] == 2)];
	[copyControllerOutlet deleteTemporayFiles:([[[NSUserDefaults standardUserDefaults] objectForKey:@"KWCleanTemporaryFolderAction"] intValue] == 2)];
}

///////////////////
// Other actions //
///////////////////

#pragma mark -
#pragma mark •• Other actions

- (NSArray *)getCombinableFormats:(BOOL)needAudioCDCheck
{
	NSMutableArray *formats = [NSMutableArray array];

	if ([dataControllerOutlet isCombinable] && ([dataControllerOutlet isOnlyHFSPlus] | (![audioControllerOutlet isAudioCD] | needAudioCDCheck)))
		[formats addObject:[NSNumber numberWithInt:0]];
	
	if ([audioControllerOutlet isCombinable])
		[formats addObject:[NSNumber numberWithInt:1]];
	
	if ([videoControllerOutlet isCombinable] && (![audioControllerOutlet isAudioCD] | needAudioCDCheck))
		[formats addObject:[NSNumber numberWithInt:2]];

	return formats;
}

- (DRFSObject *)newDRFSObject:(DRFSObject *)object
{
	DRFSObject *newObject;
		
		if ([object isVirtual])
		{
			newObject = [DRFolder virtualFolderWithName:[object baseName]];
		
			int x;
			for (x=0;x<[[(DRFolder *)object children] count];x++)
			{
				[(DRFolder *)newObject addChild:[self newDRFSObject:[[(DRFolder *)object children] objectAtIndex:x]]];
			}
		}
		else
		{
			BOOL isDir;
			[[NSFileManager defaultManager] fileExistsAtPath:[object sourcePath] isDirectory:&isDir];
		
			if (isDir)
			{
				newObject = [DRFolder folderWithPath:[object sourcePath]];
			}
			else
			{
				if (extensionHiddenArray)
				{
					unsigned short finderFlags = [KWCommonMethods getFinderFlagsAtPath:[object sourcePath]];
					[extensionHiddenArray addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[object sourcePath],[NSNumber numberWithBool:(finderFlags & 0x0010)],nil] forKeys:[NSArray arrayWithObjects:@"Path",@"Extension Hidden",nil]]];
				
					finderFlags = [[object propertyForKey:DRMacFinderFlags inFilesystem:DRHFSPlus mergeWithOtherFilesystems:NO] unsignedShortValue];
					[[NSFileManager defaultManager] changeFileAttributes:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:(finderFlags & 0x0010)] forKey:NSFileExtensionHidden] atPath:[object sourcePath]];
				}
				
				newObject = [DRFile fileWithPath:[object sourcePath]];
			}
			
			[newObject setBaseName:[object baseName]];
		}
		
	[newObject setExplicitFilesystemMask:[object explicitFilesystemMask]];

	[newObject setSpecificName:[object specificNameForFilesystem:DRHFSPlus] forFilesystem:DRHFSPlus];
	[newObject setSpecificName:[object specificNameForFilesystem:DRISO9660] forFilesystem:DRISO9660];
	[newObject setSpecificName:[object specificNameForFilesystem:DRJoliet] forFilesystem:DRJoliet];
	
	if ([KWCommonMethods OSVersion] >= 0x1040)
		[newObject setSpecificName:[object specificNameForFilesystem:@"DRUDF"] forFilesystem:@"DRUDF"];
		
	[newObject setProperties:[object propertiesForFilesystem:DRHFSPlus mergeWithOtherFilesystems:NO] inFilesystem:DRHFSPlus];
	[newObject setProperties:[object propertiesForFilesystem:DRISO9660 mergeWithOtherFilesystems:NO] inFilesystem:DRISO9660];
	[newObject setProperties:[object propertiesForFilesystem:DRJoliet mergeWithOtherFilesystems:NO] inFilesystem:DRJoliet];

	if ([KWCommonMethods OSVersion] >= 0x1040)
		[newObject setProperties:[object propertiesForFilesystem:@"DRUDF" mergeWithOtherFilesystems:NO] inFilesystem:@"DRUDF"];	

	return newObject;
}

- (BOOL)waitForMediaIfNeeded
{
	BOOL correctMedia = ![[[[KWCommonMethods savedDevice] status] objectForKey:DRDeviceMediaStateKey] isEqualTo:DRDeviceMediaStateNone];

	while (correctMedia == NO && shouldWait == YES)
	{
		NSAutoreleasePool *innerPool=[[NSAutoreleasePool alloc] init];
	
		if ([[[[KWCommonMethods savedDevice] status] objectForKey:DRDeviceMediaStateKey] isEqualTo:DRDeviceMediaStateMediaPresent])
		{
			if ([[[[[KWCommonMethods savedDevice] status] objectForKey:DRDeviceMediaInfoKey] objectForKey:DRDeviceMediaIsBlankKey] boolValue] | [[[[[KWCommonMethods savedDevice] status] objectForKey:DRDeviceMediaInfoKey] objectForKey:DRDeviceMediaIsAppendableKey] boolValue] | ([[[[[KWCommonMethods savedDevice] status] objectForKey:DRDeviceMediaInfoKey] objectForKey:DRDeviceMediaIsOverwritableKey] boolValue] && [[[burner properties] objectForKey:DRBurnOverwriteDiscKey] boolValue]))
				return YES;
			else
				[[KWCommonMethods savedDevice] ejectMedia];
		}
		else if ([[[[KWCommonMethods savedDevice] status] objectForKey:DRDeviceMediaStateKey] isEqualTo:DRDeviceMediaStateInTransition])
		{
			[progressPanel setStatus:NSLocalizedString(@"Waiting for the drive...", Localized)];
		}
		else if ([[[[KWCommonMethods savedDevice] status] objectForKey:DRDeviceMediaStateKey] isEqualTo:DRDeviceMediaStateNone])
		{
			[progressPanel setStatus:NSLocalizedString(@"Waiting for a disc to be inserted...", Localized)];
		}
	
		[innerPool release];
	}
	
	if (shouldWait == NO)
		return NO;
	
	return YES;
}

- (void)stopWaiting
{
	shouldWait = NO;
}

@end