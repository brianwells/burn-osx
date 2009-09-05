#import "videoController.h"
#import <QTKit/QTKit.h>
#import <QuickTime/QuickTime.h>
#import "KWDocument.h"
#import "KWCommonMethods.h"
#import "discCreationController.h"
#import "KWTrackProducer.h"KWTrackProducer

@implementation videoController

- (id) init
{
self = [super init];
//Here are our tableviews data stored
VCDTableData = [[NSMutableArray alloc] init];
SVCDTableData = [[NSMutableArray alloc] init];
DVDTableData = [[NSMutableArray alloc] init];
DIVXTableData = [[NSMutableArray alloc] init];

temporaryFiles = [[NSMutableArray alloc] init];
	
//Storage room for files
noRightVideoFiles = [[NSMutableArray alloc] init];

//Array with protected files
someProtected =  [[NSMutableArray alloc] init];
	
//Create a mutable array to create our list of allowed files all QuickTime files and ffmpeg files
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
	
	//Add protected files HFS Type, needed to warn
	[addFileTypes addObject:NSFileTypeForHFSTypeCode('M4P ')];
	[addFileTypes addObject:NSFileTypeForHFSTypeCode('M4B ')];
		
[addFileTypes addObject:@"iMovieProject"];
	
//Retain the files in our array for later usage
allowedFileTypes = [addFileTypes retain];
	
//EnterMovies if QuickTime 6 is installed
if (![KWCommonMethods isQuickTimeSevenInstalled])
EnterMovies();
	
//Set a starting row for dropping files in the list
currentDropRow = -1;
	
return self;
}

- (void)dealloc
{
//Stop listening to notifications from the default notification center
[[NSNotificationCenter defaultCenter] removeObserver:self];

//Release our previously explained files
[VCDTableData release];
[SVCDTableData release];
[DVDTableData release];
[DIVXTableData release];

[temporaryFiles release];

[noRightVideoFiles release];

[someProtected release];

//We have no need for the extensions of protected files
[protectedFiles release];
protectedFiles = nil;

[allowedFileTypes release];
allowedFileTypes = nil;

[super dealloc];
}

- (void)awakeFromNib
{
//Notifications send by ffmpegController
//Used to save the popups when the user selects this option in the preferences
[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changePopup:) name:@"KWTogglePopups" object:nil];
//Prevent files to be dropped when for example a sheet is open
[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setTableViewState:) name:@"KWSetDropState" object:nil];
//Updates the Inspector window with the new item selected in the list
[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(tableViewSelectionDidChange:) name:@"KWListSelected" object:tableView];
//Updates the Inspector window to show the information about the disc
[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(volumeLabelSelected:) name:@"KWDiscNameSelected" object:discName];

//Make a list of protected filetypes
//Protected files can't be converted
protectedFiles = [[NSArray arrayWithObjects:@"m4p",@"m4b",NSFileTypeForHFSTypeCode('M4P '),NSFileTypeForHFSTypeCode('M4B '),nil] retain];

//How should our tableview update its sizes when adding and modifying files
[tableView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];

//The user can drag files into the tableview
[tableView registerForDraggedTypes:[NSArray arrayWithObjects:NSFilenamesPboardType,@"NSGeneralPboardType",@"CorePasteboardFlavorType 0x6974756E",nil]];

//Select the right popup item to either the saved on or the one defined in the preferences
[tableViewPopup selectItemAtIndex:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultVideoType"] intValue]];
[self changePopup:self];

	//Set options menu
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWDVDForce43"] == YES)
	[optionsForce43 setState:NSOnState];
	else
	[optionsForce43 setState:NSOffState];
		
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWLoopDVD"] == YES)
	[optionsLoopDVD setState:NSOnState];
	else
	[optionsLoopDVD setState:NSOffState];
		
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWForceMPEG2"] == YES)
	[optionsForceMPEG2 setState:NSOnState];
	else
	[optionsForceMPEG2 setState:NSOffState];
		
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWMuxSeperateStreams"] == YES)
	[optionsMuxSeperate setState:NSOnState];
	else
	[optionsMuxSeperate setState:NSOffState];
	
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWRemuxMPEG2Streams"] == YES)
	[optionsRemuxMPEG2 setState:NSOnState];
	else
	[optionsRemuxMPEG2 setState:NSOffState];
		
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWUseTheme"] == YES)
	[optionsUseTheme setState:NSOnState];
	else
	[optionsUseTheme setState:NSOffState];
	
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWForceDivX"] == YES)
	[optionsForceDIVX setState:NSOnState];
	else
	[optionsForceDIVX setState:NSOffState];

}

//////////////////
// File actions //
//////////////////

#pragma mark -
#pragma mark •• File actions

//Show a open sheet
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

//Delete the movie from the list
- (IBAction)deleteFiles:(id)sender
{
id myObject;
	
// get and sort enumerator in descending order
NSEnumerator *selectedItemsEnum = [[[[tableView selectedRowEnumerator] allObjects] sortedArrayUsingSelector:@selector(compare:)] reverseObjectEnumerator];
	
// remove object in descending order
myObject = [selectedItemsEnum nextObject];
	
	while (myObject) 
	{
	[tableData removeObjectAtIndex:[myObject intValue]];
	myObject = [selectedItemsEnum nextObject];
	}
	
//Deselect and reload the tableview
[tableView deselectAll:nil];
[tableView reloadData];
	
//Check if there are still rows
[[NSNotificationCenter defaultCenter] postNotificationName:@"KWChangeBurnStatus" object:[NSNumber numberWithBool:([tableView numberOfRows] > 0)]];
	
//Recalculate size
[self calculateTotalSize];
}

