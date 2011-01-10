//
//  MP4Tag.h
//  MultiTag
//
//  Created by Maarten Foukhar on 10-01-11.
//  Copyright 2011 Kiwi Fruitware. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#if MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_X_VERSION_10_5
typedef int NSInteger;
typedef unsigned int NSUInteger;
#endif


@interface MP4Tag : NSObject
{
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



@end
