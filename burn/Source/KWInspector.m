#import "KWInspector.h"
#import <DiscRecording/DiscRecording.h>
#import "KWDataInspector.h"
#import "KWCommonMethods.h"

@implementation KWInspector

- (id)init
{
	if( self = [super init] )
		[NSBundle loadNibNamed:@"KWInspector" owner:self];
	
	firstRun = YES;
	
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[super dealloc];
}

- (void)awakeFromNib
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(saveFrame) name:NSWindowWillCloseNotification object:nil];

	[[self window] setFrameUsingName:@"Inspector"];
}

//////////////////
// Main actions //
//////////////////

#pragma mark -
#pragma mark •• Main actions

- (void)beginWindowForType:(NSString *)type withObject:(id)object
{
	NSWindow *window = [self window];

	if ([window isVisible])
	{
		[window orderOut:self];
	}
	else
	{
		[self updateForType:type withObject:object];

		if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWFirstRun"] == YES)
			[window setFrameOrigin:NSMakePoint(500,[[NSScreen mainScreen] frame].size.height - 548)];
		
		[window makeKeyAndOrderFront:self];
	}
}

- (void)updateForType:(NSString *)type withObject:(id)object
{
	NSWindow *window = [self window];

	id currentController = nil;

	if ([type isEqualTo:@"KWData"])
		currentController = dataController;
	else if ([type isEqualTo:@"KWDataDisc"])
		currentController = dataDiscController;
	else if ([type isEqualTo:@"KWAudio"])
		currentController = audioController;
	else if ([type isEqualTo:@"KWAudioDisc"])
		currentController = audioDiscController;
	else if ([type isEqualTo:@"KWAudioMP3"])
		currentController = audioMP3Controller;
	else if ([type isEqualTo:@"KWDVD"])
		currentController = dvdController;
	
	if ([type isEqualTo:@"KWDataDisc"] && firstRun)
	{
		firstRun = NO;
		[currentController updateView:object];
	}

	if (currentController)
	{
		NSView *view = [currentController myView];
	
		[currentController updateView:object];
		[window setContentView:view];
		[window makeFirstResponder:view];
	}
	else
	{
		[window setContentView:emptyView];
	}
}

- (void)saveFrame
{
	[[self window] saveFrameUsingName:@"Inspector"];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

@end