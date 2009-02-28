/* KWInspector */

#import <Cocoa/Cocoa.h>

@interface KWInspector : NSWindowController
{
    //Data Item
	IBOutlet id dataController;
    IBOutlet id dataView;
	//Data Disc
	IBOutlet id dataDiscController;
    IBOutlet id dataDiscView;
	//Audio Item
	IBOutlet id audioController;
    IBOutlet id audioView;
	//Audio Disc
	IBOutlet id audioDiscController;
    IBOutlet id audioDiscView;
	//Audio MP3 Item
	IBOutlet id audioMP3Controller;
    IBOutlet id audioMP3View;
	//DVD Item
	IBOutlet id dvdController;
    IBOutlet id dvdView;
	//Empty
	IBOutlet id emptyView;
	
	BOOL firstRun;
}

- (void)beginWindowForType:(NSString *)type withObject:(id)object;
- (void)updateForType:(NSString *)type withObject:(id)object;
- (void)saveFrame;

@end
