//
//  KWAlert.m
//  Burn
//
//  Created by Maarten Foukhar on 07-01-10.
//  Copyright 2010 Kiwi Fruitware. All rights reserved.
//

#import "KWAlert.h"


@implementation KWAlert

- (void)setDetails:(NSString *)details
{
	if (details)
	{
		expanded = NO;
	
		NSView *superview = [[self window] contentView];
		NSRect frame = NSMakeRect(16, 16, 88, 24);
	
		//Create details button
		NSButton *button = [[[NSButton alloc] initWithFrame:frame] autorelease];
		[button setBezelStyle:NSRoundedBezelStyle];
		[[button cell] setFont:[NSFont fontWithName:@"Lucida Grande" size:13]];
		[button setTitle:@"Details"];
		[button setAction:@selector(showDetails)];
	
		//Create scrollview with textview
		frame = NSMakeRect(20, 50, 384, 0);
		NSScrollView *scrollView = [[[NSScrollView alloc] initWithFrame:frame] autorelease];
		[scrollView setAutoresizingMask:NSViewHeightSizable];
		[scrollView setBorderType:NSBezelBorder];
		frame = NSMakeRect(0, 0, 364, 0);
		NSTextView *textView = [[[NSTextView alloc] initWithFrame:frame] autorelease];
		[textView setFont:[NSFont fontWithName:@"Andale Mono" size:12]];
		[scrollView setDocumentView:textView];
		[scrollView setHasVerticalScroller:YES];
	
		//Set the details and scroll to end
		[textView insertText:details];
		NSRange range = NSMakeRange ([[textView string] length], 0);
		[textView scrollRangeToVisible: range];
		[textView setEditable:NO];
	
		//Add our button and scrollview to alert
		[superview addSubview:button];
		[superview addSubview:scrollView];
	}
}

- (void)showDetails
{
	NSWindow *window = [self window];
	NSRect windowFrame = [window frame];
	int newHeight = windowFrame.size.height;
	
	if (expanded)
		newHeight = newHeight - 100;
	else
		newHeight = newHeight + 100;
		
	expanded = !expanded;
	
	[window setFrame:NSMakeRect(windowFrame.origin.x, windowFrame.origin.y, windowFrame.size.width, newHeight) display:YES animate:YES];
}

@end
