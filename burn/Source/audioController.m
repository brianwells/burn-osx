#import "audioController.h"
#import <QTKit/QTKit.h>
#import <QuickTime/QuickTime.h>
#import <ID3/TagAPI.h>
#import "KWDocument.h"
#import "KWCommonMethods.h"
#import "discCreationController.h"
#import "KWTrackProducer.h"KWTrackProducer

@implementation audioController

- (id)init
{
self = [super init];

//Setup our arrays for the options menus
audioOptionsMappings = [[NSArray alloc] initWithObjects:	@"KWUseCDText",	//0
															nil];
															
mp3OptionsMappings = [[NSArray alloc] initWithObjects:		@"KWCreateArtistFolders",	//0
															@"KWCreateAlbumFolders",	//1
															nil];

//Here are our tableviews data stored
AudioCDTableData = [[NSMutableArray alloc] init];
Mp3TableData = [[NSMutableArray alloc] init];
DVDAudioTableData = [[NSMutableArray alloc] init];

//Here we store our temporary files which will be deleting acording to the prefences set for deletion
temporaryFiles = [[NSMutableArray alloc] init];

//Storage room for files
notCompatibleFiles = [[NSMutableArray alloc] init];
someProtected =  [[NSMutableArray alloc] init];

//Out CDText information for the disc is stored here
CDTextDict = [[NSMutableDictionary alloc] init];
	
//The display only works only with QuickTime 7
	if ([KWCommonMethods isQuickTimeSevenInstalled])
	{
	display = 0;
	pause = NO;
	}
	
//Set a starting row for dropping files in the list
currentDropRow = -1;
	
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

[AudioCDTableData release];
[Mp3TableData release];
[DVDAudioTableData release];

[temporaryFiles release];

[notCompatibleFiles release];
[someProtected release];

[CDTextDict release];

//We have no need for the extensions of protected files
[protectedFiles release];
protectedFiles = nil;

//Release the filetypes stored, using a retain
[allowedFileTypes release];
allowedFileTypes = nil;

[super dealloc];
}

- (void)awakeFromNib
{
//Notifications
//Used to save the popups when the user selects this option in the preferences
[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(tableViewPopup:) name:@"KWTogglePopups" object:nil];
//Prevent files to be dropped when for example a sheet is open
[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setTableViewState:) name:@"KWSetDropState" object:nil];
//Updates the Inspector window with the new item selected in the list
[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(tableViewSelectionDidChange:) name:@"KWListSelected" object:tableView];
//Updates the Inspector window to show the information about the disc
[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(volumeLabelSelected:) name:@"KWDiscNameSelected" object:discName];

//How should our tableview update its sizes when adding and modifying files
[tableView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];

//The user can drag files into the tableview (including iMovie files)
[tableView registerForDraggedTypes:[NSArray arrayWithObjects:NSFilenamesPboardType,@"NSGeneralPboardType",@"CorePasteboardFlavorType 0x6974756E",nil]];

	//Double clicking will start a song
	if ([KWCommonMethods isQuickTimeSevenInstalled])
	[tableView setDoubleAction:@selector(play:)];
	
//Needs to be set in Tiger (Took me a while to figure out since it worked since Jaguar without target)
[tableView setTarget:self];
	
	//When a movie ends we'll play the next song if it exists
	if ([KWCommonMethods isQuickTimeSevenInstalled])
	{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(movieEnded:) name:QTMovieDidEndNotification object:nil];
	}
	else
	{
	//EnterMovies for QuickTime 6 functions later to be used
	EnterMovies();
	
	//Make it look like we were never able to play songs :-)
	[totalTimeText setFrameOrigin:NSMakePoint([totalTimeText frame].origin.x+63,[totalTimeText frame].origin.y)]; 
	
	[previousButton setHidden:YES];
	[playButton setHidden:YES];
	[nextButton setHidden:YES];
	[stopButton setHidden:YES];
	
	[previousButton setEnabled:YES];
	[playButton setEnabled:YES];
	[nextButton setEnabled:YES];
	[stopButton setEnabled:YES];
	}
	
//Protected files can't be converted
protectedFiles = [[NSArray arrayWithObjects:@"m4p",@"m4b",NSFileTypeForHFSTypeCode('M4P '),NSFileTypeForHFSTypeCode('M4B '),nil] retain];
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

//Show a open panel to add files
- (IBAction)openFiles:(id)sender
{
NSOpenPanel *sheet = [NSOpenPanel openPanel];
[sheet setCanChooseFiles:YES];
[sheet setCanChooseDirectories:YES];
[sheet setAllowsMultipleSelection:YES];
	
[sheet beginSheetForDirectory:nil file:nil types:allowedFileTypes modalForWindow:mainWindow modalDelegate:self didEndSelector:@selector(openPanelDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

//Check all files
- (void)openPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
[sheet orderOut:self];

	if (returnCode == NSOKButton)
	[self checkFiles:[sheet filenames]];
}

//Delete the selected row(s) and stop playing since it interferes with our tracks
- (IBAction)deleteFiles:(id)sender
{
id myObject;

	//Stop playing
	if ([KWCommonMethods isQuickTimeSevenInstalled])
	[self stop:self];
	
	// get and sort enumerator in descending order
	NSEnumerator *selectedItemsEnum = [[[[tableView selectedRowEnumerator] allObjects]
			sortedArrayUsingSelector:@selector(compare:)] reverseObjectEnumerator];
	
	// remove object in descending order
	myObject = [selectedItemsEnum nextObject];
	while (myObject) {
		[tableData removeObjectAtIndex:[myObject intValue]];
		myObject = [selectedItemsEnum nextObject];
	}
	
[tableView deselectAll:nil];
[tableView reloadData];
	
[[NSNotificationCenter defaultCenter] postNotificationName:@"KWChangeBurnStatus" object:[NSNumber numberWithBool:([tableView numberOfRows] > 0)]];

[self setTotal];
}

//Add the file to the tableview
- (void)addFile:(NSString *)path
{
NSString *fileType = NSFileTypeForHFSTypeCode([[[[NSFileManager defaultManager] fileAttributesAtPath:path traverseLink:YES] objectForKey:NSFileHFSTypeCode] longValue]);

	if ([[tableViewPopup title] isEqualTo:NSLocalizedString(@"MP3 Disc",@"Localized")] && ![[[path pathExtension] lowercaseString] isEqualTo:@"mp3"] && ![fileType isEqualTo:@"'MPG3'"] && ![fileType isEqualTo:@"'Mp3 '"] && ![fileType isEqualTo:@"'MP3 '"])
	{
	NSMutableDictionary *rowData = [NSMutableDictionary dictionary];
	[rowData setObject:[[NSFileManager defaultManager] displayNameAtPath:path] forKey:@"Name"];
	[rowData setObject:path forKey:@"Path"];
	[notCompatibleFiles addObject:rowData];
	}
	else if ([[tableViewPopup title] isEqualTo:NSLocalizedString(@"DVD-Audio",@"Localized")] && ![[[path pathExtension] lowercaseString] isEqualTo:@"wav"] && ![[[path pathExtension] lowercaseString] isEqualTo:@"flac"] && ![fileType isEqualTo:@"'WAVE'"] && ![fileType isEqualTo:@"'.WAV'"])
	{
	NSMutableDictionary *rowData = [NSMutableDictionary dictionary];
	[rowData setObject:[[NSFileManager defaultManager] displayNameAtPath:path] forKey:@"Name"];
	[rowData setObject:path forKey:@"Path"];
	[notCompatibleFiles addObject:rowData];
	}
	else
	{
	NSMutableDictionary *rowData = [NSMutableDictionary dictionary];

		if ([KWCommonMethods isQuickTimeSevenInstalled])
		[self stop:self];
	
	float time = [self getMovieDuration:path];
	
	[rowData setObject:[[NSFileManager defaultManager] displayNameAtPath:path] forKey:@"Name"];
	[rowData setObject:path forKey:@"Path"];
	
		if ([[tableViewPopup title] isEqualTo:NSLocalizedString(@"Audio CD",@"Localized")])
		[rowData setObject:[KWCommonMethods formatTime:time] forKey:@"Time"];
		else
		[rowData setObject:[KWCommonMethods makeSizeFromFloat:[[[[NSFileManager defaultManager] fileAttributesAtPath:path traverseLink:YES] objectForKey:NSFileSize] floatValue]] forKey:@"Time"];
	
	[rowData setObject:[[NSNumber numberWithInt:time] stringValue] forKey:@"RealTime"];
	[rowData setObject:[[[NSWorkspace sharedWorkspace] iconForFile:path] retain] forKey:@"Icon"];
	
		if ([tableData count] > 0 && [[[[tableData objectAtIndex:0] objectForKey:@"Name"] lowercaseString] isEqualTo:@"audio_ts"] && [[tableViewPopup title] isEqualTo:@"DVD-Audio"])
		{
		[previousButton setEnabled:YES];
		[playButton setEnabled:YES];
		[nextButton setEnabled:YES];
		[stopButton setEnabled:YES];
		
		[tableData removeAllObjects];
		currentDropRow = -1;
		}
		
		if ([[tableViewPopup title] isEqualTo:NSLocalizedString(@"MP3 Disc",@"Localized")])
		{
		TagAPI *Tag = [[TagAPI alloc] initWithGenreList:nil];
		[Tag examineFile:path];
		[rowData setObject:[[Tag getArtist] copy] forKey:@"Artist"];
		[rowData setObject:[[Tag getAlbum] copy] forKey:@"Album"];
		[Tag release];
		}
	
		if ([[tableViewPopup title] isEqualTo:NSLocalizedString(@"Audio CD",@"Localized")] && [[[path pathExtension] lowercaseString] isEqualTo:@"mp3"])
		{
		TagAPI *Tag = [[TagAPI alloc] initWithGenreList:nil];
		[Tag examineFile:path];
		[rowData setObject:[NSString stringWithString:[Tag getTitle]] forKey:@"Title"];
		[rowData setObject:[NSString stringWithString:[Tag getArtist]] forKey:@"Performer"];
		[rowData setObject:[NSString stringWithString:[Tag getComposer]] forKey:@"Composer"];
		[rowData setObject:@"" forKey:@"Songwriter"];
		[rowData setObject:@"" forKey:@"Arranger"];
		[rowData setObject:[NSString stringWithString:[Tag getComments]] forKey:@"Notes"];
		[rowData setObject:@"" forKey:@"Private"];
	
			if ([CDTextDict count] == 0)
			{
			[CDTextDict setObject:[Tag getAlbum] forKey:@"Title"];
			[CDTextDict setObject:[Tag getArtist] forKey:@"Performer"];
			[CDTextDict setObject:@"" forKey:@"Composer"];
			[CDTextDict setObject:@"" forKey:@"Songwriter"];
			[CDTextDict setObject:@"" forKey:@"Arranger"];
			[CDTextDict setObject:@"" forKey:@"Notes"];
			[CDTextDict setObject:@"" forKey:@"DiscIdent"];
			[CDTextDict setObject:@"Other..." forKey:@"GenreCode"];
				if ([[Tag getGenreNames] count] > 0)
				[CDTextDict setObject:[[Tag getGenreNames] objectAtIndex:0] forKey:@"GenreName"];
				else
				[CDTextDict setObject:@"" forKey:@"GenreName"];
			[CDTextDict setObject:@"" forKey:@"PrivateUse"];
			[CDTextDict setObject:[NSNumber numberWithBool:NO] forKey:@"EnableMCN"];
			[CDTextDict setObject:[NSNumber numberWithInt:0] forKey:@"MCN"];
			}
	
		[Tag release];
		
	
		[rowData setObject:[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultPregap"] forKey:@"Pregap"];
		[rowData setObject:[NSNumber numberWithBool:NO] forKey:@"Pre-emphasis"];
		[rowData setObject:[NSNumber numberWithBool:NO] forKey:@"EnableISRC"];
		[rowData setObject:@"" forKey:@"ISRC"];
		[rowData setObject:[NSNumber numberWithBool:NO] forKey:@"ISRCCDText"];
		[rowData setObject:[NSNumber numberWithBool:NO] forKey:@"IndexPoints"];
		}
		else if ([[tableViewPopup title] isEqualTo:NSLocalizedString(@"Audio CD",@"Localized")])
		{
		[rowData setObject:@"" forKey:@"Title"];
		[rowData setObject:@"" forKey:@"Performer"];
		[rowData setObject:@"" forKey:@"Composer"];
		[rowData setObject:@"" forKey:@"Songwriter"];
		[rowData setObject:@"" forKey:@"Arranger"];
		[rowData setObject:@"" forKey:@"Notes"];
		[rowData setObject:@"" forKey:@"Private"];
		[rowData setObject:[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultPregap"] forKey:@"Pregap"];
		[rowData setObject:[NSNumber numberWithBool:NO] forKey:@"Pre-emphasis"];
		[rowData setObject:[NSNumber numberWithBool:NO] forKey:@"EnableISRC"];
		[rowData setObject:@"" forKey:@"ISRC"];
		[rowData setObject:[NSNumber numberWithBool:NO] forKey:@"ISRCCDText"];
		[rowData setObject:[NSNumber numberWithBool:NO] forKey:@"IndexPoints"];
		}
			
		if (currentDropRow > -1)
		{
		[tableData insertObject:[rowData copy] atIndex:currentDropRow];
		currentDropRow = currentDropRow + 1;
		}
		else
		{
		[tableData addObject:[rowData copy]];
		
			if ([[tableViewPopup title] isEqualTo:NSLocalizedString(@"MP3 Disc",@"Localized")])
			{
			NSSortDescriptor *sortDescriptor;
			
				if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"KWCreateAlbumFolders"] boolValue])
				sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"Album" ascending:YES];
				else if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"KWCreateAlbumFolders"] boolValue])
				sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"Artist" ascending:YES];
				else
				sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"Name" ascending:YES];
				
			[tableData sortUsingDescriptors:[NSArray arrayWithObject:sortDescriptor]];
			[sortDescriptor release];
			}
		}
		
	[tableView reloadData];

	[self setTotal];
	}
}

