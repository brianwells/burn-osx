#import "KWTableView.h"

@implementation KWTableView

- (BOOL)becomeFirstResponder 
{
[[NSNotificationCenter defaultCenter] postNotificationName:@"KWListSelected" object:self];

return [super becomeFirstResponder];
}

@end
