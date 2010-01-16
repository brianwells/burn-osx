/* KWInspector */

#import <Cocoa/Cocoa.h>

@interface KWInspector : NSWindowController
{
	//Interface Outlets
    //Controllers
	IBOutlet id dataController;
	IBOutlet id dataDiscController;
	IBOutlet id audioController;
	IBOutlet id audioDiscController;
	IBOutlet id audioMP3Controller;
	IBOutlet id dvdController;
	//Empty
	IBOutlet id emptyView;
	
	BOOL firstRun;
}

//Main Actions
- (void)beginWindowForType:(NSString *)type withObject:(id)object;
- (void)updateForType:(NSString *)type withObject:(id)object;
- (void)saveFrame;

@end