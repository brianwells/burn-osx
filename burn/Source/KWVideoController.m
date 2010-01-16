//
//  KWVideoController.m
//  Burn
//
//  Created by Maarten Foukhar on 13-09-09.
//  Copyright 2009 Kiwi Fruitware. All rights reserved.
//

#import "KWVideoController.h"
#import <QuickTime/QuickTime.h>
#import <ID3/TagAPI.h>
#import "KWWindowController.h"
#import "KWCommonMethods.h"
#import "KWTrackProducer.h"

@implementation KWVideoController

- (id)init
{
	self = [super init];
	
	//Setup our arrays for the options menus
	dvdOptionsMappings = [[NSArray alloc] initWithObjects:		@"KWDVDForce43",			//0
																@"KWForceMPEG2",			//1
																@"KWMuxSeperateStreams",	//2
																@"KWRemuxMPEG2Streams",		//3
																@"KWLoopDVD",				//4
																@"---",						//5 >> Seperator
																@"KWUseTheme",				//6
																nil];
															
	divxOptionsMappings = [[NSArray alloc] initWithObjects:		@"KWForceDivX",				//0
																nil];

	//Here are our tableviews data stored
	VCDTableData = [[NSMutableArray alloc] init];
	SVCDTableData = [[NSMutableArray alloc] init];
	DVDTableData = [[NSMutableArray alloc] init];
	DIVXTableData = [[NSMutableArray alloc] init];
	
	//Setup supported filetypes (QuickTime and ffmpeg)
	allowedFileTypes = [[KWCommonMethods mediaTypes] retain];
	
	//Set the dvd folder name (different for audio and video)
	dvdFolderName = @"VIDEO_TS";
	
	return self;
}

- (void)dealloc
{
	//Release our previously explained files
	[dvdOptionsMappings release];
	[divxOptionsMappings release];

	[VCDTableData release];
	[SVCDTableData release];
	[DVDTableData release];
	[DIVXTableData release];

	//Release the filetypes stored, using a retain
	[allowedFileTypes release];

	[super dealloc];
}

