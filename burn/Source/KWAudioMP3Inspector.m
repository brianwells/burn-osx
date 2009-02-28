#import "KWAudioMP3Inspector.h"
#import "KWCommonMethods.h"

@implementation KWAudioMP3Inspector

- (void)updateView:(id)objects
{
Tag = [[TagAPI alloc] initWithGenreList:nil];
currentObjects = objects;

	if ([objects count] == 1)
	{
	[Tag examineFile:[[objects objectAtIndex:0] objectForKey:@"Path"]];
	[nameField setStringValue:[[currentObjects objectAtIndex:0] objectForKey:@"Name"]];
	//[sizeField setStringValue:[[currentObjects objectAtIndex:0] objectForKey:@"Time"]];
	[sizeField setStringValue:[KWCommonMethods formatTime:[[[currentObjects objectAtIndex:0] objectForKey:@"RealTime"] floatValue]]];
	[iconView setImage:[[currentObjects objectAtIndex:0] objectForKey:@"Icon"]];
	}
	else
	{
	[iconView setImage:[NSImage imageNamed:@"Multiple"]];
	[nameField setStringValue:@"Multiple Selection"];
	[sizeField setStringValue:[[[NSNumber numberWithInt:[currentObjects count]] stringValue] stringByAppendingString:@" files"]];
	}

[title setStringValue:[self getObjectWithSelector:@selector(getTitle) fromObjects:currentObjects returnsInt:NO]];
[artist setStringValue:[self getObjectWithSelector:@selector(getArtist) fromObjects:currentObjects returnsInt:NO]];
[composer setStringValue:[self getObjectWithSelector:@selector(getComposer) fromObjects:currentObjects returnsInt:NO]];
[album setStringValue:[self getObjectWithSelector:@selector(getAlbum) fromObjects:currentObjects returnsInt:NO]];
	if ([[self getObjectWithSelector:@selector(getGenreNames) fromObjects:currentObjects returnsInt:NO] count] > 0)
	[genre setStringValue:[[self getObjectWithSelector:@selector(getGenreNames) fromObjects:currentObjects returnsInt:NO] objectAtIndex:0]];
	else
	[genre setStringValue:@""];
[year setObjectValue:[self getObjectWithSelector:@selector(getYear) fromObjects:currentObjects returnsInt:YES]];
[trackNumber setObjectValue:[self getObjectWithSelector:@selector(getTrack) fromObjects:currentObjects returnsInt:YES]];
[trackTotal setObjectValue:[self getObjectWithSelector:@selector(getTotalNumberTracks) fromObjects:currentObjects returnsInt:YES]];
[discNumber setObjectValue:[self getObjectWithSelector:@selector(getDisk) fromObjects:currentObjects returnsInt:YES]];
[discTotal setObjectValue:[self getObjectWithSelector:@selector(getTotalNumberDisks) fromObjects:currentObjects returnsInt:YES]];
[notes setStringValue:[self getObjectWithSelector:@selector(getComments) fromObjects:currentObjects returnsInt:NO]];

	NSArray *images = [self getObjectWithSelector:@selector(getImage) fromObjects:currentObjects returnsInt:NO];
	
		if ([images count] > 0)
		{
		NSImage *Image1 = [[NSImage alloc] init];
		[Image1 addRepresentation:[[images objectAtIndex:0] objectForKey:@"Image"]];
		[imageView setImage:Image1];
		[Image1 release];
		[imageString setStringValue:[[@"1" stringByAppendingString:NSLocalizedString(@" of ", Localized)] stringByAppendingString:[[NSNumber numberWithInt:[images count]] stringValue]]];
		}
		else
		{
		[imageView setImage:nil];
		[imageString setStringValue:[[@"0" stringByAppendingString:NSLocalizedString(@" of ", Localized)] stringByAppendingString:@"0"]];
		}

[Tag release];
}

