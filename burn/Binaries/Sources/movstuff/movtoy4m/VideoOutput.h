/*
	movtoy4m - VideoOutput.h
	
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

#import <Foundation/Foundation.h>
#import <Carbon/Carbon.h>

///=============================================================================
//  enum output format
///=============================================================================

enum
{
	kOutputY4M,
	kOutputPPM,
	kOutputRAW
};

///=============================================================================
//  class VideoOutput
///=============================================================================

@interface VideoOutput: NSObject
{
	@protected
	Movie movie;
	
	TimeScale timeScale;
	TimeValue duration;
	
	double encodingFPS;
	int    currentFrame;
	int    outputFormat;
	
	Rect boundsRect;
	Rect scaledRect;
	Rect finalRect;
	
	GWorldPtr offscreen;
	GWorldPtr scaledOffscreen;
	
	PixMapHandle pixMapOffscreen;
	PixMapHandle pixMapScaled;
	
	char * baseAddr;
	long   rowBytes;
	
	unsigned long width;
	unsigned long height;
	
	unsigned long finalWidth;
	unsigned long finalHeight;
	
	MatrixRecord           imageMatrix;
	ImageDescriptionHandle imageDesc;
	ImageSequence          imageSequence;
	
	unsigned long fps_1;
	unsigned long fps_2;
}

- (id)initWithQTMovie:(Movie)inputMovie outputFormat:(int)format;

- (void)setWidth:(int)w height:(int)h rate1:(int)r1 rate2:(int)r2 aspect1:(int)a1 aspect2:(int)a2 fillFrame:(BOOL)fillFrame;
- (void)convert;

@end