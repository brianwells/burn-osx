//
//  id3Tags.m
//  id3Tag
//
//  Created by Chris Drew on Sat Nov 02 2002.
//  Copyright (c) 2002 __MyCompanyName__. All rights reserved.
//

#ifdef __APPLE__
#import "id3V2Tag.h"
#import "zlib.h"
#import <AppKit/NSImage.h>
#import "V20FrameSet.h"
#import "V23FrameSet.h"
#import "V24FrameSet.h"
#else
#include "id3V2Tag.h"
#include "zlib.h"
#include "V20FrameSet.h"
#include "V23FrameSet.h"
#include "V24FrameSet.h"

#include <Foundation/NSArray.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSData.h>
#include <Foundation/NSFileHandle.h>
#include <Foundation/NSFileManager.h>

#include <AppKit/NSImage.h>
#endif


@implementation id3V2Tag
-(id)initWithFrameDictionary:(NSDictionary *)Dictionary
{
    if (!(self = [super init])) return self;
    
    //ID3 tag header variables
    present = NO;
    majorVersion = 0;
    minorVersion = 0;
    flag = 0;
    tagLength = 0;
    paddingLength = 0;
    positionInFile = 0;
    frameSetLength = 0;
    tagChanged = 0;
    atStart = YES;
    
    //Parsing properties
    exhastiveSearch = NO;
    
    //storage for tag
    frameSet = NULL;  // stores the frame set
    extendedHeader = NULL;
    
    //tag contents variables 
    extendedHeaderPresent = 0; // YES if Tag has an extended header
    
    // file properties
    path = NULL;
    fileSize = 0;
    
    frameSetDictionary = [Dictionary copy];
	
    //error variables
    errorNo = 0 ;
    errorDescription = NULL;
    
    return self;
}

-(BOOL)openPath:(NSString *)Path
{
    id old = path;
    path = [Path copy];
    if (old != NULL) [old release];
    //ID3 tag header variables
    present = NO;
    majorVersion = 0;
    minorVersion = 0;
    flag = 0;
    tagLength = 0;
    paddingLength = 0;
    positionInFile = 0;
    frameSetLength = 0;
    tagChanged = 0;
    
    //Parsing properties
    exhastiveSearch = NO;
    
    //tag contents variables 
    extendedHeaderPresent = 0; // YES if Tag has an extended header
    
    // file properties
    fileSize = 0;
    
    //error variables
    errorNo = 0;
    if (errorDescription != NULL) [errorDescription release];
       errorDescription = NULL;
       
	if (extendedHeader != NULL) [extendedHeader release];
        extendedHeader = NULL;
        
    if (frameSet != NULL) [frameSet release];
        frameSet = NULL;
    
    [self getTag];
    return YES;
}

-(BOOL)getTag
{
    int bufferSize = 1024; // 1k data buffer
    int position = 0; // current postion in file
    int start = 0;
    int offset = 0;
    
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    NSMutableData * v2Tag;
    
    NSFileHandle * file = [NSFileHandle fileHandleForReadingAtPath:path];

    if (file == NULL)
    {
		#if MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_X_VERSION_10_4
        NSLog(@"Can not open file :%s",[path cString]);
		#else
		NSLog(@"Can not open file :%s",[path cStringUsingEncoding:NSUTF8StringEncoding]);
		#endif
        return NO;
    }

    BOOL headerFound = NO;
    fileSize = [file seekToEndOfFile];
    
    
    if (exhastiveSearch) bufferSize = 8192; // make storage buffer large if exhastively searching the file.
    
    if (fileSize < bufferSize) bufferSize = fileSize;
    
    for (position = 0; position < fileSize; position += bufferSize - 9 - 6) // header size = 9 , eHeader =6
    { // try to find a id3 v2 tag grabs file data and scans for header.
        
        [file seekToFileOffset:position];
        v2Tag = (NSMutableData *) [file readDataOfLength: bufferSize];
        
        if ((start = [self scanForHeader:v2Tag]) >= 0)
        {
            if (tagLength + start + position > fileSize) {
				NSLog(@"Problem detected when parsing v2 tag: tag length indicates that tag extends beyond end of file, guessing tag length");
				tagLength = fileSize - start - position;  // if tag is longer that file trunckate tag length to  fileSize - start - position
			}
			
			positionInFile = start + position;
            headerFound = YES;
            present = YES;
            int frameStartAt = 10; // 10 = tag header length
            int extendedHeaderLength = 0;
            if ([self extendedHeader])  // check for an extended header
            {
                extendedHeaderPresent = YES;
				extendedHeaderLength = [self readPackedLengthFrom:((char *)[v2Tag bytes] + start + 10)]; // 10 = tag header length
				if (extendedHeaderLength > tagLength - 14) { // test to see that extended header length is a sensible value,  14 = 10 tag header + 4 extended header length bytes
					NSLog(@"Problem detected when parsing v2 tag: extendedHeaderLength > tag length, guessing extended header length");
					extendedHeaderLength = tagLength - 14;  // 14 = 10 tag header + 4 extended header length bytes
				}
				extendedHeaderLength += 4;  // add 4 byte for the 4 header length bytes
				frameStartAt += extendedHeaderLength;
				[file seekToFileOffset:position+start+14];
				extendedHeader = (NSMutableData *) [[file readDataOfLength: extendedHeaderLength-4] retain];
				[self parseExtendedHeader:extendedHeader];
            }    
            // get the frameSet
            if (start + 10 + tagLength > bufferSize) {
				[file seekToFileOffset:position+start+extendedHeaderLength+10]; 
                v2Tag = (NSMutableData *) [file readDataOfLength: tagLength - extendedHeaderLength];
                offset = extendedHeaderLength;
            } else {
                offset = start + 10 + extendedHeaderLength;
            }
            if ([self tagUnsynch]) 
            {
                v2Tag = [self desynchData:v2Tag offset:offset];
                offset = 0;
            }
            // create a processing object for the tag version
           
             switch (majorVersion)
            {
                case 0	: {
                                frameSet = [[NSMutableDictionary alloc] initWithCapacity:10];
                                V20FrameSet* tempFrameSet = [[V20FrameSet alloc] init:v2Tag version:minorVersion validFrameSet:NULL frameSet:frameSet offset:offset];
                                frameSetLength = [tempFrameSet getFrameSetLength];
                                [tempFrameSet release];
                                break;
                          }
                case 1	: {
                                frameSet = [[NSMutableDictionary alloc] initWithCapacity:10];
                                V20FrameSet* tempFrameSet = [[V20FrameSet alloc] init:v2Tag version:minorVersion validFrameSet:NULL frameSet:frameSet offset:offset];
                                frameSetLength = [tempFrameSet getFrameSetLength];
                                [tempFrameSet release];
                                break;
                          }
                case 2	: {
                                frameSet = [[NSMutableDictionary alloc] initWithCapacity:10];
                                V20FrameSet* tempFrameSet = [[V20FrameSet alloc] init:v2Tag version:minorVersion validFrameSet:NULL frameSet:frameSet offset:offset];
                                frameSetLength = [tempFrameSet getFrameSetLength];
                                [tempFrameSet release];
                                break;
                          }
                case 3	: {
                                frameSet = [[NSMutableDictionary alloc] initWithCapacity:10];
                                V23FrameSet *tempFrameSet = [[V23FrameSet alloc] init:v2Tag version:minorVersion  validFrameSet:NULL frameSet:frameSet offset:offset];
                                frameSetLength = [tempFrameSet getFrameSetLength];
                                [tempFrameSet release];
                                break;
                          }
                case 4	: {
                                frameSet = [[NSMutableDictionary alloc] initWithCapacity:10];
                                V24FrameSet *tempFrameSet = [[V24FrameSet alloc] init:v2Tag version:minorVersion  validFrameSet:NULL frameSet:frameSet offset:offset];
                                frameSetLength = [tempFrameSet getFrameSetLength];
                                [tempFrameSet release];
                                break;
                          }
                default	: 
                            {
                                [file closeFile];
                                [pool release];
                                return NO;
                            }
            }
        }
        if (!exhastiveSearch) break;
    }
    paddingLength = tagLength - frameSetLength;
    [file closeFile];
    [pool release];
    if (headerFound) return YES;
    return NO;
}

