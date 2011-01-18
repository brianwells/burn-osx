#import "KWAudioInspector.h"
#import "KWCommonMethods.h"
#import "KWAudioController.h"

@implementation KWAudioInspector

#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_4
- (id)init
{
	if (self = [super init])
	{
		tagMappings = [[NSArray alloc] initWithObjects:	//CD-Text
														DRCDTextTitleKey,			//1
														DRCDTextPerformerKey,		//2
														DRCDTextComposerKey,		//3
														DRCDTextSongwriterKey,		//4
														DRCDTextArrangerKey,		//5
														DRCDTextSpecialMessageKey,	//6
														DRCDTextClosedKey,			//7
														DRCDTextMCNISRCKey,			//8
														//DRTrack
														DRPreGapLengthKey,			//9
														DRAudioPreEmphasisKey,		//10
														DRTrackISRCKey,				//11
														DRIndexPointsKey,			//12
		nil];
	}

	return self;
}

- (void)dealloc
{
	[tagMappings release];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[super dealloc];
}
#endif

- (void)awakeFromNib
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setCurrentField:) name:NSWindowDidBecomeKeyNotification object:nil];
}

- (void)setCurrentField:(NSNotification *)notif
{
	if (![[notif object] isEqualTo:[myView window]])
	{
		id selectedView = [[myView window] firstResponder];

		if ([selectedView isKindOfClass:[NSTextView class]])
			[self optionsChanged:[selectedView delegate]];
	}
}

- (void)updateView:(id)object
{
	#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_4
	currentTableView = object;
	KWAudioController *controller = [currentTableView delegate];
	NSArray *tableData = [controller myDataSource];
	NSArray *currentObjects = [KWCommonMethods allSelectedItemsInTableView:currentTableView fromArray:tableData];

	if ([currentObjects count] == 1)
	{
		NSDictionary *currentObject = [currentObjects objectAtIndex:0];
	
		[iconView setImage:[currentObject objectForKey:@"Icon"]];
		[nameField setStringValue:[currentObject objectForKey:@"Name"]];
		[timeField setStringValue:[currentObject objectForKey:@"Size"]];
	}
	else
	{
		[iconView setImage:[NSImage imageNamed:@"Multiple"]];
		[nameField setStringValue:@"Multiple Selection"];
		[timeField setStringValue:[NSString stringWithFormat:NSLocalizedString(@"%ld files", nil),[currentObjects count]]];
	}
	
	NSEnumerator *iter = [[myView subviews] objectEnumerator];
	id cntl;
	
	while ((cntl = [iter nextObject]) != NULL)
	{
		NSInteger index = [cntl tag] - 1;
		id property;
		
		if (index > -1 && index < 12)
		{	
			id currentKey = [tagMappings objectAtIndex:index];
			
				if ([controller hasCDText] && index < 8)
				{
					DRCDTextBlock *currentCDTextBlock = [controller myTextBlock];
					NSArray *selectedRows = [KWCommonMethods selectedRowsAtRowIndexes:[currentTableView selectedRowIndexes]];
					property = [self getCDTextObjectForKey:currentKey inCDTextObject:currentCDTextBlock atIndexes:selectedRows];

					if ([currentKey isEqualTo:DRCDTextMCNISRCKey])
						property = [NSNumber numberWithBool:(property != nil)];
				}
				else
				{
					NSArray *selectedTracks = [KWCommonMethods allSelectedItemsInTableView:currentTableView fromArray:[controller myTracks]];
					property = [self getTrackObjectForKey:currentKey inTrackObjects:selectedTracks];

					if ([currentKey isEqualTo:DRPreGapLengthKey])
						property = [NSNumber numberWithInt:(int)[property floatValue] / 75];
					else if ([currentKey isEqualTo:DRIndexPointsKey])
						property = [NSNumber numberWithBool:(property != nil)];
				}
				
			if (property)
			{
				[cntl setObjectValue:property];
			}
			else
			{
				if ([cntl isKindOfClass:[NSTextField class]])
					[cntl setObjectValue:@""];
			}
				
				
			property = nil;
		}
	}
	#endif
}

- (id)getCDTextObjectForKey:(NSString *)key inCDTextObject:(id)object atIndexes:(NSArray *)indexes
{
	#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_4
	id baseValue;
	
	baseValue = [(DRCDTextBlock *)object objectForKey:key ofTrack:[[indexes objectAtIndex:0] intValue] + 1];


	if ([indexes count] == 1)
	{
		return baseValue;
	}
	else
	{
		NSInteger i;
		for (i=1;i<[indexes count];i++)
		{
			id currentValue = [object objectForKey:key ofTrack:[[indexes objectAtIndex:i] intValue] + 1];

			if (![baseValue isEqualTo:currentValue])
				return nil;
		}
	}

	return baseValue;
	#else
	return nil;
	#endif
}

- (id)getTrackObjectForKey:(NSString *)key inTrackObjects:(NSArray *)objects
{
	#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_4
	DRTrack *firstSelectedTrack = [objects objectAtIndex:0];
	NSDictionary *trackProperties = [firstSelectedTrack properties];
	id baseValue = [trackProperties objectForKey:key];


	if ([objects count] == 1)
	{
		return baseValue;
	}
	else
	{
		NSInteger i;
		id currentValue;
		for (i = 1; i < [objects count]; i ++)
		{
			DRTrack *selectedTrack = [objects objectAtIndex:i];
			NSDictionary *trackProperties = [selectedTrack properties];
			currentValue = [trackProperties objectForKey:key];
		}

		
		if (![baseValue isEqualTo:currentValue])
			return nil;
	}

	return baseValue;
	#else
	return nil;
	#endif
}