- (void)addDVDFolder:(NSString *)path
{
[previousButton setEnabled:NO];
[playButton setEnabled:NO];
[nextButton setEnabled:NO];
[stopButton setEnabled:NO];

NSMutableDictionary *rowData = [NSMutableDictionary dictionary];
[rowData setObject:[[NSFileManager defaultManager] displayNameAtPath:path] forKey:@"Name"];
[rowData setObject:path forKey:@"Path"];
[rowData setObject:[KWCommonMethods makeSizeFromFloat:[KWCommonMethods calculateRealFolderSize:path]] forKey:@"Time"];
[rowData setObject:[[[NSWorkspace sharedWorkspace] iconForFile:path] retain] forKey:@"Icon"];

[tableData removeAllObjects];
[tableData addObject:rowData];
[tableView reloadData];
}

- (void)checkFiles:(NSArray *)paths
{
[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setCancelAdding) name:@"audioCancelAdding" object:nil];

cancelAddingFiles = NO;

progressPanel = [[KWProgress alloc] init];
[progressPanel setTask:NSLocalizedString(@"Checking files...",@"Localized")];
[progressPanel setStatus:NSLocalizedString(@"Scanning for for file and folders",@"Localized")];
[progressPanel setIcon:[NSImage imageNamed:@"Burn"]];
[progressPanel setMaximumValue:[NSNumber numberWithDouble:0]];
[progressPanel setCancelNotification:@"audioCancelAdding"];
[progressPanel beginSheetForWindow:mainWindow];

[NSThread detachNewThreadSelector:@selector(startThread:) toTarget:self withObject:paths];
}

- (void)setCancelAdding
{
cancelAddingFiles = YES;
}

- (BOOL)isProtected:(NSString *)path
{
	int x;
	for (x=0;x<[protectedFiles count];x++)
	{
		if ([[[path pathExtension] lowercaseString] isEqualTo:[protectedFiles objectAtIndex:x]])
		{
		return YES;
		}
		else if ([NSFileTypeForHFSTypeCode([[[[NSFileManager defaultManager] fileAttributesAtPath:path traverseLink:YES] objectForKey:NSFileHFSTypeCode] longValue]) isEqualTo:[protectedFiles objectAtIndex:x]])
		{
		return YES;
		}
	}
return NO;
}

//Check if the file is folder or file, if it is folder scan it, when a file
//if it is a correct file
- (void)startThread:(NSArray *)paths
{
//Needed because we're in a new thread
NSAutoreleasePool *pool=[[NSAutoreleasePool alloc] init];

	if ([paths count] == 1 && [[[[paths objectAtIndex:0] lastPathComponent] lowercaseString] isEqualTo:@"audio_ts"] && [[tableViewPopup title] isEqualTo:@"DVD-Audio"])
	{
	[self addDVDFolder:[paths objectAtIndex:0]];
	}
	else if ([paths count] == 1 && [[NSFileManager defaultManager] fileExistsAtPath:[[paths objectAtIndex:0] stringByAppendingPathComponent:@"AUDIO_TS"]] && [[tableViewPopup title] isEqualTo:@"DVD-Audio"])
	{
	[self addDVDFolder:[[paths objectAtIndex:0] stringByAppendingPathComponent:@"AUDIO_TS"]];
	}
	else
	{
		int x = 0;
		for (x=0;x<[paths count];x++)
		{
		NSAutoreleasePool *subPool = [[NSAutoreleasePool alloc] init];
		
			if (cancelAddingFiles == NO)
			{
			NSDirectoryEnumerator *enumer;
			NSString* pathName;
			NSString *realPath = [self getRealPath:[paths objectAtIndex:x]];
			BOOL fileIsFolder = NO;
			int i=0;
	
			[[NSFileManager defaultManager] fileExistsAtPath:realPath isDirectory:&fileIsFolder];

				if (fileIsFolder)
				{
				enumer = [[NSFileManager defaultManager] enumeratorAtPath:realPath];
					while (pathName = [enumer nextObject])
					{
					NSAutoreleasePool *subPool = [[NSAutoreleasePool alloc] init];
					
						if (cancelAddingFiles == NO)
						{
						NSString *realPathName = [self getRealPath:pathName];
			
							if (![realPathName isEqualTo:@".DS_Store"])
							{
								BOOL fileAdded = NO;
								for (i=0;i<[allowedFileTypes count];i++)
								{
								NSAutoreleasePool *subPool = [[NSAutoreleasePool alloc] init];
								
									if (fileAdded == NO)
									{
										if ([[[realPathName pathExtension]  lowercaseString] isEqualTo:[allowedFileTypes objectAtIndex:i]])
										{
											if ([self isProtected:[[realPath stringByAppendingString: @"/"] stringByAppendingString:realPathName]])
											[someProtected addObject:[[realPath stringByAppendingString: @"/"] stringByAppendingString:realPathName]];
											else
											[self performSelectorOnMainThread:@selector(addFile:) withObject:[[realPath stringByAppendingString: @"/"] stringByAppendingString:realPathName] waitUntilDone:YES];
										
										fileAdded = YES;
										}
										else if ([NSFileTypeForHFSTypeCode([[[[NSFileManager defaultManager] fileAttributesAtPath:[[realPath stringByAppendingString: @"/"] stringByAppendingString:pathName] traverseLink:YES] objectForKey:NSFileHFSTypeCode] longValue]) isEqualTo:[allowedFileTypes objectAtIndex:i]])
										{
											if ([self isProtected:[[realPath stringByAppendingString: @"/"] stringByAppendingString:pathName]])
											[someProtected addObject:[[realPath stringByAppendingString: @"/"] stringByAppendingString:pathName]];
											else
											[self performSelectorOnMainThread:@selector(addFile:) withObject:[[realPath stringByAppendingString: @"/"] stringByAppendingString:realPathName] waitUntilDone:YES];
										
										fileAdded = YES;
										}
									}
									
								[subPool release];
								}
							}
						}
						
					[subPool release];
					}
				}
				else
				{
					BOOL fileAdded = NO;
					for (i=0;i<[allowedFileTypes count];i++)
					{
					NSAutoreleasePool *subPool = [[NSAutoreleasePool alloc] init];
					
						if (fileAdded == NO)
						{
							if ([[[realPath pathExtension] lowercaseString] isEqualTo:[allowedFileTypes objectAtIndex:i]])
							{
								if ([self isProtected:realPath])
								[someProtected addObject:realPath];
								else
								[self performSelectorOnMainThread:@selector(addFile:) withObject:realPath waitUntilDone:YES];
							
							fileAdded = YES;
							}
							else if ([NSFileTypeForHFSTypeCode([[[[NSFileManager defaultManager] fileAttributesAtPath:realPath traverseLink:YES] objectForKey:NSFileHFSTypeCode] longValue]) isEqualTo:[allowedFileTypes objectAtIndex:i]])
							{
								if ([self isProtected:realPath])
								[someProtected addObject:realPath];
								else
								[self performSelectorOnMainThread:@selector(addFile:) withObject:realPath waitUntilDone:YES];
							
							fileAdded = YES;
							}
						}
					
					[subPool release];
					}
				}
			}
		[subPool release];
		}
	}
	
cancelAddingFiles = NO;
currentDropRow = -1;

[progressPanel endSheet];
[progressPanel release];

//Stop being the observer
[[NSNotificationCenter defaultCenter] removeObserver:self name:@"audioCancelAdding" object:nil];

[self performSelectorOnMainThread:@selector(showAlert) withObject:nil waitUntilDone:NO];

[pool release];
}

