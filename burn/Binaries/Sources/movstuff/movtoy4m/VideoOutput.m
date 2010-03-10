/*
	movto4ym - VideoOutput.m
	
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

#include <fcntl.h>
#include <sys/types.h>
#include <sys/uio.h>
#include <unistd.h>

#import <QuickTime/QuickTime.h>

#import "VideoOutput.h"

unsigned long Y_r [256];
unsigned long Y_g [256];
unsigned long Y_b [256];

unsigned long Cb_r[256];
unsigned long Cb_g[256];
unsigned long Cb_b[256];

unsigned long Cr_r[256];
unsigned long Cr_g[256];
unsigned long Cr_b[256];

#define kFixShift 14
#define kFixMult  (1 << kFixShift)

///=============================================================================
//  convertColorBuffers_Y4M
///=============================================================================

#define AVERAGE_2(_a, _b) (((((_a) ^ (_b)) & 0xFEFEFEFE) >> 1) + ((_a) & (_b)))

static void convertColorBuffers_Y4M (const void * baseAddr, const unsigned rowBytes, const unsigned width, const unsigned height,
	unsigned char * buffer_Y, unsigned char * buffer_Cb, unsigned char * buffer_Cr)
{
	const unsigned char * pixelPointer = (unsigned char *) baseAddr;
	
	unsigned r, g, b;
	unsigned x, y;
	
	for (y = 0; y < height; y += 2)
	{
		const unsigned long * rowPixelPointer = (unsigned long *) pixelPointer;
		
		unsigned char * buffer_Y_a = buffer_Y;
		unsigned char * buffer_Y_b = buffer_Y + width;
		
		for (x = 0; x < width; x += 4)
		{
			/* == argb: 4 pixels row 1 ===================== */
			const unsigned long argb_0_a = (*rowPixelPointer++);
			const unsigned long argb_1_a = (*rowPixelPointer++);
			const unsigned long argb_0_b = (*rowPixelPointer++);
			const unsigned long argb_1_b = (*rowPixelPointer++);
			rowPixelPointer = (unsigned long *) (((char *) rowPixelPointer) + rowBytes - 4 * sizeof(long));
			
			/* == argb: 4 pixels row 2 ===================== */
			const unsigned long argb_2_a = (*rowPixelPointer++);
			const unsigned long argb_3_a = (*rowPixelPointer++);
			const unsigned long argb_2_b = (*rowPixelPointer++);
			const unsigned long argb_3_b = (*rowPixelPointer++);
			rowPixelPointer = (unsigned long *) (((char *) rowPixelPointer) - rowBytes);
			
			/* == buffer_y: 4 pixels row 1 ===================== */
			r = (argb_0_a >> 16) & 0xFF; g = (argb_0_a >> 8) & 0xFF; b = (argb_0_a >> 0) & 0xFF;
			*(buffer_Y_a++) = (Y_r[r] + Y_g[g] + Y_b[b] + 16 * kFixMult) >> kFixShift;
			
			r = (argb_1_a >> 16) & 0xFF; g = (argb_1_a >> 8) & 0xFF; b = (argb_1_a >> 0) & 0xFF;
			*(buffer_Y_a++) = (Y_r[r] + Y_g[g] + Y_b[b] + 16 * kFixMult) >> kFixShift;
			
			r = (argb_0_b >> 16) & 0xFF; g = (argb_0_b >> 8) & 0xFF; b = (argb_0_b >> 0) & 0xFF;
			*(buffer_Y_a++) = (Y_r[r] + Y_g[g] + Y_b[b] + 16 * kFixMult) >> kFixShift;
			
			r = (argb_1_b >> 16) & 0xFF; g = (argb_1_b >> 8) & 0xFF; b = (argb_1_b >> 0) & 0xFF;
			*(buffer_Y_a++) = (Y_r[r] + Y_g[g] + Y_b[b] + 16 * kFixMult) >> kFixShift;
			
			/* == buffer_y: 4 pixels row 2 ===================== */
			r = (argb_2_a >> 16) & 0xFF; g = (argb_2_a >> 8) & 0xFF; b = (argb_2_a >> 0) & 0xFF;
			*(buffer_Y_b++) = (Y_r[r] + Y_g[g] + Y_b[b] + 16 * kFixMult) >> kFixShift;
			
			r = (argb_3_a >> 16) & 0xFF; g = (argb_3_a >> 8) & 0xFF; b = (argb_3_a >> 0) & 0xFF;
			*(buffer_Y_b++) = (Y_r[r] + Y_g[g] + Y_b[b] + 16 * kFixMult) >> kFixShift;
			
			r = (argb_2_b >> 16) & 0xFF; g = (argb_2_b >> 8) & 0xFF; b = (argb_2_b >> 0) & 0xFF;
			*(buffer_Y_b++) = (Y_r[r] + Y_g[g] + Y_b[b] + 16 * kFixMult) >> kFixShift;
			
			r = (argb_3_b >> 16) & 0xFF; g = (argb_3_b >> 8) & 0xFF; b = (argb_3_b >> 0) & 0xFF;
			*(buffer_Y_b++) = (Y_r[r] + Y_g[g] + Y_b[b] + 16 * kFixMult) >> kFixShift;
			
			/* == buffer_Cb & buffer_Cr: 1 pixel ===================== */
			const long a_0 = AVERAGE_2(argb_0_a, argb_1_a);
			const long a_1 = AVERAGE_2(argb_2_a, argb_3_a);
			const long a_2 = AVERAGE_2(a_0, a_1);
			
			r = (a_2 >> 16) & 0xFF; g = (a_2 >> 8) & 0xFF; b = (a_2 >> 0) & 0xFF;
			
			*(buffer_Cb++) = (Cb_r[r] + Cb_g[g] + Cb_b[b] + 128 * kFixMult) >> kFixShift;
			*(buffer_Cr++) = (Cr_r[r] + Cr_g[g] + Cr_b[b] + 128 * kFixMult) >> kFixShift;
			
			/* == buffer_Cb & buffer_Cr: 1 pixel ===================== */
			const long b_0 = AVERAGE_2(argb_0_b, argb_1_b);
			const long b_1 = AVERAGE_2(argb_2_b, argb_3_b);
			const long b_2 = AVERAGE_2(b_0, b_1);
			
			r = (b_2 >> 16) & 0xFF; g = (b_2 >> 8) & 0xFF; b = (b_2 >> 0) & 0xFF;
			
			*(buffer_Cb++) = (Cb_r[r] + Cb_g[g] + Cb_b[b] + 128 * kFixMult) >> kFixShift;
			*(buffer_Cr++) = (Cr_r[r] + Cr_g[g] + Cr_b[b] + 128 * kFixMult) >> kFixShift;
		}
		
		buffer_Y     += width    << 1;
		pixelPointer += rowBytes << 1;
	}
}

