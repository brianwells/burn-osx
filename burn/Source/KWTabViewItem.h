/* KWTabViewItem */

#import <Cocoa/Cocoa.h>

@interface KWTabViewItem : NSTabViewItem
{
    IBOutlet id controller;
}
- (id)myController;

@end
