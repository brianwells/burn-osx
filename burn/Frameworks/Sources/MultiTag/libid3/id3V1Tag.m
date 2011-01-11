//
//  id3V1Tag.m
//  id3Tag
//
//  Created by Chris Drew on Mon Nov 18 2002.
//  Copyright (c) 2002 __MyCompanyName__. All rights reserved.
//

#ifdef __APPPLE__
#import <Foundation/Foundation.h>
#import "id3V1Tag.h"
#else
#include "id3V1Tag.h"

#include <Foundation/NSFileHandle.h>
#include <Foundation/NSData.h>
#include <Foundation/NSString.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSCharacterSet.h>

#endif

// Constants for defining size and location of id3v1 tags with in a file
#define id3TagLength 128
#define HeaderLength 3			
#define TitleLength     30
#define ArtistLength    30
#define AlbumLength     30
#define YearLength      4
#define CommentLength   28
#define TrackLength	1
#define GenreLength     1

// actual location = fileSize - variable offset
#define HeaderOffset    128
#define TitleOffset     125
#define ArtistOffset    95
#define AlbumOffset     65
#define YearOffset      35
#define CommentOffset   31
#define TrackOffset	3
#define GenreOffset     1

#define kTrimSetStr	@"%c%@", '\0', @" \r\n\t"

@implementation id3V1Tag
-(id)init
{
    if (self = [super init]) 
    {
        start = 0;
        actualTagLength = 0;
        present = NO;
        changed = NO;
    
        //storage for tag
        tag = NULL;
    
        //error variables
        errorNo = 0;
        errorDescription = NULL;
    
        // file properties
        path = NULL;
        fileSize = 0;
    }
    return self;
}

-(BOOL)openPath:(NSString *)Path
{
    id old = path;
    path = [Path copy];
    if (old != NULL) [old release];
    if (tag != NULL) [tag release];
    return [self getTag];
}

// v1 Tag processing code follows below

-(NSString *)getTitle
{
    if ((present == NO)||(tag==NULL)) return NULL;
    return [self getString:3 length:30];
}

-(NSString *)getArtist;
{
    if ((present == NO)||(tag==NULL)) return NULL;
    return [self getString:33 length:30];
}

-(NSString *)getAlbum;
{
   if ((present == NO)||(tag==NULL)) return NULL;
    return [self getString:63 length:30];
}

-(int)getYear;
{
    char * pointer = (char *) [tag bytes];
    
    if ((present == NO)||(tag==NULL)) return 0;
    return [[NSMutableString stringWithCString: pointer + 93 length:4] intValue];
}

-(NSString *)getComment;
{
    if ((present == NO)||(tag==NULL)) return NULL;
    return [self getString:97 length:28];
}

-(int)getTrack;
{
    unsigned char * pointer = (unsigned char *) [tag bytes];
    
    if ((present == NO)||(tag==NULL)) return 0;
 //   if (pointer[124] != 0) return 0; // this is not a v1.1 tag
    return pointer[125];
}

- (NSString *) getString:(int)Position length:(int)MaxLength
{  // ensure that we only extract the string and not the crap at the end
    char * pointer = (char *) [tag bytes];
    int i = 0;
    int j = 0;
    //step through the string
    for (i = 0;i < MaxLength;i++)
    {
        if ((pointer[i+Position] == 0) || (pointer[i+Position] == ' '))
        {
            if (pointer[i+Position] == 0) break; // if null end string
        } else j=i;
    }
    return [[NSString stringWithCString: pointer + Position length:j+1] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:[NSString stringWithFormat:kTrimSetStr]]];
}

-(int)getGenre
{
    unsigned char * pointer = (unsigned char *) [tag bytes];
    
    if ((present == NO)||(tag==NULL)) return 0;
    return pointer[125];
}

-(BOOL)getTag
{
    NSFileHandle *file = [NSFileHandle fileHandleForReadingAtPath: path];
    if (file == NULL) 
    {
        NSLog(@"Could not open file handle for file:%s",[path cString]);
        [self newTag];
        return NO;
    }
    
    fileSize = [file seekToEndOfFile];
    if (fileSize < 128) 
    {
        [self newTag];
        [file closeFile];
        return NO; 
    }
    [file seekToFileOffset: (fileSize - 128)]; //reads last 128 bytes of the file as this is were a id3  tag would be stored
    tag = [[file readDataToEndOfFile] retain];
    if (tag == NULL)
    {
        [self newTag];
        [file closeFile];
        return NO;
    }
    
    unsigned char * pointer = (unsigned char *) [tag bytes];
    if ((pointer[0] == 'T')&&(pointer[1] == 'A')&&(pointer[2] == 'G'))
    { // found id3 v1 tag
        present = YES;
    } else
    {
        [tag release];
        tag = NULL;
        [self newTag];
        present = NO;
    } 
    [file closeFile];
    return YES;
}

//error handling
-(int)getErrorCode
{
    return errorNo;
}

-(NSString *)getErrorDescription
{
    return errorDescription;
}

-(void)clearError
{
    if (errorDescription != NULL) [errorDescription release];
    errorDescription = NULL;
    errorNo = 0;
}

