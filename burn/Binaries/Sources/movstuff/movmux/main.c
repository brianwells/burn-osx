/*
	movmux - main.c
	
	Copyright 2003 Johan Lindström
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

#include <fcntl.h>
#include <stdio.h>
#include <unistd.h>

#include <Carbon/Carbon.h>
#include <CoreFoundation/CoreFoundation.h>
#include <QuickTime/QuickTime.h>

#ifndef false
#define false 0
#endif

#ifndef true
#define true 1
#endif

///=====================
//	fileSpecFromPath
///=====================

static Boolean fileSpecFromPath (const char * path, FSSpec * fileSpec)
{
	CFStringRef filePath = CFStringCreateWithCStringNoCopy(kCFAllocatorDefault, path, kCFStringEncodingUTF8, kCFAllocatorNull);
	CFURLRef    fileURL  = CFURLCreateWithFileSystemPath  (kCFAllocatorDefault, filePath, kCFURLPOSIXPathStyle, false);
	Boolean     result   = false;
	FSRef       fsRef;
	
	if (fileSpec != NULL && fileURL != NULL && CFURLGetFSRef(fileURL, &fsRef))
		result = FSGetCatalogInfo(&fsRef, kFSCatInfoNone, NULL, NULL, fileSpec, NULL) == noErr;
	
	if (filePath != NULL) CFRelease(filePath);
	if (fileURL  != NULL) CFRelease(fileURL);
	
	return result;
}

///=====================
//	insertMovieIntoMovie
///=====================

static void insertMovieIntoMovie (Movie srcMovie, Movie dstMovie)
{
	int index;
	
	InsertMovieSegment(srcMovie, dstMovie, 0, GetMovieDuration(srcMovie), GetMovieDuration(dstMovie));
	
	// Move all tracks to the beginning of the movie. This will screw up advanced QuickTime movies with
	// multiple tracks that begin at arbitrary times in the movie. I'll leave it at that for now.
	for (index = 1; index <= GetMovieTrackCount(dstMovie); index++)
		SetTrackOffset(GetMovieIndTrack(dstMovie, index), 0);
}

///=====================
//	main
///=====================

int main (int argc, const char * argv[])
{
	if (argc < 3)
	{
		fprintf(stderr, "At least one input and one output file required.\n\n");
		return EXIT_FAILURE;
	}
	
	EnterMovies();
	
	{
		FSSpec outputSpec;
		int    fd;
		
		if ((fd = open(argv[argc - 1], O_WRONLY | O_CREAT, 0666)) == -1)
		{
			fprintf(stderr, "1. Could not create output file: %s\n\n", argv[argc - 1]);
			return EXIT_FAILURE;
		}
		
		close(fd);
		
		if (!fileSpecFromPath(argv[argc - 1], &outputSpec))
		{
			fprintf(stderr, "2. Could not create output file.\n\n");
			return EXIT_FAILURE;
		}
		
		{
			Movie outputMovie = NewMovie(kNilOptions);
			int   index;
			
			if (outputMovie == nil)
			{
				fprintf(stderr, "Could not create output movie.\n\n");
				return EXIT_FAILURE;
			}
			
			for (index = 1; index < argc - 1; index++)
			{
				FSSpec inputSpec;
				short  inputFile;
				Movie  inputMovie;
				
				if (!fileSpecFromPath(argv[index], &inputSpec))
				{
					fprintf(stderr, "Could not open file \"%s\".\n\n", argv[index]);
					continue;
				}
				
				if (OpenMovieFile(&inputSpec, &inputFile, fsRdPerm) != noErr)
				{
					fprintf(stderr, "Could not open file \"%s\".\n\n", argv[index]);
					continue;
				}
				
				if (NewMovieFromFile(&inputMovie, inputFile, NULL, NULL, newMovieDontAskUnresolvedDataRefs, NULL) != noErr)
				{
					fprintf(stderr, "Could not open file \"%s\".\n\n", argv[index]);
					continue;
				}
				
				insertMovieIntoMovie(inputMovie, outputMovie);
				
				DisposeMovie  (inputMovie);
				CloseMovieFile(inputFile);
			}
			
			// Maybe we should install a progress callback here, to give the user some feedback.
			FlattenMovie(outputMovie, flattenAddMovieToDataFork, &outputSpec, 'TVOD', smSystemScript, createMovieFileDeleteCurFile, NULL, NULL);
			DisposeMovie(outputMovie);
		}
	}
	
	return EXIT_SUCCESS;
}