#undef AVERAGE_2

///=============================================================================
//  convertColorBuffers_PPM
///=============================================================================

static void convertColorBuffers_PPM (const void * baseAddr, const unsigned rowBytes, const unsigned width, const unsigned height, unsigned char * buffer)
{
	unsigned char * pixelPointer = (unsigned char *) baseAddr;
	unsigned x, y;
	
	for (y = 0; y < height; y++)
	{
		unsigned long * rowPixelPointer = (unsigned long *) pixelPointer;
		
		for (x = 0; x < width; x++)
		{
			unsigned long argb = *(rowPixelPointer++);
			*(buffer++) = (argb >> 16) & 0xFF;
			*(buffer++) = (argb >>  8) & 0xFF;
			*(buffer++) = (argb >>  0) & 0xFF;
		}
		
		pixelPointer += rowBytes;
	}
}

///=============================================================================
//  private VideoOutput
///=============================================================================

@interface VideoOutput (Private)

+ (NSRect)fit:(NSRect)rect inRect:(NSRect)dest;

- (BOOL)setupOffscreen;

@end

@implementation VideoOutput (Private)

///=============================================================================
//  fit:inRect:
///=============================================================================

+ (NSRect)fit:(NSRect)rect inRect:(NSRect)dest
{
	double xScale = dest.size.width  / rect.size.width;
	double yScale = dest.size.height / rect.size.height;
	
	double minScale = MIN(xScale, yScale);
	NSRect newRect  = NSMakeRect(0.0, 0.0, rect.size.width * minScale, rect.size.height * minScale);
	return NSOffsetRect(newRect, dest.origin.x + (dest.size.width - newRect.size.width) / 2.0,
		dest.origin.y + (dest.size.height - newRect.size.height) / 2.0);
}

///=============================================================================
//  setupOffscreen
///=============================================================================

