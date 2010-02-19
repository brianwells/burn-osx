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
	NSWindow *myWindow = [self window];

	[burnerPopup removeAllItems];

	int i;
	for (i=0;i< [[DRDevice devices] count];i++)
	{
		NSString *displayName = [[[DRDevice devices] objectAtIndex:i] displayName];
		[burnerPopup addItemWithTitle:displayName];
	}
	
	NSString *displayName = [[self savedDevice] displayName];
	if ([burnerPopup indexOfItemWithTitle:displayName] > -1)
		[burnerPopup selectItemAtIndex:[burnerPopup indexOfItemWithTitle:displayName]];
	
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
	
	[myWindow setContentSize:NSMakeSize([myWindow frame].size.width,height)];
	
	DRNotificationCenter *currentCenter = [DRNotificationCenter currentRunLoopCenter];
	[currentCenter addObserver:self selector:@selector(statusChanged:) name:DRDeviceStatusChangedNotification object:nil];
	[currentCenter addObserver:self selector:@selector(mediaChanged:) name:DRDeviceDisappearedNotification object:nil];
	[currentCenter addObserver:self selector:@selector(mediaChanged:) name:DRDeviceAppearedNotification object:nil];
	[NSApp beginSheet:myWindow modalForWindow:window modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:[[NSArray arrayWithObjects:delegate,NSStringFromSelector(selector), contextInfo,nil] retain]];
}

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[sheet orderOut:self];
	
	DRNotificationCenter *currentCenter = [DRNotificationCenter currentRunLoopCenter];
	[currentCenter removeObserver:self name:DRDeviceStatusChangedNotification object:nil];
	[currentCenter removeObserver:self name:DRDeviceDisappearedNotification object:nil];
	[currentCenter removeObserver:self name:DRDeviceAppearedNotification object:nil];

	if (returnCode == NSOKButton)
	{
		//Save the preferences
		NSArray *speeds;
		DRDevice *currentDevice = [self currentDevice];
		NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];
		
			if (ignoreMode == NO)
			speeds = [[[currentDevice status] objectForKey:DRDeviceMediaInfoKey] objectForKey:DRDeviceBurnSpeedsKey];
		
		NSNumber *speed;

		if ([speedPopup indexOfSelectedItem] == 0 | ignoreMode == YES)
			speed = [NSNumber numberWithFloat:65535];
		else
			speed = [speeds objectAtIndex:[speedPopup indexOfSelectedItem] - 2];

		[standardDefaults setObject:speed forKey:@"DRBurnOptionsBurnSpeed"];

		NSMutableDictionary *burnDict = [[NSMutableDictionary alloc] init];
		NSDictionary *deviceInfo = [currentDevice info];

		[burnDict setObject:[deviceInfo objectForKey:@"DRDeviceProductNameKey"] forKey:@"Product"];
		[burnDict setObject:[deviceInfo objectForKey:@"DRDeviceVendorNameKey"] forKey:@"Vendor"];
		[burnDict setObject:@"" forKey:@"SerialNumber"];

		[standardDefaults setObject:burnDict forKey:@"KWDefaultDeviceIdentifier"];

		[[NSNotificationCenter defaultCenter] postNotificationName:@"KWMediaChanged" object:nil];

		[burnDict release];

		//We're gonna store our setup values for later :-)
		savedDevice = currentDevice;

		NSMutableDictionary *mutableDict = [NSMutableDictionary dictionary];

		//Set speed
		if ([speedPopup indexOfSelectedItem] == 0 && ignoreMode == NO)
			[mutableDict setObject:[speeds objectAtIndex:[speeds count]-1] forKey:DRBurnRequestedSpeedKey];
		else
			[mutableDict setObject:speed forKey:DRBurnRequestedSpeedKey];
		//Set more sessions allowed
		[mutableDict setObject:[NSNumber numberWithBool:([sessionsCheckBox state] == NSOnState)] forKey:DRBurnAppendableKey];
		//Set overwrite / erase before burning
		[mutableDict setObject:[NSNumber numberWithBool:([eraseCheckBox state] == NSOnState)] forKey:DRBurnOverwriteDiscKey];
		//Set should verify from preferences
		[mutableDict setObject:[standardDefaults objectForKey:@"KWBurnOptionsVerifyBurn"] forKey:DRBurnVerifyDiscKey];
		//Set completion action from preferences if one disc
		[mutableDict setObject:[standardDefaults objectForKey:@"KWBurnOptionsCompletionAction"] forKey:DRBurnCompletionActionKey];

		properties = [mutableDict copy];
	}
	
	SEL theSelector;
	NSMethodSignature *aSignature;
	NSInvocation *anInvocation;
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

