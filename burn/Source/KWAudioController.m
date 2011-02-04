//
//  KWAudioController.m
//  Burn
//
//  Created by Maarten Foukhar on 13-09-09.
//  Copyright 2009 Kiwi Fruitware. All rights reserved.
//

#import "KWAudioController.h"
#if MAC_OS_X_VERSION_MAX_ALLOWED < 1050
#import <QuickTime/QuickTime.h>
#endif
#import <MultiTag/MultiTag.h>
#import "KWWindowController.h"
#import "KWCommonMethods.h"
#import "KWTrackProducer.h"

@implementation KWAudioController

- (id)init
{
	self = [super init];
	
	//Set the current type to audio
	currentType = 1;
	
	//No regions for audio discs
	useRegion = NO;
	
	//Set current filesystemtype to @"" >> not needed for audio
	currentFileSystem = @"";
	
	//Set the dvd folder name (different for audio and video)
	dvdFolderName = @"AUDIO_TS";

	//Setup our arrays for the options menus
	audioOptionsMappings = [[NSArray alloc] initWithObjects:	@"KWUseCDText",	//0
																nil];
															
	mp3OptionsMappings = [[NSArray alloc] initWithObjects:		@"KWCreateArtistFolders",	//0
																@"KWCreateAlbumFolders",	//1
																nil];

	//Here are our tableviews data stored
	audioTableData = [[NSMutableArray alloc] init];
	mp3TableData = [[NSMutableArray alloc] init];
	dvdTableData = [[NSMutableArray alloc] init];
	
	//Our tracks to burn
	tracks = [[NSMutableArray alloc] init];
	
	//The display only works only with QuickTime 7
	if ([KWCommonMethods isQuickTimeSevenInstalled])
	{
		display = 0;
		pause = NO;
	}
	
	#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_4
	if ([KWCommonMethods OSVersion] >= 0x1040)
	{
		//Map track options to cue strings
		NSArray *cueStrings = [NSArray arrayWithObjects:			@"TITLE",
																	@"PERFORMER",
																	@"COMPOSER",
																	@"SONGWRITER",
																	@"ARRANGER",
																	@"MESSAGE",
																	@"REM GENRE",
																	@"REM PRIVATE",
																	nil];
																
		NSArray *trackStrings = [NSArray arrayWithObjects:			DRCDTextTitleKey,
																	DRCDTextPerformerKey,
																	DRCDTextComposerKey,
																	DRCDTextSongwriterKey,
																	DRCDTextArrangerKey,
																	DRCDTextSpecialMessageKey,
																	DRCDTextGenreKey,
																	DRCDTextClosedKey,
																	nil];
	
		cueMappings = [[NSDictionary alloc] initWithObjects:cueStrings forKeys:trackStrings];
	}
	#endif
	
	return self;
}

- (void)dealloc
{
	//Stop listening to notifications from the default notification center
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	//Stop the music
	[self stop:self];

	//Release our previously explained files
	[audioOptionsMappings release];
	audioOptionsMappings = nil;
	
	[mp3OptionsMappings release];
	mp3OptionsMappings = nil;

	[audioTableData release];
	audioTableData = nil;
	
	[mp3TableData release];
	mp3TableData = nil;
	
	[dvdTableData release];
	dvdTableData = nil;
	
	[tracks release];
	tracks = nil;
	
	[cueMappings release];
	cueMappings = nil;

	//Release the filetypes stored, using a retain
	[allowedFileTypes release];
	allowedFileTypes = nil;
	
	#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1050
	if (cdtext)
	{
		[cdtext release];
		cdtext = nil;
	}
	#elif MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_4
	if ([KWCommonMethods OSVersion] >= 0x1040)
	{
		//We might have retained it, so release it
		if (cdtext)
		{
			[cdtext release];
			cdtext = nil;
		}
	}
	#endif

	[super dealloc];
}

- (void)awakeFromNib
{
	[super awakeFromNib];
	
	NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];

	//Double clicking will start a song
	if ([KWCommonMethods isQuickTimeSevenInstalled])
		[tableView setDoubleAction:@selector(play:)];
		
	//Needs to be set in Tiger (Took me a while to figure out since it worked since Jaguar without target)
	[tableView setTarget:self];
	
	//When a movie ends we'll play the next song if it exists
	if ([KWCommonMethods isQuickTimeSevenInstalled])
	{
		#ifdef USE_QTKIT
		[defaultCenter addObserver:self selector:@selector(movieEnded:) name:QTMovieDidEndNotification object:nil];
		#endif
	}
	else
	{
		#if MAC_OS_X_VERSION_MAX_ALLOWED < 1050
		//EnterMovies for QuickTime 6 functions later to be used
		EnterMovies();
		#endif
	
		//Make it look like we we're never able to play songs :-)
		[totalText setFrameOrigin:NSMakePoint([totalText frame].origin.x+63,[totalText frame].origin.y)]; 
	
		[previousButton setHidden:YES];
		[playButton setHidden:YES];
		[nextButton setHidden:YES];
		[stopButton setHidden:YES];
	
		[previousButton setEnabled:YES];
		[playButton setEnabled:YES];
		[nextButton setEnabled:YES];
		[stopButton setEnabled:YES];
	}
	
	//Set save popup title
	[tableViewPopup selectItemAtIndex:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultAudioType"] integerValue]];
	[self tableViewPopup:self];

	//Set the Inspector window to empty
	[defaultCenter postNotificationName:@"KWChangeInspector" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"KWEmpty",@"Type",nil]];
}

//////////////////
// Main actions //
//////////////////

#pragma mark -
#pragma mark •• Main actions

