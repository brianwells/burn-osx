#import "KWDataController.h"
#import "FSTreeNode.h"
#import "ImageAndTextCell.h"
#import "NSArray_Extensions.h"
#import "NSOutlineView_Extensions.h"
#import <DiscRecording/DiscRecording.h>
#import "KWWindowController.h"
#import "KWCommonMethods.h"
#import "KWDiscCreator.h"
#import "KWTextField.h"

@interface KWDataController (Private)

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

@implementation KWDataController

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

		mainFilesystems = [[NSArray alloc] initWithObjects:		[NSNumber numberWithUnsignedInt:DRFilesystemInclusionMaskHFSPlus],
																[NSNumber numberWithUnsignedInt:DRFilesystemInclusionMaskJoliet],
																[NSNumber numberWithUnsignedInt:(DRFilesystemInclusionMaskHFSPlus | DRFilesystemInclusionMaskJoliet | DRFilesystemInclusionMaskISO9660)],
																[NSNumber numberWithUnsignedInt:1<<2],
																nil];
		
		advancedFilesystems = [[NSArray alloc] initWithObjects:	[NSNumber numberWithUnsignedInt:DRFilesystemInclusionMaskHFSPlus],
																[NSNumber numberWithUnsignedInt:DRFilesystemInclusionMaskISO9660],
																[NSNumber numberWithUnsignedInt:DRFilesystemInclusionMaskJoliet],
																[NSNumber numberWithUnsignedInt:1<<2],
																[NSNumber numberWithUnsignedInt:(1<<4)],
																nil];
	
		//Root folder of the disc
		KWDRFolder*	folderObj = [[[KWDRFolder alloc] initWithName:NSLocalizedString(@"Untitled", Localized)] autorelease];
		//Put our rootfolder in de noteData from our outlineview
		FSNodeData*	nodeData = [[[FSFolderNodeData alloc] initWithFSObject:folderObj] autorelease];;
		
		// Set the eplicit mask for the root object. This make sure that all items added to it
		// get the correct filesystem mask inherited from the root. If we didn't set this here
		// we'd need to worry about possible changes to how the default mask value is interpreted
		// in different versions of the framework.
	
		[folderObj setExplicitFilesystemMask: (DRFilesystemInclusionMaskISO9660 | DRFilesystemInclusionMaskJoliet | DRFilesystemInclusionMaskHFSPlus | 1<<2)];
		
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
	[temporaryFiles release];
	[lastSelectedItem release];
	[optionsMappings release];
	[mainFilesystems release];

	//Release disc properties if needed
	if (discProperties)
		[discProperties release];

	[super dealloc];
}

