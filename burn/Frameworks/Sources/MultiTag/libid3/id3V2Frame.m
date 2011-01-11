//
//  id3V2Frames.m
//  id3Tag
//
//  Created by Chris Drew on Sat Dec 07 2002.
//  Copyright (c) 2002 . All rights reserved.
//
#ifdef __APPLE__
#import "id3V2Frame.h"
#import <zlib.h>
#import <AppKit/NSBitmapImageRep.h>
#else

#ifndef _ID3FRAMEWORK_TAGAPI_H_
#include "id3V2Frame.h"
#include <zlib.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSCharacterSet.h>
#include <Foundation/NSData.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSString.h>
#include <AppKit/NSBitmapImageRep.h>
#endif
#endif

#define kTrimSetStr	@"%c%@%@", '\0', @"\r\n\t", @"\0\0"

@implementation id3V2Frame
-(id)initFrame:(NSData *)Frame length:(int)Length frameID:(NSString *)FrameID firstflag:(char)FlagByte1 secondFlag:(char)FlagByte2 version:(int)Version
{
    if (!(self = [super init])) return self;
    frame = [Frame copyWithZone:NULL];
    length = [frame length];
    majorVersion = Version;
    if (majorVersion < 3) frameID = [[NSString alloc]  initWithCString:[FrameID cString] length:3];
    else frameID = [[NSString  alloc] initWithCString:[FrameID cString] length:4];
    flagByte1 = FlagByte1;
    flagByte2 = FlagByte2;
    return self;
} 

-(id)initTextFrame:(NSString *)FrameID firstflag:(char)FlagByte1 secondFlag:(char)FlagByte2 text:(NSString *)Text withEncoding:(unsigned int)Encoding version:(int)Version
{
    if (!(self = [super init])) return self;
    unsigned char nullChar[] = { 0, 0};
	if (Text == NULL) Text = @"";
    frame = [[NSMutableData dataWithCapacity:1] retain];
    [frame appendData:[self getTextCodingByte: (char)Encoding]];
    [frame appendData:[Text dataUsingEncoding:[self convertTextCodingByte:(char)Encoding] allowLossyConversion:YES]];
    [frame appendData:[NSData dataWithBytes:nullChar length:(Encoding == 1?2:1)]];
    length = [frame length];
    majorVersion = Version;
    if (majorVersion < 3) frameID = [[NSString alloc]  initWithCString:[FrameID cString] length:3];
    else frameID = [[NSString alloc] initWithCString:[FrameID cString] length:4];
    flagByte1 = FlagByte1;
    flagByte2 = FlagByte2;
	iTunesV24Compat = NO;
    return self;
}

-(id)init:(NSString *)FrameID firstflag:(char)FlagByte1 secondFlag:(char)FlagByte2 version:(int)Version
{	
    if (!(self = [super init])) return self;
    frame = NULL;
    length = 0;
    majorVersion = Version;
    frameID = [[NSString alloc] initWithString:FrameID];
    flagByte1 = FlagByte1;
    flagByte2 = FlagByte2;
	iTunesV24Compat = NO;
    return self;
}

-(NSString *)getShortCommentFromFrame {
	int i;
	if(frame == NULL) return NULL;
    char *pointer = (char *) [frame bytes];
	if ([self convertTextCodingByte:*pointer] == NSUnicodeStringEncoding)  {
		// Unicode16: scan string for the first occurrance of a double NULL
		for (i = 4; i <= length -1; i ++) if (pointer[i] == 0 && pointer[i+1] == 0) break;
		if (i > length -4) return NULL; // if first null at end of string return null
	} else {
		// non unicode 16 scan string for first single null
		for (i = 4; i <= length; i ++) if (pointer[i] == 0) break;
		if (i > length -1) return NULL; // if first null at end of string return null
	}
	
	return [self cleanString:[[[NSString alloc] initWithData:[NSMutableData  dataWithBytes:pointer + 4 length: i - 4] encoding:[self convertTextCodingByte:*pointer]] autorelease]];
}

