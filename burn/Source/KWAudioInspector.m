#import "KWAudioInspector.h"
#import "audioController.h"
#import "KWCommonMethods.h"

@implementation KWAudioInspector

- (void)updateView:(id)object
{
currentTableView = object;
NSArray *currentObjects;

	if (![KWCommonMethods isPanther])
	currentObjects = [[(audioController *)[currentTableView dataSource] myDataSource] objectsAtIndexes:[currentTableView selectedRowIndexes]];
	else
	currentObjects = [KWCommonMethods allSelectedItemsInTableView:currentTableView fromArray:[(audioController *)[currentTableView dataSource] myDataSource]];

	if ([currentObjects count] == 1)
	{
	[iconView setImage:[self getObjectForKey:@"Icon" inObjects:currentObjects]];
	[nameField setStringValue:[self getObjectForKey:@"Name" inObjects:currentObjects]];
	[timeField setStringValue:[self getObjectForKey:@"Time" inObjects:currentObjects]];
	}
	else
	{
	[iconView setImage:[NSImage imageNamed:@"Multiple"]];
	[nameField setStringValue:@"Multiple Selection"];
	[timeField setStringValue:[[[NSNumber numberWithInt:[currentObjects count]] stringValue] stringByAppendingString:@" files"]];
	}

[title setStringValue:[self getObjectForKey:@"Title" inObjects:currentObjects]];
[performer setStringValue:[self getObjectForKey:@"Performer" inObjects:currentObjects]];
[composer setStringValue:[self getObjectForKey:@"Composer" inObjects:currentObjects]];
[songwriter setStringValue:[self getObjectForKey:@"Songwriter" inObjects:currentObjects]];
[arranger setStringValue:[self getObjectForKey:@"Arranger" inObjects:currentObjects]];
[notes setStringValue:[self getObjectForKey:@"Notes" inObjects:currentObjects]];
[privateUse setStringValue:[self getObjectForKey:@"Private" inObjects:currentObjects]];
[preGap setObjectValue:[self getObjectForKey:@"Pregap" inObjects:currentObjects]];
[preEmphasis setObjectValue:[self getObjectForKey:@"Pre-emphasis" inObjects:currentObjects]];
[ISRCCheckBox setObjectValue:[self getObjectForKey:@"EnableISRC" inObjects:currentObjects]];
[ISRCField setEnabled:([[self getObjectForKey:@"EnableISRC" inObjects:currentObjects] boolValue])];
[ISRCCDText setEnabled:([[self getObjectForKey:@"EnableISRC" inObjects:currentObjects] boolValue])];
//[invalid setHidden:(![[self getObjectForKey:@"EnableISRC" inObjects:currentObjects] boolValue])];
[ISRCField setStringValue:[self getObjectForKey:@"ISRC" inObjects:currentObjects]];
[ISRCCDText setObjectValue:[self getObjectForKey:@"ISRCCDText" inObjects:currentObjects]];
[indexPoints setObjectValue:[self getObjectForKey:@"IndexPoints" inObjects:currentObjects]];

	if ([[self getObjectForKey:@"EnableISRC" inObjects:currentObjects] boolValue])
	[self ISRCChanged:self];
	else
	[invalid setHidden:YES];
}

- (id)getObjectForKey:(NSString *)key inObjects:(NSArray *)objects
{
	if ([objects count] == 1)
	{
	return [[objects objectAtIndex:0] objectForKey:key];
	}
	else
	{
	id aValue = [[objects objectAtIndex:0] objectForKey:key];
	
		int i;
		for (i=0;i<[objects count];i++)
		{
			if (![aValue isEqualTo:[[objects objectAtIndex:i] objectForKey:key]])
			{
				if ([aValue isKindOfClass:[NSString class]])
				return @"";
				else
				return [NSNumber numberWithBool:NO];
			}
		}
	}

return [[objects objectAtIndex:0] objectForKey:key];
}