- (NSMutableData *)desynchData:(NSData *)Data offset:(int)Offset
{ // desynches a NSData object  the returned object have been retained and the receive needs to release the object once done with the object.
    int oldLength = [Data length];
    char * Buffer = (char *)[Data bytes] + Offset;
    NSMutableData * newBuffer = [[NSMutableData dataWithLength: oldLength] retain];
    unsigned char * tempPointer = (unsigned char*) [newBuffer bytes];
    int count = 0;
    int i;
    
    for (i = 0; i < oldLength; i ++) {
        tempPointer[i] = Buffer[i];
        if (255 == (unsigned char) Buffer[i+count]) {
            count++;
            i++;
        }
    }
    [newBuffer setLength:oldLength - count];
    return newBuffer;
}

- (int)readPackedLengthFrom:(char *)Bytes
{
    unsigned int val = 0;
    int i;
    const int MAXVAL = 268435456; //2^28
    // For each byte of the first 4 bytes in the string...
    
    for (i = 0; i < 4; ++i)
    {// ...append the last 7 bits to the end of the temp integer...
        val = val * 128;
        val += Bytes[i];
    }
    if (val > MAXVAL) val = MAXVAL;
    return (int) val;
}

-(int)scanForHeader:(NSData *)Data
{
    int i;
    char * Buffer = (char *)[Data bytes];
    for (i = 0 ; i < ([Data length] - 9); i++) // header is 10 bytes in size
    {
        // finds header and reads header
        if ((Buffer[i]=='I')&&(Buffer[i+1]=='D')&&(Buffer[i+2]=='3'))
        {
            majorVersion = Buffer[i+3];
            minorVersion = Buffer[i+4];
            flag = Buffer[i+5];
            tagLength = [self readPackedLengthFrom: Buffer + i + 6];
            // finds tag length from header
            return i;
        }
    }
    return -1;
}

-(BOOL)parseExtendedHeader:(NSData *)Header
{
/*  Extended header format 
    
    Extended header size   4 * %0xxxxxxx
    Number of flag bytes       $01
    Extended Flags             $xx 
*/
    return YES;
}

-(int)getPaddingLength
{
    return tagLength - frameSetLength;
}

-(id)getFramesTitled:(NSString *)Name
{
    return [frameSet objectForKey:Name];
}

// general information
-(int)tagVersion
{
    return majorVersion;
}

-(BOOL)tagPresent
{
    return present;
}

// id3V2 tag editing
-(BOOL)dropTag:(BOOL)NewTag
{
    if (!present) return NO;
    if (positionInFile > fileSize) return NO;
    NSMutableString * writePath = [NSMutableString stringWithString:path];
    NSDictionary *fileAttributes;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    fileAttributes = [fileManager fileSystemAttributesAtPath:writePath];
    
    if (![fileManager isWritableFileAtPath:writePath]) return NO;
    if (![fileManager isDeletableFileAtPath:writePath]) return NO;
    
    //open unique file based on file name with .temp extention added
    while ([fileManager fileExistsAtPath:writePath]) [writePath appendString:@".temp"];
    [fileManager createFileAtPath:writePath contents:NULL attributes:fileAttributes];
    
    NSFileHandle *sourceFile = [NSFileHandle fileHandleForReadingAtPath: path];
    NSFileHandle *file = [NSFileHandle fileHandleForWritingAtPath: writePath];
    
    int i = 0;
    if (positionInFile>0)
    {	
        i = remainder(positionInFile,4096);
        [file writeData:[sourceFile readDataOfLength: i]];

        while (i <  positionInFile)
        {
            [file writeData:[sourceFile readDataOfLength: 4096*100]];
            i +=4096*100;
        }
    }
    
    i += tagLength;
    while (i <  fileSize)
    {
        [file writeData:[sourceFile readDataOfLength: 4096*100]];
        i +=4096*100;
    }
    
    fileSize = [file seekToEndOfFile];
    tagLength = 0;
    positionInFile = 0;
    present = NO;
    if (NewTag)
    {
            [self newTag:majorVersion minor:minorVersion];
    }
    [file closeFile];
    [sourceFile closeFile];
    [file release];
    [fileManager removeFileAtPath:path handler:NULL];
    [fileManager movePath:writePath toPath:path handler:NULL];
    [fileManager removeFileAtPath:writePath handler:NULL];
    return YES;
}

-(BOOL)newTag:(int)MajorVersion minor:(int)MinorVersion {
    majorVersion = MajorVersion;
    minorVersion = MinorVersion;
    flag = 0;    
    
    if (extendedHeader != NULL) [extendedHeader release];
    extendedHeader = NULL;
    if (frameSet != NULL) [frameSet release];
    frameSet = NULL;
    frameSetLength = 0;
    paddingLength = 2048; 
    frameSet = [[NSMutableDictionary alloc] initWithCapacity:9];
    return YES;
}

-(BOOL)setPath:(NSString *)Path {
	[path release];
	path = [Path copy];
	return YES;
}