- (void)burnDiskImageAtPath:(NSString *)path
{
	size = [self getImageSizeAtPath:path];

	if ([self canBurn])
	{
		burn = [[DRBurn alloc] initWithDevice:savedDevice];
		[burn setProperties:properties];
		[[DRNotificationCenter currentRunLoopCenter] addObserver:self selector:@selector(burnNotification:) name:DRBurnStatusChangedNotification object:burn];
	
		if ([KWCommonMethods OSVersion] >= 0x1040)
		{
			#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_4
			id layout = [DRBurn layoutForImageFile:path];
		
			if (!layout == nil)
				[burn writeLayout:layout];
			else
				[[NSNotificationCenter defaultCenter] postNotificationName:@"KWBurnFinished" object:self userInfo:[NSDictionary dictionaryWithObject:@"KWFailure" forKey:@"ReturnCode"]];
			#endif
		}
		else
		{
			if ([[path pathExtension] isEqualTo:@"cue"])
				[burn writeLayout:[[KWTrackProducer alloc] getTracksOfCueFile:path]];
			else
				[burn writeLayout:[[KWTrackProducer alloc] getTrackForImage:path withSize:0]];
		}
	}
	else
	{
		[[NSNotificationCenter defaultCenter] postNotificationName:@"KWBurnFinished" object:self userInfo:[NSDictionary dictionaryWithObject:@"KWCanceled" forKey:@"ReturnCode"]];
	}
}

- (void)writeTrack:(id)track
{
	BOOL hasTracks = YES;
	id burnTrack = track;
	
	if ([track isKindOfClass:[DRTrack class]])
	{
		size = [track estimateLength];
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
			
				if ([newTrack isKindOfClass:[NSDictionary class]])
				{
					burnTrack = newTrack;
					newTrack = [newTrack objectForKey:@"_DRBurnCueLayout"];
				}

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
	
	if (hasTracks == NO)
	{
		[burn release];
	
		[[NSNotificationCenter defaultCenter] postNotificationName:@"KWBurnFinished" object:self userInfo:[NSDictionary dictionaryWithObject:@"KWFailure" forKey:@"ReturnCode"]];
	}
	else if ([self canBurn])
	{
		[burn writeLayout:burnTrack];
		
		[[DRNotificationCenter currentRunLoopCenter] addObserver:self selector:@selector(burnNotification:) name:DRBurnStatusChangedNotification object:burn];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"KWCancelNotificationChanged" object:@"KWStopBurning"];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stopBurning:) name:@"KWStopBurning" object:nil];
	}
	else
	{
		[burn release];
	
		[[NSNotificationCenter defaultCenter] postNotificationName:@"KWBurnFinished" object:self userInfo:[NSDictionary dictionaryWithObject:@"KWCanceled" forKey:@"ReturnCode"]];
	}
}

- (void)burnTrack:(id)track
{
	burn = [[DRBurn alloc] initWithDevice:savedDevice];
	
	NSMutableDictionary *burnProperties = [[[NSMutableDictionary alloc] initWithDictionary:properties copyItems:YES] autorelease];
	
	if (extraBurnProperties)
		[burnProperties addEntriesFromDictionary:extraBurnProperties];
	
	[burnProperties setObject:[[NSUserDefaults standardUserDefaults] objectForKey:@"KWSimulateBurn"] forKey:DRBurnTestingKey];
	[burnProperties setObject:[NSNumber numberWithInt:0.5] forKey:@"DRBurnDoubleLayerL0DataZoneBlocksKey"];
	
	[burn setProperties:burnProperties];
	[self writeTrack:track];
	
	if ([[savedDevice status] objectForKey:DRDeviceMediaInfoKey])
		isOverwritable = [[[[savedDevice status] objectForKey:DRDeviceMediaInfoKey] objectForKey:DRDeviceMediaIsOverwritableKey] boolValue];
	else
		isOverwritable = NO;
}

