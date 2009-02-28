#import "appController.h"
#import "KWDocument.h"
#import <Carbon/Carbon.h>
#import "growlController.h"
#import "KWCommonMethods.h"

@implementation appController

+ (void)initialize
{
NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults]; // standard user defaults
NSArray *defaultKeys = [NSArray arrayWithObjects:
@"KWUseSoundEffects",
@"KWRememberLastTab",
@"KWRememberPopups",
@"KWCleanTemporaryFolderAction",
@"KWBurnOptionsVerifyBurn",
@"KWShowOverwritableSpace",
@"KWDefaultCDMedia",
@"KWDefaultDVDMedia",
@"KWDefaultMedia",
@"KWDefaultDataType",
@"KWShowFilePackagesAsFolder",
@"KWCalculateFilePackageSizes",
@"KWCalculateFolderSizes",
@"KWCalculateTotalSize",
@"KWDefaultAudioType",
@"KWDefaultPregap",
@"KWUseCDText",
@"KWDefaultMP3Bitrate",
@"KWDefaultMP3Mode",
@"KWCreateArtistFolders",
@"KWCreateAlbumFolders",
@"KWDefaultRegion",
@"KWDefaultVideoType",
@"KWDefaultDVDSoundType",
@"KWCustomDVDVideoBitrate",
@"KWDefaultDVDVideoBitrate",
@"KWCustomDVDSoundBitrate",
@"KWDefaultDVDSoundBitrate",
@"KWDVDForce43",
@"KWForceMPEG2",
@"KWMuxSeperateStreams",
@"KWRemuxMPEG2Streams",
@"KWLoopDVD",
@"KWUseTheme",
@"KWDVDThemePath",
@"KWDVDThemeFormat",
@"KWDefaultDivXSoundType",
@"KWCustomDivXVideoBitrate",
@"KWDefaultDivXVideoBitrate",
@"KWCustomDivXSoundBitrate",
@"KWDefaultDivxSoundBitrate",
@"KWCustomDivXSize",
@"KWDefaultDivXWidth",
@"KWDefaultDivXHeight",
@"KWCustomFPS",
@"KWDefaultFPS",
@"KWAllowMSMPEG4",
@"KWForceDivX",
@"KWSaveBorders",
@"KWSaveBorderSize",
@"KWDebug",
@"KWUseCustomFFMPEG",
@"KWCustomFFMPEG",
@"KWAllowOverBurning",
@"KWTemporaryLocation",
@"KWTemporaryLocationPopup",
@"KWDefaultDeviceIdentifier",
@"KWBurnOptionsCompletionAction",
@"KWSavedPrefView",
@"KWLastTab",
@"KWAdvancedFileSystems",
@"KWDVDTheme",
@"KWDefaultWindowWidth",
@"KWDefaultWindowHeight",
@"KWFirstRun",
nil];

