#import "KWProgress.h"
#import "KWCommonMethods.h"

@implementation KWProgress

- (id)init
{
	self = [super init];
	
	notificationNames = [[NSArray alloc] initWithObjects:@"KWMaximumValueChanged", @"KWValueChanged", @"KWTaskChanged", @"KWStatusChanged", @"KWStatusByAddingPercentChanged", @"KWCancelNotificationChanged", nil];

	cancelNotification = nil;
	[NSBundle loadNibNamed:@"KWProgress" owner:self];

	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[progressBar stopAnimation:self];

	//Release our stuff
	[notificationNames release];
	notificationNames = nil;
	
	cancelNotification = nil;
	
	[super dealloc];
}

///////////////////
// Main actions //
///////////////////

#pragma mark -
#pragma mark •• Main actions

- (void)awakeFromNib
{
	NSInteger i;
	
	for (i = 0; i < [notificationNames count]; i ++)
	{
		NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
		NSString *notificationName = [notificationNames objectAtIndex:i];
		
		[defaultCenter addObserver:self selector:@selector(notificationReceived:) name:notificationName object:nil];
	}
}

- (void)notificationReceived:(NSNotification *)notif
{
	NSString *notificationName = [notif	name];
	NSString *selectorName = [notificationName substringWithRange:NSMakeRange(2, [notificationName length] - 9)];
	selectorName = [NSString stringWithFormat:@"set%@:", selectorName];
	
	[self performSelector:NSSelectorFromString(selectorName) withObject:[notif object]];
}

- (IBAction)cancelProgress:(id)sender
{
	if (cancelNotification)
		[[NSNotificationCenter defaultCenter] postNotificationName:cancelNotification object:self];
}

