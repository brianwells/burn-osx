#import "KWPantherCompatibleButton.h"
#import "KWCommonMethods.h"

@implementation KWPantherCompatibleButton

- (void)awakeFromNib
{
	if (![KWCommonMethods isPanther])
		[self setBezelStyle:NSSmallSquareBezelStyle];
}

@end
