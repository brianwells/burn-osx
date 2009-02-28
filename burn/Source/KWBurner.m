#import "KWBurner.h"
#import "KWTrackProducer.h"
#import "KWCommonMethods.h"
#import "KWProgress.h"

@implementation KWBurner

- (id)init
{
self = [super init];

shouldClose = NO;
userCanceled = NO;
ignoreMode = NO;
[NSBundle loadNibNamed:@"KWBurner" owner:self];

return self;
}

- (void)dealloc
{
	if (imagePath)
	{
	[imagePath release];
	imagePath = nil;
	}

[super dealloc];
}

- (void)awakeFromNib
{
currentCombineCheckBox = combineCheckBox;
}

///////////////////
// Main actions //
///////////////////

#pragma mark -
#pragma mark •• Main actions

- (void)beginBurnSetupSheetForWindow:(NSWindow *)window modalDelegate:(id)delegate didEndSelector:(SEL)selector contextInfo:(void *)contextInfo
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

int height = 205;

	if (currentType < 3 && [combinableTypes count] > 1 && [combinableTypes containsObject:[NSNumber numberWithInt:currentType]])
	{
	[self prepareTypes];
	[combineCheckBox setHidden:NO];
	}
	else
	{
	height = height - 20;
	[combineCheckBox setHidden:YES];
	}
	
[[self window] setContentSize:NSMakeSize([[self window] frame].size.width,height)];