- (BOOL)setupOffscreen
{
	if (offscreen       != nil) DisposeGWorld(offscreen);
	if (scaledOffscreen != nil) DisposeGWorld(scaledOffscreen);
	if (imageDesc       != nil) DisposeHandle((Handle) imageDesc);
	if (imageSequence   != 0)   CDSequenceEnd(imageSequence);
	
	// Thanks to Tyler Loch for fixing Intel support.
#ifdef __BIG_ENDIAN__
	if (QTNewGWorld(&offscreen,       k32ARGBPixelFormat, &boundsRect, nil, nil, keepLocal) != noErr) return NO;
	if (QTNewGWorld(&scaledOffscreen, k32ARGBPixelFormat, &finalRect,  nil, nil, keepLocal) != noErr) return NO;
#else
	if (QTNewGWorld(&offscreen,       k32BGRAPixelFormat, &boundsRect, nil, nil, keepLocal) != noErr) return NO;
	if (QTNewGWorld(&scaledOffscreen, k32BGRAPixelFormat, &finalRect,  nil, nil, keepLocal) != noErr) return NO;
#endif
	
	if (!LockPixels(GetGWorldPixMap(offscreen)))       return NO;
	if (!LockPixels(GetGWorldPixMap(scaledOffscreen))) return NO;
	
	pixMapOffscreen = GetGWorldPixMap(offscreen);
	pixMapScaled    = GetGWorldPixMap(scaledOffscreen);
	
	baseAddr = GetPixBaseAddr(pixMapScaled);
	rowBytes = GetPixRowBytes(pixMapScaled);
	
	RectMatrix(&imageMatrix, &boundsRect, &scaledRect);
	MakeImageDescriptionForPixMap(pixMapOffscreen, &imageDesc);
	
	DecompressSequenceBeginS(&imageSequence, imageDesc, GetPixBaseAddr(pixMapOffscreen), (**imageDesc).dataSize, scaledOffscreen, nil, nil,
		&imageMatrix, ditherCopy, nil, kNilOptions, codecHighQuality, bestFidelityCodec);
	
	SetMovieGWorld(movie, offscreen, GetGWorldDevice(offscreen));
	SetGWorld(scaledOffscreen, nil);
	
	ForeColor(blackColor);
	PaintRect(&finalRect);
	
	return YES;
}

@end

@implementation VideoOutput

///=============================================================================
//  initialize
///=============================================================================

+ (void)initialize
{
	if (self == [VideoOutput class])
	{
		int i; for (i = 0; i < 256; i++)
		{
//			Y_r[i]  = (long) (( 0.257 * i) * kFixMult);
//			Y_g[i]  = (long) (( 0.504 * i) * kFixMult);
//			Y_b[i]  = (long) (( 0.098 * i) * kFixMult);
			
			Y_r[i]  = (long) (( 0.270 * i) * kFixMult);
			Y_g[i]  = (long) (( 0.529 * i) * kFixMult);
			Y_b[i]  = (long) (( 0.103 * i) * kFixMult);
			
			Cb_r[i] = (long) ((-0.148 * i) * kFixMult);
			Cb_g[i] = (long) ((-0.291 * i) * kFixMult);
			Cb_b[i] = (long) (( 0.439 * i) * kFixMult);
			
			Cr_r[i] = (long) (( 0.439 * i) * kFixMult);
			Cr_g[i] = (long) ((-0.368 * i) * kFixMult);
			Cr_b[i] = (long) ((-0.071 * i) * kFixMult);
		}
	}
}

///=============================================================================
//  initWithQTMovie:
///=============================================================================

- (id)initWithQTMovie:(Movie)inputMovie outputFormat:(int)format
{
	if ((self = [super init]) != nil)
	{
		movie        = inputMovie;
		outputFormat = format;
		
		timeScale = GetMovieTimeScale(movie);
		duration  = GetMovieDuration (movie);
		
		GetMovieBox(movie, &boundsRect);
		OffsetRect(&boundsRect, -boundsRect.left, -boundsRect.top);
		SetMovieBox(movie, &boundsRect);
		
		width  = boundsRect.right;
		height = boundsRect.bottom;
	}
	
	return self;
}

///=============================================================================
//  dealloc
///=============================================================================

- (void)dealloc
{
	if (offscreen       != nil) DisposeGWorld(offscreen);
	if (scaledOffscreen != nil) DisposeGWorld(scaledOffscreen);
	if (imageDesc       != nil) DisposeHandle((Handle) imageDesc);
	if (imageSequence   != 0)   CDSequenceEnd(imageSequence);
	
	[super dealloc];
}

///=============================================================================
//  setWidth:height:rate1:rate2:aspect1:aspect2:fillFrame:
///=============================================================================

