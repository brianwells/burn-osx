#import "KWPantherCompatibleButton.h"
#import "KWCommonMethods.h"

@implementation KWPantherCompatibleButton

#if MAC_OS_X_VERSION_MAX_ALLOWED < 1050
- (void)awakeFromNib
{
	if ([KWCommonMethods OSVersion] > 0x1039)
		[self setBezelStyle:10];
}
#endif

@end