[[DRNotificationCenter currentRunLoopCenter] addObserver:self selector:@selector(statusChanged:) name:DRDeviceStatusChangedNotification object:nil];
[[DRNotificationCenter currentRunLoopCenter] addObserver:self selector:@selector(mediaChanged:) name:DRDeviceDisappearedNotification object:nil];
[[DRNotificationCenter currentRunLoopCenter] addObserver:self selector:@selector(mediaChanged:) name:DRDeviceAppearedNotification object:nil];
[NSApp beginSheet:[self window] modalForWindow:window modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:[[NSArray arrayWithObjects:delegate,NSStringFromSelector(selector), contextInfo,nil] retain]];
}

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
[sheet orderOut:self];
[[DRNotificationCenter currentRunLoopCenter] removeObserver:self name:DRDeviceStatusChangedNotification object:nil];
[[DRNotificationCenter currentRunLoopCenter] removeObserver:self name:DRDeviceDisappearedNotification object:nil];
[[DRNotificationCenter currentRunLoopCenter] removeObserver:self name:DRDeviceAppearedNotification object:nil];

	if (returnCode == NSOKButton)
	{
	//Save the preferences
	NSArray *speeds;
		if (ignoreMode == NO)
		speeds = [[[[self currentDevice] status] objectForKey:DRDeviceMediaInfoKey] objectForKey:DRDeviceBurnSpeedsKey];
	NSNumber *speed;

		if ([speedPopup indexOfSelectedItem] == 0 | ignoreMode == YES)
		speed = [NSNumber numberWithFloat:65535];
		else
		speed = [speeds objectAtIndex:[speedPopup indexOfSelectedItem] - 2];

	[[NSUserDefaults standardUserDefaults] setObject:speed forKey:@"DRBurnOptionsBurnSpeed"];

	NSMutableDictionary *burnDict = [[NSMutableDictionary alloc] init];

	[burnDict setObject:[[[self currentDevice] info] objectForKey:@"DRDeviceProductNameKey"] forKey:@"Product"];
	[burnDict setObject:[[[self currentDevice] info] objectForKey:@"DRDeviceVendorNameKey"] forKey:@"Vendor"];
	[burnDict setObject:@"" forKey:@"SerialNumber"];

	[[NSUserDefaults standardUserDefaults] setObject:burnDict forKey:@"KWDefaultDeviceIdentifier"];

	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWMediaChanged" object:nil];

	[burnDict release];

	//We're gonna store our setup values for later :-)
	savedDevice = [self currentDevice];

	NSMutableDictionary *mutableDict = [NSMutableDictionary dictionary];

		//Set speed
		if ([speedPopup indexOfSelectedItem] == 0 && ignoreMode == NO)
		[mutableDict setObject:[speeds objectAtIndex:[speeds count]-1] forKey:DRBurnRequestedSpeedKey];
		else
		[mutableDict setObject:speed forKey:DRBurnRequestedSpeedKey];
		//Set more sessions allowed
		if ([sessionsCheckBox state] == NSOnState)
		[mutableDict setObject:[NSNumber numberWithBool:YES] forKey:DRBurnAppendableKey];
		else
		[mutableDict setObject:[NSNumber numberWithBool:NO] forKey:DRBurnAppendableKey];
		//Set overwrite / erase before burning
		if ([eraseCheckBox state] == NSOnState)
		[mutableDict setObject:[NSNumber numberWithBool:YES] forKey:DRBurnOverwriteDiscKey];
		else
		[mutableDict setObject:[NSNumber numberWithBool:NO] forKey:DRBurnOverwriteDiscKey];
		//Set should verify from preferences
		[mutableDict setObject:[[NSUserDefaults standardUserDefaults] objectForKey:@"KWBurnOptionsVerifyBurn"] forKey:DRBurnVerifyDiscKey];
		//Set completion action from preferences if one disc
		[mutableDict setObject:[[NSUserDefaults standardUserDefaults] objectForKey:@"KWBurnOptionsCompletionAction"] forKey:DRBurnCompletionActionKey];

	properties = [mutableDict copy];

	SEL theSelector;
	NSMethodSignature *aSignature;
	NSInvocation *anInvocation;
	int returnCode = NSOKButton;
	id myContextInfo;
		
		if ([(NSArray *)contextInfo count] > 2)
		myContextInfo = [NSArray arrayWithArray:[(NSArray *)contextInfo objectAtIndex:2]];

	//Get selector
	theSelector = NSSelectorFromString([(NSArray *)contextInfo objectAtIndex:1]);
	//Get the methods signature and set the selector
	aSignature = [[[(NSArray *)contextInfo objectAtIndex:0] class] instanceMethodSignatureForSelector:theSelector];
	anInvocation = [NSInvocation invocationWithMethodSignature:aSignature];
	[anInvocation setSelector:theSelector];
	//Set arguments
	[anInvocation setArgument:&self atIndex:2];
	[anInvocation setArgument:&returnCode atIndex:3];
	[anInvocation setArgument:&myContextInfo atIndex:4];
	//Perform selector
	[anInvocation invokeWithTarget:[(NSArray *)contextInfo objectAtIndex:0]];

	[(NSArray *)contextInfo release];
	}
	else
	{
	SEL theSelector;
	NSMethodSignature *aSignature;
	NSInvocation *anInvocation;
	int returnCode = NSCancelButton;
	id myContextInfo;
	
		if ([(NSArray *)contextInfo count] > 2)
		myContextInfo = [NSArray arrayWithArray:[(NSArray *)contextInfo objectAtIndex:2]];

	//Get selector
	theSelector = NSSelectorFromString([(NSArray *)contextInfo objectAtIndex:1]);
	//Get the methods signature and set the selector
	aSignature = [[[(NSArray *)contextInfo objectAtIndex:0] class] instanceMethodSignatureForSelector:theSelector];
	anInvocation = [NSInvocation invocationWithMethodSignature:aSignature];
	[anInvocation setSelector:theSelector];
	//Set arguments
	[anInvocation setArgument:&self atIndex:2];
	[anInvocation setArgument:&returnCode atIndex:3];
	[anInvocation setArgument:&myContextInfo atIndex:4];
	//Perform selector
	[anInvocation invokeWithTarget:[(NSArray *)contextInfo objectAtIndex:0]];
	
	[(NSArray *)contextInfo release];
	}
}

- (void)burnDiskImageAtPath:(NSString *)path
{
size = [self getImageSizeAtPath:path];

	if ([self canBurn])
	{
		if (![KWCommonMethods isPanther] == NO)
		{
		burn = [[DRBurn alloc] initWithDevice:savedDevice];
		[burn setProperties:properties];
		[[DRNotificationCenter currentRunLoopCenter] addObserver:self selector:@selector(burnNotification:) name:DRBurnStatusChangedNotification object:burn];
		
		id layout = [DRBurn layoutForImageFile:path];
		
			if (!layout == nil)
			[burn writeLayout:layout];
			else
			[[NSNotificationCenter defaultCenter] postNotificationName:@"KWBurnFinished" object:self userInfo:[NSDictionary dictionaryWithObject:@"KWFailure" forKey:@"ReturnCode"]];
		}
		else
		{
			if ([[path pathExtension] isEqualTo:@"cue"])
			{
			burn = [[DRBurn alloc] initWithDevice:savedDevice];
			[burn setProperties:properties];
			[[DRNotificationCenter currentRunLoopCenter] addObserver:self selector:@selector(burnNotification:) name:DRBurnStatusChangedNotification object:burn];
			[burn writeLayout:[[KWTrackProducer alloc] getTracksOfCueFile:path]];
			}
			else
			{
			burn = [[DRBurn alloc] initWithDevice:savedDevice];
			[burn setProperties:properties];
			[[DRNotificationCenter currentRunLoopCenter] addObserver:self selector:@selector(burnNotification:) name:DRBurnStatusChangedNotification object:burn];
			[burn writeLayout:[[KWTrackProducer alloc] getTrackForImage:path withSize:0]];
			//[burn writeLayout:[[KWTrackProducer alloc] getTracksOfAudioCD]];
			}
		}
	}
	else
	{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWBurnFinished" object:self userInfo:[NSDictionary dictionaryWithObject:@"KWCanceled" forKey:@"ReturnCode"]];
	}
}

