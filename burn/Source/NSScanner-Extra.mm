/*
	VCD Builder - NSScanner-Extra.mm
	
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

#import "NSScanner-Extra.h"

@implementation NSScanner (Extra)

///=====================
//	skipPastString:
///=====================

- (BOOL)skipPastString:(NSString *)skipString
{
	BOOL good = YES;
	
	if (![self scanString:skipString intoString:nil])
		if ((good = [self scanUpToString:skipString intoString:nil]) == YES)
			if ((good = ![self isAtEnd]) == YES)
				[self setScanLocation:[self scanLocation] + [skipString length]];
	
	return good;
}

///=====================
//	scanToEndIntoString:
///=====================

- (BOOL)scanToEndIntoString:(NSString **)result
{
	if (result == nil)
		return NO;
	
	result[0] = [[self string] substringFromIndex:[self scanLocation]];
	return [result[0] length] > 0;
}

@end