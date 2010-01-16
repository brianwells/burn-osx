#import "KWAudioMP3Inspector.h"
#import "KWCommonMethods.h"
#import "KWAudioController.h"

@implementation KWAudioMP3Inspector

- (id)init
{
	if (self = [super init])
	{
		methodMappings = [[NSArray alloc] initWithObjects:	//NSStrings
															@"Title",				//1
															@"Artist",				//2
															@"Composer",			//3
															@"Album",				//4
															@"Comments",			//5
															//ints
															@"Year",				//6
															@"Track",				//7
															@"TotalNumberTracks",	//8
															@"Disk",				//9
															@"TotalNumberDisks",	//10
															//NSArray
															@"GenreNames",			//11
		nil];
		
		currentIndex = 0;
		
		Tag = [[TagAPI alloc] initWithGenreList:nil];
	}

	return self;
}

- (void)dealloc
{
	[methodMappings release];
	[Tag release];
	
	[super dealloc];
}


- (void)updateView:(id)object
{
	currentTableView = object;
	KWAudioController *controller = [currentTableView delegate];
	NSArray *tableData = [controller myDataSource];
	NSArray *currentObjects = [KWCommonMethods allSelectedItemsInTableView:currentTableView fromArray:tableData];

	if ([currentObjects count] == 1)
	{
		[iconView setImage:[[currentObjects objectAtIndex:0] objectForKey:@"Icon"]];
		[nameField setStringValue:[[currentObjects objectAtIndex:0] objectForKey:@"Name"]];
		[sizeField setStringValue:[[currentObjects objectAtIndex:0] objectForKey:@"Time"]];
		
	}
	else
	{
		[iconView setImage:[NSImage imageNamed:@"Multiple"]];
		[nameField setStringValue:@"Multiple Selection"];
		[sizeField setStringValue:[NSString localizedStringWithFormat:@"%ld files",[currentObjects count]]];
	}

	NSView *firstTabViewItem = [[tabView tabViewItemAtIndex:0] view];
	NSEnumerator *iter = [[firstTabViewItem subviews] objectEnumerator];
	id cntl;

	while ((cntl = [iter nextObject]) != NULL)
	{
		int index = [cntl tag] - 1;
		
		if (index > -1 && index < 11)
		{	
			id currentMethod = [methodMappings objectAtIndex:index];
			NSString *methodString = [NSString stringWithFormat:@"get%@", currentMethod];
			SEL method = NSSelectorFromString(methodString);
			id property = [self getObjectWithSelector:method fromObjects:currentObjects];
			
			if ([property isKindOfClass:[NSArray class]])
			{
				NSString *genreList = [property objectAtIndex:0];
			
				int i;
				for (i=1;i<[property count];i++)
				{
					NSString *newGenre = [property objectAtIndex:i];
					genreList = [NSString stringWithFormat:@"%@, %@", genreList, newGenre];
				}
				
				[cntl setObjectValue:genreList];
			}
			else 
			{
				if (property)
					[cntl setObjectValue:property];
			}
		}
	}
		
	[self updateArtWork];
}

- (id)getObjectWithSelector:(SEL)selector fromObjects:(NSArray *)objects
{
	[Tag examineFile:[[objects objectAtIndex:0] objectForKey:@"Path"]];
	
	id baseValue = [Tag performSelector:selector];

	if ([objects count] == 1)
	{
		if (selector == @selector(getYear))
			return [NSNumber numberWithInt:[baseValue intValue]];
		else if ([baseValue isKindOfClass:[NSNumber class]] && [baseValue intValue] == -1)
			return @"";
		else
			return baseValue;
	}
	else 
	{
		int i;
		for (i=0;i<[objects count];i++)
		{
			[Tag examineFile:[[objects objectAtIndex:i] objectForKey:@"Path"]];
			id currentValue = [Tag performSelector:selector];
			
				if (![currentValue isEqualTo:baseValue])
				{
					if ([baseValue isKindOfClass:[NSString class]])
						return @"";
					else
						return nil;
				}
		}
	}
	
		if ([baseValue isKindOfClass:[NSNumber class]] && [baseValue intValue] == -1)
			return @"";
		else
			return baseValue;
}

- (void)setObjectWithSelector:(SEL)selector forObjects:(NSArray *)objects withObject:(id)object
{
	int i;
	for (i=0;i<[objects count];i++)
	{
		id finalObject = object;
		NSString *method = NSStringFromSelector(selector);
		
		if ([method isEqualTo:@"setGenreNames:"])
			finalObject = [object componentsSeparatedByString:@", "];
	
		NSString *path = [[objects objectAtIndex:i] objectForKey:@"Path"];
		[Tag examineFile:path];
		[Tag performSelector:selector withObject:finalObject];
		[Tag updateFile];
	}
}

- (void)tabView:(NSTabView *)tabView willSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
	if ([[tabViewItem label] isEqualTo:@"Artwork"])
	{
		[self updateArtWork];
	}
}