- (void)burnTrack:(id)track
{
BOOL hasTracks = YES;
	
	if ([track isKindOfClass:[DRTrack class]])
	{
	size = [track estimateLength] * 2048 / 1024;
	}
	else
	{
	int numberOfTracks = [(NSArray *)track count];

		if (numberOfTracks > 0)
		{
			int i;
			for (i=0;i<numberOfTracks;i++)
			{
			id newTrack = [(NSArray *)track objectAtIndex:i];

				if ([newTrack isKindOfClass:[DRTrack class]])
				{
				size = size + [(DRTrack *)newTrack estimateLength];
				}
				else
				{
					int i;
					for (i=0;i<[(NSArray *)newTrack count];i++)
					{
					size = size + [[(NSArray *)newTrack objectAtIndex:i] estimateLength];
					}
				}
			}
		}
		else
		{
		hasTracks = NO;
		}
	}
	
	if ([self canBurn])
	{
	burn = [[DRBurn alloc] initWithDevice:savedDevice];
	
	NSMutableDictionary *burnProperties = [[[NSMutableDictionary alloc] initWithDictionary:properties copyItems:YES] autorelease];
		if (extraBurnProperties)
		[burnProperties addEntriesFromDictionary:extraBurnProperties];
	[burn setProperties:burnProperties];
	[burn writeLayout:track];
	
		if ([[savedDevice status] objectForKey:DRDeviceMediaInfoKey])
		isOverwritable = [[[[savedDevice status] objectForKey:DRDeviceMediaInfoKey] objectForKey:DRDeviceMediaIsOverwritableKey] boolValue];
		else
		isOverwritable = NO;
		
	[[DRNotificationCenter currentRunLoopCenter] addObserver:self selector:@selector(burnNotification:) name:DRBurnStatusChangedNotification object:burn];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWCancelNotificationChanged" object:@"KWStopBurning"];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stopBurning:) name:@"KWStopBurning" object:nil];
	}
	else if (hasTracks == NO)
	{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWBurnFinished" object:self userInfo:[NSDictionary dictionaryWithObject:@"KWFailure" forKey:@"ReturnCode"]];
	}
	else
	{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWBurnFinished" object:self userInfo:[NSDictionary dictionaryWithObject:@"KWCanceled" forKey:@"ReturnCode"]];
	}
}

- (void)burnTrackToImage:(NSDictionary *)dict
{
NSString *path = [dict objectForKey:@"Path"];
id track =  [dict objectForKey:@"Track"];
BOOL hasTracks = YES;

	if ([track isKindOfClass:[DRTrack class]])
	{
	size = [track estimateLength] * 2048 / 1024;
	}
	else
	{
	int numberOfTracks = [(NSArray *)track count];
	
		if (numberOfTracks > 0)
		{
			int i;
			for (i=0;i<numberOfTracks;i++)
			{
			id newTrack = [(NSArray *)track objectAtIndex:i];

				if ([newTrack isKindOfClass:[DRTrack class]])
				{
				size = size + [(DRTrack *)newTrack estimateLength];
				}
				else
				{
					int i;
					for (i=0;i<[(NSArray *)newTrack count];i++)
					{
					size = size + [[(NSArray *)newTrack objectAtIndex:i] estimateLength];
					}
				}
			}
		}
		else
		{
		hasTracks = NO;
		}
	}
	
	if ( hasTracks == YES)
	{
	imagePath = [path copy];
	DRCallbackDevice *device = [[DRCallbackDevice alloc] init];
	[device initWithConsumer:self];
	burn = [[DRBurn alloc] initWithDevice:device];
	[burn writeLayout:track];
	
	isOverwritable = YES;
	
	[[DRNotificationCenter currentRunLoopCenter] addObserver:self selector:@selector(burnNotification:) name:DRBurnStatusChangedNotification object:burn];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWCancelNotificationChanged" object:@"KWStopBurning"];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stopBurning:) name:@"KWStopBurning" object:nil];
	}
	else if (hasTracks == NO)
	{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWBurnFinished" object:self userInfo:[NSDictionary dictionaryWithObject:@"KWFailure" forKey:@"ReturnCode"]];
	}
	else
	{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWBurnFinished" object:self userInfo:[NSDictionary dictionaryWithObject:@"KWCanceled" forKey:@"ReturnCode"]];
	}
}

