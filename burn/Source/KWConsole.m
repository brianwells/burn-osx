#import "KWConsole.h"

@implementation KWConsole

- (id)init
{
self = [super init];

[NSBundle loadNibNamed:@"KWConsole" owner:self];
[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(addText:) name:@"KWConsoleNotification" object:nil];

return self;
}

- (void)dealloc
{
[super dealloc];
}

- (void)awakeFromNib
{
[textView setFont:[NSFont fontWithName:@"Courier Bold" size:12.0]];
[textView setContinuousSpellCheckingEnabled:NO];
}

- (IBAction)clear:(id)sender
{
NSRange range = NSMakeRange (0, [[[textView textStorage] string] length]);	
[textView setSelectedRange:range];
[textView delete:nil];
}

- (void)show
{
[[self window] makeKeyAndOrderFront:self];
}

- (void)addText:(NSNotification *)notif
{
[textView insertText:[notif object]];
NSRange range = NSMakeRange ([[textView string] length], 0);
[textView scrollRangeToVisible: range];
}

@end
