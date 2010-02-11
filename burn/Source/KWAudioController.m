//
//  KWAudioController.m
//  Burn
//
//  Created by Maarten Foukhar on 13-09-09.
//  Copyright 2009 Kiwi Fruitware. All rights reserved.
//

#import "KWAudioController.h"
#import <QuickTime/QuickTime.h>
#import <ID3/TagAPI.h>
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
	[mp3OptionsMappings release];

	[audioTableData release];
	[mp3TableData release];
	[dvdTableData release];
	
	[tracks release];

	//Release the filetypes stored, using a retain
	[allowedFileTypes release];
	
	#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_4
	//We might have retained it, so release it
	if (cdtext)
		[cdtext release];
	#endif

	[super dealloc];
}

- (void)awakeFromNib
{
	[super awakeFromNib];

	//Double clicking will start a song
	if ([KWCommonMethods isQuickTimeSevenInstalled])
		[tableView setDoubleAction:@selector(play:)];
		
	//Needs to be set in Tiger (Took me a while to figure out since it worked since Jaguar without target)
	[tableView setTarget:self];
	
	//When a movie ends we'll play the next song if it exists
	if ([KWCommonMethods isQuickTimeSevenInstalled])
	{
		#ifdef USE_QTKIT
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(movieEnded:) name:QTMovieDidEndNotification object:nil];
		#endif
	}
	else
	{
		//EnterMovies for QuickTime 6 functions later to be used
		EnterMovies();
	
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
	[tableViewPopup selectItemAtIndex:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultAudioType"] intValue]];
	[self tableViewPopup:self];

	//Set the Inspector window to empty
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWChangeInspector" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"KWEmpty",@"Type",nil]];
}

//////////////////
// Main actions //
//////////////////

#pragma mark -
#pragma mark •• Main actions

//Delete tracks from tracks array (Audio-CD only)
- (IBAction)deleteFiles:(id)sender
{	
	int selrow = [tableViewPopup indexOfSelectedItem];
	
	if (selrow == 0)
	{NSLog(@"Tracks before: %@", tracks);
		if ([KWCommonMethods isQuickTimeSevenInstalled])
			[self stop:sender];

		//Remove rows
		NSArray *selectedObjects = [KWCommonMethods allSelectedItemsInTableView:tableView fromArray:tracks];
		[tracks removeObjectsInArray:selectedObjects];NSLog(@"Tracks after: %@", tracks);
	}
	
	[super deleteFiles:sender];
}

//Add the file to the tableview
- (void)addFile:(NSString *)path isSelfEncoded:(BOOL)selfEncoded
{
	int selrow = [tableViewPopup indexOfSelectedItem];

	NSString *fileType = NSFileTypeForHFSTypeCode([[[[NSFileManager defaultManager] fileAttributesAtPath:path traverseLink:YES] objectForKey:NSFileHFSTypeCode] longValue]);

	if (selrow == 1 && ![[[path pathExtension] lowercaseString] isEqualTo:@"mp3"] && ![fileType isEqualTo:@"'MPG3'"] && ![fileType isEqualTo:@"'Mp3 '"] && ![fileType isEqualTo:@"'MP3 '"])
	{
		NSMutableDictionary *rowData = [NSMutableDictionary dictionary];
		[rowData setObject:[[NSFileManager defaultManager] displayNameAtPath:path] forKey:@"Name"];
		[rowData setObject:path forKey:@"Path"];
		[incompatibleFiles addObject:rowData];
	}
	else if (selrow == 2 && ![[[path pathExtension] lowercaseString] isEqualTo:@"wav"] && ![[[path pathExtension] lowercaseString] isEqualTo:@"flac"] && ![fileType isEqualTo:@"'WAVE'"] && ![fileType isEqualTo:@"'.WAV'"])
	{
		NSMutableDictionary *rowData = [NSMutableDictionary dictionary];
		[rowData setObject:[[NSFileManager defaultManager] displayNameAtPath:path] forKey:@"Name"];
		[rowData setObject:path forKey:@"Path"];
		[incompatibleFiles addObject:rowData];
	}
	else
	{
		NSMutableDictionary *rowData = [NSMutableDictionary dictionary];

		if ([KWCommonMethods isQuickTimeSevenInstalled])
			[self stop:self];

		float time = [self getMovieDuration:path];
	
		[rowData setObject:[[NSFileManager defaultManager] displayNameAtPath:path] forKey:@"Name"];
		[rowData setObject:path forKey:@"Path"];
		
		id sizeObject;
		if (selrow == 0)
			sizeObject = [KWCommonMethods formatTime:time];
		else
			sizeObject = [KWCommonMethods makeSizeFromFloat:[[[[NSFileManager defaultManager] fileAttributesAtPath:path traverseLink:YES] objectForKey:NSFileSize] floatValue]];
		
		[rowData setObject:sizeObject forKey:@"Size"];
		[rowData setObject:[[NSNumber numberWithInt:time] stringValue] forKey:@"RealTime"];
		[rowData setObject:[[[NSWorkspace sharedWorkspace] iconForFile:path] retain] forKey:@"Icon"];
	
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
			TagAPI *Tag = [[TagAPI alloc] initWithGenreList:nil];
			[Tag examineFile:path];
			[rowData setObject:[[Tag getArtist] copy] forKey:@"Artist"];
			[rowData setObject:[[Tag getAlbum] copy] forKey:@"Album"];
			[Tag release];
		}

		if (selrow == 0)
		{
			DRTrack	*track = [[KWTrackProducer alloc] getAudioTrackForPath:path];
			NSNumber *pregap = [[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultPregap"];
			unsigned preGapLengthInFrames = (unsigned)([pregap floatValue] * 75.0);
			
			NSMutableDictionary	*trackProperties = [NSMutableDictionary dictionary];
			[trackProperties setObject:[NSNumber numberWithUnsignedInt:preGapLengthInFrames] forKey:DRPreGapLengthKey];
			[track setProperties:trackProperties];
			[tracks addObject:track];
			
			if ([KWCommonMethods OSVersion] >= 0x1040 && [[[path pathExtension] lowercaseString] isEqualTo:@"mp3"])
			{
				#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_4
				TagAPI *Tag = [[TagAPI alloc] initWithGenreList:nil];
				[Tag examineFile:path];
				
				if (!cdtext)
				{
					cdtext = [[DRCDTextBlock cdTextBlockWithLanguage:@"" encoding:DRCDTextEncodingISOLatin1Modified] retain];
			
					[cdtext setObject:[Tag getTitle] forKey:DRCDTextTitleKey ofTrack:0];
					[cdtext setObject:[Tag getArtist] forKey:DRCDTextPerformerKey ofTrack:0];
				
				
					NSArray *genres = [Tag getGenreNames];
					if ([genres count] > 0)
					{
						[cdtext setObject:[NSNumber numberWithInt:0] forKey:DRCDTextGenreCodeKey ofTrack:0];
						[cdtext setObject:[genres objectAtIndex:0] forKey:DRCDTextGenreKey ofTrack:0];
					}
				}
				else
				{
					if (![[cdtext objectForKey:DRCDTextTitleKey ofTrack:0] isEqualTo:[Tag getTitle]])
					[cdtext setObject:@"" forKey:DRCDTextTitleKey ofTrack:0];
				
					if (![[cdtext objectForKey:DRCDTextPerformerKey ofTrack:0] isEqualTo:[Tag getArtist]])
					[cdtext setObject:@"" forKey:DRCDTextPerformerKey ofTrack:0];
				
					NSArray *genres = [Tag getGenreNames];
					if ([genres count] > 0)
					{
						if (![[cdtext objectForKey:DRCDTextGenreKey ofTrack:0] isEqualTo:[genres objectAtIndex:0]])
						[cdtext setObject:@"" forKey:DRCDTextGenreKey ofTrack:0];
					}
				}
			
				int lastTrack = [tracks count] - 1;
	
				[cdtext setObject:[Tag getTitle] forKey:DRCDTextTitleKey ofTrack:lastTrack];
				[cdtext setObject:[Tag getArtist] forKey:DRCDTextPerformerKey ofTrack:lastTrack];
				[cdtext setObject:[Tag getComposer] forKey:DRCDTextComposerKey ofTrack:lastTrack];
				[cdtext setObject:[Tag getComments] forKey:DRCDTextSpecialMessageKey ofTrack:lastTrack];
	
				[Tag release];
				
				#endif
			}
		}
			
		if (currentDropRow > -1)
		{
			[tableData insertObject:[rowData copy] atIndex:currentDropRow];
			currentDropRow = currentDropRow + 1;
		}
		else
		{
			[tableData addObject:[rowData copy]];
		}
		
		[tableView reloadData];
		
		
		[self sortIfNeeded];
		[self setTotal];
	}
}

- (IBAction)changeDiscName:(id)sender
{
	#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_4
	int selrow = [tableViewPopup indexOfSelectedItem];
	
	if	(selrow == 0)
	{
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
	int selrow = [tableViewPopup indexOfSelectedItem];

	//Stop the music before burning
	if ([KWCommonMethods isQuickTimeSevenInstalled])
		[self stop:self];

	if (selrow == 2)
	{
		NSString *outputFolder = [KWCommonMethods temporaryLocation:[discName stringValue] saveDescription:NSLocalizedString(@"Choose a location to save a temporary folder",nil)];
		
		if (outputFolder)
		{
			[temporaryFiles addObject:outputFolder];
	
			int succes = [self authorizeFolderAtPathIfNeededAtPath:outputFolder errorString:&*error];
	
			if (succes == 0)
				return [[KWTrackProducer alloc] getTrackForFolder:outputFolder ofType:7 withDiscName:[discName stringValue]];
			else
				return [NSNumber numberWithInt:succes];
		}
		else
		{
			return [NSNumber numberWithInt:2];
		}
	}
		
	if (selrow == 1)
	{
		DRFolder *discRoot = [DRFolder virtualFolderWithName:[discName stringValue]];
	
		int i;
		for (i=0;i<[tableData count];i++)
		{
			DRFolder *myFolder = discRoot;
			
			if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"KWCreateArtistFolders"] boolValue] | [[[NSUserDefaults standardUserDefaults] objectForKey:@"KWCreateAlbumFolders"] boolValue])
			{
				TagAPI *Tag = [[TagAPI alloc] initWithGenreList:nil];
				[Tag examineFile:[[tableData objectAtIndex:i] valueForKey:@"Path"]];
			
				if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"KWCreateArtistFolders"] boolValue] && ![[Tag getArtist] isEqualTo:@""])
				{
					DRFolder *artistFolder = [self checkArray:[myFolder children] forFolderWithName:[Tag getArtist]];
					
					if (!artistFolder)
						artistFolder = [DRFolder virtualFolderWithName:[Tag getArtist]];
					
					[myFolder addChild:artistFolder];
				
					myFolder = artistFolder;
				}
				
				if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"KWCreateAlbumFolders"] boolValue] && ![[Tag getAlbum] isEqualTo:@""])
				{
					DRFolder *albumFolder = [self checkArray:[myFolder children] forFolderWithName:[Tag getAlbum]];
					
					if (!albumFolder)
						albumFolder = [DRFolder virtualFolderWithName:[Tag getAlbum]];
					
					[myFolder addChild:albumFolder];
					
					myFolder = albumFolder;
				}
			
				[Tag release];
			}
			
			[myFolder addChild:[DRFile fileWithPath:[[tableData objectAtIndex:i] valueForKey:@"Path"]]];
		}
				
		[discRoot setExplicitFilesystemMask: (DRFilesystemInclusionMaskJoliet)];

		return [discRoot retain];
	}
	else
	{
		#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_4
		if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWUseCDText"] == YES)
		{
			NSMutableDictionary *burnProperties = [NSMutableDictionary dictionary];
			
			[burnProperties setObject:cdtext forKey:DRCDTextKey];
			
			id mcn = [cdtext objectForKey:DRCDTextMCNISRCKey ofTrack:0];
			if (mcn)
				[burnProperties setObject:mcn forKey:DRMediaCatalogNumberKey];
			
			[burner addBurnProperties:burnProperties];
			
			return tracks;
		}
		else
		{
			return tracks;
		}
		#else
		return tracks;
		#endif
	}

	return nil;
}

