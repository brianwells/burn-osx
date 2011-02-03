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

- (void)saveImageWithName:(NSString *)name withType:(NSInteger)type withFileSystem:(NSString *)fileSystem
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

		if ([types count] > 1 && [types containsObject:[NSNumber numberWithInteger:type]])
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

- (void)saveImageSavePanelDidEnd:(NSSavePanel *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	[sheet orderOut:self];
	
	NSArray *infoArray = contextInfo;

	if (returnCode == NSOKButton)
	{
		imagePath = [[NSString alloc] initWithString:[sheet filename]];
		
		if ([[NSFileManager defaultManager] fileExistsAtPath:imagePath])
			[KWCommonMethods removeItemAtPath:imagePath];
		
		progressPanel = [[KWProgress alloc] init];
		[progressPanel setTask:NSLocalizedString(@"Creating image file", nil)];
		[progressPanel setStatus:NSLocalizedString(@"Preparing...", nil)];
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
	infoArray = nil;
}

- (void)createImage:(NSDictionary *)dict
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	NSInteger succes = 0;

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(imageFinished:) name:@"KWBurnFinished" object:burner];
	
	KWSVCDImager *SVCDImager = [[KWSVCDImager alloc] init];
	succes = [SVCDImager createSVCDImage:[[dict objectForKey:@"Path"] stringByDeletingPathExtension] withFiles:[videoControllerOutlet files] withLabel:discName createVCD:[[dict objectForKey:@"Filesystem"] isEqualTo:@"-vcd"] hideExtension:[dict objectForKey:@"Hidden Extension"] errorString:&errorString];
	[SVCDImager release];
	SVCDImager = nil;
	
    if (succes == 0)
		[self imageFinished:@"KWSucces"];
	else if (succes == 1)
		[self imageFinished:@"KWFailure"];
	else
		[self imageFinished:@"KWCanceled"];

	[pool release];
}

- (void)showAuthorFailedOfType:(NSInteger)type
{	
	[progressPanel endSheet];
	[progressPanel release];
	progressPanel = nil;
	
	[burner release];
	burner = nil;

	KWAlert *alert = [[[KWAlert alloc] init] autorelease];
	[alert addButtonWithTitle:NSLocalizedString(@"OK", nil)];
	
	NSString *message = NSLocalizedString(@"Authoring failed", nil);
	
	if (type == 0)
		message = NSLocalizedString(@"Failed to create temporary folder", nil);
	
	[alert setMessageText:message];
	
	NSString *information = NSLocalizedString(@"There was a problem copying the disc", nil);
	
	if (type < 3)
		information = NSLocalizedString(@"There was a problem authoring the DVD", nil);
	
	[alert setInformativeText:information];
	
	if ([errorString rangeOfString:@"KWConsole:"].length > 0)
		[alert setDetails:errorString];
	else
		[alert setInformativeText:errorString];
	
	[alert beginSheetModalForWindow:mainWindow modalDelegate:self didEndSelector:nil contextInfo:nil];
}

- (void)imageFinished:(id)object
{
	[self restoreHiddenExtensions];

	NSString *returnCode;
	if ([object superclass] == [NSNotification class])
		returnCode = [[object userInfo] objectForKey:@"ReturnCode"];
	else
		returnCode = object;

	if (!isBurning | [returnCode isEqualTo:@"KWFailure"] | [returnCode isEqualTo:@"KWCanceled"])
	{
		[progressPanel endSheet];
		[progressPanel release];
		progressPanel = nil;
	}
	
	NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
	
	if ([returnCode isEqualTo:@"KWSucces"])
	{
		if ([[imagePath pathExtension] isEqualTo:@"cue"] && burner)
			[KWCommonMethods writeString:[audioControllerOutlet cueStringWithBinFile:[[[imagePath lastPathComponent] stringByDeletingPathExtension] stringByAppendingPathExtension:@"bin"]] toFile:imagePath errorString:nil];
	
		if ([[[mainTabView selectedTabViewItem] identifier] isEqualTo:@"Copy"])
		{
			[copyControllerOutlet remount:nil];
		
			NSDictionary *infoDict = [copyControllerOutlet isoInfo];
			
			if (infoDict)
				[infoDict writeToFile:[[imagePath stringByDeletingPathExtension] stringByAppendingPathExtension:@"isoInfo"] atomically:YES];
		}
	
		[defaultCenter postNotificationName:@"growlCreateImage" object:NSLocalizedString(@"Succesfully created a disk image",nil)];
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
			[alert setInformativeText:[[object userInfo] objectForKey:@"KWError"]];
		else
			[alert setInformativeText:NSLocalizedString(@"There was a problem creating the image",nil)];
	
		if (errorString != nil)
		{
			if ([errorString rangeOfString:@"KWConsole:"].length > 0)
				[alert setDetails:errorString];
			else
				[alert setInformativeText:errorString];
		}
		
		[alert beginSheetModalForWindow:mainWindow modalDelegate:self didEndSelector:nil contextInfo:nil];
	}
	else if ([returnCode isEqualTo:@"KWCanceled"])
	{
		if (burner)
			[KWCommonMethods removeItemAtPath:imagePath];
	}
	
	if (burner)
	{
		[defaultCenter removeObserver:self name:@"KWBurnFinished" object:burner];
	
		[burner release];
		burner = nil;
	}
	else
	{
		[defaultCenter removeObserver:self name:@"KWImagerFinished" object:nil];
	}

	[imagePath release];
	imagePath = nil;
	
	[discName release];
	discName = nil;
	
	[self deleteTemporaryFiles];
}

