#import "KWEraser.h"
#import "KWCommonMethods.h"

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

- (void)beginEraseSheetForWindow:(NSWindow *)window modalDelegate:(id)delegate didEndSelector:(SEL)selector
{
endSelector = selector;
endDelegate = delegate;

[burnerPopup removeAllItems];

	int i;
	for (i=0;i< [[DRDevice devices] count];i++)
	{
	[burnerPopup addItemWithTitle:[[[DRDevice devices] objectAtIndex:i] displayName]];
	}
	
	if ([burnerPopup indexOfItemWithTitle:[[self savedDevice] displayName]] > -1)
	{
	[burnerPopup selectItemAtIndex:[burnerPopup indexOfItemWithTitle:[[self savedDevice] displayName]]];
	}
	
[self updateDevice:[self currentDevice]];

[[DRNotificationCenter currentRunLoopCenter] addObserver:self selector:@selector(statusChanged:) name:DRDeviceStatusChangedNotification object:nil];
[NSApp beginSheet:[self window] modalForWindow:window modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:window];
}

- (int)beginEraseWindow
{
[burnerPopup removeAllItems];

	int i;
	for (i=0;i< [[DRDevice devices] count];i++)
	{
	[burnerPopup addItemWithTitle:[[[DRDevice devices] objectAtIndex:i] displayName]];
	}
	
	if ([burnerPopup indexOfItemWithTitle:[[self savedDevice] displayName]] > -1)
	{
	[burnerPopup selectItemAtIndex:[burnerPopup indexOfItemWithTitle:[[self savedDevice] displayName]]];
	}
	
[self updateDevice:[self currentDevice]];

[[DRNotificationCenter currentRunLoopCenter] addObserver:self selector:@selector(statusChanged:) name:DRDeviceStatusChangedNotification object:nil];

int x = [NSApp runModalForWindow:[self window]];
[[self window] close];

return x;
}

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
[sheet orderOut:self];
[[DRNotificationCenter currentRunLoopCenter] removeObserver:self name:DRDeviceStatusChangedNotification object:nil];

	if (returnCode == NSOKButton)
	{
	[endDelegate performSelector:endSelector withObject:self withObject:(id)NSOKButton];
	}
	else
	{
	[endDelegate performSelector:endSelector withObject:self withObject:(id)NSCancelButton];
	}
}

- (void)erase
{
DRErase* erase = [[DRErase alloc] initWithDevice:[self currentDevice]];

	if ([completelyErase state] == NSOnState)
	[erase setEraseType:DREraseTypeComplete];
	else
	[erase setEraseType:DREraseTypeQuick];	
		
//Save burner
NSMutableDictionary *burnDict = [[NSMutableDictionary alloc] init];

[burnDict setObject:[[[self currentDevice] info] objectForKey:@"DRDeviceProductNameKey"] forKey:@"Product"];
[burnDict setObject:[[[self currentDevice] info] objectForKey:@"DRDeviceVendorNameKey"] forKey:@"Vendor"];
[burnDict setObject:@"" forKey:@"SerialNumber"];

[[NSUserDefaults standardUserDefaults] setObject:burnDict forKey:@"KWDefaultDeviceIdentifier"];

[[NSNotificationCenter defaultCenter] postNotificationName:@"KWMediaChanged" object:nil];
	
[burnDict release];

[[DRNotificationCenter currentRunLoopCenter] addObserver:self selector:@selector(eraseNotification:) name:DREraseStatusChangedNotification object:erase];	

[erase start];
}