- (id)getObjectWithSelector:(SEL)selector fromObjects:(NSArray *)objects returnsInt:(BOOL)isInt
{
	if ([objects count] > 1)
	[Tag examineFile:[[objects objectAtIndex:0] objectForKey:@"Path"]];
	
id tagObject = [Tag performSelector:selector];
	
	if ([objects count] == 1)
	{
		if (isInt)
		{
			if ((int)tagObject > 0)
			return [NSNumber numberWithInt:(int)tagObject];
			else
			return nil;
		}
		else
		{
		return tagObject;
		}
	}
	else
	{
		int i;
		for (i=0;i<[objects count];i++)
		{
		[Tag examineFile:[[objects objectAtIndex:i] objectForKey:@"Path"]];
			if (isInt == NO)
			{
				if (![[Tag performSelector:selector] isEqualTo:tagObject])
				{
					if ([tagObject isKindOfClass:[NSString class]])
					return @"";
					else
					return nil;
				}
			}
			else
			{
				if (!((int)[Tag performSelector:selector] == (int)tagObject))
				{
				return nil;
				}
			}
		}
	}
	
	if (isInt)
	{
		if ((int)tagObject > 0)
		return [NSNumber numberWithInt:(int)tagObject];
		else
		return nil;
	}
	else
	{
	return tagObject;
	}
}

- (void)setObjectWithSelector:(SEL)selector forObjects:(NSArray *)objects withObject:(id)object
{
	if ([objects count] > 1)
	[Tag examineFile:[[objects objectAtIndex:0] objectForKey:@"Path"]];
	
	if ([objects count] == 1)
	{
	[Tag performSelector:selector withObject:object];
		if ([object isKindOfClass:[NSMutableArray class]])
		[Tag setTitle:[Tag getTitle]];
	[Tag updateFile];
	}
	else
	{
		int i;
		for (i=0;i<[objects count];i++)
		{
		[Tag examineFile:[[objects objectAtIndex:i] objectForKey:@"Path"]];
		[Tag performSelector:selector withObject:object];
			if ([object isKindOfClass:[NSMutableArray class]])
			[Tag setTitle:[Tag getTitle]];
		[Tag updateFile];
		}
	}
}

- (void)tabView:(NSTabView *)tabView willSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
	if ([[tabViewItem label] isEqualTo:@"Artwork"])
	{
	[self updateArtWorkAtIndex:0];
	}
}

- (void)updateArtWorkAtIndex:(int)index
{
Tag = [[TagAPI alloc] initWithGenreList:nil];

	if ([currentObjects count] == 1)
	[Tag examineFile:[[currentObjects objectAtIndex:0] objectForKey:@"Path"]];
	
	NSArray *images = [self getObjectWithSelector:@selector(getImage) fromObjects:currentObjects returnsInt:NO];
		
	if ([images count] > 0)
	{
	NSImage *Image1 = [[NSImage alloc] init];
	[Image1 addRepresentation:[[images objectAtIndex:index] objectForKey:@"Image"]];
	[imageView setImage:Image1];
	[imageString setStringValue:[[[[NSNumber numberWithInt:index + 1] stringValue] stringByAppendingString:NSLocalizedString(@" of ", Localized)] stringByAppendingString:[[NSNumber numberWithInt:[images count]] stringValue]]];
	}
	else
	{
	[imageView setImage:nil];
	[imageString setStringValue:[[@"0" stringByAppendingString:NSLocalizedString(@" of ", Localized)] stringByAppendingString:@"0"]];
	}
		
[Tag release];
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
	Tag = [[TagAPI alloc] initWithGenreList:nil];
		
	if ([currentObjects count] == 1)
	[Tag examineFile:[[currentObjects objectAtIndex:0] objectForKey:@"Path"]];
	
	NSMutableArray *pictures = [self getObjectWithSelector:@selector(getImage) fromObjects:currentObjects returnsInt:NO];
	int currentImage;
	
		if ([pictures count] == 0)
		{
		currentImage = 0;
		pictures = [[NSMutableArray array] retain];
		}
		else
		{
		currentImage = [[[[imageString stringValue] componentsSeparatedByString:@" of"] objectAtIndex:0] intValue] -1;
		}

	int lastImage;
	
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
			[pictures insertObject:image atIndex:currentImage+i];
			else
			[pictures addObject:image];
			
		lastImage = currentImage+i;
		}
	
	[self setObjectWithSelector:@selector(setImages:) forObjects:currentObjects withObject:pictures];
	[Tag release];
	[self updateArtWorkAtIndex:lastImage];
	}
}

