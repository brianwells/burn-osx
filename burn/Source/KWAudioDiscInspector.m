#import "KWAudioDiscInspector.h"
#import "KWCommonMethods.h"

@implementation KWAudioDiscInspector

- (void)updateView:(id)object
{
myAudioController = [object dataSource];
[timeField setStringValue:[myAudioController totalTime]];

NSDictionary *CDTextDict = [myAudioController myCDTextDict];

	if ([CDTextDict count] > 0)
	{
	[title setStringValue:[CDTextDict objectForKey:@"Title"]];
	[performer setStringValue:[CDTextDict objectForKey:@"Performer"]];
	[composer setStringValue:[CDTextDict objectForKey:@"Composer"]];
	[songwriter setStringValue:[CDTextDict objectForKey:@"Songwriter"]];
	[arranger setStringValue:[CDTextDict objectForKey:@"Arranger"]];
	[notes setStringValue:[CDTextDict objectForKey:@"Notes"]];
	[discIdent setStringValue:[CDTextDict objectForKey:@"DiscIdent"]];
	[genreCode selectItemWithTitle:[CDTextDict objectForKey:@"GenreCode"]];
		if ([[genreCode title] isEqualTo:@"Other..."])
		[genreName setEnabled:YES];
		else
		[genreName setEnabled:NO];
	[genreName setStringValue:[CDTextDict objectForKey:@"GenreName"]];
	[privateUse setStringValue:[CDTextDict objectForKey:@"PrivateUse"]];
		if ([[CDTextDict objectForKey:@"EnableMCN"] boolValue])
		{
		[mcnCheckBox setState:NSOnState];
		[mcn setEnabled:YES];
		}
		else
		{
		[mcnCheckBox setState:NSOffState];
		[mcn setEnabled:NO];
		}
		
		if ([CDTextDict objectForKey:@"MCN"])
		[mcn setObjectValue:[CDTextDict objectForKey:@"MCN"]];
	}
}

- (IBAction)optionsChanged:(id)sender
{
NSMutableDictionary *CDTextDict = [myAudioController myCDTextDict];

	if ([[genreCode title] isEqualTo:@"Other..."])
	[genreName setEnabled:YES];
	else
	[genreName setEnabled:NO];

[CDTextDict setObject:[title stringValue] forKey:@"Title"];
[CDTextDict setObject:[performer stringValue] forKey:@"Performer"];
[CDTextDict setObject:[composer stringValue] forKey:@"Composer"];
[CDTextDict setObject:[songwriter stringValue] forKey:@"Songwriter"];
[CDTextDict setObject:[arranger stringValue] forKey:@"Arranger"];
[CDTextDict setObject:[notes stringValue] forKey:@"Notes"];
[CDTextDict setObject:[discIdent stringValue] forKey:@"DiscIdent"];
[CDTextDict setObject:[genreCode title] forKey:@"GenreCode"];
[CDTextDict setObject:[genreName stringValue] forKey:@"GenreName"];
[CDTextDict setObject:[privateUse stringValue] forKey:@"PrivateUse"];
	
[mcn setEnabled:([mcnCheckBox state] == NSOnState)];
[CDTextDict setObject:[NSNumber numberWithBool:([mcnCheckBox state] == NSOnState)] forKey:@"EnableMCN"];

	if ([mcn objectValue])
	[CDTextDict setObject:[mcn objectValue] forKey:@"MCN"];
}

- (id)myView
{
return myView;
}

@end