//Delete tracks from tracks array (Audio-CD only)
- (IBAction)deleteFiles:(id)sender
{	
	NSInteger selrow = [tableViewPopup indexOfSelectedItem];
	
	if (selrow == 0)
	{
		if ([KWCommonMethods isQuickTimeSevenInstalled])
			[self stop:sender];

		//Remove rows
		#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1050
		if (cdtext)
		{
			NSMutableArray *trackDictionaries = [NSMutableArray arrayWithArray:[cdtext trackDictionaries]];
			NSDictionary *discDictionary = [NSDictionary dictionaryWithDictionary:[trackDictionaries objectAtIndex:0]];
			[trackDictionaries removeObjectAtIndex:0];
		
			NSArray *selectedDictionaries = [KWCommonMethods allSelectedItemsInTableView:tableView fromArray:trackDictionaries];
			[trackDictionaries removeObjectsInArray:selectedDictionaries];
			[trackDictionaries insertObject:discDictionary atIndex:0];
			[cdtext setTrackDictionaries:trackDictionaries];
		}
		#elif MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_4
		if (cdtext && [KWCommonMethods OSVersion] >= 0x1040)
		{
			NSMutableArray *trackDictionaries = [NSMutableArray arrayWithArray:[cdtext trackDictionaries]];
			NSDictionary *discDictionary = [NSDictionary dictionaryWithDictionary:[trackDictionaries objectAtIndex:0]];
			[trackDictionaries removeObjectAtIndex:0];
		
			NSArray *selectedDictionaries = [KWCommonMethods allSelectedItemsInTableView:tableView fromArray:trackDictionaries];
			[trackDictionaries removeObjectsInArray:selectedDictionaries];
			[trackDictionaries insertObject:discDictionary atIndex:0];
			[cdtext setTrackDictionaries:trackDictionaries];
		}
		#endif
		
		NSArray *selectedObjects = [KWCommonMethods allSelectedItemsInTableView:tableView fromArray:tracks];
		[tracks removeObjectsInArray:selectedObjects];
	}
	
	[super deleteFiles:sender];
}