-(BOOL)writeTag
{
    if (!tagChanged) return YES;  // if file unchanged do nothing
    
    BOOL repad = NO;
    paddingLength = tagLength - frameSetLength;
    if (paddingLength < (int) fileSize/100000)
    { 
        paddingLength = 1024;
        repad = YES;
    }
    
    // gets the files attributes and checks that it is writeable
    NSMutableString * writePath = [[[NSMutableString alloc] initWithString:path] autorelease];
    NSDictionary *fileAttributes;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    fileAttributes = [fileManager fileSystemAttributesAtPath:writePath];
    if (![fileManager isWritableFileAtPath:writePath])
    {
		#if MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_X_VERSION_10_4
        NSLog(@"File : %s is not writable",[path lossyCString]);
		#else
		NSLog(@"File : %s is not writable",[path cStringUsingEncoding:NSUTF8StringEncoding]);
		#endif
        return NO;
    }
    
    if (positionInFile > 0) 
    { // lib will always prepend the file so if tag is not at start we  strip the tag and write a new tag.
        [self dropTag:NO]; 
        repad = YES;
    }
    
    if (repad)
    {
        if (![fileManager isDeletableFileAtPath:writePath])
        {
			#if MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_X_VERSION_10_4
            NSLog(@"Can't repad: File %s is not deleteable", [path lossyCString]);
			#else
			NSLog(@"Can't repad: File %s is not deleteable", [path cStringUsingEncoding:NSUTF8StringEncoding]);
			#endif
            return NO;
        }
        //open unique file based on file name with .temp extention added
        while ([fileManager fileExistsAtPath:writePath]) [writePath appendString:@".temp"];
        [fileManager createFileAtPath:writePath contents:NULL attributes:fileAttributes];
    }

    // write header to file
    NSFileHandle *file = [NSFileHandle fileHandleForWritingAtPath: writePath];
    [file writeData:[self renderHeader]];
	
	// write the extended header to the file if present
	if (extendedHeaderPresent) [file writeData:[self renderExtendedHeader]];
    //write the frame set
    
    NSEnumerator *enumerator = [frameSet objectEnumerator];
    id value;
        
    while ((value = [enumerator nextObject])) 
    {
	int maxCount = [value count];
	int count;
	
	for (count = 0; count < maxCount; count ++)
	    [file writeData:[[value objectAtIndex:count] getCompleteRawFrame]];
    }
        
    //clear the padding space
    NSData *paddingData = [NSMutableData dataWithLength:paddingLength];
    [file writeData:paddingData];

    if (repad) 
    {
        NSFileHandle *sourceFile = [[NSFileHandle fileHandleForReadingAtPath: path] retain];
        // jump over the old tag and start appending the file data to the new file.
        if (present) [sourceFile seekToFileOffset:tagLength+10+positionInFile];
        
        
        int i = 0;
        while (i <  fileSize)
        {
            NSAutoreleasePool *pool = [NSAutoreleasePool new];
            [file writeData:[sourceFile readDataOfLength: 4096*100]];
            [pool drain];
            i +=4096*100;
        }
        fileSize = [file seekToEndOfFile]; 
        [file closeFile];
        [sourceFile closeFile];
        [fileManager removeFileAtPath:path handler:NULL];
        [fileManager movePath:writePath toPath:path handler:NULL];
        [fileManager removeFileAtPath:writePath handler:NULL];
    } else 
    {
        [file closeFile];
    }
    present = YES;
    positionInFile = 0;
    tagLength = [self tagLength];
    return YES;
}

-(BOOL)dropFrame:(NSString *)Name frame:(int)index
{
    if (index < 0) // if index is -ve then remove all frames
    {
        id anObject = [frameSet objectForKey:Name];
		if (anObject != NULL){
			// first remove the frameSetLength by the size of the frames that you will be deleting
			int count = [anObject count];
			int i;
			for (i=0; i < count;i ++) {
				frameSetLength -= [(id3V2Frame *)[anObject objectAtIndex:i] length];
			}
	    // then delete the old frame
	    [frameSet removeObjectForKey:Name];
		}
		return YES;
    }
    
    id anObject = [frameSet objectForKey:Name];
    if (anObject == NULL) return YES;    
    int count = [anObject count];
    if (count < index) index = count;
    frameSetLength -= [(id3V2Frame *)[anObject objectAtIndex:index] length];
    [anObject removeObjectAtIndex:index];
	if ([anObject count] <= 0) [frameSet removeObjectForKey:Name];
    return YES;
}

-(BOOL)dropFrame:(id3V2Frame *)Frame
{
    if (Frame == 0) return NO;
	
    id anObject = [frameSet objectForKey:[Frame getFrameID]];
    if (anObject == NULL) return YES;
	int index = [anObject indexOfObject:Frame];
    frameSetLength -= [(id3V2Frame *)[anObject objectAtIndex:index] length];
    [anObject removeObjectAtIndex:index];
	if ([anObject count] <= 0) [frameSet removeObjectForKey:[Frame getFrameID]];
    return YES;
}

-(BOOL)addUpdateFrame:(id3V2Frame *)Frame replace:(BOOL)Replace frame:(int)index
{
    if (Frame == NULL) return NO;
    NSString * Name = [Frame getFrameID];
    if (Replace) [self dropFrame:Name frame:index];
    tagChanged = YES;
    frameSetLength += [Frame length];
    id anObject = [frameSet objectForKey:Name];
	if (anObject != NULL) {
		if ([anObject isKindOfClass:[NSMutableArray class]]) {
			int count = [anObject count];
			if (index >= count) [anObject addObject:Frame];
			else {
				if (index < 0) index = 0;
				[anObject insertObject:Frame atIndex:index];
			}
		} else {
			NSMutableArray *tempArray = [NSMutableArray arrayWithCapacity:2];
			[tempArray addObject:anObject];
			[tempArray addObject:Frame];
			[frameSet setObject:tempArray forKey:Name];
		}
	}
    else {
		NSMutableArray *tempArray = [NSMutableArray arrayWithCapacity:2];
		[tempArray addObject:Frame];
		[frameSet setObject:tempArray forKey:Name];
    }
    return YES;
}

-(BOOL)setFrames:(NSMutableArray *)newFrames
{
    if ((newFrames == NULL)||([newFrames count] < 1)) return NO;
    // get the frame ID from the first frame in the list. all frame should be the same type
    NSString * Name = [[newFrames objectAtIndex:0] getFrameID];
    
    // get all old frames from the dictionary and delete
    if ([self dropFrame:Name frame:-1] == NO) return NO;
    
    // add the new frames, then increase the frameSetLength by the frame length in the array 
    [frameSet setObject:newFrames forKey:Name];
    NSMutableArray * anObject = [frameSet objectForKey:Name];
    if (anObject != NULL) {
		int i;
		int count = [anObject count];
		for (i=0; i < count ;i ++) {
			frameSetLength += [(id3V2Frame *)[anObject objectAtIndex:i] length];
		}
    }
	tagChanged = YES;
    return YES;
}

-(NSData *)renderHeader
{
    NSMutableData * header = [NSMutableData dataWithCapacity:10];
    [header appendBytes:"ID3" length:3];
    char tempDataPointer[] = { (char) majorVersion, (char) minorVersion, (char) flag};
    [header appendBytes: tempDataPointer length:3]; 
    [header appendData: [self writePackedLength:[self tagLength]]];
    return header;
}

-(NSData *)renderExtendedHeader {
	NSMutableData * header = [NSMutableData dataWithCapacity:10];
    int length = [extendedHeader length];
	int mask = 0xff;
	
    int Bytes3 = (length & mask);
    length = length >> 8;
    int Bytes2 = (length & mask);
    length = length >> 8;
    int Bytes1 = (length & mask);
    length = length >> 8;
    int Bytes0 = (length & mask);
	
    char tempDataPointer[] = { (char) Bytes0, (char) Bytes1, (char) Bytes2, (char) Bytes3};
    [header appendBytes: tempDataPointer length:4]; 
    [header appendData: extendedHeader];
    return header;
}