- (void)burnTrackToImage:(NSDictionary *)dict
{
	NSString *path = [dict objectForKey:@"Path"];
	id track =  [dict objectForKey:@"Track"];
	
	if ([[path pathExtension] isEqualTo:@"cue"])
		path = [[path stringByDeletingPathExtension] stringByAppendingPathExtension:@"bin"];
	
	imagePath = [path copy];
	DRCallbackDevice *device = [[DRCallbackDevice alloc] init];
	[device initWithConsumer:self];
	burn = [[DRBurn alloc] initWithDevice:device];
	[self writeTrack:track];
	
	isOverwritable = YES;
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
		
			NSDictionary *mediaInfo = [[device status] objectForKey:DRDeviceMediaInfoKey];
			BOOL erasable = [[mediaInfo objectForKey:DRDeviceMediaIsErasableKey] boolValue];
			BOOL appendable = [[mediaInfo objectForKey:DRDeviceMediaIsAppendableKey] boolValue];
			BOOL blank = [[mediaInfo objectForKey:DRDeviceMediaIsBlankKey] boolValue];
			BOOL isCD = [[mediaInfo objectForKey:DRDeviceMediaClassKey] isEqualTo:DRDeviceMediaClassCD];
			
			[eraseCheckBox setEnabled:(erasable && appendable && !blank)];
			[eraseCheckBox setState:(erasable && !appendable && !blank)];
			[sessionsCheckBox setEnabled:isCD];
				
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
	DRDevice *currentDevice = [self currentDevice];

	if ([[[currentDevice info] objectForKey:DRDeviceLoadingMechanismCanOpenKey] boolValue])
	{
		if ([[[currentDevice status] objectForKey:DRDeviceIsTrayOpenKey] boolValue] == NO)
		{
			[currentDevice openTray];
			shouldClose = YES;
		}
	}
	
	NSArray *devices = [DRDevice devices];
	
	int z;
	for (z=0;z<[devices count];z++)
	{
		DRDevice *device = [devices objectAtIndex:z];
		if ([[[device info] objectForKey:DRDeviceLoadingMechanismCanOpenKey] boolValue] && [[[device status] objectForKey:DRDeviceIsTrayOpenKey] boolValue] && !z == [burnerPopup indexOfSelectedItem])
			[device closeTray];
	}

	[self updateDevice:currentDevice];
}

- (IBAction)cancelButton:(id)sender
{
	if (shouldClose)
		[[self currentDevice] closeTray];
	
	[NSApp endSheet:[self window] returnCode:NSCancelButton];
}

