//
//  MultiTag.h
//  MultiTag
//
//  Created by Maarten Foukhar on 28-10-10.
//  Copyright 2010 Kiwi Fruitware. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#if MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_X_VERSION_10_5
typedef int NSInteger;
typedef unsigned int NSUInteger;
#endif


@interface MultiTag : NSObject
{
	id tagObject;
}

- (id)initWithFile:(NSString *)file;

- (NSString *)getTagTitle;
- (NSString *)getTagArtist;
- (NSString *)getTagComposer;
- (NSString *)getTagAlbum;
- (NSString *)getTagComments;

- (NSInteger)getTagYear;
- (NSInteger)getTagTrack;
- (NSInteger)getTagTotalNumberTracks;
- (NSInteger)getTagDisk;
- (NSInteger)getTagTotalNumberDisks;

- (NSArray *)getTagGenreNames;
- (NSMutableArray *)getTagImage;

- (BOOL)setTagTitle:(NSString *)Title;
- (BOOL)setTagArtist:(NSString *)Artist;
- (BOOL)setTagComposer:(NSString *)Text;
- (BOOL)setTagAlbum:(NSString *)Album;
- (BOOL)setTagComments:(NSString *)Comment;

- (BOOL)setTagYear:(NSNumber *)Year;
- (BOOL)setTagTrack:(NSNumber *)Track;
- (BOOL)setTagTotalNumberDisks:(NSNumber *)Total;
- (BOOL)setTagDisk:(NSNumber *)Disk;
- (BOOL)setTagTotalNumberTracks:(NSNumber *)Total;

- (BOOL)setTagGenreNames:(NSArray *)GenreNames;
- (BOOL)setTagImages:(NSMutableArray *)Images;

- (int)updateFile;

//- (BOOL)setTagImages:(NSMutableArray *)Images;

@end
