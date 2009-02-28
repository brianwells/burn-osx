#import "dataController.h"
#import "FSTreeNode.h"
#import "ImageAndTextCell.h"
#import "NSArray_Extensions.h"
#import "NSOutlineView_Extensions.h"
#import <DiscRecording/DiscRecording.h>
#import "KWDocument.h"
#import "KWCommonMethods.h"
#import "discCreationController.h"

@interface dataController (Private)

- (void)_addNewDataToSelection:(TreeNode *)newChild shouldSelect:(BOOL)boolean;

@end

// ================================================================
// Useful Macros
// ================================================================

#define COLUMNID_NAME		 		@"name"
#define COLUMNID_KIND		 		@"kind"

// Conveniences for accessing nodes, or the data in the node.
#define NODE(n)				((TreeNode*)n)
#define SAFENODE(n) 		((TreeNode*)((n)?(n):(treeData)))
#define NODE_DATA(n)		((FSNodeData*)[SAFENODE(n) nodeData])

static NSString* 	EDBFileTreeDragPboardType 					= @"EDBFileTreeDragPboardType";
static NSString*	EDBSelectionChangedNotification				= @"EDBSelectionChangedNotification";
static NSString*	EDBCurrentSelection							= @"EDBCurrentSelection";

@implementation dataController

/////////////////////
// Default actions //
/////////////////////

#pragma mark -
#pragma mark •• Default actions

- (id) init
{
	if (self = [super init])
	{
	//Setup our array for the options menu
	optionsMappings = [[NSArray alloc] initWithObjects:	@"KWShowFilePackagesAsFolder",	//0
														@"KWCalculateFilePackageSizes",	//1
														@"KWCalculateFolderSizes",		//2
														@"KWCalculateTotalSize",		//3
														nil];
	
	//Root folder of the disc
	KWDRFolder*	folderObj = [[[KWDRFolder alloc] initWithName:NSLocalizedString(@"Untitled", Localized)] autorelease];
	//Put our rootfolder in de noteData from our outlineview
	FSNodeData*	nodeData = [[[FSFolderNodeData alloc] initWithFSObject:folderObj] autorelease];;
		
	// Set the eplicit mask for the root object. This make sure that all items added to it
	// get the correct filesystem mask inherited from the root. If we didn't set this here
	// we'd need to worry about possible changes to how the default mask value is interpreted
	// in different versions of the framework.
	
	// Panther doesn't have UDF so don't add it
		if (![KWCommonMethods isPanther])
		[folderObj setExplicitFilesystemMask: (DRFilesystemInclusionMaskISO9660 | DRFilesystemInclusionMaskJoliet | DRFilesystemInclusionMaskHFSPlus | DRFilesystemInclusionMaskUDF)];
		else
		[folderObj setExplicitFilesystemMask: (DRFilesystemInclusionMaskISO9660 | DRFilesystemInclusionMaskJoliet | DRFilesystemInclusionMaskHFSPlus)];

	treeData = [[FSTreeNode treeNodeWithData:nodeData] retain];
	
	//Calculating size while mass loading files, we don't want that ;-)
	loadingBurnFile = NO;
	
	temporaryFiles = [[NSMutableArray alloc] init];
	}

return self;
}

- (void)dealloc 
{
//Stop listening to notifications
[[NSNotificationCenter defaultCenter] removeObserver:self];

//Release our stuff
[treeData release];
treeData = nil;
[temporaryFiles release];
//New
[lastSelectedItem release];
[optionsMappings release];

//Release disc properties if needed
	if (discProperties)
	{
	[discProperties release];
	discProperties = nil;
	}

[super dealloc];
}

- (void)awakeFromNib 
{
[iconView setImage:[[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(kGenericCDROMIcon)]];

//Notifications
//Reload the outlineview if need, like when a change has been made in the preferences
[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadOutlineView) name:@"KWReloadRequested" object:nil];
//Used to save the popups when the user selects this option in the preferences
[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dataPopupChanged:) name:@"KWTogglePopups" object:nil];
//Prevent files to be dropped when for example a sheet is open
[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setOutlineViewState:) name:@"KWSetDropState" object:nil];
//Updates the Inspector window with the new item selected in the list
[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(outlineViewSelectionDidChange:) name:@"KWDataListSelected" object:outlineView];
//Updates the Inspector window to show the information about the disc
[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(volumeLabelSelected:) name:@"KWDiscNameSelected" object:discName];
//Change properties variable when disc properties are changed
[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(discPropertiesChanged:) name:@"KWDiscPropertiesChanged" object:nil];

//Set advanced sheet file systems
	NSArray *sheetFileSystems = [[NSUserDefaults standardUserDefaults] objectForKey:@"KWAdvancedFileSystems"];
	if ([sheetFileSystems count] > 0)
	{
	[okSheet setEnabled:YES];
	
		if ([sheetFileSystems containsObject:@"HFS+"])
		[hfsSheet setState:NSOnState];
		
		if ([sheetFileSystems containsObject:@"ISO9660"])
		[isoSheet setState:NSOnState];
		
		if ([sheetFileSystems containsObject:@"Joliet"])
		[jolietSheet setState:NSOnState];
		
		if ([sheetFileSystems containsObject:@"UDF"])
		[udfSheet setState:NSOnState];
		
		if ([sheetFileSystems containsObject:@"HFS"])
		[hfsStandardSheet setState:NSOnState];
		
	[self filesystemSelectionChanged:self];
	}
	
//Set preferences
[fileSystemPopup selectItemAtIndex:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultDataType"] intValue]];
lastSelectedItem = [[fileSystemPopup title] retain];
[self updateFileSystem];

//Setup the optionsmenu
	
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWCalculateTotalSize"] == NO)
	[totalSizeText setHidden:YES];

//Outline
NSTableColumn*		tableColumn = nil;
ImageAndTextCell*	imageAndTextCell = nil;

// Insert custom cell types into the table view, the standard one does text only.
// We want one column to have text and images
tableColumn = [outlineView tableColumnWithIdentifier: COLUMNID_NAME];
imageAndTextCell = [[[ImageAndTextCell alloc] init] autorelease];
[imageAndTextCell setEditable:YES];
[tableColumn setDataCell:imageAndTextCell];
    	
// Register to get our custom type, strings, and filenames.... try dragging each into the view!
[outlineView registerForDraggedTypes:[NSArray arrayWithObjects:EDBFileTreeDragPboardType, NSFilenamesPboardType,@"CorePasteboardFlavorType 0x6974756E", nil]];

[outlineView setAllowsColumnReordering:NO];

	if ([KWCommonMethods isPanther])
	{
	[fileSystemPopup removeItemWithTitle:@"DVD (UDF)"];
	[udfSheet setTitle:NSLocalizedString(@"UDF / ISO9660 (only)",@"Localized")];
	}

[self setTotalSize];
}

//////////////////
// File actions //
//////////////////

#pragma mark -
#pragma mark •• File actions

- (IBAction)openFiles:(id)sender
{
NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	
[openPanel setCanChooseDirectories:YES];
[openPanel setCanChooseFiles:YES];
[openPanel setAllowsMultipleSelection:YES];
[openPanel setResolvesAliases:NO];

[openPanel beginSheetForDirectory:nil file:nil types:nil modalForWindow:mainWindow modalDelegate:self didEndSelector:@selector(addRealFileEnded:returnCode:contextInfo:) contextInfo:nil];
}

- (void)addRealFileEnded:(NSOpenPanel*)panel returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
[panel orderOut:self];

	if (returnCode == NSOKButton)
	{
	[self addFiles:[panel filenames] removeFiles:NO];
	}
}

- (void)addDroppedOnIconFiles:(NSArray *)paths
{
	if ([paths count] == 1 && [outlineView numberOfRows] == 0)
	{
		NSString *path = [paths objectAtIndex:0];
		
		BOOL isDir;
		if ([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir])
		{
			if (isDir == YES)
			{
			[self setDiskName:[path lastPathComponent]];
				
				NSArray *files = [[NSFileManager defaultManager] directoryContentsAtPath:path];
				NSMutableArray *fulPaths = [[NSMutableArray alloc] init];
				int i = 0;
				for (i=0;i<[files count];i++)
				{
				[fulPaths addObject:[path stringByAppendingPathComponent:[files objectAtIndex:i]]];
				}
					
			[self addFiles:[fulPaths copy] removeFiles:YES];
			[fulPaths release];
			}
			else
			{
			[self addFiles:paths removeFiles:NO];
			}
		}
	}
	else
	{
	[self addFiles:paths removeFiles:NO];
	}
}

