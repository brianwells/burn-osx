#import "KWOutlineView.h"
#import "KWCommonMethods.h"

@implementation KWOutlineView

- (void)reloadData
{	
	[super reloadData];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWChangeBurnStatus" object:[NSNumber numberWithBool:([self numberOfRows] > 0)]];
	[[self delegate] performSelector:@selector(setTotalSize)];
}

- (BOOL)becomeFirstResponder 
{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWDataListSelected" object:self];

	return [super becomeFirstResponder];
}

- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)isLocal 
{
	if (isLocal) 
		return NSDragOperationEvery;
    else
		return NSDragOperationCopy;
}

- (void)textDidEndEditing:(NSNotification *)notification
{
	NSDictionary *userInfo = [notification userInfo];

	NSInteger textMovement = [[userInfo valueForKey:@"NSTextMovement"] intValue];

	if (textMovement == NSReturnTextMovement || textMovement == NSTabTextMovement || textMovement == NSBacktabTextMovement)
	{
		NSMutableDictionary *newInfo;
		newInfo = [NSMutableDictionary dictionaryWithDictionary:userInfo];

		[newInfo setObject: [NSNumber numberWithInt: NSIllegalTextMovement] forKey: @"NSTextMovement"];

		notification = [NSNotification notificationWithName: [notification name] object: [notification object] userInfo: newInfo];
    }

	[super textDidEndEditing: notification];
	[[self window] makeFirstResponder:self];
}

- (void)keyDown:(NSEvent *)theEvent             
{
	unichar pressedKey = [[theEvent characters] characterAtIndex:0];

	if (pressedKey == 13 | pressedKey == 3)
		[self  editColumn:0 row:[self selectedRow] withEvent:nil select:YES];
	else if ([theEvent keyCode] == 0x35)
		[self deselectAll:self];
	else if (pressedKey == 9)
		[[self window] selectNextKeyView:self];
	else
		[super keyDown:theEvent];
}

@end