- (int)getImageSizeAtPath:(NSString *)path
{
	if ([[path pathExtension] isEqualTo:@"cue"])
	{
	return (int)[[[[NSFileManager defaultManager] fileAttributesAtPath:[[path stringByDeletingPathExtension] stringByAppendingPathExtension:@"bin"] traverseLink:YES] objectForKey:NSFileSize] floatValue] / 1024;
	}
	else if ([[path pathExtension] isEqualTo:@"toc"])
	{
	float appendSize = 0;
	NSArray *paths = [[NSString stringWithContentsOfFile:path] componentsSeparatedByString:@"FILE \""];
	NSString  *filePath;
			
			int z;
			for (z=1;z<[paths count];z++)
			{
			filePath = [[[paths objectAtIndex:z] componentsSeparatedByString:@"\""] objectAtIndex:0];
			
				if ([[filePath stringByDeletingLastPathComponent] isEqualTo:@""])
				filePath = [[path stringByDeletingLastPathComponent] stringByAppendingPathComponent:filePath];
				
			appendSize = appendSize + [[[[NSFileManager defaultManager] fileAttributesAtPath:filePath traverseLink:YES] objectForKey:NSFileSize] floatValue];
			}
			
	return (int)appendSize / 1024;
	}
	else
	{
	return (int)[[[[NSFileManager defaultManager] fileAttributesAtPath:path traverseLink:YES] objectForKey:NSFileSize] floatValue] / 1024;
	}
}

- (void)updateDevice:(DRDevice *)device
{
	if (ignoreMode == YES)
	{
	[eraseCheckBox setEnabled:YES];
	[closeButton setEnabled:NO];
	[sessionsCheckBox setEnabled:YES];
	[closeButton setTitle:NSLocalizedString(@"Eject", Localized)];
	[statusText setStringValue:NSLocalizedString(@"Ready to copy", Localized)];
	[burnButton setEnabled:YES];
	}
	else if ([[[device status] objectForKey:DRDeviceMediaStateKey] isEqualTo:DRDeviceMediaStateMediaPresent])
	{
		if ([[[[device status] objectForKey:DRDeviceMediaInfoKey] objectForKey:DRDeviceMediaIsBlankKey] boolValue] | [[[[device status] objectForKey:DRDeviceMediaInfoKey] objectForKey:DRDeviceMediaIsAppendableKey] boolValue] | [[[[device status] objectForKey:DRDeviceMediaInfoKey] objectForKey:DRDeviceMediaIsOverwritableKey] boolValue])
		{
		[self populateSpeeds:device];
		[speedPopup setEnabled:YES];
				
			if ([[[[device status] objectForKey:DRDeviceMediaInfoKey] objectForKey:DRDeviceMediaIsErasableKey] boolValue] && [[[[device status] objectForKey:DRDeviceMediaInfoKey] objectForKey:DRDeviceMediaIsAppendableKey] boolValue] && [[[[device status] objectForKey:DRDeviceMediaInfoKey] objectForKey:DRDeviceMediaIsBlankKey] boolValue] == NO)
			[eraseCheckBox setEnabled:YES];
			else
			[eraseCheckBox setEnabled:NO];
			
			if ([[[[device status] objectForKey:DRDeviceMediaInfoKey] objectForKey:DRDeviceMediaIsErasableKey] boolValue] && [[[[device status] objectForKey:DRDeviceMediaInfoKey] objectForKey:DRDeviceMediaIsAppendableKey] boolValue] == NO && [[[[device status] objectForKey:DRDeviceMediaInfoKey] objectForKey:DRDeviceMediaIsBlankKey] boolValue] == NO)
			[eraseCheckBox setState:NSOnState];
			else
			[eraseCheckBox setState:NSOffState];

			if ([[[[device status] objectForKey:DRDeviceMediaInfoKey] objectForKey:DRDeviceMediaClassKey] isEqualTo:DRDeviceMediaClassCD])
			[sessionsCheckBox setEnabled:YES];
			else
			[sessionsCheckBox setEnabled:NO];
				
		[closeButton setEnabled:YES];
		[closeButton setTitle:NSLocalizedString(@"Eject", Localized)];
		
		[statusText setStringValue:NSLocalizedString(@"Ready to burn", Localized)];
		
		[burnButton setEnabled:YES];
		}
		else
		{
		[device ejectMedia];
		}
	}
	else if ([[[device status] objectForKey:DRDeviceMediaStateKey] isEqualTo:DRDeviceMediaStateInTransition])
	{
	[speedPopup setEnabled:NO];
	[eraseCheckBox setEnabled:NO];
	[eraseCheckBox setState:NSOffState];
	[sessionsCheckBox setEnabled:NO];
	[closeButton setEnabled:NO];
	[statusText setStringValue:NSLocalizedString(@"Waiting for the drive...", Localized)];
	[burnButton setEnabled:NO];
	}
	else if ([[[device status] objectForKey:DRDeviceMediaStateKey] isEqualTo:DRDeviceMediaStateNone])
	{
	[self populateSpeeds:device];
	[speedPopup setEnabled:NO];
	[eraseCheckBox setEnabled:NO];
	[eraseCheckBox setState:NSOffState];
	[sessionsCheckBox setEnabled:NO];
	
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
	[burnButton setEnabled:NO];
	}
}