- (int)authorizeFolderAtPathIfNeededAtPath:(NSString *)path errorString:(NSString **)error;
{
	int succes;
	NSDictionary *currentData = [tableData objectAtIndex:0];
	
	if ([tableData count] > 0 && [[[currentData objectForKey:@"Name"] lowercaseString] isEqualTo:@"audio_ts"])
	{
		succes = [KWCommonMethods createDVDFolderAtPath:path ofType:0 fromTableData:tableData errorString:&*error];	
	}
	else
	{
		float maximumSize = [self totalSize];
		
		if ([KWCommonMethods OSVersion] < 0x1040)
			maximumSize = maximumSize * 2;
			
		NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
	
		[defaultCenter postNotificationName:@"KWMaximumValueChanged" object:[NSNumber numberWithFloat:maximumSize]];
	
		NSMutableArray *files = [NSMutableArray array];

		int i;
		for (i=0;i<[tableData count];i++)
		{
			[files addObject:[[tableData objectAtIndex:i] objectForKey:@"Path"]];
		}
		
		[defaultCenter postNotificationName:@"KWTaskChanged" object:NSLocalizedString(@"Authoring DVD...",nil)];
		[defaultCenter postNotificationName:@"KWStatusChanged" object:NSLocalizedString(@"Generating DVD folder",nil)];
	
		DVDAuthorizer = [[KWDVDAuthorizer alloc] init];
		succes = [DVDAuthorizer createStandardDVDAudioFolderAtPath:[path retain] withFiles:files errorString:&*error];
		[DVDAuthorizer release];
	}
	
	return succes;
}