NSArray *defaultValues = [NSArray arrayWithObjects:
[NSNumber numberWithBool:YES],		// KWUseSoundEffects
[NSNumber numberWithBool:YES],		// KWRememberLastTab
[NSNumber numberWithBool:YES],		// KWRememberPopups
[NSNumber numberWithInt:0],			// KWCleanTemporaryFolderAction
[NSNumber numberWithBool:NO],		// KWBurnOptionsVerifyBurn
[NSNumber numberWithBool:NO],		// KWShowOverwritableSpace
[NSNumber numberWithInt:2],			// KWDefaultCDMedia
[NSNumber numberWithInt:0],			// KWDefaultDVDMedia
[NSNumber numberWithInt:0],			// KWDefaultMedia
[NSNumber numberWithInt:0],			// KWDefaultDataType
[NSNumber numberWithBool:NO],		// KWShowFilePackagesAsFolder
[NSNumber numberWithBool:YES],		// KWCalculateFilePackageSizes
[NSNumber numberWithBool:YES],		// KWCalculateFolderSizes
[NSNumber numberWithBool:YES],		// KWCalculateTotalSize
[NSNumber numberWithInt:0],			// KWDefaultAudioType
[NSNumber numberWithInt:2],			// KWDefaultPregap
[NSNumber numberWithBool:NO],		// KWUseCDText
[NSNumber numberWithInt:128],		// KWDefaultMP3Bitrate
[NSNumber numberWithInt:1],			// KWDefaultMP3Mode
[NSNumber numberWithBool:YES],		// KWCreateArtistFolders
[NSNumber numberWithBool:YES],		// KWCreateAlbumFolders
[NSNumber numberWithInt:0],			// KWDefaultRegion
[NSNumber numberWithInt:0],			// KWDefaultVideoType
[NSNumber numberWithInt:0],			// KWDefaultDVDSoundType
[NSNumber numberWithBool:NO],		// KWCustomDVDVideoBitrate
[NSNumber numberWithInt:6000],		// KWDefaultDVDVideoBitrate
[NSNumber numberWithBool:NO],		// KWCustomDVDSoundBitrate
[NSNumber numberWithInt:448],		// KWDefaultDVDSoundBitrate
[NSNumber numberWithBool:NO],		// KWDVDForce43
[NSNumber numberWithBool:NO],		// KWForceMPEG2
[NSNumber numberWithBool:NO],		// KWMuxSeperateStreams
[NSNumber numberWithBool:NO],		// KWRemuxMPEG2Streams
[NSNumber numberWithBool:NO],		// KWLoopDVD
[NSNumber numberWithBool:YES],		// KWUseTheme
[[[NSBundle mainBundle] pathForResource:@"Themes" ofType:@""] stringByAppendingPathComponent:@"Default.burnTheme"], //KWDVDThemePath
[NSNumber numberWithInt:0],			// KWThemeFormat
[NSNumber numberWithInt:0],			// KWDefaultDivXSoundType
[NSNumber numberWithBool:NO],		// KWCustomDivXVideoBitrate
[NSNumber numberWithInt:768],		// KWDefaultDivXVideoBitrate
[NSNumber numberWithBool:NO],		// KWCustomDivXSoundBitrate
[NSNumber numberWithInt:128],		// KWDefaultDivxSoundBitrate
[NSNumber numberWithBool:NO],		// KWCustomDivXSize
[NSNumber numberWithInt:320],		// KWDefaultDivXWidth
[NSNumber numberWithInt:240],		// KWDefaultDivXHeight
[NSNumber numberWithBool:NO],		// KWCustomFPS
[NSNumber numberWithInt:25],		// KWDefaultFPS
[NSNumber numberWithBool:NO],		// KWAllowMSMPEG4
[NSNumber numberWithBool:NO],		// KWForceDivX
[NSNumber numberWithBool:NO],		// KWSaveBorders
[NSNumber numberWithInt:0],			// KWSaveBorderSize
[NSNumber numberWithBool:NO],		// KWDebug
[NSNumber numberWithBool:NO],		// KWUseCustomFFMPEG
@"",								// KWCustomFFMPEG
[NSNumber numberWithBool:NO],		// KWAllowOverBurning
[[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"] stringByAppendingPathComponent:@"Burn Temporary.localized"],	// KWTemporaryLocation
[NSNumber numberWithInt:0],			// KWTemporaryLocationPopup
@"",								// KWDefaultDeviceIdentifier
@"DRBurnCompletionActionMount",		// KWBurnOptionsCompletionAction
@"General",							// KWSavedPrefView
@"Data",							// KWLastTab
[NSArray arrayWithObject:@"HFS+"],	// KWAdvancedFileSystems
[NSNumber numberWithInt:0],			//KWDVDTheme
[NSNumber numberWithInt:430],		//KWDefaultWindowWidth
[NSNumber numberWithInt:436],		//KWDefaultWindowHeight
[NSNumber numberWithBool:YES],		//KWFirstRun
nil];

NSDictionary *appDefaults = [NSDictionary dictionaryWithObjects:defaultValues forKeys:defaultKeys];
[defaults registerDefaults:appDefaults];
}

- (id)init
{
self = [super init];

return self;
}

- (void)dealloc 
{
[[NSNotificationCenter defaultCenter] removeObserver:self];

[super dealloc];
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)theApplication
{
	if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"KWCleanTemporaryFolderAction"] intValue] == 1 && [[[NSUserDefaults standardUserDefaults] objectForKey:@"KWTemporaryLocationPopup"] intValue] != 2)
	{
	NSArray *files = [[NSFileManager defaultManager] directoryContentsAtPath:[[NSUserDefaults standardUserDefaults] objectForKey:@"KWTemporaryLocation"]];
	
		int i;
		for (i=0;i<[files count];i++)
		{
			if (![[files objectAtIndex:i] isEqualTo:@".localized"] &&  [[files objectAtIndex:i] isEqualTo:@"Icon\r"])
			[[NSFileManager defaultManager] removeFileAtPath:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWTemporaryLocation"] stringByAppendingPathComponent:[files objectAtIndex:i]] handler:nil];
		}
	}
	
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWFirstRun"] == YES)
	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:NO] forKey:@"KWFirstRun"];

return YES;
}

