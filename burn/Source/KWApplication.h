/* KWApplication */

#import <Cocoa/Cocoa.h>
#import "KWPreferences.h"
#import "KWRecorderInfo.h"
#import "KWDiscInfo.h"
#import "KWEjecter.h"
#import "KWInspector.h"
#import "KWGrowlController.h"

@interface KWApplication : NSObject
{
    //Variables
	KWPreferences *preferences;
	KWRecorderInfo *recorderInfo;
	KWDiscInfo *diskInfo;
	KWEjecter *ejecter;
	KWInspector *inspector;
	KWGrowlController *growlController;
	
	//Inspector variables
	id currentObject;
	NSString *currentType;
}

//Menu Actions
//Burn Menu
- (IBAction)preferencesBurn:(id)sender;
//Window Menu
- (IBAction)inspectorWindow:(id)sender;
- (IBAction)recorderInfoWindow:(id)sender;
- (IBAction)diskInfoWindow:(id)sender;
//Help Menu
- (IBAction)openBurnSite:(id)sender;

@end