//  ?? need to clean up this section I don't have a good calculator handy

-(BOOL)extendedHeader
{
    return (((majorVersion == 3)||(majorVersion ==4))&&(flag & 64));
}

-(BOOL)tagUnsynch
{
    return (flag & 128);
}

-(BOOL)compressTag
{
    return ((majorVersion <3)&&(flag & 64));
}

-(BOOL)footer
{
    return ((majorVersion ==4)&&(flag & 32));
}

-(BOOL)setExtendedHeader:(BOOL)Flag
{
    if ((majorVersion == 3)||(majorVersion ==4))
    {
        if (Flag) 
        {
            flag = flag | 64;
            
        }
        else
        {
            flag = flag & (255 ^ 64);
            [extendedHeader release];
            extendedHeader = NULL;
        }
        return YES;
    } else return NO;
}

-(BOOL)setTagUnsynch:(BOOL)Flag
{
    if (Flag) flag = flag | 128;
    else flag = flag & (255 ^ 128);
    return YES;
}

-(BOOL)setCompressTag:(BOOL)Flag
{
    if (majorVersion <3)
    {
        if (Flag) flag = flag | 64;
        else flag = flag & (255 ^ 64);
        return YES;
    } else return NO;
}

-(BOOL)setFooter:(BOOL)Flag
{
    if  (majorVersion ==4)
    {
        if (Flag) flag = flag | 32;
        else flag = flag & (255 ^ 32);
        return YES;
    } else return NO;
}

-(NSData *)writePackedLength:(int)Length
{
    int shift;
    int addressSize;
    char mask;
     
    shift = 7;
    addressSize = 4;
    mask = 0x7f;
            
    NSMutableData *Temp  = [NSMutableData dataWithLength:addressSize];
    char * Bytes = (char *) [Temp bytes];
    
    Bytes[3] = (Length & mask);
    Length = Length >> shift;
    Bytes[2] = (Length & mask);
    Length = Length >> shift;
    Bytes[1] = (Length & mask);
    Length = Length >> shift;
    Bytes[0] = (Length & mask);
    if (Length < 256) return Temp;
    return NULL;
}

- (int)tagPositionInFile
{
    return positionInFile;
}

-(int)tagLength
{  // this is actually the tag length less the header length
    return (extendedHeaderPresent ? [extendedHeader length] + 4 : 0) + frameSetLength + paddingLength + ([self footer]?10:0);
}

-(void)dealloc
{
    if (frameSet != NULL) [frameSet release]; 
	if (frameSetDictionary != NULL) [frameSetDictionary release]; 
    if (path != NULL) [path release];
    if (extendedHeader != NULL) [extendedHeader release];
    if (errorDescription != NULL) [errorDescription release];
	[super dealloc];
}

// set standard tag properties
-(BOOL)setContent:(NSArray *)Content  forFrame:(NSString *)IDAlias replace:(BOOL)Replace {
	NSString * IDName = NULL;
	NSDictionary * frameRecord = NULL;
	BOOL multi = YES;
	NSMutableArray * frames = [NSMutableArray arrayWithCapacity:2];  // 2 is a good a number as any
	
	[self getActualFrameID:&IDName andRecord:&frameRecord forID:IDAlias];
	if (IDName == NULL) {
		NSLog(@"Method setContent: forFrame replace: Could not resolve correct frame ID for :%@", IDAlias);
		return NO;
	}
	
	if (frameRecord == NULL) {
		NSLog(@"Method setContent: forFrame replace: Could not resolve correct frame ID library record for :%@", IDName);
		return NO;
	}
	
	if (![frameRecord objectForKey:@"multi"]) multi = NO; // check to see if you allowed to have more than one frame
	int i,y;
	y = [Content count];
	if (y>0 && !multi) y = 1; // if not allowed mulitple frames set y = 1;

	for (i = 0; i < y; i++) {
		id3V2Frame * temp = [[id3V2Frame alloc] init:IDName firstflag:0 secondFlag:0 version:majorVersion];
		if ([[frameRecord objectForKey:@"text"] boolValue] == NO) [temp appendDataToFrame:[Content objectAtIndex:i] newFrame:YES];
		else [temp writeTextFrame:[Content objectAtIndex:i] coding:YES];
		[frames addObject:temp];
		[temp release];
	}
	
	if (Replace) {
		id object = [self getFramesTitled:IDName];
		if (multi) {  // only add append old frames if multiple frames are allowed
			if ([object isKindOfClass:[NSMutableArray class]]) [frames addObjectsFromArray:object];
			else if (multi) [frames insertObject:object atIndex:0];
		}
	}
	return [self setFrames:frames];
}

-(BOOL)setTitle:(NSString *)Title
{
	return [self setContent:[NSArray arrayWithObject:Title] forFrame:@"TT2" replace:YES];
/*
	NSString *tempString;
	switch (majorVersion)
	{
		case 0	 	: tempString = @"TT2";
					break;
		case 1	 	: tempString = @"TT2";
					break;
		case 2	 	: tempString = @"TT2";
					break;
		case 3		: tempString = @"TIT2";
					break;
		case 4		: tempString = @"TIT2";
					break;
		default	: return NO;
	}
        return [self addUpdateFrame:[[[id3V2Frame alloc] initTextFrame:tempString firstflag:0 secondFlag:0 text:Title withEncoding:0 version:majorVersion]autorelease] replace:YES frame:0]; */
}

-(BOOL)setArtist:(NSString *)Artist {
	NSString *tempString;
	switch (majorVersion)
	{
        case 0	 	: tempString = @"TP1";
                        break;
        case 1	 	: tempString = @"TP1";
                        break;
        case 2	 	: tempString = @"TP1";
                        break;
        case 3		: tempString = @"TPE1";
                        break;
        case 4		: tempString = @"TPE1";
                        break;
        default	: return NO;
	}
	return [self addUpdateFrame:[[[id3V2Frame alloc] initTextFrame:tempString firstflag:0 secondFlag:0 text:Artist withEncoding:([Artist canBeConvertedToEncoding:NSASCIIStringEncoding]?0:1) version:majorVersion]autorelease] replace:YES frame:0];
}

-(BOOL)setAlbum:(NSString *)Album {
	NSString *tempString;
	switch (majorVersion)
	{
        case 0	 	: tempString = @"TAL";
                        break;
        case 1	 	: tempString = @"TAL";
                        break;
        case 2	 	: tempString = @"TAL";
                        break;
        case 3		: tempString = @"TALB";
                        break;
        case 4		: tempString = @"TALB";
                        break;
        default	: return NO;
	}
	return [self addUpdateFrame:[[[id3V2Frame alloc] initTextFrame:tempString firstflag:0 secondFlag:0 text:Album withEncoding:([Album canBeConvertedToEncoding:NSASCIIStringEncoding]?0:1) version:majorVersion] autorelease] replace:YES frame:0];
}

