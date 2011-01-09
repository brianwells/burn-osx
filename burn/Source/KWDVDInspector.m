#import "KWDVDInspector.h"
#import "KWVideoController.h"
#import <KWConverter.h>
#import "KWCommonMethods.h"

@interface NSSliderCell (isPressed)
- (BOOL)isPressed;
@end

@implementation NSSliderCell (isPressed)
- (BOOL)isPressed
{
	return _scFlags.isPressed;
}
@end

@implementation KWDVDInspector

- (id) init
{
	self = [super init];

	tableData = [[NSMutableArray alloc] init];

	return self;
}

- (void)dealloc
{
	[tableData release];

	[super dealloc];
}

- (void)updateView:(id)object
{
	currentTableView = object;
	currentObject = [[(KWVideoController *)[object dataSource] myDataSource] objectAtIndex:[object selectedRow]];

	[nameField setStringValue:[currentObject objectForKey:@"Name"]];
	[timeField setStringValue:[currentObject objectForKey:@"Size"]];
	[iconView setImage:[currentObject objectForKey:@"Icon"]];

	KWConverter *converter = [[KWConverter alloc] init];
	[timeSlider setMaxValue:(double)[converter totalTimeInSeconds:[currentObject objectForKey:@"Path"]]];
	[timeSlider setDoubleValue:0];
	[converter release];

	[tableData removeAllObjects];
	
	if ([currentObject objectForKey:@"Chapters"])
		[tableData addObjectsFromArray:[currentObject objectForKey:@"Chapters"]];

	[tableView reloadData];

	[previewView setImage:nil];
}

- (IBAction)add:(id)sender
{
	[previewView setImage:[[KWConverter alloc] getImageAtPath:[currentObject objectForKey:@"Path"] atTime:0 isWideScreen:[[currentObject objectForKey:@"WideScreen"] boolValue]]];	
	[titleField setStringValue:@""];
	[NSApp beginSheet:chapterSheet modalForWindow:[myView window] modalDelegate:self didEndSelector:@selector(endChapterSheet) contextInfo:nil];
}

- (void)endChapterSheet
{
	[chapterSheet orderOut:self];
}

- (IBAction)addSheet:(id)sender
{
	NSMutableDictionary *rowData = [NSMutableDictionary dictionary];

	[rowData setObject:[KWCommonMethods formatTime:(NSInteger)[timeSlider doubleValue]] forKey:@"Time"];
	[rowData setObject:[titleField stringValue] forKey:@"Title"];
	[rowData setObject:[NSNumber numberWithDouble:[timeSlider doubleValue]] forKey:@"RealTime"];
	[rowData setObject:[[previewView image] TIFFRepresentationUsingCompression:NSTIFFCompressionLZW factor:0] forKey:@"Image"];

	[tableData addObject:rowData];

	NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"Time" ascending:YES];
	[tableData sortUsingDescriptors:[NSArray arrayWithObject:sortDescriptor]];
	[sortDescriptor release];
	
	NSMutableDictionary *tempDict = [NSMutableDictionary dictionaryWithDictionary:currentObject];
	NSMutableArray *controller = [(KWVideoController *)[currentTableView dataSource] myDataSource];
	
	[tempDict setObject:[NSArray arrayWithArray:tableData] forKey:@"Chapters"];
	[controller replaceObjectAtIndex:[currentTableView selectedRow] withObject:[tempDict copy]];
	
	[currentTableView reloadData];
	currentObject = [controller objectAtIndex:[currentTableView selectedRow]];

	[tableView reloadData];
}

- (IBAction)cancelSheet:(id)sender
{
	[NSApp endSheet:chapterSheet];
}

- (IBAction)remove:(id)sender
{
	NSArray *selectedObjects = [KWCommonMethods allSelectedItemsInTableView:tableView fromArray:tableData];
	[tableData removeObjectsInArray:selectedObjects];
	
	NSMutableDictionary *tempDict = [NSMutableDictionary dictionaryWithDictionary:currentObject];
	NSMutableArray *controller = [(KWVideoController *)[currentTableView dataSource] myDataSource];

	[tempDict setObject:[NSArray arrayWithArray:tableData] forKey:@"Chapters"];

	[controller replaceObjectAtIndex:[currentTableView selectedRow] withObject:[tempDict copy]];

	[tableView deselectAll:nil];
	[tableView reloadData];
}

- (IBAction)timeSlider:(id)sender
{
	[previewView setImage:[[KWConverter alloc] getImageAtPath:[currentObject objectForKey:@"Path"] atTime:(NSInteger)[timeSlider doubleValue] isWideScreen:[[currentObject objectForKey:@"WideScreen"] boolValue]]];

	[currentTimeField setStringValue:[KWCommonMethods formatTime:(NSInteger)[timeSlider doubleValue]]];
}

///////////////////////
// Tableview actions //
///////////////////////

#pragma mark -
#pragma mark •• Tableview actions

- (BOOL)tableView:(NSTableView *)tableView shouldEditTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{    return NO; }

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

- (void)tableView:(NSTableView *)tableView
    setObjectValue:(id)anObject
    forTableColumn:(NSTableColumn *)tableColumn
    row:(NSInteger)row
{
	NSMutableDictionary *rowData = [tableData objectAtIndex:row];
	[rowData setObject:anObject forKey:[tableColumn identifier]];
}

- (id)myView
{
	return myView;
}

@end