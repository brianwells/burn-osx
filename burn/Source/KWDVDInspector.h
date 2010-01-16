/* KWDVDInspector */

#import <Cocoa/Cocoa.h>

@interface KWDVDInspector : NSObject
{
    IBOutlet id chapterSheet;
    IBOutlet id currentTimeField;
    IBOutlet id iconView;
    IBOutlet id myView;
    IBOutlet id nameField;
    IBOutlet id previewView;
    IBOutlet id tableView;
    IBOutlet id timeField;
    IBOutlet id timeSlider;
	IBOutlet id titleField;
	
	NSMutableArray *tableData;
	id currentTableView;
	id currentObject;
}
- (IBAction)add:(id)sender;
- (IBAction)addSheet:(id)sender;
- (IBAction)cancelSheet:(id)sender;
- (IBAction)remove:(id)sender;
- (IBAction)timeSlider:(id)sender;

- (void)updateView:(id)object;
- (id)myView;
@end