/////////////////////////
// Option menu actions //
/////////////////////////

#pragma mark -
#pragma mark •• Option menu actions

- (IBAction)accessOptions:(id)sender
{
id optionsPopup;
id optionsMappings;

	if ([[tableViewPopup title] isEqualTo:NSLocalizedString(@"Audio CD",@"Localized")])
	{
	optionsPopup = audioOptionsPopup;
	optionsMappings = audioOptionsMappings;
	}
	else
	{
	optionsPopup = mp3OptionsPopup;
	optionsMappings = mp3OptionsMappings;
	}
	
	//Setup options menus
	int i = 0;
	for (i=0;i<[optionsPopup numberOfItems]-1;i++)
	{
	[[optionsPopup itemAtIndex:i+1] setState:[[[NSUserDefaults standardUserDefaults] objectForKey:[optionsMappings objectAtIndex:i]] intValue]];
	}

[optionsPopup performClick:self];
}

- (IBAction)setOption:(id)sender
{
id optionsPopup;
id optionsMappings;

	if ([[tableViewPopup title] isEqualTo:NSLocalizedString(@"Audio CD",@"Localized")])
	{
	optionsPopup = audioOptionsPopup;
	optionsMappings = audioOptionsMappings;
	}
	else
	{
	optionsPopup = mp3OptionsPopup;
	optionsMappings = mp3OptionsMappings;
	}

[[NSUserDefaults standardUserDefaults] setBool:([sender state] == NSOffState) forKey:[optionsMappings objectAtIndex:[optionsPopup indexOfItem:sender] - 1]];
[[NSUserDefaults standardUserDefaults] synchronize];

[[NSNotificationCenter defaultCenter] postNotificationName:@"KWOptionsChanged" object:nil];
}

/////////////////////
// Convert actions //
/////////////////////

#pragma mark -
#pragma mark •• Convert actions

- (void)showAlert
{
	if ([notCompatibleFiles count] > 0 && [someProtected count] > 0)
	{
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert addButtonWithTitle:NSLocalizedString(@"Yes",@"Localized")];
	[alert addButtonWithTitle:NSLocalizedString(@"No",@"Localized")];
	[[[alert buttons] objectAtIndex:1] setKeyEquivalent:@"\E"];
			
		if ([notCompatibleFiles count] > 1)
		{
		[alert setMessageText:NSLocalizedString(@"Some incompatible files",@"Localized")];
			if ([someProtected count] > 1)
			{
				if ([[tableViewPopup title] isEqualTo:NSLocalizedString(@"DVD-Audio",@"Localized")])
				[alert setInformativeText:NSLocalizedString(@"Would you like to convert those files to wav?\n(Note: there are a few protected mp4 files which can't be converted)",@"Localized")];
				else
				[alert setInformativeText:NSLocalizedString(@"Would you like to convert those files to mp3?\n(Note: there are a few protected mp4 files which can't be converted)",@"Localized")];
			}
			else
			{
				if ([[tableViewPopup title] isEqualTo:NSLocalizedString(@"DVD-Audio",@"Localized")])
				[alert setInformativeText:NSLocalizedString(@"Would you like to convert those files to wav?\n(Note: there is a protected mp4 file which can't be converted)",@"Localized")];
				else
				[alert setInformativeText:NSLocalizedString(@"Would you like to convert those files to mp3?\n(Note: there is a protected mp4 file which can't be converted)",@"Localized")];
			}
		}
		else
		{
		[alert setMessageText:NSLocalizedString(@"One incompatible file",@"Localized")];
			if ([someProtected count] > 1)
			{
				if ([[tableViewPopup title] isEqualTo:NSLocalizedString(@"DVD-Audio",@"Localized")])
				[alert setInformativeText:NSLocalizedString(@"Would you like to convert that file to wav?\n(Note: there are a few protected mp4 files which can't be converted)",@"Localized")];
				else
				[alert setInformativeText:NSLocalizedString(@"Would you like to convert that file to mp3?\n(Note: there are a few protected mp4 files which can't be converted)",@"Localized")];
			}
			else
			{
				if ([[tableViewPopup title] isEqualTo:NSLocalizedString(@"DVD-Audio",@"Localized")])
				[alert setInformativeText:NSLocalizedString(@"Would you like to convert that file to wav?\n(Note: there is a protected mp4 file which can't be converted)",@"Localized")];
				else
				[alert setInformativeText:NSLocalizedString(@"Would you like to convert that file to mp3?\n(Note: there is a protected mp4 file which can't be converted)",@"Localized")];
			}
		}
		
	[alert setAlertStyle:NSWarningAlertStyle];
	
	[someProtected removeAllObjects];
	
	[alert beginSheetModalForWindow:mainWindow modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:nil];
	}
	else if ([notCompatibleFiles count] > 0)
	{
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert addButtonWithTitle:NSLocalizedString(@"Yes",@"Localized")];
	[alert addButtonWithTitle:NSLocalizedString(@"No",@"Localized")];
	[[[alert buttons] objectAtIndex:1] setKeyEquivalent:@"\E"];
			
		if ([notCompatibleFiles count] > 1)
		{
		[alert setMessageText:NSLocalizedString(@"Some incompatible files",@"Localized")];
			if ([[tableViewPopup title] isEqualTo:NSLocalizedString(@"DVD-Audio",@"Localized")])
			[alert setInformativeText:NSLocalizedString(@"Would you like to convert those files to wav?",@"Localized")];
			else
			[alert setInformativeText:NSLocalizedString(@"Would you like to convert those files to mp3?",@"Localized")];
		}
		else
		{
		[alert setMessageText:NSLocalizedString(@"One incompatible file",@"Localized")];
			if ([[tableViewPopup title] isEqualTo:NSLocalizedString(@"DVD-Audio",@"Localized")])
			[alert setInformativeText:NSLocalizedString(@"Would you like to convert that file to wav?",@"Localized")];
			else
			[alert setInformativeText:NSLocalizedString(@"Would you like to convert that file to mp3?",@"Localized")];
		}
		
	[alert setAlertStyle:NSWarningAlertStyle];
	
	[alert beginSheetModalForWindow:mainWindow modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:nil];
	}
	else if ([someProtected count] > 0)
	{
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert addButtonWithTitle:NSLocalizedString(@"OK",@"Localized")];
			
		if ([someProtected count] > 1)
		{
		[alert setMessageText:NSLocalizedString(@"Some protected mp4 files",@"Localized")];
		[alert setInformativeText:NSLocalizedString(@"These files can't be converted",@"Localized")];
		}
		else
		{
		[alert setMessageText:NSLocalizedString(@"One protected mp4 file",@"Localized")];
		[alert setInformativeText:NSLocalizedString(@"This file can't be converted",@"Localized")];
		}
		
	[alert setAlertStyle:NSWarningAlertStyle];
	
	[someProtected removeAllObjects];
	[alert beginSheetModalForWindow:mainWindow modalDelegate:self didEndSelector:nil contextInfo:nil];
	}
	else
	{
	[someProtected removeAllObjects];
	}
}

//Alert did end, whe don't need to do anything special, well releasing the alert we do, the user should
- (void)alertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
[[alert window] orderOut:self];

	if (returnCode == NSAlertFirstButtonReturn) 
	{
		NSOpenPanel *sheet = [NSOpenPanel openPanel];
		[sheet setCanChooseFiles: NO];
		[sheet setCanChooseDirectories: YES];
		[sheet setAllowsMultipleSelection: NO];
		[sheet setCanCreateDirectories: YES];
		[sheet setPrompt:NSLocalizedString(@"Choose",@"Localized")];
			if ([[tableViewPopup title] isEqualTo:NSLocalizedString(@"DVD-Audio",@"Localized")])
			[sheet setMessage:NSLocalizedString(@"Choose a location to save the wav files",@"Localized")];
			else
			[sheet setMessage:NSLocalizedString(@"Choose a location to save the mp3 files",@"Localized")];
		
		[sheet beginSheetForDirectory:nil file:nil types:nil modalForWindow:mainWindow modalDelegate:self didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:) contextInfo:nil];
	}
	else
	{
	[notCompatibleFiles removeAllObjects];
	}
}

//Place has been chosen change our editfield with this path
- (void)savePanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
[sheet orderOut:self];

	if (returnCode == NSOKButton) 
	{
	progressPanel = [[KWProgress alloc] init];
	[progressPanel setTask:NSLocalizedString(@"Preparing to encode",@"Localized")];
	[progressPanel setStatus:NSLocalizedString(@"Checking file...",@"Localized")];
		if ([[tableViewPopup title] isEqualTo:NSLocalizedString(@"DVD-Audio",@"Localized")])
		[progressPanel setIcon:[[NSWorkspace sharedWorkspace] iconForFileType:@"wav"]];
		else
		[progressPanel setIcon:[[NSWorkspace sharedWorkspace] iconForFileType:@"mp3"]];
	[progressPanel setMaximumValue:[NSNumber numberWithInt:100*[notCompatibleFiles count]]];
	[progressPanel beginSheetForWindow:mainWindow];
	
	[NSThread detachNewThreadSelector:@selector(convertFiles:) toTarget:self withObject:[sheet filename]];
	}
	else
	{
	[notCompatibleFiles removeAllObjects];
	}
}

