#import "KWEraser.h"

@implementation KWEraser

- (id)init
{
	self = [super init];

	shouldClose = NO;
	[NSBundle loadNibNamed:@"KWEraser" owner:self];

	return self;
}

- (void)dealloc
{
	[super dealloc];
}

///////////////////
// Main actions //
///////////////////

#pragma mark -
#pragma mark •• Main actions

- (void)setupWindow
{
	[burnerPopup removeAllItems];
	
	NSArray *devices = [DRDevice devices];
	NSInteger i;
	for (i = 0; i < [devices count]; i ++)
	{
		[burnerPopup addItemWithTitle:[[devices objectAtIndex:i] displayName]];
	}
	
	NSString *displayName = [[self savedDevice] displayName];
	if ([burnerPopup indexOfItemWithTitle:displayName] > -1)
	{
		[burnerPopup selectItemWithTitle:displayName];
	}
	
	[self updateDevice:[self currentDevice]];

	[[DRNotificationCenter currentRunLoopCenter] addObserver:self selector:@selector(statusChanged:) name:DRDeviceStatusChangedNotification object:nil];
}

- (void)beginEraseSheetForWindow:(NSWindow *)window modalDelegate:(id)delegate didEndSelector:(SEL)selector
{
	endSelector = selector;
	endDelegate = delegate;
	
	[self setupWindow];
	
	[NSApp beginSheet:[self window] modalForWindow:window modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:window];
}

- (NSInteger)beginEraseWindow
{
	[burnerPopup removeAllItems];
	
	[self setupWindow];
	
	NSInteger x = [NSApp runModalForWindow:[self window]];
	[[self window] close];

	return x;
}

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	[sheet orderOut:self];
	[[DRNotificationCenter currentRunLoopCenter] removeObserver:self name:DRDeviceStatusChangedNotification object:nil];

	[endDelegate performSelector:endSelector withObject:self withObject:(id)returnCode];
}

- (void)erase
{
	DRErase *erase = [[DRErase alloc] initWithDevice:[self currentDevice]];
	
	NSString *eraseType;
	if ([completelyErase state] == NSOnState)
		eraseType = DREraseTypeComplete;
	else
		eraseType = DREraseTypeQuick;
	
	[erase setEraseType:eraseType];	
		
	//Save burner
	NSDictionary *deviceInfo = [[self currentDevice] info];
	NSMutableDictionary *burnDict = [NSMutableDictionary dictionary];

	[burnDict setObject:[deviceInfo objectForKey:@"DRDeviceProductNameKey"] forKey:@"Product"];
	[burnDict setObject:[deviceInfo objectForKey:@"DRDeviceVendorNameKey"] forKey:@"Vendor"];
	[burnDict setObject:@"" forKey:@"SerialNumber"];

	[[NSUserDefaults standardUserDefaults] setObject:burnDict forKey:@"KWDefaultDeviceIdentifier"];

	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWMediaChanged" object:nil];

	[[DRNotificationCenter currentRunLoopCenter] addObserver:self selector:@selector(eraseNotification:) name:DREraseStatusChangedNotification object:erase];	

	[erase start];
}

- (void)updateDevice:(DRDevice *)device
{
	NSDictionary *deviceStatus = [device status];
	NSString *statusString = [deviceStatus objectForKey:DRDeviceMediaStateKey];

	if ([statusString isEqualTo:DRDeviceMediaStateMediaPresent])
	{
		if ([[[deviceStatus objectForKey:DRDeviceMediaInfoKey] objectForKey:DRDeviceMediaIsErasableKey] boolValue])
		{
			[closeButton setEnabled:YES];
			[closeButton setTitle:NSLocalizedString(@"Eject", Localized)];
		
			[statusText setStringValue:NSLocalizedString(@"Ready to erase", Localized)];
		
			[eraseButton setEnabled:YES];
		}
		else
		{
			[device ejectMedia];
		}
	}
	else if ([statusString isEqualTo:DRDeviceMediaStateInTransition])
	{
		[closeButton setEnabled:NO];
		[statusText setStringValue:NSLocalizedString(@"Waiting for the drive...", Localized)];
		[eraseButton setEnabled:NO];
	}
	else if ([statusString isEqualTo:DRDeviceMediaStateNone])
	{
		if ([[[device info] objectForKey:DRDeviceLoadingMechanismCanOpenKey] boolValue])
		{
			[closeButton setEnabled:YES];
		
			if ([[deviceStatus objectForKey:DRDeviceIsTrayOpenKey] boolValue])
				[closeButton setTitle:NSLocalizedString(@"Close", Localized)];
			else
				[closeButton setTitle:NSLocalizedString(@"Open", Localized)];
		}
		else
		{
			[closeButton setTitle:NSLocalizedString(@"Close", Localized)];
			[closeButton setEnabled:NO];
		}
		
		[statusText setStringValue:NSLocalizedString(@"Waiting for a disc to be inserted...", Localized)];
		[eraseButton setEnabled:NO];
	}
}

///////////////////////
// Interface actions //
///////////////////////

#pragma mark -
#pragma mark •• Interface actions

- (IBAction)burnerPopup:(id)sender
{
	DRDevice *currentDevice = [self currentDevice];

	if ([[[currentDevice info] objectForKey:DRDeviceLoadingMechanismCanOpenKey] boolValue])
	{
		if (![[[currentDevice status] objectForKey:DRDeviceIsTrayOpenKey] boolValue])
		{
			[currentDevice openTray];
			shouldClose = YES;
		}
	}
	
	NSArray *devices = [DRDevice devices];
	NSInteger i;
	for (i = 0; i < [devices count]; i ++)
	{
		DRDevice *device = [devices objectAtIndex:i];
		
		if ([[[device info] objectForKey:DRDeviceLoadingMechanismCanOpenKey] boolValue] && [[[device status] objectForKey:DRDeviceIsTrayOpenKey] boolValue] && !i == [burnerPopup indexOfSelectedItem])
			[device closeTray];
	}

	[self updateDevice:currentDevice];
}