- (void)awakeFromNib
{
[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(controlMenus:) name:NSWindowDidBecomeKeyNotification object:nil];
[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(controlMenus:) name:@"controlMenus" object:nil];

[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changeBurnStatus:) name:@"KWChangeBurnStatus" object:nil];

[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(closeWindow:) name:NSWindowWillCloseNotification object:nil];

[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changeInspector:) name:@"KWChangeInspector" object:nil];
[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changeInspector:) name:@"KWInspectorItemDeselected" object:nil];

[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(openPreferencesAndAddTheme:) name:@"KWDVDThemeOpened" object:nil];

[[growlController alloc] init];
}

//////////////////
// Menu actions //
//////////////////

#pragma mark -
#pragma mark •• Menu actions

//Burn menu

#pragma mark -
#pragma mark •• - Burn menu

- (IBAction)preferencesBurn:(id)sender
{
	if (preferences == nil)
	preferences = [[KWPreferences alloc] init];
	
[preferences showPreferences];
}

//File menu

#pragma mark -
#pragma mark •• - File menu

- (IBAction)openFile:(id)sender
{
[(KWDocument *)[[KWCommonMethods firstBurnWindow] delegate] openFile:self];
}

//Recorder menu

#pragma mark -
#pragma mark •• - Recorder menu

- (IBAction)eraseRecorder:(id)sender
{
[(KWDocument *)[[KWCommonMethods firstBurnWindow] delegate] eraseRecorder:self];
}

- (IBAction)ejectRecorder:(id)sender
{
	if ([[DRDevice devices] count] > 1)
	{
		if (ejecter == nil)
		ejecter = [[KWEjecter alloc] init];

	[ejecter startEjectSheetForWindow:[KWCommonMethods firstBurnWindow] forDevice:[KWCommonMethods getCurrentDevice]];
	}
	else
	{
	[[[DRDevice devices] objectAtIndex:0] ejectMedia];
	}
}

//Window menu

#pragma mark -
#pragma mark •• - Window menu

- (IBAction)burnWindow:(id)sender
{
	if (![KWCommonMethods firstBurnWindow] == nil)
	[[KWCommonMethods firstBurnWindow] makeKeyAndOrderFront:self];
	else
	[[[NSDocumentController alloc] init] newDocument:self];
}

- (IBAction)inspectorWindow:(id)sender
{
	if (inspector == nil)
	inspector = [[KWInspector alloc] init];
	
[inspector beginWindowForType:currentType withObject:currentObject];
}

- (IBAction)recorderInfoWindow:(id)sender
{
	if (recorderInfo == nil)
	recorderInfo = [[KWRecorderInfo alloc] init];

[recorderInfo startRecorderPanelwithDevice:[KWCommonMethods getCurrentDevice]];
}

- (IBAction)diskInfoWindow:(id)sender
{
	if (diskInfo == nil)
	diskInfo = [[KWDiskInfo alloc] init];

[diskInfo startDiskPanelwithDevice:[KWCommonMethods getCurrentDevice]];
}

//Help menu

#pragma mark -
#pragma mark •• - Help menu

- (IBAction)itemHelp:(id)sender
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
		
	if ([KWCommonMethods isPanther])
	[NSApp showHelp:nil];
	
CFBundleRef myApplicationBundle = CFBundleGetMainBundle();
CFTypeRef myBookName = CFBundleGetValueForInfoDictionaryKey(myApplicationBundle,CFSTR("CFBundleHelpBookName"));
 
	if ([[itemHelp title] isEqualTo:NSLocalizedString(@"Data Help",@"Localized")])
	AHLookupAnchor(myBookName, CFSTR("data"));
	else if ([[itemHelp title] isEqualTo:NSLocalizedString(@"Audio Help",@"Localized")])
	AHLookupAnchor(myBookName, CFSTR("audio"));
	else if ([[itemHelp title] isEqualTo:NSLocalizedString(@"Video Help",@"Localized")])
	AHLookupAnchor(myBookName, CFSTR("video"));
	else if ([[itemHelp title] isEqualTo:NSLocalizedString(@"Copy Help",@"Localized")])
	AHLookupAnchor(myBookName, CFSTR("copy"));
	else if ([[itemHelp title] isEqualTo:NSLocalizedString(@"Preferences Help",@"Localized")])
	AHLookupAnchor(myBookName, CFSTR("preferences"));
}

//////////////////////////
// Notification actions //
//////////////////////////

#pragma mark -
#pragma mark •• Notification actions

