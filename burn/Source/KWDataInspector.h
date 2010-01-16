#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

@class KWApplication;
@class HFSPlusController;
@class ISOController;
@class JolietController;
@class UDFController;

@interface KWDataInspector : NSObject 
{
	IBOutlet id tabs;
	IBOutlet id hfsController;
	IBOutlet id isoController;
	IBOutlet id jolietController;
	IBOutlet id udfController;
	IBOutlet id iconView;
	IBOutlet id nameField;
	IBOutlet id sizeField;
	IBOutlet id	myView;
	
	BOOL shouldChangeTab;
}

//Main Actions
- (void)updateView:(NSArray *)objects;
- (id)myView;
- (void)leaveTab;

@end