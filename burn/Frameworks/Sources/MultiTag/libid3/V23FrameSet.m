//
//  V23Tag.m
//  id3Tag
//
//  Created by Chris Drew on Thu Jan 16 2003.
//  Copyright (c) 2003 __MyCompanyName__. All rights reserved.
//

#ifdef __APPLE__
#import "V23FrameSet.h"
#import "zlib.h"
#else
#include "V23FrameSet.h"
#include "zlib.h"

#include <Foundation/NSArray.h>
#include <Foundation/NSData.h>
#include <Foundation/NSDictionary.h>
#endif


@implementation V23FrameSet
-(id)init:(NSMutableData *)Frames version:(int)Minor validFrameSet:(NSDictionary *)FrameSet  frameSet:(NSMutableDictionary *)frameSet offset:(int)Offset
{
    if (!(self = [super init])) return self;
    validFrames = FrameSet;
    v2Tag = Frames;
    frameOffset = Offset;
    minorVersion = Minor;
    tagLength =  [v2Tag length] - frameOffset;
    Buffer = (unsigned char *) [v2Tag bytes];
    currentFramePosition = frameOffset;
    currentFrameLength = 0;
    framesEndAt = frameOffset;
    padding = 0;
    if (([Frames length] < 10)||(Frames == NULL)) return self;
    
    if (![self nextFrame:YES]) return self;
    do {
		id3V2Frame * newFrame = [self getFrame]; 
		if (newFrame != NULL) {
				id anObject = [frameSet objectForKey:[newFrame getFrameID]];
				if (anObject == NULL) {
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
 //   int length2;
    int length = Buffer[currentFramePosition + Offset]*256*256*256 + Buffer[currentFramePosition + 1+Offset]*256*256 + Buffer[currentFramePosition + 2+Offset]*256 + Buffer[currentFramePosition + 3 + Offset];
	if (length > tagLength - frameOffset - currentFramePosition) {
		NSLog(@"Problem encountered parsing v2 frame:  frame length value longer than tag length, guessing correct frame length");
		length = tagLength - frameOffset - currentFramePosition;
	}
	if (length > MAXUNCOMPRESSEDFRAMESIZE) {
			length = MAXUNCOMPRESSEDFRAMESIZE;
			NSLog(@"Warning frame size > maximum allowable frame size, clipping frame to %i bytes.",MAXUNCOMPRESSEDFRAMESIZE);
	}
    return length;
}

-(BOOL)nextFrame:(BOOL)atStart
{
    if (atStart) // positions pointer at start of tag and tests that there is a valid frame
    {
        currentFramePosition = frameOffset;
        if (![self atValidFrame]) return NO;
        currentFrameLength = [self frameLength];
        return YES;
    }
    
    if (currentFramePosition >= tagLength + frameOffset)
    {
        framesEndAt = currentFramePosition;
        return NO;
    }
    // move position in tag
    currentFramePosition += currentFrameLength + 10;
       
    //check that there is still a valid frameheader.  this will also reject the footer as a valid header
    if (![self atValidFrame])
    {
        framesEndAt = currentFramePosition;
        return NO;
    }
     
    // get frame length
    currentFrameLength = [self frameLength];
    
    if (![self atValidFrame]) return NO;

    return YES;
}

-(int)getFrameSetLength
{
    return framesEndAt - frameOffset;
}

-(id3V2Frame *)getFrame
{
    int frameLength = [self readPackedLengthFrom:4];
    unsigned char frameFlag2 = Buffer[9+currentFramePosition];
    unsigned char frameFlag1 = Buffer[8+currentFramePosition];
    unsigned char *tempPointer;
    if (currentFramePosition > tagLength) return NULL;
    tempPointer = Buffer + currentFramePosition;
    if (frameFlag2 & 0x80)
    {   //decompressed the frame using zlib 
        unsigned long newLength = tempPointer[10]*256*256*256 + tempPointer[11]*256*256 + tempPointer[12]*256 + tempPointer[13];
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
			#if MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_X_VERSION_10_4
            case Z_MEM_ERROR: NSLog(@"Decompressing frame %s not enough memory\n", [[self getFrameID] cString]); 
            case Z_BUF_ERROR: NSLog(@"Decompressing frame %s not enough room in the output buffer\n", [[self getFrameID] cString]); 
            case Z_DATA_ERROR: NSLog(@"Decompressing frame %s input data was corrupted\n",[[self getFrameID] cString]);
			#else
			case Z_MEM_ERROR: NSLog(@"Decompressing frame %s not enough memory\n", [[self getFrameID] cStringUsingEncoding:NSUTF8StringEncoding]); 
            case Z_BUF_ERROR: NSLog(@"Decompressing frame %s not enough room in the output buffer\n", [[self getFrameID] cStringUsingEncoding:NSUTF8StringEncoding]); 
            case Z_DATA_ERROR: NSLog(@"Decompressing frame %s input data was corrupted\n",[[self getFrameID] cStringUsingEncoding:NSUTF8StringEncoding]);
			#endif
            }
            return NULL;
        }
        return [[[id3V2Frame alloc] initFrame:[NSMutableData  dataWithBytes:temp length: (int) newLength] length:frameLength frameID:[self getFrameID] firstflag:frameFlag1 secondFlag:frameFlag2 version:3]autorelease];
     }
    return [[[id3V2Frame alloc] initFrame:[NSMutableData  dataWithBytes:tempPointer + 10 length: frameLength] length:frameLength frameID:[self getFrameID] firstflag:frameFlag1 secondFlag:frameFlag2 version:3] autorelease];
}

// general information

-(BOOL)atValidFrame
{
	if (validFrames == NULL)
    {
        if ((Buffer[currentFramePosition] < 'A')||(Buffer[currentFramePosition] > 'Z')||
		(Buffer[currentFramePosition+1] < 'A')||(Buffer[currentFramePosition+1] > 'Z')||
        (Buffer[currentFramePosition+2] < 'A')||(Buffer[currentFramePosition+2] > 'Z')||
        (!(((Buffer[currentFramePosition+3] >= 'A')&&(Buffer[currentFramePosition+3] <= 'Z'))||
        ((Buffer[currentFramePosition+3] >= '0')||(Buffer[currentFramePosition+3] <= '9')))))
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


-(int)frameLength
{
    return [self readPackedLengthFrom:4];
}

-(NSString *)getFrameID
{
    if (Buffer == NULL) return NULL;
	#if MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_X_VERSION_10_4
    return [NSString stringWithCString: (char *)(Buffer + currentFramePosition) length:4];
	#else
	return [NSString stringWithCString: (char *)(Buffer + currentFramePosition) encoding:NSUTF8StringEncoding];
	#endif
}

-(void)dealloc
{
    [errorDescription release];
    [super dealloc];
}

@end
