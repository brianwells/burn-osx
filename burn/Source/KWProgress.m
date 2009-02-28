#import "KWProgress.h"

@implementation KWProgress

- (id)init
{
self = [super init];

cancelNotification = nil;
[NSBundle loadNibNamed:@"KWProgress" owner:self];

return self;
}

- (void)dealloc
{
[[NSNotificationCenter defaultCenter] removeObserver:self];
cancelNotification = nil;
[progressBar stopAnimation:self];
[super dealloc];
}

///////////////////
// Main actions //
///////////////////

#pragma mark -
#pragma mark •• Main actions

- (void)awakeFromNib
{
[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notificationReceived:) name:@"KWMaximumValueChanged" object:nil];
[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notificationReceived:) name:@"KWValueChanged" object:nil];
[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notificationReceived:) name:@"KWTaskChanged" object:nil];
[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notificationReceived:) name:@"KWStatusChanged" object:nil];
[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notificationReceived:) name:@"KWStatusByAddingPercentChanged" object:nil];
[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notificationReceived:) name:@"KWCancelNotificationChanged" object:nil];
[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notificationReceived:) name:@"KWBeginSheetForWindow" object:nil];
}

- (void)notificationReceived:(NSNotification *)notif
{
	if ([[notif name] isEqualTo:@"KWMaximumValueChanged"])
	[self setMaximumValue:[notif object]];
	else if ([[notif name] isEqualTo:@"KWValueChanged"])
	[self setValue:[notif object]];
	else if ([[notif name] isEqualTo:@"KWTaskChanged"])
	[self setTask:[notif object]];
	else if ([[notif name] isEqualTo:@"KWStatusChanged"])
	[self setStatus:[notif object]];
	else if ([[notif name] isEqualTo:@"KWStatusByAddingPercentChanged"])
	[self setStatusByAddingPercent:[notif object]];
	else if ([[notif name] isEqualTo:@"KWCancelNotificationChanged"])
	[self setCancelNotification:[notif object]];
	else if ([[notif name] isEqualTo:@"KWBeginSheetForWindow"])
	[self beginSheetForWindow:[notif object]];
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
[NSApp runModalForWindow:[self window]];
[[self window] close];
}

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
[sheet orderOut:self];
}

- (void)endSheet
{
	if (application)
	[application release];

[NSApp setApplicationIconImage:[NSImage imageNamed:@"Burn"]];

	if ([[self window] isSheet])
	[NSApp endSheet:[self window]];
	else
	[NSApp abortModal];
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
	newStatusText = [[[statusText stringValue] substringToIndex:58] stringByAppendingString:@"..."];
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
		[application release];
		
	application = [[NSImage imageNamed:@"Burn"] copy];

	[application lockFocus];
	[[NSImage imageNamed:@"-1"] drawInRect:NSMakeRect(9,10,111,16) fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
	[application unlockFocus];
	
	[NSApp performSelectorOnMainThread:@selector(setApplicationIconImage:) withObject:application waitUntilDone:YES];
	}
}