//
- (void)addFile:(NSString *)path isSelfEncoded:(BOOL)selfEncoded
{
NSNumber *isWide;

	//iMove projects can only be used if saved / contain a iDVD folder
	if ([KWCommonMethods isSavediMovieProject:path])
	{
	//Check if the file is allready the right file
	BOOL checkFile;
	converter = [[KWConverter alloc] init];

		if ([[tableViewPopup title] isEqualTo:@"VCD"])
		{
			if ([converter isVCD:path])
			checkFile = YES;
			else
			checkFile = NO;
		}
		else if([[tableViewPopup title] isEqualTo:@"SVCD"])
		{
			if ([converter isSVCD:path])
			checkFile = YES;
			else
			checkFile = NO;
		}
		else if ([[tableViewPopup title] isEqualTo:NSLocalizedString(@"DVD-Video",@"Localized")])
		{
		isWide = [converter isDVD:path];
		
			if (isWide && [[NSUserDefaults standardUserDefaults] boolForKey:@"KWForceMPEG2"] == NO | selfEncoded == YES)
			checkFile = YES;
			else
			checkFile = NO;
			
			if ([[path pathExtension] isEqualTo:@"m2v"] && [[NSUserDefaults standardUserDefaults] boolForKey:@"KWMuxSeperateStreams"] == YES)
			checkFile = YES;
		}
		else if ([[tableViewPopup title] isEqualTo:@"DivX"])
		{
			if ([converter isMPEG4:path] && [[NSUserDefaults standardUserDefaults] boolForKey:@"KWForceDivX"] == NO | selfEncoded == YES)
			checkFile = YES;
			else
			checkFile = NO;
			
			[converter release];
		}
		
		//Go on if the file is the right type
		if (checkFile == YES)
		{
		NSString *filePath = path;
		NSString *fileType = NSFileTypeForHFSTypeCode([[[[NSFileManager defaultManager] fileAttributesAtPath:path traverseLink:YES] objectForKey:NSFileHFSTypeCode] longValue]);
	
			//Remux MPEG2 files that are encoded by another app
			if (selfEncoded == NO && [[tableViewPopup title] isEqualTo:NSLocalizedString(@"DVD-Video",@"Localized")] && [[NSUserDefaults standardUserDefaults] boolForKey:@"KWRemuxMPEG2Streams"] == YES && ![[path pathExtension] isEqualTo:@"m2v"] && ![fileType isEqualTo:@"'MPG2'"])
			{
			NSString *outputFile = [KWCommonMethods temporaryLocation:[[[path lastPathComponent] stringByDeletingPathExtension] stringByAppendingPathExtension:@"mpg"] saveDescription:NSLocalizedString(@"Choose a location to save the re-muxed files",@"Localized")];
				
				if (outputFile)
				{
				[temporaryFiles addObject:outputFile];
				
				converter = [[KWConverter alloc] init];
					
				[progressPanel setStatus:[NSLocalizedString(@"Remuxing: ",@"Localized") stringByAppendingString:[[NSFileManager defaultManager] displayNameAtPath:outputFile]]];

					if ([converter remuxMPEG2File:path outPath:outputFile] == YES)
					filePath = outputFile;
					else
					filePath = @"";
					
				[converter release];
						
				[progressPanel setStatus:NSLocalizedString(@"Scanning for for file and folders",@"Localized")];
				[progressPanel setCancelNotification:@"videoCancelAdding"];
				}
			}
			
			//If we have seperate m2v and mp3/ac2 files mux them, if setted in the preferences
			if (([[path pathExtension] isEqualTo:@"m2v"] | [fileType isEqualTo:@"'MPG2'"]) && [[tableViewPopup title] isEqualTo:NSLocalizedString(@"DVD-Video",@"Localized")] && [[NSUserDefaults standardUserDefaults] boolForKey:@"KWMuxSeperateStreams"] == YES)
			{
			NSString *outputFile = [KWCommonMethods temporaryLocation:[[[path lastPathComponent] stringByDeletingPathExtension] stringByAppendingPathExtension:@"mpg"] saveDescription:NSLocalizedString(@"Choose a location to save the muxed file",@"Localized")];
				
				if (outputFile)
				{
				[temporaryFiles addObject:outputFile];
				
				converter = [[KWConverter alloc] init];
			
					if ([converter canCombineStreams:path])
					{
					[progressPanel setStatus:[NSLocalizedString(@"Creating: ",@"Localized") stringByAppendingString:[[[[NSFileManager defaultManager] displayNameAtPath:path] stringByDeletingPathExtension] stringByAppendingPathExtension:@"mpg"]]];

						if ([converter combineStreams:path atOutputPath:outputFile] == YES)
						filePath = [[path stringByDeletingPathExtension] stringByAppendingPathExtension:@"mpg"];
						else
						filePath = @"";
					
					[converter release];
				
					[progressPanel setStatus:NSLocalizedString(@"Scanning for for file and folders",@"Localized")];
					[progressPanel setCancelNotification:@"videoCancelAdding"];
					}
				}
			}
		
			//If none of the above rules are aplied add the file to the list
			if (![filePath isEqualTo:@""])
			{
			NSDictionary *attrib = [[NSFileManager defaultManager] fileAttributesAtPath:filePath traverseLink:YES];
	
			NSMutableDictionary *rowData = [NSMutableDictionary dictionary];
			[rowData setObject:[[NSFileManager defaultManager] displayNameAtPath:filePath] forKey:@"Name"];
			[rowData setObject:filePath forKey:@"Path"];
				
				if ([[tableViewPopup title] isEqualTo:NSLocalizedString(@"DVD-Video",@"Localized")])
				{
				[rowData setObject:isWide forKey:@"WideScreen"];
				[rowData setObject:[NSArray array] forKey:@"Chapters"];
				}
			
			[rowData setObject:[KWCommonMethods makeSizeFromFloat:[[attrib objectForKey:NSFileSize] floatValue]] forKey:@"Size"];
			[rowData setObject:[[[NSWorkspace sharedWorkspace] iconForFile:filePath] retain] forKey:@"Icon"];
			
				//If we're dealing with a Video_TS folder remve all rows
				if ([tableData count] > 0 && [[[[tableData objectAtIndex:0] objectForKey:@"Name"] lowercaseString] isEqualTo:@"video_ts"] && [[tableViewPopup title] isEqualTo:NSLocalizedString(@"DVD-Video",@"Localized")])
				{
				[tableData removeAllObjects];
				currentDropRow = -1;
				}
			
				//Insert the item at current row
				if (currentDropRow > -1)
				{
				[tableData insertObject:rowData atIndex:currentDropRow];
				currentDropRow = currentDropRow + 1;
				}
				else
				{
				[tableData addObject:rowData];
			
				NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"Name" ascending:YES];
				[tableData sortUsingDescriptors:[NSArray arrayWithObject:sortDescriptor]];
				[sortDescriptor release];
				}
			
			//Reload our table view
			[tableView reloadData];
			//Set the total size in the main thread
			[self performSelectorOnMainThread:@selector(calculateTotalSize) withObject: nil waitUntilDone:YES];
			}
		}
		else 
		{
		//Add the file to be encoded
		NSMutableDictionary *rowData = [NSMutableDictionary dictionary];
		[rowData setObject:[[NSFileManager defaultManager] displayNameAtPath:path] forKey:@"Name"];
		[rowData setObject:path forKey:@"Path"];
		[noRightVideoFiles addObject:rowData];
		}
	}
}

//Add a DVD folder to the list, by removing all files and adding it
- (void)addDVDFolder:(NSString *)path
{
NSMutableDictionary *rowData = [NSMutableDictionary dictionary];
[rowData setObject:[[NSFileManager defaultManager] displayNameAtPath:path] forKey:@"Name"];
[rowData setObject:path forKey:@"Path"];
[rowData setObject:[KWCommonMethods makeSizeFromFloat:[KWCommonMethods calculateRealFolderSize:path] * 2048] forKey:@"Size"];
[rowData setObject:[[[NSWorkspace sharedWorkspace] iconForFile:path] retain] forKey:@"Icon"];

[tableData removeAllObjects];
[tableData addObject:rowData];
[tableView reloadData];
}