-(NSString *)getCommentFromFrame
{
    int i;
	if(frame == NULL) return NULL;
    char *pointer = (char *) [frame bytes];
	if ([self convertTextCodingByte:*pointer] == NSUnicodeStringEncoding)  {
		// Unicode16: scan string for the first occurrance of a double NULL
		for (i = 5; i <= length; i ++) if (pointer[i-1] == 0 && pointer[i] == 0) break;
		if (i > length -4) return NULL; // if first null at end of string return null
	} else {
		// non unicode 16 scan string for first single null
		for (i = 4; i <= length; i ++) if (pointer[i] == 0) break;
		if (i > length -1) return NULL; // if first null at end of string return null
	}
    return [self cleanString:[[[NSString alloc] initWithData:[NSMutableData  dataWithBytes:pointer + i + 1 length: length-i -1] encoding:[self convertTextCodingByte:*pointer]] autorelease]];
}

-(NSString *)getTextFromFrame
{
    if(frame == NULL) return NULL;
    char *pointer = (char *)[frame bytes];
    
    NSString *tempString = [[NSString alloc] initWithData:[NSMutableData  dataWithBytes:pointer + 1 length: length-1] encoding:[self convertTextCodingByte:*pointer]];
    
    if ((pointer[1] > 0)&&[tempString length] == 1) return [tempString autorelease];
    
    
    return [[tempString autorelease] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:[NSString stringWithFormat:kTrimSetStr]]];
}

-(NSData *)getTextCodingByte:(char)encoding
{
    if((majorVersion < 2) && (encoding > 1)) encoding = 1;
    return [[[NSData alloc] initWithBytes:&encoding length:1] autorelease];
}
    

-(NSStringEncoding)convertTextCodingByte:(char)coding
{
    NSStringEncoding encodingType;
    switch (coding)
        { //select string coding type
            case 0 : 	encodingType = NSISOLatin1StringEncoding;
                        break;
            case 1 : 	encodingType = NSUnicodeStringEncoding;
                        break;
            case 2 : 	encodingType = NSUTF8StringEncoding;
                        break;
            case 3 : 	encodingType = NSUTF8StringEncoding;
                        break;
            default:	encodingType = NSISOLatin1StringEncoding;
        }
    if((majorVersion < 2) && (coding > 2)) encodingType = NSUnicodeStringEncoding;
    return encodingType;
}

-(NSString *)getFrameID
{
    return frameID;
}

-(NSArray *)getGenreFromFrame;
{
    return NULL;
}

-(int)length
{
    if (majorVersion < 3) return length + 6;
    return length + 10;
}

-(void)iTunesV24Compat {
	iTunesV24Compat = YES;
}

-(NSData *)getRawFrameData
{
    if(frame == NULL) return NULL;
    return frame;
}