- (void)addFiles:(NSArray *)paths removeFiles:(BOOL)remove
{
	if (remove == YES)
	{
	[outlineView selectAll:self];
	[self deleteFiles:self];
	[[(FSNodeData*)[treeData nodeData] fsObject] setBaseName:[[NSFileManager defaultManager] displayNameAtPath:[[paths objectAtIndex:0] stringByDeletingLastPathComponent]]];
	[self changeBaseName:discName];
	}

NSEnumerator*	iter = [paths objectEnumerator];
NSString*		path;
		
	while ((path = [iter nextObject]) != NULL)
	{
	BOOL		isDir;
	id 			nodeData = nil;
			
	// Now that we've got the pathnames of the files/folders the user chose, 
	// create the appropriate KWDRFolder or DRFile object for each path
	// and put it into a FSNodeData obejct so that the disc hierarchy
	// outline table can manage it.
		if ([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir])
		{
			if ([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir] && isDir)
			{
			KWDRFolder*	folderObj = [[[KWDRFolder alloc] initWithPath:path] autorelease];
			nodeData = [[FSFolderNodeData alloc] initWithFSObject:folderObj];
			}
			else
			{
			DRFile*	fileObj = [DRFile fileWithPath:path];
			nodeData = [[FSFileNodeData alloc] initWithFSObject:fileObj];
			}
		}
			
		if (nodeData)
		{
		FSTreeNode*	newNode = [FSTreeNode treeNodeWithData:nodeData];
		[self _addNewDataToSelection:newNode  shouldSelect:NO];
		[nodeData release];
		}
	}
	
[outlineView reloadData];

[[NSNotificationCenter defaultCenter] postNotificationName:@"KWChangeBurnStatus" object:[NSNumber numberWithBool:([outlineView numberOfRows] > 0)]];

[self setTotalSize];
}

- (IBAction)deleteFiles:(id)sender
{
NSArray *selection = [outlineView allSelectedItems];
NSMutableArray *icons = [NSMutableArray array];
  
	int x;
	for (x=0;x<[selection count];x++)
	{
	NSAutoreleasePool *subPool = [[NSAutoreleasePool alloc] init];
	
		if ([[[NODE_DATA((TreeNode *)[selection objectAtIndex:x]) fsObject] baseName] isEqualTo:@"Icon\r"])
		[icons addObject:[selection objectAtIndex:x]];
		else
		[[selection objectAtIndex:x] removeFromParent];
		
	[subPool release];
	}
	
[self setTotalSize];
	
	for (x=0;x<[icons count];x++)
	{
	[[icons objectAtIndex:x] removeFromParent];
	}
	
[selection makeObjectsPerformSelector: @selector(removeFromParent)];
[outlineView deselectAll:nil];
[outlineView reloadData];

[[NSNotificationCenter defaultCenter] postNotificationName:@"KWChangeBurnStatus" object:[NSNumber numberWithBool:([outlineView numberOfRows] > 0)]];
}

- (void)setTotalSize
{
NSString *string;

	if (![totalSizeText isHidden] && loadingBurnFile == NO)
	{
	string = [NSLocalizedString(@"Total size: ",@"Localized") stringByAppendingString:[KWCommonMethods makeSizeFromFloat:[self totalSize] * 2048]];
	[totalSizeText setStringValue:[[string copy] autorelease]];
	}
}

-(float)totalSize
{
KWDRFolder *rootFolder = (KWDRFolder*)[(FSNodeData*)[treeData nodeData] fsObject];
DRTrack *track = [DRTrack trackForRootFolder:rootFolder];

return [track estimateLength];
}

- (void)updateFileSystem
{
KWDRFolder *rootFolder = (KWDRFolder*)[(FSNodeData*)[treeData nodeData] fsObject];
[discName setStringValue:[[(FSNodeData*)[treeData nodeData] fsObject] baseName]];
[rootFolder setHfsStandard:NO];
	
	if ([fileSystemPopup indexOfSelectedItem] == 0)
	{
	[rootFolder setExplicitFilesystemMask: (DRFilesystemInclusionMaskHFSPlus)];
	}
	else if ([fileSystemPopup indexOfSelectedItem] == 1)
	{
	[rootFolder setExplicitFilesystemMask: (DRFilesystemInclusionMaskJoliet)];
	}
	else if ([fileSystemPopup indexOfSelectedItem] == 2)
	{
	[rootFolder setExplicitFilesystemMask: (DRFilesystemInclusionMaskJoliet | DRFilesystemInclusionMaskHFSPlus | DRFilesystemInclusionMaskISO9660)];
	}
	else if ([fileSystemPopup indexOfSelectedItem] == 3 && ![KWCommonMethods isPanther])
	{
	[rootFolder setExplicitFilesystemMask: (DRFilesystemInclusionMaskUDF)];
	}
	else if ([fileSystemPopup selectedItem] == [fileSystemPopup lastItem])
	{
	DRFilesystemInclusionMask mask = 0;
	
		if ([hfsStandardSheet state] == NSOnState | ([udfSheet state] == NSOnState && [KWCommonMethods isPanther]))
		{
			//Special filesystem for HFS Standard
			if ([hfsStandardSheet state] == NSOnState)
			{
			mask = (mask | (1<<4));
			}
		}
		else
		{
			if ([hfsSheet state] == NSOnState)
			mask = (mask | DRFilesystemInclusionMaskHFSPlus);
		
			if ([isoSheet state] == NSOnState)
			mask = (mask | DRFilesystemInclusionMaskISO9660);
		
			if ([jolietSheet state] == NSOnState)
			mask = (mask | DRFilesystemInclusionMaskJoliet);
		
			if ([udfSheet state] == NSOnState)
			mask = (mask | DRFilesystemInclusionMaskUDF);
		}
		
	[rootFolder setExplicitFilesystemMask:mask];
	
		if ([hfsSheet state] == NSOffState && [udfSheet state] == NSOffState && [isoSheet state] == NSOnState && [jolietSheet state] == NSOffState && [hfsStandardSheet state] == NSOffState)
		[discName setStringValue:[[(FSNodeData*)[treeData nodeData] fsObject] mangledNameForFilesystem:DRISO9660LevelTwo]];
	}
}

- (IBAction)dataPopupChanged:(id)sender
{	
	if ([fileSystemPopup selectedItem] == [fileSystemPopup lastItem] && ![sender isEqualTo:okSheet] && [sender isEqualTo:fileSystemPopup])
	{
	[NSApp beginSheet:advancedSheet modalForWindow:mainWindow modalDelegate:self didEndSelector:@selector(advancedSheetDidEnd:returnCode:contextInfo:) contextInfo:NULL];
	}
	else
	{
		[self updateFileSystem];
		[self reloadOutlineView];
	
		if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWRememberPopups"] == YES)
		[[NSUserDefaults standardUserDefaults] setObject:[fileSystemPopup objectValue] forKey:@"KWDefaultDataType"];
	
		if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWCalculateTotalSize"] == NO)
		{
		[totalSizeText setHidden:YES];
		}
		else
		{
		[totalSizeText setHidden:NO];
		[self setTotalSize];
		}

		if (outlineView == [mainWindow firstResponder])
		{
		[self outlineViewSelectionDidChange:nil];
		}
		else
		{
			if ([self isCompatible])
			[[NSNotificationCenter defaultCenter] postNotificationName:@"KWChangeInspector" object:[(FSNodeData*)[treeData nodeData] fsObject] userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"KWDataDisc",@"Type",nil]];
			else
			[[NSNotificationCenter defaultCenter] postNotificationName:@"KWChangeInspector" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"KWEmpty",@"Type",nil]];
		}
	
	lastSelectedItem = [[fileSystemPopup title] retain];
	}
}

