#import "KWToolbarKiller.h"

@implementation KWToolbarKiller

- (void)drawRect:(NSRect)rect
{
	if ([NSStringFromSelector([self action]) isEqualToString:@"_toolbarPillButtonClicked:"] && [[[self window] title] isEqualTo:NSLocalizedString(@"Burn",nil)]) 
		return;
	
	[super drawRect:rect];
}

- (void)mouseDown:(NSEvent *)anEvent
{
	if ([NSStringFromSelector([self action]) isEqualToString:@"_toolbarPillButtonClicked:"] && [[[self window] title] isEqualTo:NSLocalizedString(@"Burn",nil)]) 
		return;

	[super mouseDown:anEvent];
}

@end