- (void)awakeFromNib
{
	[super awakeFromNib];
	
	//Set save popup title
	[tableViewPopup selectItemAtIndex:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultVideoType"] intValue]];
	[self tableViewPopup:self];
}

//////////////////
// Main actions //
//////////////////

#pragma mark -
#pragma mark •• Main actions

- (void)addFile:(NSString *)path isSelfEncoded:(BOOL)selfEncoded
{
	BOOL isWide;
	BOOL unsavediMovieProject = NO;
	int selrow = [tableViewPopup indexOfSelectedItem];
	NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];
	
	if ([path rangeOfString:@".iMovieProject"].length > 0)
	{
		if (![[[path stringByDeletingLastPathComponent] lastPathComponent] isEqualTo:@"iDVD"])
		unsavediMovieProject = YES;
	}

	//iMove projects can only be used if saved / contain a iDVD folder
	if (!unsavediMovieProject)
	{
	//Check if the file is allready the right file
	BOOL checkFile;
	converter = [[KWConverter alloc] init];

		if (selrow == 0)
		{
			checkFile = [converter isVCD:path];
		}
		else if (selrow == 1)
		{
			checkFile = [converter isSVCD:path];
		}
		else if (selrow == 2)
		{
			checkFile = (([converter isDVD:path isWideAspect:&isWide] && [standardDefaults boolForKey:@"KWForceMPEG2"] == NO) | selfEncoded == YES);
			
			if ([[path pathExtension] isEqualTo:@"m2v"] && [standardDefaults boolForKey:@"KWMuxSeperateStreams"] == YES)
				checkFile = YES;
		}
		else if (selrow == 3)
		{
			if ([converter isMPEG4:path] && [standardDefaults boolForKey:@"KWForceDivX"] == NO | selfEncoded == YES)
				checkFile = YES;
			else
				checkFile = NO;
			
			[converter release];
		}
		
		NSFileManager *defaultManager = [NSFileManager defaultManager];
		
		//Go on if the file is the right type
		if (checkFile == YES)
		{
			NSString *filePath = path;
			NSString *fileType = NSFileTypeForHFSTypeCode([[[defaultManager fileAttributesAtPath:path traverseLink:YES] objectForKey:NSFileHFSTypeCode] longValue]);
	
			//Remux MPEG2 files that are encoded by another app
			if (selfEncoded == NO && selrow == 2 && [standardDefaults boolForKey:@"KWRemuxMPEG2Streams"] == YES && ![[path pathExtension] isEqualTo:@"m2v"] && ![fileType isEqualTo:@"'MPG2'"])
			{
				NSString *outputFile = [KWCommonMethods temporaryLocation:[[[path lastPathComponent] stringByDeletingPathExtension] stringByAppendingPathExtension:@"mpg"] saveDescription:NSLocalizedString(@"Choose a location to save the re-muxed files",nil)];
				
				if (outputFile)
				{
					[temporaryFiles addObject:outputFile];
					converter = [[KWConverter alloc] init];
					[progressPanel setStatus:[NSLocalizedString(@"Remuxing: ",nil) stringByAppendingString:[defaultManager displayNameAtPath:outputFile]]];

					if ([converter remuxMPEG2File:path outPath:outputFile] == YES)
						filePath = outputFile;
					else
						filePath = @"";
					
					[converter release];
						
					[progressPanel setStatus:NSLocalizedString(@"Scanning for files and folders",nil)];
					[progressPanel setCancelNotification:@"videoCancelAdding"];
				}
			}
			
			//If we have seperate m2v and mp3/ac2 files mux them, if setted in the preferences
			if (([[path pathExtension] isEqualTo:@"m2v"] | [fileType isEqualTo:@"'MPG2'"]) && [[tableViewPopup title] isEqualTo:NSLocalizedString(@"DVD-Video",nil)] && [standardDefaults boolForKey:@"KWMuxSeperateStreams"] == YES)
			{
				NSString *outputFile = [KWCommonMethods temporaryLocation:[[[path lastPathComponent] stringByDeletingPathExtension] stringByAppendingPathExtension:@"mpg"] saveDescription:NSLocalizedString(@"Choose a location to save the muxed file",nil)];
				
				if (outputFile)
				{
					[temporaryFiles addObject:outputFile];
				
					converter = [[KWConverter alloc] init];
			
					if ([converter canCombineStreams:path])
					{
						[progressPanel setStatus:[NSLocalizedString(@"Creating: ",nil) stringByAppendingString:[[[defaultManager displayNameAtPath:path] stringByDeletingPathExtension] stringByAppendingPathExtension:@"mpg"]]];

						if ([converter combineStreams:path atOutputPath:outputFile] == YES)
							filePath = [[path stringByDeletingPathExtension] stringByAppendingPathExtension:@"mpg"];
						else
							filePath = @"";
					
						[converter release];
				
						[progressPanel setStatus:NSLocalizedString(@"Scanning for files and folders",nil)];
						[progressPanel setCancelNotification:@"videoCancelAdding"];
					}
				}
			}
		
			//If none of the above rules are aplied add the file to the list
			if (![filePath isEqualTo:@""])
			{
				NSDictionary *attrib = [defaultManager fileAttributesAtPath:filePath traverseLink:YES];
	
				NSMutableDictionary *rowData = [NSMutableDictionary dictionary];
				[rowData setObject:[defaultManager displayNameAtPath:filePath] forKey:@"Name"];
				[rowData setObject:filePath forKey:@"Path"];
				
				if (selrow == 2)
				{
					[rowData setObject:[NSNumber numberWithBool:isWide] forKey:@"WideScreen"];
					[rowData setObject:[NSArray array] forKey:@"Chapters"];
				}
			
				[rowData setObject:[KWCommonMethods makeSizeFromFloat:[[attrib objectForKey:NSFileSize] floatValue]] forKey:@"Size"];
				[rowData setObject:[[[NSWorkspace sharedWorkspace] iconForFile:filePath] retain] forKey:@"Icon"];
			
				//If we're dealing with a Video_TS folder remve all rows
				if ([tableData count] > 0 && [[[[tableData objectAtIndex:0] objectForKey:@"Name"] lowercaseString] isEqualTo:@"video_ts"] && selrow == 3)
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
				[self performSelectorOnMainThread:@selector(setTotal) withObject: nil waitUntilDone:YES];
			}
		}
		else 
		{
			//Add the file to be encoded
			NSMutableDictionary *rowData = [NSMutableDictionary dictionary];
			[rowData setObject:[[NSFileManager defaultManager] displayNameAtPath:path] forKey:@"Name"];
			[rowData setObject:path forKey:@"Path"];
			[incompatibleFiles addObject:rowData];
		}
	}
}

///////////////////////////
// Disc creation actions //
///////////////////////////

#pragma mark -
#pragma mark •• Disc creation actions

//Set type temporary to video for burning
- (void)burn:(id)sender
{
	currentType = 2;
	[super burn:sender];
	[self tableViewPopup:self];
}