- (IBAction)optionsChanged:(id)sender
{
	#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_4
	NSInteger index = [sender tag] - 1;
	NSString *currentKey = [tagMappings objectAtIndex:index];
	KWAudioController *controller = [currentTableView delegate];
	NSArray *selectedRows = [KWCommonMethods selectedRowsAtRowIndexes:[currentTableView selectedRowIndexes]];

	if (index < 8)
	{
		DRCDTextBlock *currentCDTextBlock = [controller myTextBlock];
		NSMutableArray *currentTracks = [controller myTracks];
		
		NSInteger i;
		for (i=0;i<[selectedRows count];i++)
		{
			NSInteger selectedTrack = [[selectedRows objectAtIndex:i] intValue];
			id value;
			
				if ([currentKey isEqualTo:DRCDTextMCNISRCKey])
				{
					DRTrack *currentTrack = [currentTracks objectAtIndex:selectedTrack];
					NSDictionary *trackProperties = [currentTrack properties];
					value = [trackProperties objectForKey:DRTrackISRCKey];
				}
				else 
				{
					value = [sender objectValue];
				}

				if (value)
					[currentCDTextBlock setObject:value forKey:currentKey ofTrack:selectedTrack + 1];
		}
	}
	else
	{
		KWAudioController *controller = [currentTableView delegate];
		NSArray *selectedTracks = [KWCommonMethods allSelectedItemsInTableView:currentTableView fromArray:[controller myTracks]];
		
		NSInteger i;
		for (i = 0; i < [selectedTracks count]; i ++)
		{
			id value;
			
			if ([currentKey isEqualTo:DRPreGapLengthKey])
			{
				unsigned preGapLengthInFrames = (unsigned)([[sender objectValue] floatValue] * 75.0);
				value = [NSNumber numberWithUnsignedInt:preGapLengthInFrames];
			}
			else if ([currentKey isEqualTo:DRIndexPointsKey])
			{
				if ([[sender objectValue] boolValue])
					value = [NSMutableArray arrayWithCapacity:98];
				else
					value = nil;
			}
			else
			{
				value = [sender objectValue];
			}
		
			if (value)
			{
				DRTrack *currentTrack = [selectedTracks objectAtIndex:i];
				NSMutableDictionary *trackProperties = [NSMutableDictionary dictionaryWithDictionary:[currentTrack properties]];
				[trackProperties setObject:value forKey:currentKey];
				[currentTrack setProperties:trackProperties];
			}
			else
			{
				DRTrack *currentTrack = [selectedTracks objectAtIndex:i];
				NSMutableDictionary *trackProperties = [NSMutableDictionary dictionaryWithDictionary:[currentTrack properties]];
				[trackProperties removeObjectForKey:currentKey];
				[currentTrack setProperties:trackProperties];
			}
		}
	}
	#endif
}

- (IBAction)ISRCChanged:(id)sender
{
	#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_4
	BOOL isValue = [self isValidISRC:[sender stringValue]];

	if (isValue)
	{
		NSString *newFormatedISRC = [self ISRCStringFromString:[sender objectValue]];
		[sender setObjectValue:newFormatedISRC];
		
		[self optionsChanged:sender];
	}

	[invalid setHidden:isValue];
	#endif
}

- (BOOL)isValidISRC:(NSString*)isrc
{
	// Get the string as ASCII, and make sure it's 12 bytes long.
	NSData *data = [isrc dataUsingEncoding:NSASCIIStringEncoding];
	if (data == nil)
		return NO;
	
	// Check the length.
	unsigned length = [data length];
	if (length > 12)
		return NO;
	if (length != 12)
		return NO;
	
	// Make sure the characters are within the right ranges.
	const char *byte = (char*)[data bytes];
	unsigned i;
	for (i=0; i<length; ++i)
	{
		char	c = byte[i];
		BOOL	alpha = (c >= 'A' && c <= 'Z');
		BOOL	num = (c >= '0' && c <= '9');
		if (i<2) {			// first two chars are A-Z
			if (!alpha) return NO;
		} else if (i<5) {	// next three chars are 0-9 A-Z
			if (!alpha && !num) return NO;
		} else	{			// remaining chars are 0-9
			if (!num) return NO;
		}
	}
	
	// Looks valid.
	return YES;
}

- (NSString *)ISRCStringFromString:(NSString *)string
{
	// Convert the ISRC into the appropriate format:
	//	an NSData containing 12 bytes.
	NSData *data = [string dataUsingEncoding:NSASCIIStringEncoding];
		
	if ([data length] == 12)
		return string;

	char cstr[16];
	char *ip = (char*)[data bytes];
	snprintf(cstr,sizeof(cstr),"%.2s-%.3s-%.2s-%.5s",&ip[0],&ip[2],&ip[5],&ip[7]);
	cstr[15] = 0;
				
	return [NSString stringWithUTF8String:cstr];
}

- (id)myView
{
	return myView;
}

@end