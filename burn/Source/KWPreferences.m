#import "KWPreferences.h"
#import <DiscRecording/DiscRecording.h>
#import "KWDVDAuthorizer.h"

@implementation KWPreferences

- (id)init
{
	if (self = [super init])
	{
		preferenceMappings = [[NSArray alloc] initWithObjects:	@"KWUseSoundEffects",			//1
																@"KWRememberLastTab",			//2
																@"KWRememberPopups",			//3
																@"KWTemporaryLocationPopup",	//4
																@"KWCleanTemporaryFolderAction",//5
																@"KWBurnOptionsVerifyBurn",		//6
																@"KWShowOverwritableSpace",		//7
																@"KWDefaultCDMedia",			//8
																@"KWDefaultDVDMedia",			//9
																@"KWDefaultMedia",				//10
																@"KWDefaultDataType",			//11
																@"KWShowFilePackagesAsFolder",	//12
																@"KWCalculateFilePackageSizes",	//13
																@"KWCalculateFolderSizes",		//14
																@"KWCalculateTotalSize",		//15
																@"KWDefaultAudioType",			//16
																@"KWDefaultPregap",				//17
																@"KWUseCDText",					//18
																@"KWDefaultMP3Bitrate",			//19
																@"KWDefaultMP3Mode",			//20
																@"KWCreateArtistFolders",		//21
																@"KWCreateAlbumFolders",		//22
																@"KWDefaultRegion",				//23
																@"KWDefaultVideoType",			//24
																@"KWDefaultDVDSoundType",		//25
																@"KWCustomDVDVideoBitrate",		//26
																@"KWDefaultDVDVideoBitrate",	//27
																@"KWCustomDVDSoundBitrate",		//28
																@"KWDefaultDVDSoundBitrate",	//29
																@"KWDVDForce43",				//30
																@"KWForceMPEG2",				//31
																@"KWMuxSeperateStreams",		//32
																@"KWRemuxMPEG2Streams",			//33
																@"KWLoopDVD",					//34
																@"KWUseTheme",					//35
																@"KWDVDThemeFormat",			//36
																@"KWDefaultDivXSoundType",		//37
																@"KWCustomDivXVideoBitrate",	//38
																@"KWDefaultDivXVideoBitrate",	//39
																@"KWCustomDivXSoundBitrate",	//40
																@"KWDefaultDivxSoundBitrate",	//41
																@"KWCustomDivXSize",			//42
																@"KWDefaultDivXWidth",			//43
																@"KWDefaultDivXHeight",			//44
																@"KWCustomFPS",					//45
																@"KWDefaultFPS",				//46
																@"KWAllowMSMPEG4",				//47
																@"KWForceDivX",					//48
																@"KWSaveBorders",				//49
																@"KWSaveBorderSize",			//50
																@"KWDebug",						//51
																@"KWUseCustomFFMPEG",			//52
																@"KWCustomFFMPEG",				//53
																@"KWAllowOverBurning",			//54
	nil];
																
		itemsList = [[NSMutableDictionary alloc] init];
		[NSBundle loadNibNamed:@"KWPreferences" owner:self];
	}

return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[[DRNotificationCenter currentRunLoopCenter] removeObserver:self name:DRDeviceStatusChangedNotification object:nil];
	[itemsList release];
	[savedAudioItem release];

	[super dealloc];
}

