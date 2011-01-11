//
//  TagAPI.h
//  id3Tag
//
//  Created by Chris Drew on Tue Nov 12 2002.
//  Copyright (c) 2002 . All rights reserved.
//

#ifdef __APPLE__
#import <Foundation/Foundation.h>
#import "id3V2Tag.h"
#import "id3V1Tag.h"
#import "id3V2Frame.h"
#else
#ifndef _ID3FRAMEWORK_TAGAPI_H_
#define _ID3FRAMEWORK_TAGAPI_H_
#include <Foundation/NSObject.h>
#include "id3V2Tag.h"
#include "id3V1Tag.h"
#include "id3V2Frame.h"
#endif
#endif


@interface TagAPI : NSObject {
//data dictionary used to store frame and genres information
    NSDictionary *dataDictionary;

 //standard decode variables
    BOOL modify;
    
    NSMutableDictionary *genreDictionary;
    NSMutableDictionary *preferences;
    BOOL externalPreferences;
    BOOL externalDictionary;
    
    id3V2Tag *v2Tag;
    id3V1Tag *v1Tag;
    int parse;
    BOOL parsedV1;

    NSString *path;
}

// ********** Initialise and examine files *********************
- (id)initWithGenreList:(NSMutableDictionary *)Dictionary;
- (void)dealloc;
- (void)releaseAttributes;
- (BOOL)examineFile:(NSString *)Path;
- (int)updateFile;

// *********  Methods to get tag data ************************** 
- (NSString *)getTagTitle;
- (NSString *)getTagArtist;
- (NSString *)getTagAlbum;
- (NSNumber *)getTagYear;
- (NSNumber *)getTagTrack;
- (NSNumber *)getTagTotalNumberTracks;
- (NSNumber *)getTagDisk;
- (NSNumber *)getTagTotalNumberDisks;
- (NSArray *)getTagGenreNames;
- (NSString *)getTagComments;
- (NSMutableArray *)getTagImage;
- (NSString *)getTagComposer;

// ****** Methods to set tag data ***************************************
- (BOOL)setTagTitle:(NSString *)Title;
- (BOOL)setTagArtist:(NSString *)Artist;
- (BOOL)setTagAlbum:(NSString *)Album;
- (BOOL)setTagYear:(NSNumber *)Year;
- (BOOL)setTagTrack:(int)Track totalTracks:(int)Total;
- (BOOL)setTagDisk:(int)Disk totalDisks:(int)Total;
- (BOOL)setTagTrack:(NSNumber *)Track;
- (BOOL)setTagTotalNumberTracks:(NSNumber *)Total;
- (BOOL)setTagDisk:(NSNumber *)Disk;
- (BOOL)setTagTotalNumberDisks:(NSNumber *)Total;
- (BOOL)setTagGenreNames:(NSArray *)GenreNames;
- (BOOL)setTagComments:(NSString *)Comment;
- (BOOL)setTagImages:(NSMutableArray *)Images;
- (BOOL)setTagComposer:(NSString *)Text;

// ***** Create new, copy data between and drop tags *********************
- (BOOL)copyV2TagToV1Tag;
- (BOOL)copyV1TagToV2Tag;

- (BOOL)v1TagPresent; // use to check if a v1 tag is present (will force the Framework to check for a v1 tag)
- (BOOL)v2TagPresent; //

- (NSMutableArray *)processGenreArray:(NSArray *)Array;

// ***** Other ************************************************************
- (NSNumber *)returnNumber:(int)number;

@end