//Add the file to the tableview
- (void)addFile:(id)file isSelfEncoded:(BOOL)selfEncoded
{
	NSFileManager *defaultManager = [NSFileManager defaultManager];

	if (!incompatibleFiles)
		incompatibleFiles = [[NSMutableArray alloc] init];

	NSString *path;
	if ([file isKindOfClass:[NSString class]])
		path = file;
	else
		path = [file objectForKey:@"Path"];

	NSInteger selrow = [tableViewPopup indexOfSelectedItem];
	NSString *displayName = [defaultManager displayNameAtPath:path];
	NSString *pathExtension = [[path pathExtension] lowercaseString];
	NSString *fileType = NSFileTypeForHFSTypeCode([[[defaultManager fileAttributesAtPath:path traverseLink:YES] objectForKey:NSFileHFSTypeCode] longValue]);

	if (selrow == 1 && ![pathExtension isEqualTo:@"mp3"] && ![fileType isEqualTo:@"'MPG3'"] && ![fileType isEqualTo:@"'Mp3 '"] && ![fileType isEqualTo:@"'MP3 '"])
	{
		NSMutableDictionary *rowData = [NSMutableDictionary dictionary];
		[rowData setObject:displayName forKey:@"Name"];
		[rowData setObject:path forKey:@"Path"];
		[incompatibleFiles addObject:rowData];
	}
	else if (selrow == 2 && ![pathExtension isEqualTo:@"wav"] && ![pathExtension isEqualTo:@"flac"] && ![fileType isEqualTo:@"'WAVE'"] && ![fileType isEqualTo:@"'.WAV'"])
	{
		NSMutableDictionary *rowData = [NSMutableDictionary dictionary];
		[rowData setObject:displayName forKey:@"Name"];
		[rowData setObject:path forKey:@"Path"];
		[incompatibleFiles addObject:rowData];
	}
	else
	{
		NSMutableDictionary *rowData = [NSMutableDictionary dictionary];

		if ([KWCommonMethods isQuickTimeSevenInstalled])
			[self stop:self];

		CGFloat time = [self getMovieDuration:path];
	
		[rowData setObject:displayName forKey:@"Name"];
		[rowData setObject:path forKey:@"Path"];
		
		id sizeObject;
		if (selrow == 0)
			sizeObject = [KWCommonMethods formatTime:time withFrames:NO];
		else
			sizeObject = [KWCommonMethods makeSizeFromFloat:[[[defaultManager fileAttributesAtPath:path traverseLink:YES] objectForKey:NSFileSize] cgfloatValue]];
		
		[rowData setObject:sizeObject forKey:@"Size"];
		[rowData setObject:[[NSNumber numberWithInteger:time] stringValue] forKey:@"RealTime"];
		[rowData setObject:[[NSWorkspace sharedWorkspace] iconForFile:path] forKey:@"Icon"];
	
		if ([tableData count] > 0 && [[[[tableData objectAtIndex:0] objectForKey:@"Name"] lowercaseString] isEqualTo:@"audio_ts"] && selrow == 2)
		{
			[previousButton setEnabled:YES];
			[playButton setEnabled:YES];
			[nextButton setEnabled:YES];
			[stopButton setEnabled:YES];
		
			[tableData removeAllObjects];
			currentDropRow = -1;
		}
		
		if (selrow == 1)
		{
			currentDropRow = -1;
		
			MultiTag *soundTag = [[MultiTag alloc] initWithFile:path];
			[rowData setObject:[soundTag getTagArtist] forKey:@"Artist"];
			[rowData setObject:[soundTag getTagAlbum] forKey:@"Album"];
			[soundTag release];
		}

		if (selrow == 0)
		{
			KWTrackProducer *producer = [[KWTrackProducer alloc] init];
			DRTrack	*track = [producer getAudioTrackForPath:path];
			[producer release];
			producer = nil;
			
			NSNumber *pregap = [[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultPregap"];
			unsigned preGapLengthInFrames = (unsigned)([pregap cgfloatValue] * 75.0);
			
			NSMutableDictionary	*trackProperties = [NSMutableDictionary dictionaryWithDictionary:[track properties]];
			[trackProperties setObject:[NSNumber numberWithUnsignedInt:preGapLengthInFrames] forKey:DRPreGapLengthKey];
			[track setProperties:trackProperties];
			[tracks addObject:track];
			
			#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_4
			#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1050
			if ([pathExtension isEqualTo:@"mp3"] | [pathExtension isEqualTo:@"m4a"])
			#else
			if ([KWCommonMethods OSVersion] >= 0x1040 && [pathExtension isEqualTo:@"mp3"] | [pathExtension isEqualTo:@"m4a"])
			#endif
			{
				MultiTag *soundTag = [[MultiTag alloc] initWithFile:path];
				
				NSString *album = [soundTag getTagAlbum];

				if (!cdtext)
				{
					cdtext = [[DRCDTextBlock cdTextBlockWithLanguage:@"" encoding:DRCDTextEncodingISOLatin1Modified] retain];
	
					[cdtext setObject:[soundTag getTagArtist] forKey:DRCDTextPerformerKey ofTrack:0];
				
					NSArray *genres = [soundTag getTagGenreNames];
					if ([genres count] > 0)
					{
						[cdtext setObject:[NSNumber numberWithInteger:0] forKey:DRCDTextGenreCodeKey ofTrack:0];
						[cdtext setObject:[genres objectAtIndex:0] forKey:DRCDTextGenreKey ofTrack:0];
					}
					
					[cdtext setObject:album forKey:DRCDTextTitleKey ofTrack:0];
					[discName setStringValue:album];
				}
				else
				{
					if (![[cdtext objectForKey:DRCDTextPerformerKey ofTrack:0] isEqualTo:[soundTag getTagArtist]])
						[cdtext setObject:@"" forKey:DRCDTextPerformerKey ofTrack:0];
				
					NSArray *genres = [soundTag getTagGenreNames];
					if ([genres count] > 0)
					{
						if (![[cdtext objectForKey:DRCDTextGenreKey ofTrack:0] isEqualTo:[genres objectAtIndex:0]])
							[cdtext setObject:@"" forKey:DRCDTextGenreKey ofTrack:0];
					}
					
					if (![[cdtext objectForKey:DRCDTextTitleKey ofTrack:0] isEqualTo:album])
					{
						[cdtext setObject:NSLocalizedString(@"Untitled", nil) forKey:DRCDTextTitleKey ofTrack:0];
						[discName setStringValue:NSLocalizedString(@"Untitled", nil)];
					}
				}
			
				NSInteger lastTrack = [tracks count];

				[cdtext setObject:[soundTag getTagTitle] forKey:DRCDTextTitleKey ofTrack:lastTrack];
				[cdtext setObject:[soundTag getTagArtist] forKey:DRCDTextPerformerKey ofTrack:lastTrack];
				[cdtext setObject:[soundTag getTagComposer] forKey:DRCDTextComposerKey ofTrack:lastTrack];
				[cdtext setObject:[soundTag getTagComments] forKey:DRCDTextSpecialMessageKey ofTrack:lastTrack];
				
				[soundTag release];
				soundTag = nil;
			}
			else
			{
				if (cdtext)
				{
					NSMutableArray *trackDictionaries = [NSMutableArray arrayWithArray:[cdtext trackDictionaries]];
					[trackDictionaries addObject:[NSMutableDictionary dictionary]];
					[cdtext setTrackDictionaries:trackDictionaries];
				}
			}
			#endif
		}
			
		if (currentDropRow > -1)
		{
			[tableData insertObject:rowData atIndex:currentDropRow];
			currentDropRow = currentDropRow + 1;
		}
		else
		{
			[tableData addObject:rowData];
		}
		
		[tableView reloadData];
		
		
		[self sortIfNeeded];
		[self setTotal];
	}
}

- (IBAction)changeDiscName:(id)sender
{
	#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1050
	NSInteger selrow = [tableViewPopup indexOfSelectedItem];
	
	if	(cdtext && selrow == 0)
		[cdtext setObject:[discName stringValue] forKey:DRCDTextTitleKey ofTrack:0];
	#elif MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_4
	if ([KWCommonMethods OSVersion] >= 0x1040)
	{
		NSInteger selrow = [tableViewPopup indexOfSelectedItem];
	
		if	(cdtext && selrow == 0)
			[cdtext setObject:[discName stringValue] forKey:DRCDTextTitleKey ofTrack:0];
	}
	#endif
}

///////////////////////////
// Disc creation actions //
///////////////////////////

#pragma mark -
#pragma mark •• Disc creation actions

//Create a track for burning
- (id)myTrackWithBurner:(KWBurner *)burner errorString:(NSString **)error
{
	NSInteger selrow = [tableViewPopup indexOfSelectedItem];
	NSString *discTitle = [discName stringValue];
	NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];

	//Stop the music before burning
	if ([KWCommonMethods isQuickTimeSevenInstalled])
		[self stop:self];

	if (selrow == 2)
	{
		NSString *outputFolder = [KWCommonMethods temporaryLocation:discTitle saveDescription:NSLocalizedString(@"Choose a location to save a temporary folder", nil)];
		
		if (outputFolder)
		{
			[temporaryFiles addObject:outputFolder];
	
			NSInteger succes = [self authorizeFolderAtPathIfNeededAtPath:outputFolder errorString:&*error];
	
			if (succes == 0)
				return [[KWTrackProducer alloc] getTrackForFolder:outputFolder ofType:7 withDiscName:discTitle];
			else
				return [NSNumber numberWithInteger:succes];
		}
		else
		{
			return [NSNumber numberWithInteger:2];
		}
	}
		
	if (selrow == 1)
	{
		DRFolder *discRoot = [DRFolder virtualFolderWithName:discTitle];
	
		NSInteger i;
		for (i = 0; i < [tableData count]; i ++)
		{
			DRFolder *myFolder = discRoot;
			
			if ([[standardDefaults objectForKey:@"KWCreateArtistFolders"] boolValue] | [[standardDefaults objectForKey:@"KWCreateAlbumFolders"] boolValue])
			{
				NSString *path = [[tableData objectAtIndex:i] valueForKey:@"Path"];
				MultiTag *soundTag = [[MultiTag alloc] initWithFile:path];
			
				if ([[standardDefaults objectForKey:@"KWCreateArtistFolders"] boolValue] && ![[soundTag getTagArtist] isEqualTo:@""])
				{
					NSString *artist = [soundTag getTagArtist];
					DRFolder *artistFolder = [self checkArray:[myFolder children] forFolderWithName:artist];
					
					if (!artistFolder)
						artistFolder = [DRFolder virtualFolderWithName:artist];
					
					[myFolder addChild:artistFolder];
				
					myFolder = artistFolder;
				}
				
				if ([[standardDefaults objectForKey:@"KWCreateAlbumFolders"] boolValue] && ![[soundTag getTagAlbum] isEqualTo:@""])
				{
					NSString *album = [soundTag getTagAlbum];
					DRFolder *albumFolder = [self checkArray:[myFolder children] forFolderWithName:album];
					
					if (!albumFolder)
						albumFolder = [DRFolder virtualFolderWithName:album];
					
					[myFolder addChild:albumFolder];
					
					myFolder = albumFolder;
				}
			
				[soundTag release];
				soundTag = nil;
			}
			
			[myFolder addChild:[DRFile fileWithPath:[[tableData objectAtIndex:i] valueForKey:@"Path"]]];
		}
				
		[discRoot setExplicitFilesystemMask: (DRFilesystemInclusionMaskJoliet)];

		return discRoot;
	}
	else
	{
		#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_4
		if ([KWCommonMethods OSVersion] >= 0x1040)
		{
			if ([standardDefaults boolForKey:@"KWUseCDText"] == YES && cdtext)
			{
				NSMutableDictionary *burnProperties = [NSMutableDictionary dictionary];
			
				[burnProperties setObject:cdtext forKey:DRCDTextKey];
			
				id mcn = [cdtext objectForKey:DRCDTextMCNISRCKey ofTrack:0];
				if (mcn)
					[burnProperties setObject:mcn forKey:DRMediaCatalogNumberKey];
			
				[burner addBurnProperties:burnProperties];
			}
		}
		#endif
		
		return tracks;
	}

	return nil;
}

- (NSInteger)authorizeFolderAtPathIfNeededAtPath:(NSString *)path errorString:(NSString **)error;
{
	NSInteger succes;
	NSDictionary *currentData = [tableData objectAtIndex:0];
	
	if ([tableData count] > 0 && [[[currentData objectForKey:@"Name"] lowercaseString] isEqualTo:@"audio_ts"])
	{
		succes = [KWCommonMethods createDVDFolderAtPath:path ofType:0 fromTableData:tableData errorString:&*error];	
	}
	else
	{
		CGFloat maximumSize = [[self totalSize] cgfloatValue];
		
		#if MAC_OS_X_VERSION_MAX_ALLOWED < 1050
		if ([KWCommonMethods OSVersion] < 0x1040)
			maximumSize = maximumSize * 2;
		#endif
			
		NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
	
		[defaultCenter postNotificationName:@"KWMaximumValueChanged" object:[NSNumber numberWithCGFloat:maximumSize]];
	
		NSMutableArray *files = [NSMutableArray array];

		NSInteger i;
		for (i = 0; i < [tableData count]; i ++)
		{
			[files addObject:[[tableData objectAtIndex:i] objectForKey:@"Path"]];
		}
		
		[defaultCenter postNotificationName:@"KWTaskChanged" object:NSLocalizedString(@"Authoring DVD...",nil)];
		[defaultCenter postNotificationName:@"KWStatusChanged" object:NSLocalizedString(@"Generating DVD folder",nil)];
	
		DVDAuthorizer = [[KWDVDAuthorizer alloc] init];
		succes = [DVDAuthorizer createStandardDVDAudioFolderAtPath:[path retain] withFiles:files errorString:&*error];
		[DVDAuthorizer release];
		DVDAuthorizer = nil;
	}
	
	return succes;
}

//////////////////
// Save actions //
//////////////////

#pragma mark -
#pragma mark •• Save actions

- (void)setExtraInformation:(NSDictionary *)information
{
	if (cdtext)
	{
		[cdtext release];
		cdtext = nil;
	}

	[tracks removeAllObjects];

	NSArray *trackProperties = [information objectForKey:@"KWTrackProperties"];
	
	if (trackProperties)
	{
		NSInteger i;
		for (i = 0; i < [trackProperties count]; i ++)
		{
			NSDictionary *properties = [trackProperties objectAtIndex:i];
			DRTrack	*track = [[KWTrackProducer alloc] getTrackWithTrackProperties:properties];
			[tracks addObject:track];
		}
	}
	
	NSArray *cdTextDictionaries = [information objectForKey:@"KWCDTextDictionaries"];
	
	if (cdTextDictionaries)
	{
		cdtext = [[DRCDTextBlock cdTextBlockWithLanguage:@"" encoding:DRCDTextEncodingISOLatin1Modified] retain];
		[cdtext setTrackDictionaries:cdTextDictionaries];
	}
}

- (NSDictionary *)extraInformation
{
	if ([tracks count] > 0)
	{
		NSMutableDictionary *information = [NSMutableDictionary dictionary];
		NSMutableArray *trackProperties = [NSMutableArray array];
		
		NSInteger i;
		for (i = 0; i < [tracks count]; i ++)
		{
			DRTrack *currentTrack = [tracks objectAtIndex:i];
			[trackProperties addObject:[currentTrack properties]];
		}
		
		[information setObject:trackProperties forKey:@"KWTrackProperties"];
		
		if (cdtext)
			[information setObject:[cdtext trackDictionaries] forKey:@"KWCDTextDictionaries"];
			
		return information;
	}
	
	return nil;
}

///////////////////////
// Tableview actions //
///////////////////////

#pragma mark -
#pragma mark •• Tableview actions

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
	NSInteger selrow = [tableViewPopup indexOfSelectedItem];
	
	NSString *kind = @"KWEmpty";
	id object = nil;
	
	#if MAC_OS_X_VERSION_MAX_ALLOWED < 1050
	if (selrow == 0 && [KWCommonMethods OSVersion] >= 0x1040)
	{
		object = tableView;
	
		if ([tableView selectedRow] == -1)
			kind = @"KWAudioDisc";
		else
			kind = @"KWAudio";
	}
	#else
	if (selrow == 0)
	{
		object = tableView;
	
		if ([tableView selectedRow] == -1)
			kind = @"KWAudioDisc";
		else
			kind = @"KWAudio";
	}
	#endif
	else if (selrow == 1)
	{
		object = tableView;
	
		if ([tableView selectedRow] != -1)
			kind = @"KWAudioMP3";
	}
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWChangeInspector" object:object userInfo:[NSDictionary dictionaryWithObjectsAndKeys:kind, @"Type", nil]];
}

