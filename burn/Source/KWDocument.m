#import "KWDocument.h"
#import "appController.h"
#import <Carbon/Carbon.h>
#import "dataController.h"
#import "audioController.h"
#import "videoController.h"
#import "copyController.h"
#import "KWRecorderInfo.h"
#import "KWDiskInfo.h"
#import "KWCommonMethods.h"
#import "KWToolbarKiller.h"

@implementation KWDocument

- (id)init
{
self = [super init];
    
	if (self) 
	{
		if ([NSLocalizedString(@"Burn",@"Localized") isEqualTo:@"Brand"])
		[self setLastComponentOfFileName:NSLocalizedString(@"Burn",@"Localized")];
		else
		[self setLastComponentOfFileName:@"Burn"];
	}

return self;
}

- (void)dealloc 
{
[[NSNotificationCenter defaultCenter] removeObserver:self];

[[DRNotificationCenter currentRunLoopCenter] removeObserver:self name:DRDeviceDisappearedNotification object:nil];
[[DRNotificationCenter currentRunLoopCenter] removeObserver:self name:DRDeviceAppearedNotification object:nil];
[[DRNotificationCenter currentRunLoopCenter] removeObserver:self name:DRDeviceStatusChangedNotification object:nil];

[super dealloc];
}

- (void)awakeFromNib
{	
	if ([[DRDevice devices] count] > 0)
	{
	discInserted = ([[[[KWCommonMethods getCurrentDevice] status] objectForKey:DRDeviceMediaStateKey] isEqualTo:DRDeviceMediaStateMediaPresent]);
	}

//Notifications
[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mediaChanged:) name:@"KWMediaChanged" object:nil];
[[DRNotificationCenter currentRunLoopCenter] addObserver:self selector:@selector(mediaChanged:) name:DRDeviceDisappearedNotification object:nil];
[[DRNotificationCenter currentRunLoopCenter] addObserver:self selector:@selector(mediaChanged:) name:DRDeviceAppearedNotification object:nil];
[[DRNotificationCenter currentRunLoopCenter] addObserver:self selector:@selector(mediaChanged:) name:DRDeviceStatusChangedNotification object:nil];

[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changeBurnStatus:) name:@"KWChangeBurnStatus" object:nil];

[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(closeWindow:) name:NSWindowWillCloseNotification object:nil];

[defaultBurner setStringValue:[self getRecorderDisplayNameForDevice:[KWCommonMethods getCurrentDevice]]];
	
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWRememberLastTab"] == YES)
	{
	[mainTabView selectTabViewItemWithIdentifier:[[NSUserDefaults standardUserDefaults] objectForKey:@"KWLastTab"]];
	}

[self setupToolbar];

	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWFirstRun"] == YES)
	{
	[self returnToDefaultSize:self];
	[mainWindow setFrameOrigin:NSMakePoint(36,[[NSScreen mainScreen] frame].size.height - [mainWindow frame].size.height - 56)];
	}
}

///////////////////////
// NSDocument Actions //
////////////////////////

#pragma mark -
#pragma mark •• NSDocument Actions

- (NSString *)windowNibName
{
return @"KWDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *)aController
{
[super windowControllerDidLoadNib:aController];

[aController setShouldCascadeWindows:([[NSApp orderedDocuments] count] < 1)];
	
[[aController window] setFrameUsingName:NSLocalizedString(@"Burn",@"Localized")];
}

- (NSData *)dataRepresentationOfType:(NSString *)aType
{
return nil;
}

- (BOOL)loadDataRepresentation:(NSData *)data ofType:(NSString *)aType
{
return YES;
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
			{
			x = i + 1;
			}
		}
			
		if (x > [devices count]-1)
		{
		x = 0;
		}

	NSMutableDictionary *burnDict = [[NSMutableDictionary alloc] init];

	[burnDict setObject:[[[devices objectAtIndex:x] info] objectForKey:@"DRDeviceProductNameKey"] forKey:@"Product"];
	[burnDict setObject:[[[devices objectAtIndex:x] info] objectForKey:@"DRDeviceVendorNameKey"] forKey:@"Vendor"];
	[burnDict setObject:@"" forKey:@"SerialNumber"];
	
	[[NSUserDefaults standardUserDefaults] setObject:[burnDict copy] forKey:@"KWDefaultDeviceIdentifier"];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWMediaChanged" object:nil];

	[burnDict release];
	}
}

- (IBAction)showItemHelp:(id)sender
{
[(appController *)[NSApp delegate] itemHelp:self];
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

- (void)openFile:(id)sender
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
	[self openDocument:[openPanel filename]];
}

