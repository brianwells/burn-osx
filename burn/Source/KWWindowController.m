//
//  KWMainWindowController.m
//  Burn
//
//  Created by Maarten Foukhar on 08-10-09.
//  Copyright 2009 Kiwi Fruitware. All rights reserved.
//

#import "KWWindowController.h"
#import "KWCommonMethods.h"
#import "KWToolbarKiller.h"
#import "KWTabViewItem.h"

@implementation KWWindowController

- (id)init
{
	self = [super init];

	return self;
}

- (void)dealloc 
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	DRNotificationCenter *burnNotificationCenter = [DRNotificationCenter currentRunLoopCenter];
	[burnNotificationCenter removeObserver:self name:DRDeviceDisappearedNotification object:nil];
	[burnNotificationCenter removeObserver:self name:DRDeviceAppearedNotification object:nil];
	[burnNotificationCenter removeObserver:self name:DRDeviceStatusChangedNotification object:nil];

	[super dealloc];
}

- (void)awakeFromNib
{
	DRDevice *currentDevice = [KWCommonMethods getCurrentDevice];

	if ([[DRDevice devices] count] > 0)
	{
		discInserted = ([[[currentDevice status] objectForKey:DRDeviceMediaStateKey] isEqualTo:DRDeviceMediaStateMediaPresent]);
	}

	//Notifications
	DRNotificationCenter *burnNotificationCenter = [DRNotificationCenter currentRunLoopCenter];
	[burnNotificationCenter addObserver:self selector:@selector(mediaChanged:) name:DRDeviceDisappearedNotification object:nil];
	[burnNotificationCenter addObserver:self selector:@selector(mediaChanged:) name:DRDeviceAppearedNotification object:nil];
	[burnNotificationCenter addObserver:self selector:@selector(mediaChanged:) name:DRDeviceStatusChangedNotification object:nil];
	
	NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
	[defaultCenter addObserver:self selector:@selector(mediaChanged:) name:@"KWMediaChanged" object:nil];
	[defaultCenter addObserver:self selector:@selector(changeBurnStatus:) name:@"KWChangeBurnStatus" object:nil];
	[defaultCenter addObserver:self selector:@selector(closeWindow:) name:NSWindowWillCloseNotification object:nil];

	[defaultBurner setStringValue:[self getRecorderDisplayNameForDevice:currentDevice]];
	
	NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
	
	if ([standardUserDefaults boolForKey:@"KWRememberLastTab"])
	[mainTabView selectTabViewItemWithIdentifier:[standardUserDefaults objectForKey:@"KWLastTab"]];

	[self setupToolbar];

	if ([standardUserDefaults boolForKey:@"KWFirstRun"])
	{
		[self returnToDefaultSizeWindow:self];
		[mainWindow setFrameOrigin:NSMakePoint(36,[[NSScreen mainScreen] frame].size.height - [mainWindow frame].size.height - 56)];
	}
}

/////////////////////////
// Main window actions //
/////////////////////////

#pragma mark -
#pragma mark •• Main window actions

- (IBAction)changeRecorder:(id)sender
{
	NSArray *devices = [DRDevice devices];
	
	if ([devices count] > 1)
	{
		int x = 0;

		int i;
		for (i=0;i< [devices count];i++)
		{
			if ([[[devices objectAtIndex:i] displayName] isEqualTo:[[[defaultBurner stringValue] componentsSeparatedByString:@"\n"] objectAtIndex:0]])
				x = i + 1;
		}
			
		if (x > [devices count]-1)
			x = 0;

		NSMutableDictionary *burnDict = [NSMutableDictionary dictionary];
		NSDictionary *deviceInfo = [[devices objectAtIndex:x] info];
	
		[burnDict setObject:[deviceInfo objectForKey:@"DRDeviceProductNameKey"] forKey:@"Product"];
		[burnDict setObject:[deviceInfo objectForKey:@"DRDeviceVendorNameKey"] forKey:@"Vendor"];
		[burnDict setObject:@"" forKey:@"SerialNumber"];
	
		[[NSUserDefaults standardUserDefaults] setObject:burnDict forKey:@"KWDefaultDeviceIdentifier"];
	
		[[NSNotificationCenter defaultCenter] postNotificationName:@"KWMediaChanged" object:nil];
	}
}