- (void)advancedSheetDidEnd:(NSWindow*)panel returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[panel orderOut:self];
	
	if (returnCode == NSOKButton)
	{
	NSMutableArray *mutFileSystems = [NSMutableArray array];
	
		if ([hfsSheet state] == NSOnState)
		[mutFileSystems addObject:@"HFS+"];
		
		if ([isoSheet state] == NSOnState)
		[mutFileSystems addObject:@"ISO9660"];
		
		if ([jolietSheet state] == NSOnState)
		[mutFileSystems addObject:@"Joliet"];
		
		if ([udfSheet state] == NSOnState)
		[mutFileSystems addObject:@"UDF"];
		
		if ([hfsStandardSheet state] == NSOnState)
		[mutFileSystems addObject:@"HFS"];
	
	[[NSUserDefaults standardUserDefaults] setObject:mutFileSystems forKey:@"KWAdvancedFileSystems"];
	
	[self dataPopupChanged:okSheet];
	}
	else
	{
		NSArray *sheetFileSystems = [[NSUserDefaults standardUserDefaults] objectForKey:@"KWAdvancedFileSystems"];
		if ([sheetFileSystems count] > 0)
		{
		[okSheet setEnabled:YES];
	
			if ([sheetFileSystems containsObject:@"HFS+"])
			[hfsSheet setState:NSOnState];
			else
			[hfsSheet setState:NSOffState];
		
			if ([sheetFileSystems containsObject:@"ISO9660"])
			[isoSheet setState:NSOnState];
			else
			[isoSheet setState:NSOffState];
		
			if ([sheetFileSystems containsObject:@"Joliet"])
			[jolietSheet setState:NSOnState];
			else
			[jolietSheet setState:NSOffState];
		
			if ([sheetFileSystems containsObject:@"UDF"])
			[udfSheet setState:NSOnState];
			else
			[udfSheet setState:NSOffState];
			
			if ([sheetFileSystems containsObject:@"HFS"])
			[hfsStandardSheet setState:NSOnState];
			else
			[hfsStandardSheet setState:NSOffState];
			
		[self filesystemSelectionChanged:self];
			
		[fileSystemPopup selectItemWithTitle:lastSelectedItem];
		}
	}
}

- (IBAction)changeBaseName:(id)sender
{
	if ([fileSystemPopup selectedItem] == [fileSystemPopup lastItem] && [hfsSheet state] == NSOffState && [udfSheet state] == NSOffState && [isoSheet state] == NSOnState && [jolietSheet state] == NSOffState)
	{
		if (![[[sender stringValue] lowercaseString] isEqualTo:[[[(FSNodeData*)[treeData nodeData] fsObject] baseName] lowercaseString]])
		{
		[[(FSNodeData*)[treeData nodeData] fsObject] setBaseName:[sender stringValue]];
		[sender setStringValue:[[(FSNodeData*)[treeData nodeData] fsObject] mangledNameForFilesystem:DRISO9660LevelTwo]];
		}
	}
	else
	{
		if (![[sender stringValue] isEqualTo:[[(FSNodeData*)[treeData nodeData] fsObject] baseName]])
		[[(FSNodeData*)[treeData nodeData] fsObject] setBaseName:[sender stringValue]];
	}
}

/////////////////////////
// Option menu actions //
/////////////////////////

#pragma mark -
#pragma mark •• Option menu actions


- (IBAction)accessOptions:(id)sender
{
	//Setup options menu
	int i = 0;
	for (i=0;i<[optionsPopup numberOfItems]-1;i++)
	{
	[[optionsPopup itemAtIndex:i+1] setState:[[[NSUserDefaults standardUserDefaults] objectForKey:[optionsMappings objectAtIndex:i]] intValue]];
	}

[optionsPopup performClick:self];
}

- (IBAction)setOption:(id)sender
{
[[NSUserDefaults standardUserDefaults] setBool:([sender state] == NSOffState) forKey:[optionsMappings objectAtIndex:[optionsPopup indexOfItem:sender] - 1]];
[[NSUserDefaults standardUserDefaults] synchronize];

	if ([optionsPopup indexOfItem:sender] == 4)
	[totalSizeText setHidden:([sender state] == NSOnState)];
	else
	[self reloadOutlineView];

[[NSNotificationCenter defaultCenter] postNotificationName:@"KWOptionsChanged" object:nil];
}

//////////////////////////////
// New Folder Sheet actions //
//////////////////////////////

#pragma mark -
#pragma mark •• New Folder Sheet actions

- (IBAction)newVirtualFolder:(id)sender 
{
[newFolderSheet makeFirstResponder:folderName];
[folderName setStringValue:@""];

//Just a folder kGenericFolderIcon creates weird folders on Intel
NSImage *img = [[NSWorkspace sharedWorkspace] iconForFile:@"/bin"];
[img setScalesWhenResized:YES];
[img setSize:NSMakeSize(64.0,64.0)];
[folderIcon setImage:img];

[NSApp beginSheet:newFolderSheet modalForWindow:mainWindow modalDelegate:self didEndSelector:@selector(newFolderSheetDidEnd:returnCode:contextInfo:) contextInfo:NULL];
}

- (IBAction)ok:(id)sender
{
[NSApp endSheet:newFolderSheet returnCode:NSOKButton];
}

- (IBAction)cancel:(id)sender
{
[NSApp endSheet:newFolderSheet returnCode:NSCancelButton];
}

- (void)newFolderSheetDidEnd:(NSWindow*)panel returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
[panel orderOut:self];
[outlineView display]; 
	
	if (returnCode == NSOKButton)
	{
	KWDRFolder*	folderObj = [[[KWDRFolder alloc] initWithName:[folderName stringValue]] autorelease];
		
		id nodeData = [[FSFolderNodeData alloc] initWithFSObject:folderObj];
		if (nodeData)
		{
			FSTreeNode*	newNode = [FSTreeNode treeNodeWithData:nodeData];
			[self _addNewDataToSelection:newNode  shouldSelect:NO];
			[nodeData release];
		}
	}
}

////////////////////////////
// Advanced Sheet actions //
////////////////////////////

#pragma mark -
#pragma mark •• Advanced Sheet actions

- (IBAction)filesystemSelectionChanged:(id)sender
{
//If one filesystem is selected set OK enabled
[okSheet setEnabled:([hfsSheet state] == NSOnState | [isoSheet state] == NSOnState | [jolietSheet state] == NSOnState | [udfSheet state] == NSOnState | [hfsStandardSheet state] == NSOnState)];

BOOL hfsSelected = [hfsStandardSheet state] == NSOnState;
BOOL pantherUDFSelected = [udfSheet state] == NSOnState && [KWCommonMethods isPanther];

[hfsSheet setEnabled:(!hfsSelected && !pantherUDFSelected)];
[isoSheet setEnabled:(!hfsSelected && !pantherUDFSelected)];
[jolietSheet setEnabled:(!hfsSelected && !pantherUDFSelected)];
[udfSheet setEnabled:!hfsSelected];
[hfsStandardSheet setEnabled:!pantherUDFSelected];
}

- (IBAction)okSheet:(id)sender
{
[NSApp endSheet:advancedSheet returnCode:NSOKButton];
}

- (IBAction)cancelSheet:(id)sender
{
[NSApp endSheet:advancedSheet returnCode:NSCancelButton];
}

///////////////////////////
// Disc creation actions //
///////////////////////////

#pragma mark -
#pragma mark •• Disc creation actions

- (void)burn
{
[myDiscCreationController burnDiscWithName:[discName stringValue] withType:0];
}

- (void)saveImage
{
[myDiscCreationController saveImageWithName:[discName stringValue] withType:0 withFileSystem:@""];
}