- (void)awakeFromNib
{
	NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];
	NSFileManager *defaultManager = [NSFileManager defaultManager];

	//Hide CD-Text since it's not supported on Panther 
	[cdTextCheckbox setHidden:([KWCommonMethods OSVersion] < 0x1040)];

	dataViewHeight = [dataView frame].size.height;

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(settingsChangedByOptionsMenuInMainWindow) name:NSUserDefaultsDidChangeNotification object:nil];

	//Load the custom options
	//General
	NSString *temporaryFolder = [standardDefaults objectForKey:@"KWTemporaryLocation"];
	[temporaryFolderPopup insertItemWithTitle:[defaultManager displayNameAtPath:temporaryFolder] atIndex:0];
	NSImage *folderImage = [[NSWorkspace sharedWorkspace] iconForFile:temporaryFolder];
	[folderImage setSize:NSMakeSize(16,16)];
	[[temporaryFolderPopup itemAtIndex:0] setImage:folderImage];
	[[temporaryFolderPopup itemAtIndex:0] setToolTip:[[[standardDefaults objectForKey:@"KWTemporaryLocation"] stringByDeletingLastPathComponent] stringByAppendingPathComponent:[defaultManager displayNameAtPath:[standardDefaults objectForKey:@"KWTemporaryLocation"]]]];
		
	//Burner
	[KWCommonMethods setupBurnerPopup:burnerPopup];
	
	NSArray *cells = [completionActionMatrix cells];
	BOOL mount = ([[standardDefaults objectForKey:@"KWBurnOptionsCompletionAction"] isEqualTo:@"DRBurnCompletionActionMount"]);
	[[cells objectAtIndex:0] setObjectValue:[NSNumber numberWithBool:!mount]];
	[[cells objectAtIndex:1] setObjectValue:[NSNumber numberWithBool:mount]];
	
	NSInteger selectedCDItem = [[standardDefaults objectForKey:@"KWDefaultCDMedia"] intValue];
	if (selectedCDItem == 0 | selectedCDItem == 3)
		[standardDefaults setObject:[NSNumber numberWithInt:6] forKey:@"KWDefaultCDMedia"];
	
	[cdPopup setAutoenablesItems:NO];
	[(NSMenuItem *)[cdPopup itemAtIndex:0] setEnabled:NO];
	[(NSMenuItem *)[cdPopup itemAtIndex:3] setEnabled:NO];
	
	NSInteger selectedDVDItem = [[standardDefaults objectForKey:@"KWDefaultDVDMedia"] intValue];
	if (selectedDVDItem == 0 | selectedDVDItem == 3)
		[standardDefaults setObject:[NSNumber numberWithInt:4] forKey:@"KWDefaultDVDMedia"];
	
	[dvdPopup setAutoenablesItems:NO];
	[(NSMenuItem *)[dvdPopup itemAtIndex:0] setEnabled:NO];
	[(NSMenuItem *)[dvdPopup itemAtIndex:3] setEnabled:NO];
	
	//Video
	[themePopup removeAllItems];
	
	NSBundle *mainBundle = [NSBundle mainBundle];
	NSString *defaultThemePath = [[mainBundle pathForResource:@"Themes" ofType:nil] stringByAppendingPathComponent:@"Default.burnTheme"];
	NSBundle *themeBundle = [NSBundle bundleWithPath:defaultThemePath];
	NSDictionary *theme = [[NSArray arrayWithContentsOfFile:[themeBundle pathForResource:@"Theme" ofType:@"plist"]] objectAtIndex:[[standardDefaults objectForKey:@"KWDVDThemeFormat"] intValue]];
	
	themePaths = [[NSMutableArray alloc] init];
	[themePaths addObject:defaultThemePath];
	
	[themePopup addItemWithTitle:[theme objectForKey:@"KWThemeTitle"]];
		
	NSMutableArray *mightBeThemes = [NSMutableArray array];
	NSArray *defaultThemes = [defaultManager directoryContentsAtPath:[mainBundle pathForResource:@"Themes" ofType:@""]];
	NSString *userThemefolder = @"~/Library/Application Support/Burn/Themes";
	userThemefolder = [userThemefolder stringByExpandingTildeInPath];
	NSArray *userThemes = [defaultManager directoryContentsAtPath:userThemefolder];
	
	[mightBeThemes addObjectsFromArray:defaultThemes];
	[mightBeThemes addObject:@"---"];
	[mightBeThemes addObjectsFromArray:userThemes];
	
	NSInteger y;
	for (y=0;y<[mightBeThemes count];y++)
	{
		NSString *currentFile = [mightBeThemes objectAtIndex:y];

		if (![currentFile isEqualTo:@"Default.burnTheme"])
		{
			if ([[currentFile pathExtension] isEqualTo:@"burnTheme"])
			{
				NSString *themePath;
				
				if (y <= [defaultThemes count])
					themePath = [mainBundle pathForResource:@"Themes" ofType:@""];
				else
					themePath = userThemefolder;

				NSBundle *themeBundle = [NSBundle bundleWithPath:[themePath stringByAppendingPathComponent:currentFile]];
				NSDictionary *theme = [[NSArray arrayWithContentsOfFile:[themeBundle pathForResource:@"Theme" ofType:@"plist"]] objectAtIndex:[[standardDefaults objectForKey:@"KWDVDThemeFormat"] intValue]];
			
				[themePaths addObject:[themePath stringByAppendingPathComponent:currentFile]];
				[themePopup addItemWithTitle:[theme objectForKey:@"KWThemeTitle"]];
			}
			else if ([currentFile isEqualTo:@"---"] && [userThemes count] > 0)
			{
				[themePaths addObject:@"Seperator"];
				[[themePopup menu] addItem:[NSMenuItem separatorItem]];
			}
		}
	}
	
	[themePopup selectItemAtIndex:[[standardDefaults objectForKey:@"KWDVDTheme"] intValue]];
	
	//Load the options for our views
	[self setViewOptions:[NSArray arrayWithObjects:generalView, burnerView, dataView, audioView, videoView, advancedView, nil]];

	[self setupToolbar];
	[toolbar setSelectedItemIdentifier:[standardDefaults objectForKey:@"KWSavedPrefView"]];
	[self toolbarAction:[toolbar selectedItemIdentifier]];
	
	DRNotificationCenter *currentRunLoopCenter = [DRNotificationCenter currentRunLoopCenter];
	[currentRunLoopCenter addObserver:self selector:@selector(mediaChanged:) name:DRDeviceDisappearedNotification object:nil];
	[currentRunLoopCenter addObserver:self selector:@selector(mediaChanged:) name:DRDeviceAppearedNotification object:nil];
	
	NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
	[defaultCenter addObserver:self selector:@selector(mediaChanged:) name:@"KWMediaChanged" object:nil];
	[defaultCenter addObserver:self selector:@selector(saveFrame) name:NSWindowWillCloseNotification object:nil];

	NSWindow *myWindow = [self window];
	[myWindow setFrameUsingName:@"Preferences"];

	if ([standardDefaults boolForKey:@"KWFirstRun"] == YES)
		[myWindow setFrameOrigin:NSMakePoint(500,[[NSScreen mainScreen] frame].size.height - [myWindow frame].size.height - 54)];
}