- (void)convertFiles:(NSString *)path
{
NSAutoreleasePool *pool=[[NSAutoreleasePool alloc] init];

NSMutableArray *onlyFilesMutable = [[NSMutableArray alloc] init];

	int x;
	for (x=0;x<[notCompatibleFiles count];x++)
	{
	[onlyFilesMutable addObject:[[notCompatibleFiles objectAtIndex:x] objectForKey:@"Path"]];
	}

[notCompatibleFiles removeAllObjects];
NSArray *onlyFiles = [onlyFilesMutable copy];
[onlyFilesMutable release];

	converter = [[KWConverter alloc] init];
		int result;
		if ([[tableViewPopup title] isEqualTo:NSLocalizedString(@"DVD-Audio",@"Localized")])
		result = [converter batchConvert:onlyFiles destination:path useRegion:@"PAL" useKind:@"wav"];
		else
		result = [converter batchConvert:onlyFiles destination:path useRegion:@"PAL" useKind:@"mp3"];
	NSArray *failedFiles = [[converter failureArray] copy];
	NSArray *succeededFiles = [[converter succesArray] copy];
	
[converter release];

	int y;
	for (y=0;y<[succeededFiles count];y++)
	{
	[self addFile:[succeededFiles objectAtIndex:y]];
	}
	
[succeededFiles release];

[progressPanel endSheet];
[progressPanel release];

	if (result == 0)
	{
		if ([onlyFiles count] > 1)
		[[NSNotificationCenter defaultCenter] postNotificationName:@"growlFinishedConverting" object:[[NSLocalizedString(@"Finished converting ",@"Localized") stringByAppendingString:[[NSNumber numberWithInt:[onlyFiles count]] stringValue]] stringByAppendingString:NSLocalizedString(@" files",@"Localized")]];
		else
		[[NSNotificationCenter defaultCenter] postNotificationName:@"growlFinishedConverting" object:[[NSLocalizedString(@"Finished converting ",@"Localized") stringByAppendingString:[[NSNumber numberWithInt:[onlyFiles count]] stringValue]] stringByAppendingString:NSLocalizedString(@" file",@"Localized")]];
	}
	else if (result == 1)
	{
	[self performSelectorOnMainThread:@selector(showConvertFailAlert:) withObject:failedFiles waitUntilDone:NO];
	}

[pool release];
}

- (void)showConvertFailAlert:(NSArray *)descriptions
{
NSAlert *alert = [[[NSAlert alloc] init] autorelease];
[alert addButtonWithTitle:NSLocalizedString(@"OK",@"Localized")];
[alert addButtonWithTitle:NSLocalizedString(@"Open Log",@"Localized")];
		
	if ([descriptions count] > 1)
	[alert setMessageText:NSLocalizedString(@"Burn failed to encode some files",@"Localized")];
	else
	[alert setMessageText:NSLocalizedString(@"Burn failed to encode one file",@"Localized")];
		
	int i;
	NSString *descriptionsList = @"";
	for (i=0;i<[descriptions count];i++)
	{
		if ([descriptionsList isEqualTo:@""])
		descriptionsList = [descriptionsList stringByAppendingString:[descriptions objectAtIndex:i]];
		else
		descriptionsList = [[descriptionsList stringByAppendingString:@"\n"] stringByAppendingString:[descriptions objectAtIndex:i]];
	}

[alert setInformativeText:descriptionsList];
[alert setAlertStyle:NSWarningAlertStyle];
[alert beginSheetModalForWindow:mainWindow modalDelegate:self didEndSelector:@selector(failedAlertDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

- (void)failedAlertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
[[alert window] orderOut:self];

	if (returnCode == NSAlertSecondButtonReturn) 
	{
	[[NSWorkspace sharedWorkspace] openFile:[NSHomeDirectory() stringByAppendingString:@"/Library/Logs/Burn Errors.log"] withApplication:@"TextEdit"];
	}
}

///////////////////////////
// Disc creation actions //
///////////////////////////

#pragma mark -
#pragma mark •• Disc creation actions

- (void)burn
{
[myDiscCreationController burnDiscWithName:[discName stringValue] withType:1];
}

- (void)saveImage
{
[myDiscCreationController saveImageWithName:[discName stringValue] withType:1 withFileSystem:@""];
}

- (id)myTrackWithBurner:(KWBurner *)burner
{
	//Stop the music before burning
	if ([KWCommonMethods isQuickTimeSevenInstalled])
	[self stop:self];

	if ([KWCommonMethods isPanther] && [[tableViewPopup title] isEqualTo:NSLocalizedString(@"DVD-Audio",@"Localized")])
	{
	NSString *outputFolder = [KWCommonMethods temporaryLocation:[discName stringValue] saveDescription:NSLocalizedString(@"Choose a location to save a temporary folder",@"Localized")];
		
		if (outputFolder)
		{
		[temporaryFiles addObject:outputFolder];
	
		int succes = [self authorizeFolderAtPathIfNeededAtPath:outputFolder];
	
			if (succes == 0)
			return [[KWTrackProducer alloc] getTrackForFolder:outputFolder ofType:2 withDiscName:[discName stringValue] withGlobalSize:[self totalSize]];
			else
			return [NSNumber numberWithInt:succes];
		}
		else
		{
		return [NSNumber numberWithInt:2];
		}
	}
		
	if ([[tableViewPopup title] isEqualTo:NSLocalizedString(@"MP3 Disc",@"Localized")])
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
	else if ([[tableViewPopup title] isEqualTo:@"DVD-Audio"])
	{
		if ([tableData count] > 0 && [[[[tableData objectAtIndex:0] objectForKey:@"Name"] lowercaseString] isEqualTo:@"audio_ts"] && [[tableViewPopup title] isEqualTo:@"DVD-Audio"])
		{
		DRFolder *rootFolder = [DRFolder virtualFolderWithName:[discName stringValue]];
		[rootFolder addChild:[DRFolder folderWithPath:[[tableData objectAtIndex:0] objectForKey:@"Path"]]];
		
		[rootFolder setExplicitFilesystemMask:(DRFilesystemInclusionMaskUDF)];
			
		return [rootFolder retain];
		}
		else
		{
		int succes = NSOKButton;
		
		NSString *outputFile = [KWCommonMethods temporaryLocation:[discName stringValue] saveDescription:NSLocalizedString(@"Choose a location to save the DVD folder",@"Localized")];
				
			if (outputFile)
			{
			[temporaryFiles addObject:outputFile];
			
			succes = [self authorizeFolderAtPathIfNeededAtPath:outputFile];
			}
			else
			{
			return [NSNumber numberWithInt:2];
			}
			
			if (succes == 0)
			{
			DRFolder *newObject = [DRFolder virtualFolderWithName:[discName stringValue]];
			[newObject addChild:[DRFolder folderWithPath:[outputFile stringByAppendingPathComponent:@"AUDIO_TS"]]];
			[newObject setExplicitFilesystemMask:DRFilesystemInclusionMaskUDF];
				
			return [newObject retain];
			}
			else
			{
			return [NSNumber numberWithInt:succes];
			}
		}
	}
	else
	{
		if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWUseCDText"] == YES && ![KWCommonMethods isPanther])
		{
		[burner addBurnProperties:[self getBurnProperties]];
		return (NSArray *)[self createLayoutForBurn];
		}
		else if ([KWCommonMethods isPanther])
		{
		return [self getSavePantherAudioCDArray];
		}
		else
		{
		NSMutableArray*	trackArray = [NSMutableArray arrayWithCapacity:[tableData count]];
		
			int i;
			for (i=0;i<[tableData count];i++)
			{
			DRTrack* track = [DRTrack trackForAudioFile:[[tableData objectAtIndex:i] valueForKey: @"Path"]];
			NSMutableDictionary* properties;
			
			properties = [[track properties] mutableCopy];
			[properties setObject:[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultPregap"] intValue]*75] forKey:DRPreGapLengthKey];
			[track setProperties:properties];
			[trackArray addObject:[track retain]];
			}

		return trackArray;
		}
	}

return nil;
}

- (int)authorizeFolderAtPathIfNeededAtPath:(NSString *)path
{
int succes;

	if ([tableData count] > 0 && [[[[tableData objectAtIndex:0] objectForKey:@"Name"] lowercaseString] isEqualTo:@"audio_ts"])
	{
	[[NSFileManager defaultManager] createDirectoryAtPath:path attributes:nil];
	
	BOOL result = [[NSFileManager defaultManager] linkPath:[[tableData objectAtIndex:0] objectForKey:@"Path"] toPath:[path stringByAppendingPathComponent:[[tableData objectAtIndex:0] objectForKey:@"Name"]] handler:nil];

		if (result == NO)
		result = [[NSFileManager defaultManager] copyPath:[[tableData objectAtIndex:0] objectForKey:@"Path"] toPath:[path stringByAppendingPathComponent:[[tableData objectAtIndex:0] objectForKey:@"Name"]] handler:nil];
	
		if (result)
		succes = 0;
		else
		succes = 1;
	}
	else
	{
	float maximumSize;
	if (![KWCommonMethods isPanther])
	maximumSize = [self totalSize];
	else
	maximumSize = [self totalSize] * 2;
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWMaximumValueChanged" object:[NSNumber numberWithFloat:maximumSize]];
	
	NSMutableArray *files = [NSMutableArray array];

		int i;
		for (i=0;i<[tableData count];i++)
		{
		[files addObject:[[tableData objectAtIndex:i] objectForKey:@"Path"]];
		}
		
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWTaskChanged" object:NSLocalizedString(@"Authoring DVD...",@"Localized")];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWStatusChanged" object:NSLocalizedString(@"Generating DVD folder",@"Localized")];
	
	DVDAuthorizer = [[KWDVDAuthorizer alloc] init];
	succes = [DVDAuthorizer createStandardDVDAudioFolderAtPath:[path retain] withFiles:files];
	[DVDAuthorizer release];
	}
	
return succes;
}

//////////////////
// Save actions //
//////////////////

#pragma mark -
#pragma mark •• Save actions

- (void)openBurnDocument:(NSString *)path
{	
NSDictionary *burnFile = [NSDictionary dictionaryWithContentsOfFile:path];

[tableViewPopup setObjectValue:[burnFile objectForKey:@"KWSubType"]];

	NSDictionary *savedDictionary = [burnFile objectForKey:@"KWProperties"];
	NSArray *savedArray = [savedDictionary objectForKey:@"Files"];
	
	[self tableViewPopup:self];
	NSMutableDictionary *rowData = [NSMutableDictionary dictionary];
	int time=0;

	[tableData removeAllObjects];

		int i;
		for (i=0;i<[savedArray count];i++)
		{
			if ([[NSFileManager defaultManager] fileExistsAtPath:[[savedArray objectAtIndex:i] objectForKey:@"Path"]])
			{
			[rowData addEntriesFromDictionary:[savedArray objectAtIndex:i]];
			[rowData setObject:[[[NSWorkspace sharedWorkspace] iconForFile:[[savedArray objectAtIndex:i] objectForKey:@"Path"]] retain] forKey:@"Icon"];
			[tableData addObject:[[rowData mutableCopy] autorelease]];
			[rowData removeAllObjects];
			}
		}
		
		[tableView reloadData];
	
		[[NSNotificationCenter defaultCenter] postNotificationName:@"KWChangeBurnStatus" object:[NSNumber numberWithBool:([tableView numberOfRows] > 0)]];

		for (i=0;i<[tableData count];i++)
		{
		time = time + [[[tableData objectAtIndex:i] valueForKey: @"RealTime"] intValue];
		}

	[totalTimeText setStringValue:[NSLocalizedString(@"Total time: ",@"Localized") stringByAppendingString:[KWCommonMethods formatTime:time]]];

	if ([tableViewPopup indexOfSelectedItem] == 1 | [tableViewPopup indexOfSelectedItem] == 2)
	[discName setStringValue:[savedDictionary objectForKey:@"Name"]];
}

- (void)saveDocument
{
NSSavePanel *sheet = [NSSavePanel savePanel];
[sheet setRequiredFileType:@"burn"];
[sheet setCanSelectHiddenExtension:YES];
[sheet setMessage:NSLocalizedString(@"Choose a location to save the burn file",@"Localized")];
[sheet beginSheetForDirectory:nil file:[[discName stringValue] stringByAppendingString:@".burn"] modalForWindow:mainWindow modalDelegate:self didEndSelector:@selector(saveDocumentPanelDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

- (void)saveDocumentPanelDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
[sheet orderOut:self];

	if (returnCode == NSOKButton) 
	{
	NSMutableArray *tempArray = [tableData mutableCopy];
	NSMutableDictionary *tempDict;
	
		int i;
		for (i=0;i<[tempArray count];i++)
		{
		tempDict = [[tempArray objectAtIndex:i] mutableCopy];
		[tempDict removeObjectForKey:@"Icon"];
		[tempArray replaceObjectAtIndex:i withObject:tempDict];
		[tempDict release];
		}
	
	NSDictionary *burnFileProperties = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:tempArray,[discName stringValue],nil] forKeys:[NSArray arrayWithObjects:@"Files",@"Name",nil]];
	
	[[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:1],[NSNumber numberWithInt:[tableViewPopup indexOfSelectedItem]],burnFileProperties,nil] forKeys:[NSArray arrayWithObjects:@"KWType",@"KWSubType",@"KWProperties",nil]] writeToFile:[sheet filename] atomically:YES];
	
	[tempArray release];
	
		if ([sheet isExtensionHidden])
		[[NSFileManager defaultManager] changeFileAttributes:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:@"NSFileExtensionHidden"] atPath:[sheet filename]];
	}
}