//Set the current tableview and tabledata to the selected popup item
- (void)getTableView
{
	NSInteger selrow = [tableViewPopup indexOfSelectedItem];
	
	if (allowedFileTypes)
	{
		[allowedFileTypes release];
		allowedFileTypes = nil;
	}

	if (selrow == 0)
	{
		tableData = audioTableData;

		allowedFileTypes = [[KWCommonMethods quicktimeTypes] retain];
	}
	else
	{
		if (selrow == 1)
			tableData = mp3TableData;
		else
			tableData = dvdTableData;

		allowedFileTypes = [[KWCommonMethods mediaTypes] retain];
	}

	[tableView reloadData];
}

//Popup clicked
- (IBAction)tableViewPopup:(id)sender
{
	NSInteger selrow = [tableViewPopup indexOfSelectedItem];
	canBeReorderd = YES;
	isDVD = NO;
	currentFileSystem = @"";

	//Stop playing
	if ([KWCommonMethods isQuickTimeSevenInstalled])
		[self stop:self];

	[self getTableView];
	
	id tableHeaderCell = [[tableView tableColumnWithIdentifier:@"Size"] headerCell];
	[tableHeaderCell setStringValue:NSLocalizedString(@"Size", nil)];

	//Set the icon, tabview and textfield
	if (selrow == 0)
	{
		currentFileSystem = @"-audio-cd";
	
		optionsPopup = audioOptionsPopup;
		optionsMappings = audioOptionsMappings;
	
		[tableHeaderCell setStringValue:NSLocalizedString(@"Time", nil)];
	
		[popupIcon setImage:[NSImage imageNamed:@"Audio CD"]];
		
		[accessOptions setEnabled:([KWCommonMethods OSVersion] >= 0x1040)];
	}
	else if (selrow == 1)
	{
		convertExtension = @"mp3";
		convertKind = 5;
		canBeReorderd = NO;
	
		optionsPopup = mp3OptionsPopup;
		optionsMappings = mp3OptionsMappings;
	
		[popupIcon setImage:[[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(kGenericCDROMIcon)]];
		[accessOptions setEnabled:YES];
	}
	else if (selrow == 2)
	{
		convertExtension = @"wav";
		convertKind = 6;
		isDVD = YES;
	
		[popupIcon setImage:[NSImage imageNamed:@"DVD"]];
		[accessOptions setEnabled:NO];
	}
	
	//get the tableview and set the total time
	[self setDisplay:self];
	
	//Save the popup if needed
	NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];
	if ([standardDefaults boolForKey:@"KWRememberPopups"] == YES)
	{
		[self saveTableViewPopup:self];
	}
	
	if (tableView == [mainWindow firstResponder])
	{
		[self tableViewSelectionDidChange:nil];
	}
	else
	{
		NSString *kind = @"KWEmpty";
		
		#if MAC_OS_X_VERSION_MAX_ALLOWED < 1050
		if (selrow == 0 && [KWCommonMethods OSVersion] >= 0x1040)
			kind = @"KWAudioDisc";
		else if (selrow == 1)
			kind = @"KWAudioMP3Disc";
		#else
		if (selrow == 0)
			kind = @"KWAudioDisc";
		else if (selrow == 1)
			kind = @"KWAudioMP3Disc";
		#endif
		
		[[NSNotificationCenter defaultCenter] postNotificationName:@"KWChangeInspector" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:kind, @"Type", nil]];
	}
}