- (IBAction)closeButton:(id)sender
{
	DRDevice *currentDevice = [self currentDevice];
	NSString *closeButtonTitle = [closeButton title];

	if ([closeButtonTitle isEqualTo:NSLocalizedString(@"Eject", Localized)])
	{
		[currentDevice ejectMedia];
	}
	else if ([closeButtonTitle isEqualTo:NSLocalizedString(@"Close", Localized)])
	{
		[currentDevice closeTray];
	}
	else if ([closeButtonTitle isEqualTo:NSLocalizedString(@"Open", Localized)])
	{
		shouldClose = YES;
		[currentDevice openTray];
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
	DRDevice *device = [notif object];

	if ([[device displayName] isEqualTo:[burnerPopup title]])
	[self updateDevice:device];
}

- (void)mediaChanged:(NSNotification *)notification
{
	[burnerPopup removeAllItems];
	
	NSArray *devices = [DRDevice devices];

	int i;
	for (i=0;i< [devices count];i++)
	{
		[burnerPopup addItemWithTitle:[[devices objectAtIndex:i] displayName]];
	}
	
	NSString *saveDeviceName = [[self savedDevice] displayName];
	
	if ([burnerPopup indexOfItemWithTitle:saveDeviceName] > -1)
	{
		[burnerPopup selectItemAtIndex:[burnerPopup indexOfItemWithTitle:saveDeviceName]];
	}
	
	[self updateDevice:[self currentDevice]];
}

- (void)burnNotification:(NSNotification*)notification	
{
	NSDictionary *status = [notification userInfo];
	NSString *currentStatusString = [status objectForKey:DRStatusStateKey];
	NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
	NSString *time = nil;
	NSString *statusString = nil;
	
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWDebug"])
		NSLog([status description]);
	
	if ([[status objectForKey:DRStatusPercentCompleteKey] floatValue] > 0)
	{
		if (![currentStatusString isEqualTo:DRStatusStateTrackOpen])
		{
			NSNumber *percent = [status objectForKey:DRStatusPercentCompleteKey];
			float currentPercent = [percent floatValue];
			[defaultCenter postNotificationName:@"KWMaximumValueChanged" object:[NSNumber numberWithFloat:1.0]];
			[defaultCenter postNotificationName:@"KWValueChanged" object:percent];
			
			if (!imagePath)
			{
				float currentSpeed = [[status objectForKey:DRStatusCurrentSpeedKey] floatValue];
				time = [KWCommonMethods formatTime:size / currentSpeed - (size / currentSpeed * currentPercent)];
			}
			else
			{
				time = [NSString stringWithFormat:@"%.0f%@", currentPercent * 100, @"%"];
			}
		}
	}
	else
	{
		[defaultCenter postNotificationName:@"KWMaximumValueChanged" object:[NSNumber numberWithFloat:0]];
	}
	
	if ([currentStatusString isEqualTo:DRStatusStatePreparing])
	{
		statusString = NSLocalizedString(@"Preparing...", Localized);
	}
	else if ([currentStatusString isEqualTo:DRStatusStateTrackOpen])
	{
		if ([[status objectForKey:DRStatusTotalTracksKey] intValue] > 1)
			statusString = [NSString stringWithFormat:NSLocalizedString(@"Opening track %ld", nil),[[status objectForKey:DRStatusCurrentTrackKey] longValue]];
		else
			statusString = NSLocalizedString(@"Opening track", Localized);
	}
	else if ([currentStatusString isEqualTo:DRStatusStateTrackWrite])
	{
		if (time)
		{
			if ([[status objectForKey:DRStatusTotalTracksKey] intValue] > 1)
				statusString = [NSString stringWithFormat:NSLocalizedString(@"Writing track %ld of %ld (%@)", nil), [[status objectForKey:DRStatusCurrentTrackKey] longValue], [[status objectForKey:DRStatusTotalTracksKey] longValue], time];
			else
				statusString = [NSString stringWithFormat:NSLocalizedString(@"Writing track (%@)", nil), time];
		}
	}
	else if ([currentStatusString isEqualTo:DRStatusStateTrackClose])
	{
		if ([[status objectForKey:DRStatusTotalTracksKey] intValue] > 1)
			statusString = [NSString stringWithFormat:NSLocalizedString(@"Closing track %ld of %ld (%@)", nil), [[status objectForKey:DRStatusCurrentTrackKey] longValue], [[status objectForKey:DRStatusTotalTracksKey] longValue], time];
		else
			statusString = [NSString stringWithFormat:NSLocalizedString(@"Closing track (%@)", nil), time];
	}
	else if ([currentStatusString isEqualTo:DRStatusStateSessionClose])
	{
		statusString = NSLocalizedString(@"Closing session", Localized);
	}
	else if ([currentStatusString isEqualTo:DRStatusStateFinishing])
	{
		statusString = NSLocalizedString(@"Finishing...", Localized);
	}
	else if ([currentStatusString isEqualTo:DRStatusStateVerifying])
	{
		statusString = NSLocalizedString(@"Verifying...", Localized);
	}
	else if ([currentStatusString isEqualTo:DRStatusStateDone])
	{
		[defaultCenter postNotificationName:@"KWCancelNotificationChanged" object:nil];
		[defaultCenter removeObserver:self];
		[[DRNotificationCenter currentRunLoopCenter] removeObserver:self name:DRBurnStatusChangedNotification object:[notification object]];
		
		[burn release];
	
		[properties release];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"KWBurnFinished" object:self userInfo:[NSDictionary dictionaryWithObject:@"KWSucces" forKey:@"ReturnCode"]];
	}
	else if ([currentStatusString isEqualTo:DRStatusStateFailed])
	{
		[defaultCenter postNotificationName:@"KWCancelNotificationChanged" object:nil];
		[defaultCenter removeObserver:self];
		[[DRNotificationCenter currentRunLoopCenter] removeObserver:self name:DRBurnStatusChangedNotification object:[notification object]];
		
		[burn release];
		
		if (userCanceled)
		{
			[defaultCenter postNotificationName:@"KWBurnFinished" object:self userInfo:[NSDictionary dictionaryWithObject:@"KWCanceled" forKey:@"ReturnCode"]];
		}
		else
		{
			NSString *errorString;
		
			if ([[status objectForKey:DRErrorStatusKey] objectForKey:@"DRErrorStatusErrorInfoStringKey"])
				errorString = [[status objectForKey:DRErrorStatusKey] objectForKey:@"DRErrorStatusErrorInfoStringKey"];
			else
				errorString = [[status objectForKey:DRErrorStatusKey] objectForKey:DRErrorStatusErrorStringKey];
		NSLog(errorString);
			[defaultCenter postNotificationName:@"KWBurnFinished" object:self userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"KWFailure", errorString,nil] forKeys:[NSArray arrayWithObjects:@"ReturnCode",@"Error",nil]]];
		}
		
		[properties release];
	}
	
	if (statusString)
		[defaultCenter postNotificationName:@"KWStatusChanged" object:statusString];
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
	
	int i;
	for (i=0;i< 3;i++)
	{
		[[sessions cellWithTag:i] setState:NSOffState];
		
		if (![combinableTypes containsObject:[NSNumber numberWithInt:i]])
			[[sessions cellWithTag:i] setEnabled:NO];
	}
	
	[[sessions cellWithTag:currentType] setEnabled:NO];
	[[sessions cellWithTag:currentType] setState:NSOnState];
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
	NSDictionary *mediaInfo = [[device status] objectForKey:DRDeviceMediaInfoKey];
	NSArray *speeds = [mediaInfo objectForKey:DRDeviceBurnSpeedsKey];
	
	[speedPopup removeAllItems];

	if ([speeds count] > 0)
	{
		float speed;
	
		int z;
		for (z=0;z<[speeds count];z++)
		{
			speed = [[speeds objectAtIndex:z] floatValue];
		
			if ([[mediaInfo objectForKey:DRDeviceMediaClassKey] isEqualTo:DRDeviceMediaClassCD])
				speed = speed / DRDeviceBurnSpeedCD1x;
			else
				speed = speed / DRDeviceBurnSpeedDVD1x;

			[speedPopup addItemWithTitle:[NSString stringWithFormat:@"%.0fx", speed]];
		}

	[speedPopup insertItemWithTitle:[NSString stringWithFormat:NSLocalizedString(@"Maximum Possible (%.0fx)", nil), speed] atIndex:0];
	[[speedPopup menu] insertItem:[NSMenuItem separatorItem] atIndex:1];


		NSNumber *burnSpeed = [[NSUserDefaults standardUserDefaults] objectForKey:@"DRBurnOptionsBurnSpeed"];
		
		if (!burnSpeed)
		{
			if ([speeds containsObject:burnSpeed])
			{
				[speedPopup selectItemAtIndex:[speeds indexOfObject:burnSpeed] + 2];
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
		DRDevice *device = [devices objectAtIndex:i];
	
		if ([[[device info] objectForKey:@"DRDeviceProductNameKey"] isEqualTo:[[[NSUserDefaults standardUserDefaults] dictionaryForKey:@"KWDefaultDeviceIdentifier"] objectForKey:@"Product"]])
		{
			return device;
		}
	}
	
	return [devices objectAtIndex:0];
}

- (BOOL)canBurn
{
	if (imagePath)
		return YES;

	int space;
	NSDictionary *mediaInfo = [[savedDevice status] objectForKey:DRDeviceMediaInfoKey];

	if ([[mediaInfo objectForKey:DRDeviceMediaIsBlankKey] boolValue])
	{
		space = [[mediaInfo objectForKey:DRDeviceMediaFreeSpaceKey] floatValue];
	}
	else if ([[mediaInfo objectForKey:DRDeviceMediaClassKey] isEqualTo:DRDeviceMediaClassDVD])
	{
		space = [[mediaInfo objectForKey:DRDeviceMediaOverwritableSpaceKey] floatValue];
	}
	else
	{
		space = (int)[KWCommonMethods defaultSizeForMedia:@"KWDefaultCDMedia"];
	}
		
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWAllowOverBurning"])
	{
		return YES;
	}
	else if (space < size)
	{
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle:NSLocalizedString(@"Burn", Localized)];
		[alert addButtonWithTitle:NSLocalizedString(@"Cancel", Localized)];
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
		[alert addButtonWithTitle:NSLocalizedString(@"Continue", Localized)];
		[alert addButtonWithTitle:NSLocalizedString(@"Cancel", Localized)];
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