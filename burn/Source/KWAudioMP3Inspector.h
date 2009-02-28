/* KWAudioMP3Inspector */

#import <Cocoa/Cocoa.h>
#import "ID3/TagAPI.h"

@interface KWAudioMP3Inspector : NSObject
{
	IBOutlet id nameField;
	IBOutlet id sizeField;
	IBOutlet id iconView;
	IBOutlet id tabView;
	
    IBOutlet id album;
    IBOutlet id artist;
    IBOutlet id composer;
    IBOutlet id discNumber;
    IBOutlet id discTotal;
    IBOutlet id genre;
    IBOutlet id imageString;
    IBOutlet id imageView;
    IBOutlet id myView;
    IBOutlet id notes;
    IBOutlet id title;
    IBOutlet id trackNumber;
    IBOutlet id trackTotal;
    IBOutlet id year;
	
	id currentObjects;
	TagAPI *Tag;
}
- (void)updateView:(id)object;
- (id)getObjectWithSelector:(SEL)selector fromObjects:(NSArray *)objects returnsInt:(BOOL)isInt;
- (void)setObjectWithSelector:(SEL)selector forObjects:(NSArray *)objects withObject:(id)object;
- (IBAction)addImage:(id)sender;
- (IBAction)nextImage:(id)sender;
- (IBAction)optionsChanged:(id)sender;
- (IBAction)previousImage:(id)sender;
- (IBAction)removeImage:(id)sender;
- (void)updateArtWorkAtIndex:(int)index;
- (id)myView;
@end