- (void)saveAsFile:(id)sender
{
[[self currentController] saveDocument];
}

- (void)saveImage:(id)sender
{
[[self currentController] saveImage];
}

//Recorder menu

#pragma mark -
#pragma mark •• - Recorder menu

- (void)eraseRecorder:(id)sender
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
	[[NSNotificationCenter defaultCenter] postNotificationName:@"growlFailedErasing" object:NSLocalizedString(@"There was a problem erasing the disc",@"Localized")];
	
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert addButtonWithTitle:NSLocalizedString(@"OK",@"Localized")];
	[alert setMessageText:NSLocalizedString(@"Erasing failed",@"Localized")];
	[alert setInformativeText:NSLocalizedString(@"There was a problem erasing the disc",@"Localized")];
	[alert setAlertStyle:NSWarningAlertStyle];
	
	[alert beginSheetModalForWindow:mainWindow modalDelegate:self didEndSelector:nil contextInfo:nil];
	}
	else
	{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"growlFinishedErasing" object:NSLocalizedString(@"The disc has been succesfully erased",@"Localized")];
	}
}

- (IBAction)burnRecorder:(id)sender
{
[[self currentController] burn];
}

//Items menu

#pragma mark -
#pragma mark •• - Items menu

- (void)addItems:(id)sender
{
[[self currentController] openFiles:self];
}

- (void)deleteItems:(id)sender
{
[[self currentController] deleteFiles:self];
}

- (void)createFolderItems:(id)sender
{
[dataControllerOutlet newVirtualFolder:self];
}

- (void)mountImageItems:(id)sender
{
[copyControllerOutlet mountImage:self];
}

- (void)scanDiscsItems:(id)sender
{
[copyControllerOutlet scanDisks:self];
}

//Window menu

#pragma mark -
#pragma mark •• - Window menu

- (void)returnToDefaultSize:(id)sender
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
		if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWRememberLastTab"] == YES)
		[[NSUserDefaults standardUserDefaults] setObject:[[mainTabView selectedTabViewItem] identifier] forKey:@"KWLastTab"];
		
	[audioControllerOutlet stop:self];
	}
	
[mainWindow saveFrameUsingName:@"Burn"];
[[NSUserDefaults standardUserDefaults] synchronize];
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

/////////////////////////
// Application actions //
/////////////////////////

#pragma mark -
#pragma mark •• Application actions

- (BOOL)isAudioMP3
{
return [audioControllerOutlet isMp3];
}

- (BOOL)isImageCompatible
{
return [copyControllerOutlet isCompatible];
}

- (BOOL)isImageMounted
{
return [copyControllerOutlet isMounted];
}

- (BOOL)isImageRealDisk
{
return [copyControllerOutlet isRealDisk];
}

- (BOOL)dataHasRows
{
return [dataControllerOutlet hasRows];
}

- (BOOL)audioHasRows
{
return [audioControllerOutlet hasRows];
}

- (BOOL)videoHasRows
{
return [videoControllerOutlet hasRows];
}

- (BOOL)copyHasRows
{
return [copyControllerOutlet hasRows];
}

/////////////////////
// Toolbar actions //
/////////////////////

#pragma mark -
#pragma mark •• Toolbar actions