- (void)saveTableViewPopup:(id)sender
{
	[[NSUserDefaults standardUserDefaults] setObject:[tableViewPopup objectValue] forKey:@"KWDefaultAudioType"];
}

- (void)sortIfNeeded
{
	if ([tableViewPopup indexOfSelectedItem] == 1)
	{
		NSMutableArray *sortDescriptors = [NSMutableArray array];
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
		if ([[defaults objectForKey:@"KWCreateAlbumFolders"] boolValue])
			[sortDescriptors addObject:[[[NSSortDescriptor alloc] initWithKey:@"Album" ascending:YES] autorelease]];
		
		if ([[defaults objectForKey:@"KWCreateArtistFolders"] boolValue])
			[sortDescriptors addObject:[[[NSSortDescriptor alloc] initWithKey:@"Artist" ascending:YES] autorelease]];		
					
		[sortDescriptors addObject:[[[NSSortDescriptor alloc] initWithKey:@"Name" ascending:YES] autorelease]];
		
		[tableData sortUsingDescriptors:sortDescriptors];
	}
}

////////////////////
// Player actions //
////////////////////

#pragma mark -
#pragma mark •• Player actions

- (IBAction)play:(id)sender
{
	#ifdef USE_QTKIT
	//Check if there are some rows, we really need those
	if ([tableData count] > 0)
	{
		//If image is pause.png the movie has already started so we should pause it, but if the message is
		//send by the tableview the user wants a other song
		if ([playButton image] == [NSImage imageNamed:@"Play"] | sender == tableView)
		{
			//If the user click pause before we should resume, else we should start the selected, 
			//double-clicked or first song
			if (pause == NO | sender == tableView)
			{
				//If there still is a movie (when a user double-clicked a row) stop it and make movie nil
				if (movie != nil)
				{
					[movie stop];
					[movie release];
					movie = nil;
				}
				
				NSInteger selrow = [tableView selectedRow];
				
				//Check if a row is selected if not play first song 
				if (selrow > -1)
					playingSong = selrow;
				else
					playingSong = 0;
					
				movie = [[QTMovie alloc] initWithFile:[[tableData objectAtIndex:playingSong] objectForKey:@"Path"] error:nil];
			
				[movie play];
					
				if (display == 0)
					[self setDisplay:self];
					
				displayTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateDisplay:) userInfo:nil repeats: YES];
				[playButton setImage:[NSImage imageNamed:@"Pause"]];
			}
			else
			//Resume
			{
				[movie play];
				displayTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateDisplay:) userInfo:nil repeats: YES];
				[playButton setImage:[NSImage imageNamed:@"Pause"]];
			}
		}
		else
		//Pause
		{
			[movie stop];
			[displayTimer invalidate];
			pause = YES;
			[playButton setImage:[NSImage imageNamed:@"Play"]];
		}
	}
	#endif
}