////////////////////////
// Main Sheet actions //
////////////////////////

#pragma mark -
#pragma mark •• Main Sheet actions

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
	
[NSApp endSheet:[self window] returnCode:NSCancelButton];
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

- (IBAction)burnButton:(id)sender
{
[NSApp endSheet:[self window] returnCode:NSOKButton];
}

- (IBAction)combineSessions:(id)sender
{
	if ([sender state] == NSOnState)
	[NSApp runModalForWindow:sessionsPanel];
}

///////////////////////////
// Session Sheet actions //
///////////////////////////

#pragma mark -
#pragma mark •• Session Sheet actions

- (IBAction)okSession:(id)sender
{
[NSApp stopModal];
[sessionsPanel orderOut:self];
}

- (IBAction)cancelSession:(id)sender
{
[NSApp stopModal];
[sessionsPanel orderOut:self];
[currentCombineCheckBox setState:NSOffState];
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

- (void)mediaChanged:(NSNotification *)notification
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
}

- (void)burnNotification:(NSNotification*)notification	
{
NSDictionary *status = [notification userInfo];
	
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWDebug"] == YES)
	NSLog([status description]);

NSString *time = @"";
	
	if ([[status objectForKey:DRStatusPercentCompleteKey] floatValue] > 0)
	{
		if (![[status objectForKey:DRStatusStateKey] isEqualTo:DRStatusStateTrackOpen])
		{
		NSNumber *percent = [NSNumber numberWithFloat:[[status objectForKey:DRStatusPercentCompleteKey] floatValue] * 100];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"KWMaximumValueChanged" object:[NSNumber numberWithFloat:1.0]];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"KWValueChanged" object:[status objectForKey:DRStatusPercentCompleteKey]];
			if (!imagePath)
			time = [KWCommonMethods formatTime:size / [[status objectForKey:DRStatusCurrentSpeedKey] intValue] - (size / [[status objectForKey:DRStatusCurrentSpeedKey] intValue] * [percent intValue] / 100)];
			else
			time = [[[[percent stringValue] componentsSeparatedByString:@"."] objectAtIndex:0]  stringByAppendingString:@"%"];
		time = [[@" (" stringByAppendingString:time] stringByAppendingString:@")"];
		}
	}
	else
	{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWMaximumValueChanged" object:[NSNumber numberWithFloat:0]];
	}
	
	if ([[status objectForKey:DRStatusStateKey] isEqualTo:DRStatusStatePreparing])
	{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWStatusChanged" object:NSLocalizedString(@"Preparing...", Localized)];
	}
	else if ([[status objectForKey:DRStatusStateKey] isEqualTo:DRStatusStateTrackOpen])
	{
		if ([[status objectForKey:DRStatusTotalTracksKey] intValue] > 1)
		[[NSNotificationCenter defaultCenter] postNotificationName:@"KWStatusChanged" object:[NSLocalizedString(@"Opening track ", Localized) stringByAppendingString:[[status objectForKey:DRStatusCurrentTrackKey] stringValue]]];
		else
		[[NSNotificationCenter defaultCenter] postNotificationName:@"KWStatusChanged" object:NSLocalizedString(@"Opening track", Localized)];
	}
	else if ([[status objectForKey:DRStatusStateKey] isEqualTo:DRStatusStateTrackWrite])
	{
		if ([[status objectForKey:DRStatusTotalTracksKey] intValue] > 1)
		[[NSNotificationCenter defaultCenter] postNotificationName:@"KWStatusChanged" object:[[[[NSLocalizedString(@"Writing track ", Localized) stringByAppendingString:[[status objectForKey:DRStatusCurrentTrackKey] stringValue]] stringByAppendingString:NSLocalizedString(@" of ", Localized)] stringByAppendingString:[[status objectForKey:DRStatusTotalTracksKey] stringValue]] stringByAppendingString:time]];
		else
		[[NSNotificationCenter defaultCenter] postNotificationName:@"KWStatusChanged" object:[NSLocalizedString(@"Writing track", Localized) stringByAppendingString:time]];
	}
	else if ([[status objectForKey:DRStatusStateKey] isEqualTo:DRStatusStateTrackClose])
	{
		if ([[status objectForKey:DRStatusTotalTracksKey] intValue] > 1)
		[[NSNotificationCenter defaultCenter] postNotificationName:@"KWStatusChanged" object:[[[NSLocalizedString(@"Closing track ", Localized) stringByAppendingString:[[status objectForKey:DRStatusCurrentTrackKey] stringValue]] stringByAppendingString:NSLocalizedString(@" of ", Localized)] stringByAppendingString:[[status objectForKey:DRStatusTotalTracksKey] stringValue]]];
		else
		[[NSNotificationCenter defaultCenter] postNotificationName:@"KWStatusChanged" object:NSLocalizedString(@"Closing track", Localized)];
	}
	else if ([[status objectForKey:DRStatusStateKey] isEqualTo:DRStatusStateSessionClose])
	{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWStatusChanged" object:NSLocalizedString(@"Closing session", Localized)];
	}
	else if ([[status objectForKey:DRStatusStateKey] isEqualTo:DRStatusStateFinishing])
	{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWStatusChanged" object:NSLocalizedString(@"Finishing...", Localized)];
	}
	else if ([[status objectForKey:DRStatusStateKey] isEqualTo:DRStatusStateVerifying])
	{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWStatusChanged" object:NSLocalizedString(@"Verifying...", Localized)];
	}
	else if ([[status objectForKey:DRStatusStateKey] isEqualTo:DRStatusStateDone])
	{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWCancelNotificationChanged" object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[[DRNotificationCenter currentRunLoopCenter] removeObserver:self name:DRBurnStatusChangedNotification object:[notification object]];
		
	[burn release];
	
	[properties release];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWBurnFinished" object:self userInfo:[NSDictionary dictionaryWithObject:@"KWSucces" forKey:@"ReturnCode"]];
	}
	else if ([[status objectForKey:DRStatusStateKey] isEqualTo:DRStatusStateFailed])
	{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWCancelNotificationChanged" object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[[DRNotificationCenter currentRunLoopCenter] removeObserver:self name:DRBurnStatusChangedNotification object:[notification object]];
		
	[burn release];
		
		if (userCanceled)
		{
		[[NSNotificationCenter defaultCenter] postNotificationName:@"KWBurnFinished" object:self userInfo:[NSDictionary dictionaryWithObject:@"KWCanceled" forKey:@"ReturnCode"]];
		}
		else
		{
			if ([[status objectForKey:DRErrorStatusKey] objectForKey:DRErrorStatusErrorInfoStringKey])
			[[NSNotificationCenter defaultCenter] postNotificationName:@"KWBurnFinished" object:self userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"KWFailure",[[status objectForKey:DRErrorStatusKey] objectForKey:DRErrorStatusErrorInfoStringKey],nil] forKeys:[NSArray arrayWithObjects:@"ReturnCode",@"Error",nil]]];
			else
			[[NSNotificationCenter defaultCenter] postNotificationName:@"KWBurnFinished" object:self userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"KWFailure",[[status objectForKey:DRErrorStatusKey] objectForKey:DRErrorStatusErrorStringKey],nil] forKeys:[NSArray arrayWithObjects:@"ReturnCode",@"Error",nil]]];
		}
		
	[properties release];
	}
}

