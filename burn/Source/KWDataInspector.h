#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <DiscRecording/DiscRecording.h>

@class AppController;
@class HFSPlusController;
@class ISOController;
@class JolietController;
@class UDFController;

@interface KWDataInspector : NSObject 
{
	IBOutlet NSTabView *tabs;
	IBOutlet HFSPlusController *hfsController;
	IBOutlet ISOController *isoController;
	IBOutlet JolietController *jolietController;
	IBOutlet UDFController *udfController;
	IBOutlet NSImageView *iconView;
	IBOutlet NSTextField *nameField;
	IBOutlet NSTextField *sizeField;
	IBOutlet id	myView;
	
	BOOL shouldChangeTab;
}

- (void)updateView:(NSArray *)objects;
- (id)myView;

@end