- (IBAction)showItemHelp:(id)sender
{
	NSDictionary *bundleInfo = [[NSBundle bundleForClass:[self class]] infoDictionary];
	NSString *bundleIdent = [bundleInfo objectForKey:@"CFBundleIdentifier"];
	CFBundleRef mainBundle = CFBundleGetBundleWithIdentifier((CFStringRef)bundleIdent);
	
	if (mainBundle)
	{
		CFURLRef bundleURL = NULL;
		CFRetain(mainBundle);
		bundleURL = CFBundleCopyBundleURL(mainBundle);
		if (bundleURL)
		{
			FSRef bundleFSRef;
		
			if (CFURLGetFSRef(bundleURL, &bundleFSRef))
				AHRegisterHelpBook(&bundleFSRef);
		
			CFRelease(bundleURL);
		}
		
		CFRelease(mainBundle);
	}
	
	CFBundleRef myApplicationBundle = CFBundleGetMainBundle();
	CFTypeRef myBookName = CFBundleGetValueForInfoDictionaryKey(myApplicationBundle,CFSTR("CFBundleHelpBookName"));
 
	if ([[itemHelp title] isEqualTo:[NSString stringWithFormat:NSLocalizedString(@"%@ Help", nil), NSLocalizedString(@"Data", nil)]])
		AHLookupAnchor(myBookName, CFSTR("data"));
	else if ([[itemHelp title] isEqualTo:[NSString stringWithFormat:NSLocalizedString(@"%@ Help", nil), NSLocalizedString(@"Audio", nil)]])
		AHLookupAnchor(myBookName, CFSTR("audio"));
	else if ([[itemHelp title] isEqualTo:[NSString stringWithFormat:NSLocalizedString(@"%@ Help", nil), NSLocalizedString(@"Video", nil)]])
		AHLookupAnchor(myBookName, CFSTR("video"));
	else if ([[itemHelp title] isEqualTo:[NSString stringWithFormat:NSLocalizedString(@"%@ Help", nil), NSLocalizedString(@"Copy", nil)]])
		AHLookupAnchor(myBookName, CFSTR("copy"));
}

- (IBAction)newTabViewAction:(id)sender
{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWChangeInspector" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"KWEmpty",@"Type",nil]];
	[mainTabView selectTabViewItemAtIndex:[newTabView selectedSegment]];
}

//////////////////
// Menu actions //
//////////////////

#pragma mark -
#pragma mark •• Menu actions

//File menu

#pragma mark -
#pragma mark •• - File menu

- (IBAction)openFile:(id)sender
{
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	[openPanel setAllowsMultipleSelection:NO];

	NSMutableArray *fileTypes = [NSMutableArray array];

	[fileTypes addObject:@"burn"];
	[fileTypes addObjectsFromArray:[KWCommonMethods diskImageTypes]];

	[openPanel beginSheetForDirectory:nil file:nil types:fileTypes modalForWindow:mainWindow modalDelegate:self didEndSelector:@selector(burnOpenPanelDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

- (void)burnOpenPanelDidEnd:(NSOpenPanel *)openPanel returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[openPanel orderOut:self];

	if (returnCode == NSOKButton)
		[self open:[openPanel filename]];
}

//Recorder menu

#pragma mark -
#pragma mark •• - Recorder menu

- (IBAction)eraseRecorder:(id)sender
{
	eraser = [[KWEraser alloc] init];
	[eraser beginEraseSheetForWindow:mainWindow modalDelegate:self didEndSelector:@selector(eraseSetupEnded:returnCode:)];
}

- (void)eraseSetupEnded:(KWEraser *)eraseSetupSheet returnCode:(int)returnCode
{
	if (returnCode == NSOKButton)
	{
		progressPanel = [[KWProgress alloc] init];
		[progressPanel setIcon:[NSImage imageNamed:@"Burn"]];
		[progressPanel setTask:NSLocalizedString(@"Erasing disc", Localized)];
		[progressPanel setStatus:NSLocalizedString(@"Preparing...", Localized)];
		[progressPanel setMaximumValue:[NSNumber numberWithDouble:0]];
		[progressPanel setCanCancel:NO];
		[progressPanel beginSheetForWindow:mainWindow];
	
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(eraseFinished:) name:@"KWEraseFinished" object:nil];
		[eraser erase];
	}
	else
	{
		[eraser release];
	}
}

- (void)eraseFinished:(NSNotification *)notif
{
	NSString *returnCode = [[notif userInfo] objectForKey:@"ReturnCode"];

	[progressPanel endSheet];
	[progressPanel release];
	[eraser release];
	eraser = nil;

	if ([returnCode isEqualTo:@"KWFailure"])
	{
		[[NSNotificationCenter defaultCenter] postNotificationName:@"growlFailedErasing" object:NSLocalizedString(@"There was a problem erasing the disc",nil)];
	
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle:NSLocalizedString(@"OK",nil)];
		[alert setMessageText:NSLocalizedString(@"Erasing failed",nil)];
		[alert setInformativeText:NSLocalizedString(@"There was a problem erasing the disc",nil)];
		[alert setAlertStyle:NSWarningAlertStyle];
	
		[alert beginSheetModalForWindow:mainWindow modalDelegate:self didEndSelector:nil contextInfo:nil];
	}
	else
	{
		[[NSNotificationCenter defaultCenter] postNotificationName:@"growlFinishedErasing" object:NSLocalizedString(@"The disc has been succesfully erased",nil)];
	}
}