///////////////////
// Image actions //
///////////////////

#pragma mark -
#pragma mark •• Image actions

- (BOOL)writeBlocks:(char*)wBlocks blockCount:(uint32_t)bCount blockSize:(uint32_t)bSize atAddress:(uint64_t)address
{
NSOutputStream *imageStream = [NSOutputStream outputStreamToFileAtPath:imagePath append:YES];
[imageStream open];	
[imageStream write:(const uint8_t *)wBlocks maxLength:bSize * bCount];
[imageStream close];

return NO;
}

- (BOOL)prepareBurn:(DRBurn *)burnObject
{
return NO;
}

- (BOOL)prepareTrack:(id)track trackIndex:(id)index
{
trackNumber = trackNumber + 1;
return NO;
}

- (BOOL)prepareSession:(id)session sessionIndex:(id)index
{
return NO;
}

- (BOOL)cleanupSessionAfterBurn:(id)session sessionIndex:(id)index
{
return NO;
}

- (BOOL)cleanupAfterBurn:(DRBurn *)burnObject
{
return NO;
}

- (BOOL)cleanupTrackAfterBurn:(DRTrack *)track trackIndex:(id)index
{
return NO;
}

///////////////////
// Other actions //
///////////////////

#pragma mark -
#pragma mark •• Other actions

