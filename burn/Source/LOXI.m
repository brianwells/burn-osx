/*
 * Copyright (c) 2008-2009, Maconnect
 * All rights reserved.
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *     * Redistributions of source code MUST retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of Maconnect, Berkeley nor the
 *       names of its contributors may be used to endorse or promote products
 *       derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE REGENTS AND CONTRIBUTORS BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "LOXI.h"
#import <DiscRecording/DiscRecording.h>

@interface NSObject (LiquidCDTrackAccess)
-(DRTrack *)track;
@end

@implementation LOXI

+ (NSXMLElement *)elementForTrack:(DRTrack *)track startingOffset:(uint64_t)offset size:(uint64_t *)retSize
{
	NSXMLElement *root = [NSXMLElement elementWithName:@"track"];
	require(root, error);
	NSDictionary *props = [track properties];
	require(props, error);
	NSNumber *blockType = [props objectForKey:DRBlockTypeKey];
	require(blockType, error);
	NSXMLNode *tempNode = NULL;
	
	switch ([blockType intValue])
	{
		case kDRBlockTypeAudio:
			tempNode=[NSXMLNode attributeWithName:@"type" stringValue:@"audio"];
			break;
		case kDRBlockTypeMode2Data:
		case kDRBlockTypeMode2Form1Data:
		case kDRBlockTypeMode2Form2Data:
			tempNode=[NSXMLNode attributeWithName:@"type" stringValue:@"mode2"];
			break;
		default: // = kDRBlockTypeDVDData
			tempNode=[NSXMLNode attributeWithName:@"type" stringValue:@"mode1"];
			break;
	}
	
	if (tempNode)
		[root addAttribute:tempNode];
		
	tempNode = NULL;
	
	NSNumber * blockSize=[props objectForKey:DRBlockSizeKey];
	require(blockSize, error);
	[root addAttribute:[NSXMLNode attributeWithName:@"block-size" stringValue:[NSString stringWithFormat:@"%d", [blockSize intValue]]]];
	[root addAttribute:[NSXMLNode attributeWithName:@"start-offset" stringValue:[NSString stringWithFormat:@"%llu", offset]]];
	
	uint64_t size = [track estimateLength] * [blockSize unsignedLongLongValue];
	[root addAttribute:[NSXMLNode attributeWithName:@"size" stringValue:[NSString stringWithFormat:@"%llu", size]]];
	require(size, error);
	if (retSize)
		*retSize=size;
	
	NSNumber * pregap=[props objectForKey:DRPreGapLengthKey];
	if (pregap)
	{
		size = [pregap unsignedLongLongValue] * [blockSize unsignedLongLongValue];
		[root addAttribute:[NSXMLNode attributeWithName:@"pregap-size" stringValue:[NSString stringWithFormat:@"%llu", size]]];
	}
	
	return root;
error:;
	return nil;
}

+(NSData *)LOXIHeaderForDRLayout:(id)layout
{
	return [self LOXIHeaderForDRLayout:layout arrayOfCDTextBlocks:nil];
}

+(NSData *)LOXIHeaderForDRLayout:(id)layout arrayOfCDTextBlocks:(NSArray*)cdtextBlocks
{
	if (!layout)
		return nil;
	NSXMLElement			*root=[NSXMLElement elementWithName:@"disc"];
	NSXMLDocument			*xmlDoc=[[[NSXMLDocument alloc] initWithRootElement:root] autorelease];
	uint64_t				totalSize=0;
	
	[xmlDoc setCharacterEncoding:@"UTF-8"];
	[root addAttribute:[NSXMLNode attributeWithName:@"version" stringValue:@"1.01"]];
	[root addAttribute:[NSXMLNode attributeWithName:@"version-compatibility" stringValue:@"1.0"]];
	
	if (cdtextBlocks){
		NSXMLElement	*cdt = [self XMLElementForArrayOfCDTextBlocks:cdtextBlocks];
		if (cdt)
			[root addChild:cdt];
	}
	
	if (![layout isKindOfClass:[NSArray class]])
	{
		DRTrack	* track= [layout isKindOfClass:[DRTrack class]] ? layout : [(NSObject*)layout track];
		if (!track)
			return nil;
		NSXMLElement *e = [self elementForTrack:track startingOffset:totalSize size:NULL];
		if (!e)
			return nil;
		[root addChild:e];
	}
	else if ([layout isKindOfClass:[NSArray class]])
	{
		#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1050
		for(id object in (NSArray*)layout){
		#else
		NSInteger i;
		for (i = 0; i < [(NSArray*)layout count]; i ++)
		{
			id object = [(NSArray*)layout objectAtIndex:i];
		#endif
			
			if ([object isKindOfClass:[NSArray class]])
			{
				NSXMLElement *session = [NSXMLElement elementWithName:@"session"];
				
				#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1050
				for(id otrack in (NSArray*)object){
				#else
				NSInteger x;
				for (x = 0; x < [(NSArray*)object count]; x ++)
				{
					id otrack = [(NSArray*)object objectAtIndex:x];
				#endif
					DRTrack	*track = [otrack isKindOfClass:[DRTrack class]] ? otrack : [(NSObject*)otrack track];
					if (!track)
						return nil;
					uint64_t size = 0;
					NSXMLElement *e= [self elementForTrack:track startingOffset:totalSize size:&size];
					if (!e)
						return nil;
					[session addChild:e];
					totalSize+=size;
				}
				
				[root addChild:session];
			}
			else
			{
				uint64_t size = 0;
				DRTrack *track = [object isKindOfClass:[DRTrack class]] ? object : [(NSObject*)object track];
				if (!track)
					return nil;
				NSXMLElement *e = [self elementForTrack:track startingOffset:totalSize size:&size];
				if (!e)
					return nil;
				[root addChild:e];
				totalSize+=size;
			}
		}
	}
	else
		return nil;
	
	NSMutableData * md = [NSMutableData dataWithData:[xmlDoc XMLData]];
	uint32_t dataSize = [md length];
	
	dataSize=OSSwapHostToBigInt32(dataSize);
	[md appendBytes:(void*)&dataSize length:sizeof(dataSize)];
	[md appendBytes:"L" length:1];
	[md appendBytes:"O" length:1];
	[md appendBytes:"X" length:1];
	[md appendBytes:"I" length:1];
	
	return md;
}

+(NSXMLDocument*)LOXIXmlDocumentForFileAtPath:(NSString*)path{
	NSFileHandle			*fh=NULL;
	require(path, error);
	fh=[NSFileHandle fileHandleForReadingAtPath:path];
	require(fh, error);
	
	[fh seekToEndOfFile];
	[fh seekToFileOffset:[fh offsetInFile]-4];
	
	NSData					*tempData=[fh readDataOfLength:4];
	require(tempData, error);
	char					*tempBytes=(char*)[tempData bytes];
	require(tempBytes[0]=='L' && tempBytes[1]=='O' && tempBytes[2]=='X' && tempBytes[3]=='I', error);
	
	uint32_t				footerSize=0;
	[fh seekToEndOfFile];
	[fh seekToFileOffset:[fh offsetInFile]-4-sizeof(footerSize)];
	
	tempData=[fh readDataOfLength:sizeof(footerSize)];
	require(tempData, error);
	
	[tempData getBytes:&footerSize];
	footerSize=OSSwapBigToHostInt32(footerSize);
	require(footerSize, error);
	
	[fh seekToEndOfFile];
	[fh seekToFileOffset:[fh offsetInFile]-4-sizeof(footerSize)-footerSize];
	
	tempData=[fh readDataOfLength:footerSize];
	require(tempData, error);
	
	NSXMLDocument			*doc=[[NSXMLDocument alloc] initWithData:tempData options:0 error:NULL];
	require(doc, error);
	[fh closeFile];
	
	return [doc autorelease];
	
error:
	if (fh)
		[fh closeFile];
	return nil;
}

+(NSXMLElement*)XMLElementForArrayOfCDTextBlocks:(NSArray*)a
{
	if (!a || ![a count])
		return nil;
	NSXMLElement			*root=[NSXMLElement elementWithName:@"cdtext"];
	require(root, error);
	
	#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1050
	for(DRCDTextBlock *block in a){
	#else
	NSInteger i;
	for (i = 0; i < [a count]; i ++)
	{
		DRCDTextBlock *block = [a objectAtIndex:i];
	#endif
		
		NSStringEncoding	encoding=[block encoding];
		NSString			*lang=[block language];
		NSString			*strEnc=@"utf8";
		lang = lang ? lang : @"";
		
		switch (encoding){
			case NSUTF8StringEncoding: strEnc=@"utf8"; break;
			case NSASCIIStringEncoding: strEnc=@"ascii"; break;
			case NSShiftJISStringEncoding: strEnc=@"8shiftjis"; break;
			case DRCDTextEncodingISOLatin1Modified: strEnc=@"latin1"; break;
			default: return nil; //not a valid encoding for cdtext
		}
		
		NSXMLElement		*xmlBlock=[NSXMLElement elementWithName:@"cdtextblock"];
		[xmlBlock addAttribute:[NSXMLNode attributeWithName:@"encoding" stringValue:strEnc]];
		[xmlBlock addAttribute:[NSXMLNode attributeWithName:@"language" stringValue:lang]];
		
		NSArray				*trackInfo=[block trackDictionaries];
		#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1050
		for(NSDictionary *info in trackInfo){
		#else
		NSInteger x;
		for (x = 0; x < [trackInfo count]; x ++)
		{
			NSDictionary *info = [trackInfo objectAtIndex:x];
		#endif
			NSXMLElement	*track=[NSXMLElement elementWithName:@"cdtexttrack"];
			
			NSString		*autor=[info objectForKey:DRCDTextSongwriterKey];
			NSString		*msg=[info objectForKey:DRCDTextSpecialMessageKey];
			NSString		*title=[info objectForKey:DRCDTextTitleKey];
			NSString		*mcnisrc=[info objectForKey:DRCDTextMCNISRCKey];
			
			if (autor)
				[track addAttribute:[NSXMLNode attributeWithName:@"songwriter" stringValue:autor]];
			if (msg)
				[track addAttribute:[NSXMLNode attributeWithName:@"specialmessage" stringValue:msg]];
			if (title)
				[track addAttribute:[NSXMLNode attributeWithName:@"title" stringValue:title]];
			if (mcnisrc)
				[track addAttribute:[NSXMLNode attributeWithName:@"mcnisrc" stringValue:mcnisrc]];
			
			[xmlBlock addChild:track];
		}
		
		[root addChild:xmlBlock];
	}
	
	return root;
error:;
	return nil;
}

+(NSArray*)arrayOfCDTextBlocksForXMLElement:(NSXMLElement*)e
{
	if (![[e name] isEqual:@"cdtext"])
		return nil;
	
	NSMutableArray		*ma=[NSMutableArray arrayWithCapacity:1];
	NSArray				*blocks=[e nodesForXPath:@"cdtextblock" error:NULL];
	#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1050
	for(NSXMLElement *bloc in blocks){
	#else
	NSInteger i;
	for (i = 0; i < [blocks count]; i ++)
	{
		NSXMLElement *bloc = [blocks objectAtIndex:i];
	#endif
		NSXMLNode		*xmlEnc=[bloc attributeForName:@"encoding"];
		NSXMLNode		*xmlLang=[bloc attributeForName:@"language"];
		
		NSArray			*tracks=[bloc nodesForXPath:@"cdtexttrack" error:NULL];
		NSMutableArray	*tracksInfo=[NSMutableArray arrayWithCapacity:1];
		#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1050
		for(NSXMLElement *track in tracks){
		#else
		NSInteger x;
		for (x = 0; x < [tracks count]; x ++)
		{
			NSXMLElement *track = [tracks objectAtIndex:x];
		#endif
			NSMutableDictionary *md=[NSMutableDictionary dictionaryWithCapacity:1];
			
			NSXMLNode	*xsongwriter=[track attributeForName:@"songwriter"];
			NSXMLNode	*xspecialmessage=[track attributeForName:@"specialmessage"];
			NSXMLNode	*xtitle=[track attributeForName:@"title"];
			NSXMLNode	*mcnisrc=[track attributeForName:@"mcnisrc"];
			
			if (xsongwriter)
				[md setObject:[xsongwriter stringValue] forKey:DRCDTextSongwriterKey];
			if (xspecialmessage)
				[md setObject:[xspecialmessage stringValue] forKey:DRCDTextSpecialMessageKey];
			if (xtitle)
				[md setObject:[xtitle stringValue] forKey:DRCDTextTitleKey];
			if (mcnisrc)
				[md setObject:[mcnisrc stringValue] forKey:DRCDTextMCNISRCKey];
			
			[tracksInfo addObject:md];
		}
		
		NSString			*txtLang=xmlLang ? [xmlLang stringValue] : @"";
		NSStringEncoding	enc=NSUTF8StringEncoding;
		
		if (xmlEnc){
			NSString		*s=[xmlEnc stringValue];
			if ([@"utf8" isEqual:s])
				enc=NSUTF8StringEncoding;
			else if ([@"ascii" isEqual:s])
				enc=NSASCIIStringEncoding;
			else if ([@"8shiftjis" isEqual:s])
				enc=NSShiftJISStringEncoding;
			else if ([@"latin1" isEqual:s])
				enc=DRCDTextEncodingISOLatin1Modified;
		}
		
		DRCDTextBlock		*block=[DRCDTextBlock cdTextBlockWithLanguage:txtLang encoding:enc];
		
		[block setTrackDictionaries:tracksInfo];
		if (!block)
			goto error;
		[ma addObject:block];
	}
	
	return ma;
error:;
	return nil;
}

@end