- (id)myTrack
{
	if ([fileSystemPopup selectedItem] == [fileSystemPopup lastItem] && [hfsStandardSheet state] == NSOnState)
	{
	NSString *outputFolder = [KWCommonMethods temporaryLocation:[discName stringValue] saveDescription:NSLocalizedString(@"Choose a location to save a temporary folder",@"Localized")];
		
		if (outputFolder)
		{
		[temporaryFiles addObject:outputFolder];
		[[NSFileManager defaultManager] createDirectoryAtPath:outputFolder attributes:nil];
		[self createVirtualFolder:[SAFENODE(treeData) children] atPath:outputFolder];
	
		return [[KWTrackProducer alloc] getTrackForFolder:outputFolder ofType:1 withDiscName:[discName stringValue]];
		}
		else
		{
		return [NSNumber numberWithInt:2];
		}
	}
	else if ([fileSystemPopup selectedItem] == [fileSystemPopup lastItem] && [udfSheet state] == NSOnState && [KWCommonMethods isPanther])
	{
	NSString *outputFolder = [KWCommonMethods temporaryLocation:[discName stringValue] saveDescription:NSLocalizedString(@"Choose a location to save a temporary folder",@"Localized")];
	
		if (outputFolder)
		{
		[temporaryFiles addObject:outputFolder];
		[[NSFileManager defaultManager] createDirectoryAtPath:outputFolder attributes:nil];
		[self createVirtualFolder:[SAFENODE(treeData) children] atPath:outputFolder];
	
		return [[KWTrackProducer alloc] getTrackForFolder:outputFolder ofType:2 withDiscName:[discName stringValue]];
		}
		else
		{
		return [NSNumber numberWithInt:2];
		}
	}

KWDRFolder *rootFolder = (KWDRFolder*)[(FSNodeData*)[treeData nodeData] fsObject];
NSString *volumeName = [discName stringValue];
	
	if ([fileSystemPopup indexOfSelectedItem] == 0)
	{
	[rootFolder setExplicitFilesystemMask: (DRFilesystemInclusionMaskHFSPlus)];
	[rootFolder setSpecificName:volumeName forFilesystem:DRHFSPlus];
	}
	else if ([fileSystemPopup indexOfSelectedItem] == 1)
	{
	[rootFolder setExplicitFilesystemMask: (DRFilesystemInclusionMaskJoliet)];
	[rootFolder setSpecificName:volumeName forFilesystem:DRJoliet];
	[rootFolder setSpecificName:volumeName forFilesystem:DRISO9660LevelTwo];
	
		if ([volumeName length] > 16)
		{
		NSRange	jolietVolumeRange = NSMakeRange(0, 16);
		volumeName = [volumeName substringWithRange:jolietVolumeRange];
		[rootFolder setSpecificName:volumeName forFilesystem:DRJoliet];
		}
	}
	else if ([fileSystemPopup indexOfSelectedItem] == 2)
	{
	[rootFolder setExplicitFilesystemMask: (DRFilesystemInclusionMaskJoliet | DRFilesystemInclusionMaskHFSPlus)];
	[rootFolder setSpecificName:volumeName forFilesystem:DRHFSPlus];
	[rootFolder setSpecificName:volumeName forFilesystem:DRJoliet];
	[rootFolder setSpecificName:volumeName forFilesystem:DRISO9660LevelTwo];
	
		if ([volumeName length] > 16)
		{
		NSRange	jolietVolumeRange = NSMakeRange(0, 16);
		volumeName = [volumeName substringWithRange:jolietVolumeRange];
		[rootFolder setSpecificName:volumeName forFilesystem:DRJoliet];
		}
	}
	else if ([fileSystemPopup indexOfSelectedItem] == 3 && ![KWCommonMethods isPanther])
	{
	[rootFolder setExplicitFilesystemMask: (DRFilesystemInclusionMaskUDF)];
	[rootFolder setSpecificName:volumeName forFilesystem:DRUDF];
	}
	else if ([fileSystemPopup selectedItem] == [fileSystemPopup lastItem])
	{
	DRFilesystemInclusionMask mask = 0;
	
		if ([hfsSheet state] == NSOnState)
		{
		[rootFolder setSpecificName:volumeName forFilesystem:DRHFSPlus];
		mask = (mask | DRFilesystemInclusionMaskHFSPlus);
		}
		
		if ([isoSheet state] == NSOnState)
		{
		[rootFolder setSpecificName:volumeName forFilesystem:DRISO9660LevelTwo];
		[rootFolder setSpecificName:volumeName forFilesystem:DRISO9660LevelOne];
		mask = (mask | DRFilesystemInclusionMaskISO9660);
		}
	
		if ([jolietSheet state] == NSOnState)
		{
		[rootFolder setSpecificName:volumeName forFilesystem:DRJoliet];
		
			if ([volumeName length] > 16)
			{
			NSRange	jolietVolumeRange = NSMakeRange(0, 16);
			volumeName = [volumeName substringWithRange:jolietVolumeRange];
			[rootFolder setSpecificName:volumeName forFilesystem:DRJoliet];
			}
		
		mask = (mask | DRFilesystemInclusionMaskJoliet);
		}
		
		if ([udfSheet state] == NSOnState && ![KWCommonMethods isPanther])
		{
		[rootFolder setSpecificName:volumeName forFilesystem:DRUDF];
		mask = (mask | DRFilesystemInclusionMaskUDF);
		}
		
	[rootFolder setExplicitFilesystemMask:mask];
	}

return rootFolder;
}

- (void)createVirtualFolder:(NSArray *)items atPath:(NSString *)path
{
id item;
unsigned int length = 0;

NSEnumerator *itemEnum = [items objectEnumerator];
	
	while (item = [itemEnum nextObject]) 
	{
		if ([NODE_DATA(item) isExpandable] && [[NODE_DATA(item) fsObject] isVirtual]) 
		{
		NSString *fileName = [NODE_DATA(item) name];
		NSString *savePath = [KWCommonMethods uniquePathNameFromPath:[path stringByAppendingPathComponent:fileName] withLength:0];
		[[NSFileManager defaultManager] createDirectoryAtPath:savePath attributes:nil];
		NSArray *children = [SAFENODE(item) children];
		
		[self createVirtualFolder:children atPath:savePath];
		}
		else 
		{
		NSString *file = [[NODE_DATA(item) fsObject] sourcePath];
		NSDirectoryEnumerator *enumer;
		NSString *pathName;
		BOOL fileIsFolder = NO;
	
		[[NSFileManager defaultManager] fileExistsAtPath:file isDirectory:&fileIsFolder];
		
			if (fileIsFolder)
			{
			NSString *saveFileName = [[NODE_DATA(item) fsObject] baseName];
			NSString *savePath = [KWCommonMethods uniquePathNameFromPath:[path stringByAppendingPathComponent:saveFileName] withLength:length];
			
			[[NSFileManager defaultManager] createDirectoryAtPath:savePath attributes:nil];
					
				enumer = [[NSFileManager defaultManager] enumeratorAtPath:file];
				while (pathName = [enumer nextObject])
				{
				[[NSFileManager defaultManager] fileExistsAtPath:[file stringByAppendingPathComponent:pathName] isDirectory:&fileIsFolder];
					
					if (fileIsFolder)
					{
					NSString *savePathName = [pathName lastPathComponent];
					NSString *savePath = [KWCommonMethods uniquePathNameFromPath:[path stringByAppendingPathComponent:[[saveFileName stringByAppendingPathComponent:[pathName stringByDeletingLastPathComponent]] stringByAppendingPathComponent:savePathName]] withLength:length];
			
					[[NSFileManager defaultManager] createDirectoryAtPath:savePath attributes:nil];
					}
					else
					{
					NSString *savePathName = [pathName lastPathComponent];
					NSString *savePath = [KWCommonMethods uniquePathNameFromPath:[path stringByAppendingPathComponent:[[saveFileName stringByAppendingPathComponent:[pathName stringByDeletingLastPathComponent]] stringByAppendingPathComponent:savePathName]] withLength:length];

					[[NSFileManager defaultManager] createSymbolicLinkAtPath:savePath pathContent:[file stringByAppendingPathComponent:pathName]];
						
						if ([[[file stringByAppendingPathComponent:pathName] lastPathComponent] isEqualTo:@"Icon\r"])
						{
							if (![KWCommonMethods isPanther])
							[[NSWorkspace sharedWorkspace] setIcon:[[NSWorkspace sharedWorkspace] iconForFile:[[file stringByAppendingPathComponent:pathName] stringByDeletingLastPathComponent]] forFile:[[path stringByAppendingPathComponent:[[file lastPathComponent] stringByAppendingPathComponent:pathName]] stringByDeletingLastPathComponent] options:NSExclude10_4ElementsIconCreationOption];
						}
					}
				}
			}
			else
			{
			NSString *saveFileName = [[NODE_DATA(item) fsObject] baseName];
			NSString *savePath = [KWCommonMethods uniquePathNameFromPath:[path stringByAppendingPathComponent:saveFileName] withLength:length];
	
			[[NSFileManager defaultManager] createSymbolicLinkAtPath:savePath pathContent:file];
			}
		}
	}
}

//////////////////
// Save actions //
//////////////////

#pragma mark -
#pragma mark •• Save actions

