/*
	movtowav - main.mm
	
	Copyright 2002 Johan Lindstršm
	All rights reserved.
	
	Redistribution and use in source and binary forms, with or without modification,
	are permitted provided that the following conditions are met:
	
	¥ Redistributions of source code must retain the above copyright notice, this list
	  of conditions and the following disclaimer.
	¥ Redistributions in binary form must reproduce the above copyright notice, this
	  list of conditions and the following disclaimer in the documentation and/or other
	  materials provided with the distribution.
	¥ Neither the name Johan Lindstršm nor the names of the contributors may be used to
	  endorse or promote products derived from this software without specific prior
	  written permission.
	
	
	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY
	EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
	OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT
	SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
	INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
	TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
	BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
	CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
	WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#define __STRICT_ANSI__

#import <Cocoa/Cocoa.h>
#import <QuickTime/QuickTime.h>

#include <fcntl.h>
#import <stdlib.h>
#import <string.h>

NSString * outputPath = nil;
NSMovie  * cocoaMovie = nil;
Movie      movie      = nil;

///=====================
//	printError
///=====================

int printError (char * error)
{
	fprintf(stderr, error);
	
	return 1;
}

///=====================
//	printUsage
///=====================

int printUsage (void)
{
	fprintf(stderr, "usage: movtoway -o output.wav movie.mov\n\n");
	
	return 1;
}

///=====================
//	parseOptions
///=====================

BOOL parseOptions (int argc, const char * argv[])
{
	for (int i = 1; i < argc; i++)
	{
		const char * string = argv[i];
		
		// -o OUTPUT
		if (strncmp(string, "-o", strlen("-o")) == 0)
		{
			if (strlen(string) > strlen("-o"))
				string += strlen("-o");
			else if (i + 1 < argc)
				string = argv[++i];
			else return NO;
			
			outputPath = [[NSString stringWithUTF8String:string] retain];
		}
		// FILENAME
		else if (movie == nil)
		{
			NSString * path = [NSString stringWithUTF8String:string];
			
			cocoaMovie = [[NSMovie alloc] initWithURL:[NSURL fileURLWithPath:path] byReference:YES];
			movie      = (Movie) [cocoaMovie QTMovie];
		}
		// Invalid option
		else return NO;
	}
	
	if (movie == nil || outputPath == nil)
		return NO;
	
	return YES;
}

///=====================
//	setupMovie
///=====================

void setupMovie (void)
{
	SetMovieActive   (movie, YES);
	SetMoviePlayHints(movie, hintsHighQuality, hintsHighQuality);
	
	GoToBeginningOfMovie(movie);
}

///=====================
//	main
///=====================

int main (int argc, const char * argv[])
{
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	if (!parseOptions(argc, argv))
		return printUsage();
	
	if (GetMovieIndTrackType(movie, 1, AudioMediaCharacteristic, movieTrackEnabledOnly | movieTrackCharacteristic) == nil)
		return printError("error: movie contains no audio tracks!\n\n");
	
	setupMovie();
	
	NSString * folderPath = [outputPath stringByDeletingLastPathComponent];
	FSRef      folderRef;
	
	NSString * filename = [[outputPath componentsSeparatedByString:@"/"] lastObject];
	FSSpec     fileSpec;
	
	if ([filename length] <= 0)
		return printError("error: invalid file name!\n\n");
	
	UniChar  * buffer = new UniChar[[filename length]];
	[filename getCharacters:buffer];
	
	//if (FSPathMakeRef((const UInt8 *) [folderPath UTF8String], &folderRef, nil) != noErr)
	//	return printError("error: could not create save folder!\n\n");
	
	if (FSCreateFileUnicode(&folderRef, [filename length], buffer, kFSCatInfoNone, nil, nil, &fileSpec) != noErr)
		return printError("error: could not create save file!\n\n");
	
	if (ConvertMovieToFile(movie, nil, &fileSpec, kQTFileTypeWave, 'TVOD', smSystemScript, nil, 0, nil) != noErr)
		fprintf(stderr, "error: could not convert audio track!\n\n");
	
	delete[] buffer;
	
	[cocoaMovie  release];
	[pool        release];
	
	return 0;
}