-(NSData *)getCompleteRawFrame
{
    if(frame == NULL) return NULL;
    id processedFrame = frame;
    unsigned long int tempLength = length;
    
    NSMutableData *completeFrame = [NSMutableData dataWithCapacity: length + 10 ];
    
    if ((majorVersion == 4)||(majorVersion == 3))
    {
        int i;
            
        if ([self compress])
        {   //compressed the frame using zlib 
            unsigned char * frameBytes = (unsigned char *)[frame bytes];
            processedFrame = [[NSMutableData dataWithLength: length + 10] retain];
            unsigned char *temp = (unsigned char *)[processedFrame bytes];
            int x = 0;
            x = compress(temp+4,&tempLength,frameBytes,length);
            if  (x) return NULL;
            //write new length into start of compressed frame data
            temp[0] = ((length >> 24) & 0xFF);
            temp[1] = ((length >> 16) & 0xFF);
            temp[2] = ((length >> 8) & 0xFF);
            temp[3] = (length & 0xFF);
            tempLength += 4;
        }   
        
        if ([self unsynch])
        {
            char * frameBytes = (char *)[processedFrame bytes];
            int count = 0;
            for (i = 0; i < tempLength; i++)
            {
                if (frameBytes[i] == (char) 255) count ++;
            }
            
            NSMutableData * tempUnsynchBuffer = [NSMutableData dataWithLength: tempLength+count];
            unsigned char * tempPointer = (unsigned char*) [tempUnsynchBuffer bytes];
            count = 0;
            for (i = 0; i < tempLength; i ++)
            {
                tempPointer[i+count] = frameBytes[i];
                if (255 == (unsigned char) frameBytes[i]) 
                {
                    tempPointer[i+1] = 0;
                    count++;
                }
            }
            tempLength += count;
                
            if (processedFrame != frame) [processedFrame release];
            processedFrame = tempUnsynchBuffer;
        }
        
        [completeFrame appendBytes:[frameID cString] length:4];
        if (majorVersion == 3 || iTunesV24Compat) [completeFrame appendData:[self write3FrameLength:tempLength]];
        else [completeFrame appendData:[self write4FrameLength:tempLength]];
        [completeFrame appendBytes:&flagByte1 length:1];
        [completeFrame appendBytes:&flagByte2 length:1];
        
        if (processedFrame != frame) 
        {
            [completeFrame appendBytes:[processedFrame bytes] length:tempLength];
            [processedFrame release];
        }
        else
            [completeFrame appendData:processedFrame];
    }
    else if (majorVersion <3)
    {
            [completeFrame appendBytes:[frameID cString] length:3];
            [completeFrame appendData:[self write2FrameLength:length]];
            [completeFrame appendData:frame];
    }
    return completeFrame;
}

-(NSData *)write2FrameLength:(int)Length
{
    NSMutableData *Temp  = [NSMutableData dataWithLength:3];
    char * Bytes = (char *) [Temp bytes];
    
    Bytes[2] = (Length & 0xff);
    Length = Length >> 8;
    Bytes[1] = (Length & 0xff);
    Length = Length >> 8;
    Bytes[0] = (Length & 0xff);
    if (Length < 256) return Temp;
    return NULL;
}

-(NSData *)write4FrameLength:(int)Length
{
    NSMutableData *Temp  = [NSMutableData dataWithLength:4];
    char * Bytes = (char *)[Temp bytes];
    
    Bytes[3] = (Length & 0x7f);
    Length = Length >> 7;
    Bytes[2] = (Length & 0x7f);
    Length = Length >> 7;
    Bytes[1] = (Length & 0x7f);
    Length = Length >> 7;
    Bytes[0] =(Length & 0x7f);
    if (Length < 256) return Temp;
    return NULL;
}

-(NSData *)write3FrameLength:(int)Length
{
    NSMutableData *Temp  = [NSMutableData dataWithLength:4];
    char * Bytes = (char *) [Temp bytes];
    
    Bytes[3] = (Length & 0xff);
    Length = Length >> 8;
    Bytes[2] = (Length & 0xff);
    Length = Length >> 8;
    Bytes[1] = (Length & 0xff);
    Length = Length >> 8;
    Bytes[0] = (Length & 0xff);
    if (Length < 256) return Temp;
    return NULL;
}

-(BOOL)writeCommentToFrame:(NSString *)Comments language:(NSString *)Language coding:(BOOL)UTF16
{
    if (frame !=NULL) [frame release];
    frame = [[NSMutableData dataWithCapacity:1] retain];
    length = 0;
    if (frame == NULL) return NO;
    
	if (Comments == NULL) Comments = @"";
    char encoding;
    if (UTF16) encoding = 1;
    else encoding = 0;

    [frame appendData:[self getTextCodingByte: encoding]];
    if (![Language canBeConvertedToEncoding: NSISOLatin1StringEncoding]) return NO;
    if ([Language length] <3) return NO;
    [frame appendBytes:[Language cString] length:3];
	[frame appendBytes:"" length:1];
	if (UTF16) [frame appendBytes:"" length:1];
    [frame appendData:[Comments dataUsingEncoding:[self convertTextCodingByte:encoding] allowLossyConversion:YES]];

    if (frame == NULL) return NO;
    length = [frame length];
    return YES;
}

