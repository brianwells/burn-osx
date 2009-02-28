#import "KWInspector.h"
#import <DiscRecording/DiscRecording.h>
#import "KWDataInspector.h"

@implementation KWInspector

- (id)init
{
self = [super init];

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

- (void)beginWindowForType:(NSString *)type withObject:(id)object
{
	if ([[self window] isVisible])
	[[self window] orderOut:self];
	else
	[[self window] makeKeyAndOrderFront:self];
	
[self updateForType:type withObject:object];

	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWFirstRun"] == YES)
	[[self window] setFrameOrigin:NSMakePoint(500,[[NSScreen mainScreen] frame].size.height - 548)];
}

- (void)updateForType:(NSString *)type withObject:(id)object
{
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
	[currentController updateView:object];
	[[self window] setContentView:[currentController myView]];
	[[self window] makeFirstResponder:[currentController myView]];
	}
	else
	{
	[[self window] setContentView:emptyView];
	}
}

- (void)saveFrame
{
[[self window] saveFrameUsingName:@"Inspector"];
[[NSUserDefaults standardUserDefaults] synchronize];
}

@end
