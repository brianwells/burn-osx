#import "KWPreferences.h"
#import <DiscRecording/DiscRecording.h>
#import "KWCommonMethods.h"
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
	//Hide CD-Text since it's not supported on Panther
	if ([KWCommonMethods isPanther])
	[[audioView viewWithTag:16] setHidden:YES];

dataViewHeight = [dataView frame].size.height;

[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(settingsChangedByOptionsMenuInMainWindow) name:@"KWOptionsChanged" object:nil];

//Load the custom options
//General
NSString *defaultPath = [[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"] stringByAppendingPathComponent:@"Burn Temporary.localized"];
NSString *tempPath = [@"/tmp" stringByAppendingPathComponent:@"Burn Temporary.localized"];

	if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"KWTemporaryLocation"] isEqualTo:defaultPath])
	{
		if (![[NSFileManager defaultManager] fileExistsAtPath:defaultPath])
		{
		//Create the temporary folder
		[[NSFileManager defaultManager] createDirectoryAtPath:tempPath attributes:nil];
		[[NSFileManager defaultManager] createDirectoryAtPath:[tempPath stringByAppendingPathComponent:@".localized"] attributes:nil];
		
		//Get the folders in Burn.app/Contents/Resources
		NSArray *resourceFolders = [[NSBundle mainBundle] localizations];
		
			int y;
			for (y=0;y<[resourceFolders count];y++)
			{
			//Create a localized dictionary file
			NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:[[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:[[resourceFolders objectAtIndex:y] stringByAppendingPathExtension:@"lproj"]] stringByAppendingPathComponent:@"Localizable.strings"]];
			NSDictionary *localizedDict = [NSDictionary dictionaryWithObject:[dict objectForKey:@"Burn Temporary"] forKey:@"Burn Temporary"];
			NSString *localizedStringsFile = [[[resourceFolders objectAtIndex:y] stringByDeletingPathExtension] stringByAppendingPathExtension:@"strings"];
			[localizedDict writeToFile:[[tempPath stringByAppendingPathComponent:@".localized"] stringByAppendingPathComponent:localizedStringsFile] atomically:YES];
			}
		}
		
	[[NSFileManager defaultManager] movePath:tempPath toPath:defaultPath handler:nil];
	}

