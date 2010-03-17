#import "KWRecorderInfo.h"
#import "KWCommonMethods.h"

@implementation KWRecorderInfo

- (id)init
{
	if( self = [super init] )
	{
		NSArray *objects = [NSArray arrayWithObjects:	@"CD-R",
														@"CD-RW",
														@"DVD-R",
														@"DVD-RW",
														@"DVD-RAM",
														@"DVD+R",
														@"DVD+R(DL)",
														@"DVD+RW",
		nil];
		
		NSArray *keys = [NSArray arrayWithObjects:	@"DRDeviceCanWriteCDRKey",
													@"DRDeviceCanWriteCDRWKey",
													@"DRDeviceCanWriteDVDRKey",
													@"DRDeviceCanWriteDVDRWKey",
													@"DRDeviceCanWriteDVDRAMKey",
													@"DRDeviceCanWriteDVDPlusRKey",
													@"DRDeviceCanWriteDVDPlusRDoubleLayerKey",
													@"DRDeviceCanWriteDVDPlusRWKey",
		nil];
		
		discTypes = [[NSDictionary alloc] initWithObjects:objects forKeys:keys];
	
		[NSBundle loadNibNamed:@"KWRecorderInfo" owner:self];
	}
	
	return self;
}

- (void)dealloc
{
	[[DRNotificationCenter currentRunLoopCenter] removeObserver:self name:DRDeviceStatusChangedNotification object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[super dealloc];
}

- (void)awakeFromNib
{
	NSWindow *myWindow = [self window];
	DRNotificationCenter *currentCenter = [DRNotificationCenter currentRunLoopCenter];

	[currentCenter addObserver:self selector:@selector(updateRecorderInfo) name:DRDeviceDisappearedNotification object:nil];
	[currentCenter addObserver:self selector:@selector(updateRecorderInfo) name:DRDeviceAppearedNotification object:nil];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(saveFrame) name:NSWindowWillCloseNotification object:nil];

	[myWindow setFrameUsingName:@"Recorder Info"];

	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWFirstRun"] == YES)
		[myWindow setFrameOrigin:NSMakePoint(500,[[NSScreen mainScreen] frame].size.height - 310)];
}

//////////////////
// Main actions //
//////////////////

#pragma mark -
#pragma mark •• Main actions

- (void)startRecorderPanelwithDevice:(DRDevice *)device
{
	NSWindow *myWindow = [self window];

	if ([myWindow isVisible])
	{
		[myWindow orderOut:self];
	}
	else
	{
		[recorderPopup removeAllItems];

		NSArray *devices = [DRDevice devices];
		int i;
		for (i=0;i< [devices count];i++)
		{
			[recorderPopup addItemWithTitle:[[devices objectAtIndex:i] displayName]];
		}
			
		[recorderPopup selectItemWithTitle:[device displayName]];
		
		[self setRecorderInfo:device];
		
		[myWindow makeKeyAndOrderFront:self];
	}
}

///////////////////////
// Interface actions //
///////////////////////

#pragma mark -
#pragma mark •• Interface actions

- (IBAction)recorderPopup:(id)sender
{
	NSArray *devices = [DRDevice devices];
	[self setRecorderInfo:[devices objectAtIndex:[recorderPopup indexOfSelectedItem]]];
}

//////////////////////
// Internal actions //
//////////////////////

#pragma mark -
#pragma mark •• Internal actions

- (void)setRecorderInfo:(DRDevice *)device
{
	NSDictionary *deviceInfo = [device info];

	[recorderProduct setStringValue:[deviceInfo objectForKey:@"DRDeviceProductNameKey"]];
	[recorderVendor setStringValue:[deviceInfo objectForKey:@"DRDeviceVendorNameKey"]];
	[recorderConnection setStringValue:[deviceInfo objectForKey:@"DRDevicePhysicalInterconnectKey"]];
	[recorderCache setStringValue:[NSString localizedStringWithFormat:NSLocalizedString(@"%.0f KB", nil), [deviceInfo objectForKey:@"DRDeviceWriteBufferSizeKey"]]];

	NSDictionary *writeCapabilities = [deviceInfo objectForKey:@"DRDeviceWriteCapabilitiesKey"];
	BOOL cdUnderrunProtect = [[writeCapabilities objectForKey:DRDeviceCanUnderrunProtectCDKey] boolValue];
	BOOL canWriteDVD = [[writeCapabilities objectForKey:DRDeviceCanWriteDVDKey] boolValue];
	
	if (cdUnderrunProtect && !canWriteDVD)
		[recorderBuffer setStringValue:NSLocalizedString(@"Yes",nil)];
	
	if (canWriteDVD)
	{
		BOOL dvdUnderrunProtect = [[writeCapabilities objectForKey:DRDeviceCanUnderrunProtectDVDKey] boolValue];
		NSString *cdUnderrun;
		NSString *dvdUnderrun;
		
		if (cdUnderrunProtect)
			cdUnderrun = NSLocalizedString(@"Yes",nil);
		else
			cdUnderrun = NSLocalizedString(@"No",nil);
			
		if (dvdUnderrunProtect)
			dvdUnderrun = NSLocalizedString(@"Yes",nil);
		else
			dvdUnderrun = NSLocalizedString(@"No",nil);
			
		[recorderBuffer setStringValue:[NSString stringWithFormat:@"CD: %@ DVD: %@", cdUnderrun, dvdUnderrun]];
	}
	
	NSArray *typeKeys = [discTypes allKeys];
	NSString *writesOn = @"";
	NSString *space = @"";
	
	int i;
	for (i=0;i< [typeKeys count];i++)
	{
	NSString *currentKey = [typeKeys objectAtIndex:i];
	
		if ([[writeCapabilities objectForKey:currentKey] boolValue])
		{
			writesOn = [NSString stringWithFormat:@"%@%@%@", writesOn, space, [discTypes objectForKey:currentKey]];
			space = @" ";
		}
	}
	
	[recorderWrites setStringValue:writesOn];
}

- (void)updateRecorderInfo
{
	NSArray *devices = [DRDevice devices];
	
	NSString *title = [[recorderPopup title] copy];

	[recorderPopup removeAllItems];
		
	int i;
	for (i=0;i< [devices count];i++)
	{
		[recorderPopup addItemWithTitle:[[devices objectAtIndex:i] displayName]];
	}
		
		if ([recorderPopup indexOfItemWithTitle:title] > -1)
		[recorderPopup selectItemWithTitle:title];
		
	[title release];
	
	[self recorderPopup:self];
}

- (void)saveFrame
{
	[[self window] saveFrameUsingName:@"Recorder Info"];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

@end