//Create a track for burning
- (id)myTrackWithBurner:(KWBurner *)burner errorString:(NSString **)error
{
	int selrow = [tableViewPopup indexOfSelectedItem];

	if (selrow == 2)
	{
		NSString *outputFolder = [KWCommonMethods temporaryLocation:[discName stringValue] saveDescription:NSLocalizedString(@"Choose a location to save a temporary folder",nil)];
		int succes;
	
		if (outputFolder)
		{
			[temporaryFiles addObject:outputFolder];

			succes = [self authorizeFolderAtPathIfNeededAtPath:outputFolder errorString:&*error];
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
	else if (selrow == 0)
	{
		return [[KWTrackProducer alloc] getTrackForVCDMPEGFiles:[self files] withDiscName:[discName stringValue] ofType:4];
	}
	else if (selrow == 1)
	{
		return [[KWTrackProducer alloc] getTrackForVCDMPEGFiles:[self files] withDiscName:[discName stringValue] ofType:5];
	}

	if (selrow == 3)
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

- (int)authorizeFolderAtPathIfNeededAtPath:(NSString *)path errorString:(NSString **)error
{
	int succes;
	NSDictionary *currentData = [tableData objectAtIndex:0];
	
	if ([tableData count] > 0 && [[[currentData objectForKey:@"Name"] lowercaseString] isEqualTo:@"video_ts"])
	{
		succes = [KWCommonMethods createDVDFolderAtPath:path ofType:1 fromTableData:tableData errorString:&*error];
	}
	else
	{
		int totalSize = [self totalSize];
		NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
		
		[defaultCenter postNotificationName:@"KWMaximumValueChanged" object:[NSNumber numberWithFloat:totalSize]];
		[defaultCenter postNotificationName:@"KWTaskChanged" object:NSLocalizedString(@"Authoring DVD...",nil)];
		[defaultCenter postNotificationName:@"KWStatusChanged" object:NSLocalizedString(@"Processing: ",nil)];
	
		DVDAuthorizer = [[KWDVDAuthorizer alloc] init];
		NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];
		if ([standardDefaults boolForKey:@"KWUseTheme"] == YES)
		{
			NSBundle *themeBundle = [NSBundle bundleWithPath:[standardDefaults objectForKey:@"KWDVDThemePath"]];
			NSDictionary *theme = [[NSArray arrayWithContentsOfFile:[themeBundle pathForResource:@"Theme" ofType:@"plist"]] objectAtIndex:[[standardDefaults objectForKey:@"KWDVDThemeFormat"] intValue]];
			
			succes = [DVDAuthorizer createDVDMenuFiles:path withTheme:theme withFileArray:tableData withSize:[NSNumber numberWithInt:totalSize / 2] withName:[discName stringValue] errorString:&*error];
		}
		else
		{
			succes = [DVDAuthorizer createStandardDVDFolderAtPath:path withFileArray:tableData withSize:[NSNumber numberWithInt:totalSize / 2] errorString:&*error];
		}
	
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
	
	if (selrow == 2 && [tableView selectedRow] > -1)
	{
		if (![[[[tableData objectAtIndex:0] objectForKey:@"Name"] lowercaseString] isEqualTo:@"video_ts"])
		[defaultCenter postNotificationName:@"KWChangeInspector" object:tableView userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"KWDVD",@"Type",nil]];
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
	currentType = 2;
	currentFileSystem = @"";
	convertExtension = @"mpg";
	useRegion = YES;
	isDVD = NO;
	canBeReorderd = YES;

	if (selrow == 0)
	{
		tableData = VCDTableData;
		currentType = 4;
		currentFileSystem = @"-vcd";
		convertKind = 1;
	}
	else if (selrow == 1)
	{
		tableData = SVCDTableData;
		currentType = 4;
		currentFileSystem = @"-svcd";
		convertKind = 2;
	}
	else if (selrow == 2)
	{
		tableData = DVDTableData;
		isDVD = YES;
		convertKind = 3;
		optionsPopup = dvdOptionsPopup;
		optionsMappings = dvdOptionsMappings;
	}
	else if (selrow == 3)
	{
		tableData = DIVXTableData;
		convertExtension = @"avi";
		useRegion = NO;
		canBeReorderd = NO;
		convertKind = 4;
		optionsPopup = divxOptionsPopup;
		optionsMappings = divxOptionsMappings;
	}

	[tableView reloadData];
}

//Popup clicked
- (IBAction)tableViewPopup:(id)sender
{
	int selrow = [tableViewPopup indexOfSelectedItem];

	if (selrow == 2)
		[popupIcon setImage:[NSImage imageNamed:@"DVD"]];
	else
		[popupIcon setImage:[[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(kGenericCDROMIcon)]];
	
	[accessOptions setEnabled:(selrow == 2 | selrow == 3)];
	
	[self getTableView];
	
	[self setTotal];
	
	//Save the popup if needed
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWRememberPopups"] == YES)
		[[NSUserDefaults standardUserDefaults] setObject:[tableViewPopup objectValue] forKey:@"KWDefaultVideoType"];
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

//Check if the disc can be combined
- (BOOL)isCombinable
{
	return ([tableData count] > 0 | [tableViewPopup indexOfSelectedItem] > 2);
}

- (void)volumeLabelSelected:(NSNotification *)notif
{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWChangeInspector" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"KWEmpty",@"Type",nil]];
}

@end