-(BOOL)writeImage:(NSDictionary *)Image
{
    if (frame !=NULL) [frame release];
    frame = [[NSMutableData dataWithCapacity:1] retain];
    length = 0;
    char nullChar = 0;
    if (frame == NULL) return NO;
    
/*  V2.0-2.2 encoding
    Frame size         $xx xx xx
    Text encoding      $xx
    Image format       $xx xx xx
    Picture type       $xx
    Description        <textstring> $00 (00)
    Picture data       <binary data>
    
    V2.3-2.4 encoding
    Text encoding      $xx
    MIME type          <text string> $00
    Picture type       $xx
    Description        <text string according to encoding> $00 (00)
    Picture data       <binary data> */

    // write Text encoding byte
    char encoding;
    NSString * tempDescription = [Image objectForKey:@"Description"];
    if ([tempDescription canBeConvertedToEncoding:NSASCIIStringEncoding]) encoding = 0;
    else encoding = 1;
    [frame appendData:[self getTextCodingByte: encoding]];
    
    int imageEncoding = 0;
    
    // write Image Format
    NSString *tempMime = [[Image objectForKey:@"Mime Type"] lastPathComponent];
    NSString *MIMEString;
    if (NSOrderedSame == [tempMime caseInsensitiveCompare:@"jpeg"]) {
		imageEncoding = NSJPEGFileType;
		if (majorVersion >= 3) MIMEString = [[NSString stringWithString:@"image/jpeg"] retain];
		else MIMEString = [[NSString stringWithString:@"JPG"] retain];
    } else
    if (NSOrderedSame == [tempMime caseInsensitiveCompare:@"jpg"]) {
		imageEncoding = NSJPEGFileType;
		if (majorVersion >= 3) MIMEString = [[NSString stringWithString:@"image/jpeg"] retain];
		else MIMEString = [[NSString stringWithString:@"JPG"] retain];
    } else
    if (NSOrderedSame == [tempMime caseInsensitiveCompare:@"BMP"]) {
		if (majorVersion >= 3) MIMEString = [[NSString stringWithString:@"image/bmp"] retain];
		else MIMEString = [[NSString stringWithString:@"BMP"] retain];
		imageEncoding = NSBMPFileType;
    } else
    if (NSOrderedSame == [tempMime caseInsensitiveCompare:@"GIF"]) {
		imageEncoding = NSGIFFileType;
		if (majorVersion >= 3) MIMEString = [[NSString stringWithString:@"image/gif"] retain];
		else MIMEString = [[NSString stringWithString:@"GIF"] retain];
    } else
    if (NSOrderedSame == [tempMime caseInsensitiveCompare:@"TIFF"]) {
		imageEncoding = NSTIFFFileType;
    	if (majorVersion >= 3) MIMEString = [[NSString stringWithString:@"image/tiff"] retain];
		else MIMEString = [[NSString stringWithString:@"tiff"] retain];
    } else
    if (NSOrderedSame == [tempMime caseInsensitiveCompare:@"PNG"]) {
		imageEncoding = NSPNGFileType;
		if (majorVersion >= 3) MIMEString = [[NSString stringWithString:@"image/png"] retain];
		else MIMEString = [[NSString stringWithString:@"PNG"] retain];
    } else  {
		imageEncoding = NSJPEGFileType;
		if (majorVersion >= 3) MIMEString = [[NSString stringWithString:@"image/jpeg"] retain];
		else MIMEString = [[NSString stringWithString:@"JPG"] retain];
    }

    [frame appendData:[MIMEString dataUsingEncoding:NSASCIIStringEncoding]];
    [MIMEString release];
    id tempPtr = [Image objectForKey:@"Picture Type"];
    unsigned int pictureType;
    
    if (NSOrderedSame == [tempPtr caseInsensitiveCompare:@"Other"]) pictureType = 0;
    else
    if (NSOrderedSame == [tempMime caseInsensitiveCompare:@"32x32 pixels \'file icon\'"]) pictureType = 1;
    else
    if (NSOrderedSame == [tempMime caseInsensitiveCompare:@"Other file icon"]) pictureType = 2;
    else
    if (NSOrderedSame == [tempMime caseInsensitiveCompare:@"Cover (front)"]) pictureType = 3;
    else 
    if (NSOrderedSame == [tempMime caseInsensitiveCompare:@"Cover (back)"]) pictureType = 4;
    else
    if (NSOrderedSame == [tempMime caseInsensitiveCompare:@"Leaflet page"]) pictureType = 5;
    else
    if (NSOrderedSame == [tempMime caseInsensitiveCompare:@"Media (e.g. label side of CD)"]) pictureType = 6;
    else
    if (NSOrderedSame == [tempMime caseInsensitiveCompare:@"Lead artist/lead performer/soloist"]) pictureType =7;
    else
    if (NSOrderedSame == [tempMime caseInsensitiveCompare:@"Artist/performer"]) pictureType = 8;
    else
    if (NSOrderedSame == [tempMime caseInsensitiveCompare:@"Conductor"]) pictureType = 9;
    else
    if (NSOrderedSame == [tempMime caseInsensitiveCompare:@"Band/Orchestra"]) pictureType = 10;
    else
    if (NSOrderedSame == [tempMime caseInsensitiveCompare:@"Composer"]) pictureType = 11;
    else
    if (NSOrderedSame == [tempMime caseInsensitiveCompare:@"Lyricist/text writer"]) pictureType = 12;
    else
    if (NSOrderedSame == [tempMime caseInsensitiveCompare:@"Recording Location"]) pictureType = 13;
    else
    if (NSOrderedSame == [tempMime caseInsensitiveCompare:@"During recording"]) pictureType = 14;
    else
    if (NSOrderedSame == [tempMime caseInsensitiveCompare:@"During performance"]) pictureType = 15;
    else
    if (NSOrderedSame == [tempMime caseInsensitiveCompare:@"Movie/video screen capture"]) pictureType = 16;
    else
    if (NSOrderedSame == [tempMime caseInsensitiveCompare:@"A bright coloured fish"]) pictureType = 17;
    else
    if (NSOrderedSame == [tempMime caseInsensitiveCompare:@"Illustration"]) pictureType = 18;
    else
    if (NSOrderedSame == [tempMime caseInsensitiveCompare:@"Band/artist logotype"]) pictureType = 19;
    else
    if (NSOrderedSame == [tempMime caseInsensitiveCompare:@"Publisher/Studio logotype"]) pictureType = 20;
    else
	pictureType = 0;  // UNKNOWN
	
    [frame appendBytes:&nullChar length:1];
    [frame appendBytes: &pictureType length:1];
    
    // append description
    NSString * descriptionString = [Image objectForKey:@"Description"];
    if (descriptionString == NULL) 
    {
	[frame appendBytes:&nullChar length:1];
    }
    else 
    {
	[frame appendData:[descriptionString dataUsingEncoding:NSASCIIStringEncoding]];
	if ([descriptionString length] == 0) [frame appendBytes:&nullChar length:1];
    }
    
    [frame appendData: [[Image objectForKey:@"Image"] representationUsingType:imageEncoding properties:NULL]];
    
    if (frame == NULL) return NO;
    length = [frame length];
    return YES;
}