- (IBAction)ejectRecorder:(id)sender
{
	if ([[DRDevice devices] count] > 1)
	{
		if (ejecter == nil)
			ejecter = [[KWEjecter alloc] init];

		[ejecter startEjectSheetForWindow:mainWindow forDevice:[KWCommonMethods getCurrentDevice]];
	}
	else
	{
		[[[DRDevice devices] objectAtIndex:0] ejectMedia];
	}
}

//Window menu

#pragma mark -
#pragma mark •• - Window menu

- (IBAction)returnToDefaultSizeWindow:(id)sender
{
	[mainWindow setFrame:NSMakeRect([mainWindow frame].origin.x , [mainWindow frame].origin.y - ([[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultWindowHeight"] intValue] - [mainWindow frame].size.height), [[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultWindowWidth"] intValue], [[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultWindowHeight"] intValue]) display:YES];
}

//////////////////////////
// Notification actions //
/////////////////////////

#pragma mark -
#pragma mark •• Notification actions

- (void)closeWindow:(NSNotification *)notification
{
	if ([notification object] == mainWindow)
	{
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
		if ([defaults boolForKey:@"KWRememberLastTab"] == YES)
			[defaults setObject:[[mainTabView selectedTabViewItem] identifier] forKey:@"KWLastTab"];
			
		[defaults synchronize];
	
		[NSApp terminate:self];
	}
}

- (void)changeBurnStatus:(NSNotification *)notification
{
	[burnButton setEnabled:([[notification object] boolValue])];
	[defaultBurner setStringValue:[self getRecorderDisplayNameForDevice:[KWCommonMethods getCurrentDevice]]];
}

- (void)mediaChanged:(NSNotification *)notification
{
	[defaultBurner setStringValue:[self getRecorderDisplayNameForDevice:[KWCommonMethods getCurrentDevice]]];
}

/////////////////////
// Toolbar actions //
/////////////////////

#pragma mark -
#pragma mark •• Toolbar actions

- (void)setupToolbar
{
	if ([KWCommonMethods OSVersion] >= 0x1040)
	{
		#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_4
		//First setup accessibility support since it can't be done from interface builder
		id segmentElement = NSAccessibilityUnignoredDescendant(newTabView);
		NSArray *segments = [segmentElement accessibilityAttributeValue:NSAccessibilityChildrenAttribute];
    
    
		id segment;
		NSArray *descriptions = [NSArray arrayWithObjects:@"Select to create a data disc",@"Select to create a audio disc",@"Select to create a video disc",@"Select to copy a disc or disk image",nil];
		NSEnumerator *e = [segments objectEnumerator];
			
		int i = 0;
		while ((segment = [e nextObject])) 
		{
			[segment accessibilitySetOverrideValue:[descriptions objectAtIndex:i] forAttribute:NSAccessibilityHelpAttribute];
			[segment accessibilitySetOverrideValue:[descriptions objectAtIndex:i] forAttribute:NSAccessibilityHelpAttribute];
			i = i + 1;
		}
		#endif
	}

	mainItem = [[[NSToolbarItem alloc] initWithItemIdentifier:@"Main"] autorelease];
    [mainItem setView:newTabView];
	[mainItem setMinSize:NSMakeSize([newTabView frame].size.width,28)];
	
	//Some things don't work in Panther, so doing a trick to hide the toolbarbutton
	if ([KWCommonMethods OSVersion] < 0x1040)
		[KWToolbarKiller poseAsClass:NSClassFromString(@"_NSThemeWidget")];
	
    toolbar = [[[NSToolbar alloc] initWithIdentifier:@"mainToolbar"] autorelease];
    [toolbar setDelegate:self];
    [toolbar setAllowsUserCustomization:NO];
    [toolbar setAutosavesConfiguration:NO];
	[toolbar setDisplayMode:NSToolbarDisplayModeIconOnly];
    [mainWindow setToolbar:toolbar];
	
	#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_4
	if ([KWCommonMethods OSVersion] >= 0x1040)
		[mainWindow setShowsToolbarButton:NO];
	#endif
}

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag
{
	NSToolbarItem *item = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
	
	if ([itemIdentifier isEqualToString:@"Main"])
		return mainItem;
	
	return item;
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar
{
	return [NSArray arrayWithObjects:NSToolbarSeparatorItemIdentifier, NSToolbarSpaceItemIdentifier, NSToolbarFlexibleSpaceItemIdentifier, @"Main", nil];
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar
{
	return [NSArray arrayWithObjects:NSToolbarFlexibleSpaceItemIdentifier,@"Main",NSToolbarFlexibleSpaceItemIdentifier, nil];
}

///////////////////
// Other actions //
///////////////////

#pragma mark -
#pragma mark •• Other actions

- (NSString *)getRecorderDisplayNameForDevice:(DRDevice *)device
{
	if (device)
	{
		float space;
	
		if ([[[device status] objectForKey:DRDeviceMediaStateKey] isEqualTo:DRDeviceMediaStateMediaPresent])
		{
			NSDictionary *mediaInfo = [[device status] objectForKey:DRDeviceMediaInfoKey];
		
			if ([[mediaInfo objectForKey:DRDeviceMediaIsBlankKey] boolValue] | [[NSUserDefaults standardUserDefaults] boolForKey:@"KWShowOverwritableSpace"] == NO)
				space = [[mediaInfo objectForKey:DRDeviceMediaFreeSpaceKey] floatValue] * 2048 / 1024 / 2;
			else if ([[mediaInfo objectForKey:DRDeviceMediaClassKey] isEqualTo:DRDeviceMediaClassDVD])
				space = [[mediaInfo objectForKey:DRDeviceMediaOverwritableSpaceKey] floatValue] * 2048 / 1024 / 2;
			else
				space = [KWCommonMethods defaultSizeForMedia:@"KWDefaultCDMedia"];
		}
		else
		{
			int media = [[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultMedia"] intValue];
		
			if (media == 1)
				space = [KWCommonMethods defaultSizeForMedia:@"KWDefaultCDMedia"];
			else if (media == 2)
				space = [KWCommonMethods defaultSizeForMedia:@"KWDefaultDVDMedia"];
			else
				space = -1;
		}
		
		if ([[[device status] objectForKey:DRDeviceMediaStateKey] isEqualTo:DRDeviceMediaStateInTransition] | space == -1)
		{
			return [NSString stringWithFormat:@"%@\n%@", [device displayName], NSLocalizedString(@"No disc",nil)];
		}
		else
		{
			NSString *percent;
			KWTabViewItem *tabViewItem = (KWTabViewItem *)[mainTabView selectedTabViewItem];
			id controller = [tabViewItem myController];
			float totalSize = [[controller performSelector:@selector(totalSize)] floatValue];
		
			if (space > 0)
				percent = [NSString stringWithFormat: @"(%.0f%@)", totalSize / space * 100, @"%"];
			else
				percent = @"";
				
			return [NSString stringWithFormat:@"%@\n%@ %@", [device displayName], [NSString stringWithFormat:NSLocalizedString(@"%@ free", nil), [KWCommonMethods makeSizeFromFloat:space * 2048]], percent];
		}
	}
	else
	{
		return NSLocalizedString(@"No Recorder",nil);
	}
}

- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename
{
	[self open:filename];
	
	return YES;
}

- (void)open:(NSString *)pathname
{
	SEL aSelector;
	id object = nil;

	if ([[KWCommonMethods diskImageTypes] containsObject:[[pathname pathExtension] lowercaseString]] | [[[NSWorkspace sharedWorkspace] mountedLocalVolumePaths] containsObject:pathname])
	{
		[mainTabView selectTabViewItemWithIdentifier:@"Copy"];
		
		aSelector = @selector(checkImage:);
		object = pathname;
	}
	else if ([[[pathname pathExtension] lowercaseString] isEqualTo:@"burn"])
	{
		NSDictionary *burnFile = [NSDictionary dictionaryWithContentsOfFile:pathname];
		
		if (burnFile)
		{
			[mainTabView selectTabViewItemAtIndex:[[burnFile objectForKey:@"KWType"] intValue]];

			aSelector = @selector(openBurnDocument:);
			object = pathname;
		}
		else 
		{
			[KWCommonMethods standardAlertWithMessageText:NSLocalizedString(@"Invalid Burn file", nil) withInformationText:NSLocalizedString(@"The Burn file is corrupt or a wrong filetype", nil) withParentWindow:mainWindow];
		}
	}
	else if ([[[pathname pathExtension] lowercaseString] isEqualTo:@"burntheme"])
	{
		[[NSNotificationCenter defaultCenter] postNotificationName:@"KWDVDThemeOpened" object:[NSArray arrayWithObjects:pathname,nil]];
	}
	else
	{
		[mainTabView selectTabViewItemWithIdentifier:@"Data"];
		
		aSelector = @selector(addDroppedOnIconFiles:);
		object = [NSArray arrayWithObject:pathname];
	}
	
	if (object)
	{
		KWTabViewItem *tabViewItem = (KWTabViewItem *)[mainTabView selectedTabViewItem];
		id controller = [tabViewItem myController];
		
		[controller performSelector:aSelector withObject:[object copy]];
	}
}

- (void)tabView:(NSTabView *)aTabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
	int segment = [aTabView indexOfTabViewItem:[aTabView selectedTabViewItem]];
	[newTabView setSelectedSegment:segment];
	
	id controller = [(KWTabViewItem *)[aTabView selectedTabViewItem] myController];
	
	[itemHelp setTitle:[NSString stringWithFormat:NSLocalizedString(@"%@ Help", nil), [newTabView labelForSegment:segment]]];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWChangeBurnStatus" object:[NSNumber numberWithBool:([controller numberOfRows] > 0)]];
}

- (BOOL)respondsToSelector:(SEL)aSelector
{
	if ([mainWindow attachedSheet] && aSelector != @selector(showItemHelp:))
		return NO;

	return [super respondsToSelector:aSelector];
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)theApplication
{
	NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];

	if ([[standardDefaults objectForKey:@"KWCleanTemporaryFolderAction"] intValue] == 1 && [[standardDefaults objectForKey:@"KWTemporaryLocationPopup"] intValue] != 2)
	{
		NSString *temporaryLocation = [standardDefaults objectForKey:@"KWTemporaryLocation"];
		NSFileManager *defaultManager = [NSFileManager defaultManager];
		NSArray *files = [defaultManager directoryContentsAtPath:temporaryLocation];
	
		int i;
		for (i=0;i<[files count];i++)
		{
			NSString *path = [files objectAtIndex:i];
		
			if (![path isEqualTo:@".localized"] && ![path isEqualTo:@"Icon\r"])
				[KWCommonMethods removeItemAtPath:[temporaryLocation stringByAppendingPathComponent:path]];
		}
	}
	
	if ([standardDefaults boolForKey:@"KWFirstRun"] == YES)
		[standardDefaults setObject:[NSNumber numberWithBool:NO] forKey:@"KWFirstRun"];
	return YES;
}

@end