- (IBAction)cancelButton:(id)sender
{
	if (shouldClose)
		[[[DRDevice devices] objectAtIndex:[burnerPopup indexOfSelectedItem]] closeTray];
		
	[[DRNotificationCenter currentRunLoopCenter] removeObserver:self name:DREraseStatusChangedNotification object:nil];
	
	[NSApp endSheet:[self window] returnCode:NSCancelButton];
}

- (IBAction)closeButton:(id)sender
{
	DRDevice *selectedDevice = [[DRDevice devices] objectAtIndex:[burnerPopup indexOfSelectedItem]];
	
	NSString *closeTitle = [closeButton title];
	if ([closeTitle isEqualTo:NSLocalizedString(@"Eject", Localized)])
	{
		[selectedDevice ejectMedia];
	}
	else if ([closeTitle isEqualTo:NSLocalizedString(@"Close", Localized)])
	{
		[selectedDevice closeTray];
	}
	else if ([closeTitle isEqualTo:NSLocalizedString(@"Open", Localized)])
	{
		shouldClose = YES;
		[selectedDevice openTray];
	}
}

- (IBAction)eraseButton:(id)sender
{
	[[DRNotificationCenter currentRunLoopCenter] removeObserver:self name:DREraseStatusChangedNotification object:nil];
	[NSApp endSheet:[self window] returnCode:NSOKButton];
}

//////////////////////////
// Notification actions //
//////////////////////////

#pragma mark -
#pragma mark •• Notification actions

- (void)statusChanged:(NSNotification *)notif
{
	DRDevice *notifDevice = [notif object];

	if ([[notifDevice displayName] isEqualTo:[burnerPopup title]])
	[self updateDevice:notifDevice];
}

- (void)eraseNotification:(NSNotification*)notification	
{	
	NSDictionary* status = [notification userInfo];
	DRErase *eraseObject = [notification object];
	NSString *currentStatusString = [status objectForKey:DRStatusStateKey];
	NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
	NSString *time = @"";
	NSString *statusString = nil;
	
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWDebug"])
		NSLog(@"%@", [status description]);
	
	NSNumber *percent = [status objectForKey:DRStatusPercentCompleteKey];
	if ([percent floatValue] > 0)
	{
		[defaultCenter postNotificationName:@"KWMaximumValueChanged" object:[NSNumber numberWithCGFloat:1.0]];
		[defaultCenter postNotificationName:@"KWValueChanged" object:percent];
		
		NSString *progressString;
		if ([KWCommonMethods OSVersion] == 0x1039)
			progressString = [NSString stringWithFormat:@"%.0f%@", [percent floatValue] * 100, @"%"];
		else
			progressString = [KWCommonMethods formatTime:[[[status objectForKey:@"DRStatusProgressInfoKey"] objectForKey:@"DRStatusProgressRemainingTime"] floatValue] withFrames:NO];
		
		time = [NSString stringWithFormat:@" (%@)", progressString];
	}
	else
	{
		[defaultCenter postNotificationName:@"KWMaximumValueChanged" object:[NSNumber numberWithCGFloat:0]];
	}

	if ([currentStatusString isEqualTo:DRStatusStatePreparing])
	{
		statusString = NSLocalizedString(@"Preparing...", Localized);
	}
	else if ([currentStatusString isEqualTo:DRStatusStateErasing])
	{
		statusString = [NSLocalizedString(@"Erasing disc", Localized) stringByAppendingString:time];
	}
	else if ([currentStatusString isEqualTo:DRStatusStateFinishing])
	{
		statusString = NSLocalizedString(@"Finishing...", Localized);
	}
	else if ([currentStatusString isEqualTo:DRStatusStateDone])
	{
		[[DRNotificationCenter currentRunLoopCenter] removeObserver:self name:DREraseStatusChangedNotification object:eraseObject];
		[eraseObject release];
		eraseObject = nil;
		
		[defaultCenter postNotificationName:@"KWEraseFinished" object:self userInfo:[NSDictionary dictionaryWithObject:@"KWSucces" forKey:@"ReturnCode"]];
	}
	else if ([currentStatusString isEqualTo:DRStatusStateFailed])
	{
		[[DRNotificationCenter currentRunLoopCenter] removeObserver:self name:DREraseStatusChangedNotification object:eraseObject];
		[eraseObject release];
		eraseObject = nil;
	
		[defaultCenter postNotificationName:@"KWEraseFinished" object:self userInfo:[NSDictionary dictionaryWithObject:@"KWFailure" forKey:@"ReturnCode"]];
	}
	
	if (statusString)
		[defaultCenter postNotificationName:@"KWStatusChanged" object:statusString];
}

///////////////////
// Other actions //
///////////////////

#pragma mark -
#pragma mark •• Other actions

- (DRDevice *)currentDevice
{
	return [[DRDevice devices] objectAtIndex:[burnerPopup indexOfSelectedItem]];
}

- (DRDevice *)savedDevice
{
	NSArray *devices = [DRDevice devices];
	NSInteger i;
	for (i = 0; i < [devices count];i ++)
	{
	DRDevice *currentDevice = [devices objectAtIndex:i];
	
		if ([[[currentDevice info] objectForKey:@"DRDeviceProductNameKey"] isEqualTo:[[[NSUserDefaults standardUserDefaults] dictionaryForKey:@"KWDefaultDeviceIdentifier"] objectForKey:@"Product"]])
		{
			return currentDevice;
		}
	}
	
	return [devices objectAtIndex:0];
}

@end