- (void)saveFrame
{
	[[self window] saveFrameUsingName:@"Preferences"];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

///////////////////
// Main actions //
///////////////////

#pragma mark -
#pragma mark •• Main actions

//////////////////////
// PrefPane actions //
//////////////////////

#pragma mark -
#pragma mark •• PrefPane actions

- (void)showPreferences
{
	[[self window] makeKeyAndOrderFront:self];
}

- (IBAction)setPreferenceOption:(id)sender
{
	NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];
	NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
	NSInteger tag = [sender tag];
	id object = [sender objectValue];

	if (tag == 4)
	{
		if ([sender indexOfSelectedItem] == 4)
		{
			NSOpenPanel *sheet = [NSOpenPanel openPanel];
			[sheet setCanChooseFiles:NO];
			[sheet setCanChooseDirectories:YES];
			[sheet setAllowsMultipleSelection:NO];
			[sheet beginSheetForDirectory:nil file:nil types:nil modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(temporaryOpenPanelDidEnd:returnCode:contextInfo:) contextInfo:nil];
		}
		else
		{
			[standardDefaults setObject:object forKey:[preferenceMappings objectAtIndex:tag - 1]];
		}
	}
	else
	{
		[standardDefaults setObject:object forKey:[preferenceMappings objectAtIndex:tag - 1]];
	}
	
	//Reload the data list
	if (tag == 12 | tag == 13 | tag == 14)
	{
		[standardDefaults synchronize];
		[defaultCenter postNotificationName:@"KWReloadRequested" object:nil];
	}
	else if (tag == 15) //Calculate total size
	{
		[standardDefaults synchronize];
		[defaultCenter postNotificationName:@"KWTogglePopups" object:nil];
	}
	
	if (tag == 36)
	{
		[self setPreviewImage:self];
	}
	
	[self checkForExceptions:sender];
}

//General

#pragma mark -
#pragma mark •• - General

