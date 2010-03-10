/*
	movto4ym - main.m
	
	Copyright 2002-2006 Johan Lindström
	All rights reserved.
	
	Redistribution and use in source and binary forms, with or without modification,
	are permitted provided that the following conditions are met:
	
	• Redistributions of source code must retain the above copyright notice, this list
	  of conditions and the following disclaimer.
	• Redistributions in binary form must reproduce the above copyright notice, this
	  list of conditions and the following disclaimer in the documentation and/or other
	  materials provided with the distribution.
	• Neither the name Johan Lindström nor the names of the contributors may be used to
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

#import <Cocoa/Cocoa.h>
#import <QuickTime/QuickTime.h>

#include <fcntl.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#import "VideoOutput.h"

int width  = 352;
int height = 288;

int fps_1 = 30000;
int fps_2 =  1001;

int aspect_1 = 4;
int aspect_2 = 3;

BOOL fillFrame   = NO;
BOOL singleField = NO;
int  format      = kOutputY4M;

NSMovie * cocoaMovie = nil;
Movie     movie      = nil;

///=============================================================================
//  printUsage
///=============================================================================

static int printUsage (void)
{
	fprintf(stderr, "usage:   movtoy4m -w width -h height -F a:b -a a:b [-s] [-f] [-o ppm/y4m/raw] movie.mov\n\n");
	fprintf(stderr, "example: movtoy4m -w 352 -h 288 -F 25:1 -a 4:3 pal_normal.mov\n");
	fprintf(stderr, "example: movtoy4m -w 352 -h 240 -F 30000:1001 -a 16:9 ntsc_wide.mov\n\n");
	
	return 1;
}

///=============================================================================
//  parseOptions
///=============================================================================

static BOOL parseOptions (int argc, char * const argv[])
{
	while (getopt(argc, argv, "fso:w:h:F:a:") != -1)
	{
		char * string = optarg;
		
		switch (optopt)
		{
			case 'f': fillFrame = YES;       break;
			case 's': singleField = YES;     break;
			case 'w': width  = atoi(optarg); break;
			case 'h': height = atoi(optarg); break;
			
			case 'F':
				fps_1 = atoi(string);
				
				while (string[0] && string[0] != ':')
					string++;
				
				if (strlen(string) > 1)
					fps_2 = atoi(string + 1);
				
				if (fps_2 == 0)
					fps_2 = fps_1 == 30000? 1001: 1;
				
				break;
			
			case 'a':
				aspect_1 = atoi(string);
				
				while (string[0] && string[0] != ':')
					string++;
				
				if (strlen(string) > 1)
					aspect_2 = atoi(string + 1);
				
				if (aspect_2 == 0)
					aspect_2 = aspect_1 == 16? 9: 3;
				
				break;
			
			case 'o':
				if (strcmp(string, "ppm") == 0)
					format = kOutputPPM;
				if (strcmp(string, "raw") == 0)
					format = kOutputRAW;
				break;
			
			default:
				printUsage();
				return NO;
		}
	}
	
	argc -= optind;
	argv += optind;
	
	if (argc != 1)
	{
		printUsage();
		return NO;
	}
	
	NSString * path = [NSString stringWithUTF8String:argv[0]];
	
	cocoaMovie = [[NSMovie alloc] initWithURL:[NSURL fileURLWithPath:path] byReference:YES];
	movie      = (Movie) [cocoaMovie QTMovie];
	
	if (movie == nil)
	{
		fprintf(stderr, "ERROR: Could not open movie: %s\n", argv[0]);
		return NO;
	}
	
	if (width <= 0 || height <= 0)
	{
		fprintf(stderr, "ERROR: Width and height must be positive numbers.\n");
		return NO;
	}
	
	if (fps_1 <= 0 || fps_2 <= 0)
	{
		fprintf(stderr, "ERROR: Invalid framerate specified.\n");
		return NO;
	}
	
	if (aspect_1 <= 0 || aspect_2 <= 0)
	{
		fprintf(stderr, "ERROR: Invalid aspect ratio specified.\n");
		return NO;
	}
	
	return YES;
}

///=============================================================================
//  setupMovie
///=============================================================================

static void setupMovie (void)
{
	SetMovieActive   (movie, YES);
	SetMoviePlayHints(movie, hintsHighQuality, hintsHighQuality);
	
	if (singleField)
		SetMoviePlayHints(movie, hintsSingleField, hintsSingleField);
	
	GoToBeginningOfMovie(movie);
}

///=============================================================================
//  main
///=============================================================================

int main (int argc, char * const argv[])
{
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	fprintf(stderr, "movtoy4m\nCopyright 2002-2006 Johan Lindström\nAll rights reserved..\n");
	
	if (!parseOptions(argc, argv))
		return EXIT_FAILURE;
	
	if (GetMovieIndTrackType(movie, 1, VisualMediaCharacteristic, movieTrackEnabledOnly | movieTrackCharacteristic) == nil)
	{
		fprintf(stderr, "ERROR: Movie contains no video tracks!\n\n");
		return EXIT_FAILURE;
	}
	
	setupMovie();
	
	VideoOutput * videoOutput = [[VideoOutput alloc] initWithQTMovie:movie outputFormat:format];
	
	[videoOutput setWidth:width height:height rate1:fps_1 rate2:fps_2 aspect1:aspect_1 aspect2:aspect_2 fillFrame:fillFrame];
	[videoOutput convert];
	
	[videoOutput release];
	[cocoaMovie  release];
	[pool        release];
	
	return EXIT_SUCCESS;
}