- (void)awakeFromNib 
{
	//Set a nice generic CD image
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
	[self setupAdvancedSheet];
	
	//Set preferences
	[fileSystemPopup selectItemAtIndex:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultDataType"] intValue]];
	lastSelectedItem = [[fileSystemPopup title] retain];
	[self updateFileSystem];
	
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

	if ([KWCommonMethods OSVersion] < 0x1040)
	{
		[fileSystemPopup removeItemAtIndex:3];
		[[advancedCheckboxes cellAtRow:3 column:0] setTitle:NSLocalizedString(@"UDF / ISO9660 (only)",nil)];
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
		[self addFiles:[panel filenames] removeFiles:NO];
}

- (void)addDroppedOnIconFiles:(NSArray *)paths
{
	if ([paths count] == 1 && [outlineView numberOfRows] == 0)
	{
		NSString *path = [paths objectAtIndex:0];
		NSFileManager *defaultManager = [NSFileManager defaultManager];
		
		BOOL isDir;
		if ([defaultManager fileExistsAtPath:path isDirectory:&isDir])
		{
			if (isDir == YES)
			{
				[self setDiskName:[path lastPathComponent]];
				
				NSArray *files = [defaultManager directoryContentsAtPath:path];
				NSMutableArray *fulPaths = [NSMutableArray array];
				
				int i = 0;
				for (i=0;i<[files count];i++)
				{
					[fulPaths addObject:[path stringByAppendingPathComponent:[files objectAtIndex:i]]];
				}
					
				[self addFiles:fulPaths removeFiles:YES];
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
}

- (IBAction)deleteFiles:(id)sender
{
	NSArray *selection = [outlineView allSelectedItems];
	NSMutableArray *icons = [NSMutableArray array];
	
	[outlineView abortEditing];
  
	int x;
	for (x=0;x<[selection count];x++)
	{
		NSAutoreleasePool *subPool = [[NSAutoreleasePool alloc] init];
		TreeNode *selectedItem = [selection objectAtIndex:x];
	
		if ([[[NODE_DATA(selectedItem) fsObject] baseName] isEqualTo:@"Icon\r"])
			[icons addObject:selectedItem];
		else
			[selectedItem removeFromParent];
		
		[subPool release];
	}
	
	for (x=0;x<[icons count];x++)
	{
		[[icons objectAtIndex:x] removeFromParent];
	}
	
	[selection makeObjectsPerformSelector: @selector(removeFromParent)];
	[outlineView deselectAll:nil];
	[outlineView reloadData];
}

- (void)setTotalSize
{
	NSString *string;

	if (![totalSizeText isHidden] && loadingBurnFile == NO)
	{
		string = [NSString stringWithFormat:NSLocalizedString(@"Total size: %@", nil), [KWCommonMethods makeSizeFromFloat:[self totalSize] * 2048]];
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
	[rootFolder setHfsStandard:NO];

	if ([fileSystemPopup selectedItem] != [fileSystemPopup lastItem])
	{
		[rootFolder setExplicitFilesystemMask:[[mainFilesystems objectAtIndex:[fileSystemPopup indexOfSelectedItem]] unsignedIntValue]];
	}
	else
	{
		DRFilesystemInclusionMask mask = 0;
		
		if ([[advancedCheckboxes cellAtRow:4 column:0] state] == NSOnState)
		{
			mask = (mask | 1<<4);
		}
		else if ([[advancedCheckboxes cellAtRow:3 column:0] state] == NSOnState && [KWCommonMethods OSVersion] < 0x1040)
		{
			mask = (mask | 1<<2);
		}
		else
		{
			int i;
			for (i=0;i<[advancedCheckboxes numberOfRows] - 1;i++)
			{
				NSNumber *filesystemMask = [advancedFilesystems objectAtIndex:i];
				id control = [advancedCheckboxes cellAtRow:i column:0];
			
				if ([control state] == NSOnState)
					mask = (mask | [filesystemMask unsignedIntValue]);
			}
		}
		
		[rootFolder setExplicitFilesystemMask:mask];
	}
	
	if ([rootFolder explicitFilesystemMask] == DRFilesystemInclusionMaskISO9660)
	{
		[discName setStringValue:[[(FSNodeData*)[treeData nodeData] fsObject] mangledNameForFilesystem:DRISO9660LevelTwo]];
	}
	else
	{
		int discNameLength = [KWCommonMethods maxLabelLength:rootFolder];
		NSString *baseName = [rootFolder baseName];

		if ([baseName length] > discNameLength)
			[discName setStringValue:[baseName substringWithRange:NSMakeRange(0, discNameLength)]];
		else
			[discName setStringValue:baseName];
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
	
		[totalSizeText setHidden:![[NSUserDefaults standardUserDefaults] boolForKey:@"KWCalculateTotalSize"]];

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
		NSMutableArray *saveFilesystems = [NSMutableArray array];
	
		int i;
		for (i=0;i<[advancedCheckboxes numberOfRows];i++)
		{
			NSNumber *filesystemMask = [advancedFilesystems objectAtIndex:i];
			id control = [advancedCheckboxes cellAtRow:i column:0];
			
			if ([control state] == NSOnState)
				[saveFilesystems addObject:filesystemMask];
		}
	
		[[NSUserDefaults standardUserDefaults] setObject:saveFilesystems forKey:@"KWAdvancedFilesystems"];
		
		[self dataPopupChanged:okSheet];
	}
	else
	{
		[self setupAdvancedSheet];
		[fileSystemPopup selectItemWithTitle:lastSelectedItem];
	}
}

- (IBAction)changeBaseName:(id)sender
{
	KWDRFolder *rootFolder = (KWDRFolder*)[(FSNodeData*)[treeData nodeData] fsObject];

	if ([rootFolder explicitFilesystemMask] == DRFilesystemInclusionMaskISO9660)
	{
		if (![[[sender stringValue] lowercaseString] isEqualTo:[[rootFolder baseName] lowercaseString]])
		{
			[rootFolder setBaseName:[sender stringValue]];
			[sender setStringValue:[rootFolder mangledNameForFilesystem:DRISO9660LevelTwo]];
		}
	}
	else
	{
		if (![[sender stringValue] isEqualTo:[rootFolder baseName]])
			[rootFolder setBaseName:[sender stringValue]];
	}
	
	if ([self isCompatible])
		[[NSNotificationCenter defaultCenter] postNotificationName:@"KWChangeInspector" object:[(FSNodeData*)[treeData nodeData] fsObject] userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"KWDataDisc",@"Type",nil]];
	else
		[[NSNotificationCenter defaultCenter] postNotificationName:@"KWChangeInspector" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"KWEmpty",@"Type",nil]];
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

	if ([optionsPopup indexOfItem:sender] == 4)
		[totalSizeText setHidden:([sender state] == NSOnState)];
	else
		[self reloadOutlineView];
}

//////////////////////////////
// New Folder Sheet actions //
//////////////////////////////

#pragma mark -
#pragma mark •• New Folder Sheet actions

- (IBAction)newVirtualFolder:(id)sender 
{	
	KWDRFolder*	folderObj = [[[KWDRFolder alloc] initWithName:NSLocalizedString(@"Untitled Folder",nil)] autorelease];
	[folderObj setFolderSize:[NSString localizedStringWithFormat: @"%.0f KB", 0]];
	
	id nodeData = [[FSFolderNodeData alloc] initWithFSObject:folderObj];
	if (nodeData)
	{
		id currentItem = [outlineView itemAtRow:[outlineView selectedRow]];
			
			if (![outlineView isItemExpanded:currentItem])
			{
				int parentRow = [outlineView rowForItem:[currentItem nodeParent]];
				
				if (parentRow == -1)
					[outlineView deselectAll:self];
				else
					[outlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:parentRow] byExtendingSelection:NO];
			}
	
		FSTreeNode*	newNode = [FSTreeNode treeNodeWithData:nodeData];
		[self _addNewDataToSelection:newNode shouldSelect:YES];
		[nodeData release];
			
		[outlineView collapseItem:[outlineView itemAtRow:[outlineView selectedRow]]];
		[outlineView editColumn:0 row:[outlineView selectedRow] withEvent:nil select:YES];
	}
}

////////////////////////////
// Advanced Sheet actions //
////////////////////////////

#pragma mark -
#pragma mark •• Advanced Sheet actions

- (IBAction)filesystemSelectionChanged:(id)sender
{
	BOOL pantherUDF = [[advancedCheckboxes cellAtRow:3 column:0] state] == NSOnState && [KWCommonMethods OSVersion] < 0x1040;
	BOOL hfsStandard = [[advancedCheckboxes cellAtRow:4 column:0] state] == NSOnState;
	BOOL oneSelected = NO;
	
	int i = 0;
	for (i=0;i<[advancedCheckboxes numberOfRows];i++)
	{
		id control = [advancedCheckboxes cellAtRow:i column:0];
		
		if ([control state] == NSOnState)
			oneSelected = YES;
					
		if ((pantherUDF && (i < 3 | i > 3)) | (hfsStandard && i < 4))
			[control setEnabled:NO];
		else
			[control setEnabled:YES];
	}
	
	[okSheet setEnabled:oneSelected];
}

- (IBAction)okSheet:(id)sender
{
	[NSApp endSheet:advancedSheet returnCode:NSOKButton];
}

- (IBAction)cancelSheet:(id)sender
{
	[NSApp endSheet:advancedSheet returnCode:NSCancelButton];
}


- (void)setupAdvancedSheet
{
	//Set advanced sheet file systems
	NSArray *sheetFilesystems = [[NSUserDefaults standardUserDefaults] objectForKey:@"KWAdvancedFilesystems"];
	
	int i = 0;
	for (i=0;i<[advancedCheckboxes numberOfRows];i++)
	{
		id control = [advancedCheckboxes cellAtRow:i column:0];
		NSNumber *filesystemMask = [advancedFilesystems objectAtIndex:i];
			
		if ([sheetFilesystems containsObject:filesystemMask])
			[control setState:NSOnState];
		else
			[control setState:NSOffState];
	}
	
	[self filesystemSelectionChanged:self];
}

///////////////////////////
// Disc creation actions //
///////////////////////////

#pragma mark -
#pragma mark •• Disc creation actions

- (void)burn:(id)sender
{
	[myDiscCreationController burnDiscWithName:[discName stringValue] withType:0];
}

- (void)saveImage:(id)sender
{
	[myDiscCreationController saveImageWithName:[discName stringValue] withType:0 withFileSystem:@""];
}

- (id)myTrackWithErrorString:(NSString **)error
{
	KWDRFolder *rootFolder = (KWDRFolder*)[(FSNodeData*)[treeData nodeData] fsObject];

	if ([rootFolder explicitFilesystemMask] == 1<<4 | ([rootFolder explicitFilesystemMask] == 1<<2 && [KWCommonMethods OSVersion] < 0x1040))
	{
		NSString *outputFolder = [KWCommonMethods temporaryLocation:[discName stringValue] saveDescription:NSLocalizedString(@"Choose a location to save a temporary folder",nil)];
		
		if (outputFolder)
		{
			[temporaryFiles addObject:outputFolder];
			
			if (![KWCommonMethods createDirectoryAtPath:outputFolder errorString:&*error])
				return [NSNumber numberWithInt:1];
			
			if (![self createVirtualFolder:[SAFENODE(treeData) children] atPath:outputFolder errorString:&*error])
				return [NSNumber numberWithInt:1];
			
			int type = 2;
			
			if ([rootFolder explicitFilesystemMask] == 1<<4)
				type = 1;
	
			return [[KWTrackProducer alloc] getTrackForFolder:outputFolder ofType:type withDiscName:[discName stringValue]];
		}
		else
		{
			return [NSNumber numberWithInt:2];
		}
	}

	return rootFolder;
}

- (BOOL)createVirtualFolder:(NSArray *)items atPath:(NSString *)path errorString:(NSString **)error
{
	id item;

	NSEnumerator *itemEnum = [items objectEnumerator];
	NSFileManager *defaultManager = [NSFileManager defaultManager];
	
	while (item = [itemEnum nextObject]) 
	{
		if ([NODE_DATA(item) isExpandable] && [[NODE_DATA(item) fsObject] isVirtual]) 
		{
			NSString *fileName = [NODE_DATA(item) name];
			NSString *savePath = [KWCommonMethods uniquePathNameFromPath:[path stringByAppendingPathComponent:fileName]];
			
			if (![KWCommonMethods createDirectoryAtPath:savePath errorString:&*error])
				return NO;
				
			NSArray *children = [SAFENODE(item) children];
		
			if (![self createVirtualFolder:children atPath:savePath errorString:&*error])
				return NO;
		}
		else 
		{
			NSString *file = [[NODE_DATA(item) fsObject] sourcePath];
			NSDirectoryEnumerator *enumer;
			NSString *pathName;
			
			BOOL fileIsFolder = NO;
	
			[defaultManager fileExistsAtPath:file isDirectory:&fileIsFolder];
			
			NSString *saveFileName = [[NODE_DATA(item) fsObject] baseName];
			NSString *savePath = [KWCommonMethods uniquePathNameFromPath:[path stringByAppendingPathComponent:saveFileName]];
				
			if (![KWCommonMethods createSymbolicLinkAtPath:savePath withDestinationPath:file errorString:&*error] && fileIsFolder)
			{
				NSString *saveFileName = [[NODE_DATA(item) fsObject] baseName];
				NSString *savePath = [KWCommonMethods uniquePathNameFromPath:[path stringByAppendingPathComponent:saveFileName]];
			
				if (![KWCommonMethods createDirectoryAtPath:savePath errorString:&*error])
					return NO;
					
				enumer = [defaultManager enumeratorAtPath:file];
				while (pathName = [enumer nextObject])
				{
					[defaultManager fileExistsAtPath:[file stringByAppendingPathComponent:pathName] isDirectory:&fileIsFolder];
					
					NSString *savePathName = [pathName lastPathComponent];
					NSString *savePath = [KWCommonMethods uniquePathNameFromPath:[path stringByAppendingPathComponent:[[saveFileName stringByAppendingPathComponent:[pathName stringByDeletingLastPathComponent]] stringByAppendingPathComponent:savePathName]]];

					if (![KWCommonMethods createSymbolicLinkAtPath:savePath withDestinationPath:[file stringByAppendingPathComponent:pathName] errorString:&*error] && fileIsFolder)
					{
						NSString *savePathName = [pathName lastPathComponent];
						NSString *savePath = [KWCommonMethods uniquePathNameFromPath:[path stringByAppendingPathComponent:[[saveFileName stringByAppendingPathComponent:[pathName stringByDeletingLastPathComponent]] stringByAppendingPathComponent:savePathName]]];
			
						if (![KWCommonMethods createDirectoryAtPath:savePath errorString:&*error])
							return NO;
					}
					else
					{
						#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_4
						if ([[[file stringByAppendingPathComponent:pathName] lastPathComponent] isEqualTo:@"Icon\r"])
						{
							if ([KWCommonMethods OSVersion] >= 0x1040)
								[[NSWorkspace sharedWorkspace] setIcon:[[NSWorkspace sharedWorkspace] iconForFile:[[file stringByAppendingPathComponent:pathName] stringByDeletingLastPathComponent]] forFile:[[path stringByAppendingPathComponent:[[file lastPathComponent] stringByAppendingPathComponent:pathName]] stringByDeletingLastPathComponent] options:1 << 2];
						}
						#endif
					}
				}
			}
		}
	}
	
	return YES;
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
	[[NSUserDefaults standardUserDefaults] setObject:advancedStates forKey:@"KWAdvancedFilesystems"];
	[self setupAdvancedSheet];

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
				if ([[NODE_DATA([outlineView itemAtRow:y]) fsObject] isVirtual] && [(KWDRFolder *)[NODE_DATA([outlineView itemAtRow:y]) fsObject] isExpanded])
					[outlineView collapseItem:[outlineView itemAtRow:y] collapseChildren:YES];
			}
			
			[outlineView deselectAll:self];
		}
	}

	[subFolders release];
	[virtualFolders release];
}