- (void)updateArtWork
{
	KWAudioController *controller = [currentTableView delegate];
	NSArray *tableData = [controller myDataSource];
	NSArray *currentObjects = [KWCommonMethods allSelectedItemsInTableView:currentTableView fromArray:tableData];

	NSArray *images = [self getObjectWithSelector:@selector(getImage) fromObjects:currentObjects];
	
	if (currentIndex > [images count] - 1)
		currentIndex = 0;
		
	if (images && [images count] > 0)
	{
		NSImage *Image1 = [[NSImage alloc] init];
		[Image1 addRepresentation:[[images objectAtIndex:currentIndex] objectForKey:@"Image"]];
		[imageView setImage:Image1];
		
		NSString *countString = [NSString stringWithFormat:@"%ld of %ld", currentIndex + 1, [images count]];
		[imageString setStringValue:countString];
	}
	else
	{
		[imageView setImage:nil];
		NSString *countString = [NSString stringWithFormat:@"%ld of %ld",0,0];
		[imageString setStringValue:countString];
	}
}

- (IBAction)addImage:(id)sender
{
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	
	[openPanel setCanChooseDirectories:NO];
	[openPanel setCanChooseFiles:YES];
	[openPanel setAllowsMultipleSelection:NO];
	[openPanel setResolvesAliases:YES];

	[openPanel beginSheetForDirectory:nil file:nil types:[NSImage imageFileTypes] modalForWindow:[myView window] modalDelegate:self didEndSelector:@selector(openFileEnded:returnCode:contextInfo:) contextInfo:nil];
}

- (void)openFileEnded:(NSOpenPanel*)panel returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[panel orderOut:self];

	if (returnCode == NSOKButton)
	{
		KWAudioController *controller = [currentTableView delegate];
		NSArray *tableData = [controller myDataSource];
		NSArray *currentObjects = [KWCommonMethods allSelectedItemsInTableView:currentTableView fromArray:tableData];
	
		NSMutableArray *pictures = [self getObjectWithSelector:@selector(getImage) fromObjects:currentObjects];
	
		if ([pictures count] == 0)
			pictures = [[NSMutableArray alloc] init];

		NSArray *files = [panel filenames];
		
		int i;
		for (i=0;i<[files count];i++)
		{
			NSMutableDictionary *image = [NSMutableDictionary dictionaryWithCapacity:4];
	    
			[image setObject:[[NSBitmapImageRep imageRepsWithData:[NSData dataWithContentsOfFile:[files objectAtIndex:i]]] objectAtIndex:0] forKey:@"Image"];
			[image setObject:@"Other" forKey:@"Picture Type"];
			[image setObject:[NSString stringWithFormat:@"image/%@", [[files objectAtIndex:i] pathExtension]] forKey:@"Mime Type"];
			[image setObject:@"" forKey:@"Description"];
			
			if ([currentObjects count] == 1)
			{
				[pictures insertObject:image atIndex:currentIndex + 1];
				currentIndex = currentIndex + 1;
			}
			else
			{
				[pictures addObject:image];
			}
		}
	
		[self setObjectWithSelector:@selector(setImages:) forObjects:currentObjects withObject:pictures];
		
		[self updateArtWork];
	}
}

- (IBAction)nextImage:(id)sender
{
	currentIndex = currentIndex + 1;
	[self updateArtWork];
}

- (IBAction)optionsChanged:(id)sender
{
	KWAudioController *controller = [currentTableView delegate];
	NSArray *tableData = [controller myDataSource];
	NSArray *currentObjects = [KWCommonMethods allSelectedItemsInTableView:currentTableView fromArray:tableData];
	
	int index = [sender tag] - 1;
	id currentMethod = [methodMappings objectAtIndex:index];
	NSString *methodString = [NSString stringWithFormat:@"set%@:", currentMethod];
	SEL method = NSSelectorFromString(methodString);

	[self setObjectWithSelector:method forObjects:currentObjects withObject:[sender objectValue]];
}

- (IBAction)previousImage:(id)sender
{
	currentIndex = currentIndex - 1;
	[self updateArtWork];
}

- (IBAction)removeImage:(id)sender
{
	KWAudioController *controller = [currentTableView delegate];
	NSArray *tableData = [controller myDataSource];
	NSArray *currentObjects = [KWCommonMethods allSelectedItemsInTableView:currentTableView fromArray:tableData];

	NSMutableArray *images = [self getObjectWithSelector:@selector(getImage) fromObjects:currentObjects];
	
	if ([images count] > 1)
	{
		[images removeObjectAtIndex:currentIndex];
		[self setObjectWithSelector:@selector(setImages:) forObjects:currentObjects withObject:images];
		
		currentIndex = currentIndex - 1;
		[self updateArtWork];
	}
}

- (id)myView
{
	return myView;
}

@end