- (void)controlMenus:(NSNotification *)notif
{
	if ([notif object] == [preferences window])
	{
	[itemHelp setTitle:NSLocalizedString(@"Preferences Help",@"Localized")];
	
	[saveAsFile setEnabled:NO];
	[saveImageFile setEnabled:NO];
	
	[openFile setEnabled:YES];
	[closeFile setEnabled:YES];
	[addItems setEnabled:NO];
	[deleteItems setEnabled:NO];
	[createFolderItems setEnabled:NO];
	[mountImageItems setEnabled:NO];
	[scanDisksItems setEnabled:NO];
	
	//[burnRecorder setEnabled:YES];
	[eraseRecorder setEnabled:YES];
	[ejectRecorder setEnabled:YES];

	[preferencesBurn setEnabled:YES];
	[returnToDefaultSizeWindow setEnabled:NO];
	[zoomWindow setEnabled:NO];
	}

	if ([[[notif object] delegate] isKindOfClass:[KWDocument class]])
	{
	[eraseRecorder setEnabled:([[DRDevice devices] count] > 0)];
	[ejectRecorder setEnabled:([[DRDevice devices] count] > 0)];
	
	[preferencesBurn setEnabled:YES];
	[closeFile setEnabled:YES];
	[returnToDefaultSizeWindow setEnabled:YES];
	[minimizeWindow setEnabled:YES];
	[zoomWindow setEnabled:YES];
	[openFile setEnabled:YES];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWSetDropState" object:[NSNumber numberWithBool:YES]];
	
		if ([[[[notif object] delegate] currentTabviewItem] isEqualTo:@"Data"])
		{
		[itemHelp setTitle:NSLocalizedString(@"Data Help",@"Localized")];

		[[NSNotificationCenter defaultCenter] postNotificationName:@"KWChangeBurnStatus" object:[NSNumber numberWithBool:([[[notif object] delegate] dataHasRows] == YES)]];
	
		[addItems setEnabled:YES];
		[deleteItems setEnabled:YES];
		[createFolderItems setEnabled:YES];
		[mountImageItems setEnabled:NO];
		
		[scanDisksItems setEnabled:NO];
		}
		else if ([[[[notif object] delegate] currentTabviewItem] isEqualTo:@"Audio"])
		{
		[itemHelp setTitle:NSLocalizedString(@"Audio Help",@"Localized")];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:@"KWChangeBurnStatus" object:[NSNumber numberWithBool:([[[notif object] delegate] audioHasRows] == YES)]];
		
		[addItems setEnabled:YES];
		[deleteItems setEnabled:YES];
		[createFolderItems setEnabled:NO];
		[mountImageItems setEnabled:NO];
		
		[scanDisksItems setEnabled:NO];
		}
		else if ([[[[notif object] delegate] currentTabviewItem] isEqualTo:@"Video"])
		{
		[itemHelp setTitle:NSLocalizedString(@"Video Help",@"Localized")];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:@"KWChangeBurnStatus" object:[NSNumber numberWithBool:([[[notif object] delegate] videoHasRows] == YES)]];
		
		[addItems setEnabled:YES];
		[deleteItems setEnabled:YES];
		[createFolderItems setEnabled:NO];
		[mountImageItems setEnabled:NO];
		
		[scanDisksItems setEnabled:NO];
		}
		else if ([[[[notif object] delegate] currentTabviewItem] isEqualTo:@"Copy"])
		{
		[itemHelp setTitle:NSLocalizedString(@"Copy Help",@"Localized")];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"KWChangeInspector" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"KWEmpty",@"Type",nil]];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:@"KWChangeBurnStatus" object:[NSNumber numberWithBool:([[[notif object] delegate] copyHasRows] == YES)]];
		
		[addItems setEnabled:NO];
		[deleteItems setEnabled:NO];
		[createFolderItems setEnabled:NO];
		[scanDisksItems setEnabled:YES];
		}
	}
	else if ([[notif object] isSheet])
	{
	[eraseRecorder setEnabled:NO];
	[ejectRecorder setEnabled:NO];
	
	[openFile setEnabled:NO];
	[closeFile setEnabled:NO];
	[addItems setEnabled:NO];
	[deleteItems setEnabled:NO];
	[createFolderItems setEnabled:NO];
	[mountImageItems setEnabled:NO];
	[burnRecorder setEnabled:NO];
	[saveAsFile setEnabled:NO];
	[scanDisksItems setEnabled:NO];
	[saveImageFile setEnabled:NO];

	[preferencesBurn setEnabled:NO];
	[returnToDefaultSizeWindow setEnabled:NO];
	[zoomWindow setEnabled:NO];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWSetDropState" object:[NSNumber numberWithBool:NO]];
	}
	