- (void)saveDocument:(id)sender
{
	NSSavePanel *sheet = [NSSavePanel savePanel];
	[sheet setRequiredFileType:@"burn"];
	[sheet setCanSelectHiddenExtension:YES];
	[sheet setMessage:NSLocalizedString(@"Choose a location to save the burn file",nil)];

	[sheet beginSheetForDirectory:nil file:[[discName stringValue] stringByAppendingString:@".burn"] modalForWindow:mainWindow modalDelegate:self didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

- (void)savePanelDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[sheet orderOut:self];

	if (returnCode == NSOKButton) 
	{
		NSDictionary *burnFile = [self getSaveDictionary];
		NSString *errorString;
		
		if ([KWCommonMethods writeDictionary:burnFile toFile:[sheet filename] errorString:&errorString])
		{	
			if ([sheet isExtensionHidden])
				[[NSFileManager defaultManager] changeFileAttributes:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:@"NSFileExtensionHidden"] atPath:[sheet filename]];
		}
		else
		{
			[KWCommonMethods standardAlertWithMessageText:NSLocalizedString(@"Failed to save Burn file",nil) withInformationText:errorString withParentWindow:mainWindow];
		}
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

	NSDictionary *burnFileProperties = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[discName stringValue],[NSDictionary dictionaryWithDictionary:newProperties],[self getFileArray:[(DRFolder *)[(FSNodeData*)[treeData nodeData] fsObject] children]],nil] forKeys:[NSArray arrayWithObjects:@"Name",@"Properties",@"Files",nil]];
	NSArray *sheetFilesystems = [[NSUserDefaults standardUserDefaults] objectForKey:@"KWAdvancedFilesystems"];
	
	return [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:0],[fileSystemPopup objectValue],sheetFilesystems,burnFileProperties,nil] forKeys:[NSArray arrayWithObjects:@"KWType",@"KWSubType",@"KWDataTypes",@"KWProperties",nil]];
}