//Start a progresssheet and start thread in which we check the files
- (void)checkFiles:(NSArray *)paths
{
[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setCancelAdding) name:@"videoCancelAdding" object:nil];

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

//When cancel is pushed we change the BOOL, this might take some time to cancel
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

//Our check thread
- (void)startThread:(NSArray *)paths
{
//Needed because we're in a new thread
NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	if ([paths count] == 1 && [[[[paths objectAtIndex:0] lastPathComponent] lowercaseString] isEqualTo:@"video_ts"] && [[tableViewPopup title] isEqualTo:NSLocalizedString(@"DVD-Video",@"Localized")])
	{
	//Add Video_TS folder if it's directly dropped
	[self addDVDFolder:[paths objectAtIndex:0]];
	}
	else if ([paths count] == 1 && [[NSFileManager defaultManager] fileExistsAtPath:[[paths objectAtIndex:0] stringByAppendingPathComponent:@"VIDEO_TS"]] && [[tableViewPopup title] isEqualTo:NSLocalizedString(@"DVD-Video",@"Localized")])
	{
	//Add Video_TS from inside dropped folder
	[self addDVDFolder:[[paths objectAtIndex:0] stringByAppendingPathComponent:@"VIDEO_TS"]];
	[discName setStringValue:[[paths objectAtIndex:0] lastPathComponent]];
	}
	else if ([paths count] == 1 && ([[[paths objectAtIndex:0] pathExtension] isEqualTo:@"cue"] | [[[paths objectAtIndex:0] pathExtension] isEqualTo:@"iso"]))
	{
	//Open cue files in disk image tab
	[(KWDocument *)[mainWindow delegate] openDocument:[paths objectAtIndex:0]];
	}
	else
	{
	NSDictionary *attDict;
	NSString *hfsType;
	//Check files (by extension) and folders and then let them be checked by our addFile method
		int i = 0;
		for (i=0;i<[paths count];i++)
		{
		NSAutoreleasePool *subPool = [[NSAutoreleasePool alloc] init];
		
			if (cancelAddingFiles == NO)
			{
			NSDirectoryEnumerator *enumer;
			NSString* pathName;
			NSString *realPath = [self getRealPath:[paths objectAtIndex:i]];
			BOOL fileIsFolder = NO;
			int x=0;

			[[NSFileManager defaultManager] fileExistsAtPath:realPath isDirectory:&fileIsFolder];

				if (fileIsFolder)
				{
					enumer = [[NSFileManager defaultManager] enumeratorAtPath:realPath];
					while (pathName = [enumer nextObject])
					{
					NSAutoreleasePool *subPool = [[NSAutoreleasePool alloc] init];
					
						if (cancelAddingFiles == NO)
						{
							if (![pathName isEqualTo:@".DS_Store"])
							{
								NSString *currentPath = [[realPath stringByAppendingString: @"/"] stringByAppendingString:pathName];
								attDict = [[NSFileManager defaultManager] fileAttributesAtPath:currentPath traverseLink:YES];
								hfsType = NSFileTypeForHFSTypeCode([[attDict objectForKey:NSFileHFSTypeCode] longValue]);
								BOOL fileAdded = NO;
								for (x=0;x<[allowedFileTypes count];x++)
								{
								NSAutoreleasePool *subPool = [[NSAutoreleasePool alloc] init];
								
									if (fileAdded == NO)
									{
										if ([[[pathName pathExtension] lowercaseString] isEqualTo:[allowedFileTypes objectAtIndex:x]])
										{
											if ([self isProtected:[[realPath stringByAppendingString: @"/"] stringByAppendingString:pathName]])
											[someProtected addObject:[[realPath stringByAppendingString: @"/"] stringByAppendingString:pathName]];
											else
											[self addFile:[[realPath stringByAppendingString: @"/"] stringByAppendingString: pathName] isSelfEncoded:NO];
										
										fileAdded = YES;
										}
										else if ([hfsType isEqualTo:[allowedFileTypes objectAtIndex:x]])
										{
											if ([self isProtected:[[realPath stringByAppendingString: @"/"] stringByAppendingString:pathName]])
											[someProtected addObject:[[realPath stringByAppendingString: @"/"] stringByAppendingString:pathName]];
											else
											[self addFile:[[realPath stringByAppendingString: @"/"] stringByAppendingString: pathName] isSelfEncoded:NO];
										
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
					attDict = [[NSFileManager defaultManager] fileAttributesAtPath:realPath traverseLink:YES];
					hfsType = NSFileTypeForHFSTypeCode([[attDict objectForKey:NSFileHFSTypeCode] longValue]);
					for (x=0;x<[allowedFileTypes count];x++)
					{
					NSAutoreleasePool *subPool = [[NSAutoreleasePool alloc] init];
					
						if (fileAdded == NO)
						{
							if ([[[realPath pathExtension] lowercaseString] isEqualTo:[allowedFileTypes objectAtIndex:x]])
							{
								if ([self isProtected:realPath])
								[someProtected addObject:realPath];
								else
								[self addFile:realPath isSelfEncoded:NO];
								
							fileAdded = YES;
							}
							else if ([hfsType isEqualTo:[allowedFileTypes objectAtIndex:x]])
							{
								if ([self isProtected:realPath])
								[someProtected addObject:realPath];
								else
								[self addFile:realPath isSelfEncoded:NO];
							
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

//Reset bool for canceling
cancelAddingFiles = NO;
//Reset drop row
currentDropRow = -1;
	
//End sheet and release it
[progressPanel endSheet];
[progressPanel release];

//Stop being the observer
[[NSNotificationCenter defaultCenter] removeObserver:self name:@"videoCancelAdding" object:nil];

//Do the showAlert method, which will only show a alert if there are files to be encoded
[self performSelectorOnMainThread:@selector(showAlert) withObject:nil waitUntilDone:NO];

//Release out thread pool	
[pool release];
}

/////////////////////
// Convert actions //
/////////////////////

#pragma mark -
#pragma mark •• Convert actions

- (void)showAlert
{
[self calculateTotalSize];

		if ([[tableViewPopup title] isEqualTo:@"DivX"] && [[NSUserDefaults standardUserDefaults] boolForKey:@"KWForceDivX"] == YES && [noRightVideoFiles count] > 0)
		{
			if ([someProtected count] > 1)
			{
			NSAlert *alert = [[[NSAlert alloc] init] autorelease];
			
			[alert addButtonWithTitle:NSLocalizedString(@"Continue",@"Localized")];
			[alert addButtonWithTitle:NSLocalizedString(@"Cancel",@"Localized")];
			
			[alert setMessageText:NSLocalizedString(@"Some protected mp4 files",@"Localized")];
			[alert setInformativeText:NSLocalizedString(@"These files can't be converted, would you like to continue?",@"Localized")];
			
			[alert setAlertStyle:NSWarningAlertStyle];
	
			[someProtected removeAllObjects];
			[alert beginSheetModalForWindow:mainWindow modalDelegate:self didEndSelector:@selector(protectedAlertDidEnd:returnCode:contextInfo:) contextInfo:nil];
			}
			else if ([someProtected count] > 0)
			{
			NSAlert *alert = [[[NSAlert alloc] init] autorelease];
			
			[alert addButtonWithTitle:NSLocalizedString(@"Continue",@"Localized")];
			[alert addButtonWithTitle:NSLocalizedString(@"Cancel",@"Localized")];
			
			[alert setMessageText:NSLocalizedString(@"One protected mp4 file",@"Localized")];
			[alert setInformativeText:NSLocalizedString(@"This file can't be converted, would you like to continue?",@"Localized")];
			
			[alert setAlertStyle:NSWarningAlertStyle];
	
			[someProtected removeAllObjects];
			[alert beginSheetModalForWindow:mainWindow modalDelegate:self didEndSelector:@selector(protectedAlertDidEnd:returnCode:contextInfo:) contextInfo:nil];
			}
			else
			{
			NSOpenPanel *sheet = [NSOpenPanel openPanel];
			[sheet setCanChooseFiles: NO];
			[sheet setCanChooseDirectories: YES];
			[sheet setAllowsMultipleSelection: NO];
			[sheet setCanCreateDirectories: YES];
			[sheet setPrompt:NSLocalizedString(@"Choose",@"Localized")];
			[sheet setMessage:NSLocalizedString(@"Choose a location to save the avi files",@"Localized")];
			[sheet beginSheetForDirectory:nil file:nil types:nil modalForWindow:mainWindow modalDelegate:self didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:) contextInfo:nil];
			}
		}
		else if ([[tableViewPopup title] isEqualTo:NSLocalizedString(@"DVD-Video",@"Localized")] && [[NSUserDefaults standardUserDefaults] boolForKey:@"KWForceMPEG2"] == YES && [noRightVideoFiles count] > 0)
		{
			if ([someProtected count] > 1)
			{
			NSAlert *alert = [[[NSAlert alloc] init] autorelease];
			
			[alert addButtonWithTitle:NSLocalizedString(@"Continue",@"Localized")];
			[alert addButtonWithTitle:NSLocalizedString(@"Cancel",@"Localized")];
			
			[alert setMessageText:NSLocalizedString(@"Some protected mp4 files",@"Localized")];
			[alert setInformativeText:NSLocalizedString(@"These files can't be converted, would you like to continue?",@"Localized")];
			
			[alert setAlertStyle:NSWarningAlertStyle];
	
			[someProtected removeAllObjects];
			[alert beginSheetModalForWindow:mainWindow modalDelegate:self didEndSelector:@selector(protectedAlertDidEnd:returnCode:contextInfo:) contextInfo:nil];
			}
			else if ([someProtected count] > 0)
			{
			NSAlert *alert = [[[NSAlert alloc] init] autorelease];
			
			[alert addButtonWithTitle:NSLocalizedString(@"Continue",@"Localized")];
			[alert addButtonWithTitle:NSLocalizedString(@"Cancel",@"Localized")];
			
			[alert setMessageText:NSLocalizedString(@"One protected mp4 file",@"Localized")];
			[alert setInformativeText:NSLocalizedString(@"This file can't be converted, would you like to continue?",@"Localized")];
			
			[alert setAlertStyle:NSWarningAlertStyle];
	
			[someProtected removeAllObjects];
			[alert beginSheetModalForWindow:mainWindow modalDelegate:self didEndSelector:@selector(protectedAlertDidEnd:returnCode:contextInfo:) contextInfo:nil];
			}
			else
			{
			NSOpenPanel *sheet = [NSOpenPanel openPanel];
			[sheet setCanChooseFiles: NO];
			[sheet setCanChooseDirectories: YES];
			[sheet setAllowsMultipleSelection: NO];
			[sheet setCanCreateDirectories: YES];
			[sheet setPrompt:NSLocalizedString(@"Choose",@"Localized")];
			[sheet setMessage:NSLocalizedString(@"Choose a location to save the mpg files",@"Localized")];
			[sheet setAccessoryView:saveView];
			[sheet beginSheetForDirectory:nil file:nil types:nil modalForWindow:mainWindow modalDelegate:self didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:) contextInfo:nil];
			}
		}
		else if ([noRightVideoFiles count] > 0)
		{
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle:NSLocalizedString(@"Yes",@"Localized")];
		[alert addButtonWithTitle:NSLocalizedString(@"No",@"Localized")];
		[[[alert buttons] objectAtIndex:1] setKeyEquivalent:@"\E"];
			if ([[tableViewPopup title] isEqualTo:@"VCD"])
			{
				if ([noRightVideoFiles count] > 1)
				{
				[alert setMessageText:NSLocalizedString(@"Some incompatible files",@"Localized")];
				[alert setInformativeText:NSLocalizedString(@"Would you like to convert those files to VCD mpg?",@"Localized")];
				}
				else
				{
				[alert setMessageText:NSLocalizedString(@"One incompatible file",@"Localized")];
				[alert setInformativeText:NSLocalizedString(@"Would you like to convert that file to VCD mpg?",@"Localized")];
				}
			}
			else if ([[tableViewPopup title] isEqualTo:@"SVCD"])
			{
				if ([noRightVideoFiles count] > 1)
				{
				[alert setMessageText:NSLocalizedString(@"Some incompatible files",@"Localized")];
				[alert setInformativeText:NSLocalizedString(@"Would you like to convert those files to SVCD mpg?",@"Localized")];
				}
				else
				{
				[alert setMessageText:NSLocalizedString(@"One incompatible file",@"Localized")];
				[alert setInformativeText:NSLocalizedString(@"Would you like to convert that file to SVCD mpg?",@"Localized")];
				}
			}
			else if ([[tableViewPopup title] isEqualTo:NSLocalizedString(@"DVD-Video",@"Localized")])
			{
				if ([noRightVideoFiles count] > 1)
				{
				[alert setMessageText:NSLocalizedString(@"Some incompatible files",@"Localized")];
				[alert setInformativeText:NSLocalizedString(@"Would you like to convert those files to DVD mpg?",@"Localized")];
				}
				else
				{
				[alert setMessageText:NSLocalizedString(@"One incompatible file",@"Localized")];
				[alert setInformativeText:NSLocalizedString(@"Would you like to convert that file to DVD mpg?",@"Localized")];
				}
			}
			else if ([[tableViewPopup title] isEqualTo:@"DivX"])
			{
				if ([noRightVideoFiles count] > 1)
				{
				[alert setMessageText:NSLocalizedString(@"Some incompatible files",@"Localized")];
				[alert setInformativeText:NSLocalizedString(@"Would you like to convert those files to DivX avi?",@"Localized")];
				}
				else
				{
				[alert setMessageText:NSLocalizedString(@"One incompatible file",@"Localized")];
				[alert setInformativeText:NSLocalizedString(@"Would you like to convert that file to DivX avi?",@"Localized")];
				}
			}
			
			if ([someProtected count] > 1)
			{
			[alert setInformativeText:[[alert informativeText] stringByAppendingString:NSLocalizedString(@"\n(Note: there are a few protected mp4 files which can't be converted)",@"Localized")]];
			}
			if ([someProtected count] > 0)
			{
			[alert setInformativeText:[[alert informativeText] stringByAppendingString:NSLocalizedString(@"\n(Note: there is a protected mp4 file which can't be converted)",@"Localized")]];
			}
		
		[someProtected removeAllObjects];
		
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
}

- (void)protectedAlertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
[[alert window] orderOut:self];
	
	if (returnCode == NSAlertFirstButtonReturn) 
	{
		if ([[tableViewPopup title] isEqualTo:@"DivX"])
		{
		NSOpenPanel *sheet = [NSOpenPanel openPanel];
		[sheet setCanChooseFiles: NO];
		[sheet setCanChooseDirectories: YES];
		[sheet setAllowsMultipleSelection: NO];
		[sheet setCanCreateDirectories: YES];
		[sheet setPrompt:NSLocalizedString(@"Choose",@"Localized")];
		[sheet setMessage:NSLocalizedString(@"Choose a location to save the avi files",@"Localized")];
		[sheet beginSheetForDirectory:nil file:nil types:nil modalForWindow:mainWindow modalDelegate:self didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:) contextInfo:nil];
		}
		else if ([[tableViewPopup title] isEqualTo:NSLocalizedString(@"DVD-Video",@"Localized")])
		{
		NSOpenPanel *sheet = [NSOpenPanel openPanel];
		[sheet setCanChooseFiles: NO];
		[sheet setCanChooseDirectories: YES];
		[sheet setAllowsMultipleSelection: NO];
		[sheet setCanCreateDirectories: YES];
		[sheet setPrompt:NSLocalizedString(@"Choose",@"Localized")];
		[sheet setMessage:NSLocalizedString(@"Choose a location to save the mpg files",@"Localized")];
		[sheet setAccessoryView:saveView];
		[sheet beginSheetForDirectory:nil file:nil types:nil modalForWindow:mainWindow modalDelegate:self didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:) contextInfo:nil];
		}
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
		[regionPopup selectItemAtIndex:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultRegion"] intValue]];
		[sheet setPrompt:NSLocalizedString(@"Choose",@"Localized")];
			if ([[tableViewPopup title] isEqualTo:@"DivX"])
			[sheet setMessage:NSLocalizedString(@"Choose a location to save the avi files",@"Localized")];
			else
			[sheet setMessage:NSLocalizedString(@"Choose a location to save the mpg files",@"Localized")];
			if (![[tableViewPopup title] isEqualTo:@"DivX"])
			[sheet setAccessoryView:saveView];
		
		[sheet beginSheetForDirectory:nil file:nil types:nil modalForWindow:mainWindow modalDelegate:self didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:) contextInfo:nil];
	}
	else
	{
	[noRightVideoFiles removeAllObjects];
	}
}

//Place has been chosen change our editfield with this path
- (void)savePanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
[sheet orderOut:self];

	if (returnCode == NSOKButton) 
	{
	[[NSUserDefaults standardUserDefaults] setObject:[regionPopup objectValue] forKey:@"KWDefaultRegion"];
	
	progressPanel = [[KWProgress alloc] init];
	[progressPanel setTask:NSLocalizedString(@"Preparing to encode",@"Localized")];
	[progressPanel setStatus:NSLocalizedString(@"Checking file...",@"Localized")];
		if ([[tableViewPopup title] isEqualTo:@"DivX"])
		[progressPanel setIcon:[[NSWorkspace sharedWorkspace] iconForFileType:@"avi"]];
		else
		[progressPanel setIcon:[[NSWorkspace sharedWorkspace] iconForFileType:@"mpg"]];
	[progressPanel setMaximumValue:[NSNumber numberWithInt:100*[noRightVideoFiles count]]];
	[progressPanel beginSheetForWindow:mainWindow];
		
	[NSThread detachNewThreadSelector:@selector(convertFiles:) toTarget:self withObject:[sheet filename]];
	}
	else
	{
	[noRightVideoFiles removeAllObjects];
	}
}

- (void)convertFiles:(NSString *)path
{
NSAutoreleasePool *pool= [[NSAutoreleasePool alloc] init];

NSMutableArray *onlyFiles = [[NSMutableArray alloc] init];

	int x;
	for (x=0;x<[noRightVideoFiles count];x++)
	{
	[onlyFiles addObject:[[[noRightVideoFiles objectAtIndex:x] objectForKey:@"Path"] copy]];
	}

[noRightVideoFiles removeAllObjects];

	converter = [[KWConverter alloc] init];
	int result = [converter batchConvert:onlyFiles destination:path useRegion:[regionPopup title] useKind:[tableViewPopup title]];
	NSArray *failedFiles = [[NSArray alloc] initWithArray:[converter failureArray] copyItems:YES];
	NSArray *succeededFiles = [[NSArray alloc] initWithArray:[converter succesArray] copyItems:YES];

[converter release];

	int y;
	for (y=0;y<[succeededFiles count];y++)
	{
	[self addFile:[succeededFiles objectAtIndex:y] isSelfEncoded:YES];
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
	[self performSelectorOnMainThread:@selector(showConvertFailAlert:) withObject:[NSArray arrayWithArray:failedFiles] waitUntilDone:NO];
	}

[onlyFiles release];	
[failedFiles release];

[pool release];
}

- (void)showConvertFailAlert:(NSArray *)descriptions
{
NSAlert *alert = [[[NSAlert alloc] init] autorelease];
[alert addButtonWithTitle:NSLocalizedString(@"OK",@"Localized")];
[alert addButtonWithTitle:NSLocalizedString(@"Console",@"Localized")];
		
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
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWOpenConsole" object:self];
	}
}

///////////////////////////
// Disc creation actions //
///////////////////////////

#pragma mark -
#pragma mark •• Disc creation actions

- (void)burn
{
[myDiscCreationController burnDiscWithName:[discName stringValue] withType:2];
}

- (void)saveImage
{
	if ([[tableViewPopup title] isEqualTo:@"VCD"])
	[myDiscCreationController saveImageWithName:[discName stringValue] withType:4 withFileSystem:@"-vcd"];
	if ([[tableViewPopup title] isEqualTo:@"SVCD"])
	[myDiscCreationController saveImageWithName:[discName stringValue] withType:4 withFileSystem:@"-svcd"];
	else
	[myDiscCreationController saveImageWithName:[discName stringValue] withType:2 withFileSystem:@""];
}

- (id)myTrack;
{
	if ([[tableViewPopup title] isEqualTo:NSLocalizedString(@"DVD-Video",@"Localized")])
	{
	NSString *outputFolder = [KWCommonMethods temporaryLocation:[discName stringValue] saveDescription:NSLocalizedString(@"Choose a location to save a temporary folder",@"Localized")];
	int succes;
	
		if (outputFolder)
		{
		[temporaryFiles addObject:outputFolder];
		
		succes = [self authorizeFolderAtPathIfNeededAtPath:outputFolder];
		}
		else
		{
		return [NSNumber numberWithInt:2];
		}
	
		if (succes == 0)
		{
		[[NSNotificationCenter defaultCenter] postNotificationName:@"KWMaximumValueChanged" object:[NSNumber numberWithFloat:0]];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"KWStatusChanged" object:NSLocalizedString(@"Preparing...", Localized)];
		return [[KWTrackProducer alloc] getTrackForFolder:outputFolder ofType:3 withDiscName:[discName stringValue]];
		}
		else
		{
		return [NSNumber numberWithInt:succes];
		}
	}
	else if ([[tableViewPopup title] isEqualTo:@"VCD"])
	{
	return [[KWTrackProducer alloc] getTrackForVCDMPEGFiles:[self files] withDiscName:[discName stringValue] ofType:4];
	}
	else if ([[tableViewPopup title] isEqualTo:@"SVCD"])
	{
	return [[KWTrackProducer alloc] getTrackForVCDMPEGFiles:[self files] withDiscName:[discName stringValue] ofType:5];
	}

	if ([[tableViewPopup title] isEqualTo:@"DivX"])
	{
	DRFolder *rootFolder = [DRFolder virtualFolderWithName:[discName stringValue]];
		
		int i;
		DRFSObject *fsObj;
		for (i=0;i<[tableData count];i++)
		{
		fsObj = [DRFile fileWithPath:[[tableData objectAtIndex:i] valueForKey:@"Path"]];
		[rootFolder addChild:fsObj];
		}
		
	NSString *volumeName = [discName stringValue];
		
	[rootFolder setExplicitFilesystemMask: (DRFilesystemInclusionMaskJoliet)];
	[rootFolder setSpecificName:volumeName forFilesystem:DRJoliet];
	[rootFolder setSpecificName:volumeName forFilesystem:DRISO9660LevelTwo];
	
		if ([volumeName length] > 16)
		{
		NSRange	jolietVolumeRange = NSMakeRange(0, 16);
		volumeName = [volumeName substringWithRange:jolietVolumeRange];
		[rootFolder setSpecificName:volumeName forFilesystem:DRJoliet];
		}
			
	return [rootFolder retain];
	}

return nil;
}

- (int)authorizeFolderAtPathIfNeededAtPath:(NSString *)path
{
int succes;
	int x, z = 0;
	NSArray *videoFiles = [NSArray arrayWithObjects:@"VIDEO_TS.IFO", @"VIDEO_TS.VOB", @"VIDEO_TS.BUP", @"VTS.IFO", @"VTS.BUP", nil];
	NSPredicate *videoTrackPredicate = [NSPredicate predicateWithFormat:@"SELF MATCHES 'VTS_\\\\d\\\\d_\\\\d\\\\.(?:IFO|VOB|BUP)'"];
	
	if ([tableData count] > 0 && [[[[tableData objectAtIndex:0] objectForKey:@"Name"] lowercaseString] isEqualTo:@"video_ts"])
	{
		[[NSFileManager defaultManager] createDirectoryAtPath:path attributes:nil];
		
		// create DVD folders
		[[NSFileManager defaultManager] createDirectoryAtPath:[path stringByAppendingPathComponent:@"AUDIO_TS"] attributes:nil];
		[[NSFileManager defaultManager] createDirectoryAtPath:[path stringByAppendingPathComponent:@"VIDEO_TS"] attributes:nil];
		
		// folderName should be VIDEO_TS
		NSString *folderPath = [[tableData objectAtIndex:0] objectForKey:@"Path"];
		NSString *folderName = [[tableData objectAtIndex:0] objectForKey:@"Name"];
		
		// copy or link contents that conform to standard
		succes = 0;
		NSArray *folderContents = [[NSFileManager defaultManager] directoryContentsAtPath:folderPath];
		for (x = 0; x < [folderContents count]; x++) {
			NSString *fileName = [[folderContents objectAtIndex:x] uppercaseString];
			NSString *filePath = [folderPath stringByAppendingPathComponent:[folderContents objectAtIndex:x]];
			BOOL isDir;
			if ([[NSFileManager defaultManager] fileExistsAtPath:filePath isDirectory:&isDir] && !isDir) {
				// normal file... check name
				if ([videoFiles containsObject:fileName] || [videoTrackPredicate evaluateWithObject:fileName]) {
					// proper name... link or copy
					NSString *dstPath = [[path stringByAppendingPathComponent:folderName] stringByAppendingPathComponent:fileName];
					BOOL result = [[NSFileManager defaultManager] linkPath:filePath toPath:dstPath handler:nil];
					if (result == NO)
						result = [[NSFileManager defaultManager] copyPath:filePath toPath:dstPath handler:nil];
					if (result == NO)
                        succes = 1;
					if (succes == 1)
						break; 
					z++;
				}
			}
		}
		if (z == 0)
			succes = 1;
	}
	else
	{
	int totalSize = [self totalSize];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWMaximumValueChanged" object:[NSNumber numberWithFloat:totalSize]];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWTaskChanged" object:NSLocalizedString(@"Authoring DVD...",@"Localized")];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWStatusChanged" object:NSLocalizedString(@"Processing: ",@"Localized")];
	
		DVDAuthorizer = [[KWDVDAuthorizer alloc] init];
		if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWUseTheme"] == YES)
		{
		NSBundle *themeBundle = [NSBundle bundleWithPath:[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDVDThemePath"]];
		NSDictionary *theme = [[NSArray arrayWithContentsOfFile:[themeBundle pathForResource:@"Theme" ofType:@"plist"]] objectAtIndex:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDVDThemeFormat"] intValue]];

		succes = [DVDAuthorizer createDVDMenuFiles:path withTheme:theme withFileArray:tableData withSize:[NSNumber numberWithInt:totalSize / 2] withName:[discName stringValue]];
		}
		else
		{
		succes = [DVDAuthorizer createStandardDVDFolderAtPath:path withFileArray:tableData withSize:[NSNumber numberWithInt:totalSize / 2]];
		}
	
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

[tableViewPopup selectItemAtIndex:[[burnFile objectForKey:@"KWSubType"] intValue]];

	NSDictionary *savedDictionary = [burnFile objectForKey:@"KWProperties"];
	NSArray *savedArray = [savedDictionary objectForKey:@"Files"];
	[discName setStringValue:[savedDictionary objectForKey:@"Name"]];
	[self changePopup:self];
	NSMutableDictionary *rowData = [NSMutableDictionary dictionary];

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
		[self calculateTotalSize];
	
[[NSNotificationCenter defaultCenter] postNotificationName:@"KWChangeBurnStatus" object:[NSNumber numberWithBool:([tableView numberOfRows] > 0)]];
}

- (void)videoBurnOpenPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode == NSOKButton) 
	{
	[self openBurnDocument:[sheet filename]];
	}
}

- (void)saveDocument
{
NSSavePanel *sheet = [NSSavePanel savePanel];
[sheet setRequiredFileType:@"burn"];
[sheet setCanSelectHiddenExtension:YES];
[sheet setMessage:NSLocalizedString(@"Choose a location to save the burn file",@"Localized")];
[sheet beginSheetForDirectory:nil file:[[discName stringValue] stringByAppendingString:@".burn"] modalForWindow:mainWindow modalDelegate:self didEndSelector:@selector(videoSavePanelDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

- (void)videoSavePanelDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
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
	
	[[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:2],[NSNumber numberWithInt:[tableViewPopup indexOfSelectedItem]],burnFileProperties,nil] forKeys:[NSArray arrayWithObjects:@"KWType",@"KWSubType",@"KWProperties",nil]] writeToFile:[sheet filename] atomically:YES];
	
	[tempArray release];
		
		if ([sheet isExtensionHidden])
		[[NSFileManager defaultManager] changeFileAttributes:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:@"NSFileExtensionHidden"] atPath:[sheet filename]];
	}
}

/////////////////////
// Options actions //
/////////////////////

#pragma mark -
#pragma mark •• Options actions

- (IBAction)accessOptions:(id)sender
{
	//Set our options values the button with gear and arrow
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWDVDForce43"] == YES)
	[optionsForce43 setState:NSOnState];
	else
	[optionsForce43 setState:NSOffState];
		
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWLoopDVD"] == YES)
	[optionsLoopDVD setState:NSOnState];
	else
	[optionsLoopDVD setState:NSOffState];
		
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWForceMPEG2"] == YES)
	[optionsForceMPEG2 setState:NSOnState];
	else
	[optionsForceMPEG2 setState:NSOffState];
		
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWMuxSeperateStreams"] == YES)
	[optionsMuxSeperate setState:NSOnState];
	else
	[optionsMuxSeperate setState:NSOffState];
	
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWRemuxMPEG2Streams"] == YES)
	[optionsRemuxMPEG2 setState:NSOnState];
	else
	[optionsRemuxMPEG2 setState:NSOffState];
		
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWUseTheme"] == YES)
	[optionsUseTheme setState:NSOnState];
	else
	[optionsUseTheme setState:NSOffState];
	
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWForceDivX"] == YES)
	[optionsForceDIVX setState:NSOnState];
	else
	[optionsForceDIVX setState:NSOffState];

	//Show the right popup DVD-Video or DivX options
	if ([[tableViewPopup title] isEqualTo:NSLocalizedString(@"DVD-Video",@"Localized")])
	[optionsPopupDVD performClick:self];
	else if ([[tableViewPopup title] isEqualTo:NSLocalizedString(@"DivX",@"Localized")])
	[optionsPopupDIVX performClick:self];
}

//Compatible DVD-Video disc clicked in the options menu, save it to the prefs
- (IBAction)optionsLoopDVD:(id)sender
{
	if ([optionsLoopDVD state] == NSOffState)
	{
	[optionsLoopDVD setState:NSOnState];
	[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"KWLoopDVD"];
	}
	else
	{
	[optionsLoopDVD setState:NSOffState];
	[[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"KWLoopDVD"];
	}
	
[[NSNotificationCenter defaultCenter] postNotificationName:@"KWOptionsChanged" object:nil];
}

//Force 4:3 clicked in the options menu, save it to the prefs
- (IBAction)optionsForce43:(id)sender
{
	if ([optionsForce43 state] == NSOffState)
	{
	[optionsForce43 setState:NSOnState];
	[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"KWDVDForce43"];
	}
	else
	{
	[optionsForce43 setState:NSOffState];
	[[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"KWDVDForce43"];
	}
	
[[NSNotificationCenter defaultCenter] postNotificationName:@"KWOptionsChanged" object:nil];
}

//Force MPEG2 Encoding clicked in the options menu, save it to the prefs
- (IBAction)optionsForceMPEG2:(id)sender
{
	if ([optionsForceMPEG2 state] == NSOffState)
	{
	[optionsForceMPEG2 setState:NSOnState];
	[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"KWForceMPEG2"];
	}
	else
	{
	[optionsForceMPEG2 setState:NSOffState];
	[[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"KWForceMPEG2"];
	}
	
[[NSNotificationCenter defaultCenter] postNotificationName:@"KWOptionsChanged" object:nil];
}

//Mux seperate files clicked in the options menu, save it to the prefs
- (IBAction)optionsMuxSeperate:(id)sender
{
	if ([optionsMuxSeperate state] == NSOffState)
	{
	[optionsMuxSeperate setState:NSOnState];
	[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"KWMuxSeperateStreams"];
	}
	else
	{
	[optionsMuxSeperate setState:NSOffState];
	[[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"KWMuxSeperateStreams"];
	}
	
[[NSNotificationCenter defaultCenter] postNotificationName:@"KWOptionsChanged" object:nil];
}

//Force remux MPEG2 clicked in the options menu, save it to the prefs
- (IBAction)optionsRemuxMPEG2:(id)sender
{
	if ([optionsRemuxMPEG2 state] == NSOffState)
	{
	[optionsRemuxMPEG2 setState:NSOnState];
	[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"KWRemuxMPEG2Streams"];
	}
	else
	{
	[optionsRemuxMPEG2 setState:NSOffState];
	[[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"KWRemuxMPEG2Streams"];
	}
	
[[NSNotificationCenter defaultCenter] postNotificationName:@"KWOptionsChanged" object:nil];
}

//Use DVD theme clicked in the options menu, save it to the prefs
- (IBAction)optionsUseTheme:(id)sender
{
	if ([optionsUseTheme state] == NSOffState)
	{
	[optionsUseTheme setState:NSOnState];
	[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"KWUseTheme"];
	}
	else
	{
	[optionsUseTheme setState:NSOffState];
	[[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"KWUseTheme"];
	}
	
[[NSNotificationCenter defaultCenter] postNotificationName:@"KWOptionsChanged" object:nil];
}

//Force DivX encoding clicked in the options menu, save it to the prefs
- (IBAction)optionsForceDIVX:(id)sender
{
	if ([optionsForceDIVX state] == NSOffState)
	{
	[optionsForceDIVX setState:NSOnState];
	[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"KWForceDivX"];
	}
	else
	{
	[optionsForceDIVX setState:NSOffState];
	[[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"KWForceDivX"];
	}
	
[[NSNotificationCenter defaultCenter] postNotificationName:@"KWOptionsChanged" object:nil];
}

///////////////////////
// Tableview actions //
///////////////////////

#pragma mark -
#pragma mark •• Tableview actions

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
	if ([[tableViewPopup title] isEqualTo:NSLocalizedString(@"DVD-Video",@"Localized")])
	{
		if ([tableView selectedRow] == -1)
		{
		[[NSNotificationCenter defaultCenter] postNotificationName:@"KWChangeInspector" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"KWEmpty",@"Type",nil]];
		}
		else
		{
			if (![[[[tableData objectAtIndex:0] objectForKey:@"Name"] lowercaseString] isEqualTo:@"video_ts"])
			[[NSNotificationCenter defaultCenter] postNotificationName:@"KWChangeInspector" object:tableView userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"KWDVD",@"Type",nil]];
		}
	}
	else
	{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWChangeInspector" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"KWEmpty",@"Type",nil]];
	}
}

- (void)getTableView
{
	if ([[tableViewPopup title] isEqualTo:@"VCD"])
	{
	tableData = VCDTableData;
	}
	else if ([[tableViewPopup title] isEqualTo:@"SVCD"])
	{
	tableData = SVCDTableData;
	}
	else if ([[tableViewPopup title] isEqualTo:NSLocalizedString(@"DVD-Video",@"Localized")])
	{
	tableData = DVDTableData;
	}
	else if ([[tableViewPopup title] isEqualTo:@"DivX"])
	{
	tableData = DIVXTableData;
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

- (IBAction)changePopup:(id)sender
{	
	if ([[tableViewPopup title] isEqualTo:NSLocalizedString(@"DVD-Video",@"Localized")])
	[popupIcon setImage:[NSImage imageNamed:@"DVD"]];
	else
	[popupIcon setImage:[[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(kGenericCDROMIcon)]];
	
	if ([[tableViewPopup title] isEqualTo:@"DivX"] | [[tableViewPopup title] isEqualTo:NSLocalizedString(@"DVD-Video",@"Localized")])
	[accessOptions setEnabled:YES];
	else
	[accessOptions setEnabled:NO];
	
[self getTableView];
[[NSNotificationCenter defaultCenter] postNotificationName:@"KWChangeBurnStatus" object:[NSNumber numberWithBool:([tableView numberOfRows] > 0)]];
[self calculateTotalSize];
	
	//Save the popup if needed
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWRememberPopups"] == YES)
	[[NSUserDefaults standardUserDefaults] setObject:[tableViewPopup objectValue] forKey:@"KWDefaultVideoType"];
}

- (void)selectPopupTitle:(NSString *)title
{
[tableViewPopup selectItemWithTitle:title];
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

- (BOOL)tableView:(NSTableView *)tableView shouldEditTableColumn:(NSTableColumn *)tableColumn row:(int)row
{    return NO; }

- (NSDragOperation)tableView:(NSTableView*)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)op
{
int result = NSDragOperationNone;

    if (op == NSTableViewDropAbove && ![[tableViewPopup title] isEqualTo:@"DivX"])
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

	if ([[pboard types] containsObject:@"NSGeneralPboardType"] && ![[tableViewPopup title] isEqualTo:@"DivX"])
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
		if (![[tableViewPopup title] isEqualTo:@"DivX"])
		currentDropRow = row;

	[self checkFiles:[pboard propertyListForType:NSFilenamesPboardType]];
	}

return YES;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
{
     [super concludeDragOperation:sender];
}

- (int) numberOfRowsInTableView:(NSTableView *)tableView
{
	return [tableData count];
}

- (id) tableView:(NSTableView *)tableView
    objectValueForTableColumn:(NSTableColumn *)tableColumn
    row:(int)row
{
    NSDictionary *rowData = [tableData objectAtIndex:row];
    return [rowData objectForKey:[tableColumn identifier]];
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

- (BOOL) tableView:(NSTableView *)view writeRows:(NSArray *)rows toPasteboard:(NSPasteboard *)pboard
{
	if (![[tableViewPopup title] isEqualTo:@"DivX"])
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

///////////////////
// Other actions //
///////////////////

#pragma mark -
#pragma mark •• Other actions

- (NSArray *)files
{
NSMutableArray *files = [NSMutableArray array];

	int i;
	for (i=0;i<[tableData count];i++)
	{
	[files addObject:[[tableData objectAtIndex:i] objectForKey:@"Path"]];
	}
	
return files;
}

- (NSString *)discName
{
return [discName stringValue];
}

- (BOOL)isDVDVideo
{
	if ([[tableViewPopup title] isEqualTo:NSLocalizedString(@"DVD-Video",@"Localized")])
	return YES;
	else
	return NO;
}

- (void)volumeLabelSelected:(NSNotification *)notif
{
[[NSNotificationCenter defaultCenter] postNotificationName:@"KWChangeInspector" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"KWEmpty",@"Type",nil]];
}

- (void)tableViewRegenerate
{
NSArray *oldArray = [tableData copy];
[tableData removeAllObjects];

	int i;
	for (i=0;i<[oldArray count];i++)
	{
	NSMutableDictionary *rowData = [[oldArray objectAtIndex:i] mutableCopy];
	[rowData setObject:[[NSFileManager defaultManager] displayNameAtPath:[rowData objectForKey:@"Path"]] forKey:@"Name"];
	[tableData addObject:rowData];
	[rowData release];
	}
	
[tableView reloadData];
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

- (void)calculateTotalSize
{	
[totalSizeText setStringValue:[NSLocalizedString(@"Total size: ",@"Localized") stringByAppendingString:[KWCommonMethods makeSizeFromFloat:[self totalSize] * 2048]]];
}

- (float)totalSize
{
	if ([tableData count] > 0 && [[[[tableData objectAtIndex:0] objectForKey:@"Name"] lowercaseString] isEqualTo:@"video_ts"] && [[tableViewPopup title] isEqualTo:NSLocalizedString(@"DVD-Video",@"Localized")])
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
				
		if ([KWCommonMethods isPanther] | ![[tableViewPopup title] isEqualTo:NSLocalizedString(@"DVD-Video",@"Localized")])
		{
		[discRoot setExplicitFilesystemMask: (DRFilesystemInclusionMaskJoliet)];
		}
		else
		{
		[discRoot setExplicitFilesystemMask: (DRFilesystemInclusionMaskUDF)];
		}
	
	return [[DRTrack trackForRootFolder:discRoot] estimateLength];
	}
}

- (BOOL)isCompatible
{
	if ([[tableViewPopup title] isEqualTo:@"DivX"])
	return YES;
	
return NO;
}

- (BOOL)isCombinable
{
	if (![self hasRows])
	return NO;
	else if (![[tableViewPopup title] isEqualTo:@"DivX"])
	return NO;

return YES;
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

@end