-(BOOL)writeTextFrame:(NSString *)Text coding:(BOOL)UTF16
{
    if (frame !=NULL) [frame release];
    frame = [[NSMutableData dataWithCapacity:1] retain];
    length = 0;
    unsigned char nullChar[] = { 0, 0};
    if (frame == NULL) return NO;
	if (Text == NULL) Text = @"";
    
    char encoding;
    if (UTF16) encoding = 1;
    else encoding = 0;

    [frame appendData:[self getTextCodingByte: encoding]];
    [frame appendData:[Text dataUsingEncoding:[self convertTextCodingByte:encoding] allowLossyConversion:YES]];
    [frame appendData:[NSData dataWithBytes:nullChar length:(UTF16?2:1)]];
    
    if (frame == NULL) return NO;
    length = [frame length];
    return YES;
}

-(BOOL)appendDataToFrame:(NSData *)frameData newFrame:(BOOL)Wipe
{
    if ((Wipe)||(frame == NULL))
    {
        if (frame !=NULL) [frame release];
        frame = [[NSMutableData dataWithData:frameData] retain];
    }
    else [frame appendData:frameData];
    if (frame == NULL) return NO;
    length = [frame length];
    return YES;
}

-(BOOL)compress
{
    return (((flagByte2 & 0x80)&&(majorVersion == 3)||(majorVersion == 4)&&(flagByte2 & 0x08)));
}