- (void)openBurnDocument:(NSString *)path
{
NSDictionary *burnFile = [NSDictionary dictionaryWithContentsOfFile:path];

[fileSystemPopup setObjectValue:[burnFile objectForKey:@"KWSubType"]];

NSArray *advancedStates = [burnFile objectForKey:@"KWDataTypes"];
[hfsSheet setObjectValue:[advancedStates objectAtIndex:0]];
[isoSheet setObjectValue:[advancedStates objectAtIndex:1]];
[jolietSheet setObjectValue:[advancedStates objectAtIndex:2]];
[udfSheet setObjectValue:[advancedStates objectAtIndex:3]];
[hfsStandardSheet setObjectValue:[advancedStates objectAtIndex:4]];

[self filesystemSelectionChanged:self];

[self loadSaveDictionary:[burnFile objectForKey:@"KWProperties"]];
}

- (void)loadSaveDictionary:(NSDictionary *)savedDictionary
{
loadingBurnFile = YES;

[discName setStringValue:[savedDictionary objectForKey:@"Name"]];
[self changeBaseName:discName];
NSArray *savedArray = [savedDictionary objectForKey:@"Files"];

[outlineView selectAll:nil];
NSArray *rowSelection = [outlineView allSelectedItems];
[rowSelection makeObjectsPerformSelector: @selector(removeFromParent)];
[outlineView deselectAll:nil];
[outlineView reloadData];

	NSDictionary *properties = [[savedDictionary objectForKey:@"Properties"] objectForKey:@"Disc Properties"];
	if (properties)
	[(KWDRFolder *)[(FSNodeData*)[treeData nodeData] fsObject] setDiscProperties:properties];

[self setPropertiesFor:[(FSNodeData*)[treeData nodeData] fsObject] fromDictionary:[savedDictionary objectForKey:@"Properties"]];

[self loadOutlineItems:savedArray originalArray:savedArray];

[[(NSScrollView *)[[outlineView superview] superview] verticalScroller] setFloatValue:0];
[(NSClipView *)[outlineView superview] scrollToPoint:NSMakePoint(0,0)];
	
[self dataPopupChanged:self];
	
loadingBurnFile = NO;		
[self setTotalSize];
}

- (void)loadOutlineItems:(NSArray *)ar originalArray:(NSArray *)orAr
{
loadingBurnFile = YES;
NSMutableArray *subFolders = [[NSMutableArray alloc] init];
NSMutableArray *virtualFolders = [[NSMutableArray alloc] init];
NSIndexSet *selectedItem;

	int i = 0;
	for (i=0;i<[ar count];i++)
	{
		if ([[[ar objectAtIndex:i] objectForKey:@"Path"] isEqualTo:@"isVirtual"])
		{
		[virtualFolders addObject:[ar objectAtIndex:i]];
		}
		else if ([[NSFileManager defaultManager] fileExistsAtPath:[[ar objectAtIndex:i] objectForKey:@"Path"]])
		{
		BOOL isDir;
		id newData = nil;
		
			if ([[NSFileManager defaultManager] fileExistsAtPath:[[ar objectAtIndex:i] objectForKey:@"Path"] isDirectory:&isDir] && isDir)
			{
			KWDRFolder*	realFolder = [[[KWDRFolder alloc] initWithPath:[[ar objectAtIndex:i] objectForKey:@"Path"]] autorelease];
			[self setPropertiesFor:realFolder fromDictionary:[ar objectAtIndex:i]];
			newData = [[FSFolderNodeData alloc] initWithFSObject:realFolder];
			}
			else
			{
			DRFile*	fileObj = [DRFile fileWithPath:[[ar objectAtIndex:i] objectForKey:@"Path"]];
			[self setPropertiesFor:fileObj fromDictionary:[ar objectAtIndex:i]];
			[(FSNodeData*)[treeData nodeData] fsObject];

				if ([[fileObj baseName] isEqualTo:@".VolumeIcon.icns"])
				[(DRFolder *)[(FSNodeData*)[treeData nodeData] fsObject] addChild:fileObj];
				else
				newData = [[FSFileNodeData alloc] initWithFSObject:fileObj];
			}
			if (newData)
			{
			FSTreeNode*	newNode = [FSTreeNode treeNodeWithData:newData];
			[self _addNewDataToSelection:newNode shouldSelect:NO];
			[newData release];
			newData = nil;
			}
		}
	}
	
	selectedItem = [NSIndexSet indexSetWithIndex:[outlineView selectedRow]];
	for (i=0;i<[virtualFolders count];i++)
	{
	[outlineView selectRowIndexes:selectedItem byExtendingSelection:NO];
	[subFolders removeAllObjects];

	KWDRFolder*	folderObj = [[[KWDRFolder alloc] initWithName:[[virtualFolders objectAtIndex:i] objectForKey:@"Group"]] autorelease];
	
	id nodeData = [[FSFolderNodeData alloc] initWithFSObject:[folderObj retain]];
		
		if (nodeData)
		{
		FSTreeNode*	newNode = [FSTreeNode treeNodeWithData:nodeData];
		
		[self _addNewDataToSelection:newNode shouldSelect:YES];
		[nodeData release];

		[self setPropertiesFor:folderObj fromDictionary:[virtualFolders objectAtIndex:i]];
		}
				
		if ([[virtualFolders objectAtIndex:i] objectForKey:@"Entries"])
		{
			int x;
			NSArray *entries = [[virtualFolders objectAtIndex:i] objectForKey:@"Entries"];
			for (x=0;x<[entries count];x++)
			{
				if (![[[entries objectAtIndex:x] objectForKey:@"Path"] isEqualTo:@"isVirtual"])
				{
					BOOL isDir;
					id newData = nil;
					if ([[NSFileManager defaultManager] fileExistsAtPath:[[entries objectAtIndex:x] objectForKey:@"Path"] isDirectory:&isDir])
					{
						if ([[NSFileManager defaultManager] fileExistsAtPath:[[entries objectAtIndex:x] objectForKey:@"Path"] isDirectory:&isDir] && isDir)
						{
						KWDRFolder*	realFolder = [[[KWDRFolder alloc] initWithPath:[[entries objectAtIndex:x] objectForKey:@"Path"]] autorelease];
						[self setPropertiesFor:realFolder fromDictionary:[entries objectAtIndex:x]];
						newData = [[FSFolderNodeData alloc] initWithFSObject:realFolder];
						}
						else
						{
						DRFile*	fileObj = [DRFile fileWithPath:[[entries objectAtIndex:x] objectForKey:@"Path"]];
						[self setPropertiesFor:fileObj fromDictionary:[entries objectAtIndex:x]];
						newData = [[FSFileNodeData alloc] initWithFSObject:fileObj];
						}
						
						if (newData)
						{
						FSTreeNode*	newNode = [FSTreeNode treeNodeWithData:newData];
						[self _addNewDataToSelection:newNode shouldSelect:NO];
						[newData release];
						newData = nil;
						}
					}
				}
				else
				{
				[subFolders addObject:[entries objectAtIndex:x]];
				}
			}
		}
		
		if ([subFolders count] > 0)
		{
		[self loadOutlineItems:subFolders originalArray:ar];
		}
		else
		{
			int y;
			for (y=0;y<[outlineView numberOfRows];y++)
			{
				if ([[NODE_DATA([outlineView itemAtRow:y]) fsObject] isVirtual] && ![(KWDRFolder *)[NODE_DATA([outlineView itemAtRow:y]) fsObject] isExpanded])
				[outlineView collapseItem:[outlineView itemAtRow:y] collapseChildren:YES];
			}
			
		[outlineView deselectAll:self];
		}
	}

[subFolders release];
[virtualFolders release];
}

- (void)saveDocument
{
NSSavePanel *sheet = [NSSavePanel savePanel];
[sheet setRequiredFileType:@"burn"];
[sheet setCanSelectHiddenExtension:YES];
[sheet setMessage:NSLocalizedString(@"Choose a location to save the burn file",@"Localized")];

[sheet beginSheetForDirectory:nil file:[[discName stringValue] stringByAppendingString:@".burn"] modalForWindow:mainWindow modalDelegate:self didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

- (void)savePanelDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
[sheet orderOut:self];

	if (returnCode == NSOKButton) 
	{
	[[self getSaveDictionary] writeToFile:[sheet filename] atomically:YES];
	
		if ([sheet isExtensionHidden])
		[[NSFileManager defaultManager] changeFileAttributes:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:@"NSFileExtensionHidden"] atPath:[sheet filename]];
	}
}

