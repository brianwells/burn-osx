#import "KWDiscScanner.h"
#import "KWCommonMethods.h"

@implementation KWDiscScanner

//We need to have table datasource
- (id)init
{
	self = [super init];

	tableData = [[NSMutableArray alloc] init];
	[NSBundle loadNibNamed:@"KWDiscScanner" owner:self];
	[tableView setDoubleAction:@selector(chooseScan:)];
	
	NSWorkspace *sharedWorkspace = [NSWorkspace sharedWorkspace];
	[[sharedWorkspace notificationCenter] addObserver:self selector:@selector(beginScanning) name:NSWorkspaceDidMountNotification object:nil];
	[[sharedWorkspace notificationCenter] addObserver:self selector:@selector(beginScanning) name:NSWorkspaceDidUnmountNotification object:nil];
   
	return self;
}

//Delocate datasource
- (void)dealloc
{
	[[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];
	[tableData release];

	[super dealloc];
}

//////////////////
// Main actions //
//////////////////

#pragma mark -
#pragma mark •• Main actions

- (void)beginSetupSheetForWindow:(NSWindow *)window modelessDelegate:(id)modelessDelegate didEndSelector:(SEL)didEndSelector contextInfo:(void *)contextInfo
{
	[self beginScanning];
	[NSApp beginSheet:[self window] modalForWindow:window modalDelegate:modelessDelegate didEndSelector:didEndSelector contextInfo:contextInfo];
}

//Check for removable disks, also check their bsd name and if they're read only
- (void)scanDisks
{
	//NSMutableString *rootName = [[NSMutableString alloc] init];
	NSArray *mountedRemovableMedia = [[NSWorkspace sharedWorkspace] mountedRemovableMedia];
	
	NSInteger i;
	for(i = 0; i < [mountedRemovableMedia count]; i ++)
	{
		NSString *path = [mountedRemovableMedia objectAtIndex:i];
		
		NSString *string;
		NSArray *arguments = [NSArray arrayWithObjects:@"info", path, nil];
		BOOL succes = [KWCommonMethods launchNSTaskAtPath:@"/usr/sbin/diskutil" withArguments:arguments outputError:NO outputString:YES output:&string];
		NSDictionary *information = nil;
		
		if (succes)
			information = [KWCommonMethods getDictionaryFromString:string];
		
		if (information)
		{
			//NSString *partitionNumber = [[[information objectForKey:@"Device Node"] componentsSeparatedByString:@"/dev/disk"] objectAtIndex:1];
			//[rootName appendString:[NSString stringWithFormat:@"/dev/rdisk%@", partitionNumber]];
		
			if ([[information objectForKey:@"Read Only"] boolValue] == YES | [[information objectForKey:@"Read-Only Media"] boolValue] == YES )
			{ 
				NSMutableDictionary *rowData = [NSMutableDictionary dictionary];
		
				NSInteger size = [KWCommonMethods getSizeFromMountedVolume:path] * 512;

				[rowData setObject:[path lastPathComponent] forKey:@"Name"];
				[rowData setObject:[[[NSWorkspace sharedWorkspace] iconForFile:path] retain] forKey:@"Icon"];
				[rowData setObject:[KWCommonMethods makeSizeFromFloat:size] forKey:@"Device"];
				[rowData setObject:path forKey:@"Mounted Path"];
			
				[tableData addObject:rowData];
				[tableView reloadData];
			}
		}

		[cancelScan setEnabled:YES];
		[progressScan setHidden:YES];
		
		BOOL rows = ([tableData count] > 0);
		
		[chooseScan setEnabled:rows];
	
		if (rows)
			[progressTextScan setHidden:YES];
		else
			[progressTextScan setStringValue:NSLocalizedString(@"No discs, try inserting a cd/dvd.", Localized)];
	}
	
	if ([mountedRemovableMedia count] == 0)
	{
		[progressTextScan setStringValue:NSLocalizedString(@"No discs, try inserting a cd/dvd.", Localized)];
		[chooseScan setEnabled:NO];
		[cancelScan setEnabled:YES];
		[progressScan setHidden:YES];
	}
	
	[progressScan stopAnimation:self];
}

//Throw the scanning in a thread, so the app stays responding
-(void)beginScanning
{
	[cancelScan setEnabled:NO];
	[chooseScan setEnabled:NO];
	[progressScan setHidden:NO];
	[progressTextScan setHidden:NO];
	[progressTextScan setStringValue:NSLocalizedString(@"Scanning for disks...", Localized)];
	[progressScan startAnimation:self];
	[tableData removeAllObjects];
	[tableView reloadData];

	[NSThread detachNewThreadSelector:@selector(scan:) toTarget:self withObject:nil];
}

//The thread
- (void)scan:(id)args
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[self scanDisks];
	[pool release];
}

///////////////////////
// Interface actions //
///////////////////////

#pragma mark -
#pragma mark •• Interface actions

- (IBAction)chooseScan:(id)sender
{
	[NSApp endSheet:[self window] returnCode:NSOKButton];
}

- (IBAction)cancelScan:(id)sender
{
	[NSApp endSheet:[self window] returnCode:0];
}

////////////////////
// Output actions //
////////////////////

#pragma mark -
#pragma mark •• Output actions

//Return disk to use
- (NSString *)disk
{
	if ([tableView selectedRow] == -1)
		return nil;
	else
		return [[tableData objectAtIndex:[tableView selectedRow]] objectForKey:@"Mounted Path"];
}

- (NSString *)name
{
	if ([tableView selectedRow] == -1)
		return nil;
	else
		return [[[tableData objectAtIndex:[tableView selectedRow]] objectForKey:@"Name"] lastPathComponent];
}

- (NSImage *)image
{
	if ([tableView selectedRow] == -1)
		return nil;
	else
		return [[tableData objectAtIndex:[tableView selectedRow]] objectForKey:@"Icon"];
}

///////////////////////
// Tableview actions //
///////////////////////

#pragma mark -
#pragma mark •• Tableview actions

- (BOOL)tableView:(NSTableView *)tableView shouldEditTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{    
	return NO;
}

- (NSInteger) numberOfRowsInTableView:(NSTableView *)tableView
{
    return [tableData count];
}

- (id) tableView:(NSTableView *)tableView
    objectValueForTableColumn:(NSTableColumn *)tableColumn
    row:(NSInteger)row
{
    NSDictionary *rowData = [tableData objectAtIndex:row];
    return [rowData objectForKey:[tableColumn identifier]];
}

- (void) tableView:(NSTableView *)tableView
    setObjectValue:(id)anObject
    forTableColumn:(NSTableColumn *)tableColumn
    row:(NSInteger)row
{
    NSMutableDictionary *rowData = [tableData objectAtIndex:row];
    [rowData setObject:anObject forKey:[tableColumn identifier]];
}

@end