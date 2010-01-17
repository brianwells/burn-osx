#import "KWPantherCompatibleButton.h"
#import "KWCommonMethods.h"

@implementation KWPantherCompatibleButton

- (void)awakeFromNib
{
	if ([KWCommonMethods OSVersion] > 0x1039)
		[self setBezelStyle:NSSmallSquareBezelStyle];
}

@end
