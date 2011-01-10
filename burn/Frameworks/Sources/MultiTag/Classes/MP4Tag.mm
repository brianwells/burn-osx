//
//  MP4Tag.mm
//  MultiTag
//
//  Created by Maarten Foukhar on 10-01-11.
//  Copyright 2011 Kiwi Fruitware. All rights reserved.
//

#import "MP4Tag.h"
#include <mp4v2/mp4v2.h>

MP4FileHandle _file;
const MP4Tags* _tags;

@implementation MP4Tag

- (id)initWithFile:(NSString *)file
{
	self = [super init];

	_file = MP4Read([file cStringUsingEncoding:NSUTF8StringEncoding]);
	
	if ( _file != MP4_INVALID_FILE_HANDLE )
	{
		_tags = MP4TagsAlloc();
		MP4TagsFetch( _tags, _file );
	}
	else
	{
		return nil;
	}
	
	return self;
}

- (void)dealloc
{
	MP4TagsFree(_tags);
	MP4Close(_file);
	
	[super dealloc];
}

- (NSString *)getTagTitle
{
	if (_tags->name)
		return [NSString stringWithCString:_tags->name encoding:NSUTF8StringEncoding];
	
	return @"";
}

- (NSString *)getTagArtist
{
	if (_tags->artist)
		return [NSString stringWithCString:_tags->artist encoding:NSUTF8StringEncoding];
	
	return @"";
}

- (NSString *)getTagComposer
{
	if (_tags->composer)
		return [NSString stringWithCString:_tags->composer encoding:NSUTF8StringEncoding];
	
	return @"";
}

- (NSString *)getTagAlbum
{
	if (_tags->album)
		return [NSString stringWithCString:_tags->album encoding:NSUTF8StringEncoding];
	
	return @"";
}

- (NSString *)getTagComments
{
	if (_tags->comments)
		return [NSString stringWithCString:_tags->comments encoding:NSUTF8StringEncoding];
		
	return @"";
}

- (NSInteger)getTagYear
{
	if (_tags->releaseDate)
		#if MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_X_VERSION_10_5
		return [[NSString stringWithCString:_tags->releaseDate encoding:NSUTF8StringEncoding] intValue];
		#else
		return [[NSString stringWithCString:_tags->releaseDate encoding:NSUTF8StringEncoding] integerValue];
		#endif
		
	return 0;
}

- (NSInteger)getTagTrack
{
	if (_tags->track)
		if (_tags->track->index)
			return _tags->track->index;
	
	return 0;
}

- (NSInteger)getTagTotalNumberTracks
{
	if (_tags->track)
		if (_tags->track->total)
			return _tags->track->total;
	
	return 0;
}

- (NSInteger)getTagDisk
{
	if (_tags->disk)
		if (_tags->disk->index)
			return _tags->disk->index;
	
	return 0;
}

- (NSInteger)getTagTotalNumberDisks
{
	if (_tags->disk)
		if (_tags->disk->total)
			return _tags->disk->total;
	
	return 0;
}

- (NSArray *)getTagGenreNames
{
	if (_tags->genre)
			return [NSArray arrayWithObject:[NSString stringWithCString:_tags->genre encoding:NSUTF8StringEncoding]];

	return [NSArray array];
}

/*- (NSImage *)getTagArtwork
{
	MP4FileHandle mp4file = MP4Read([_file cStringUsingEncoding:NSUTF8StringEncoding]);
	
	if ( mp4file != MP4_INVALID_FILE_HANDLE )
	{
		const MP4Tags* tags = MP4TagsAlloc();
		MP4TagsFetch( tags, mp4file );
		
		if (tags->artwork)
		{
			const MP4TagArtwork* art = tags->artwork;
	
			NSData *imageData = [NSData dataWithBytes:art->data length:art->size];
			NSImage *image = [[NSImage alloc] initWithData:imageData];
		
			return [image autorelease];
		}
		
		MP4TagsFree(tags);
		MP4Close(mp4file);
	}
	
	return nil;
}*/

@end
