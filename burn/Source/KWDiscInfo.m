#import "KWDiskInfo.h"
#import "KWCommonMethods.h"

@implementation KWDiskInfo

- (id)init
{
self = [super init];

[NSBundle loadNibNamed:@"KWDiskInfo" owner:self];
	
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
[[DRNotificationCenter currentRunLoopCenter] addObserver:self selector:@selector(updateDiskInfo) name:DRDeviceDisappearedNotification object:nil];
[[DRNotificationCenter currentRunLoopCenter] addObserver:self selector:@selector(updateDiskInfo) name:DRDeviceAppearedNotification object:nil];

[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(saveFrame) name:NSWindowWillCloseNotification object:nil];

[[self window] setFrameUsingName:@"Disc Info"];

	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWFirstRun"] == YES)
	[[self window] setFrameOrigin:NSMakePoint(500,[[NSScreen mainScreen] frame].size.height - 500)];
}

- (void)saveFrame
{
[[self window] saveFrameUsingName:@"Disc Info"];
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
[self setDiskInfo:[devices objectAtIndex:[recorderPopup indexOfSelectedItem]]];
}

/////////////////
// Own actions //
/////////////////

#pragma mark -
#pragma mark •• Own actions

- (void)startDiskPanelwithDevice:(DRDevice *)device
{
NSArray *devices = [DRDevice devices];

[recorderPopup removeAllItems];
		
	int i;
	for (i=0;i< [devices count];i++)
	{
	[recorderPopup addItemWithTitle:[[devices objectAtIndex:i] displayName]];
	}
			
[recorderPopup selectItemWithTitle:[device displayName]];
		
[self setDiskInfo:device];

	if ([[self window] isVisible])
	[[self window] orderOut:self];
	else
	[[self window] makeKeyAndOrderFront:self];
}

- (void)setDiskInfo:(DRDevice *)device
{
NSString *type = [[[device status] objectForKey:DRDeviceMediaInfoKey] objectForKey:DRDeviceMediaTypeKey];

	if ([type isEqualTo:@"DRDeviceMediaTypeCDROM"])
	{
	[kindDisk setStringValue:@"CD-ROM"];
	}
	else if ([type isEqualTo:@"DRDeviceMediaTypeDVDROM"])
	{
	[kindDisk setStringValue:@"DVD-ROM"];
	}
	else if ([type isEqualTo:@"DRDeviceMediaTypeCDR"])
	{
	[kindDisk setStringValue:@"CD-R"];
	}
	else if ([type isEqualTo:@"DRDeviceMediaTypeCDRW"])
	{
	[kindDisk setStringValue:@"CD-RW"];
	}
	else if ([type isEqualTo:@"DRDeviceMediaTypeDVDR"])
	{
	[kindDisk setStringValue:@"DVD-R"];
	}
	else if ([type isEqualTo:@"DRDeviceMediaTypeDVDRW"])
	{
	[kindDisk setStringValue:@"DVD-RW"];
	}
	else if ([type isEqualTo:@"DRDeviceMediaTypeDVDRAM"])
	{
	[kindDisk setStringValue:@"DVD-RAM"];
	}
	else if ([type isEqualTo:@"DRDeviceMediaTypeDVDPlusR"])
	{
	[kindDisk setStringValue:@"DVD+R"];
	}
	else if ([type isEqualTo:@"DRDeviceMediaTypeDVDPlusRW"])
	{
	[kindDisk setStringValue:@"DVD+RW"];
	}
	else
	{
	[kindDisk setStringValue:NSLocalizedString(@"No disc",@"Localized")];
	
		if (![KWCommonMethods isPanther])
			if ([type isEqualTo:@"DRDeviceMediaTypeDVDPlusRDoubleLayer"])
			[kindDisk setStringValue:@"DVD+R Double Layer"];
	}

	if (![[kindDisk stringValue] isEqualTo:NSLocalizedString(@"No disc",@"Localized")])
	{
	[freeSpaceDisk setStringValue:[KWCommonMethods makeSizeFromFloat:[[[[device status] objectForKey:DRDeviceMediaInfoKey] objectForKey:DRDeviceMediaFreeSpaceKey] floatValue] * 2048]];
	[usedSpaceDisk setStringValue:[KWCommonMethods makeSizeFromFloat:[[[[device status] objectForKey:DRDeviceMediaInfoKey] objectForKey:DRDeviceMediaUsedSpaceKey] floatValue] * 2048]];

		if ([[[[[device status] objectForKey:DRDeviceMediaInfoKey] objectForKey:DRDeviceMediaBlocksOverwritableKey] stringValue] isEqualTo:@"0"])
		{
		[writableDisk setStringValue:NSLocalizedString(@"No",@"Localized")];
		}
		else
		{
		[writableDisk setStringValue:NSLocalizedString(@"Yes",@"Localized")];
		}
	}
	else
	{
	[freeSpaceDisk setStringValue:@""];
	[usedSpaceDisk setStringValue:@""];
	[writableDisk setStringValue:@""];
	}
}

- (void)updateDiskInfo
{
NSArray *devices = [DRDevice devices];

NSString *title = [[recorderPopup title] copy];
BOOL deviceStillExsists = NO;
[recorderPopup removeAllItems];
		
	int i;
	for (i=0;i< [devices count];i++)
	{
	[recorderPopup addItemWithTitle:[[devices objectAtIndex:i] displayName]];
		if ([title isEqualTo:[[devices objectAtIndex:i] displayName]])
		deviceStillExsists = YES;
	}
		
	if (deviceStillExsists == YES)
	[recorderPopup selectItemWithTitle:title];
}

@end