///////////////////////
// Tableview actions //
///////////////////////

#pragma mark -
#pragma mark •• Tableview actions

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
	if ([[tableViewPopup title] isEqualTo:NSLocalizedString(@"Audio CD",@"Localized")] && ![KWCommonMethods isPanther])
	{
		if ([tableView selectedRow] == -1)
		[[NSNotificationCenter defaultCenter] postNotificationName:@"KWChangeInspector" object:tableView userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"KWAudioDisc",@"Type",nil]];
		else
		[[NSNotificationCenter defaultCenter] postNotificationName:@"KWChangeInspector" object:tableView userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"KWAudio",@"Type",nil]];
	}
	else if ([[tableViewPopup title] isEqualTo:NSLocalizedString(@"MP3 Disc",@"Localized")])
	{
		if ([tableView selectedRow] == -1)
		[[NSNotificationCenter defaultCenter] postNotificationName:@"KWChangeInspector" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"KWEmpty",@"Type",nil]];
		else if (![KWCommonMethods isPanther])
		[[NSNotificationCenter defaultCenter] postNotificationName:@"KWChangeInspector" object:[[tableData objectsAtIndexes:[tableView selectedRowIndexes]] retain] userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"KWAudioMP3",@"Type",nil]];
		else
		[[NSNotificationCenter defaultCenter] postNotificationName:@"KWChangeInspector" object:[[KWCommonMethods allSelectedItemsInTableView:tableView fromArray:tableData] retain] userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"KWAudioMP3",@"Type",nil]];
	}
	else
	{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWChangeInspector" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"KWEmpty",@"Type",nil]];
	}
}

//Set the current tableview and tabledata to the selected popup item
- (void)getTableView
{
	if ([[tableViewPopup title] isEqualTo:NSLocalizedString(@"Audio CD",@"Localized")])
	{
	tableData = AudioCDTableData;
	
	NSMutableArray *addFileTypes = [NSMutableArray array];
	if ([KWCommonMethods isQuickTimeSevenInstalled])
	addFileTypes = [[[QTMovie movieFileTypes:QTIncludeCommonTypes] mutableCopy] autorelease];
	else
	addFileTypes = [[[self getQuickTimeTypes] mutableCopy] autorelease];
		
		//Add protected files HFS Type, needed to warn
		[addFileTypes addObject:NSFileTypeForHFSTypeCode('M4P ')];
		[addFileTypes addObject:NSFileTypeForHFSTypeCode('M4B ')];

	allowedFileTypes = [addFileTypes retain];
	}
	else
	{
		if ([[tableViewPopup title] isEqualTo:NSLocalizedString(@"MP3 Disc",@"Localized")])
		tableData = Mp3TableData;
		else
		tableData = DVDAudioTableData;

	NSMutableArray *addFileTypes = [NSMutableArray array];
	if ([KWCommonMethods isQuickTimeSevenInstalled])
	addFileTypes = [[[QTMovie movieFileTypes:QTIncludeCommonTypes] mutableCopy] autorelease];
	else
	addFileTypes = [[[self getQuickTimeTypes] mutableCopy] autorelease];

		if ([addFileTypes indexOfObject:@"vob"] == NSNotFound)
		[addFileTypes addObject:@"vob"];
		
		if ([addFileTypes indexOfObject:@"wma"] == NSNotFound)
		[addFileTypes addObject:@"wma"];
		
		if ([addFileTypes indexOfObject:@"wmv"] == NSNotFound)
		[addFileTypes addObject:@"wmv"];
		
		if ([addFileTypes indexOfObject:@"asf"] == NSNotFound)
		[addFileTypes addObject:@"asf"];
		
		if ([addFileTypes indexOfObject:@"asx"] == NSNotFound)
		[addFileTypes addObject:@"asx"];
		
		if ([addFileTypes indexOfObject:@"ogg"] == NSNotFound)
		[addFileTypes addObject:@"ogg"];
		
		if ([addFileTypes indexOfObject:@"flv"] == NSNotFound)
		[addFileTypes addObject:@"flv"];
	
		if ([addFileTypes indexOfObject:@"rm"] == NSNotFound)
		[addFileTypes addObject:@"rm"];
		
		if ([addFileTypes indexOfObject:@"flac"] == NSNotFound)
		[addFileTypes addObject:@"flac"];
		
		//Add protected files HFS Type, needed to warn
		[addFileTypes addObject:NSFileTypeForHFSTypeCode('M4P ')];
		[addFileTypes addObject:NSFileTypeForHFSTypeCode('M4B ')];

	allowedFileTypes = [addFileTypes retain];
	}

[tableView reloadData];
}

- (void)setTableViewState:(NSNotification *)notif
{
	if ([[notif object] boolValue] == YES)
	[tableView registerForDraggedTypes:[NSArray arrayWithObjects:NSFilenamesPboardType,@"NSGeneralPboardType",@"CorePasteboardFlavorType 0x6974756E",nil]];
	else
	[tableView unregisterDraggedTypes];
}

-(BOOL)hasRows
{
if ([tableView numberOfRows] > 0)
return YES;
else
return NO;
}

-(id)myDataSource
{
return tableData;
}

//Popup clicked
- (IBAction)tableViewPopup:(id)sender
{
	//Stop playing
	if ([KWCommonMethods isQuickTimeSevenInstalled])
	[self stop:self];

[self getTableView];
[[[tableView tableColumnWithIdentifier:@"Time"] headerCell] setStringValue:NSLocalizedString(@"Size",@"Localized")];

	//Set the icon, tabview and textfield
	if ([[tableViewPopup title] isEqualTo:NSLocalizedString(@"Audio CD",@"Localized")])
	{
	[[[tableView tableColumnWithIdentifier:@"Time"] headerCell] setStringValue:NSLocalizedString(@"Time",@"Localized")];
	
	[popupIcon setImage:[NSImage imageNamed:@"Audio CD"]];
	[discName setEditable:NO];
		if (![KWCommonMethods isPanther])
		[accessOptions setEnabled:YES];
		else
		[accessOptions setEnabled:NO];
	
	[discName setStringValue:NSLocalizedString(@"Audio CD",@"Localized")];
	}
	else if ([[tableViewPopup title] isEqualTo:NSLocalizedString(@"MP3 Disc",@"Localized")])
	{
	[popupIcon setImage:[[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(kGenericCDROMIcon)]];
	[discName setEditable:YES];
	[discName setStringValue:NSLocalizedString(@"MP3 Disc",@"Localized")];
	[accessOptions setEnabled:YES];
	}
	else if ([[tableViewPopup title] isEqualTo:NSLocalizedString(@"DVD-Audio",@"Localized")])
	{
	[popupIcon setImage:[NSImage imageNamed:@"DVD"]];
	[discName setEditable:YES];
	[discName setStringValue:NSLocalizedString(@"DVD-Audio",@"Localized")];
	[accessOptions setEnabled:NO];
	}
	
	//get the tableview and set the total time
	[self setDisplay:self];
	
	//Enable or disable burn button
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWChangeBurnStatus" object:[NSNumber numberWithBool:([tableView numberOfRows] > 0)]];
	
	//Save the popup if needed
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWRememberPopups"] == YES)
	{
	[[NSUserDefaults standardUserDefaults] setObject:[tableViewPopup objectValue] forKey:@"KWDefaultAudioType"];
	}
	
	if (tableView == [mainWindow firstResponder])
	{
	[self tableViewSelectionDidChange:nil];
	}
	else
	{
		if ([[tableViewPopup title] isEqualTo:NSLocalizedString(@"Audio CD",@"Localized")] && ![KWCommonMethods isPanther])
		[[NSNotificationCenter defaultCenter] postNotificationName:@"KWChangeInspector" object:tableView userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"KWAudioDisc",@"Type",nil]];
		else if ([[tableViewPopup title] isEqualTo:NSLocalizedString(@"MP3 Disc",@"Localized")])
		[[NSNotificationCenter defaultCenter] postNotificationName:@"KWChangeInspector" object:tableView userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"KWAudioMP3Disc",@"Type",nil]];
		else if ([[tableViewPopup title] isEqualTo:NSLocalizedString(@"DVD-Audio",@"Localized")])
		[[NSNotificationCenter defaultCenter] postNotificationName:@"KWChangeInspector" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"KWEmpty",@"Type",nil]];
	}
}

- (BOOL)tableView:(NSTableView *)tableView shouldEditTableColumn:(NSTableColumn *)tableColumn row:(int)row
{    
return NO; 
}