//////////////////
// Burn actions //
//////////////////

#pragma mark -
#pragma mark •• Burn actions

- (void)burnDiscWithName:(NSString *)name withType:(NSInteger)type
{
	burner = [[KWBurner alloc] init];
	discName = [name retain];

	//Check if the user wants to copy the disc in the burning device
	[burner setIgnoreMode:(type == 3 && [[[KWCommonMethods savedDevice] status] objectForKey:DRDeviceMediaInfoKey] && [[copyControllerOutlet myDisc] isEqualTo:[@"/dev/" stringByAppendingString:[[[[KWCommonMethods savedDevice] status] objectForKey:DRDeviceMediaInfoKey] objectForKey:DRDeviceMediaBSDNameKey]]])];

	[burner setType:type];
	[burner setCombinableTypes:[self getCombinableFormats:NO]];
	[burner beginBurnSetupSheetForWindow:mainWindow modalDelegate:self didEndSelector:@selector(burnSetupPanelEnded:returnCode:contextInfo:) contextInfo:nil];
}

- (void)burnSetupPanelEnded:(KWBurner *)myBurner returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
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
	else
	{
		[burner release];
		burner = nil;
		
		[discName release];
		discName = nil;
	}
}

- (void)burnTracks
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	NSMutableArray *tracks = [NSMutableArray array];
	NSInteger result = 0;
	BOOL maskSet = NO;
	NSNumber *layerBreak = nil;

	DRFolder *rootFolder = [[[DRFolder alloc] initWithName:discName] autorelease];
	[rootFolder setExplicitFilesystemMask:0];

	if ([[burner types] containsObject:[NSNumber numberWithInteger:1]])
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
					NSInteger i;
					for (i = 0; i < [[audioTracks children] count]; i ++)
					{
						[rootFolder addChild:[self newDRFSObject:[[audioTracks children] objectAtIndex:i]]];
					}
				}
				else
				{
					[rootFolder addChild:[self newDRFSObject:audioTracks]];
				}
			}
			else if ([audioTracks isKindOfClass:[NSNumber class]])
			{
				result = [audioTracks integerValue];
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
	
	if ([[burner types] containsObject:[NSNumber numberWithInteger:2]] && result == 0)
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
					NSInteger i;
					for (i = 0;i < [[videoTracks children] count]; i ++)
					{
						[rootFolder addChild:[self newDRFSObject:[[videoTracks children] objectAtIndex:i]]];
					}
				}
				else
				{
					[rootFolder addChild:[self newDRFSObject:videoTracks]];
				}
			}
			else if ([videoTracks isKindOfClass:[NSNumber class]])
			{
				result = [videoTracks integerValue];
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

	if ([[burner types] containsObject:[NSNumber numberWithInteger:0]] && result == 0)
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
			
				NSInteger i;
				for (i = 0; i < [[dataTracks children] count]; i ++)
				{
					NSAutoreleasePool *subPool = [[NSAutoreleasePool alloc] init];
					id object = [[dataTracks children] objectAtIndex:i];
				
					if ([[object baseName] isEqualTo:@".VolumeIcon.icns"])
						[rootFolder setProperty:[NSNumber numberWithUnsignedShort:1024] forKey:DRMacFinderFlags inFilesystem:DRHFSPlus];
				
					[rootFolder addChild:[self newDRFSObject:object]];

					[subPool release];
					subPool = nil;
				}
			}
			else
			{
				[rootFolder addChild:[self newDRFSObject:dataTracks]];
			}
		}
		else if ([dataTracks isKindOfClass:[NSNumber class]])
		{
			result = [dataTracks integerValue];
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
	
	if ([[burner types] containsObject:[NSNumber numberWithInteger:3]] && result == 0)
	{
		id copyTracks = [copyControllerOutlet myTrackWithErrorString:&errorString andLayerBreak:&layerBreak];
	
		if ([copyTracks isKindOfClass:[NSNumber class]])
			result = [copyTracks integerValue];
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
			[progressPanel setStatus:NSLocalizedString(@"Preparing...", nil)];
			
			if ([KWCommonMethods createFileAtPath:imagePath attributes:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:hiddenExtension], NSFileExtensionHidden, nil] errorString:&errorString])
			{	
				[burner performSelectorOnMainThread:@selector(burnTrackToImage:) withObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:imagePath, tracks, nil] forKeys:[NSArray arrayWithObjects:@"Path", @"Track", nil]] waitUntilDone:YES];
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
				progressPanel = nil;
				
				[burner release];
				burner = nil;
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
		progressPanel = nil;
		
		[burner release];
		burner = nil;
		
		[imagePath release];
		imagePath = nil;
		
		[discName release];
		discName = nil;
	}

	[pool release];
	pool = nil;
}

