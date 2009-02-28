#import "KWRecorderInfo.h"
#import "KWCommonMethods.h"

@implementation KWRecorderInfo

- (id)init
{
self = [super init];

[NSBundle loadNibNamed:@"KWRecorderInfo" owner:self];

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
[[DRNotificationCenter currentRunLoopCenter] addObserver:self selector:@selector(updateRecorderInfo) name:DRDeviceDisappearedNotification object:nil];
[[DRNotificationCenter currentRunLoopCenter] addObserver:self selector:@selector(updateRecorderInfo) name:DRDeviceAppearedNotification object:nil];

[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(saveFrame) name:NSWindowWillCloseNotification object:nil];

[[self window] setFrameUsingName:@"Recorder Info"];

	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWFirstRun"] == YES)
	[[self window] setFrameOrigin:NSMakePoint(500,[[NSScreen mainScreen] frame].size.height - 310)];
}

- (void)saveFrame
{
[[self window] saveFrameUsingName:@"Recorder Info"];
[[NSUserDefaults standardUserDefaults] synchronize];
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

/////////////////
// Own actions //
/////////////////

#pragma mark -
#pragma mark •• Own actions

- (void)startRecorderPanelwithDevice:(DRDevice *)device
{
NSArray *devices = [DRDevice devices];

[recorderPopup removeAllItems];
		
	int i;
	for (i=0;i< [devices count];i++)
	{
	[recorderPopup addItemWithTitle:[[devices objectAtIndex:i] displayName]];
	}
			
[recorderPopup selectItemWithTitle:[device displayName]];
		
[self setRecorderInfo:device];

	if ([[self window] isVisible])
	[[self window] orderOut:self];
	else
	[[self window] makeKeyAndOrderFront:self];
}

- (void)setRecorderInfo:(DRDevice *)device
{
[recorderProduct setStringValue:[[device info] objectForKey:@"DRDeviceProductNameKey"]];
[recorderVendor setStringValue:[[device info] objectForKey:@"DRDeviceVendorNameKey"]];
[recorderConnection setStringValue:[[device info] objectForKey:@"DRDevicePhysicalInterconnectKey"]];
[recorderCache setStringValue:[[[[device info] objectForKey:@"DRDeviceWriteBufferSizeKey"] stringValue] stringByAppendingString:@" KB"]];

	if ([[[[[device info] objectForKey:@"DRDeviceWriteCapabilitiesKey"] objectForKey:DRDeviceCanUnderrunProtectCDKey] stringValue] isEqualTo:@"1"])
	[recorderBuffer setStringValue:NSLocalizedString(@"Yes",@"Localized")];
	else
	[recorderBuffer setStringValue:NSLocalizedString(@"No",@"Localized")];
	
	if ([[[[[device info] objectForKey:@"DRDeviceWriteCapabilitiesKey"] objectForKey:DRDeviceCanWriteDVDKey] stringValue] isEqualTo:@"1"])
	{
		if ([[[[[device info] objectForKey:@"DRDeviceWriteCapabilitiesKey"] objectForKey:DRDeviceCanUnderrunProtectDVDKey] stringValue] isEqualTo:@"1"])
		{
			if ([[recorderBuffer stringValue] isEqualTo:NSLocalizedString(@"Yes",@"Localized")])
			[recorderBuffer setStringValue:[[[@"CD: " stringByAppendingString:NSLocalizedString(@"Yes",@"Localized")] stringByAppendingString:@" DVD: "] stringByAppendingString:NSLocalizedString(@"Yes",@"Localized")]];
			else
			[recorderBuffer setStringValue:[[[@"CD: " stringByAppendingString:NSLocalizedString(@"No",@"Localized")] stringByAppendingString:@" DVD: "] stringByAppendingString:NSLocalizedString(@"Yes",@"Localized")]];
		}
		else
		{
			if ([[recorderBuffer stringValue] isEqualTo:NSLocalizedString(@"Yes",@"Localized")])
			[recorderBuffer setStringValue:[[[@"CD: " stringByAppendingString:NSLocalizedString(@"Yes",@"Localized")] stringByAppendingString:@" DVD: "] stringByAppendingString:NSLocalizedString(@"No",@"Localized")]];
			else
			[recorderBuffer setStringValue:[[[@"CD: " stringByAppendingString:NSLocalizedString(@"No",@"Localized")] stringByAppendingString:@" DVD: "] stringByAppendingString:NSLocalizedString(@"No",@"Localized")]];
		}
	}
	
NSString *writesOn = @"";
	
	if ([[[[[device info] objectForKey:@"DRDeviceWriteCapabilitiesKey"] objectForKey:DRDeviceCanWriteCDRKey] stringValue] isEqualTo:@"1"])
	writesOn = [writesOn stringByAppendingString:@"CD-R "];
	
	if ([[[[[device info] objectForKey:@"DRDeviceWriteCapabilitiesKey"] objectForKey:DRDeviceCanWriteCDRWKey] stringValue] isEqualTo:@"1"])
	writesOn = [writesOn stringByAppendingString:@"CD-RW "];
	
	if ([[[[[device info] objectForKey:@"DRDeviceWriteCapabilitiesKey"] objectForKey:DRDeviceCanWriteDVDRKey] stringValue] isEqualTo:@"1"])
	writesOn = [writesOn stringByAppendingString:@"DVD-R "];
	
	if ([[[[[device info] objectForKey:@"DRDeviceWriteCapabilitiesKey"] objectForKey:DRDeviceCanWriteDVDRWKey] stringValue] isEqualTo:@"1"])
	writesOn = [writesOn stringByAppendingString:@"DVD-RW "];

	if ([[[[[device info] objectForKey:@"DRDeviceWriteCapabilitiesKey"] objectForKey:DRDeviceCanWriteDVDRAMKey] stringValue] isEqualTo:@"1"])
	writesOn = [writesOn stringByAppendingString:@"DVD-RAM "];

	if ([[[[[device info] objectForKey:@"DRDeviceWriteCapabilitiesKey"] objectForKey:DRDeviceCanWriteDVDPlusRKey] stringValue] isEqualTo:@"1"])
	writesOn = [writesOn stringByAppendingString:@"DVD+R "];
	
	if (![KWCommonMethods isPanther])
		if ([[[[[device info] objectForKey:@"DRDeviceWriteCapabilitiesKey"] objectForKey:DRDeviceCanWriteDVDPlusRDoubleLayerKey] stringValue] isEqualTo:@"1"])
		writesOn = [writesOn stringByAppendingString:@"DVD+R(DL) "];
	
	if ([[[[[device info] objectForKey:@"DRDeviceWriteCapabilitiesKey"] objectForKey:DRDeviceCanWriteDVDPlusRWKey] stringValue] isEqualTo:@"1"])
	writesOn = [writesOn stringByAppendingString:@"DVD+RW"];
	
	[recorderWrites setStringValue:writesOn];
}

- (void)updateRecorderInfo
{
NSArray *devices = [DRDevice devices];
	
NSString *title = [[recorderPopup title] copy];
BOOL deviceStillExsists = NO;
[recorderPopup removeAllItems];
		
	int i;
	for (i=0;i< [devices count];i++)
	{
	[recorderPopup addItemWithTitle:[[devices objectAtIndex:i] displayName]];
	
	deviceStillExsists = ([title isEqualTo:[[devices objectAtIndex:i] displayName]]);
	}
		
	if (deviceStillExsists == YES)
	{
	[recorderPopup selectItemWithTitle:title];
	}
	
[self recorderPopup:self];
}

@end
