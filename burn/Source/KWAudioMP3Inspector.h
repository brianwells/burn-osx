/* KWAudioMP3Inspector */

#import <Cocoa/Cocoa.h>
#import "ID3/TagAPI.h"
#import "KWCommonMethods.h"

@interface KWAudioMP3Inspector : NSObject
{
	IBOutlet id nameField;
	IBOutlet id sizeField;
	IBOutlet id iconView;
	IBOutlet id tabView;
	
    IBOutlet id imageString;
    IBOutlet id imageView;
    
	IBOutlet id myView;

	//Variables
	TagAPI *Tag;
	NSTableView *currentTableView;
	NSArray *methodMappings;
	NSInteger currentIndex;
}
- (void)updateView:(id)object;
- (id)getObjectWithSelector:(SEL)selector fromObjects:(NSArray *)objects;
- (void)setObjectWithSelector:(SEL)selector forObjects:(NSArray *)objects withObject:(id)object;
- (IBAction)addImage:(id)sender;
- (IBAction)nextImage:(id)sender;
- (IBAction)optionsChanged:(id)sender;
- (IBAction)previousImage:(id)sender;
- (IBAction)removeImage:(id)sender;
- (void)updateArtWork;
- (id)myView;

@end