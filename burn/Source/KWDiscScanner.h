/* scanTableViewController */

#import <Cocoa/Cocoa.h>

@interface KWDiskScanner : NSWindowController
{
    //Sheet outlets
	IBOutlet id tableView;
	IBOutlet id chooseScan;
	IBOutlet id cancelScan;
	IBOutlet id progressScan;
	IBOutlet id progressTextScan;
	
	//Variables
	NSMutableArray *tableData;
}

//Main actions
- (void)beginSetupSheetForWindow:(NSWindow *)window modelessDelegate:(id)modelessDelegate didEndSelector:(SEL)didEndSelector contextInfo:(void *)contextInfo;
- (void)scanDisks;
- (void)beginScanning;
- (void)scan:(id)args;

//Interface actions
- (IBAction)chooseScan:(id)sender;
- (IBAction)cancelScan:(id)sender;

//Output actions
- (NSString *)disk;
- (NSString *)name;
- (NSImage *)image;


@end