//Make a array with the files
- (NSArray *)getFileArray:(NSArray *)items
{
	id item;
	NSMutableArray *itemsArray = [[NSMutableArray alloc] init];
	NSEnumerator *itemEnum = [items objectEnumerator];
	
	while (item = [itemEnum nextObject]) 
	{
		NSMutableDictionary *subDict = [[NSMutableDictionary alloc] init];
		[subDict setObject:[item baseName] forKey:@"Base Name"];
	
       if ([item isVirtual]) 
	   {
			NSArray *children = [item children];
			NSArray *subArray = [NSArray arrayWithArray:[self getFileArray:children]];
		
			[subDict setObject:[item baseName] forKey:@"Group"];
			[subDict setObject:@"isVirtual" forKey:@"Path"];
			[subDict setObject:subArray forKey:@"Entries"];
			[subDict setObject:[NSNumber numberWithBool:[(KWDRFolder *)item isExpanded]] forKey:@"Expanded"];
		}
		else 
		{
			[subDict setObject:[item sourcePath] forKey:@"Path"];
		}
		
		[subDict addEntriesFromDictionary:[self saveDictionaryForObject:item]];
		[itemsArray addObject:subDict];
		[subDict release];
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
	
	[subDict setObject:[object specificNameForFilesystem:DRHFSPlus] forKey:@"HSFSpecificName"];
	[subDict setObject:[object specificNameForFilesystem:DRISO9660LevelOne] forKey:@"ISOLevel1SpecificName"];
	[subDict setObject:[object specificNameForFilesystem:DRISO9660LevelTwo] forKey:@"ISOLevel2SpecificName"];
	[subDict setObject:[object specificNameForFilesystem:DRJoliet] forKey:@"JolietSpecificName"];	

	[subDict setObject:[NSNumber numberWithBool:([object effectiveFilesystemMask] & DRFilesystemInclusionMaskHFSPlus)] forKey:@"HFSEnabled"];
	[subDict setObject:[NSNumber numberWithBool:([object effectiveFilesystemMask] & DRFilesystemInclusionMaskISO9660)] forKey:@"ISOEnabled"];
	[subDict setObject:[NSNumber numberWithBool:([object effectiveFilesystemMask] & DRFilesystemInclusionMaskJoliet)] forKey:@"JolietEnabled"];	
	
	NSString *fileSystem;
	
	if ([KWCommonMethods OSVersion] >= 0x1040)
		fileSystem = @"DRUDF";
	else
		fileSystem = DRJoliet;
	
	[subDict setObject:[object propertiesForFilesystem:fileSystem mergeWithOtherFilesystems:NO] forKey:@"UDFProperties"];
	[subDict setObject:[object specificNameForFilesystem:fileSystem] forKey:@"UDFSpecificName"];
	[subDict setObject:[NSNumber numberWithBool:([object effectiveFilesystemMask] & 1<<2)] forKey:@"UDFEnabled"];

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
	if ([KWCommonMethods OSVersion] >= 0x1040)
		[object setProperties:[dict objectForKey:@"UDFProperties"] inFilesystem:@"DRUDF"];

	[object setSpecificName:[dict objectForKey:@"HSFSpecificName"] forFilesystem:DRHFSPlus];
	[object setSpecificName:[dict objectForKey:@"ISOLevel1SpecificName"] forFilesystem:DRISO9660LevelOne];
	[object setSpecificName:[dict objectForKey:@"ISOLevel2SpecificName"] forFilesystem:DRISO9660LevelTwo];

	[object setSpecificName:[dict objectForKey:@"JolietSpecificName"] forFilesystem:DRJoliet];
	if ([KWCommonMethods OSVersion] >= 0x1040)
		[object setSpecificName:[dict objectForKey:@"UDFSpecificName"] forFilesystem:@"DRUDF"];

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
	if ([[dict objectForKey:@"UDFEnabled"] boolValue])
		udf = 1<<2;
	
	[object setExplicitFilesystemMask:(hfs | iso | joliet | udf)];

	if ([dict objectForKey:@"Folder Icon"])
		[(KWDRFolder *)object setFolderIcon:[[[NSImage alloc] initWithData:[dict objectForKey:@"Folder Icon"]] autorelease]];
}

///////////////////
// Other actions //
///////////////////

#pragma mark -
#pragma mark •• Other actions

//Used by KWDataView
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
	KWDRFolder *rootFolder = (KWDRFolder*)[(FSNodeData*)[treeData nodeData] fsObject];

	if (([rootFolder explicitFilesystemMask] == 1<<2 && [KWCommonMethods OSVersion] < 0x1040) | [rootFolder explicitFilesystemMask] == 1<<4)
		return NO;
	
	return YES;
}