-(BOOL)unsynch
{
    return ((flagByte2 & 0x80)&&(majorVersion == 4));
}

-(BOOL)setCompress:(BOOL)Flag
{
    if (majorVersion == 3)
    {
        if (Flag) flagByte2 = (flagByte2 | 0x80);
        else flagByte2 = (flagByte2 & (0xff ^ 0x80));
        return YES;
    }
    if (majorVersion == 4)
    {
        if (Flag) flagByte2 = (flagByte2 | 0x08);
        else flagByte2 = (flagByte2 & (0xff ^ 0x08));
        return YES;
    }
    return NO;
}

-(BOOL)setUnsynch:(BOOL)Flag
{ 
    if (majorVersion == 4)
    {
        if (Flag) flagByte2 = (flagByte2 | 0x02);
        else flagByte2 = (flagByte2 & (0xff ^ 0x02));
        return YES;
    }
    return NO;
}

-(BOOL)dropIfTagChange
{
    if (majorVersion == 3) return (flagByte1 & 0x80);
    if (majorVersion == 4) return (flagByte1 & 0x40);
    return NO;
}

-(BOOL)dropIfFileChange
{
    if (majorVersion == 3) return (flagByte1 & 0x40);
    if (majorVersion == 4) return (flagByte1 & 0x20);
    return NO;
}

-(BOOL)readOnly
{
    if (majorVersion == 3)
        return (flagByte1 & 0x20);

    if (majorVersion == 4)
        return (flagByte1 & 0x10);
        
    return NO;
}

-(BOOL)encrypted
{
    if (majorVersion == 3) return (flagByte2 & 0x40);
    if (majorVersion == 4) return (flagByte2 & 0x04);
    return NO;    
}

-(BOOL)setEncrypted:(BOOL)Flag
{
    if (majorVersion == 3)
    {
        if (Flag) flagByte2 = (flagByte2 | 0x40);
        else flagByte2 = (flagByte2 & (0xff ^ 0x40));
        return YES;
    }
    if (majorVersion == 4)
    {
        if (Flag) flagByte2 = (flagByte2 | 0x04);
        else flagByte2 = (flagByte2 & (0xff ^ 0x04));
        return YES;
    }
    return NO;
}

-(BOOL)setDropIfTagChange:(BOOL)Flag
{
    if (majorVersion == 3)
    {
        if (Flag) flagByte1 = (flagByte1 | 0x80);
        else flagByte1 = (flagByte1 & (0xff ^ 0x80));
        return YES;
    }
    if (majorVersion == 4)
    {
        if (Flag) flagByte1 = (flagByte1 | 0x40);
        else flagByte1 = (flagByte1 & (0xff ^ 0x40));
        return YES;
    }
    return NO;
}

-(BOOL)setDropIfFileChange:(BOOL)Flag
{
    if (majorVersion == 3)
    {
        if (Flag) flagByte1 = (flagByte1 | 0x40);
        else flagByte1 = (flagByte1 & (0xff ^ 0x40));
        return YES;
    }
    if (majorVersion == 4)
    {
        if (Flag) flagByte1 = (flagByte1 | 0x20);
        else flagByte1 = (flagByte2 & (0xff ^ 0x20));
        return YES;
    }
    return NO;
}