NSString *temporaryFolder = [[NSUserDefaults standardUserDefaults] objectForKey:@"KWTemporaryLocation"];
[temporaryFolderPopup insertItemWithTitle:[[NSFileManager defaultManager] displayNameAtPath:temporaryFolder] atIndex:0];
NSImage *folderImage = [[NSWorkspace sharedWorkspace] iconForFile:temporaryFolder];
[folderImage setSize:NSMakeSize(16,16)];
[[temporaryFolderPopup itemAtIndex:0] setImage:folderImage];
[[temporaryFolderPopup itemAtIndex:0] setToolTip:[[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWTemporaryLocation"] stringByDeletingLastPathComponent] stringByAppendingPathComponent:[[NSFileManager defaultManager] displayNameAtPath:[[NSUserDefaults standardUserDefaults] objectForKey:@"KWTemporaryLocation"]]]];
		
//Burner
[KWCommonMethods setupBurnerPopup:burnerPopup];
		
[[[completionActionMatrix cells] objectAtIndex:0] setObjectValue:[NSNumber numberWithBool:(![[[NSUserDefaults standardUserDefaults] objectForKey:@"KWBurnOptionsCompletionAction"] isEqualTo:@"DRBurnCompletionActionMount"])]];
[[[completionActionMatrix cells] objectAtIndex:1] setObjectValue:[NSNumber numberWithBool:([[[NSUserDefaults standardUserDefaults] objectForKey:@"KWBurnOptionsCompletionAction"] isEqualTo:@"DRBurnCompletionActionMount"])]];
	
//Video
[themePopup removeAllItems];

NSString *defaultThemePath = [[[NSBundle mainBundle] pathForResource:@"Themes" ofType:nil] stringByAppendingPathComponent:@"Default.burnTheme"];
NSBundle *themeBundle = [NSBundle bundleWithPath:defaultThemePath];
NSDictionary *theme = [[NSArray arrayWithContentsOfFile:[themeBundle pathForResource:@"Theme" ofType:@"plist"]] objectAtIndex:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDVDThemeFormat"] intValue]];
		
[themePopup addItemWithTitle:[theme objectForKey:@"KWThemeTitle"]];
		
	NSArray *mightBeThemes = [[NSFileManager defaultManager] directoryContentsAtPath:[[NSBundle mainBundle] pathForResource:@"Themes" ofType:@""]];
	int y;
	for (y=0;y<[mightBeThemes count];y++)
	{
		if (![[mightBeThemes objectAtIndex:y] isEqualTo:@"Default.burnTheme"])
		{
			if ([[[mightBeThemes objectAtIndex:y] pathExtension] isEqualTo:@"burnTheme"])
			{
			NSBundle *themeBundle = [NSBundle bundleWithPath:[[[NSBundle mainBundle] pathForResource:@"Themes" ofType:@""] stringByAppendingPathComponent:[mightBeThemes objectAtIndex:y]]];
			NSDictionary *theme = [[NSArray arrayWithContentsOfFile:[themeBundle pathForResource:@"Theme" ofType:@"plist"]] objectAtIndex:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDVDThemeFormat"] intValue]];
		
			[themePopup addItemWithTitle:[theme objectForKey:@"KWThemeTitle"]];
			}
		}
	}
		
[themePopup selectItemAtIndex:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDVDTheme"] intValue]];
	
//Load the options for our views
[self setViewOptions:[NSArray arrayWithObjects:generalView, burnerView, dataView, audioView, videoView, advancedView, nil]];

[self setupToolbar];
[toolbar setSelectedItemIdentifier:[[NSUserDefaults standardUserDefaults] objectForKey:@"KWSavedPrefView"]];
[self toolbarAction:[toolbar selectedItemIdentifier]];
	
[[DRNotificationCenter currentRunLoopCenter] addObserver:self selector:@selector(mediaChanged:) name:DRDeviceDisappearedNotification object:nil];
[[DRNotificationCenter currentRunLoopCenter] addObserver:self selector:@selector(mediaChanged:) name:DRDeviceAppearedNotification object:nil];
[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mediaChanged:) name:@"KWMediaChanged" object:nil];

[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(saveFrame) name:NSWindowWillCloseNotification object:nil];

[[self window] setFrameUsingName:@"Preferences"];

	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWFirstRun"] == YES)
	[[self window] setFrameOrigin:NSMakePoint(500,[[NSScreen mainScreen] frame].size.height - [[self window] frame].size.height - 54)];
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
	if ([sender tag] == 4)
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
		[[NSUserDefaults standardUserDefaults] setObject:[sender objectValue] forKey:[preferenceMappings objectAtIndex:[sender tag] - 1]];
		}
	}
	else
	{
	[[NSUserDefaults standardUserDefaults] setObject:[sender objectValue] forKey:[preferenceMappings objectAtIndex:[sender tag] - 1]];
	}
	
	//Reload the data list
	if ([sender tag] == 12 | [sender tag] == 13 | [sender tag] == 14)
	{
	[[NSUserDefaults standardUserDefaults] synchronize];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWReloadRequested" object:nil];
	}
	else if ([sender tag] == 15) //Calculate total size
	{
	[[NSUserDefaults standardUserDefaults] synchronize];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWTogglePopups" object:nil];
	}
	
	if ([sender tag] == 36)
	{
	[self setPreviewImage:self];
	}
	
[self checkForExceptions:sender];
}

//General

#pragma mark -
#pragma mark •• - General

- (void)temporaryOpenPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
[sheet orderOut:self];

	if (returnCode == NSOKButton)
	{
	[temporaryFolderPopup removeItemAtIndex:0];
	NSString *temporaryFolder = [sheet filename];
	[temporaryFolderPopup insertItemWithTitle:[[NSFileManager defaultManager] displayNameAtPath:temporaryFolder] atIndex:0];
	NSImage *folderImage = [[NSWorkspace sharedWorkspace] iconForFile:temporaryFolder];
	[folderImage setSize:NSMakeSize(16,16)];
	[[temporaryFolderPopup itemAtIndex:0] setImage:folderImage];
	[[temporaryFolderPopup itemAtIndex:0] setToolTip:[[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWTemporaryLocation"] stringByDeletingLastPathComponent] stringByAppendingPathComponent:[[NSFileManager defaultManager] displayNameAtPath:[[NSUserDefaults standardUserDefaults] objectForKey:@"KWTemporaryLocation"]]]];
	[temporaryFolderPopup selectItemAtIndex:0];
	
	[[NSUserDefaults standardUserDefaults] setObject:[sheet filename] forKey:@"KWTemporaryLocation"];
	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInt:0] forKey:@"KWTemporaryLocationPopup"];
	}
	else
	{
	[temporaryFolderPopup selectItemAtIndex:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWTemporaryLocationPopup"] intValue]];
	}
}

//Burner

#pragma mark -
#pragma mark •• - Burner

- (IBAction)setBurner:(id)sender
{
DRDevice *currentDevice = [[DRDevice devices] objectAtIndex:[burnerPopup indexOfSelectedItem]];
NSMutableDictionary *burnDict = [NSMutableDictionary dictionary];

[burnDict setObject:[[currentDevice info] objectForKey:@"DRDeviceProductNameKey"] forKey:@"Product"];
[burnDict setObject:[[currentDevice info] objectForKey:@"DRDeviceVendorNameKey"] forKey:@"Vendor"];
[burnDict setObject:@"" forKey:@"SerialNumber"];

[[NSUserDefaults standardUserDefaults] setObject:burnDict forKey:@"KWDefaultDeviceIdentifier"];
}

- (IBAction)setCompletionAction:(id)sender
{
	if ([[[completionActionMatrix cells] objectAtIndex:0] state] == NSOnState)
	[[NSUserDefaults standardUserDefaults] setObject:@"DRBurnCompletionActionEject" forKey:@"KWBurnOptionsCompletionAction"];
	else
	[[NSUserDefaults standardUserDefaults] setObject:@"DRBurnCompletionActionMount" forKey:@"KWBurnOptionsCompletionAction"];
}

//Video

#pragma mark -
#pragma mark •• - Video

- (IBAction)setTheme:(id)sender
{
[[NSUserDefaults standardUserDefaults] setObject:[sender objectValue] forKey:@"KWDVDTheme"];
[[NSUserDefaults standardUserDefaults] setObject:[self getCurrentThemePath] forKey:@"KWDVDThemePath"];

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

- (void)themeOpenPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
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
	NSString *themePath = [self getCurrentThemePath];
		
		if (themePath)
		{
		[[NSFileManager defaultManager] removeFileAtPath:[self getCurrentThemePath] handler:nil];
		[themePopup removeItemAtIndex:[themePopup indexOfSelectedItem]];
	
		[self setTheme:themePopup];
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
NSString *themePath = [self getCurrentThemePath];

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

- (void)openPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
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

	int i = 0;
	for (i=0;i<[files count];i++)
	{
	NSString *newFile = [KWCommonMethods uniquePathNameFromPath:[[[NSBundle mainBundle] pathForResource:@"Themes" ofType:@""] stringByAppendingPathComponent:[[files objectAtIndex:i] lastPathComponent]] withLength:0];
		
	[[NSFileManager defaultManager] copyPath:[files objectAtIndex:i] toPath:newFile handler:nil];
		
	NSBundle *themeBundle = [NSBundle bundleWithPath:newFile];
	NSDictionary *theme = [[NSArray arrayWithContentsOfFile:[themeBundle pathForResource:@"Theme" ofType:@"plist"]] objectAtIndex:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDVDThemeFormat"] intValue]];

	[themePopup addItemWithTitle:[theme objectForKey:@"KWThemeTitle"]];
	}
		
[themePopup selectItemAtIndex:[themePopup numberOfItems] - 1];
[self setTheme:themePopup];
}

- (void)setViewOptions:(NSArray *)views
{
NSEnumerator *iter = [[[NSEnumerator alloc] init] autorelease];
NSControl *cntl;

	int x;
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
		
		int index = [cntl tag] - 1;
		id property;
		
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
	if ([button tag] == 26 | [button tag] == 28 | [button tag] == 38 | [button tag] == 40 | [button tag] == 42 | [button tag] == 45 | [button tag] == 52)
	{
	[[[button superview] viewWithTag:[button tag] + 1] setEnabled:([button state] == NSOnState)];
		if ([button tag] == 42)
		[[[button superview] viewWithTag:[button tag] + 2] setEnabled:([button state] == NSOnState)];
	}
	
	if ([button tag] == 35)
	{
	[themePopup setEnabled:([button state] == NSOnState)];
	[[[button superview] viewWithTag:100] setEnabled:([button state] == NSOnState)];
	[[[button superview] viewWithTag:101] setEnabled:([button state] == NSOnState)];
	[[[button superview] viewWithTag:36] setEnabled:([button state] == NSOnState)];
	[[[button superview] viewWithTag:102] setEnabled:([button state] == NSOnState)];
	}
	
	if ([button tag] == 3)
	{
	[[dataView viewWithTag:11] setHidden:([button state] == NSOnState)];
	[[dataView viewWithTag:99] setHidden:([button state] == NSOnState)];

		if ([button state] == NSOnState)
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

	[[videoView viewWithTag:24] setHidden:([button state] == NSOnState)];
	[[videoView viewWithTag:99] setHidden:([button state] == NSOnState)];

		int height;

			if ([button state] == NSOnState)
			height = dataViewHeight - 26;
			else
			height = dataViewHeight;

	[dataView setFrame:NSMakeRect([dataView frame].origin.x,[dataView frame].origin.y,[dataView frame].size.width,height)];

		if ([button state] == NSOnState)
		{
		[[NSUserDefaults standardUserDefaults] synchronize];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"KWTogglePopups" object:nil];
		}
		else
		{
		[self setPreferenceOption:[dataView viewWithTag:11]];
		[self setPreferenceOption:[audioView viewWithTag:16]];
		[self setPreferenceOption:[videoView viewWithTag:24]];
		}
	}
	
	if ([button tag] == 4)
	[[generalView viewWithTag:5] setEnabled:([[button objectValue] intValue] != 2)];
	
	if ([button tag] == 7 | [button tag] == 8 | [button tag] == 9 | [button tag] == 10)
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWMediaChanged" object:nil];
}

- (NSString *)getCurrentThemePath
{
NSArray *mightBeThemes = [[NSFileManager defaultManager] directoryContentsAtPath:[[NSBundle mainBundle] pathForResource:@"Themes" ofType:@""]];
	
	int y;
	for (y=0;y<[mightBeThemes count];y++)
	{
		if ([[[mightBeThemes objectAtIndex:y] pathExtension] isEqualTo:@"burnTheme"])
		{
		NSBundle *themeBundle = [NSBundle bundleWithPath:[[[NSBundle mainBundle] pathForResource:@"Themes" ofType:@""] stringByAppendingPathComponent:[mightBeThemes objectAtIndex:y]]];
		NSDictionary *theme = [[NSArray arrayWithContentsOfFile:[themeBundle pathForResource:@"Theme" ofType:@"plist"]] objectAtIndex:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDVDThemeFormat"] intValue]];
		
			if ([[themePopup title] isEqualTo:[theme objectForKey:@"KWThemeTitle"]])
			return [[[NSBundle mainBundle] pathForResource:@"Themes" ofType:@""] stringByAppendingPathComponent:[mightBeThemes objectAtIndex:y]];
		}
	}
	
return nil;
}

@end