- (NSDragOperation)tableView:(NSTableView*)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)op
{
int result = NSDragOperationNone;

    if (op == NSTableViewDropAbove && [[tableViewPopup title] isEqualTo:NSLocalizedString(@"Audio CD",@"Localized")])
	{
	result = NSDragOperationMove;
	}
	else
	{
	[tv setDropRow:[tv numberOfRows] dropOperation:NSTableViewDropAbove];
    result = NSTableViewDropAbove;
	}

return (result);
}

- (BOOL)tableView:(NSTableView*)tv acceptDrop:(id <NSDraggingInfo>)info row:(int)row dropOperation:(NSTableViewDropOperation)op
{
NSPasteboard *pboard = [info draggingPasteboard];

	if ([[pboard types] containsObject:@"NSGeneralPboardType"] && [[tableViewPopup title] isEqualTo:NSLocalizedString(@"Audio CD",@"Localized")])
	{
	NSData *data = [pboard dataForType:@"NSGeneralPboardType"];
	id object = [NSUnarchiver unarchiveObjectWithData:data];
	[tableData insertObject:object atIndex:row];
		
		int removeRow = [[pboard stringForType:@"KWRemoveRowPboardType"] intValue];
		if (removeRow > row)
		[tableData removeObjectAtIndex:removeRow+1];
		else
		[tableData removeObjectAtIndex:removeRow];
	
	[tableView reloadData];
	}
	else if ([[pboard types] containsObject:@"CorePasteboardFlavorType 0x6974756E"])
	{
	NSArray *keys = [[[pboard propertyListForType:@"CorePasteboardFlavorType 0x6974756E"] objectForKey:@"Tracks"] allKeys];
	NSMutableArray *fileList = [NSMutableArray array];
	
		int i;
		for (i=0;i<[keys count];i++)
		{
		NSURL *url = [[NSURL alloc] initWithString:[[[[pboard propertyListForType:@"CorePasteboardFlavorType 0x6974756E"] objectForKey:@"Tracks"] objectForKey:[keys objectAtIndex:i]] objectForKey:@"Location"]];
		[fileList addObject:[url path]];
		[url release];
		}
		
	[self checkFiles:[fileList copy]];
	}
	else
	{
		if ([[tableViewPopup title] isEqualTo:NSLocalizedString(@"Audio CD",@"Localized")] | [[tableViewPopup title] isEqualTo:NSLocalizedString(@"DVD-Audio",@"Localized")])
		currentDropRow = row;

	[self checkFiles:[pboard propertyListForType:NSFilenamesPboardType]];
	}

return YES;
}

- (int) numberOfRowsInTableView:(NSTableView *)tableView
{
    return [tableData count];
}

- (id) tableView:(NSTableView *)tableView
    objectValueForTableColumn:(NSTableColumn *)tableColumn
    row:(int)row
{
	if ([tableData count] > 0)
	{
	NSDictionary *rowData = [tableData objectAtIndex:row];
    return [rowData objectForKey:[tableColumn identifier]];
	}
	else
	{
	return nil;
	}
}

- (void)tableView:(NSTableView *)tableView
    setObjectValue:(id)anObject
    forTableColumn:(NSTableColumn *)tableColumn
    row:(int)row
{
    NSMutableDictionary *rowData = [tableData objectAtIndex:row];
    [rowData setObject:anObject forKey:[tableColumn identifier]];
}

- (NSString *)getRealPath:(NSString *)inPath
{
	CFStringRef resolvedPath = nil;
	CFURLRef url = CFURLCreateWithFileSystemPath(NULL, (CFStringRef)inPath, kCFURLPOSIXPathStyle, NO);
	
	if (url != NULL) 
	{
	FSRef fsRef;
		
		if (CFURLGetFSRef(url, &fsRef)) 
		{
		Boolean targetIsFolder, wasAliased;
			
			if (FSResolveAliasFile (&fsRef, true, &targetIsFolder, &wasAliased) == noErr && wasAliased) 
			{
			CFURLRef resolvedurl = CFURLCreateFromFSRef(NULL, &fsRef);
				
				if (resolvedurl != NULL) 
				{
				resolvedPath = CFURLCopyFileSystemPath(resolvedurl, kCFURLPOSIXPathStyle);
				CFRelease(resolvedurl);
				}
			}
		}
	
	CFRelease(url);
	}
	
	if ((NSString *)resolvedPath)
	return (NSString *)resolvedPath;
	else
	return inPath;
}

- (BOOL)tableView:(NSTableView *)view writeRows:(NSArray *)rows toPasteboard:(NSPasteboard *)pboard
{
	if ([[tableViewPopup title] isEqualTo:NSLocalizedString(@"Audio CD",@"Localized")] | [[tableViewPopup title] isEqualTo:NSLocalizedString(@"DVD-Audio",@"Localized")])
	{
	id object = [tableData objectAtIndex:[[rows lastObject] intValue]];
	NSData *data = [NSArchiver archivedDataWithRootObject:object];

	[pboard declareTypes: [NSArray arrayWithObjects:@"NSGeneralPboardType",@"KWRemoveRowPboardType",nil] owner:nil];
	[pboard setData:data forType:@"NSGeneralPboardType"];
	[pboard setString:[[NSNumber numberWithInt:[[rows lastObject] intValue]] stringValue] forType:@"KWRemoveRowPboardType"];
   
	return YES;
	}
	else
	{
	return NO;
	}
}

////////////////////
// Player actions //
////////////////////

#pragma mark -
#pragma mark •• Player actions

- (IBAction)play:(id)sender
{
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
				//Check if a row is selected if not play first song
				if ([tableView selectedRow] > -1)
				{
				movie = [[QTMovie alloc] initWithFile:[[tableData objectAtIndex:[tableView selectedRow]] objectForKey:@"Path"] error:nil];
				[movie play];
				playingSong = [tableView selectedRow];
					if (display == 0)
					{
					[self setDisplay:self];
					}
				displayTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateDisplay:) userInfo:nil repeats: YES];
				[playButton setImage:[NSImage imageNamed:@"Pause"]];
				}
				else
				{
				movie = [[QTMovie alloc] initWithFile:[[tableData objectAtIndex:0] objectForKey:@"Path"] error:nil];
				[movie play];
				playingSong = 0;
					if (display == 0)
					{
					[self setDisplay:self];
					}
				displayTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateDisplay:) userInfo:nil repeats: YES];
				[playButton setImage:[NSImage imageNamed:@"Pause"]];
				}
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
}

- (IBAction)stop:(id)sender
{
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
		[self setDisplay:self];
		pause = NO;
		[playButton setImage:[NSImage imageNamed:@"Play"]];
		playingSong = 0;
		[movie release];
		movie = nil;
		}
	}
}

- (IBAction)back:(id)sender
{
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
}

- (IBAction)forward:(id)sender
{
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
}

//When the movie has stopped there will be a notification, we go to the next song if there is any
- (void)movieEnded:(NSNotification *)notification
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
	
	movie = [[QTMovie alloc] initWithFile:[[tableData objectAtIndex:playingSong+1] objectForKey:@"Path"] error:nil];
	[movie play];
	playingSong = playingSong + 1;
	}
	else
	{
		//Stop previous movie
		if (!movie == nil)
		{
		[movie stop];
		[movie release];
		movie = nil;
		}
	
	[self stop:self];
	}
}