- (void)setupToolbar
{
	if (![KWCommonMethods isPanther])
	{
	//First setup accessibility support since it can't be done from interface builder
	id segmentElement = NSAccessibilityUnignoredDescendant(tabView);
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
	}

	mainItem = [[[NSToolbarItem alloc] initWithItemIdentifier:@"Main"] autorelease];
    [mainItem setView:tabView];
	[mainItem setMinSize:NSMakeSize([tabView frame].size.width,28)];
	
		//Some things don't work in Panther, so doing a trick to hide the toolbarbutton
		if ([KWCommonMethods isPanther])
		[KWToolbarKiller poseAsClass:NSClassFromString(@"_NSThemeWidget")];
	
    toolbar = [[[NSToolbar alloc] initWithIdentifier:@"mainToolbar"] autorelease];
    [toolbar setDelegate:self];
    [toolbar setAllowsUserCustomization:NO];
    [toolbar setAutosavesConfiguration:NO];
	[toolbar setDisplayMode:NSToolbarDisplayModeIconOnly];
    [mainWindow setToolbar:toolbar];

		if (![KWCommonMethods isPanther])
		[mainWindow setShowsToolbarButton:NO];
}

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag
{
NSToolbarItem *item = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
	
	if ([itemIdentifier isEqualToString:@"Main"])
    {
	return mainItem;
    }
	
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
			if ([[[[device status] objectForKey:DRDeviceMediaInfoKey] objectForKey:DRDeviceMediaIsBlankKey] boolValue] | [[NSUserDefaults standardUserDefaults] boolForKey:@"KWShowOverwritableSpace"] == NO)
			{
			space = [[[[device status] objectForKey:DRDeviceMediaInfoKey] objectForKey:DRDeviceMediaFreeSpaceKey] floatValue] * 2048 / 1024 / 2;
			}
			else if ([[[[device status] objectForKey:DRDeviceMediaInfoKey] objectForKey:DRDeviceMediaClassKey] isEqualTo:DRDeviceMediaClassDVD])
			{
			space = [[[[device status] objectForKey:DRDeviceMediaInfoKey] objectForKey:DRDeviceMediaOverwritableSpaceKey] floatValue] * 2048 / 1024 / 2;
			}
			else
			{
			space = [[DRMSF msfWithString:[[KWCommonMethods defaultSizeForMedia:1] stringByAppendingString:@":00:00"]] intValue];
			}
		}
		else
		{
			if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultMedia"] intValue] == 1)
			space = [[DRMSF msfWithString:[[KWCommonMethods defaultSizeForMedia:1] stringByAppendingString:@":00:00"]] intValue];
			else if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultMedia"] intValue] == 2)
			space = [[KWCommonMethods defaultSizeForMedia:2] intValue] * 1024 / 2;
			else
			space = -1;
		}
		
		if ([[[device status] objectForKey:DRDeviceMediaStateKey] isEqualTo:DRDeviceMediaStateInTransition] | space == -1)
		{
		return [[[device displayName] stringByAppendingString:@"\n"] stringByAppendingString:NSLocalizedString(@"No disc",@"Localized")];
		}
		else
		{
		NSString *percent;
		
			if (space > 0)
			percent = [[NSString localizedStringWithFormat: @" (%.0f", [[self currentController] totalSize] / space * 100] stringByAppendingString:@"%)"];
			else
			percent = @"";
		
		return [[[[[device displayName] stringByAppendingString:@"\n"] stringByAppendingString:[KWCommonMethods makeSizeFromFloat:space * 2048]] stringByAppendingString:NSLocalizedString(@" free",@"Localized")] stringByAppendingString:percent];
		}
	}
	else
	{
	return NSLocalizedString(@"No Recorder",@"Localized");
	}
}

- (void)openDocument:(NSString *)pathname
{
	if ([[KWCommonMethods diskImageTypes] containsObject:[[pathname pathExtension] lowercaseString]] | [[[NSWorkspace sharedWorkspace] mountedLocalVolumePaths] containsObject:pathname])
	{
	[mainTabView selectTabViewItemWithIdentifier:@"Copy"];
	[copyControllerOutlet checkImage:pathname];
	}
	else if ([[[pathname pathExtension] lowercaseString] isEqualTo:@"burn"])
	{
	NSDictionary *burnFile = [NSDictionary dictionaryWithContentsOfFile:pathname];
	
	[mainTabView selectTabViewItemAtIndex:[[burnFile objectForKey:@"KWType"] intValue]];
	[[self currentController] openBurnDocument:pathname];
	}
	else if ([[[pathname pathExtension] lowercaseString] isEqualTo:@"burntheme"])
	{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWDVDThemeOpened" object:[NSArray arrayWithObjects:pathname,nil]];
	}
	else
	{
	[mainTabView selectTabViewItemWithIdentifier:@"Data"];
	[dataControllerOutlet addDroppedOnIconFiles:[NSArray arrayWithObject:pathname]];
	}
}

- (void)tabView:(NSTabView *)aTabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
[newTabView setSelectedSegment:[aTabView indexOfTabViewItem:[aTabView selectedTabViewItem]]];
[[NSNotificationCenter defaultCenter] postNotificationName:@"controlMenus" object:mainWindow];
}

- (NSString *)currentTabviewItem
{
return [[mainTabView selectedTabViewItem] identifier];
}

- (id)currentController
{
	if ([[self currentTabviewItem] isEqualTo:@"Data"])
	return dataControllerOutlet;
	
	if ([[self currentTabviewItem] isEqualTo:@"Audio"])
	return audioControllerOutlet;

	if ([[self currentTabviewItem] isEqualTo:@"Video"])
	return videoControllerOutlet;
	
	if ([[self currentTabviewItem] isEqualTo:@"Copy"])
	return copyControllerOutlet;
	
return nil;
}

@end
