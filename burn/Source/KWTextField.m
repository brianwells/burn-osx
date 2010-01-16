#import "KWTextField.h"

@implementation KWTextField

//Needed for the inspector
- (BOOL)becomeFirstResponder 
{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWDiscNameSelected" object:self];

	return [super becomeFirstResponder];
}

- (BOOL)textShouldEndEditing:(NSText *)textObject
{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWDiscNameChanged" object:self];

	return YES;
}

@end