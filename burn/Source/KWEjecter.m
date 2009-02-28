#import "KWEjecter.h"

@implementation KWEjecter

- (id)init
{
	if( self = [super init] )
	{
	[NSBundle loadNibNamed:@"KWEjecter" owner:self];
	}
	
	return self;
}

- (void)dealloc
{
[super dealloc];
}

- (void)startEjectSheetForWindow:(NSWindow *)atachWindow forDevice:(DRDevice *)device
{
[popupButton removeAllItems];

	int i;
	for (i=0;i< [[DRDevice devices] count];i++)
	{
	[popupButton addItemWithTitle:[[[DRDevice devices] objectAtIndex:i] displayName]];
	}
	
[popupButton selectItemWithTitle:[device displayName]];

	if (!atachWindow == nil)
	{
	[NSApp beginSheet:[self window] modalForWindow:atachWindow modalDelegate:self didEndSelector: @selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:nil];
	}
	else
	{
	[[self window] makeKeyAndOrderFront:self];
	}
}

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
[sheet orderOut:self];
}

- (IBAction)cancelEject:(id)sender
{
[NSApp endSheet:[self window]];
}

- (IBAction)ejectDisk:(id)sender
{
[[[DRDevice devices] objectAtIndex:[popupButton indexOfSelectedItem]] ejectMedia];

[NSApp endSheet:[self window]];
}

@end