- (IBAction)stop:(id)sender
{
	#ifdef USE_QTKIT
	//Check if we have some rows, so we don't try to stop it for the second time
	if ([tableData count] > 0)
	{
		//Check if there is a movie, so we have something to stop
		if (movie != nil)
		{
			[movie stop];
			
			if ([playButton image] == [NSImage imageNamed:@"Pause"])
				[displayTimer invalidate];
				
			display = 2;
			pause = NO;
			[playButton setImage:[NSImage imageNamed:@"Play"]];
			playingSong = 0;
			[movie release];
			movie = nil;
			[self setDisplay:self];
		}
	}
	#endif
}

- (IBAction)back:(id)sender
{
	#ifdef USE_QTKIT
	if (movie != nil)
	{
		//Only fire if the player is already playing
		if ([playButton image] == [NSImage imageNamed:@"Pause"])
		{
			//If we're not at number 1 go back
			if (playingSong - 1 > - 1)
			{
				//Stop previous movie
				if (movie != nil)
				{
					[movie stop];
					[movie release];
					movie = nil;
				}
				
				movie = [[QTMovie alloc] initWithFile:[[tableData objectAtIndex:playingSong - 1] objectForKey:@"Path"] error:nil];
				[movie play];
				playingSong = playingSong - 1;
			}
			else if (playingSong == 0)
			{
				[movie gotoBeginning];
			}
		}
		else
		{
			if (playingSong - 1 > - 1)
			{
				//Stop previous movie
				if (movie != nil)
				{
					[movie stop];
					[movie release];
					movie = nil;
				}
			
				movie = [[QTMovie alloc] initWithFile:[[tableData objectAtIndex:playingSong- 1] objectForKey:@"Path"] error:nil];
				playingSong = playingSong - 1;
				[self setDisplay:self];
			}
			else
			{
				[movie gotoBeginning];
			}
		}
	}
	#endif
}

- (IBAction)forward:(id)sender
{
	#ifdef USE_QTKIT
	if (movie != nil)
	{
		//Only fire if the player is already playing
		if ([playButton image] == [NSImage imageNamed:@"Pause"])
		{
			//If the're more tracks go to next
			if (playingSong + 1 < [tableData count])
			{
				//Stop previous movie
				if (movie != nil)
				{
					[movie stop];
					[movie release];
					movie = nil;
				}
				
				movie = [[QTMovie alloc] initWithFile:[[tableData objectAtIndex:playingSong + 1] objectForKey:@"Path"] error:nil];
				[movie play];
				playingSong = playingSong + 1;
			}
		}
		else
		{
			if (playingSong + 1 < [tableData count])
			{
				//Stop previous movie
				if (movie != nil)
				{
					[movie stop];
					[movie release];
					movie = nil;
				}
			
				movie = [[QTMovie alloc] initWithFile:[[tableData objectAtIndex:playingSong + 1] objectForKey:@"Path"] error:nil];
				playingSong = playingSong + 1;
				[self setDisplay:self];
			}
		}
	}
	#endif
}

//When the movie has stopped there will be a notification, we go to the next song if there is any
- (void)movieEnded:(NSNotification *)notification
{
	#ifdef USE_QTKIT
	if (playingSong + 1 < [tableData count])
	{
		//Stop previous movie
		if (movie != nil)
		{
			[movie stop];
			[movie release];
			movie = nil;
		}
	
		movie = [[QTMovie alloc] initWithFile:[[tableData objectAtIndex:playingSong+1] objectForKey:@"Path"] error:nil];
		[movie play];
		playingSong = playingSong + 1;
	}
	else
	{
		[self stop:self];
	}
	#endif
}

//When the user clicks on the time display change the mode
- (IBAction)setDisplay:(id)sender
{
	#ifdef USE_QTKIT
	if ([KWCommonMethods isQuickTimeSevenInstalled])
	{
		if (movie != nil)
		{
			if (display < 2)
				display = display + 1;
			else
				display = 0;
		
			[self setDisplayText];
		}
		else
		{
			[self setTotal];
		}
	}
	else
	{
		[self setTotal];
	}
	#endif
}

//Keep the seconds running on the display
- (void)updateDisplay:(NSTimer *)theTimer
{
	#ifdef USE_QTKIT
	if (movie != nil)
	#endif
		[self setDisplayText];
}

