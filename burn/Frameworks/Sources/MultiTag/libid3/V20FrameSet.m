//
//  V20Tag.m
//  id3Tag
//
//  Created by Chris Drew on Thu Jan 16 2003.
//  Copyright (c) 2003 __MyCompanyName__. All rights reserved.
//
#ifdef __APPLE__
#import "V20FrameSet.h"
#else 
#include "V20FrameSet.h"

#include <Foundation/NSArray.h>
#include <Foundation/NSData.h>
#include <Foundation/NSDictionary.h>
#endif


@implementation V20FrameSet
-(id)init:(NSMutableData *)Frames version:(int)Minor validFrameSet:(NSDictionary *)FrameSet frameSet:(NSMutableDictionary *)frameSet offset:(int)Offset
{
    if (!(self = [super init])) return self;
    validFrames = FrameSet;
    frameOffset = Offset;
    v2Tag = Frames;
    minorVersion = Minor;
    tagLength = [v2Tag length] - frameOffset;
    Buffer = (unsigned char *) [v2Tag bytes];
    currentFramePosition = frameOffset;
    currentFrameLength = 0;
    framesEndAt = frameOffset;
    padding = 0;

    
    if (([Frames length] < 6)||(Frames == NULL)) return self;
    
    if (![self nextFrame:YES]) return self;
    do
    {
        id3V2Frame * newFrame = [self getFrame]; 
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
    currentFramePosition += currentFrameLength + 6;
       
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

-(id3V2Frame *)getFrame
{
    if (![self atValidFrame]) return NULL;
    int frameLength = [self frameLength];
    
    unsigned char * tempPointer = Buffer + currentFramePosition;
    return [[[id3V2Frame alloc] initFrame:[NSMutableData  dataWithBytes:tempPointer + 6 length: frameLength] length:frameLength frameID:[self getFrameID] firstflag:0 secondFlag:0 version:2] autorelease];
}


-(BOOL)atValidFrame
{
    if (validFrames == NULL)
    {
        if ((Buffer[currentFramePosition] < 'A')||(Buffer[currentFramePosition] > 'Z')||
            (Buffer[currentFramePosition+1] < 'A')||(Buffer[currentFramePosition+1] > 'Z') ||
            (((Buffer[currentFramePosition+2] < 'A')||(Buffer[currentFramePosition+2] > 'Z'))&&
            ((Buffer[currentFramePosition+2] < '0')||(Buffer[currentFramePosition+2] > '9'))))
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
    int length = Buffer[3+currentFramePosition]*256*256 + Buffer[4+currentFramePosition]*256 + Buffer[5+currentFramePosition];
	
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

-(NSString *)getFrameID
{
    if (Buffer == NULL) return NULL;
	#if MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_X_VERSION_10_4
    return [NSString stringWithCString: (char *)(Buffer + currentFramePosition) length:3];
	#else
	return [NSString stringWithCString: (char *)(Buffer + currentFramePosition) encoding:NSUTF8StringEncoding];
	#endif
}

//  ?? need to clean up this section I don't have a good calculator handy

-(int)getFrameSetLength
{
    return framesEndAt - frameOffset;
}

-(void)dealloc
{
    [errorDescription release];
    [super dealloc];
}

@end