-(BOOL)setError:(int)No reason:(NSString *)Description
{
    [self clearError];
    errorNo = No;
    errorDescription = [[NSString stringWithString:Description] retain];
    return NO;
}

-(BOOL)tagPresent
{
    return present;
}

// id3 tag editing

-(BOOL)newTag
{ // deletes old tag array and creates a blank tag
    [self clearError];
    if (tag != NULL) [tag release];
    tag = [[NSMutableData dataWithLength:128] retain];
    unsigned char * Buffer = (unsigned char *)[tag bytes];
    Buffer[0] = 'T';
    Buffer[1] = 'A';
    Buffer[2] = 'G';
    changed = YES;
    return YES;
}

-(BOOL)writeTag
{
    if (!changed) return YES;
    unsigned char * Buffer = (unsigned char *)[tag bytes];
    Buffer [124] = 0;
    int Offset = 0;
    [self clearError];
    if (tag == NULL) [self setError:1 reason:@"writeTag: No data in V1tag"];
    NSFileHandle *file = [NSFileHandle fileHandleForUpdatingAtPath: path];
    if (present) Offset = -128;
    [file seekToFileOffset:fileSize + Offset];
    [file writeData:tag];
    present = YES;
    changed = NO;
    [file closeFile];

    return YES; 
}

-(BOOL)dropTag
{
    NSFileHandle *file = [NSFileHandle fileHandleForUpdatingAtPath: path];
    
    fileSize = [file seekToEndOfFile];
    if (fileSize < 128) 
    {
        [file closeFile];
        return NO; 
    }
    [file seekToFileOffset: (fileSize - 128)]; //reads last 128 bytes of the file as this is were a id3  tag would be stored
    NSData * tempTag = [file readDataToEndOfFile];
    if (tag == NULL)
    {
        [file closeFile];
        return NO;
    }
    
    unsigned char * pointer = (unsigned char *) [tempTag bytes];
    if ((pointer[0] == 'T')&&(pointer[1] == 'A')&&(pointer[2] == 'G'))
    { // found id3 v1 tag
        present = YES;
    } else
    {
        present = NO;
    } 
    [file closeFile];

    if (present)
    {
        [file truncateFileAtOffset:fileSize - 128];
    }
    [file closeFile];
    present = NO;
    return YES;
}

-(BOOL)setFieldWithString:(NSString *)String offset:(int)Offset length:(int)Length
{
    char *Buffer = (char *) [tag bytes];
    if (Buffer == NULL) return NO;
    int i;
    
    for (i = id3TagLength - Offset; i < Length; i++) Buffer[i] = 0;
    if ([String length] > Length) [self setError:1 reason:@"setFieldWithString: Data in field to long"];
    char *cString = (char *) [String lossyCString];
    Buffer += (id3TagLength - Offset);
    for (i = 0; i < Length; i++) Buffer[i] = cString[i];
    changed = YES;
    return YES;
}

-(BOOL)setFieldWithNumber:(int)Number offset:(int)Offset length:(int)Length
{
    char * Buffer = (char *)[tag bytes];
    if (Buffer == NULL) return NO;
    int i;
    
    for (i = id3TagLength - Offset; i < Length; i++) Buffer[i] = 0;
    [[[NSNumber numberWithInt:Number] stringValue] getCString:Buffer + id3TagLength - Offset maxLength: Length];
    changed = YES;
    return YES;
}

-(BOOL)setTitle:(NSString *)Title
{
    changed = YES;
    return [self setFieldWithString:Title offset:TitleOffset length:TitleLength];
}

-(BOOL)setArtist:(NSString *)Artist
{
    changed = YES;
    return [self setFieldWithString:Artist offset:ArtistOffset length:ArtistLength];
}

-(BOOL)setAlbum:(NSString *)Album
{
    changed = YES;
    return [self setFieldWithString:Album offset:AlbumOffset length:AlbumLength];
}

-(BOOL)setYear:(int)Year
{
    changed = YES;
    if (Year > 9999) Year = 9999;
    return [self setFieldWithNumber:Year offset:YearOffset length:YearLength];
}

-(BOOL)setComment:(NSString *)Comment
{
    changed = YES;
    char * Buffer = (char *)[tag bytes];
    Buffer [124] = 0;
    return [self setFieldWithString:Comment offset:CommentOffset length:CommentLength];
}

-(BOOL)setTrack:(int)Track
{
    char * Buffer = (char *)[tag bytes];
    if (Buffer == NULL) return NO;
    changed = YES;
    char test  = (char) ((unsigned)Track & 0xff); 
    Buffer[id3TagLength - TrackOffset] = test;
    
    return YES;
}

-(BOOL)setGenre:(int)Genre
{
    changed = YES;
    return [self setFieldWithNumber:Genre offset:GenreOffset length:GenreLength];
}

- (void)dealloc
{
    if (tag != NULL) 
        if ([tag retainCount]) [tag release];
    if (path != NULL) 
        if ([path retainCount]) [path release];
    if (errorDescription != NULL) 
        if ([errorDescription retainCount]) [errorDescription release];
    [super dealloc];
}
@end