- (void)updateDevice:(DRDevice *)device
{
	if ([[[device status] objectForKey:DRDeviceMediaStateKey] isEqualTo:DRDeviceMediaStateMediaPresent])
	{
		if ([[[[device status] objectForKey:DRDeviceMediaInfoKey] objectForKey:DRDeviceMediaIsErasableKey] boolValue])
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
	else if ([[[device status] objectForKey:DRDeviceMediaStateKey] isEqualTo:DRDeviceMediaStateInTransition])
	{
	[closeButton setEnabled:NO];
	[statusText setStringValue:NSLocalizedString(@"Waiting for the drive...", Localized)];
	[eraseButton setEnabled:NO];
	}
	else if ([[[device status] objectForKey:DRDeviceMediaStateKey] isEqualTo:DRDeviceMediaStateNone])
	{
		if ([[[device info] objectForKey:DRDeviceLoadingMechanismCanOpenKey] boolValue])
		{
		[closeButton setEnabled:YES];
		
			if ([[[device status] objectForKey:DRDeviceIsTrayOpenKey] boolValue])
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
	if ([[[[self currentDevice] info] objectForKey:DRDeviceLoadingMechanismCanOpenKey] boolValue])
	{
		if ([[[[self currentDevice] status] objectForKey:DRDeviceIsTrayOpenKey] boolValue] == NO)
		{
		[[self currentDevice] openTray];
		shouldClose = YES;
		}
	}
	
	int z;
	for (z=0;z<[[DRDevice devices] count];z++)
	{
	DRDevice *device = [[DRDevice devices] objectAtIndex:z];
		if ([[[device info] objectForKey:DRDeviceLoadingMechanismCanOpenKey] boolValue] && [[[device status] objectForKey:DRDeviceIsTrayOpenKey] boolValue] && !z == [burnerPopup indexOfSelectedItem])
		[device closeTray];
	}

[self updateDevice:[self currentDevice]];
}

- (IBAction)cancelButton:(id)sender
{
	if (shouldClose)
	[[[DRDevice devices] objectAtIndex:[burnerPopup indexOfSelectedItem]] closeTray];
	
	if ([[self window] isSheet])
	{
	[NSApp endSheet:[self window] returnCode:NSCancelButton];
	}
	else
	{
	[[DRNotificationCenter currentRunLoopCenter] removeObserver:self name:DREraseStatusChangedNotification object:nil];
	[NSApp stopModalWithCode:NSCancelButton];
	}
}

- (IBAction)closeButton:(id)sender
{
	if ([[closeButton title] isEqualTo:NSLocalizedString(@"Eject", Localized)])
	{
	[[[DRDevice devices] objectAtIndex:[burnerPopup indexOfSelectedItem]] ejectMedia];
	}
	else if ([[closeButton title] isEqualTo:NSLocalizedString(@"Close", Localized)])
	{
	[[[DRDevice devices] objectAtIndex:[burnerPopup indexOfSelectedItem]] closeTray];
	}
	else if ([[closeButton title] isEqualTo:NSLocalizedString(@"Open", Localized)])
	{
	shouldClose = YES;
	[[[DRDevice devices] objectAtIndex:[burnerPopup indexOfSelectedItem]] openTray];
	}
}

- (IBAction)eraseButton:(id)sender
{
	if ([[self window] isSheet])
	{
	[NSApp endSheet:[self window] returnCode:NSOKButton];
	}
	else
	{
	[[DRNotificationCenter currentRunLoopCenter] removeObserver:self name:DREraseStatusChangedNotification object:nil];
	[NSApp stopModalWithCode:NSOKButton];
	}
}

//////////////////////////
// Notification actions //
//////////////////////////

#pragma mark -
#pragma mark •• Notification actions

- (void)statusChanged:(NSNotification *)notif
{
	if ([[[notif object] displayName] isEqualTo:[burnerPopup title]])
	[self updateDevice:[notif object]];
}

- (void)eraseNotification:(NSNotification*)notification	
{	
NSDictionary* status = [notification userInfo];
NSString *time = @"";
	
	if ([[status objectForKey:DRStatusPercentCompleteKey] floatValue] > 0)
	{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWMaximumValueChanged" object:[NSNumber numberWithFloat:1.0]];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWValueChanged" object:[status objectForKey:DRStatusPercentCompleteKey]];
	time = [KWCommonMethods formatTime:[[[status objectForKey:DRStatusProgressInfoKey] objectForKey:@"DRStatusProgressRemainingTime"] intValue]];
	time = [[@" (" stringByAppendingString:time] stringByAppendingString:@")"];
	}
	else
	{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWMaximumValueChanged" object:[NSNumber numberWithFloat:0]];
	}

	if ([[status objectForKey:DRStatusStateKey] isEqualTo:DRStatusStatePreparing])
	{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWStatusChanged" object:NSLocalizedString(@"Preparing...", Localized)];
	}
	else if ([[status objectForKey:DRStatusStateKey] isEqualTo:DRStatusStateErasing])
	{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWStatusChanged" object:[NSLocalizedString(@"Erasing disc", Localized) stringByAppendingString:time]];
	}
	else if ([[status objectForKey:DRStatusStateKey] isEqualTo:DRStatusStateFinishing])
	{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWStatusChanged" object:NSLocalizedString(@"Finishing...", Localized)];
	}
	else if ([[status objectForKey:DRStatusStateKey] isEqualTo:DRStatusStateDone])
	{
	[[DRNotificationCenter currentRunLoopCenter] removeObserver:self name:DREraseStatusChangedNotification object:[notification object]];
	[[notification object] release];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWEraseFinished" object:self userInfo:[NSDictionary dictionaryWithObject:@"KWSucces" forKey:@"ReturnCode"]];
	}
	else if ([[status objectForKey:DRStatusStateKey] isEqualTo:DRStatusStateFailed])
	{
	[[DRNotificationCenter currentRunLoopCenter] removeObserver:self name:DREraseStatusChangedNotification object:[notification object]];
	[[notification object] release];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWEraseFinished" object:self userInfo:[NSDictionary dictionaryWithObject:@"KWFailure" forKey:@"ReturnCode"]];
	}
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
	
	int i;
	for (i=0;i< [devices count];i++)
	{
		if ([[[[devices objectAtIndex:i] info] objectForKey:@"DRDeviceProductNameKey"] isEqualTo:[[[NSUserDefaults standardUserDefaults] dictionaryForKey:@"KWDefaultDeviceIdentifier"] objectForKey:@"Product"]])
		{
		return [devices objectAtIndex:i];
		}
	}
	
return [devices objectAtIndex:0];
}

@end