- (void)setDisplayText
{
	if (display == 1 | display == 2)
	{
		#ifdef USE_QTKIT
		NSString *displayText;
		NSString *timeString;
		
		CGFloat time = (CGFloat)[movie currentTime].timeValue / (CGFloat)[movie currentTime].timeScale;
				
		if (display == 2)
			time = (CGFloat)[movie duration].timeValue / (CGFloat)[movie duration].timeScale - time;
			
		timeString = [KWCommonMethods formatTime:time withFrames:NO];
				
		NSInteger selrow = [tableViewPopup indexOfSelectedItem];
		if (selrow == 1 | selrow == 2)
		{
			NSString *displayName = [[NSFileManager defaultManager] displayNameAtPath:[[tableData objectAtIndex:playingSong] objectForKey:@"Path"]];
			displayText = [NSString stringWithFormat:@"%@ %@", displayName, timeString];
		}
		else
		{
			displayText = [NSString stringWithFormat:NSLocalizedString(@"Track %ld %@", nil), (long) playingSong + 1, timeString];
		}
				
		[totalText setStringValue:displayText];
		#endif
	}
	else if (display == 2)
	{
		display = 0;
		[self setTotal];
	}
}

///////////////////////
// TableView actions //
///////////////////////

#pragma mark -
#pragma mark •• TableView actions

- (BOOL)tableView:(NSTableView*)tv acceptDrop:(id <NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)op
{
	#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1050
	if (cdtext)
	#elif MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_4
	if (cdtext && [KWCommonMethods OSVersion] >= 0x1040)
	{
		NSInteger selrow = [tableViewPopup indexOfSelectedItem];

		if (selrow == 0)
		{
			NSPasteboard *pboard = [info draggingPasteboard];
	
			if ([[pboard types] containsObject:@"NSGeneralPboardType"])
			{
				NSMutableArray *trackDictionaries = [NSMutableArray arrayWithArray:[cdtext trackDictionaries]];
				NSDictionary *discDictionary = [NSDictionary dictionaryWithDictionary:[trackDictionaries objectAtIndex:0]];
				[trackDictionaries removeObjectAtIndex:0];
			
				NSArray *draggedRows = [pboard propertyListForType:@"KWDraggedRows"];
				NSMutableArray *draggedObjects = [NSMutableArray array];
				NSInteger numberOfRows = [trackDictionaries count];
		
				NSInteger i;
				for (i = 0; i < [draggedRows count]; i ++)
				{
					NSInteger currentRow = [[draggedRows objectAtIndex:i] integerValue];
					[draggedObjects addObject:[trackDictionaries objectAtIndex:currentRow]];
					[trackDictionaries removeObjectAtIndex:currentRow];
				}
			
				for (i = 0; i < [draggedObjects count]; i ++)
				{
					id object = [draggedObjects objectAtIndex:i];
					NSInteger destinationRow = row + i;
			
					if (row > numberOfRows)
					{
						[trackDictionaries addObject:object];
			
						destinationRow = [tableData count] - 1;
					}
					else
					{
						if ([[draggedRows objectAtIndex:i] integerValue] < destinationRow)
							destinationRow = destinationRow - [draggedRows count];
				
						[trackDictionaries insertObject:object atIndex:destinationRow];
					}
				}
	
				[trackDictionaries insertObject:discDictionary atIndex:0];
				[cdtext setTrackDictionaries:trackDictionaries];
			}
		}
	}
	#endif
	
	return [super tableView:tv acceptDrop:info row:row dropOperation:op];
}

///////////////////
// Other actions //
///////////////////

#pragma mark -
#pragma mark •• Other actions

