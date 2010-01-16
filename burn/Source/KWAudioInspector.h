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
- (id)getObjectForKey:(NSString *)key inObject:(id)object atIndexes:(NSArray *)indexes;
- (IBAction)optionsChanged:(id)sender;
- (IBAction)ISRCChanged:(id)sender;
- (BOOL)isValidISRC:(NSString*)isrc;
- (NSString *)ISRCStringFromString:(NSString *)string;
- (id)myView;

@end
