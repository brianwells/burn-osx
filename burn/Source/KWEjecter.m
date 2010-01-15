#import "KWEjecter.h"
#import "KWCommonMethods.h"

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

//////////////////
// Main actions //
//////////////////

#pragma mark -
#pragma mark •• Main actions

- (void)startEjectSheetForWindow:(NSWindow *)atachWindow forDevice:(DRDevice *)device
{
	[popupButton removeAllItems];
	
	NSArray *devices = [DRDevice devices];
	int i;
	for (i=0;i< [devices count];i++)
	{
		[popupButton addItemWithTitle:[[devices objectAtIndex:i] displayName]];
	}
	
	[popupButton selectItemWithTitle:[device displayName]];

	[NSApp beginSheet:[self window] modalForWindow:atachWindow modalDelegate:self didEndSelector: @selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[sheet orderOut:self];
}

///////////////////////
// Interface actions //
///////////////////////

#pragma mark -
#pragma mark •• Interface actions

- (IBAction)cancelEject:(id)sender
{
	[NSApp endSheet:[self window]];
}

- (IBAction)ejectDisk:(id)sender
{
	if (![[[DRDevice devices] objectAtIndex:[popupButton indexOfSelectedItem]] ejectMedia])
	{
		[KWCommonMethods standardAlertWithMessageText:NSLocalizedString(@"Failed to eject", Localized) withInformationText:NSLocalizedString(@"Could not eject media from the drive", Localized)withParentWindow:nil];
	}

	[NSApp endSheet:[self window]];
}

@end
