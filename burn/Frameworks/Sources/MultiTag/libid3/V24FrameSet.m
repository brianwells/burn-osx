//
//  V24Tag.m
//  id3Tag
//
//  Created by Chris Drew on Thu Jan 16 2003.
//  Copyright (c) 2003 __MyCompanyName__. All rights reserved.
//

#ifdef __APPLE__
#import "V24FrameSet.h"
#import "zlib.h"
#else
#include "V24FrameSet.h"
#include "zlib.h"

#include <Foundation/NSArray.h>
#include <Foundation/NSData.h>
#endif

@implementation V24FrameSet
-(id)init:(NSMutableData *)Frames version:(int)Minor validFrameSet:(NSDictionary *)FrameSet  frameSet:(NSMutableDictionary *)frameSet offset:(int)Offset  iTunes:(BOOL)ITunes
{
    if (!(self = [super init])) return self;
    validFrames = FrameSet;
    v2Tag = Frames;
    frameOffset = Offset;
    minorVersion = Minor;
    tagLength = [v2Tag length] - frameOffset;
    Buffer = (unsigned char *) [v2Tag bytes];
    currentFramePosition = frameOffset;
    currentFrameLength = 0;
    framesEndAt = frameOffset;
    padding = 0;
	iTunesFlag = NO;
	validChars = [[NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZ 1234567890"] retain];
    
    if (([Frames length] < 10)||(Frames == NULL)) return self;
	
    if (![self nextFrame:YES]) return self;
    do
    {
		id3V2Frame * newFrame = [self getFrame]; 
		if (iTunesFlag && ITunes) [newFrame iTunesV24Compat];

        if (newFrame != NULL) 
        {
            id anObject = [frameSet objectForKey:[newFrame getFrameID]];
            if (anObject == NULL) 
			{
				NSMutableArray *tempArray = [NSMutableArray arrayWithCapacity:2];
				[tempArray addObject:newFrame];
				[frameSet setObject:tempArray forKey:[newFrame getFrameID]];
			}
            else [anObject addObject:newFrame];
		}
    } while ([self nextFrame:NO]);
    
    return self;
}

- (int)readPackedLengthFrom:(int)Offset
{
    int val = 0;
    int i;
    const int MAXVAL = 268435456; //2^28
    // For each byte of the first 4 bytes in the string...
	
	if (Buffer[currentFramePosition + Offset] & 0x80 || Buffer[currentFramePosition + 1 + Offset] & 0x80 || 
	    Buffer[currentFramePosition + 2 + Offset] & 0x80 || Buffer[currentFramePosition + 3 + Offset] & 0x80) iTunesFlag = YES;
	if (iTunesFlag) return [self readLargeByteLengthFrom:Offset];
    
    for (i = 0; i < 4; ++i)
    {// ...append the last 7 bits to the end of the temp integer...
        val = val * 128;
        val += Buffer[currentFramePosition + i + Offset];
    }
    if (val > MAXVAL) val = MAXVAL;
	if (val > tagLength - frameOffset - currentFramePosition) {
		NSLog(@"Problem encountered parsing v2 frame:  frame length value longer than tag length, guessing correct frame length");
		val = tagLength - frameOffset - currentFramePosition;
	}
	if (val > MAXUNCOMPRESSEDFRAMESIZE) {
			val = MAXUNCOMPRESSEDFRAMESIZE;
			NSLog(@"Warning frame size > maximum allowable frame size, clipping frame to %i bytes.",MAXUNCOMPRESSEDFRAMESIZE);
	}
    return val;
}

- (int)readLargeByteLengthFrom:(int)Offset
{
    int val = 0;
    const int MAXVAL = 268435456; //2^28
    // For each byte of the first 4 bytes in the string...
    
	val = Buffer[currentFramePosition + Offset]*256*256*256 +  Buffer[currentFramePosition + 1 + Offset]*256*256 +  Buffer[currentFramePosition + 2 + Offset]*256 + Buffer[currentFramePosition + 3 + Offset];
    if (val > MAXVAL) val = MAXVAL;
	if (val > tagLength - frameOffset - currentFramePosition) {
		NSLog(@"Problem encountered parsing v2 frame:  frame length value longer than tag length, guessing correct frame length");
		val = tagLength - frameOffset - currentFramePosition;
	}
	if (val > MAXUNCOMPRESSEDFRAMESIZE) {
			val = MAXUNCOMPRESSEDFRAMESIZE;
			NSLog(@"Warning frame size > maximum allowable frame size, clipping frame to %i bytes.",MAXUNCOMPRESSEDFRAMESIZE);
	}

    return val;
}

-(BOOL)nextFrame:(BOOL)atStart
{
    if (atStart) // positions pointer at start of tag and tests that there is a valid frame
    {
        currentFramePosition = frameOffset;
        if (![self atValidFrame]) return NO;
        currentFrameLength = [self frameLength];
		if (iTunesFlag) return YES;
		if ((currentFrameLength > 127) && (tagLength - 10 > currentFrameLength)) {
			if (![self validFrameAt:currentFrameLength]) {
				int possibleLength = [self readLargeByteLengthFrom:4];
				if ([self validFrameAt:possibleLength]) {
					currentFrameLength = possibleLength;
				}
			}
		}
        return YES;
    }
    
    if (currentFramePosition >= tagLength + frameOffset)
    {
        framesEndAt = currentFramePosition;
        return NO;
    }
    // move position in tag
	currentFramePosition += currentFrameLength;
	
    if (currentFrameLength <= 127) // iTunes writes incorrect framelengths for frames longer than 127 bytes need to do additional testing
	{
		//check that there is still a valid frameheader.  this will also reject the footer as a valid header
		if (![self atValidFrame])
		{
			framesEndAt = currentFramePosition;
			return NO;
		}
	} else {
		if (![self atValidFrame])
		{
			currentFramePosition -= currentFrameLength;
			int possibleLength = [self readLargeByteLengthFrom:4];
			currentFramePosition +=  possibleLength;
			if (![self atValidFrame])
			{
				framesEndAt = currentFramePosition - possibleLength + currentFrameLength;
				return NO;
			} else {
				iTunesFlag = YES;
				currentFrameLength = possibleLength;
			}
		}
    } 
	// get frame length
    currentFrameLength = [self frameLength];
    
    if (![self atValidFrame]) return NO;

    return YES;
}

-(id3V2Frame *)getFrame
{
    int frameLength;
	if (iTunesFlag) frameLength = [self readLargeByteLengthFrom:4];
	else frameLength = [self readPackedLengthFrom:4];
    unsigned char frameFlag2 = Buffer[9+currentFramePosition];
    unsigned char frameFlag1 = Buffer[8+currentFramePosition];
    NSMutableData *tempBuffer;
    unsigned char *tempPointer;
    int i, count;

    tempPointer = Buffer + currentFramePosition;
    if (frameFlag2 & 0x02) //only v2.4 allow frame synchronisation
    {  // need to decode unsynched frame. create new buffer and copy across without desync bytes
        tempBuffer = [NSMutableData dataWithLength: frameLength];
        tempPointer = (unsigned char*) [tempBuffer bytes];
        count = 0;
        for (i = 10; i < frameLength; i ++)
        {
            tempPointer[i] = Buffer[i+currentFramePosition];
            if (255 == (unsigned char) Buffer[i+currentFramePosition]) 
            {
                count++;
                i++;
            }
        }
        frameLength -= count;
    }
    if (frameFlag2 & 0x08)
    {   //decompressed the frame using zlib 
        unsigned long newLength = tempPointer[11]*256*256*256 + tempPointer[12]*256*256 + tempPointer[13]*256 + tempPointer[14];
		if (newLength > MAXUNCOMPRESSEDFRAMESIZE) {
			newLength = MAXUNCOMPRESSEDFRAMESIZE;
			NSLog(@"Warning Uncompressed frame size > maximum allowable frame size, clipping frame to %i bytes.",MAXUNCOMPRESSEDFRAMESIZE);
		}
        NSMutableData *uncompressed = [NSMutableData dataWithLength: newLength];
        unsigned char *temp = (unsigned char *)[uncompressed bytes];
        int x;
        x = uncompress(temp,&newLength,tempPointer+14,frameLength);
        if (x!=0)
        {
            switch (x)
            {
            case Z_MEM_ERROR: NSLog(@"Decompressing frame %s not enough memory\n", [[self getFrameID] cString]); 
            case Z_BUF_ERROR: NSLog(@"Decompressing frame %s not enough room in the output buffer\n", [[self getFrameID] cString]); 
            case Z_DATA_ERROR: NSLog(@"Decompressing frame %s input data was corrupted\n",[[self getFrameID] cString]);
            }
            return NULL;
        }
        return [[[id3V2Frame alloc] initFrame:[NSMutableData  dataWithBytes:temp length: (int) newLength] length:frameLength frameID:[self getFrameID] firstflag:frameFlag1 secondFlag:frameFlag2 version:4]autorelease];
     }

    return [[[id3V2Frame alloc] initFrame:[NSMutableData  dataWithBytes:tempPointer + 10 length: frameLength] length:frameLength frameID:[self getFrameID] firstflag:frameFlag1 secondFlag:frameFlag2 version:4] autorelease];
}

-(BOOL)atValidFrame
{
	if (validFrames == NULL)
    {
        if (![validChars characterIsMember:(unichar) Buffer[currentFramePosition]] || 				
			![validChars characterIsMember:(unichar) Buffer[currentFramePosition+1]] ||
			![validChars characterIsMember:(unichar) Buffer[currentFramePosition+2]] ||
			![validChars characterIsMember:(unichar) Buffer[currentFramePosition+3]])
        {
            framesEndAt = currentFramePosition;
            return NO;
        }
        return YES;
    } else    
    if ([validFrames objectForKey:[self getFrameID]] != NULL)
    {
        framesEndAt = currentFramePosition;
        return NO;
    }
    return YES;
}

-(BOOL)validFrameAt:(int)Offset
{
	if (validFrames == NULL)
    {
        if (![validChars characterIsMember:(unichar) Buffer[currentFramePosition + Offset]] || 				
			![validChars characterIsMember:(unichar) Buffer[currentFramePosition + 1 + Offset]] ||
			![validChars characterIsMember:(unichar) Buffer[currentFramePosition + 2 + Offset]] ||
			![validChars characterIsMember:(unichar) Buffer[currentFramePosition + 3 + Offset]])
        {
            framesEndAt = currentFramePosition;
            return NO;
        }
        return YES;
    } else    
    if ([validFrames objectForKey:[self getFrameID]] != NULL)
    {
        framesEndAt = currentFramePosition;
        return NO;
    }
    return YES;
}

-(int)getFrameSetLength
{
    return framesEndAt - frameOffset;
}

-(int)frameLength
{
    return [self readPackedLengthFrom:4] + 10;
}

-(NSString *)getFrameID
{
    return [NSString stringWithCString: (char *)(Buffer + currentFramePosition) length:4];
}

-(void)dealloc
{
    [errorDescription release];
	[validChars release];
    [super dealloc];
}

@end