[recorderInfoWindow setEnabled:([[DRDevice devices] count] > 0)];
[diskInfoWindow setEnabled:([[DRDevice devices] count] > 0)];
}

- (void)closeWindow:(NSNotification *)notif
{
	if ([[[notif object] delegate] isKindOfClass:[KWDocument class]])
	{
	[NSApp terminate:self];
	}
	else
	{
		if ([[NSApp orderedDocuments] count] == 1 && [[[notif object] delegate] isKindOfClass:[KWDocument class]])
		{
		[burnRecorder setEnabled:NO];
	
		[openFile setEnabled:YES];
		[saveAsFile setEnabled:NO];
		[saveImageFile setEnabled:NO];
	
		[addItems setEnabled:NO];
		[deleteItems setEnabled:NO];
		[createFolderItems setEnabled:NO];
		[mountImageItems setEnabled:NO];
		[scanDisksItems setEnabled:NO];
	
		[returnToDefaultSizeWindow setEnabled:NO];
		[minimizeWindow setEnabled:NO];
		[zoomWindow setEnabled:NO];
		}
	}
}

- (void)changeBurnStatus:(NSNotification *)notif
{
	if ([[notif object] boolValue] == YES)
	{
	[burnRecorder setEnabled:([[DRDevice devices] count] > 0)];
	
		if (([[(KWDocument *)[[KWCommonMethods firstBurnWindow] delegate] currentTabviewItem] isEqualTo:@"Data"]) | ([[(KWDocument *)[[KWCommonMethods firstBurnWindow] delegate] currentTabviewItem] isEqualTo:@"Audio"] && [(KWDocument *)[[KWCommonMethods firstBurnWindow] delegate] isAudioMP3]) | ([[(KWDocument *)[[KWCommonMethods firstBurnWindow] delegate] currentTabviewItem] isEqualTo:@"Video"]))
		{
		[saveImageFile setEnabled:YES];
		}
		else if ([[(KWDocument *)[[KWCommonMethods firstBurnWindow] delegate] currentTabviewItem] isEqualTo:@"Copy"] && [(KWDocument *)[[KWCommonMethods firstBurnWindow] delegate] isImageCompatible])
		{
		[saveImageFile setEnabled:YES];
		[mountImageItems setEnabled:YES];
		
			if ([(KWDocument *)[[KWCommonMethods firstBurnWindow] delegate] isImageMounted])
			[mountImageItems setTitle:NSLocalizedString(@"Unmount",@"Localized")];
			else if ([(KWDocument *)[[KWCommonMethods firstBurnWindow] delegate] isImageRealDisk])
			[mountImageItems setTitle:NSLocalizedString(@"Eject",@"Localized")];
			else
			[mountImageItems setTitle:NSLocalizedString(@"Mount",@"Localized")];
		}
		else
		{
		[mountImageItems setTitle:NSLocalizedString(@"Mount",@"Localized")];
		[saveImageFile setEnabled:NO];
		[mountImageItems setEnabled:NO];
		}
	
	[saveAsFile setEnabled:(![[(KWDocument *)[[KWCommonMethods firstBurnWindow] delegate] currentTabviewItem] isEqualTo:@"Copy"])];
	}
	else
	{
	[burnRecorder setEnabled:NO];
	[saveAsFile setEnabled:NO];
	[saveImageFile setEnabled:NO];
	[mountImageItems setEnabled:NO];
	}
}

- (void)changeInspector:(NSNotification *)notif
{
	if (currentObject && [currentObject superclass] == [NSMutableArray class])
	{
	[currentObject release];
	}
	
currentObject = nil;
currentType = nil;

currentObject = [notif object];
currentType = [[notif userInfo] objectForKey:@"Type"];

	if (inspector)
	[inspector updateForType:currentType withObject:currentObject];
}

- (void)openPreferencesAndAddTheme:(NSNotification *)notif
{
[self preferencesBurn:self];
[preferences addThemeAndShow:[notif object]];
}

///////////////////
// Other actions //
///////////////////

#pragma mark -
#pragma mark •• Other actions

- (BOOL)application:(NSApplication *)sender openFile:(NSString *)pathname
{
	if ([[NSApp orderedDocuments] count] == 0)
	{
	[[[NSDocumentController alloc] init] newDocument:self];
	[(KWDocument *)[[KWCommonMethods firstBurnWindow] delegate] openDocument:pathname];
	}
	else
	{
	[(KWDocument *)[[KWCommonMethods firstBurnWindow] delegate] openDocument:pathname];
	}

return YES;
}

@end