- (void)beginSheetForWindow:(NSWindow *)window
{
	[NSApp beginSheet:[self window] modalForWindow:window modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

- (void)beginWindow
{
	NSWindow *window = [self window];
	[NSApp runModalForWindow:window];
	[window close];
}

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	[sheet orderOut:self];
}

- (void)endSheet
{
	if (application)
	{
		[application release];
		application = nil;
	}

	[NSApp setApplicationIconImage:[NSImage imageNamed:@"Burn"]];
	[NSApp endSheet:[self window]];
}

- (void)setTask:(NSString *)task
{
	[taskText performSelectorOnMainThread:@selector(setStringValue:) withObject:task waitUntilDone:YES];
}

- (void)setStatus:(NSString *)status
{
	[statusText performSelectorOnMainThread:@selector(setStringValue:) withObject:status waitUntilDone:YES];
}

- (void)setStatusByAddingPercent:(NSString *)percent
{
	NSString *newStatusText;

	if ([[statusText stringValue] length] > 60)
		newStatusText = [NSString stringWithFormat:@"%@…",  [[statusText stringValue] substringToIndex:58]];
	else
		newStatusText = [statusText stringValue];

	[statusText performSelectorOnMainThread:@selector(setStringValue:) withObject:[[[newStatusText componentsSeparatedByString:@" ("] objectAtIndex:0] stringByAppendingString:percent] waitUntilDone:YES];
}

- (void)setMaximumValue:(NSNumber *)number
{
	if ([number doubleValue] > 0)
	{
		[self performSelectorOnMainThread:@selector(setIndeterminateOnMainThread:) withObject:[NSNumber numberWithBool:NO] waitUntilDone:YES];
		[self performSelectorOnMainThread:@selector(setDoubleValueOnMainThread:) withObject:[NSNumber numberWithDouble:0] waitUntilDone:YES];
		[self performSelectorOnMainThread:@selector(setMaxiumValueOnMainThread:) withObject:number waitUntilDone:YES];
	}
	else
	{
		[self performSelectorOnMainThread:@selector(setIndeterminateOnMainThread:) withObject:[NSNumber numberWithBool:YES] waitUntilDone:YES];
		[progressBar performSelectorOnMainThread:@selector(startAnimation:) withObject:self waitUntilDone:YES];
	
		if (application)
		{
			[application release];
			application = nil;
		}
		
		application = [[NSImage imageNamed:@"Burn"] copy];

		[application lockFocus];
		[[NSImage imageNamed:@"-1"] drawInRect:NSMakeRect(9, 10, 111, 16) fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
		[application unlockFocus];
	
		[NSApp performSelectorOnMainThread:@selector(setApplicationIconImage:) withObject:application waitUntilDone:YES];
	}
}

- (void)setValue:(NSNumber *)number
{
	NSImage *miniProgressIndicator;
	
	if (application)
	{
		[application release];
		application = nil;
	}

	application = [[NSImage imageNamed:@"Burn"] copy];
	NSRect progressRect = NSMakeRect(9, 10, 111, 16);

	if ([number doubleValue] == -1)
	{
		[self performSelectorOnMainThread:@selector(setIndeterminateOnMainThread:) withObject:[NSNumber numberWithBool:YES] waitUntilDone:YES];
		[progressBar performSelectorOnMainThread:@selector(startAnimation:) withObject:self waitUntilDone:YES];
	
		miniProgressIndicator = [NSImage imageNamed:@"-1"];
	
		[application lockFocus];
		[miniProgressIndicator drawInRect:progressRect fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
		[application unlockFocus];
	
		[NSApp performSelectorOnMainThread:@selector(setApplicationIconImage:) withObject:application waitUntilDone:YES];
	}
	else
	{
		[self performSelectorOnMainThread:@selector(setIndeterminateOnMainThread:) withObject:[NSNumber numberWithBool:NO] waitUntilDone:YES];
	}

	if ([number doubleValue] > [progressBar doubleValue])
	{
		[self performSelectorOnMainThread:@selector(setDoubleValueOnMainThread:) withObject:number waitUntilDone:YES];
	
		NSImage *emptyBar = [NSImage imageNamed:@"0"];
		NSImage *fullBar = [NSImage imageNamed:@"100"];
		CGFloat scale = [number doubleValue] / [progressBar maxValue];
		CGFloat width = [fullBar size].width * scale;
		NSRect fullRect = NSMakeRect(0, 0, width, [fullBar size].height);
		NSRect fullProgressRect = NSMakeRect(progressRect.origin.x, progressRect.origin.y, width, progressRect.size.height);
		
		[application lockFocus];
		[emptyBar drawInRect:progressRect fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
		[fullBar drawInRect:fullProgressRect fromRect:fullRect operation:NSCompositeCopy fraction:1.0];
		[application unlockFocus];

		[NSApp performSelectorOnMainThread:@selector(setApplicationIconImage:) withObject:application waitUntilDone:YES];
	}
}

- (void)setIcon:(NSImage *)image
{
	[progressIcon performSelectorOnMainThread:@selector(setImage:) withObject:image waitUntilDone:YES];
}

- (void)setCancelNotification:(NSString *)notification
{
	cancelNotification = notification;
}

- (void)setCanCancel:(BOOL)cancel
{
	NSWindow *window = [self window];
	[cancelProgress setHidden:!cancel];

	if (cancel)
		[window setFrame:NSMakeRect([window frame].origin.x, [window frame].origin.y, [window frame].size.width, 163) display:YES];
	else
		[[self window] setFrame:NSMakeRect([window frame].origin.x, [window frame].origin.y, [window frame].size.width, 124) display:YES];
}

- (void)setMaxiumValueOnMainThread:(NSNumber *)number
{
	[progressBar setMaxValue:[number doubleValue]];
}

- (void)setIndeterminateOnMainThread:(NSNumber *)number
{
	[progressBar setIndeterminate:[number boolValue]];
}

- (void)setDoubleValueOnMainThread:(NSNumber *)number
{
	[progressBar setDoubleValue:[number doubleValue]];
}

@end