-(BOOL)setYear:(int)Year {
	NSString *tempString;
	switch (majorVersion) {
        case 0	 	: tempString = @"TYE";
                        break;
        case 1	 	: tempString = @"TYE";
                        break;
        case 2	 	: tempString = @"TYE";
                        break;
        case 3		: tempString = @"TYER";
                        break;
        case 4		: tempString = @"TDRC";
                        break;
        default	: return NO;
	}
	return [self addUpdateFrame:[[[id3V2Frame alloc] initTextFrame:tempString firstflag:0 secondFlag:0 text:[[NSNumber numberWithInt:Year] stringValue] withEncoding:0 version:majorVersion] autorelease] replace:YES frame:0];
}

-(BOOL)setTrack:(int)Track totalTracks:(int)Total
{
	NSString *tempString;
    switch (majorVersion) {
        case 0	 	: tempString = @"TRK";
                        break;
        case 1	 	: tempString = @"TRK";
                        break;
        case 2	 	: tempString = @"TRK";
                        break;
        case 3		: tempString = @"TRCK";
                        break;
        case 4		: tempString = @"TRCK";
                        break;
        default	: return NO;
	}
	return [self addUpdateFrame:[[[id3V2Frame alloc] initTextFrame:tempString firstflag:0 secondFlag:0 text:[NSString stringWithFormat:@"%i/%i",Track,Total] withEncoding:0 version:majorVersion] autorelease] replace:YES frame:0];
}

-(BOOL)setDisk:(int)Disk totalDisks:(int)Total
{
	NSString *tempString;
	switch (majorVersion) {
        case 0	 	: tempString = @"TPA";
                        break;
        case 1	 	: tempString = @"TPA";
                        break;
        case 2	 	: tempString = @"TPA";
                        break;
        case 3		: tempString = @"TPOS";
                        break;
        case 4		: tempString = @"TPOS";
                        break;
        default	:return NO;
	}
	return [self addUpdateFrame:[[[id3V2Frame alloc] initTextFrame:tempString firstflag:0 secondFlag:0 text:[NSString stringWithFormat:@"%i/%i",Disk,Total] withEncoding:0 version:majorVersion] autorelease] replace:YES frame:0];
}

-(BOOL)setGenreName:(NSArray *)GenreName {
    BOOL result = YES;
	NSString *tempString;
	switch (majorVersion) {
        case 0	 	: tempString = @"TCO";
                        break;
        case 1	 	: tempString = @"TCO";
                        break;
        case 2	 	: tempString = @"TCO";
                        break;
        case 3		: tempString = @"TCON";
                        break;
        case 4		: tempString = @"TCON";
                        break;
        default	: return NO;
	}
	id3V2Frame * frame = [[id3V2Frame alloc] init:tempString firstflag:0 secondFlag:0 version:majorVersion];
	[frame writeTextFrame:[frame genreStringFromArray:GenreName] coding:1];
	result = [self addUpdateFrame:frame replace:YES frame:0];
	[frame release];
	return result;
}

-(BOOL)setComments:(NSString *)Comments
{
    BOOL results = YES;
    NSString * comments = NULL;
    int i;
    int index = -1;
	NSString *tempString = @"";
	switch (majorVersion) {
        case 0	 	: tempString = @"COM";
                        break;
        case 1	 	: tempString = @"COM";
                        break;
        case 2	 	: tempString = @"COM";
                        break;
        case 3	 	: tempString = @"COMM";
                        break;
        case 4	 	: tempString = @"COMM";
                        break;
        default	: return NO;
	}
	id3V2Frame * frame = [[id3V2Frame alloc] init:tempString firstflag:0 secondFlag:0 version:majorVersion];
	[frame writeCommentToFrame:Comments language:@"eng" coding:![Comments canBeConvertedToEncoding:NSASCIIStringEncoding]];
        
	// need to check for iTunes equalisation comment frames 
	NSMutableArray *tempArray = [self getFramesTitled:tempString];
	if (tempArray)
	for (i = 0; i < [tempArray count]; i++)
	{
	    BOOL Flag = NO;
	    comments = [[tempArray objectAtIndex:i] getShortCommentFromFrame];
	    NSRange range = [comments rangeOfString:@"iTunNORM"];
	    if ((range.location == 0) && (range.length == 8)) Flag = YES;
	    if (!Flag)
	    {
			comments = [[tempArray objectAtIndex:i] getShortCommentFromFrame];
			range = [comments rangeOfString:@"iTunes_CDDB_IDs"];
			if ((range.location == 0) && (range.length == 15)) Flag = YES;
		}
		if (!Flag) {
			index = i;
			i = [tempArray count];
		}
	}
	if (index == -1) // found only iTunes eq comments frames hence add new comment field
	    results = [self addUpdateFrame: frame replace:NO frame:[tempArray count]+1];
	    // found first user readable comment field
	else results = [self addUpdateFrame: frame replace:YES frame:index]; 
        [frame release];
	return results;
}

-(BOOL)setImages:(NSMutableArray *)Images {
    if (Images == NULL) return NO;
    int count = [Images count];
	NSString *tempString;
	switch (majorVersion) {
        case 0	 	: tempString = @"PIC";
                        break;
        case 1	 	: tempString = @"PIC";
                        break;
        case 2	 	: tempString = @"PIC";
                        break;
        case 3	 	: tempString = @"APIC";
                        break;
        case 4	 	: tempString = @"APIC";
                        break;
        default	:       return NO;
	}
	
	if ([Images count] == 0)
	    return [self dropFrame:tempString frame:-1]; // if frame <0 all frames of the name tempString are removed
	else {
	    NSMutableArray * tempArray = [NSMutableArray arrayWithCapacity:count];
	    int i;
	    for (i = 0; i < count; i ++) {
			id3V2Frame * frame = [[id3V2Frame alloc] init:tempString firstflag:0 secondFlag:0 version:majorVersion];
			[frame writeImage:[Images objectAtIndex:i]];
			[tempArray addObject:frame];
			[frame release];
	    }
	    if ([tempArray count] > 0) return [self setFrames:tempArray];
	    return NO;
	}
}

-(BOOL)setComposer:(NSString *)Text {
    BOOL results = YES;
    if (Text == NULL) return NO;
	NSString *tempString;
	switch (majorVersion) {
	    case 0      : tempString = @"TCM";
                        break;
	    case 1      : tempString = @"TCM";
                        break;
	    case 2      : tempString = @"TCM";
                        break;
	    case 3      : tempString = @"TCOM";
                        break;
	    case 4      : tempString = @"TCOM";
                        break;
        default	:       return NO;
	}
	results = [self addUpdateFrame:[[[id3V2Frame alloc] initTextFrame:tempString firstflag:0 secondFlag:0 text:Text withEncoding:([Text canBeConvertedToEncoding:NSASCIIStringEncoding]?0:1) version:majorVersion]autorelease] replace:YES frame:0];
    return results;
}

// get standard properties from Tag.
-(NSString *)getTitle
{
    NSString * title = NULL;
    id anObject;
    
    if (present==YES)
    {
        if(majorVersion < 3)
        {
            if (anObject = [self getFirstFrameNamed:@"TT2"]) title = [anObject getTextFromFrame];
        } else
        if (majorVersion == 3)
        {	
            if (anObject = [self getFirstFrameNamed:@"TIT2"]) title = [anObject getTextFromFrame];
        } else
        if (majorVersion == 4)
        {	
        if (anObject = [self getFirstFrameNamed:@"TIT2"]) title = [anObject getTextFromFrame];
        }
    }
    return title;
}