- (IBAction)nextImage:(id)sender
{
Tag = [[TagAPI alloc] initWithGenreList:nil];
	
	if ([currentObjects count] == 1)
	[Tag examineFile:[[currentObjects objectAtIndex:0] objectForKey:@"Path"]];
	
int currentImage = [[[[imageString stringValue] componentsSeparatedByString:@" of"] objectAtIndex:0] intValue] -1;
	
	if (currentImage + 1 < [[Tag getImage] count])
	currentImage = currentImage + 1;
	else
	currentImage = 0;

NSArray *images = [self getObjectWithSelector:@selector(getImage) fromObjects:currentObjects returnsInt:NO];
	
	if ([images count] > 0)
	{
	NSImage *Image1 = [[NSImage alloc] init];
	[Image1 addRepresentation:[[images objectAtIndex:currentImage] objectForKey:@"Image"]];
	[imageView setImage:Image1];
	[imageString setStringValue:[[[NSNumber numberWithInt:currentImage + 1] stringValue] stringByAppendingString:[NSLocalizedString(@" of ", Localized) stringByAppendingString:[[NSNumber numberWithInt:[images count]] stringValue]]]];
	}
	
[Tag release];
}

- (IBAction)optionsChanged:(id)sender
{
Tag = [[TagAPI alloc] initWithGenreList:nil];
BOOL setTitle = YES;
BOOL setArtist = YES;
BOOL setComposer = YES;
BOOL setAlbum = YES;
BOOL setGenre = YES;
BOOL setNotes = YES;

	if ([currentObjects count] == 1)
	{
	[Tag examineFile:[[currentObjects objectAtIndex:0] objectForKey:@"Path"]];
	}
	else
	{
	setTitle = (![[self getObjectWithSelector:@selector(getTitle) fromObjects:currentObjects returnsInt:NO] isEqualTo:[title stringValue]]);
	setArtist = (![[self getObjectWithSelector:@selector(getArtist) fromObjects:currentObjects returnsInt:NO] isEqualTo:[artist stringValue]]);
	setComposer = (![[self getObjectWithSelector:@selector(getComposer) fromObjects:currentObjects returnsInt:NO] isEqualTo:[composer stringValue]]);
	setAlbum = (![[self getObjectWithSelector:@selector(getAlbum) fromObjects:currentObjects returnsInt:NO] isEqualTo:[album stringValue]]);
	setGenre = (![[self getObjectWithSelector:@selector(getGenreNames) fromObjects:currentObjects returnsInt:NO] isEqualTo:[NSArray arrayWithObject:[genre stringValue]]]);
	setNotes = (![[self getObjectWithSelector:@selector(getComments) fromObjects:currentObjects returnsInt:NO] isEqualTo:[notes stringValue]]);
	}
	
	int i;
	TagAPI *saveTag = [[TagAPI alloc] initWithGenreList:nil];
	for (i=0;i<[currentObjects count];i++)
	{
	[saveTag examineFile:[[currentObjects objectAtIndex:i] objectForKey:@"Path"]];
	
		if (setTitle)
		[saveTag setTitle:[title stringValue]];
		if (setArtist)
		[saveTag setArtist:[artist stringValue]];
		if (setComposer)
		[saveTag setComposer:[composer stringValue]];
		if (setAlbum)
		[saveTag setAlbum:[album stringValue]];
		if (setGenre)
		[saveTag setGenreName:[[NSArray arrayWithObject:[genre stringValue]] retain]];
		if ([year objectValue])
		[saveTag setYear:[[year objectValue] intValue]];
		if ([trackNumber objectValue] && [trackTotal objectValue])
		[saveTag setTrack:[[trackNumber objectValue] intValue] totalTracks:[[trackTotal objectValue] intValue]];
		else if ([trackNumber objectValue] && ![trackTotal objectValue])
		[saveTag setTrack:[[trackNumber objectValue] intValue] totalTracks:[saveTag getTotalNumberTracks]];
		else if (![trackNumber objectValue] && [trackTotal objectValue])
		[saveTag setTrack:[saveTag getTrack] totalTracks:[[trackTotal objectValue] intValue]];
		if ([discNumber objectValue] && [discTotal objectValue])
		[saveTag setDisk:[[discNumber objectValue] intValue] totalDisks:[[discTotal objectValue] intValue]];
		else if ([discNumber objectValue] && ![discTotal objectValue])
		[saveTag setDisk:[[discNumber objectValue] intValue] totalDisks:[saveTag getTotalNumberDisks]];
		else if (![discNumber objectValue] && [discTotal objectValue])
		[saveTag setDisk:[saveTag getDisk] totalDisks:[[discTotal objectValue] intValue]];
		if (setNotes)
		[saveTag setComments:[notes stringValue]];
		
	[saveTag updateFile];
	}

[saveTag release];
[Tag release];
}

