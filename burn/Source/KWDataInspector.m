#import "KWDataInspector.h"
#import "HFSPlusController.h"
#import "ISOController.h"
#import "JolietController.h"
#import "UDFController.h"
#import "KWCommonMethods.h"
#import "KWDRFolder.h"

@implementation KWDataInspector

- (id)init
{
self = [super init];
    
[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(leaveTab) name:@"KWLeaveTab" object:nil];

shouldChangeTab = YES;

return self;
}

- (void)dealloc 
{
[[NSNotificationCenter defaultCenter] removeObserver:self];

[super dealloc];
}

- (void)awakeFromNib
{
	if ([KWCommonMethods isPanther])
	[tabs removeTabViewItem:[tabs tabViewItemAtIndex:3]];
}

- (void)leaveTab
{
shouldChangeTab = NO;
}

- (void)updateView:(NSArray *)objects
{
	if ([objects count] == 1)
	{
	[nameField setStringValue:[KWCommonMethods fsObjectFileName:[objects objectAtIndex:0]]];
		
		BOOL isDir;
		if (![[objects objectAtIndex:0] isVirtual]  && [[NSFileManager defaultManager] fileExistsAtPath:[[objects objectAtIndex:0] sourcePath] isDirectory:&isDir] && !isDir)
		{
		[sizeField setStringValue:[KWCommonMethods makeSizeFromFloat:[[[[NSFileManager defaultManager] fileAttributesAtPath:[[objects objectAtIndex:0] sourcePath] traverseLink:YES] objectForKey:NSFileSize] floatValue]]];
		}
		else
		{
			if ([(KWDRFolder *)[objects objectAtIndex:0] folderSize])
			{
				if ((![(KWDRFolder *)[objects objectAtIndex:0] isFilePackage] && [[NSUserDefaults standardUserDefaults] boolForKey:@"KWCalculateFolderSizes"] == YES) | ([(KWDRFolder *)[objects objectAtIndex:0] isFilePackage] && (![[[KWCommonMethods fsObjectFileName:[objects objectAtIndex:0]] pathExtension] isEqualTo:@""] | [[[[objects objectAtIndex:0] baseName] stringByDeletingPathExtension] isEqualTo:[KWCommonMethods fsObjectFileName:[objects objectAtIndex:0]]] | [[KWCommonMethods fsObjectFileName:[objects objectAtIndex:0]] isEqualTo:[(KWDRFolder *)[objects objectAtIndex:0] displayName]]) && [[NSUserDefaults standardUserDefaults] boolForKey:@"KWCalculateFilePackageSizes"]) | ([(KWDRFolder *)[objects objectAtIndex:0] isFilePackage] && ([[[KWCommonMethods fsObjectFileName:[objects objectAtIndex:0]] pathExtension] isEqualTo:@""] | [[[[objects objectAtIndex:0] baseName] stringByDeletingPathExtension] isEqualTo:[KWCommonMethods fsObjectFileName:[objects objectAtIndex:0]]]) && [[NSUserDefaults standardUserDefaults] boolForKey:@"KWCalculateFolderSizes"]))
				[sizeField setStringValue:[(KWDRFolder *)[objects objectAtIndex:0] folderSize]];
				else
				[sizeField setStringValue:@"--"];
			}
			else
			{
			[sizeField setStringValue:@"--"];
			}
		}
	
		if ([[objects objectAtIndex:0] isVirtual])
		{
		NSImage *img = [KWCommonMethods getFolderIcon:[objects objectAtIndex:0]];
		[img setScalesWhenResized:YES];
		[img setSize:NSMakeSize(32.0,32.0)];
		[iconView setImage:img];
		}
		else
		{
		NSImage *img;
		BOOL fileIsFolder = NO;
		[[NSFileManager defaultManager] fileExistsAtPath:[[objects objectAtIndex:0] sourcePath] isDirectory:&fileIsFolder];
		
			if (fileIsFolder)
			{
			img = [KWCommonMethods getFolderIcon:[objects objectAtIndex:0]];
			}
			else
			{
			img = [KWCommonMethods getFileIcon:[objects objectAtIndex:0]];
			}
			
		[img setScalesWhenResized:YES];
		[img setSize:NSMakeSize(32.0,32.0)];
		[iconView setImage:img];
		}
	}
	else
	{
	[iconView setImage:[NSImage imageNamed:@"Multiple"]];
	[nameField setStringValue:@"Multiple Selection"];
	[sizeField setStringValue:[[[NSNumber numberWithInt:[objects count]] stringValue] stringByAppendingString:@" files"]];
	}

[hfsController inspect:objects];
[isoController inspect:objects];
[jolietController inspect:objects];
	if (![KWCommonMethods isPanther])
	[udfController inspect:objects];
	
	if (shouldChangeTab)
	{
		if ([[objects objectAtIndex:0] effectiveFilesystemMask] & DRFilesystemInclusionMaskHFSPlus)
		{
		[tabs selectTabViewItemWithIdentifier:@"HFS+"];
		}
		else if ([[objects objectAtIndex:0] effectiveFilesystemMask] & DRFilesystemInclusionMaskISO9660)
		{
		[tabs selectTabViewItemWithIdentifier:@"ISO"];
		}
		else if ([[objects objectAtIndex:0] effectiveFilesystemMask] & DRFilesystemInclusionMaskJoliet)
		{
		[tabs selectTabViewItemWithIdentifier:@"Joliet"];
		}
		else if (![KWCommonMethods isPanther])
		{
			if ([[objects objectAtIndex:0] effectiveFilesystemMask] & DRFilesystemInclusionMaskUDF)
			{
			[tabs selectTabViewItemWithIdentifier:@"UDF"];
			}
		}
	}

shouldChangeTab = YES;
}

- (id)myView
{
return myView;
}

@end