- (IBAction)optionsChanged:(id)sender
{
NSArray *currentObjects;
	
	if (![KWCommonMethods isPanther])
	currentObjects = [[(audioController *)[currentTableView dataSource] myDataSource] objectsAtIndexes:[currentTableView selectedRowIndexes]];
	else
	currentObjects = [KWCommonMethods allSelectedItemsInTableView:currentTableView fromArray:[(audioController *)[currentTableView dataSource] myDataSource]];
	
	int i;
	for (i=0;i<[currentObjects count];i++)
	{
	NSMutableDictionary *tempDict = [[currentObjects objectAtIndex:i] mutableCopy];
	
		if (![[self getObjectForKey:@"Title" inObjects:currentObjects] isEqualTo:[title stringValue]])
		[tempDict setObject:[title stringValue] forKey:@"Title"];
		if (![[self getObjectForKey:@"Performer" inObjects:currentObjects] isEqualTo:[performer stringValue]])
		[tempDict setObject:[performer stringValue] forKey:@"Performer"];
		if (![[self getObjectForKey:@"Composer" inObjects:currentObjects] isEqualTo:[composer stringValue]])
		[tempDict setObject:[composer stringValue] forKey:@"Composer"];
		if (![[self getObjectForKey:@"Songwriter" inObjects:currentObjects] isEqualTo:[songwriter stringValue]])
		[tempDict setObject:[songwriter stringValue] forKey:@"Songwriter"];
		if (![[self getObjectForKey:@"Arranger" inObjects:currentObjects] isEqualTo:[arranger stringValue]])
		[tempDict setObject:[arranger stringValue] forKey:@"Arranger"];
		if (![[self getObjectForKey:@"Notes" inObjects:currentObjects] isEqualTo:[notes stringValue]])
		[tempDict setObject:[notes stringValue] forKey:@"Notes"];
		if (![[self getObjectForKey:@"Private" inObjects:currentObjects] isEqualTo:[privateUse stringValue]])
		[tempDict setObject:[privateUse stringValue] forKey:@"Private"];
	

		if (![[self getObjectForKey:@"Pregap" inObjects:currentObjects] isEqualTo:[preGap stringValue]])
		[tempDict setObject:[preGap stringValue] forKey:@"Pregap"];
		if (([preEmphasis state] == NSOnState) | [currentObjects count] == 1)
		[tempDict setObject:[NSNumber numberWithBool:([preEmphasis state] == NSOnState)] forKey:@"Pre-emphasis"];
		if (([ISRCCheckBox state] == NSOnState) | [currentObjects count] == 1)
		[tempDict setObject:[NSNumber numberWithBool:([ISRCCheckBox state] == NSOnState)] forKey:@"EnableISRC"];
		if (![[self getObjectForKey:@"ISRC" inObjects:currentObjects] isEqualTo:[ISRCField stringValue]])
		[tempDict setObject:[ISRCField stringValue] forKey:@"ISRC"];
		if (([ISRCCDText state] == NSOnState) | [currentObjects count] == 1)
		[tempDict setObject:[NSNumber numberWithBool:([ISRCCDText state] == NSOnState)] forKey:@"ISRCCDText"];
		if (([indexPoints state] == NSOnState) | [currentObjects count] == 1)
		[tempDict setObject:[NSNumber numberWithBool:([indexPoints state] == NSOnState)] forKey:@"IndexPoints"];
		
	[[(audioController *)[currentTableView dataSource] myDataSource] replaceObjectAtIndex:[[(audioController *)[currentTableView dataSource] myDataSource] indexOfObject:[currentObjects objectAtIndex:i]] withObject:[tempDict copy]];
	}
}

- (IBAction)ISRCCheckBox:(id)sender
{
[ISRCField setEnabled:([ISRCCheckBox state] == NSOnState)];
[ISRCCDText setEnabled:([ISRCCheckBox state] == NSOnState)];
[invalid setHidden:([ISRCCheckBox state] == NSOffState)];
}

- (IBAction)ISRCChanged:(id)sender
{
BOOL isValue = [self isValidISRC:[ISRCField stringValue]];

	if (isValue)
	[self optionsChanged:self];

[invalid setHidden:isValue];
}

- (BOOL)isValidISRC:(NSString*)isrc
{
	// Get the string as ASCII, and make sure it's 12 bytes long.
	NSData *data = [isrc dataUsingEncoding:NSASCIIStringEncoding];
	if (data == nil)
	return NO;
	
	// Check the length.
	unsigned length = [data length];
	if (length > 12)
		return NO;
	if (length != 12)
		return NO;
	
	// Make sure the characters are within the right ranges.
	const char *byte = (char*)[data bytes];
	unsigned i;
	for (i=0; i<length; ++i)
	{
		char	c = byte[i];
		BOOL	alpha = (c >= 'A' && c <= 'Z');
		BOOL	num = (c >= '0' && c <= '9');
		if (i<2) {			// first two chars are A-Z
			if (!alpha) return NO;
		} else if (i<5) {	// next three chars are 0-9 A-Z
			if (!alpha && !num) return NO;
		} else	{			// remaining chars are 0-9
			if (!num) return NO;
		}
	}
	
// Looks valid.
return YES;
}

- (id)myView
{
return myView;
}


@end