- (void)burnFinished:(NSNotification *)notif
{
	NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];

	[defaultCenter postNotificationName:@"KWDoneBurning" object:nil];

	[self restoreHiddenExtensions];

	isBurning = NO;

	NSString *returnCode = [[notif userInfo] objectForKey:@"ReturnCode"];

	[progressPanel endSheet];
	[progressPanel release];
	progressPanel = nil;
	
	[burner release];
	burner = nil;

	[defaultCenter removeObserver:self name:@"KWBurnFinished" object:burner];
	
	if ([returnCode isEqualTo:@"KWSucces"])
	{
		[defaultCenter postNotificationName:@"growlFinishedBurning" object:[NSString stringWithFormat:NSLocalizedString(@"'%@' was burned succesfully", nil), discName]];
	}
	else if ([returnCode isEqualTo:@"KWFailure"])
	{
		[[NSNotificationCenter defaultCenter] postNotificationName:@"growlFailedBurning" object:[NSString stringWithFormat:NSLocalizedString(@"Failed to burn '%@'", nil), discName]];
		KWAlert *alert = [[[KWAlert alloc] init] autorelease];
		[alert addButtonWithTitle:NSLocalizedString(@"OK",nil)];
		[alert setMessageText:NSLocalizedString(@"Burning failed",nil)];
		[alert setInformativeText:[[notif userInfo] objectForKey:@"KWError"]];
		[alert setAlertStyle:NSWarningAlertStyle];
	
		[alert beginSheetModalForWindow:mainWindow modalDelegate:self didEndSelector:nil contextInfo:nil];
	}
	
	[discName release];
	discName = nil;

	[self deleteTemporaryFiles];
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
		[formats addObject:[NSNumber numberWithInteger:0]];
	
	if ([audioControllerOutlet isCombinable])
		[formats addObject:[NSNumber numberWithInteger:1]];
	
	if ([videoControllerOutlet isCombinable] && (![audioControllerOutlet isAudioCD] | needAudioCDCheck))
		[formats addObject:[NSNumber numberWithInteger:2]];

	return formats;
}

