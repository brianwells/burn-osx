/* KWAudioDiscInspector */

#import <Cocoa/Cocoa.h>

@interface KWAudioDiscInspector : NSObject
{
    IBOutlet id genreCode;
	IBOutlet id	myView;
	IBOutlet id	timeField;
	
	//Variables
	NSTableView *currentTableView;
	NSArray *tagMappings;
}
- (void)updateView:(id)object;
- (IBAction)optionsChanged:(id)sender;
- (id)myView;
@end