///////////////////////
// Tableview actions //
///////////////////////

#pragma mark -
#pragma mark •• Tableview actions

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
	int selrow = [tableViewPopup indexOfSelectedItem];

	NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];

	if (selrow == 0 && [KWCommonMethods OSVersion] >= 0x1040)
	{
		if (selrow == -1)
			[defaultCenter postNotificationName:@"KWChangeInspector" object:tableView userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"KWAudioDisc",@"Type",nil]];
		else
			[defaultCenter postNotificationName:@"KWChangeInspector" object:tableView userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"KWAudio",@"Type",nil]];
	}
	else if (selrow == 1)
	{
		if ([tableView selectedRow] == -1)
			[defaultCenter postNotificationName:@"KWChangeInspector" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"KWEmpty",@"Type",nil]];
		else
			[defaultCenter postNotificationName:@"KWChangeInspector" object:tableView userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"KWAudioMP3",@"Type",nil]];
	}
	else
	{
		[defaultCenter postNotificationName:@"KWChangeInspector" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"KWEmpty",@"Type",nil]];
	}
}

//Set the current tableview and tabledata to the selected popup item
- (void)getTableView
{
	int selrow = [tableViewPopup indexOfSelectedItem];
	
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
	int selrow = [tableViewPopup indexOfSelectedItem];
	canBeReorderd = YES;
	isDVD = NO;

	//Stop playing
	if ([KWCommonMethods isQuickTimeSevenInstalled])
		[self stop:self];

	[self getTableView];
	[[[tableView tableColumnWithIdentifier:@"Size"] headerCell] setStringValue:NSLocalizedString(@"Size",nil)];

	//Set the icon, tabview and textfield
	if (selrow == 0)
	{
		optionsPopup = audioOptionsPopup;
		optionsMappings = audioOptionsMappings;
	
		[[[tableView tableColumnWithIdentifier:@"Size"] headerCell] setStringValue:NSLocalizedString(@"Time",nil)];
	
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
		[standardDefaults setObject:[tableViewPopup objectValue] forKey:@"KWDefaultAudioType"];
	}
	
	if (tableView == [mainWindow firstResponder])
	{
		[self tableViewSelectionDidChange:nil];
	}
	else
	{
		NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
	
		if (selrow == 0 && [KWCommonMethods OSVersion] >= 0x1040)
			[defaultCenter postNotificationName:@"KWChangeInspector" object:tableView userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"KWAudioDisc",@"Type",nil]];
		else if (selrow == 1)
			[defaultCenter postNotificationName:@"KWChangeInspector" object:tableView userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"KWAudioMP3Disc",@"Type",nil]];
		else if (selrow == 1)
			[defaultCenter postNotificationName:@"KWChangeInspector" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"KWEmpty",@"Type",nil]];
	}
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
				if (!movie == nil)
				{
					[movie stop];
					[movie release];
					movie = nil;
				}
				
				int selrow = [tableView selectedRow];
				
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
		if (!movie == nil)
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
	if (!movie==nil)
	{
		//Only fire if the player is already playing
		if ([playButton image] == [NSImage imageNamed:@"Pause"])
		{
			//If we're not at number 1 go back
			if (playingSong - 1 > - 1)
			{
				//Stop previous movie
				if (!movie == nil)
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
				if (!movie == nil)
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
	if (!movie==nil)
	{
		//Only fire if the player is already playing
		if ([playButton image] == [NSImage imageNamed:@"Pause"])
		{
			//If the're more tracks go to next
			if (playingSong + 1 < [tableData count])
			{
				//Stop previous movie
				if (!movie == nil)
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
				if (!movie == nil)
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
		if (!movie == nil)
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
		if (!movie==nil)
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
		
		int time = (int)[movie currentTime].timeValue/(int)[movie currentTime].timeScale;
				
		if (display == 2)
			time = (int)[movie duration].timeValue/(int)[movie duration].timeScale - time;
			
		timeString = [KWCommonMethods formatTime:time];
				
		int selrow = [tableViewPopup indexOfSelectedItem];
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

//Calculate and return total time as string
- (NSString *)totalTime
{
	int time = 0;

	int i;
	for (i=0;i<[tableData count];i++)
	{
		time = time + [[[tableData objectAtIndex:i] valueForKey: @"RealTime"] intValue];
	}
	
	return [KWCommonMethods formatTime:time];
}

//Get movie duration using NSMovie so it works in Panther too
- (int)getMovieDuration:(NSString *)path
{
	int duration;

	NSMovie *theMovie = [[NSMovie alloc] initWithURL:[NSURL fileURLWithPath:path] byReference:NO];

	if (theMovie)
	{
		duration = GetMovieDuration([theMovie QTMovie]) / GetMovieTimeScale([theMovie QTMovie]);
		[theMovie release];
	}

	return duration;
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

	if ([tableViewPopup indexOfSelectedItem] == 0 && [KWCommonMethods OSVersion] >= 0x1040)
		[defaultCenter postNotificationName:@"KWChangeInspector" object:tableView userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"KWAudioDisc",@"Type",nil]];
	else
		[defaultCenter postNotificationName:@"KWChangeInspector" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"KWEmpty",@"Type",nil]];
}

- (BOOL)respondsToSelector:(SEL)aSelector
{
	if (aSelector == @selector(saveImage:) && [tableViewPopup indexOfSelectedItem] == 0)
		return NO;
		
	return [super respondsToSelector:aSelector];
}

//////////////////////
// External actions //
//////////////////////

#pragma mark -
#pragma mark •• External actions

#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_4
- (DRCDTextBlock *)myTextBlock
{
	return cdtext;
}
#endif

- (NSMutableArray *)myTracks
{
	return tracks;
}

@end