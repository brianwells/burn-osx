/* KWAudioInspector */

#import <Cocoa/Cocoa.h>

@interface KWAudioInspector : NSObject
{
	//Interface outlets
	IBOutlet id invalid;
	IBOutlet id myView;
	IBOutlet id iconView;
	IBOutlet id nameField;
    IBOutlet id timeField;
	
	//Variables
	NSTableView *currentTableView;
	NSArray *tagMappings;
}

- (void)updateView:(id)object;
- (id)getCDTextObjectForKey:(NSString *)key inCDTextObject:(id)object atIndexes:(NSArray *)indexes;
- (id)getTrackObjectForKey:(NSString *)key inTrackObjects:(NSArray *)objects;
- (IBAction)optionsChanged:(id)sender;
- (IBAction)ISRCChanged:(id)sender;
- (BOOL)isValidISRC:(NSString*)isrc;
- (NSString *)ISRCStringFromString:(NSString *)string;
- (id)myView;

@end