//Make a dictionary to save
- (NSDictionary *)getSaveDictionary
{
NSDictionary *properties = [self saveDictionaryForObject:[(FSNodeData*)[treeData nodeData] fsObject]];
NSMutableDictionary *newProperties = [NSMutableDictionary dictionary];
[newProperties addEntriesFromDictionary:properties];
	
	if (discProperties)
	{
	NSMutableDictionary *tempDict = [NSMutableDictionary dictionary];
	[tempDict addEntriesFromDictionary:discProperties];
	
		if ([discProperties objectForKey:DRCopyrightFile])
		[tempDict setObject:[[discProperties objectForKey:DRCopyrightFile] sourcePath] forKey:DRCopyrightFile];
	
		if ([discProperties objectForKey:DRBibliographicFile])
		[tempDict setObject:[[discProperties objectForKey:DRBibliographicFile] sourcePath] forKey:DRBibliographicFile];

		if ([discProperties objectForKey:DRAbstractFile])
		[tempDict setObject:[[discProperties objectForKey:DRAbstractFile] sourcePath] forKey:DRAbstractFile];
	
	[newProperties setObject:tempDict forKey:@"Disc Properties"];
	}
		
//Get the selected rows and save them
NSIndexSet *rows = [outlineView selectedRowIndexes];
NSMutableArray *selectedRows = [NSMutableArray array];
	
	unsigned current_index = [rows lastIndex];
    while (current_index != NSNotFound)
    {
	[selectedRows addObject:[NSNumber numberWithUnsignedInt:current_index]];
	current_index = [rows indexLessThanIndex: current_index];
    }

NSDictionary *burnFileProperties = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[discName stringValue],[NSDictionary dictionaryWithDictionary:newProperties],[self getFileArray:[(DRFolder *)[(FSNodeData*)[treeData nodeData] fsObject] children]],selectedRows,[NSNumber numberWithFloat:[[(NSScrollView *)[[outlineView superview] superview] verticalScroller] floatValue]],[NSNumber numberWithFloat:[(NSClipView *)[outlineView superview] documentVisibleRect].origin.y],nil] forKeys:[NSArray arrayWithObjects:@"Name",@"Properties",@"Files",@"Selected items",@"Scroll value",@"View x",nil]];

return [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:0],[fileSystemPopup objectValue],[NSArray arrayWithObjects:[hfsSheet objectValue], [isoSheet objectValue], [jolietSheet objectValue], [udfSheet objectValue], [hfsStandardSheet objectValue],nil],burnFileProperties,nil] forKeys:[NSArray arrayWithObjects:@"KWType",@"KWSubType",@"KWDataTypes",@"KWProperties",nil]];
}

//Make a array with the files
- (NSArray *)getFileArray:(NSArray *)items
{
id item;
NSMutableArray *itemsArray = [[NSMutableArray alloc] init];
NSEnumerator *itemEnum = [items objectEnumerator];
	
	while (item = [itemEnum nextObject]) 
	{
       if ([item isVirtual]) 
	   {
		NSMutableDictionary *subDict = [[NSMutableDictionary alloc] init];
		NSArray *children = [item children];
		NSArray *subArray = [NSArray arrayWithArray:[self getFileArray:children]];
		
		[subDict setObject:[item baseName] forKey:@"Group"];
		[subDict setObject:@"isVirtual" forKey:@"Path"];
		[subDict setObject:subArray forKey:@"Entries"];
		[subDict setObject:[item baseName] forKey:@"Base Name"];
		[subDict setObject:[NSNumber numberWithBool:[(KWDRFolder *)item isExpanded]] forKey:@"Expanded"];
		
		[subDict addEntriesFromDictionary:[self saveDictionaryForObject:item]];
		
		[itemsArray addObject:subDict];
		[subDict release];
		}
		else 
		{
		NSMutableDictionary *subDict = [[NSMutableDictionary alloc] init];
		[subDict setObject:[item sourcePath] forKey:@"Path"];
		[subDict setObject:[item baseName] forKey:@"Base Name"];
		[subDict addEntriesFromDictionary:[self saveDictionaryForObject:item]];
		[itemsArray addObject:subDict];
		[subDict release];
		}
	}

return [itemsArray autorelease];
}

- (NSDictionary *)saveDictionaryForObject:(DRFSObject *)object
{
NSMutableDictionary *subDict = [NSMutableDictionary dictionary];

[subDict setObject:[object propertiesForFilesystem:DRHFSPlus mergeWithOtherFilesystems:NO] forKey:@"HFSProperties"];
[subDict setObject:[object propertiesForFilesystem:DRISO9660 mergeWithOtherFilesystems:NO] forKey:@"ISOProperties"];
[subDict setObject:[object propertiesForFilesystem:DRJoliet mergeWithOtherFilesystems:NO] forKey:@"JolietProperties"];
[subDict setObject:[object propertiesForFilesystem:DRAllFilesystems mergeWithOtherFilesystems:NO] forKey:@"AllProperties"];
	if (![KWCommonMethods isPanther])
	[subDict setObject:[object propertiesForFilesystem:DRUDF mergeWithOtherFilesystems:NO] forKey:@"UDFProperties"];
	
[subDict setObject:[object specificNameForFilesystem:DRHFSPlus] forKey:@"HSFSpecificName"];
[subDict setObject:[object specificNameForFilesystem:DRISO9660LevelOne] forKey:@"ISOLevel1SpecificName"];
[subDict setObject:[object specificNameForFilesystem:DRISO9660LevelTwo] forKey:@"ISOLevel2SpecificName"];
[subDict setObject:[object specificNameForFilesystem:DRJoliet] forKey:@"JolietSpecificName"];
	if (![KWCommonMethods isPanther])
	[subDict setObject:[object specificNameForFilesystem:DRUDF] forKey:@"UDFSpecificName"];

[subDict setObject:[NSNumber numberWithBool:([object effectiveFilesystemMask] & DRFilesystemInclusionMaskHFSPlus)] forKey:@"HFSEnabled"];
[subDict setObject:[NSNumber numberWithBool:([object effectiveFilesystemMask] & DRFilesystemInclusionMaskISO9660)] forKey:@"ISOEnabled"];
[subDict setObject:[NSNumber numberWithBool:([object effectiveFilesystemMask] & DRFilesystemInclusionMaskJoliet)] forKey:@"JolietEnabled"];
	if (![KWCommonMethods isPanther])
	[subDict setObject:[NSNumber numberWithBool:([object effectiveFilesystemMask] & DRFilesystemInclusionMaskUDF)] forKey:@"UDFEnabled"];

	if ([object isVirtual])
	{
		if ([(KWDRFolder *)object folderIcon])
		{
		[subDict setObject:[[(KWDRFolder *)object folderIcon] TIFFRepresentation] forKey:@"Folder Icon"];
		}
	}
	
return subDict;
}

- (void)setPropertiesFor:(DRFSObject *)object fromDictionary:(NSDictionary *)dict
{
[object setBaseName:[dict objectForKey:@"Base Name"]];
	
[object setProperties:[dict objectForKey:@"HFSProperties"] inFilesystem:DRHFSPlus];
[object setProperties:[dict objectForKey:@"ISOProperties"] inFilesystem:DRISO9660];
[object setProperties:[dict objectForKey:@"JolietProperties"] inFilesystem:DRJoliet];
[object setProperties:[dict objectForKey:@"AllProperties"] inFilesystem:DRAllFilesystems];
	if (![KWCommonMethods isPanther])
	[object setProperties:[dict objectForKey:@"UDFProperties"] inFilesystem:DRUDF];

[object setSpecificName:[dict objectForKey:@"HSFSpecificName"] forFilesystem:DRHFSPlus];
[object setSpecificName:[dict objectForKey:@"ISOLevel1SpecificName"] forFilesystem:DRISO9660LevelOne];
[object setSpecificName:[dict objectForKey:@"ISOLevel2SpecificName"] forFilesystem:DRISO9660LevelTwo];

[object setSpecificName:[dict objectForKey:@"JolietSpecificName"] forFilesystem:DRJoliet];
	if (![KWCommonMethods isPanther])
	[object setSpecificName:[dict objectForKey:@"UDFSpecificName"] forFilesystem:DRUDF];

	DRFilesystemInclusionMask hfs;
	if ([[dict objectForKey:@"HFSEnabled"] boolValue])
	hfs = DRFilesystemInclusionMaskHFSPlus;
	
	DRFilesystemInclusionMask iso;
	if ([[dict objectForKey:@"ISOEnabled"] boolValue])
	iso = DRFilesystemInclusionMaskISO9660;
	
	DRFilesystemInclusionMask joliet;
	if ([[dict objectForKey:@"JolietEnabled"] boolValue])
	joliet = DRFilesystemInclusionMaskJoliet;
	
	DRFilesystemInclusionMask udf;
	if ([[dict objectForKey:@"UDFEnabled"] boolValue] && ![KWCommonMethods isPanther])
	udf = DRFilesystemInclusionMaskUDF;
	
[object setExplicitFilesystemMask:(hfs | iso | joliet | udf)];

	if ([dict objectForKey:@"Folder Icon"])
	{
	[(KWDRFolder *)object setFolderIcon:[[[NSImage alloc] initWithData:[dict objectForKey:@"Folder Icon"]] autorelease]];
	}
}

