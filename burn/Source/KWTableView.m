#import "KWTableView.h"

@implementation KWTableView

- (void)reloadData
{	
	[super reloadData];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWChangeBurnStatus" object:[NSNumber numberWithBool:([self numberOfRows] > 0)]];
}

- (BOOL)becomeFirstResponder 
{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWListSelected" object:self];

	return [super becomeFirstResponder];
}

@end