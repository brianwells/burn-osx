#import "KWApplication.h"
#import "KWCommonMethods.h"

@implementation KWApplication

+ (void)initialize
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults]; // standard user defaults
	NSArray *defaultKeys = [NSArray arrayWithObjects:	@"KWUseSoundEffects",
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
														@"KWDVDForceAspect",
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
														@"KWAdvancedFilesystems",
														@"KWDVDTheme",
														@"KWDefaultWindowWidth",
														@"KWDefaultWindowHeight",
														@"KWFirstRun",
														@"KWEncodingThreads",
														@"KWSimulateBurn",
														@"KWDVDAspectMode",
														@"KWTemporaryFiles",
	nil];

	NSArray *defaultValues = [NSArray arrayWithObjects:	[NSNumber numberWithBool:YES],		// KWUseSoundEffects
														[NSNumber numberWithBool:YES],		// KWRememberLastTab
														[NSNumber numberWithBool:YES],		// KWRememberPopups
														[NSNumber numberWithInteger:0],			// KWCleanTemporaryFolderAction
														[NSNumber numberWithBool:NO],		// KWBurnOptionsVerifyBurn
														[NSNumber numberWithBool:NO],		// KWShowOverwritableSpace
														[NSNumber numberWithInteger:6],			// KWDefaultCDMedia
														[NSNumber numberWithInteger:4],			// KWDefaultDVDMedia
														[NSNumber numberWithInteger:0],			// KWDefaultMedia
														[NSNumber numberWithInteger:0],			// KWDefaultDataType
														[NSNumber numberWithBool:NO],		// KWShowFilePackagesAsFolder
														[NSNumber numberWithBool:YES],		// KWCalculateFilePackageSizes
														[NSNumber numberWithBool:YES],		// KWCalculateFolderSizes
														[NSNumber numberWithBool:YES],		// KWCalculateTotalSize
														[NSNumber numberWithInteger:0],			// KWDefaultAudioType
														[NSNumber numberWithInteger:2],			// KWDefaultPregap
														[NSNumber numberWithBool:NO],		// KWUseCDText
														[NSNumber numberWithInteger:128],		// KWDefaultMP3Bitrate
														[NSNumber numberWithInteger:1],			// KWDefaultMP3Mode
														[NSNumber numberWithBool:YES],		// KWCreateArtistFolders
														[NSNumber numberWithBool:YES],		// KWCreateAlbumFolders
														[NSNumber numberWithInteger:0],			// KWDefaultRegion
														[NSNumber numberWithInteger:0],			// KWDefaultVideoType
														[NSNumber numberWithInteger:0],			// KWDefaultDVDSoundType
														[NSNumber numberWithBool:NO],		// KWCustomDVDVideoBitrate
														[NSNumber numberWithInteger:6000],		// KWDefaultDVDVideoBitrate
														[NSNumber numberWithBool:NO],		// KWCustomDVDSoundBitrate
														[NSNumber numberWithInteger:448],		// KWDefaultDVDSoundBitrate
														[NSNumber numberWithInteger:0],			// KWDVDForceAspect
														[NSNumber numberWithBool:NO],		// KWForceMPEG2
														[NSNumber numberWithBool:NO],		// KWMuxSeperateStreams
														[NSNumber numberWithBool:NO],		// KWRemuxMPEG2Streams
														[NSNumber numberWithBool:NO],		// KWLoopDVD
														[NSNumber numberWithBool:YES],		// KWUseTheme
														[[[NSBundle mainBundle] pathForResource:@"Themes" ofType:@""] stringByAppendingPathComponent:@"Default.burnTheme"], //KWDVDThemePath
														[NSNumber numberWithInteger:0],			// KWThemeFormat
														[NSNumber numberWithInteger:0],			// KWDefaultDivXSoundType
														[NSNumber numberWithBool:NO],		// KWCustomDivXVideoBitrate
														[NSNumber numberWithInteger:768],		// KWDefaultDivXVideoBitrate
														[NSNumber numberWithBool:NO],		// KWCustomDivXSoundBitrate
														[NSNumber numberWithInteger:128],		// KWDefaultDivxSoundBitrate
														[NSNumber numberWithBool:NO],		// KWCustomDivXSize
														[NSNumber numberWithInteger:320],		// KWDefaultDivXWidth
														[NSNumber numberWithInteger:240],		// KWDefaultDivXHeight
														[NSNumber numberWithBool:NO],		// KWCustomFPS
														[NSNumber numberWithInteger:25],		// KWDefaultFPS
														[NSNumber numberWithBool:NO],		// KWAllowMSMPEG4
														[NSNumber numberWithBool:NO],		// KWForceDivX
														[NSNumber numberWithBool:NO],		// KWSaveBorders
														[NSNumber numberWithInteger:0],			// KWSaveBorderSize
														[NSNumber numberWithBool:NO],		// KWDebug
														[NSNumber numberWithBool:NO],		// KWUseCustomFFMPEG
														@"",								// KWCustomFFMPEG
														[NSNumber numberWithBool:NO],		// KWAllowOverBurning
														[[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"] stringByAppendingPathComponent:@"Burn Temporary.localized"], // KWTemporaryLocation
														[NSNumber numberWithInteger:0],			// KWTemporaryLocationPopup
														@"",								// KWDefaultDeviceIdentifier
														@"DRBurnCompletionActionMount",		// KWBurnOptionsCompletionAction
														@"General",							// KWSavedPrefView
														@"Data",							// KWLastTab
														[NSArray arrayWithObject:@"HFS+"],	// KWAdvancedFilesystems
														[NSNumber numberWithInteger:0],			//KWDVDTheme
														[NSNumber numberWithInteger:430],		//KWDefaultWindowWidth
														[NSNumber numberWithInteger:436],		//KWDefaultWindowHeight
														[NSNumber numberWithBool:YES],		//KWFirstRun
														[NSNumber numberWithInteger:8],			//KWEncodingThreads
														[NSNumber numberWithBool:NO],		//KWSimulateBurn
														[NSNumber numberWithInteger:0],			//KWDVDAspectMode
														[NSArray array],					//KWTemporaryFiles
	nil];

	NSDictionary *appDefaults = [NSDictionary dictionaryWithObjects:defaultValues forKeys:defaultKeys];
	[defaults registerDefaults:appDefaults];
}

- (void)dealloc 
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[growlController release];
	growlController = nil;
	
	if (preferences)
	{
		[preferences release];
		preferences = nil;
	}
	
	if (inspector)
	{
		[inspector release];
		inspector = nil;
	}
	
	if (recorderInfo)
	{
		[recorderInfo release];
		recorderInfo = nil;
	}
	
	if (diskInfo)
	{
		[diskInfo release];
		diskInfo = nil;
	}
	
	if (currentObject)
	{
		[currentObject release];
		currentObject = nil;
	}
	
	if (currentType)
	{
		[currentType release];
		currentType = nil;
	}

	[super dealloc];
}

