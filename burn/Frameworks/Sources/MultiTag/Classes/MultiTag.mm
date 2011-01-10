//
//  MultiTag.m
//  MultiTag
//
//  Created by Maarten Foukhar on 28-10-10.
//  Copyright 2010 Kiwi Fruitware. All rights reserved.
//

#import "MultiTag.h"
#import "MP4Tag.h"
#import "TagAPI.h"

@interface MultiTag (InternalMethods)
- (int)updateFile;
@end

@implementation MultiTag

- (id)initWithFile:(NSString *)file
{
	self = [super init];
	
	if ([[[file pathExtension] lowercaseString] isEqualTo:@"m4a"])
	{
		tagObject = [[MP4Tag alloc] initWithFile:file];
	}
	else if ([[[file pathExtension] lowercaseString] isEqualTo:@"mp3"])
	{
		tagObject = [[TagAPI alloc] initWithGenreList:nil];
		[tagObject examineFile:file];
	}
	
	return self;
}

- (void)dealloc
{
	if (tagObject)
		[tagObject release];
	
	[super dealloc];
}

- (NSString *)getTagTitle
{
	return [tagObject getTagTitle];
}

- (NSString *)getTagArtist
{
	return [tagObject getTagArtist];
}

- (NSString *)getTagComposer
{
	return [tagObject getTagComposer];
}

- (NSString *)getTagAlbum
{
	return [tagObject getTagAlbum];
}

- (NSString *)getTagComments
{
	return [tagObject getTagComments];
}

- (NSInteger)getTagYear
{
	return [tagObject getTagYear];
}

- (NSInteger)getTagTrack
{
	return [tagObject getTagTrack];
}

- (NSInteger)getTagTotalNumberTracks
{
	return [tagObject getTagTotalNumberTracks];
}

- (NSInteger)getTagDisk
{
	return [tagObject getTagDisk];
}

- (NSInteger)getTagTotalNumberDisks
{
	return [tagObject getTagTotalNumberDisks];
}

- (NSArray *)getTagGenreNames
{
	return [tagObject getTagGenreNames];
}

- (NSMutableArray *)getTagImage
{
	return [tagObject getTagImage];
}

- (BOOL)setTagTitle:(NSString *)Title
{
	return [tagObject setTagTitle:Title];
}

- (BOOL)setTagArtist:(NSString *)Artist
{
	return [tagObject setTagArtist:Artist];
}

- (BOOL)setTagComposer:(NSString *)Text
{
	return [tagObject setTagComposer:Text];
}

- (BOOL)setTagAlbum:(NSString *)Album
{
	return [tagObject setTagAlbum:Album];
}

- (BOOL)setTagComments:(NSString *)Comment
{
	return [tagObject setTagComments:Comment];
}

- (BOOL)setTagYear:(NSNumber *)Year
{
	return [tagObject setTagYear:Year];
}

- (BOOL)setTagTrack:(NSNumber *)Track
{
	return [tagObject setTagTrack:Track];
}

- (BOOL)setTagTotalNumberDisks:(NSNumber *)Total
{
	return [tagObject setTagTotalNumberDisks:Total];
}

- (BOOL)setTagDisk:(NSNumber *)Disk
{
	return [tagObject setTagDisk:Disk];
}

- (BOOL)setTagTotalNumberTracks:(NSNumber *)Total
{
	return [tagObject setTagTotalNumberTracks:Total];
}

- (BOOL)setTagGenreNames:(NSArray *)GenreNames
{
	return [tagObject setTagGenreNames:GenreNames];
}

- (BOOL)setTagImages:(NSMutableArray *)Images
{
	return [tagObject setTagImages:Images];
}

- (int)updateFile
{
	if ([tagObject respondsToSelector:@selector(updateFile)])
		return [tagObject updateFile];
		
	return 0;
}

@end