///////////////////
// Other actions //
///////////////////

#pragma mark -
#pragma mark •• Other actions

- (void)setDiskName:(NSString *)name
{
[discName setStringValue:name];
}

- (void)discPropertiesChanged:(NSNotification *)notif
{
discProperties = [notif object];
}

- (BOOL)isCompatible
{
	if ([fileSystemPopup selectedItem] == [fileSystemPopup lastItem])
	{
		if ([udfSheet state] == NSOnState && [KWCommonMethods isPanther])
		return NO;
		else if ([hfsStandardSheet state] == NSOnState)
		return NO;
	}
	
return YES;
}

- (BOOL)isCombinable
{
	if (![self hasRows])
	return NO;
	else if (![self isCompatible])
	return NO;
	
return YES;
}

- (BOOL)isOnlyHFSPlus
{
	if ([fileSystemPopup indexOfSelectedItem] == 0)
	return YES;
	else if ([fileSystemPopup selectedItem] == [fileSystemPopup lastItem] && [hfsSheet state] == NSOnState && [udfSheet state] == NSOffState && [isoSheet state] == NSOffState && [jolietSheet state] == NSOffState)
	return YES;
	
return NO;
}

/*- (NSString *)getHFSStandardCompatibleName:(NSString *)origName
{
NSString *pathExtension;

	if ([[origName pathExtension] isEqualTo:@""])
	pathExtension = @"";
	else
	pathExtension = [@"." stringByAppendingString:[origName pathExtension]];

	if ([origName length] > 31)
	{
		NSString *pathExtension;

		if ([[origName pathExtension] isEqualTo:@""])
		pathExtension = @"";
		else
		pathExtension = [@"." stringByAppendingString:[origName pathExtension]];

	
	unsigned int fileLength = 31 - [pathExtension length];

	return [[origName substringWithRange:NSMakeRange(0,fileLength)] stringByAppendingString:pathExtension];
	}
	else
	{
	return origName;
	}
}*/

- (BOOL)isHFSStandardSupportedFile:(NSString *)file
{
	if ([[[file lastPathComponent] substringWithRange:NSMakeRange(0,1)] isEqualTo:@"."])
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

///////////////////////
// Outside variables //
///////////////////////

#pragma mark -
#pragma mark •• Outside variables

- (NSWindow*) window 
{
return mainWindow;
}

- (NSArray*) rootFiles
{
NSEnumerator*	iter = [[treeData children] objectEnumerator];
TreeNode*		child;
NSMutableArray*	rootFiles = [NSMutableArray arrayWithCapacity:1];
	
	while ((child = [iter nextObject]) != NULL)
	{
	// A cheap (but somewhat lame) way of identifing a file is to check to see if it's expandable.
	// If not, it's a file.
	if ([NODE_DATA(child) isExpandable] == NO)
	{
	[rootFiles addObject:child];
	}
}
	
return [[rootFiles copy] autorelease];
}

- (KWDRFolder*) filesystemRoot
{
return (KWDRFolder*)[NODE_DATA(treeData) fsObject];
}

///////////////////////
// Inspector actions //
///////////////////////

#pragma mark -
#pragma mark •• Inspector actions

- (void)volumeLabelSelected:(NSNotification *)notif
{
[self updateFileSystem];

	if ([self isCompatible])
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWChangeInspector" object:[(FSNodeData*)[treeData nodeData] fsObject] userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"KWDataDisc",@"Type",nil]];
	else
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWChangeInspector" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"KWEmpty",@"Type",nil]];
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{
NSArray* selectedNodes = [outlineView allSelectedItems];
TreeNode* selectedNode = ([selectedNodes count] ? [selectedNodes objectAtIndex:0] : treeData);

	if ([self isCompatible])
	{
		if (selectedNode == treeData)
		[[NSNotificationCenter defaultCenter] postNotificationName:@"KWChangeInspector" object:[(FSNodeData*)[treeData nodeData] fsObject] userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"KWDataDisc",@"Type",nil]];
		else
		[[NSNotificationCenter defaultCenter] postNotificationName:@"KWChangeInspector" object:[[self selectedDRFSObjects] retain] userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"KWData",@"Type",nil]];
	}
	else
	{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWChangeInspector" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"KWEmpty",@"Type",nil]];
	}
}

- (NSArray *)selectedDRFSObjects
{
NSArray* selectedNodes = [outlineView allSelectedItems];
NSMutableArray *objects = [NSMutableArray array];

	int x;
	for (x=0;x<[selectedNodes count];x++)
	{
	[objects addObject:[NODE_DATA((TreeNode *)[selectedNodes objectAtIndex:x]) fsObject]];
	}

return objects;
}

/////////////////////
// Outline actions //
/////////////////////

#pragma mark -
#pragma mark •• Outline actions

- (void)reloadOutlineView
{
[outlineView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:YES];
}

- (void)setOutlineViewState:(NSNotification *)notif
{
	if ([[notif object] boolValue] == YES)
	[outlineView registerForDraggedTypes:[NSArray arrayWithObjects:EDBFileTreeDragPboardType, NSFilenamesPboardType,@"CorePasteboardFlavorType 0x6974756E", nil]];
	else
	[outlineView unregisterDraggedTypes];
}

- (IBAction)outlineViewAction:(id)sender
{
[[NSNotificationCenter defaultCenter] postNotificationName:EDBSelectionChangedNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[outlineView allSelectedItems], EDBCurrentSelection, nil]];
}

-(BOOL)hasRows
{
	if ([outlineView numberOfRows] > 0)
	return YES;
	else
	return NO;
}

- (NSArray*)draggedNodes
{
return draggedNodes;
}

// Required methods.
- (id)outlineView:(NSOutlineView *)olv child:(int)index ofItem:(id)item 
{
    return [SAFENODE(item) childAtIndex:index];
}

- (BOOL)outlineView:(NSOutlineView *)olv isItemExpandable:(id)item 
{
    return [NODE_DATA(item) isExpandable];
}

- (int)outlineView:(NSOutlineView *)olv numberOfChildrenOfItem:(id)item 
{
    return [SAFENODE(item) numberOfChildren];
}

- (id)outlineView:(NSOutlineView *)olv objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item 
{
	return [NODE_DATA(item) valueForKey:[tableColumn identifier]];
}

- (void)outlineView:(NSOutlineView *)olv setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
//Set the new name
	if (![[NODE_DATA((TreeNode *)[[outlineView allSelectedItems] objectAtIndex:0]) name] isEqualTo:object])
	[NODE_DATA((TreeNode *)[[outlineView allSelectedItems] objectAtIndex:0]) setName:object];
}

// We need to make sure that we make a real folder virtual if
// it's about to be expanded.
- (void)outlineViewItemWillExpand:(NSNotification *)notification;
{
id	item = SAFENODE([[notification userInfo] objectForKey:@"NSObject"]);
[item children];
[(KWDRFolder *)[NODE_DATA(item) fsObject] setExpanded:YES];
}

- (BOOL)outlineView:(NSOutlineView *)olv shouldExpandItem:(id)item 
{
    return [NODE_DATA(item) isExpandable];
}