-(NSString *)getArtist
{
    NSString * artist = NULL;
    id anObject;
    
    if (present==YES)
    {
        if(majorVersion < 3)
        {
            if (anObject = [self getFirstFrameNamed:@"TP1"]) artist = [anObject getTextFromFrame];
        } else
        if (majorVersion == 3)
        {	
            if (anObject = [self getFirstFrameNamed:@"TPE1"]) artist = [anObject getTextFromFrame];
        } else
        if (majorVersion == 4)
        {	
            if (anObject = [self getFirstFrameNamed:@"TPE1"]) artist = [anObject getTextFromFrame];
        }
	}    
    return artist;
}

-(NSString *)getAlbum
{
    NSString * album = NULL;
    id anObject;
    
    if (present==YES)
    {
        if(majorVersion < 3)
        {
            if (anObject = [self getFirstFrameNamed:@"TAL"]) album = [anObject getTextFromFrame];
        } else
        if (majorVersion == 3)
        {	
            if (anObject = [self getFirstFrameNamed:@"TALB"]) album = [anObject getTextFromFrame];
        } else
        if (majorVersion == 4)
        {	
            if (anObject = [self getFirstFrameNamed:@"TALB"]) album = [anObject getTextFromFrame];
        }
    }    
    return album;
}

-(int)getYear
{
    id anObject;

    if (present==YES)
    {
        if (majorVersion <= 2)
        {
            if (anObject = [self getFirstFrameNamed:@"TYE"])
            {
                NSString * yearString = [anObject getTextFromFrame];
                return [yearString intValue];
            }
        } else
        if (majorVersion == 3)
        { 
            if (anObject = [self getFirstFrameNamed:@"TYER"])
            {
                NSString * yearString = [anObject getTextFromFrame];
                return [yearString intValue];
            }
        } else
        if (majorVersion == 4)
        {    
            if (anObject = [self getFirstFrameNamed:@"TDRC"])
            {
                NSString * yearString = [anObject getTextFromFrame];
                NSArray *listItems = [yearString componentsSeparatedByString:@"-"];
                yearString = [listItems objectAtIndex:0];
                [listItems release];
                return [yearString intValue];
            }
        }
    }
    return -1;
}

-(int)getTrack
{
    int track = -1;
    id anObject;
   
    if (present==YES)
    {
        if (majorVersion <= 2)
        {
            if (anObject = [self getFirstFrameNamed:@"TRK"]) 
            {
                NSString * trackString = [anObject getTextFromFrame];
                track = [self numberInSetString: trackString];
            }
        } else 
        if (majorVersion == 3)
        {
            if (anObject = [self getFirstFrameNamed:@"TRCK"])
            {
                NSString * trackString = [anObject getTextFromFrame];
                track = [self numberInSetString: trackString];
            }
        } else
        if (majorVersion == 4)
        {
            if (anObject = [self getFirstFrameNamed:@"TRCK"])
            {
                NSString * trackString = [anObject getTextFromFrame];
                track = [self numberInSetString: trackString];
            }
        }
    }
    return track;
}

-(int)getTotalNumberTracks
{
    int tracks = -1;
    id anObject;
   
    if (present==YES)
    {
        if (majorVersion <= 2)
        {
            if (anObject = [self getFirstFrameNamed:@"TRK"]) 
            {
                NSString * trackString = [anObject getTextFromFrame];
                tracks = [self setSizeInSetString: trackString];
            }
        } else 
        if (majorVersion == 3)
        {
            if (anObject = [self getFirstFrameNamed:@"TRCK"])
            {
                NSString * trackString = [anObject getTextFromFrame];
                tracks = [self setSizeInSetString: trackString];
            }
        } else
        if (majorVersion == 4)
        {
            if (anObject = [self getFirstFrameNamed:@"TRCK"])
            {
                NSString * trackString = [anObject getTextFromFrame];
                tracks = [self setSizeInSetString: trackString];
            }
        }
    }
    return tracks;
}

-(int)getDisk
{
    int track = -1;
    id anObject;
   
    if (present==YES)
    {
        if (majorVersion <= 2)
        {
            if (anObject = [self getFirstFrameNamed:@"TPA"]) 
            {
                NSString * trackString = [anObject getTextFromFrame];
                track = [self numberInSetString: trackString];
            }
        } else 
        if (majorVersion == 3)
        {
            if (anObject = [self getFirstFrameNamed:@"TPOS"])
            {
                NSString * trackString = [anObject getTextFromFrame];
                track = [self numberInSetString: trackString];
            }
        } else
        if (majorVersion == 4)
        {
            if (anObject = [self getFirstFrameNamed:@"TPOS"])
            {
                NSString * trackString = [anObject getTextFromFrame];
                track = [self numberInSetString: trackString];
            }
        }
    }
    return track;
}

-(int)getTotalNumberDisks
{
    int Disks = -1;
    id anObject;
   
    if (present==YES)
    {
        if (majorVersion <= 2)
        {
            if (anObject = [self getFirstFrameNamed:@"TPA"]) 
            {
                NSString * trackString = [anObject getTextFromFrame];
                Disks = [self setSizeInSetString: trackString];
            }
        } else 
        if (majorVersion == 3)
        {
            if (anObject = [self getFirstFrameNamed:@"TPOS"])
            {
                NSString * trackString = [anObject getTextFromFrame];
                Disks = [self setSizeInSetString: trackString];
            }
        } else
        if (majorVersion == 4)
        {
            if (anObject = [self getFirstFrameNamed:@"TPOS"])
            {
                NSString * trackString = [anObject getTextFromFrame];
                Disks = [self setSizeInSetString: trackString];
            }
        }
    }
    return Disks;
}

-(NSArray *)getGenreNames
{
    NSArray * genreName = NULL;
    id anObject;
    
    if (present==YES)
    {
        if (majorVersion <= 2)
        {
            if(anObject = [self getFirstFrameNamed:@"TCO"]) genreName = [anObject genreArrayFromFrame];
        } else
        if (majorVersion == 3)
        {
            if(anObject = [self getFirstFrameNamed:@"TCON"]) genreName = [anObject genreArrayFromFrame];
        } else
        if (majorVersion == 4)
        {
            if(anObject = [self getFirstFrameNamed:@"TCON"]) genreName = [anObject genreArrayFromFrame];
        }
    }
    if ((genreName == NULL)||([genreName count] == 0)) return NULL;    
    return genreName;
}