//Set total size or time
- (void)setTotal
{
	if ([tableViewPopup indexOfSelectedItem] == 0)
		[totalText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Total time: %@", nil), [self totalTime]]];
	else
		[super setTotal];
}

- (NSNumber *)totalSize
{
	if ([tableViewPopup indexOfSelectedItem] > 0)
	{
		return [super totalSize];
	}
	else
	{
		NSInteger i;
		NSInteger size = 0;
		for (i = 0; i < [tracks count]; i ++)
		{
			DRTrack *currentTrack = [tracks objectAtIndex:i];
			NSDictionary *properties = [currentTrack properties];
			size = size + [[properties objectForKey:DRTrackLengthKey] integerValue];
			size = size + [[properties objectForKey:DRPreGapLengthKey] integerValue];
		}
		
		return [NSNumber numberWithInteger:size];
	}
}

//Calculate and return total time as string
- (NSString *)totalTime
{
	return [KWCommonMethods formatTime:[[self totalSize] cgfloatValue] / 75 withFrames:NO];
}

//Get movie duration using NSMovie so it works in Panther too
- (NSInteger)getMovieDuration:(NSString *)path
{
	#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1050
	return [KWConverter totalTimeInSeconds:path];
	#else
	NSInteger duration;

	if ([KWCommonMethods isQuickTimeSevenInstalled])
	{
		#ifdef USE_QTKIT
		QTMovie *qtMovie = [QTMovie movieWithFile:path error:nil];
		QTTime movieDuration = [qtMovie duration];
		duration = (NSInteger)movieDuration.timeValue / (NSInteger)movieDuration.timeScale;
		#endif
	}
	else
	{
		NSMovie *theMovie = [[NSMovie alloc] initWithURL:[NSURL fileURLWithPath:path] byReference:NO];

		if (theMovie)
		{
			duration = GetMovieDuration([theMovie QTMovie]) / GetMovieTimeScale([theMovie QTMovie]);
			[theMovie release];
		}
	}

	return duration;
	#endif
}

//Check if the disc can be combined
- (BOOL)isCombinable
{
	return ([tableData count] > 0 && [tableViewPopup indexOfSelectedItem] == 1);
}

//Check if the disc is a Audio CD disc
- (BOOL)isAudioCD
{
	return ([tableViewPopup indexOfSelectedItem] == 0 && [tableData count] > 0);
}

- (void)volumeLabelSelected:(NSNotification *)notif
{
	NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
	
	id object = nil;
	NSString *kind = @"KWEmpty";
	
	#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1050
	if ([tableViewPopup indexOfSelectedItem] == 0)
	{
		object = tableView;
		kind = @"KWAudioDisc";
	}
	#else
	if ([tableViewPopup indexOfSelectedItem] == 0 && [KWCommonMethods OSVersion] >= 0x1040)
	{
		kind = @"KWAudioDisc";
		object = tableView;
	}
	#endif

	[defaultCenter postNotificationName:@"KWChangeInspector" object:object userInfo:[NSDictionary dictionaryWithObjectsAndKeys:kind, @"Type", nil]];
}

- (BOOL)respondsToSelector:(SEL)aSelector
{
	//Remove to save cue / bin from an Audio-CD (note: might not work perfect yet)
	if (aSelector == @selector(saveImage:) && [tableViewPopup indexOfSelectedItem] == 0)
		return NO;

	return [super respondsToSelector:aSelector];
}

- (NSString *)cueStringWithBinFile:(NSString *)binFile
{
	NSString *cueFile = [NSString stringWithFormat:@"FILE \"%@\" BINARY", binFile];
	NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];
	
	#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1050
	if ([standardDefaults objectForKey:@"KWUseCDText"])
	#elif MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_4
	if ([KWCommonMethods OSVersion] >= 0x1040 && [standardDefaults objectForKey:@"KWUseCDText"])
	{
		NSArray *keys = [cueMappings allKeys];
	
		NSInteger i;
		for (i=0;i<[keys count];i++)
		{
			NSString *key = [keys objectAtIndex:i];
			NSString *cueString = [cueMappings objectForKey:key];
			id object = [cdtext objectForKey:key ofTrack:0];
		
			if (object && ![[NSString stringWithFormat:@"%@", object] isEqualTo:@""] && (![cueString isEqualTo:@"MESSAGE"] | [(NSString *)object length] > 1))
			{
				if (i > 7)
					cueFile = [NSString stringWithFormat:@"%@\n%@ %@", cueFile, cueString, object];
				else 
					cueFile = [NSString stringWithFormat:@"%@\n%@ \"%@\"", cueFile, cueString, object];
			}
		}
	
		id ident = [cdtext objectForKey:DRCDTextDiscIdentKey ofTrack:0];
	
		if (ident)
			cueFile = [NSString stringWithFormat:@"%@\nDISC_ID %@", cueFile, ident];
		
		id mcn = [cdtext objectForKey:DRCDTextMCNISRCKey ofTrack:0];
	
		if (mcn)
			cueFile = [NSString stringWithFormat:@"%@\nUPC_EAN %@", cueFile, mcn];
	}
	#endif
		
	NSInteger x;
	NSInteger size = 0;
	for (x=0;x<[tracks count];x++)
	{
		NSInteger trackNumber = x + 1;
		cueFile = [NSString stringWithFormat:@"%@\n  TRACK %2i AUDIO", cueFile, trackNumber];
		
		#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_4
		if ([KWCommonMethods OSVersion] >= 0x1040 && [standardDefaults objectForKey:@"KWUseCDText"])
		{
			NSArray *keys = [cueMappings allKeys];
		
			NSInteger i;
			for (i=0;i<[keys count];i++)
			{
				NSString *key = [keys objectAtIndex:i];
				NSString *cueString = [cueMappings objectForKey:key];
				id object = [cdtext objectForKey:key ofTrack:trackNumber];
		
				if (object && ![[NSString stringWithFormat:@"%@", object] isEqualTo:@""] && (![cueString isEqualTo:@"MESSAGE"] | [(NSString *)object length] > 1))
				{
					if (i > 7)
						cueFile = [NSString stringWithFormat:@"%@\n    %@ %@", cueFile, cueString, object];
					else 
						cueFile = [NSString stringWithFormat:@"%@\n    %@ \"%@\"", cueFile, cueString, object];
				}
			}
		
			id isrc = [cdtext objectForKey:DRTrackISRCKey ofTrack:trackNumber];
	
			if (isrc)
				cueFile = [NSString stringWithFormat:@"%@\n    ISRC %@", cueFile, isrc];
		
			id mcn = [cdtext objectForKey:DRCDTextMCNISRCKey ofTrack:trackNumber];
	
			if (mcn)
				cueFile = [NSString stringWithFormat:@"%@\n    CATALOG %@", cueFile, mcn];
			
			id preemphasis = [cdtext objectForKey:DRAudioPreEmphasisKey ofTrack:trackNumber];
	
			if (preemphasis)
				cueFile = [NSString stringWithFormat:@"%@\n    FLAGS PRE", cueFile];
		}
		#endif
		
		DRTrack *currentTrack = [tracks objectAtIndex:x];
		NSDictionary *trackProperties = [currentTrack properties];
		NSInteger pregap = [[trackProperties objectForKey:DRPreGapLengthKey] integerValue];
			
		if (pregap > 0)
		{
			NSString *time = [[DRMSF msfWithFrames:size] description];
			cueFile = [NSString stringWithFormat:@"%@\n    INDEX 00 %@", cueFile, time];
			size = size + pregap;
		}
		
		NSInteger trackSize = [[trackProperties objectForKey:DRTrackLengthKey] integerValue];
		NSString *time = [[DRMSF msfWithFrames:size] description];
		cueFile = [NSString stringWithFormat:@"%@\n    INDEX 01 %@", cueFile, time];
		size = size + trackSize;
	}
	
	return cueFile;
}

//////////////////////
// External actions //
//////////////////////

#pragma mark -
#pragma mark •• External actions

#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_4
- (BOOL)hasCDText
{
	return (cdtext != nil);
}

- (DRCDTextBlock *)myTextBlock
{
	if (!cdtext)
	{
		cdtext = [[DRCDTextBlock cdTextBlockWithLanguage:@"" encoding:DRCDTextEncodingISOLatin1Modified] retain];
		[cdtext setObject:NSLocalizedString(@"Untitled", nil) forKey:DRCDTextTitleKey ofTrack:0];
		
		NSMutableArray *trackDictionaries = [NSMutableArray arrayWithArray:[cdtext trackDictionaries]];
		NSInteger i;
		
		for (i = 0; i < [tracks count]; i ++)
		{
			[trackDictionaries addObject:[NSMutableDictionary dictionary]];
		}
		
		[cdtext setTrackDictionaries:trackDictionaries];
	}

	return cdtext;
}
#endif

- (NSMutableArray *)myTracks
{
	return tracks;
}

@end