-(BOOL)setReadOnly:(BOOL)Flag
{
    if (majorVersion == 3)
    {
        if (Flag) flagByte1 = (flagByte1 | 0x20);
        else flagByte1 = (flagByte1 & (0xff ^ 0x20));
        return YES;
    }
    if (majorVersion == 4)
    {
        if (Flag) flagByte1 = (flagByte1 | 0x10);
        else flagByte1 = (flagByte2 & (0xff ^ 0x10));
        return YES;
    }
    return NO;
}

-(NSString *)genreStringFromArray:(NSArray *)Array
{// takes an array of strings an converts them to a single string 
    NSMutableString * tempString = [NSMutableString stringWithCapacity:[Array count]*10];
    NSEnumerator *enumerator = [Array objectEnumerator];
    char * charPtr = "";
    NSString *nullString = [NSString stringWithCString:charPtr length:1];
    NSString * anObject;
    
    while (anObject = [enumerator nextObject]) 
    {
        [tempString appendString:anObject];
        [tempString appendString:nullString];
    }
    return tempString;
}

-(NSMutableArray *)genreArrayFromFrame
{  //Splits the genre string into an array of string. Number are converted to strings base on the dictionary. if the dictionary is NULL the system used the inbuilt dictionary.
    //check that user passed valid variables
    NSString * String = [[self getTextFromFrame] retain];
       
    //obtain a cstring representation of the genre string
    NSMutableData *Data = [NSMutableData dataWithLength:[String length]];
    char * tempPointer = (char *) [Data bytes];
    [String getCString:tempPointer];
    int start = 0;
    int end = 0;
    int foundNull = 0;
    int foundBracket = 0;
    
    NSMutableArray * Array = [NSMutableArray arrayWithCapacity:10];
    
    // process the string: string structure = (number or genre)...(number or genre)...((bracketed text))... || genre '\0x00' genre '\x00' (genre) ...
    
    if (*tempPointer == '(')
    {
        foundBracket = 1;
        start += 1;
    }
    
    if (*tempPointer == '\0')
    {
        foundNull = 1;
        start += 1;
    }
    
    end = start;
    
    while ([String length] > end)
    {	
        if (tempPointer[end] == '\0') 
        {
            foundBracket = 0;
            foundNull = 0;             
            if (start < end)
                [Array addObject:[NSString stringWithCString:tempPointer + start length:end - start]];
            start = end + 1;
        }        
        
        if (tempPointer[end] == '(')
        {
            if (foundBracket == 0) start = end + 1;
            foundBracket++;
        }
        
        if (tempPointer[end] == ')')
        {
            if (foundBracket > 0) foundBracket--;
            if ((start < end) && (!foundBracket) && (!foundNull)) 
            {
                [Array  addObject:[NSString stringWithCString:tempPointer + start length:end - start]]; 
            }
        }
        
        end ++;
    }
    if (end>start) [Array addObject:[NSString stringWithCString:tempPointer + start length:end - start]];
    [String release];
    return Array;
}

-(int)getFrameLength
{
    return length;
}

- (BOOL)isEqual:(id)anObject {
	if ([frameID isEqual:[anObject getFrameID]]&&[frame isEqual:[anObject getRawFrameData]]&&([self length] == [anObject length])) return YES;
	else return NO;
}

-(NSMutableString *)cleanString:(NSString *)String {
	NSMutableString * cleanString = [[String stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:[NSString stringWithFormat:kTrimSetStr]]] mutableCopy];
	NSRange range;
	range.location = 0;
	range.length = [cleanString length];
	[cleanString replaceOccurrencesOfString:@"\0\0" withString:@" " options:NSCaseInsensitiveSearch range:range];
	range.length = [cleanString length];
	[cleanString replaceOccurrencesOfString:@"\0" withString:@" " options:NSCaseInsensitiveSearch range:range];
	return cleanString;
}

-(void)dealloc
{
    if (frameID != NULL) [frameID release];
    if (frame != NULL) [frame release];
	[super dealloc];
}
@end