- (void)temporaryOpenPanelDidEnd:(NSOpenPanel *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	[sheet orderOut:self];
	
	NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];

	if (returnCode == NSOKButton)
	{
		[temporaryFolderPopup removeItemAtIndex:0];
		NSString *temporaryFolder = [sheet filename];
		[temporaryFolderPopup insertItemWithTitle:[[NSFileManager defaultManager] displayNameAtPath:temporaryFolder] atIndex:0];
		NSImage *folderImage = [[NSWorkspace sharedWorkspace] iconForFile:temporaryFolder];
		[folderImage setSize:NSMakeSize(16,16)];
		NSMenuItem *item = [temporaryFolderPopup itemAtIndex:0];
		[item setImage:folderImage];
		[item setToolTip:[[temporaryFolder stringByDeletingLastPathComponent] stringByAppendingPathComponent:[[NSFileManager defaultManager] displayNameAtPath:temporaryFolder]]];
		[temporaryFolderPopup selectItemAtIndex:0];
	
		[standardDefaults setObject:[sheet filename] forKey:@"KWTemporaryLocation"];
		[standardDefaults setObject:[NSNumber numberWithInt:0] forKey:@"KWTemporaryLocationPopup"];
	}
	else
	{
		[temporaryFolderPopup selectItemAtIndex:[[standardDefaults objectForKey:@"KWTemporaryLocationPopup"] intValue]];
	}
}

//Burner

#pragma mark -
#pragma mark •• - Burner

- (IBAction)setBurner:(id)sender
{
	DRDevice *currentDevice = [[DRDevice devices] objectAtIndex:[burnerPopup indexOfSelectedItem]];
	NSMutableDictionary *burnDict = [NSMutableDictionary dictionary];
	NSDictionary *currentDeviceInfo = [currentDevice info];
	
	[burnDict setObject:[currentDeviceInfo objectForKey:@"DRDeviceProductNameKey"] forKey:@"Product"];
	[burnDict setObject:[currentDeviceInfo objectForKey:@"DRDeviceVendorNameKey"] forKey:@"Vendor"];
	[burnDict setObject:@"" forKey:@"SerialNumber"];

	[[NSUserDefaults standardUserDefaults] setObject:burnDict forKey:@"KWDefaultDeviceIdentifier"];
}

- (IBAction)setCompletionAction:(id)sender
{
	NSString *completionAction;

	if ([sender selectedCell] == [[sender cells] objectAtIndex:0])
		completionAction = @"DRBurnCompletionActionEject";
	else
		completionAction = @"DRBurnCompletionActionMount";

	[[NSUserDefaults standardUserDefaults] setObject:completionAction forKey:@"KWBurnOptionsCompletionAction"];
}

//Video

#pragma mark -
#pragma mark •• - Video

- (IBAction)setTheme:(id)sender
{
	NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];

	[standardDefaults setObject:[sender objectValue] forKey:@"KWDVDTheme"];
	[standardDefaults setObject:[themePaths objectAtIndex:[themePopup indexOfSelectedItem]] forKey:@"KWDVDThemePath"];

	[self setPreviewImage:self];
}

