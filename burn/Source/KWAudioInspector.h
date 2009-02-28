/* KWAudioInspector */

#import <Cocoa/Cocoa.h>

@interface KWAudioInspector : NSObject
{
	IBOutlet id title;
	IBOutlet id performer;
	IBOutlet id composer;
	IBOutlet id songwriter;
	IBOutlet id arranger;
	IBOutlet id notes;
	IBOutlet id privateUse;
    IBOutlet id indexPoints;
    IBOutlet id ISRCCDText;
    IBOutlet id ISRCCheckBox;
    IBOutlet id ISRCField;
    IBOutlet id preEmphasis;
    IBOutlet id preGap;
	IBOutlet id invalid;
	
	IBOutlet id myView;
	IBOutlet id iconView;
	IBOutlet id nameField;
    IBOutlet id timeField;
	id currentTableView;
}
- (void)updateView:(id)object;
- (id)getObjectForKey:(NSString *)key inObjects:(NSArray *)objects;
- (IBAction)optionsChanged:(id)sender;
- (IBAction)ISRCCheckBox:(id)sender;
- (IBAction)ISRCChanged:(id)sender;
- (BOOL)isValidISRC:(NSString*)isrc;
- (id)myView;
@end