-(NSString *)getComments
{
    NSString * comments = @"";
    NSMutableArray * tempArray = NULL;
    int i;
    if (present == YES)
    {
        if (majorVersion <= 2)
        {
            tempArray = [self getFramesTitled:@"COM"];
        } else
        if (majorVersion == 3)
        {
            tempArray = [self getFramesTitled:@"COMM"];
        } else
        if (majorVersion == 4)
        {
            tempArray = [self getFramesTitled:@"COMM"];
        }
	
		if (tempArray)
		for (i = 0; i < [tempArray count]; i++) {
			BOOL Flag = NO;
			comments = [[tempArray objectAtIndex:i] getShortCommentFromFrame];
			NSRange range = [comments rangeOfString:@"iTunNORM"];
			if ((range.location == 0) && (range.length = 8)) Flag = YES;
			if (!Flag) {
				range = [comments rangeOfString:@"iTunes_CDDB_IDs"];
				if ((range.location == 0) && (range.length = 15)) Flag = YES;
				if (!Flag) return [[tempArray objectAtIndex:i] getCommentFromFrame];
			}
		}
    }
    return NULL;
}

-(NSMutableArray *)getImage
{
    NSMutableArray * tempArray = [NSMutableArray arrayWithCapacity:3];
    NSMutableDictionary * tempDictionary = NULL;
    NSString * tempString = NULL;
    id anObject;
    int count;
    int maxCount;
    
    if (!present) return NULL;
    
	#if MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_X_VERSION_10_4
    if (majorVersion < 3) tempString = [NSString stringWithCString:"PIC"];
    if (majorVersion == 3) tempString = [NSString stringWithCString:"APIC"];
    if (majorVersion == 4) tempString = [NSString stringWithCString:"APIC"];
	#else
	if (majorVersion < 3) tempString = [NSString stringWithCString:"PIC" encoding:NSUTF8StringEncoding];
    if (majorVersion == 3) tempString = [NSString stringWithCString:"APIC" encoding:NSUTF8StringEncoding];
    if (majorVersion == 4) tempString = [NSString stringWithCString:"APIC" encoding:NSUTF8StringEncoding];
	#endif
    
    anObject = [frameSet objectForKey:tempString];
    
    if (anObject == NULL) return NULL;
    
    maxCount = [anObject count];
    for (count = 0; count < maxCount; count ++)
    {
        if (majorVersion < 3) tempDictionary = [self getImageFrom2Frame:[anObject objectAtIndex:count]];  // get the frame
        if ((majorVersion == 3)||(majorVersion == 4))  tempDictionary = [self getImageFrom3Frame:[anObject objectAtIndex:count]];  	// get the frame
        if (tempDictionary == NULL) NSLog(@"Failed to find a valid image in APIC frame");
        else [tempArray addObject:tempDictionary];
    }
    if ([tempArray count] < 1) return NULL;
    return tempArray;
}

-(NSString *)getComposer
{
    NSString * album = @"";
    id anObject;
    
    if (present==YES)
    {
        if(majorVersion < 3)
        {
            if (anObject = [self getFirstFrameNamed:@"TCM"]) album = [anObject getTextFromFrame];
        } else
        if (majorVersion == 3)
        {	
            if (anObject = [self getFirstFrameNamed:@"TCOM"]) album = [anObject getTextFromFrame];
        } else
        if (majorVersion == 4)
        {	
            if (anObject = [self getFirstFrameNamed:@"TCOM"]) album = [anObject getTextFromFrame];
        }
    }    
    return album;
}

-(NSMutableDictionary *)getImageFrom2Frame:(id3V2Frame *)frame
{
/*   Text encoding      $xx
     Image format       $xx xx xx
     Picture type       $xx
     Description        <textstring> $00 (00)
     Picture data       <binary data>
*/
    NSMutableDictionary * tempDictionary = [NSMutableDictionary dictionaryWithCapacity:3];
    NSBitmapImageRep * tempImage;
    NSData * tempImageData;
    NSString * Type;
    NSString * pictureType;
    NSString * Description;
    NSData * data = [frame getRawFrameData]; // extract the data from the frame
    const char * charPtr = (const char *) [data bytes];
    char textCoding = *charPtr;  // the first byte is the text coding for the description
    int i;
    
	#if MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_X_VERSION_10_4
    Type = [NSString stringWithCString:charPtr+1 length:3];  //FIX: Convert to real MIME type
	#else
	Type = [NSString stringWithCString:charPtr+1 encoding:NSUTF8StringEncoding];  //FIX: Convert to real MIME type
	#endif
            
    // get the picture type byte and convert into a information string;
    pictureType = [self decodeImageType:charPtr[4]];
    // scan for the end of the description

    for (i = 5; i < [data length] - 2; i++)  // find the end of the Description text 
    {
        if (charPtr[i] == '\0')
            if( textCoding==0 )
                break;
            else if( (i&1)==1 && charPtr[i+1] == '\0' )     // 1st byte of zero Unicode char
                break;
    }
    
    // create the description text string
    Description = [[[NSString alloc] initWithData:[NSData dataWithBytesNoCopy:(void *)charPtr+5 length: i-5 freeWhenDone:NO] encoding:(textCoding ?NSUnicodeStringEncoding :NSISOLatin1StringEncoding)] autorelease];
    
    // skip null byte(s)
    i++;
    if( textCoding )
        i++;

    // get the image 
    if (charPtr[i]=='\0') i++;
    tempImageData = [NSData dataWithBytes:(void *)charPtr+i length: [data length]-i];
    tempImage = [NSBitmapImageRep imageRepWithData:tempImageData];
    if (tempImage == NULL ) return NULL;
    [tempDictionary setObject:tempImage forKey:@"Image"];
    [tempDictionary setObject:tempImageData forKey:@"Image Data"];
    [tempDictionary setObject:pictureType forKey:@"Picture Type"];
    [tempDictionary setObject:Type forKey:@"Mime Type"];
    [tempDictionary setObject:Description forKey:@"Description"];
    return tempDictionary;
}

-(NSMutableDictionary *)getImageFrom3Frame:(id3V2Frame *)frame
{
/*   Text encoding      $xx
     MIME type          <text string> $00
     Picture type       $xx
     Description        <text string according to encoding> $00 (00)
     Picture data       <binary data>
*/    
    NSMutableDictionary * tempDictionary = [NSMutableDictionary dictionaryWithCapacity:3];
    NSBitmapImageRep * tempImage;
    NSData * tempImageData;
    NSString * pictureType;
    NSString * Type;
    NSString * Description;
    NSData * data = [frame getRawFrameData]; // extract the data from the frame
    const char * charPtr = (const char *) [data bytes];
    char textCoding = * charPtr;  // the first byte is the text coding for the description
    int i,y;
    
    for (i = 1 ; i < [data length] - 1; i++)  // find the end of the Description text 
    {
        if (charPtr[i] == '\0') break;
    }
    
	#if MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_X_VERSION_10_4
    Type = [NSString stringWithCString:charPtr+1 length:i];
	#else
	Type = [NSString stringWithCString:charPtr+1 encoding:NSUTF8StringEncoding];
	#endif
    
    i++;
    // get the picture type byte and convert into a information string;
    pictureType = [self decodeImageType:charPtr[i]];
    // scan for the end of the description
    i++;
    y=i;
    for (; i < [data length] - 2; i++)  // find the end of the Description text 
    {
        if ((charPtr[i] == '\0')&&((textCoding > 0 ? charPtr[i+1]: 1))) break;
    }
    
    // create the description text string
    i++;
    if (textCoding == 0)
    {
		#if MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_X_VERSION_10_4
        Description = [NSString stringWithCString:(void *)charPtr length:i-y];
		#else
		Description = [NSString stringWithCString:(void *)charPtr encoding:NSUTF8StringEncoding];
		#endif
    }
    else 
    {
        i++;
        Description = [[[NSString alloc] initWithData:[NSData dataWithBytesNoCopy:(void *)charPtr+y length: i-y freeWhenDone:NO] encoding:NSUTF8StringEncoding] autorelease];  //this is not the right encoding I will fix later
    // get the image 
    }
    
    if (charPtr[i]=='\0') i++;
    tempImageData = [NSData dataWithBytes:(void *)charPtr+i length: [data length]-i];
    tempImage = [NSBitmapImageRep imageRepWithData:tempImageData];
    if (tempImage == NULL ) return NULL;
    [tempDictionary setObject:tempImage forKey:@"Image"];
    [tempDictionary setObject:tempImageData forKey:@"Image Data"];
    [tempDictionary setObject:pictureType forKey:@"Picture Type"];
    [tempDictionary setObject:Type forKey:@"Mime Type"];
    [tempDictionary setObject:Description forKey:@"Description"];
    return tempDictionary;
}