- (IBAction)addTheme:(id)sender
{
	NSOpenPanel *sheet = [NSOpenPanel openPanel];
	[sheet setCanChooseFiles:YES];
	[sheet setCanChooseDirectories:NO];
	[sheet setAllowsMultipleSelection:YES];
	[sheet beginSheetForDirectory:nil file:nil types:[NSArray arrayWithObject:@"burnTheme"] modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(themeOpenPanelDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

- (void)themeOpenPanelDidEnd:(NSOpenPanel *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	[sheet orderOut:self];

	if (returnCode == NSOKButton)
	{
		[self addThemeAndShow:[sheet filenames]];
	}
}

- (IBAction)deleteTheme:(id)sender
{
	if ([themePopup indexOfSelectedItem] != 0)
	{
		NSString *themePath = [themePaths objectAtIndex:[themePopup indexOfSelectedItem]];
		
		if (themePath)
		{
			if ([KWCommonMethods removeItemAtPath:[themePaths objectAtIndex:[themePopup indexOfSelectedItem]]])
			{
				[themePopup removeItemAtIndex:[themePopup indexOfSelectedItem]];
				[themePaths removeObject:themePath];

				if ([themePaths indexOfObject:@"Seperator"] == [themePaths count] - 1)
				{
					NSInteger index = [themePopup numberOfItems] - 1;
					[themePopup removeItemAtIndex:index];
					[themePaths removeObjectAtIndex:index];
				}
		
				[self setTheme:themePopup];
			}
		}
		else
		{
			NSBeep();
		}
	}
	else
	{
		NSBeep();
	}
}

- (IBAction)showPreview:(id)sender
{
	if ([previewWindow isVisible])
	{
		[previewWindow orderOut:self];
	}
	else
	{
		[self setPreviewImage:self];
		[previewWindow makeKeyAndOrderFront:self];
	}
}

- (IBAction)setPreviewImage:(id)sender
{
	NSString *themePath = [themePaths objectAtIndex:[themePopup indexOfSelectedItem]];

	if (themePath)
	{
		NSBundle *themeBundle = [NSBundle bundleWithPath:themePath];
		NSDictionary *theme = [[NSArray arrayWithContentsOfFile:[themeBundle pathForResource:@"Theme" ofType:@"plist"]] objectAtIndex:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDVDThemeFormat"] intValue]];
	
		[previewImageView setImage:[[KWDVDAuthorizer alloc] getPreviewImageFromTheme:theme ofType:[previewImagePopup indexOfSelectedItem]]];
	}
}

//Advanced

#pragma mark -
#pragma mark •• - Advanced

- (IBAction)chooseFFMPEG:(id)sender
{
	NSOpenPanel *sheet = [NSOpenPanel openPanel];
	[sheet setCanChooseFiles:YES];
	[sheet setCanChooseDirectories:NO];
	[sheet setAllowsMultipleSelection:NO];
	[sheet beginSheetForDirectory:nil file:nil types:nil modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(openPanelDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

- (void)openPanelDidEnd:(NSOpenPanel *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	[sheet orderOut:self];

	if (returnCode == NSOKButton)
	{
		[[advancedView viewWithTag:53] setStringValue:[sheet filename]];
		[[NSUserDefaults standardUserDefaults] setObject:[sheet filename] forKey:@"KWCustomFFMPEG"];
	}
}

/////////////////////
// Toolbar actions //
/////////////////////

#pragma mark -
#pragma mark •• Toolbar actions

- (NSToolbarItem *)createToolbarItemWithName:(NSString *)name
{
	NSToolbarItem *toolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier:name];
	[toolbarItem autorelease];
	[toolbarItem setLabel:NSLocalizedString(name, Localized)];
	[toolbarItem setPaletteLabel:[toolbarItem label]];
	[toolbarItem setImage:[KWCommonMethods getImageForName:name]];
	[toolbarItem setTarget:self];
	[toolbarItem setAction:@selector(toolbarAction:)];
	[itemsList setObject:name forKey:name];

	return toolbarItem;
}

- (void)setupToolbar
{
	toolbar = [[NSToolbar alloc] initWithIdentifier:@"mainToolbar"];
	[toolbar autorelease];
	[toolbar setDelegate:self];
	[toolbar setAllowsUserCustomization:NO];
	[toolbar setAutosavesConfiguration:NO];
	[[self window] setToolbar:toolbar];
}

- (void)toolbarAction:(id)object
{
	id itemIdentifier;

	if ([object isKindOfClass:[NSToolbarItem class]])
		itemIdentifier = [object itemIdentifier];
	else
		itemIdentifier = object;
	
	id view = [self myViewWithIdentifier:itemIdentifier];

	[[self window] setContentView:[[[NSView alloc] initWithFrame:[view frame]] autorelease]];
	[self resizeWindowOnSpotWithRect:[view frame]];
	[[self window] setContentView:view];
	[[self window] setTitle:NSLocalizedString(itemIdentifier, Localized)];

	[[NSUserDefaults standardUserDefaults] setObject:itemIdentifier forKey:@"KWSavedPrefView"];
}

- (id)myViewWithIdentifier:(NSString *)identifier
{
	if ([identifier isEqualTo:@"General"])
		return generalView;
	else if ([identifier isEqualTo:@"Burner"])
		return burnerView;
	else if ([identifier isEqualTo:@"Data"])
		return dataView;
	else if ([identifier isEqualTo:@"Audio"])
		return audioView;
	else if ([identifier isEqualTo:@"Video"])
		return videoView;
	else if ([identifier isEqualTo:@"Advanced"])
		return advancedView;
	
	return nil;
}

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag
{
	return [self createToolbarItemWithName:itemIdentifier];
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar
{
	return [NSArray arrayWithObjects:NSToolbarSeparatorItemIdentifier, NSToolbarSpaceItemIdentifier, NSToolbarFlexibleSpaceItemIdentifier, @"General",@"Burner",@"Data",@"Audio",@"Video",@"Advanced", nil];
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar
{
	return [NSArray arrayWithObjects:@"General",@"Burner",@"Data",@"Audio",@"Video",@"Advanced", nil];
}

///////////////////
// Other actions //
///////////////////

#pragma mark -
#pragma mark •• Other actions

- (void)mediaChanged:(NSNotification *)notification
{
	[KWCommonMethods setupBurnerPopup:burnerPopup];
}

- (void)resizeWindowOnSpotWithRect:(NSRect)aRect
{
    NSRect r = NSMakeRect([[self window] frame].origin.x - 
        (aRect.size.width - [[self window] frame].size.width), [[self window] frame].origin.y - 
        (aRect.size.height+78 - [[self window] frame].size.height), aRect.size.width, aRect.size.height+78);
    [[self window] setFrame:r display:YES animate:YES];
}

/* -----------------------------------------------------------------------------
	toolbarSelectableItemIdentifiers:
		Make sure all our custom items can be selected. NSToolbar will
		automagically select the appropriate item when it is clicked.
   -------------------------------------------------------------------------- */

#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_3
-(NSArray*) toolbarSelectableItemIdentifiers: (NSToolbar*)toolbar
{
	return [itemsList allKeys];
}
#endif

- (void)settingsChangedByOptionsMenuInMainWindow
{
	[self setViewOptions:[NSArray arrayWithObjects:dataView,audioView,videoView,nil]];
}

- (void)addThemeAndShow:(NSArray *)files
{
	[self toolbarAction:@"Video"];
	[videoTab selectTabViewItemAtIndex:1];

	NSString *burnASFolder = @"~/Library/Application Support/Burn";
	burnASFolder = [burnASFolder stringByExpandingTildeInPath];
	NSString *userThemefolder = [burnASFolder stringByAppendingPathComponent:@"Themes"];

	BOOL succes = NO;
	NSString *string;

	if ([KWCommonMethods createDirectoryAtPath:burnASFolder errorString:&string])
		succes = ([KWCommonMethods createDirectoryAtPath:userThemefolder errorString:&string]);
	
	if (succes)
	{
		NSInteger i = 0;
		for (i=0;i<[files count];i++)
		{
			NSString *oldFile = [files objectAtIndex:i];
			NSString *newFile = [KWCommonMethods uniquePathNameFromPath:[userThemefolder stringByAppendingPathComponent:[oldFile lastPathComponent]]];
		
			if ([KWCommonMethods copyItemAtPath:oldFile toPath:newFile errorString:&string])
			{
				if ([themePopup indexOfItem:[NSMenuItem separatorItem]] == -1)
				{
					[themePaths addObject:@"Seperator"];
					[[themePopup menu] addItem:[NSMenuItem separatorItem]];
				}
			
				NSBundle *themeBundle = [NSBundle bundleWithPath:newFile];
				NSDictionary *theme = [[NSArray arrayWithContentsOfFile:[themeBundle pathForResource:@"Theme" ofType:@"plist"]] objectAtIndex:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDVDThemeFormat"] intValue]];
	
				[themePaths addObject:newFile];
				[themePopup addItemWithTitle:[theme objectForKey:@"KWThemeTitle"]];
			}
			else
			{
				succes = NO;
			}
		}
	}
	
	if (succes)
	{
		[themePopup selectItemAtIndex:[themePopup numberOfItems] - 1];
		[self setTheme:themePopup];
	}
	else
	{
		[KWCommonMethods standardAlertWithMessageText:NSLocalizedString(@"Failed to install theme in the 'Application Support' folder",nil) withInformationText:string withParentWindow:[self window]];
	}

}

- (void)setViewOptions:(NSArray *)views
{
	NSEnumerator *iter = [[[NSEnumerator alloc] init] autorelease];
	NSControl *cntl;

	NSInteger x;
	for (x=0;x<[views count];x++)
	{
		NSView *currentView;
	
		if ([[views objectAtIndex:x] isKindOfClass:[NSView class]])
			currentView = [views objectAtIndex:x];
		else
			currentView = [[views objectAtIndex:x] view];
		
		iter = [[currentView subviews] objectEnumerator];
		while ((cntl = [iter nextObject]) != NULL)
		{
			if ([cntl isKindOfClass:[NSTabView class]])
			[self setViewOptions:[(NSTabView *)cntl tabViewItems]];
		
			NSInteger index = [cntl tag] - 1;
			id property = nil;
		
			if (index > -1 && index < 54)
				property = [[NSUserDefaults standardUserDefaults] objectForKey:[preferenceMappings objectAtIndex:index]];
		
			if (property)
				[cntl setObjectValue:property];
			
			if ([cntl isKindOfClass:[NSButton class]])
				[self checkForExceptions:(NSButton *)cntl];
			
			property = nil;
		}
	}
}

- (void)checkForExceptions:(NSButton *)button
{
	NSInteger tag = [button tag];
	NSInteger state;
		
	if ([button respondsToSelector:@selector(state)])
		state = [button state];
	
	NSView *superView = [button superview];
	NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
	
	if (tag == 18 && [KWCommonMethods OSVersion] < 0x1040)
		[button setHidden:YES];

	if (tag == 26 | tag == 28 | tag == 38 | tag == 40 | tag == 42 | tag == 45 | tag == 52)
	{
		[[superView viewWithTag:tag + 1] setEnabled:(state == NSOnState)];
		
		if (tag == 42)
			[[superView viewWithTag:tag + 2] setEnabled:(state == NSOnState)];
	}
	
	if (tag == 35)
	{
		[themePopup setEnabled:(state == NSOnState)];
		[[superView viewWithTag:100] setEnabled:(state == NSOnState)];
		[[superView viewWithTag:101] setEnabled:(state == NSOnState)];
		[[superView viewWithTag:36] setEnabled:(state == NSOnState)];
		[[superView viewWithTag:102] setEnabled:(state == NSOnState)];
	}
	
	if (tag == 3)
	{
		[[dataView viewWithTag:11] setHidden:(state == NSOnState)];
		[[dataView viewWithTag:99] setHidden:(state == NSOnState)];

		if (state == NSOnState)
		{
			if (savedAudioItem == nil)
				savedAudioItem = [audioTabGeneral retain];
		
			[audioTab removeTabViewItem:[audioTab tabViewItemAtIndex:0]];
		}
		else
		{
			if (savedAudioItem)
			{
				[audioTab insertTabViewItem:savedAudioItem atIndex:0];
				[audioTab selectFirstTabViewItem:self];
			}
		}

		[[videoView viewWithTag:24] setHidden:(state == NSOnState)];
		[[videoView viewWithTag:99] setHidden:(state == NSOnState)];

		NSInteger height;

		if (state == NSOnState)
			height = dataViewHeight - 26;
		else
			height = dataViewHeight;
		
		NSRect dataViewFrame = [dataView frame];
		[dataView setFrame:NSMakeRect(dataViewFrame.origin.x,dataViewFrame.origin.y,dataViewFrame.size.width,height)];

		if (state == NSOnState)
		{
			[[NSUserDefaults standardUserDefaults] synchronize];
			[defaultCenter postNotificationName:@"KWTogglePopups" object:nil];
		}
		else
		{
			[self setPreferenceOption:[dataView viewWithTag:11]];
			[self setPreferenceOption:[audioView viewWithTag:16]];
			[self setPreferenceOption:[videoView viewWithTag:24]];
		}
	}
	
	if (tag == 4)
		[[generalView viewWithTag:5] setEnabled:([[button objectValue] intValue] != 2)];
	
	if (tag == 7 | tag == 8 | tag == 9 | tag == 10)
		[defaultCenter postNotificationName:@"KWMediaChanged" object:nil];
}

@end