- (BOOL)isCombinable
{
	return ([self numberOfRows] > 0 && [self isCompatible]);
}

- (BOOL)isOnlyHFSPlus
{
	KWDRFolder *rootFolder = (KWDRFolder*)[(FSNodeData*)[treeData nodeData] fsObject];

	return ([rootFolder explicitFilesystemMask] == DRFilesystemInclusionMaskHFSPlus);
}

- (void)deleteTemporayFiles:(BOOL)needed
{
	if (needed)
	{
		int i;
		for (i=0;i<[temporaryFiles count];i++)
		{
			[KWCommonMethods removeItemAtPath:[temporaryFiles objectAtIndex:i]];
		}
	}
	
	[temporaryFiles removeAllObjects];
}

- (void)controlTextDidChange:(NSNotification *)aNotification
{
	KWDRFolder *rootFolder = (KWDRFolder*)[(FSNodeData*)[treeData nodeData] fsObject];
	int maxCharacters = [KWCommonMethods maxLabelLength:rootFolder];
	
	NSString *nameString = [discName stringValue];
	NSString *oldName = [NSString stringWithString:nameString];
	
	[self changeBaseName:discName];
	
	if ([nameString length] > maxCharacters)
	{
		if ([nameString length] > maxCharacters)
			[discName setStringValue:[nameString substringWithRange:NSMakeRange(0, maxCharacters)]];
	}

	if (![[[discName stringValue] lowercaseString] isEqualTo:[oldName lowercaseString]])
		NSBeep();
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
			[[NSNotificationCenter defaultCenter] postNotificationName:@"KWChangeInspector" object:[[self selectedDRFSObjects] retain] userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"KWData" ,@"Type",nil]];
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