- (void)setIgnoreMode:(BOOL)mode
{
ignoreMode = mode;
}

- (void)prepareTypes
{
[[sessions cellWithTag:0] setState:NSOffState];
[[sessions cellWithTag:1] setState:NSOffState];
[[sessions cellWithTag:2] setState:NSOffState];
[[sessions cellWithTag:currentType] setEnabled:NO];
[[sessions cellWithTag:currentType] setState:NSOnState];
	
	if (![combinableTypes containsObject:[NSNumber numberWithInt:0]])
	[[sessions cellWithTag:0] setEnabled:NO];
		
	if (![combinableTypes containsObject:[NSNumber numberWithInt:1]])
	[[sessions cellWithTag:1] setEnabled:NO];
		
	if (![combinableTypes containsObject:[NSNumber numberWithInt:2]])
	[[sessions cellWithTag:2] setEnabled:NO];
}

- (void)setCombineBox:(id)box
{
currentCombineCheckBox = box;
}

- (DRDevice *)currentDevice
{
return [[DRDevice devices] objectAtIndex:[burnerPopup indexOfSelectedItem]];
}

- (void)populateSpeeds:(DRDevice *)device
{
NSArray *speeds = [[[device status] objectForKey:DRDeviceMediaInfoKey] objectForKey:DRDeviceBurnSpeedsKey];
int speed;
[speedPopup removeAllItems];

	if ([speeds count] > 0)
	{
		int z;
		for (z=0;z<[speeds count];z++)
		{
			if ([[[[device status] objectForKey:DRDeviceMediaInfoKey] objectForKey:DRDeviceMediaClassKey] isEqualTo:DRDeviceMediaClassCD])
			speed = round([[speeds objectAtIndex:z] floatValue] / DRDeviceBurnSpeedCD1x);
			else
			speed = round([[speeds objectAtIndex:z] floatValue] / DRDeviceBurnSpeedDVD1x);

		[speedPopup addItemWithTitle:[[[NSNumber numberWithInt:speed] stringValue] stringByAppendingString:@"x"]];
		}

		if ([[[[device status] objectForKey:DRDeviceMediaInfoKey] objectForKey:DRDeviceMediaClassKey] isEqualTo:DRDeviceMediaClassCD])
		speed = round([[speeds objectAtIndex:[speeds count]-1] floatValue] / DRDeviceBurnSpeedCD1x);
		else
		speed = round([[speeds objectAtIndex:[speeds count]-1] floatValue] / DRDeviceBurnSpeedDVD1x);

	[speedPopup insertItemWithTitle:[[[NSLocalizedString(@"Maximum Possible", Localized) stringByAppendingString:@" ("] stringByAppendingString:[[NSNumber numberWithInt:speed] stringValue]] stringByAppendingString:@"x)"] atIndex:0];
	[[speedPopup menu] insertItem:[NSMenuItem separatorItem] atIndex:1];


		if (![[NSUserDefaults standardUserDefaults] objectForKey:@"DRBurnOptionsBurnSpeed"] == nil)
		{
			if ([speeds containsObject:[[NSUserDefaults standardUserDefaults] objectForKey:@"DRBurnOptionsBurnSpeed"]])
			{
			[speedPopup selectItemAtIndex:[speeds indexOfObject:[[NSUserDefaults standardUserDefaults] objectForKey:@"DRBurnOptionsBurnSpeed"]] + 2];
			}
			else
			{
			[speedPopup selectItemAtIndex:0];
			}
		}
		else
		{
		[speedPopup selectItemAtIndex:0];
		}
	}
	else
	{
	[speedPopup addItemWithTitle:NSLocalizedString(@"Maximum Possible", Localized)];
	}
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

- (BOOL)canBurn
{
int space;

	if ([[[[savedDevice status] objectForKey:DRDeviceMediaInfoKey] objectForKey:DRDeviceMediaIsBlankKey] boolValue])
	{
	space = [[[[savedDevice status] objectForKey:DRDeviceMediaInfoKey] objectForKey:DRDeviceMediaFreeSpaceKey] floatValue] * 2048 / 1024;
	}
	else if ([[[[savedDevice status] objectForKey:DRDeviceMediaInfoKey] objectForKey:DRDeviceMediaClassKey] isEqualTo:DRDeviceMediaClassDVD])
	{
	space = [[[[savedDevice status] objectForKey:DRDeviceMediaInfoKey] objectForKey:DRDeviceMediaOverwritableSpaceKey] floatValue] * 2048 / 1024;
	}
	else
	{
	
	space = [[DRMSF msfWithString:[[KWCommonMethods defaultSizeForMedia:1] stringByAppendingString:@":00:00"]] intValue] * 2048 / 1024;
	}
		
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWAllowOverBurning"])
	{
	return YES;
	}
	else if (space < size)
	{
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert addButtonWithTitle:NSLocalizedString(@"Yes", Localized)];
	[alert addButtonWithTitle:NSLocalizedString(@"No", Localized)];
	[alert setMessageText:NSLocalizedString(@"Not enough space", Localized)];
	[alert setInformativeText:NSLocalizedString(@"Still try to burn the disc?", Localized)];
	[alert setAlertStyle:NSWarningAlertStyle];
		
	return ([alert runModal] == NSAlertFirstButtonReturn);
	}
	else
	{
	return YES;
	}
}

