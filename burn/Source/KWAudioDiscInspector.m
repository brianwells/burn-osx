#import "KWAudioDiscInspector.h"
#import "KWCommonMethods.h"
#import "KWAudioController.h"

@implementation KWAudioDiscInspector

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
														DRCDTextDiscIdentKey,		//8
														DRCDTextGenreCodeKey,		//9
														DRCDTextGenreKey,			//10
														DRCDTextMCNISRCKey,			//11
		nil];
	}

	return self;
}

- (void)dealloc
{
	[tagMappings release];
	
	[super dealloc];
}
#endif

- (void)updateView:(id)object
{
	#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_4
	currentTableView = object;
	KWAudioController *controller = [currentTableView delegate];
	DRCDTextBlock *currentCDTextBlock = [controller myTextBlock];
	
	[timeField setStringValue:[controller totalTime]];
	
	NSEnumerator *iter = [[myView subviews] objectEnumerator];
	id cntl;
	
	while ((cntl = [iter nextObject]) != NULL)
	{
		NSInteger index = [cntl tag] - 1;
		
		if (index > -1 && index < 11)
		{	
			NSString *currentKey = [tagMappings objectAtIndex:index];
			id property = [currentCDTextBlock objectForKey:currentKey ofTrack:0];
			
			if ([currentKey isEqualTo:DRCDTextGenreCodeKey])
			{
				if (property)
					[genreCode selectItemAtIndex:[property intValue]];
			}
			else if ([currentKey isEqualTo:DRCDTextMCNISRCKey])
			{
				NSString *string = [[[NSString alloc] initWithData:property encoding:NSASCIIStringEncoding] autorelease];
			
				if (string)
					[cntl setObjectValue:string];
			}
			else
			{
				if (property)
					[cntl setObjectValue:property];
			}
		}
	}
	#endif
}

- (IBAction)optionsChanged:(id)sender
{
	#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_4
	KWAudioController *controller = [currentTableView delegate];
	DRCDTextBlock *currentCDTextBlock = [controller myTextBlock];
	id property = [sender objectValue];
	NSString *currentKey = [tagMappings objectAtIndex:[sender tag] - 1];
	
	if ([currentKey isEqualTo:DRCDTextGenreCodeKey])
	{
		[currentCDTextBlock setObject:[NSNumber numberWithInt:[sender indexOfSelectedItem]] forKey:currentKey ofTrack:0];
	}
	else if ([currentKey isEqualTo:DRCDTextMCNISRCKey])
	{
		NSData *data = [property dataUsingEncoding:NSASCIIStringEncoding];
			
		if (data)
			[currentCDTextBlock setObject:data forKey:currentKey ofTrack:0];
	}
	else
	{
		if (property)
			[currentCDTextBlock setObject:property forKey:currentKey ofTrack:0];
	}
	#endif
}

- (id)myView
{
	return myView;
}

@end