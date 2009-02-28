#import <AppKit/AppKit.h>

@interface _NSThemeWidget : NSButton {} @end

//Kill the toolbar, only way in Panther
@interface KWToolbarKiller : _NSThemeWidget
{}
// ...
@end