//When the user clicks on the time display change the mode
- (IBAction)setDisplay:(id)sender
{
	if ([KWCommonMethods isQuickTimeSevenInstalled])
	{
		if (!movie==nil)
		{
			if (display == 0)
			{
			display = 1;
				if ([[tableViewPopup title] isEqualTo:NSLocalizedString(@"MP3 Disc",@"Localized")] | [[tableViewPopup title] isEqualTo:NSLocalizedString(@"DVD-Audio",@"Localized")])
				[totalTimeText setStringValue:[[[[NSFileManager defaultManager] displayNameAtPath:[[tableData objectAtIndex:playingSong] objectForKey:@"Path"]] stringByAppendingString:@" "] stringByAppendingString:[KWCommonMethods formatTime:(int)[movie currentTime].timeValue/(int)[movie currentTime].timeScale]]];
				else
				[totalTimeText setStringValue:[[[NSLocalizedString(@"Track ",@"Localized") stringByAppendingString:[[NSNumber numberWithInt:playingSong+1] stringValue]] stringByAppendingString:@" "] stringByAppendingString:[KWCommonMethods formatTime:(int)[movie currentTime].timeValue/(int)[movie currentTime].timeScale]]];
			}
			else if (display == 1)
			{
			display = 2;
				if ([[tableViewPopup title] isEqualTo:NSLocalizedString(@"MP3 Disc",@"Localized")] | [[tableViewPopup title] isEqualTo:NSLocalizedString(@"DVD-Audio",@"Localized")])
				[totalTimeText setStringValue:[[[[NSFileManager defaultManager] displayNameAtPath:[[tableData objectAtIndex:playingSong] objectForKey:@"Path"]] stringByAppendingString:@" "] stringByAppendingString:[KWCommonMethods formatTime:(int)[movie duration].timeValue/(int)[movie duration].timeScale - (int)[movie currentTime].timeValue/(int)[movie currentTime].timeScale]]];
				else
				[totalTimeText setStringValue:[[[NSLocalizedString(@"Track ",@"Localized") stringByAppendingString:[[NSNumber numberWithInt:playingSong+1] stringValue]] stringByAppendingString:@" "] stringByAppendingString:[KWCommonMethods formatTime:(int)[movie duration].timeValue/(int)[movie duration].timeScale - (int)[movie currentTime].timeValue/(int)[movie currentTime].timeScale]]];
			}
			else if (display == 2)
			{
			display = 0;
			[self setTotal];
			}
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
}

//Keep the seconds running on the display
- (void)updateDisplay:(NSTimer *)theTimer
{
	if (movie > nil)
	{
		if (display == 1)
		{
			if ([[tableViewPopup title] isEqualTo:NSLocalizedString(@"MP3 Disc",@"Localized")] | [[tableViewPopup title] isEqualTo:NSLocalizedString(@"DVD-Audio",@"Localized")])
			[totalTimeText setStringValue:[[[[NSFileManager defaultManager] displayNameAtPath:[[tableData objectAtIndex:playingSong] objectForKey:@"Path"]] stringByAppendingString:@" "] stringByAppendingString:[KWCommonMethods formatTime:(int)[movie currentTime].timeValue/(int)[movie currentTime].timeScale]]];
			else
			[totalTimeText setStringValue:[[[NSLocalizedString(@"Track ",@"Localized") stringByAppendingString:[[NSNumber numberWithInt:playingSong+1] stringValue]] stringByAppendingString:@" "] stringByAppendingString:[KWCommonMethods formatTime:(int)[movie currentTime].timeValue/(int)[movie currentTime].timeScale]]];
		}
		else if (display == 2)
		{
			if ([[tableViewPopup title] isEqualTo:NSLocalizedString(@"MP3 Disc",@"Localized")] | [[tableViewPopup title] isEqualTo:NSLocalizedString(@"DVD-Audio",@"Localized")])
			[totalTimeText setStringValue:[[[[NSFileManager defaultManager] displayNameAtPath:[[tableData objectAtIndex:playingSong] objectForKey:@"Path"]] stringByAppendingString:@" "] stringByAppendingString:[KWCommonMethods formatTime:(int)[movie duration].timeValue/(int)[movie duration].timeScale - (int)[movie currentTime].timeValue/(int)[movie currentTime].timeScale]]];
			else
			[totalTimeText setStringValue:[[[NSLocalizedString(@"Track ",@"Localized") stringByAppendingString:[[NSNumber numberWithInt:playingSong+1] stringValue]] stringByAppendingString:@" "] stringByAppendingString:[KWCommonMethods formatTime:(int)[movie duration].timeValue/(int)[movie duration].timeScale - (int)[movie currentTime].timeValue/(int)[movie currentTime].timeScale]]];
		}
		else if (display == 0)
		{
		[self setTotal];
		}
	}
}

///////////////////
// Other actions //
///////////////////

#pragma mark -
#pragma mark •• Other actions

- (NSString *)discName
{
return [discName stringValue];
}

- (void)volumeLabelSelected:(NSNotification *)notif
{
	if ([[tableViewPopup title] isEqualTo:NSLocalizedString(@"Audio CD",@"Localized")] && ![KWCommonMethods isPanther])
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWChangeInspector" object:tableView userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"KWAudioDisc",@"Type",nil]];
	else
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWChangeInspector" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"KWEmpty",@"Type",nil]];
}

- (NSArray *)getQuickTimeTypes
{	
NSMutableArray *fileTypes = [NSMutableArray array];
ComponentDescription findCD = {0, 0, 0, 0, 0};
ComponentDescription infoCD = {0, 0, 0, 0, 0};
Component comp = NULL;
OSErr err = noErr;

findCD.componentType = MovieImportType;
findCD.componentFlags = 0;

	while (comp = FindNextComponent(comp, &findCD)) 
	{
	
		err = GetComponentInfo(comp, &infoCD, nil, nil, nil);
		if (err == noErr) 
		{
			if (infoCD.componentFlags & movieImportSubTypeIsFileExtension)
			[fileTypes addObject:[[[NSString stringWithCString:(char *)&infoCD.componentSubType length:sizeof(OSType)] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] lowercaseString]];
			else 
			[fileTypes addObject:[NSString stringWithFormat:@"\'%@\'", [NSString stringWithCString:(char *)&infoCD.componentSubType length:sizeof(OSType)]]];
		}
	}
	
return [fileTypes copy]; 
}

- (BOOL)isMp3
{
	if ([[tableViewPopup title] isEqualTo:NSLocalizedString(@"MP3 Disc",@"Localized")] | [[tableViewPopup title] isEqualTo:NSLocalizedString(@"DVD-Audio",@"Localized")])
	return YES;
	else
	return NO;
}

- (BOOL)isDVDAudio
{
	if ([[tableViewPopup title] isEqualTo:NSLocalizedString(@"DVD-Audio",@"Localized")])
	return YES;
	else
	return NO;
}

- (void)setTotal
{
	if ([[tableViewPopup title] isEqualTo:NSLocalizedString(@"Audio CD",@"Localized")])
	{
	[totalTimeText setStringValue:[NSLocalizedString(@"Total time: ",@"Localized") stringByAppendingString:[self totalTime]]];
	}
	else
	{
	[totalTimeText setStringValue:[NSLocalizedString(@"Total size: ",@"Localized") stringByAppendingString:[KWCommonMethods makeSizeFromFloat:[self totalSize] * 2048]]];
	}
}

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

- (float)totalSize
{
	if ([tableData count] > 0 && [[[[tableData objectAtIndex:0] objectForKey:@"Name"] lowercaseString] isEqualTo:@"audio_ts"] && [[tableViewPopup title] isEqualTo:NSLocalizedString(@"DVD-Audio",@"Localized")])
	{
	return [KWCommonMethods calculateRealFolderSize:[[tableData objectAtIndex:0] objectForKey:@"Path"]];
	}
	else
	{
	DRFolder *discRoot = [DRFolder virtualFolderWithName:[discName stringValue]];
	
	int i;
	DRFSObject *fsObj;
	for (i=0;i<[tableData count];i++)
	{
	fsObj = [DRFile fileWithPath:[[tableData objectAtIndex:i] valueForKey: @"Path"]];
	[discRoot addChild:fsObj];
	}
				
	if ([KWCommonMethods isPanther] | ![[tableViewPopup title] isEqualTo:NSLocalizedString(@"DVD-Audio",@"Localized")])
	{
	//Just a filesystem since UDF isn't supported in Panther (not it will ever come here :-)
	[discRoot setExplicitFilesystemMask: (DRFilesystemInclusionMaskJoliet)];
	}
	else
	{
	[discRoot setExplicitFilesystemMask: (DRFilesystemInclusionMaskUDF)];
	}

	return [[DRTrack trackForRootFolder:discRoot] estimateLength];
	}
}

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

- (id)myCDTextDict
{
return CDTextDict;
}

- (DRFolder *)checkArray:(NSArray *)array forFolderWithName:(NSString *)name
{
	int i;
	for (i=0;i<[array count];i++)
	{
		if ([[(DRFolder *)[array objectAtIndex:i] baseName] isEqualTo:name])
		return (DRFolder *)[array objectAtIndex:i];
	}
	
return nil;
}

- (void)createVirtualFolderAtPath:(NSString *)path
{					
	if ([[NSFileManager defaultManager] fileExistsAtPath:path])
	[[NSFileManager defaultManager] removeFileAtPath:path handler:nil];
	
[[NSFileManager defaultManager] createDirectoryAtPath:path attributes:nil];

NSString *lastPath;

	int i;
	for (i=0;i<[tableData count];i++)
	{
	TagAPI *Tag = [[TagAPI alloc] initWithGenreList:nil];
	[Tag examineFile:[[tableData objectAtIndex:i] valueForKey:@"Path"]];
	
	lastPath = path;
				
		if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"KWCreateArtistFolders"] boolValue])
		{
			if (![[NSFileManager defaultManager] fileExistsAtPath:[lastPath stringByAppendingPathComponent:[Tag getArtist]]])
			[[NSFileManager defaultManager] createDirectoryAtPath:[lastPath stringByAppendingPathComponent:[Tag getArtist]] attributes:nil];
		
		lastPath = [lastPath stringByAppendingPathComponent:[Tag getArtist]];
		}
				
		if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"KWCreateAlbumFolders"] boolValue])
		{
			if (![[NSFileManager defaultManager] fileExistsAtPath:[lastPath stringByAppendingPathComponent:[Tag getAlbum]]])
			[[NSFileManager defaultManager] createDirectoryAtPath:[lastPath stringByAppendingPathComponent:[Tag getAlbum]] attributes:nil];
		
		lastPath = [lastPath stringByAppendingPathComponent:[Tag getAlbum]];
		}

	[Tag release];
	
		if ([[NSFileManager defaultManager] linkPath:[[tableData objectAtIndex:i] valueForKey:@"Path"] toPath:[lastPath stringByAppendingPathComponent:[[[tableData objectAtIndex:i] valueForKey:@"Path"] lastPathComponent]] handler:nil] == NO)
		[[NSFileManager defaultManager] copyPath:[[tableData objectAtIndex:i] valueForKey:@"Path"] toPath:[lastPath stringByAppendingPathComponent:[[[tableData objectAtIndex:i] valueForKey:@"Path"] lastPathComponent]] handler:nil];
	}
}