- (void)setWidth:(int)w height:(int)h rate1:(int)r1 rate2:(int)r2 aspect1:(int)a1 aspect2:(int)a2 fillFrame:(BOOL)fillFrame
{
	finalWidth  = w;
	finalHeight = h;
	
	fps_1 = r1;
	fps_2 = r2;
	
	encodingFPS = ((float) fps_1) / ((float) fps_2);
	
	Rect movieBounds;
	GetMovieNaturalBoundsRect(movie, &movieBounds);
	
	NSRect movieRect    = NSMakeRect(0.0, 0.0, movieBounds.right - movieBounds.left, movieBounds.bottom - movieBounds.top);
	NSRect screenRect   = NSMakeRect(0.0, 0.0, finalWidth, finalHeight);
	NSRect unscaledRect = NSMakeRect(0.0, 0.0, a1, a2);
	
	if (fillFrame)
	{
		movieRect.size.width  = screenRect.size.width;
		movieRect.size.height = screenRect.size.height;
	}
	else
	{
		movieRect = [VideoOutput fit:movieRect inRect:unscaledRect];
		
		double xScale = screenRect.size.width  / unscaledRect.size.width;
		double yScale = screenRect.size.height / unscaledRect.size.height;
		
		movieRect.size.width  *= xScale;
		movieRect.size.height *= yScale;
		
		movieRect.origin.x = (screenRect.size.width  - movieRect.size.width)  / 2.0;
		movieRect.origin.y = (screenRect.size.height - movieRect.size.height) / 2.0;
	}
	
	SetRect(&scaledRect, 0, 0, (short) movieRect.size.width, (short) movieRect.size.height);
	OffsetRect(&scaledRect, (short) movieRect.origin.x, (short) movieRect.origin.y);
	SetRect(&finalRect, 0, 0, finalWidth, finalHeight);
	
	[self setupOffscreen];
}

///=============================================================================
//  convert
///=============================================================================

- (void)convert
{
	currentFrame = 0;
	
	unsigned        frameBufferLength;
	unsigned char * frameDataBuffer;
	unsigned char * buffer;
	unsigned char * buffer_Y  = NULL;
	unsigned char * buffer_Cb = NULL;
	unsigned char * buffer_Cr = NULL;
	
	if (outputFormat == kOutputPPM)
	{
		char frameHeader[128];
		sprintf(frameHeader, "P6\n%d %d\n255\n", (int) finalWidth, (int) finalHeight);
		
		frameBufferLength = finalWidth * finalHeight * 3 + strlen(frameHeader);
		buffer = (unsigned char *) malloc(frameBufferLength);
		
		frameDataBuffer = buffer + strlen(frameHeader);
		memcpy(buffer, frameHeader, strlen(frameHeader));
	}
	else
	{
		const char * frameHeader = (outputFormat == kOutputY4M? "FRAME\n": "");
		
		frameBufferLength = finalWidth * finalHeight + ((finalWidth * finalHeight) >> 1) + strlen(frameHeader);
		buffer = (unsigned char *) malloc(frameBufferLength);
		
		frameDataBuffer = buffer + strlen(frameHeader);
		memcpy(buffer, frameHeader, strlen(frameHeader));
		
		buffer_Y  = frameDataBuffer;
		buffer_Cb = buffer_Y  +  (finalWidth * finalHeight);
		buffer_Cr = buffer_Cb + ((finalWidth * finalHeight) >> 2);
		
		if (outputFormat == kOutputY4M)
		{
			printf("YUV4MPEG2 W%d H%d F%d:%d Ip A1:1\n", (int) finalWidth, (int) finalHeight, (int) fps_1, (int) fps_2);
			fflush(stdout);
		}
	}
	
	while (YES)
	{
		TimeValue timeValue = (TimeValue) ceil(((((double) currentFrame++) / encodingFPS) * (double) timeScale));
		
		if (timeValue >= duration)
			break;
		
		SetMovieTimeValue(movie, timeValue);
		MoviesTask(movie, 0);
		
		DecompressSequenceFrameWhen(imageSequence, GetPixBaseAddr(pixMapOffscreen), (**imageDesc).dataSize, kNilOptions, nil, nil, nil);
		
		if (outputFormat == kOutputPPM)
			convertColorBuffers_PPM(baseAddr, rowBytes, finalWidth, finalHeight, frameDataBuffer);
		else
			convertColorBuffers_Y4M(baseAddr, rowBytes, finalWidth, finalHeight, buffer_Y, buffer_Cb, buffer_Cr);
		
		write(STDOUT_FILENO, buffer, frameBufferLength);
	}
	
	free(buffer);
}

@end