- (IBAction)previousImage:(id)sender
{
Tag = [[TagAPI alloc] initWithGenreList:nil];
	
	if ([currentObjects count] == 1)
	[Tag examineFile:[[currentObjects objectAtIndex:0] objectForKey:@"Path"]];
	
int currentImage = [[[[imageString stringValue] componentsSeparatedByString:@" of"] objectAtIndex:0] intValue] -1;
	
	if (currentImage - 1 > - 1)
	currentImage = currentImage - 1;
	else
	currentImage = [[Tag getImage] count] - 1;
	
NSArray *images = [self getObjectWithSelector:@selector(getImage) fromObjects:currentObjects returnsInt:NO];
NSImage *Image1 = [[NSImage alloc] init];
[Image1 addRepresentation:[[images objectAtIndex:currentImage] objectForKey:@"Image"]];
[imageView setImage:Image1];
[imageString setStringValue:[[[NSNumber numberWithInt:currentImage + 1] stringValue] stringByAppendingString:[NSLocalizedString(@" of ", Localized) stringByAppendingString:[[NSNumber numberWithInt:[images count]] stringValue]]]];
	
[Tag release];
}

- (IBAction)removeImage:(id)sender
{
Tag = [[TagAPI alloc] initWithGenreList:nil];
	
	if ([currentObjects count] == 1)
	[Tag examineFile:[[currentObjects objectAtIndex:0] objectForKey:@"Path"]];
	
NSMutableArray *images = [self getObjectWithSelector:@selector(getImage) fromObjects:currentObjects returnsInt:NO];
	
	if ([images count] > 1)
	{
	int currentImage = [[[[imageString stringValue] componentsSeparatedByString:@" of"] objectAtIndex:0] intValue] - 1;
	[images removeObjectAtIndex:currentImage];
	[self setObjectWithSelector:@selector(setImages:) forObjects:currentObjects withObject:images];
	
	[Tag release];

		if (currentImage < [images count])
		[self updateArtWorkAtIndex:currentImage];
		else
		[self updateArtWorkAtIndex:currentImage - 1];
	}
	else
	{
		if ([[Tag getImage] count] > 0)
		{
		[self setObjectWithSelector:@selector(setImages:) forObjects:currentObjects withObject:[[NSMutableArray arrayWithCapacity:2] retain]];
		[Tag release];
		[self updateArtWorkAtIndex:0];
		}
	}
}

- (id)myView
{
return myView;
}

@end