- (void)stopBurning:(NSNotification *)notif
{
	if (isOverwritable)
	{
	userCanceled = YES;
	[burn abort];
	}
	else
	{
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert addButtonWithTitle:NSLocalizedString(@"Yes", Localized)];
	[alert addButtonWithTitle:NSLocalizedString(@"No", Localized)];
	[alert setMessageText:NSLocalizedString(@"Are you sure you want to cancel?", Localized)];
	[alert setInformativeText:NSLocalizedString(@"After canceling the disc can't be used anymore?", Localized)];
	[alert setAlertStyle:NSWarningAlertStyle];

		if ([alert runModal] == NSAlertFirstButtonReturn)
		{
		userCanceled = YES;
		[burn abort];
		}
	}
}

- (BOOL)isCD
{
return [[[[savedDevice status] objectForKey:DRDeviceMediaInfoKey] objectForKey:DRDeviceMediaClassKey] isEqualTo:DRDeviceMediaClassCD];
}

- (void)setType:(int)type
{
currentType = type;
}

- (void)setCombinableTypes:(NSArray *)types
{
combinableTypes = types;
}

- (int)currentType
{
return currentType;
}

- (NSArray *)types
{
	if ([currentCombineCheckBox state] == NSOnState)
	{
	NSMutableArray *types = [NSMutableArray array];
		
		if ([dataSession state] == NSOnState)
		[types addObject:[NSNumber numberWithInt:0]];
		
		if ([audioSession state] == NSOnState)
		[types addObject:[NSNumber numberWithInt:1]];
		
		if ([videoSession state] == NSOnState)
		[types addObject:[NSNumber numberWithInt:2]];
		
	return [types copy];
	}
	else
	{
	return [NSArray arrayWithObject:[NSNumber numberWithInt:currentType]];
	}
}

- (void)addBurnProperties:(NSDictionary *)burnProperties
{
extraBurnProperties = burnProperties;
}

- (NSDictionary *)properties
{
return properties;
}

@end