- (int)numberOfRows
{
	return [outlineView numberOfRows];
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
	FSNodeData *nodeData = NODE_DATA((TreeNode *)[[outlineView allSelectedItems] objectAtIndex:0]); 

	//Set the new name
	if (![[nodeData name] isEqualTo:object])
		[nodeData setName:object];
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
		[(ImageAndTextCell*)cell setImage:[NODE_DATA(item) icon]];
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
        KWDataController *dragDataSource = [[info draggingSource] dataSource];
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
		
		NSEnumerator*	iter = [fileList objectEnumerator];
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
	
    [outlineView selectItems: itemsToSelect byExtendingSelection: NO];
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

@implementation KWDataController (Private)

- (void)_addNewDataToSelection:(TreeNode *)newChild shouldSelect:(BOOL)select
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
	
	newRow = [outlineView rowForItem:newChild];

		if (select)
		{
			[outlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:newRow] byExtendingSelection:NO];
			[outlineView scrollRowToVisible:newRow];
			[outlineView expandItem:[outlineView itemAtRow:newRow]];
		}
}

- (BOOL)respondsToSelector:(SEL)aSelector
{
	if (aSelector == @selector(burn:) | aSelector == @selector(saveImage:) | aSelector == @selector(saveDocument:) && [outlineView numberOfRows] == 0)
		return NO;
		
	return [super respondsToSelector:aSelector];
}

@end