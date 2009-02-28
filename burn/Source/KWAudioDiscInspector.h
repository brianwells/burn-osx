/* KWAudioDiscInspector */

#import <Cocoa/Cocoa.h>
#import "audioController.h"

@interface KWAudioDiscInspector : NSObject
{
    IBOutlet id arranger;
    IBOutlet id composer;
    IBOutlet id discIdent;
    IBOutlet id genreCode;
    IBOutlet id genreName;
    IBOutlet id mcn;
    IBOutlet id mcnCheckBox;
    IBOutlet id notes;
    IBOutlet id performer;
    IBOutlet id privateUse;
    IBOutlet id songwriter;
    IBOutlet id timeField;
    IBOutlet id title;
	IBOutlet id	myView;
	
	audioController *myAudioController;
}
- (void)updateView:(id)object;
- (IBAction)optionsChanged:(id)sender;
- (id)myView;
@end