- (void)setValue:(NSNumber *)number
{
NSImage *miniProgressIndicator = [[NSImage alloc] init];
	
	if (application)
	[application release];

application = [[NSImage imageNamed:@"Burn"] copy];
NSRect progressRect = NSMakeRect(9,10,111,16);

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
	
	double percent = [number doubleValue] / [progressBar maxValue] * 100;
	
		if (percent > 0 && percent < 10)
		{
		miniProgressIndicator = [NSImage imageNamed:@"0"];
		
		[application lockFocus];
		[miniProgressIndicator drawInRect:progressRect fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
		[application unlockFocus];

		[NSApp performSelectorOnMainThread:@selector(setApplicationIconImage:) withObject:application waitUntilDone:YES];
		}
		else if (percent > 10 && percent < 20)
		{
		miniProgressIndicator = [NSImage imageNamed:@"10"];
		
		[application lockFocus];
		[miniProgressIndicator drawInRect:progressRect fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
		[application unlockFocus];
		
		[NSApp performSelectorOnMainThread:@selector(setApplicationIconImage:) withObject:application waitUntilDone:YES];
		}
		else if (percent > 20 && percent < 30)
		{
		miniProgressIndicator = [NSImage imageNamed:@"20"];
		
		[application lockFocus];
		[miniProgressIndicator drawInRect:progressRect fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
		[application unlockFocus];
		
		[NSApp performSelectorOnMainThread:@selector(setApplicationIconImage:) withObject:application waitUntilDone:YES];
		}
		else if (percent > 30 && percent < 40)
		{
		miniProgressIndicator = [NSImage imageNamed:@"30"];
		
		[application lockFocus];
		[miniProgressIndicator drawInRect:progressRect fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
		[application unlockFocus];
		
		[NSApp performSelectorOnMainThread:@selector(setApplicationIconImage:) withObject:application waitUntilDone:YES];
		}
		else if (percent > 40 && percent < 50)
		{
		miniProgressIndicator = [NSImage imageNamed:@"40"];
		
		[application lockFocus];
		[miniProgressIndicator drawInRect:progressRect fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
		[application unlockFocus];
		
		[NSApp performSelectorOnMainThread:@selector(setApplicationIconImage:) withObject:application waitUntilDone:YES];
		}
		else if (percent > 50 && percent < 60)
		{
		miniProgressIndicator = [NSImage imageNamed:@"50"];
		
		[application lockFocus];
		[miniProgressIndicator drawInRect:progressRect fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
		[application unlockFocus];
		
		[NSApp performSelectorOnMainThread:@selector(setApplicationIconImage:) withObject:application waitUntilDone:YES];
		}
		else if (percent > 60 && percent < 70)
		{
		miniProgressIndicator = [NSImage imageNamed:@"60"];
		
		[application lockFocus];
		[miniProgressIndicator drawInRect:progressRect fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
		[application unlockFocus];
		
		[NSApp performSelectorOnMainThread:@selector(setApplicationIconImage:) withObject:application waitUntilDone:YES];
		}
		else if (percent > 70 && percent < 80)
		{
		miniProgressIndicator = [NSImage imageNamed:@"70"];
		
		[application lockFocus];
		[miniProgressIndicator drawInRect:progressRect fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
		[application unlockFocus];
		
		[NSApp performSelectorOnMainThread:@selector(setApplicationIconImage:) withObject:application waitUntilDone:YES];
		}
		else if (percent > 80 && percent < 90)
		{
		miniProgressIndicator = [NSImage imageNamed:@"80"];
		
		[application lockFocus];
		[miniProgressIndicator drawInRect:progressRect fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
		[application unlockFocus];
		
		[NSApp performSelectorOnMainThread:@selector(setApplicationIconImage:) withObject:application waitUntilDone:YES];
		}
		else if (percent > 90 && percent < 99)
		{
		miniProgressIndicator = [NSImage imageNamed:@"90"];
		
		[application lockFocus];
		[miniProgressIndicator drawInRect:progressRect fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
		[application unlockFocus];

		[NSApp performSelectorOnMainThread:@selector(setApplicationIconImage:) withObject:application waitUntilDone:YES];
		}
		else if (percent == 99 && percent > 99)
		{
		miniProgressIndicator = [NSImage imageNamed:@"100"];
		
		[application lockFocus];
		[miniProgressIndicator drawInRect:progressRect fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
		[application unlockFocus];
		
		[NSApp performSelectorOnMainThread:@selector(setApplicationIconImage:) withObject:application waitUntilDone:YES];
		}
	}
	
[miniProgressIndicator release];
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
	if (cancel == NO)
	{
	[[self window] setFrame:NSMakeRect([[self window] frame].origin.x,[[self window] frame].origin.y,[[self window] frame].size.width,124) display:YES];
	[cancelProgress setHidden:YES];
	}
	else
	{
	[[self window] setFrame:NSMakeRect([[self window] frame].origin.x,[[self window] frame].origin.y,[[self window] frame].size.width,163) display:YES];
	[cancelProgress setHidden:NO];
	}
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