- (NSArray *)getSavePantherAudioCDArray
{
NSMutableArray *saveTracks = [NSMutableArray arrayWithCapacity:[tableData count]];
NSString *outputFolder = [KWCommonMethods uniquePathNameFromPath:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWTemporaryLocation"] stringByAppendingPathComponent:[discName stringValue]] withLength:0];

[[NSFileManager defaultManager] createDirectoryAtPath:outputFolder attributes:nil];

	int i;
	for (i=0;i<[tableData count];i++)
	{
	NSString *saveTrack = [[outputFolder stringByAppendingPathComponent:[@"Track " stringByAppendingString:[[NSNumber numberWithInt:i+1] stringValue]]] stringByAppendingPathExtension:[[[tableData objectAtIndex:i] valueForKey: @"Path"] pathExtension]];
	
		if ([[NSFileManager defaultManager] linkPath:[[tableData objectAtIndex:i] valueForKey: @"Path"] toPath:saveTrack handler:nil] == NO)
		[[NSFileManager defaultManager] copyPath:[[tableData objectAtIndex:i] valueForKey: @"Path"] toPath:saveTrack handler:nil];
	
	DRTrack* track = [DRTrack trackForAudioFile:saveTrack];
	
	NSMutableDictionary* properties;
		
	properties = [[track properties] mutableCopy];
	[properties setObject:[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultPregap"] intValue]*75] forKey:DRPreGapLengthKey];
	[track setProperties:properties];
	[saveTracks addObject:[track retain]];
	}
	
return saveTracks;
}

- (BOOL)isCompatible
{
	if ([[tableViewPopup titleOfSelectedItem] isEqualToString:@"DVD-Audio"] && [KWCommonMethods isPanther])
	return NO;
	
return YES;
}

- (BOOL)isCombinable:(BOOL)needAudioCDCheck
{
	if (![self hasRows])
	return NO;
	else if ([KWCommonMethods isPanther] && [[tableViewPopup title] isEqualTo:NSLocalizedString(@"DVD-Audio",@"Localized")])
	return NO;
	else if (needAudioCDCheck && [[tableViewPopup title] isEqualTo:NSLocalizedString(@"Audio CD",@"Localized")])
	return NO;
	
return YES;
}

- (BOOL)isAudioCD
{
	if (![self hasRows])
	return NO;
	else if ([[tableViewPopup titleOfSelectedItem] isEqualToString:NSLocalizedString(@"Audio CD",@"Localized")])
	return YES;

return NO;
}

- (void)deleteTemporayFiles:(BOOL)needed
{
	if (needed)
	{
		int i;
		for (i=0;i<[temporaryFiles count];i++)
		{
		[[NSFileManager defaultManager] removeFileAtPath:[temporaryFiles objectAtIndex:i] handler:nil];
		}
	}
	
[temporaryFiles removeAllObjects];
}

/////////////////////
// CD-Text actions //
/////////////////////

#pragma mark -
#pragma mark •• CD-Text actions

- (NSDictionary *)getBurnProperties
{
//NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];
DRCDTextBlock *cdtext = nil;
NSData *mcn = nil;
NSMutableDictionary	*burnProperties = [[NSMutableDictionary alloc] init];
	
	// Are we adding an MCN to the disc?
	if ([[CDTextDict objectForKey:@"EnableMCN"] boolValue])
	{
	// Get the MCN.
	mcn = [self mcnDataForDisc];
		
		// Add it to the burn properties.
		if (mcn != nil)
		[burnProperties setObject:mcn forKey:DRMediaCatalogNumberKey];
	}
	
// Allocate an empty CD-Text block.
cdtext = [DRCDTextBlock cdTextBlockWithLanguage:@"" encoding:DRCDTextEncodingISOLatin1Modified];
		
	// Go through the document and copy all of the CD-Text
	//	information into the block.
	//NSArray *cdTextTracks = [self createCDTextArray];
	[cdtext setTrackDictionaries:[self createCDTextArray]];
	
	unsigned	i, count = [tableData count];
	for (i=0; i<count; ++i)
	{
		NSDictionary *dict = [tableData objectAtIndex:i];
			
		// If the track has an ISRC specified and it's being added to
		//	the CD-Text, do so.
		if (i>0 && [[dict objectForKey:@"ISRCCDText"] boolValue])
		{
			NSData *isrc = [self isrcDataForTrack:i-1];
			if (isrc != nil)
			{
				// Hyphenate the ISRC data to make it look nicer when it's
				//	in CD-Text.
				char	cstr[16];
				char	*ip = (char*)[isrc bytes];
				snprintf(cstr,sizeof(cstr),"%.2s-%.3s-%.2s-%.5s",&ip[0],&ip[2],&ip[5],&ip[7]);
				cstr[15] = 0;
				
				[cdtext setObject:[NSString stringWithUTF8String:cstr] forKey:DRCDTextMCNISRCKey ofTrack:i];
			}
		}
	}
		
	// If we had an MCN above, put it into the CD-Text too.
	if (mcn)
		[cdtext setObject:mcn forKey:DRCDTextMCNISRCKey ofTrack:0];
	
	// Add the CD-Text block to the burn properties.
	[burnProperties setObject:cdtext forKey:DRCDTextKey];
	
	// Set the accumulated burn properties back onto the object.
//[burn setProperties:burnProperties];
//[pool release];
return burnProperties;
}



// -------------------------------------------------------------------------------
//	createLayoutForBurn
// -------------------------------------------------------------------------------
//	Creates an array of DRTracks from the settings in the document.
//
//	May raise an NSObjectNotAvailableException if a track was not found
//	or could not be imported.
//
- (id)createLayoutForBurn
{
	unsigned i, count = [tableData count];
	NSMutableArray	*tracks = [NSMutableArray arrayWithCapacity:count];
	
	for (i=0; i<count; ++i)
	{
	NSDictionary	*trackInfo = [tableData objectAtIndex:i];
	NSString		*path = [[tableData objectAtIndex:i] objectForKey:@"Path"];
	//[trackInfo objectForKey:EABTrackFilePath];
		
	// Create the track.
	DRTrack	*track = [DRTrack trackForAudioFile:path];
		
		if (track == nil)
		{
			NSLog(@"An error occurred at track %d: %@", (i+1), path);
			[NSException raise:NSObjectNotAvailableException
						format:@"Source file for track %u was not found, or could not be imported!  Filename was %@",
						(i+1), path];
		}
		
		// Set track properties from the document.
		unsigned	preGapLengthInFrames = (unsigned)([[trackInfo objectForKey:@"Pregap"] floatValue] * 75.0);
		
		NSMutableDictionary	*trackProperties = [[track properties] mutableCopy];
		[trackProperties setObject:[NSNumber numberWithUnsignedInt:preGapLengthInFrames] forKey:DRPreGapLengthKey];
		[trackProperties setObject:[trackInfo objectForKey:@"Pre-emphasis"] forKey:DRAudioPreEmphasisKey];
		if ([[trackInfo objectForKey:@"EnableISRC"] boolValue])
		{
		NSData *isrc = [self isrcDataForTrack:i];
			if (isrc)
			[trackProperties setObject:isrc forKey:DRTrackISRCKey];
		}
		if ([[trackInfo objectForKey:@"IndexPoints"] boolValue])
		{
			NSArray	*indexPoints = [NSMutableArray arrayWithCapacity:98];
			if (indexPoints)
				[trackProperties setObject:indexPoints forKey:DRIndexPointsKey];
		}
		[track setProperties:trackProperties];
		
		// Add this track to the list.
		[tracks addObject:track];
	}
	
	return tracks;
}


// -------------------------------------------------------------------------------
//	mcnDataForDisc
// -------------------------------------------------------------------------------
//	Returns an NSData for the MCN of the specified disc.  Only valid MCNs
//	are returned.
//
- (NSData*)mcnDataForDisc
{
	NSString *mcn = [CDTextDict objectForKey:@"MCN"];
	if (mcn)
	{
		// Convert the MCN into the appropriate format:
		//	an NSData containing 13 bytes.
		NSData *data = [mcn dataUsingEncoding:NSASCIIStringEncoding];
		if ([data length] == 13)
			return data;
	}
	return nil;
}


// -------------------------------------------------------------------------------
//	isrcDataForTrack:
// -------------------------------------------------------------------------------
//	Returns an NSData for the ISRC of the specified track.  Only valid ISRCs
//	are returned.
//
- (NSData*)isrcDataForTrack:(unsigned)index
{
	NSDictionary *trackInfo = [tableData objectAtIndex:index];
	NSString *isrc = [trackInfo objectForKey:@"ISRC"];
	if (isrc)
	{
		// Convert the ISRC into the appropriate format:
		//	an NSData containing 12 bytes.
		NSData *data = [isrc dataUsingEncoding:NSASCIIStringEncoding];
		if ([data length] == 12)
			return data;
	}
	return nil;
}

- (NSArray *)createCDTextArray
{
NSMutableArray *mutableArray = [NSMutableArray array];

[mutableArray addObject:[self getDiscInfo]];

	int i;
	for (i=0;i<[tableData count];i++)
	{
	[mutableArray addObject:[self getTrackInfo:i]];
	}
	
return [mutableArray copy];
}

- (NSDictionary *)getTrackInfo:(int)index
{
NSMutableDictionary *mutableDictionary = [NSMutableDictionary dictionary];

	if ([[tableData objectAtIndex:index] objectForKey:@"Title"])
	[mutableDictionary setObject:[[tableData objectAtIndex:index] objectForKey:@"Title"] forKey:DRCDTextTitleKey];
	if ([[tableData objectAtIndex:index] objectForKey:@"Performer"])
	[mutableDictionary setObject:[[tableData objectAtIndex:index] objectForKey:@"Performer"] forKey:DRCDTextPerformerKey];
	if ([[tableData objectAtIndex:index] objectForKey:@"Composer"])
	[mutableDictionary setObject:[[tableData objectAtIndex:index] objectForKey:@"Composer"] forKey:DRCDTextComposerKey];
	if ([[tableData objectAtIndex:index] objectForKey:@"Songwriter"])
	[mutableDictionary setObject:[[tableData objectAtIndex:index] objectForKey:@"Songwriter"] forKey:DRCDTextSongwriterKey];
	if ([[tableData objectAtIndex:index] objectForKey:@"Arranger"])
	[mutableDictionary setObject:[[tableData objectAtIndex:index] objectForKey:@"Arranger"] forKey:DRCDTextArrangerKey];
	if ([[tableData objectAtIndex:index] objectForKey:@"Notes"])
	[mutableDictionary setObject:[[tableData objectAtIndex:index] objectForKey:@"Notes"] forKey:DRCDTextSpecialMessageKey];
	if ([[tableData objectAtIndex:index] objectForKey:@"PrivateUse"])
	[mutableDictionary setObject:[[tableData objectAtIndex:index] objectForKey:@"PrivateUse"] forKey:DRCDTextClosedKey];

return [mutableDictionary copy];
}

- (NSDictionary *)getDiscInfo
{
NSMutableDictionary *mutableDictionary = [NSMutableDictionary dictionary];

	if ([CDTextDict objectForKey:@"Title"])
	[mutableDictionary setObject:[CDTextDict objectForKey:@"Title"] forKey:DRCDTextTitleKey];
	if ([CDTextDict objectForKey:@"Performer"])
	[mutableDictionary setObject:[CDTextDict objectForKey:@"Performer"] forKey:DRCDTextPerformerKey];
	if ([CDTextDict objectForKey:@"Composer"])
	[mutableDictionary setObject:[CDTextDict objectForKey:@"Composer"] forKey:DRCDTextComposerKey];
	if ([CDTextDict objectForKey:@"Songwriter"])
	[mutableDictionary setObject:[CDTextDict objectForKey:@"Songwriter"] forKey:DRCDTextSongwriterKey];
	if ([CDTextDict objectForKey:@"Arranger"])
	[mutableDictionary setObject:[CDTextDict objectForKey:@"Arranger"] forKey:DRCDTextArrangerKey];
	if ([CDTextDict objectForKey:@"Notes"])
	[mutableDictionary setObject:[CDTextDict objectForKey:@"Notes"] forKey:DRCDTextSpecialMessageKey];
	if ([CDTextDict objectForKey:@"PrivateUse"])
	[mutableDictionary setObject:[CDTextDict objectForKey:@"PrivateUse"] forKey:DRCDTextClosedKey];
	if ([CDTextDict objectForKey:@"DiscIdent"])
	[mutableDictionary setObject:[CDTextDict objectForKey:@"DiscIdent"] forKey:DRCDTextDiscIdentKey];
	if ([CDTextDict objectForKey:@"GenreCode"])
	[mutableDictionary setObject:[CDTextDict objectForKey:@"GenreCode"] forKey:DRCDTextGenreCodeKey];
	if ([CDTextDict objectForKey:@"GenreName"])
	[mutableDictionary setObject:[CDTextDict objectForKey:@"GenreName"] forKey:DRCDTextGenreKey];
	
return [mutableDictionary copy];
}

@end