- (void)awakeFromNib
{
	NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
	NSFileManager *defaultManager = [NSFileManager defaultManager];

	[defaultCenter addObserver:self selector:@selector(openPreferencesAndAddTheme:) name:@"KWDVDThemeOpened" object:nil];
	[defaultCenter addObserver:self selector:@selector(changeInspector:) name:@"KWChangeInspector" object:nil];
	
	NSString *defaultPath = [[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"] stringByAppendingPathComponent:@"Burn Temporary.localized"];
	
	if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"KWTemporaryLocation"] isEqualTo:defaultPath] && ![defaultManager fileExistsAtPath:defaultPath])
	{
		//Create it in the tmp folder so it will look good localized in less updating Finders (10.3, 10.4 I guess)
		NSString *tempPath = [@"/tmp" stringByAppendingPathComponent:@"Burn Temporary.localized"];

		//Create the temporary folder
		NSString *errorString;
		BOOL succes = NO;
		
		if ([KWCommonMethods createDirectoryAtPath:tempPath errorString:&errorString])
			succes = [KWCommonMethods createDirectoryAtPath:[tempPath stringByAppendingPathComponent:@".localized"] errorString:&errorString];
		
		if (succes)
		{
			//Get the folders in Burn.app/Contents/Resources
			NSBundle *mainBundle = [NSBundle mainBundle];
			NSArray *resourceFolders = [mainBundle localizations];
		
			NSInteger y;
			for (y=0;y<[resourceFolders count];y++)
			{
				//Create a localized dictionary file
				NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:[[[mainBundle resourcePath] stringByAppendingPathComponent:[[resourceFolders objectAtIndex:y] stringByAppendingPathExtension:@"lproj"]] stringByAppendingPathComponent:@"Localizable.strings"]];
				NSDictionary *localizedDict = [NSDictionary dictionaryWithObject:[dict objectForKey:@"Burn Temporary"] forKey:@"Burn Temporary"];
				NSString *localizedStringsFile = [[[resourceFolders objectAtIndex:y] stringByDeletingPathExtension] stringByAppendingPathExtension:@"strings"];
				[KWCommonMethods writeString:[localizedDict descriptionInStringsFileFormat] toFile:[[tempPath stringByAppendingPathComponent:@".localized"] stringByAppendingPathComponent:localizedStringsFile] errorString:nil];
			}
		
			[defaultManager movePath:tempPath toPath:defaultPath handler:nil];
		}
		else 
		{
			[KWCommonMethods standardAlertWithMessageText:NSLocalizedString(@"Failed to create temporary folder", nil) withInformationText:NSLocalizedString(@"OK", nil)withParentWindow:nil];	
		}

	}
	
	growlController = [[KWGrowlController alloc] init];
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

//Window menu

#pragma mark -
#pragma mark •• - Window menu

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
		diskInfo = [[KWDiscInfo alloc] init];

	[diskInfo startDiskPanelwithDevice:[KWCommonMethods getCurrentDevice]];
}

//Help menu

#pragma mark -
#pragma mark •• - Help menu

- (IBAction)openBurnSite:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://burn-osx.sourceforge.net"]];
}

//////////////////////////
// Notification actions //
//////////////////////////

#pragma mark -
#pragma mark •• Notification actions

- (void)openPreferencesAndAddTheme:(NSNotification *)notif
{
	[self preferencesBurn:self];
	[preferences addThemeAndShow:[notif object]];
}

- (void)changeInspector:(NSNotification *)notif
{	
	if (currentObject)
		currentObject = nil;
	
	if (currentType)
	{
		[currentType release];
		currentType = nil;
	}

	currentObject = [notif object];
	currentType = [[[notif userInfo] objectForKey:@"Type"] retain];

	if (inspector)
		[inspector updateForType:currentType withObject:currentObject];
}

@end