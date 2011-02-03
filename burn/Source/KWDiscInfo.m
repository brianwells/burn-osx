#import "KWDiscInfo.h"
#import "KWCommonMethods.h"

@implementation KWDiscInfo

- (id)init
{
	if( self = [super init] )
	{
		NSArray *objects = [NSArray arrayWithObjects:	@"CD-ROM",
														@"DVD-ROM",
														@"CD-R",
														@"CD-RW",
														@"DVD-R",
														@"DVD-RW",
														@"DVD-RAM",
														@"DVD+R",
														@"DVD+RW",
		nil];
		
		NSArray *keys = [NSArray arrayWithObjects:	@"DRDeviceMediaTypeCDROM",
													@"DRDeviceMediaTypeDVDROM",
													@"DRDeviceMediaTypeCDR",
													@"DRDeviceMediaTypeCDRW",
													@"DRDeviceMediaTypeDVDR",
													@"DRDeviceMediaTypeDVDRW",
													@"DRDeviceMediaTypeDVDRAM",
													@"DRDeviceMediaTypeDVDPlusR",
													@"DRDeviceMediaTypeDVDPlusRW",
		nil];
	
		discTypes = [[NSDictionary alloc] initWithObjects:objects forKeys:keys];
		
		[NSBundle loadNibNamed:@"KWDiscInfo" owner:self];
	}
	
	return self;
}

- (void)dealloc
{
	[discTypes release];

	[[DRNotificationCenter currentRunLoopCenter] removeObserver:self name:DRDeviceStatusChangedNotification object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[super dealloc];
}

- (void)awakeFromNib
{
	NSWindow *myWindow = [self window];
	DRNotificationCenter *currentCenter = [DRNotificationCenter currentRunLoopCenter];

	[currentCenter addObserver:self selector:@selector(updateDiskInfo) name:DRDeviceDisappearedNotification object:nil];
	[currentCenter addObserver:self selector:@selector(updateDiskInfo) name:DRDeviceAppearedNotification object:nil];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(saveFrame) name:NSWindowWillCloseNotification object:nil];

	[myWindow setFrameUsingName:@"Disc Info"];

	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWFirstRun"] == YES)
		[myWindow setFrameOrigin:NSMakePoint(500,[[NSScreen mainScreen] frame].size.height - 500)];
}

//////////////////
// Main actions //
//////////////////

#pragma mark -
#pragma mark •• Main actions

- (void)startDiskPanelwithDevice:(DRDevice *)device
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
		NSInteger i;
		for (i=0;i< [devices count];i++)
		{
			[recorderPopup addItemWithTitle:[[devices objectAtIndex:i] displayName]];
		}
			
		[recorderPopup selectItemWithTitle:[device displayName]];
		
		[self setDiskInfo:device];
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
	[self setDiskInfo:[devices objectAtIndex:[recorderPopup indexOfSelectedItem]]];
}

//////////////////////
// Internal actions //
//////////////////////

#pragma mark -
#pragma mark •• Internal actions

- (void)setDiskInfo:(DRDevice *)device
{
	NSDictionary *mediaInfo = [[device status] objectForKey:DRDeviceMediaInfoKey];
	NSString *type = [mediaInfo objectForKey:DRDeviceMediaTypeKey];
	NSString *kind = [discTypes objectForKey:type];

	if (kind)
	{
		[kindDisk setStringValue:kind];
		[freeSpaceDisk setStringValue:[KWCommonMethods makeSizeFromFloat:[[mediaInfo objectForKey:DRDeviceMediaFreeSpaceKey] cgfloatValue] * 2048]];
		[usedSpaceDisk setStringValue:[KWCommonMethods makeSizeFromFloat:[[mediaInfo objectForKey:DRDeviceMediaUsedSpaceKey] cgfloatValue] * 2048]];

		if ([[[mediaInfo objectForKey:DRDeviceMediaBlocksOverwritableKey] stringValue] isEqualTo:@"0"])
			[writableDisk setStringValue:NSLocalizedString(@"No",nil)];
		else
			[writableDisk setStringValue:NSLocalizedString(@"Yes",nil)];
	}
	else
	{
		[kindDisk setStringValue:NSLocalizedString(@"No disc",nil)];
		[freeSpaceDisk setStringValue:@""];
		[usedSpaceDisk setStringValue:@""];
		[writableDisk setStringValue:@""];
	}
}

- (void)updateDiskInfo
{
	NSArray *devices = [DRDevice devices];
	
	NSString *title = [[recorderPopup title] copy];

	[recorderPopup removeAllItems];
		
	NSInteger i;
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
	[[self window] saveFrameUsingName:@"Disc Info"];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

@end