-(id3V2Frame *)getFirstFrameNamed:(NSString *)Name
{
    id value = [self getFramesTitled:Name];
    if (value == NULL) return NULL;
    if ([value isKindOfClass:[NSMutableArray class]]) return [value objectAtIndex:0];
    else return value;
}

-(NSString *)decodeImageType:(int)encodedValue
{
    NSString * Type;
    switch (encodedValue)
    { // the string values are from the specification
        case 00 :   Type = [NSString stringWithString:@"Other"];
                    break;
        case 01 :   Type = [NSString stringWithString:@"32x32 pixels \'file icon\'"];
                    break;
        case 02 :   Type = [NSString stringWithString:@"Other file icon"];
                    break;
        case 03 :   Type = [NSString stringWithString:@"Cover (front)"];
                    break;
        case 04 :   Type = [NSString stringWithString:@"Cover (back)"];
                    break;
        case 05 :   Type = [NSString stringWithString:@"Leaflet page"];
                    break;
        case 06 :   Type = [NSString stringWithString:@"Media (e.g. label side of CD)"];
                    break;
        case 07 :   Type = [NSString stringWithString:@"Lead artist/lead performer/soloist"];
                    break;
        case 8 :    Type = [NSString stringWithString:@"Artist/performer"];
                    break;
        case 9 :    Type = [NSString stringWithString:@"Conductor"];
                    break;
        case 10 :   Type = [NSString stringWithString:@"Band/Orchestra"];
                    break;
        case 11 :   Type = [NSString stringWithString:@"Composer"];
                    break;
        case 12 :   Type = [NSString stringWithString:@"Lyricist/text writer"];
                    break;
        case 13 :   Type = [NSString stringWithString:@"Recording Location"];
                    break;
        case 14 :   Type = [NSString stringWithString:@"During recording"];
                    break;
        case 15 :   Type = [NSString stringWithString:@"During performance"];
                    break;
        case 16 :   Type = [NSString stringWithString:@"Movie/video screen capture"];
                    break;
        case 17 :   Type = [NSString stringWithString:@"A bright coloured fish"];
                    break;
        case 18 :   Type = [NSString stringWithString:@"Illustration"];
                    break;
        case 19 :   Type = [NSString stringWithString:@"Band/artist logotype"];
                    break;
        case 20 :   Type = [NSString stringWithString:@"Publisher/Studio logotype"];
                    break;
        default:    Type = [NSString stringWithString:@"Unknown"];
                    break;
    }
    return Type;
}

- (void) getActualFrameID:(NSString **)Name andRecord:(NSDictionary **)Record forID:(NSString *)ID {
	// The frame ID could be a v2.0, v2.3 or v2.4 frame ID.  Need to check if it is a valid frame type and if not try and convert it to a valid frame type.
	
	//First check the frame dictionary to see that frame ID if valid for v2 tag version. If it is not you try to find the appropriate frame ID by checking the frame compatability information stored in the frame dictionary.  If that doesn't work you then check if it exist in other v2 tag version and use the conversion information to try and find an appropriate frame type.
	
    NSString * frameVersion;  //used initially as a tempory store, later used to store the correct frame ID.
	NSString * frameVersionSecondary;  //used to store the second option if ID not found in first choice for frame type
	NSString * frameVersionTertiary;  // last choice
	
	*Name = NULL;
	*Record = NULL;
	
	// selecting frame dictionary and alternative checking order
	switch (majorVersion) {
		case 0	:	frameVersion = @"2.0";
					frameVersionSecondary = @"2.4";
					frameVersionTertiary = @"2.3";
					break;
		case 1	:	frameVersion = @"2.0";
					frameVersionSecondary = @"2.4";
					frameVersionTertiary = @"2.3";
					break;
		case 2	:	frameVersion = @"2.0";
					frameVersionSecondary = @"2.4";
					frameVersionTertiary = @"2.3";
					break;
		case 3	:	frameVersion = @"2.3";
					frameVersionSecondary = @"2.4";
					frameVersionTertiary = @"2.0";
					break;
		case 4	:	frameVersion = @"2.4";
					frameVersionSecondary = @"2.3";
					frameVersionTertiary = @"2.0";
					break;
		default :	frameVersion = @"2.3";
					frameVersionSecondary = @"2.4";
					frameVersionTertiary = @"2.0";
					break;
	}
	
	// check to see if the frame ID is valid.  frameInformation != NULL if it is a valid frame
	*Record = [[frameSetDictionary objectForKey:frameVersion] objectForKey:ID];
	if (*Record) {
		*Name = ID;
	}
	if (!*Record) {
		// not a valid ID for this frame type hence check other frame dictionaries for a possible conversion
		// secondary choice next
		*Record = [[frameSetDictionary objectForKey:frameVersionSecondary] objectForKey:ID];
		if (Record) {
			*Name = [*Record objectForKey:frameVersion];
			if (Name) {
				*Record = [[frameSetDictionary objectForKey:frameVersion] objectForKey:*Name];
			}
		}
		
		// if no valid frame if found check final frame type option
		if (!*Record) {
			*Record = [[frameSetDictionary objectForKey:frameVersionTertiary] objectForKey:ID];
			
			if (*Record) {
				*Name = [*Record objectForKey:frameVersion];
				if (*Name) {
					*Record = [[frameSetDictionary objectForKey:frameVersion] objectForKey:*Name];
				}
			}
		}
	}
}

-(int)numberInSetString:(NSString *)Set
{
    if (Set == NULL) return 0;
	NSArray *listItems = [Set componentsSeparatedByString:@"/"];
    if ([listItems count] < 1) return 0;
    return [[listItems objectAtIndex:0] intValue];
}

-(int)setSizeInSetString:(NSString *)Set
{
    NSArray *listItems = [Set componentsSeparatedByString:@"/"];
    if ([listItems count] < 2) return 0;
    return [[listItems objectAtIndex:1] intValue];
}

@end
