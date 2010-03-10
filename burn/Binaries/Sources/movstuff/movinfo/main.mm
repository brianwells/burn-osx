/*
	movinfo - main.mm
	
	Copyright 2003 Johan Lindstršm
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
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

///=====================
//	printUsage
///=====================

static int printUsage (void)
{
	fprintf(stderr, "usage: movinfo movie.mov\n\n");
	
	return EXIT_FAILURE;
}

///=====================
//	printMovieInfo
///=====================

static int printMovieInfo (NSString * path)
{
	NSMovie * cocoaMovie = [[NSMovie alloc] initWithURL:[NSURL fileURLWithPath:path] byReference:YES];
	Movie     movie      = (Movie) [cocoaMovie QTMovie];
	
	if (movie == NULL)
		return EXIT_FAILURE;
	
	/* == Width & Height ===================== */
	Rect boundsRect;
	GetMovieBox(movie, &boundsRect);
	int width  = boundsRect.right  - boundsRect.left;
	int height = boundsRect.bottom - boundsRect.top;
	
	/* == Duration ===================== */
	TimeScale timeScale = GetMovieTimeScale(movie);
	TimeValue duration  = GetMovieDuration (movie);
	
	/* == Frames ===================== */
	int   frame = -1;
	short flags = nextTimeStep | nextTimeEdgeOK;
	
	TimeValue blipTimeValue = 0;
	OSType    mediaType     = VisualMediaCharacteristic;
	
	while (blipTimeValue >= 0)
	{
		GetMovieNextInterestingTime(movie, flags, 1, &mediaType, blipTimeValue, fixed1, &blipTimeValue, NULL);
		
		frame++;
		flags = nextTimeStep;
	}
	
	float seconds = ((float) duration) / ((float) timeScale);
	
	/* == Output ===================== */
	printf("%d, %d, %d, %.2f\n", frame, width, height, ((float) frame) / seconds);
	
	return EXIT_SUCCESS;
}

///=====================
//	main
///=====================

int main (int argc, char * const argv[])
{
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	if (argc != 2)
		return printUsage();
	
	int err = printMovieInfo([NSString stringWithUTF8String:argv[1]]);
	
	[pool release];
	
	return err;
}