- (void)outlineView:(NSOutlineView *)olv willDisplayCell:(NSCell *)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item 
{    
    if ([[tableColumn identifier] isEqualToString: COLUMNID_NAME]) 
	{
	[(ImageAndTextCell*)cell setImage:[NODE_DATA(item) icon]];
	}
}

- (BOOL)outlineView:(NSOutlineView *)olv writeItems:(NSArray*)items toPasteboard:(NSPasteboard*)pboard 
{
draggedNodes = items; // Don't retain since this is just holding temporaral drag information, and it is only used during a drag!  We could put this in the pboard actually.

// Provide data for our custom type, and simple NSStrings.
[pboard declareTypes:[NSArray arrayWithObjects: EDBFileTreeDragPboardType, NSStringPboardType, nil] owner:self];

// the actual data doesn't matter since EDBFileTreeDragPboardType drags aren't recognized by anyone but us!.
[pboard setData:[NSData data] forType:EDBFileTreeDragPboardType]; 

// Put string data on the pboard... notice you can drag into TextEdit!
[pboard setString:[draggedNodes description] forType: NSStringPboardType];

return YES;
}

- (unsigned int)outlineView:(NSOutlineView*)olv validateDrop:(id <NSDraggingInfo>)info proposedItem:(id)item proposedChildIndex:(int)childIndex 
{
    // This method validates whether or not the proposal is a valid one. Returns NO if the drop should not be allowed.
    TreeNode *target = item;
    BOOL targetIsValid = YES;
	
	// Check to make sure we don't allow a node to be inserted into one of its descendants!
	if ([info draggingSource] == outlineView && 
		[[info draggingPasteboard] availableTypeFromArray:[NSArray arrayWithObject:EDBFileTreeDragPboardType]] != nil) 
	{
	    NSArray *_draggedNodes = [[[info draggingSource] dataSource] draggedNodes];
	    targetIsValid = ![target isDescendantOfNodeInArray: _draggedNodes];
	}

	if (targetIsValid)
	{
		if ([NODE_DATA(target) isExpandable] == NO)
		{
			target = [target nodeParent];
		}
		
		if (target == treeData)
		{
			target = nil;
		}
		[outlineView setDropItem:target dropChildIndex:NSOutlineViewDropOnItemIndex];
	}
	
    return targetIsValid ? NSDragOperationGeneric : NSDragOperationNone;
}

- (void)_performDropOperation:(id <NSDraggingInfo>)info ontoItem:(TreeNode*)parent 
{
    // Helper method to insert dropped data into the model. 
    NSPasteboard*	pboard = [info draggingPasteboard];
    NSMutableArray*	itemsToSelect = nil;
    
    // Do the appropriate thing depending on whether the data is EDBFileTreeDragPboardType or NSStringPboardType.
    if ([pboard availableTypeFromArray:[NSArray arrayWithObjects:EDBFileTreeDragPboardType, nil]] != nil) 
	{
        dataController *dragDataSource = [[info draggingSource] dataSource];
        NSArray *_draggedNodes = [TreeNode minimumNodeCoverFromNodesInArray: [dragDataSource draggedNodes]];
        NSEnumerator *iter = [_draggedNodes objectEnumerator];
        TreeNode *_draggedNode = nil;
        
		itemsToSelect = [NSMutableArray arrayWithArray:[outlineView allSelectedItems]];
	
        while ((_draggedNode = [iter nextObject]) != nil) 
		{
		NSAutoreleasePool *subPool = [[NSAutoreleasePool alloc] init];
		
			int x;
			BOOL nameExists = NO;
			for (x=0;x<[[parent children] count];x++)
			{
			NSAutoreleasePool *subPool = [[NSAutoreleasePool alloc] init];
			
				if ([[[(FSNodeData *)[[[parent children] objectAtIndex:x] nodeData] fsObject] baseName] isEqualTo:[[(FSNodeData *)[_draggedNode nodeData] fsObject] baseName]])
				nameExists = YES;
				
			[subPool release];
			}
		
			if (nameExists == NO)
			{
			[_draggedNode removeFromParent];
			[parent addChild:_draggedNode];
			}
        
		[subPool release];
		}
    }
	else if ([pboard availableTypeFromArray:[NSArray arrayWithObjects:NSFilenamesPboardType, nil]] != nil) 
	{
		NSArray* 		paths = [pboard propertyListForType:NSFilenamesPboardType];
		NSEnumerator*	iter = [paths objectEnumerator];
		NSString*		path;
		
		itemsToSelect = [NSMutableArray arrayWithArray:[outlineView allSelectedItems]];

		while ((path = [iter nextObject]) != NULL)
		{
		NSAutoreleasePool *subPool = [[NSAutoreleasePool alloc] init];
		
		id nodeData = [FSNodeData nodeDataWithPath:path];
		FSTreeNode*	newNode = [FSTreeNode treeNodeWithData:nodeData];
		
			int x;
			BOOL nameExists = NO;
			for (x=0;x<[[parent children] count];x++)
			{
			NSAutoreleasePool *subPool = [[NSAutoreleasePool alloc] init];
			
				if ([[[(FSNodeData *)[[[parent children] objectAtIndex:x] nodeData] fsObject] baseName] isEqualTo:[path lastPathComponent]])
				nameExists = YES;
			
			[subPool release];
			}
		
			if (nodeData)
			{
				if (nameExists == NO)
				{
				[parent addChild:newNode];
				}
			}
		
		[subPool release];
		}
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
		
	NSArray* 		paths = [fileList copy];
	NSEnumerator*	iter = [paths objectEnumerator];
	NSString*		path;
		
	itemsToSelect = [NSMutableArray arrayWithArray:[outlineView allSelectedItems]];

		while ((path = [iter nextObject]) != NULL)
		{
			id nodeData = [FSNodeData nodeDataWithPath:path];
			FSTreeNode*	newNode = [FSTreeNode treeNodeWithData:nodeData];
			
			int x;
			BOOL nameExists = NO;
			for (x=0;x<[[parent children] count];x++)
			{
				if ([[[(FSNodeData *)[[[parent children] objectAtIndex:x] nodeData] fsObject] baseName] isEqualTo:[path lastPathComponent]])
				nameExists = YES;
			}
			
			if (nodeData && nameExists == NO)
			{
			[parent addChild:newNode];
			}
		}
	}

    [outlineView reloadData];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWChangeBurnStatus" object:[NSNumber numberWithBool:([outlineView numberOfRows] > 0)]];
	
    [outlineView selectItems: itemsToSelect byExtendingSelection: NO];
	
	[self setTotalSize];
}

- (BOOL)outlineView:(NSOutlineView*)olv acceptDrop:(id <NSDraggingInfo>)info item:(id)targetItem childIndex:(int)childIndex 
{
    TreeNode* 		dropParent = nil;
    
    // Determine the parent to insert into and the child index to insert at.
    if ([NODE_DATA(targetItem) isExpandable] == NO) 
	{
        dropParent = (TreeNode*)(childIndex == NSOutlineViewDropOnItemIndex ? [targetItem nodeParent] : targetItem);
    } 
	else
	{            
        dropParent = targetItem;
    }
    
    [self _performDropOperation:info ontoItem:SAFENODE(dropParent)];

    return YES;
}

@end

@implementation dataController (Private)

- (void)_addNewDataToSelection:(TreeNode *)newChild shouldSelect:(BOOL)boolean
{
int			newRow = 0;
NSArray*	selectedNodes = [outlineView allSelectedItems];
TreeNode*	selectedNode = ([selectedNodes count] ? [selectedNodes objectAtIndex:0] : treeData);
TreeNode*	parentNode = nil;
		
	if ([NODE_DATA(selectedNode) isExpandable]) 
	{ 
	parentNode = selectedNode;
    }
    else 
	{ 
	parentNode = [selectedNode nodeParent]; 
		
	[outlineView expandItem:parentNode];
    }
 
[parentNode addChild:newChild];
[outlineView reloadData];
	
[[NSNotificationCenter defaultCenter] postNotificationName:@"KWChangeBurnStatus" object:[NSNumber numberWithBool:([outlineView numberOfRows] > 0)]];
	
[self setTotalSize];
	
newRow = [outlineView rowForItem:newChild];

		if (boolean)
		{
		[outlineView selectRow:newRow byExtendingSelection:NO];
		[outlineView scrollRowToVisible:newRow];
		[outlineView expandItem:[outlineView itemAtRow:newRow]];
		}
}

@end