- (DRFSObject *)newDRFSObject:(DRFSObject *)object
{
	DRFSObject *newObject;
		
	if ([object isVirtual])
	{
		newObject = [DRFolder virtualFolderWithName:[object baseName]];
		
		NSInteger i;
		for (i = 0; i < [[(DRFolder *)object children] count]; i ++)
		{
			[(DRFolder *)newObject addChild:[self newDRFSObject:[[(DRFolder *)object children] objectAtIndex:i]]];
		}
	}
	else
	{
		BOOL isDir;
		NSFileManager *defaultManager = [NSFileManager defaultManager];
		
		[defaultManager fileExistsAtPath:[object sourcePath] isDirectory:&isDir];
		
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
				[defaultManager changeFileAttributes:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:(finderFlags & 0x0010)] forKey:NSFileExtensionHidden] atPath:[object sourcePath]];
			}
				
			newObject = [DRFile fileWithPath:[object sourcePath]];
		}
			
		[newObject setBaseName:[object baseName]];
	}
		
	[newObject setExplicitFilesystemMask:[object explicitFilesystemMask]];

	[newObject setSpecificName:[object specificNameForFilesystem:DRHFSPlus] forFilesystem:DRHFSPlus];
	[newObject setSpecificName:[object specificNameForFilesystem:DRISO9660] forFilesystem:DRISO9660];
	[newObject setSpecificName:[object specificNameForFilesystem:DRJoliet] forFilesystem:DRJoliet];
	
	#if MAC_OS_X_VERSION_MAX_ALLOWED < 1050
	if ([KWCommonMethods OSVersion] >= 0x1040)
	#endif
	[newObject setSpecificName:[object specificNameForFilesystem:@"DRUDF"] forFilesystem:@"DRUDF"];
		
	[newObject setProperties:[object propertiesForFilesystem:DRHFSPlus mergeWithOtherFilesystems:NO] inFilesystem:DRHFSPlus];
	[newObject setProperties:[object propertiesForFilesystem:DRISO9660 mergeWithOtherFilesystems:NO] inFilesystem:DRISO9660];
	[newObject setProperties:[object propertiesForFilesystem:DRJoliet mergeWithOtherFilesystems:NO] inFilesystem:DRJoliet];
	
	#if MAC_OS_X_VERSION_MAX_ALLOWED < 1050
	if ([KWCommonMethods OSVersion] >= 0x1040)
	#endif
	[newObject setProperties:[object propertiesForFilesystem:@"DRUDF" mergeWithOtherFilesystems:NO] inFilesystem:@"DRUDF"];	

	return newObject;
}

- (BOOL)waitForMediaIfNeeded
{
	NSDictionary *mediaStatus = [[[KWCommonMethods savedDevice] status] objectForKey:DRDeviceMediaStateKey];
	NSDictionary *mediaInfo = [[[KWCommonMethods savedDevice] status] objectForKey:DRDeviceMediaInfoKey];

	BOOL correctMedia = ![mediaStatus isEqualTo:DRDeviceMediaStateNone];

	while (correctMedia == NO && shouldWait == YES)
	{
		NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
	
		if ([mediaStatus isEqualTo:DRDeviceMediaStateMediaPresent])
		{
			if ([[mediaInfo objectForKey:DRDeviceMediaIsBlankKey] boolValue] | [[mediaInfo objectForKey:DRDeviceMediaIsAppendableKey] boolValue] | ([[mediaInfo objectForKey:DRDeviceMediaIsOverwritableKey] boolValue] && [[[burner properties] objectForKey:DRBurnOverwriteDiscKey] boolValue]))
				return YES;
			else
				[[KWCommonMethods savedDevice] ejectMedia];
		}
		else if ([mediaStatus isEqualTo:DRDeviceMediaStateInTransition])
		{
			[progressPanel setStatus:NSLocalizedString(@"Waiting for the drive...", Localized)];
		}
		else if ([mediaStatus isEqualTo:DRDeviceMediaStateNone])
		{
			[progressPanel setStatus:NSLocalizedString(@"Waiting for a disc to be inserted...", Localized)];
		}
	
		[innerPool release];
		innerPool = nil;
	}
	
	if (shouldWait == NO)
		return NO;
	
	return YES;
}

- (void)stopWaiting
{
	shouldWait = NO;
}

- (void)restoreHiddenExtensions
{
	if (extensionHiddenArray)
	{
		NSInteger i;
		for (i = 0; i < [extensionHiddenArray count]; i ++)
		{
			NSDictionary *hiddenDictionary = [extensionHiddenArray objectAtIndex:i];
			[[NSFileManager defaultManager] changeFileAttributes:[NSDictionary dictionaryWithObject:[hiddenDictionary objectForKey:@"Extension Hidden"] forKey:NSFileExtensionHidden] atPath:[hiddenDictionary objectForKey:@"Path"]];
		}
		
		[extensionHiddenArray release];
		extensionHiddenArray = nil;
	}
}

- (void)deleteTemporaryFiles
{
	NSArray *controllers = [NSArray arrayWithObjects:dataControllerOutlet, audioControllerOutlet, videoControllerOutlet, copyControllerOutlet, nil];
	NSNumber *boolNumber = [NSNumber numberWithBool:([[[NSUserDefaults standardUserDefaults] objectForKey:@"KWCleanTemporaryFolderAction"] integerValue] == 2)];
	[controllers makeObjectsPerformSelector:@selector(deleteTemporayFiles:) withObject:boolNumber];
}

@end