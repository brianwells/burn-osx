#import "KWConverter.h"
#if MAC_OS_X_VERSION_MAX_ALLOWED < 1050
#import <QuickTime/QuickTime.h>
#endif

@implementation KWConverter

/////////////////////
// Default actions //
/////////////////////

#pragma mark -
#pragma mark •• Default actions

- (id) init
{
	self = [super init];

	status = 0;
	userCanceled = NO;
	
	convertedFiles = [[NSMutableArray alloc] init];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(cancelEncoding) name:@"KWStopConverter" object:nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWCancelNotificationChanged" object:@"KWStopConverter"];
	
	return self;
}

- (void)dealloc
{
	[convertedFiles release];
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[super dealloc];
}

/////////////////////
// Encode actions //
/////////////////////

#pragma mark -
#pragma mark •• Encode actions

- (NSInteger)batchConvert:(NSArray *)files withOptions:(NSDictionary *)options errorString:(NSString **)error
{
	//Set the options
	convertDestination = [options objectForKey:@"KWConvertDestination"];
	convertExtension = [options objectForKey:@"KWConvertExtension"];
	convertRegion = [[options objectForKey:@"KWConvertRegion"] integerValue];
	convertKind = [[options objectForKey:@"KWConvertKind"] integerValue];

	NSInteger i;
	for (i=0;i<[files count];i++)
	{
		NSString *currentPath = [files objectAtIndex:i];
	
		if (userCanceled == NO)
		{
			number = i;
		
			[[NSNotificationCenter defaultCenter] postNotificationName:@"KWTaskChanged" object:[NSString stringWithFormat:NSLocalizedString(@"Encoding file %i of %i to %@", nil), i + 1, [files count], [options objectForKey:@"KWConvertExtension"]]];
		
			//Test the file on how to encode it
			NSInteger output = [self testFile:currentPath];
			
			useWav = (output == 2 | output == 4 | output == 8);
			useQuickTime = (output == 2 | output == 3 | output == 6);
			
			copyAudio = [self containsAC3:currentPath];
			
			if (useWav)
				output = [self encodeAudioAtPath:currentPath];
			else if (output != 0)
				output = [self encodeFileAtPath:currentPath];
			else
				output = 3;
		
			if (output == 0)
			{
				NSDictionary *output = [NSDictionary dictionaryWithObjectsAndKeys:encodedOutputFile, @"Path", [KWCommonMethods quicktimeChaptersFromFile:currentPath], @"Chapters", nil];
			
				[convertedFiles addObject:output];
			}
			else if (output == 1)
			{
				NSString *displayName = [[NSFileManager defaultManager] displayNameAtPath:currentPath];
				
				[self setErrorStringWithString:[NSString stringWithFormat:NSLocalizedString(@"%@ (Unknown error)", nil), displayName]];
			}
			else if (output == 2)
			{
				if (errorString)
				{
					*error = errorString;
					
					return 1;
				}
				else
				{
					return 2;
				}
			}
		}
		else
		{
			if (errorString)
			{
				*error = errorString;
					
				return 1;
			}
			else
			{
				return 2;
			}
		}
	}
	
	if (errorString)
	{
		*error = errorString;
					
		return 1;
	}
	
	return 0;
}

//Encode the file, use wav file if quicktime created it, use pipe (from movtoy4m)
- (NSInteger)encodeFileAtPath:(NSString *)path
{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWStatusChanged" object:[NSLocalizedString(@"Encoding: ", Localized) stringByAppendingString:[[NSFileManager defaultManager] displayNameAtPath:path]]];
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	// Encoder options for ffmpeg, movtoy4m
	NSString *aspect;
	NSString *ffmpegFormat = @"";
	NSString *outFileWithExtension = [KWCommonMethods uniquePathNameFromPath:[NSString stringWithFormat:@"%@/%@.%@", convertDestination, [[path lastPathComponent] stringByDeletingPathExtension], convertExtension]];
	NSString *outputFile = [outFileWithExtension stringByDeletingPathExtension];
	
	NSArray *quicktimeOptions = [NSArray array];
	NSArray *wavOptions = [NSArray array];
	NSArray *inputOptions = [NSArray array];
	
	NSSize outputSize;
	
	// To keep the aspect ratio ffmpeg needs to pad the movie
	NSArray *padOptions = [NSArray array];
	NSSize aspectSize = NSMakeSize(4, 3);
	//NSInteger dvdAspectMode = [[defaults objectForKey:@"KWDVDAspectMode"] integerValue];
	NSInteger dvdAspectMode = [[defaults objectForKey:@"KWDVDForce43"] integerValue];
	NSInteger calculateSize;
	BOOL topBars;
	
	if (convertRegion == 0)
		ffmpegFormat = @"pal";
	else
		ffmpegFormat = @"ntsc";
	
	if (convertKind == 1 | convertKind == 2)
	{
		aspect = @"4:3";
		aspectSize = NSMakeSize(4, 3);
		topBars = (inputAspect >= (CGFloat)4 / (CGFloat)3);
	}
	
	if (convertKind == 1)
	{
		ffmpegFormat = [NSString stringWithFormat:@"%@-vcd", ffmpegFormat];
	
		if (inputAspect < (CGFloat)4 / (CGFloat)3)
			calculateSize = 352;
		else if (convertRegion == 0)
			calculateSize = 288;
		else
			calculateSize = 240;
			
		if (convertRegion == 0)
			outputSize = NSMakeSize(352, 288);
		else
			outputSize = NSMakeSize(352, 240);
	}
	
	if (convertKind == 2)
	{
		ffmpegFormat = [NSString stringWithFormat:@"%@-svcd", ffmpegFormat];
	
		if (convertRegion == 1 && inputAspect < (CGFloat)4 / (CGFloat)3)
			calculateSize = 576;
		else
			calculateSize = 480;
			
		if (convertRegion == 0)
			outputSize = NSMakeSize(480, 576);
		else
			outputSize = NSMakeSize(480, 480);
	}
	
	if (convertKind == 3)
	{
		ffmpegFormat = [NSString stringWithFormat:@"%@-dvd", ffmpegFormat];
	
		if ((inputAspect <= (CGFloat)4 / (CGFloat)3 && dvdAspectMode != 2) | dvdAspectMode == 1)
		{
			aspectSize = NSMakeSize(4, 3);
			calculateSize = 720;
			topBars = (inputAspect > (CGFloat)4 / (CGFloat)3);
		}
		else
		{
			aspectSize = NSMakeSize(16, 9);
		
			if (convertRegion == 1)
				calculateSize = 576;
			else
				calculateSize = 480;
				
			topBars = (inputAspect > (CGFloat)16 / (CGFloat)9);
		}
		
		if (convertRegion == 0)
			outputSize = NSMakeSize(720, 576);
		else
			outputSize = NSMakeSize(720, 480);
	}
		
	if ((convertKind == 1 | convertKind == 2 | convertKind == 3) && ((inputAspect != (CGFloat)4 / (CGFloat)3 | (inputAspect == (CGFloat)4 / (CGFloat)3 && dvdAspectMode == 2 && convertKind == 3)) && (inputAspect != (CGFloat)16 / (CGFloat)9) | (inputAspect == (CGFloat)16 / (CGFloat)9 && convertKind == 1 | convertKind == 2 | dvdAspectMode == 1)))
	{
		NSInteger padSize = [self getPadSize:calculateSize withAspect:aspectSize withTopBars:topBars];
		
		if (topBars)
			padOptions = [NSArray arrayWithObjects:@"-vf", [NSString stringWithFormat:@"scale=%i:%i,pad=%i:%i:0:%i:black", (NSInteger)outputSize.width, (NSInteger)outputSize.height - (padSize * 2), (NSInteger)outputSize.width, (NSInteger)outputSize.height, padSize], nil];
			//padOptions = [NSArray arrayWithObjects:@"-padtop", padSize, @"-padbottom", padSize, nil];
		else
			padOptions = [NSArray arrayWithObjects:@"-vf", [NSString stringWithFormat:@"scale=%i:%i,pad=%i:%i:%i:0:black", (NSInteger)outputSize.width - (padSize * 2), (NSInteger)outputSize.height, (NSInteger)outputSize.width, (NSInteger)outputSize.height, padSize], nil];
			//padOptions = [NSArray arrayWithObjects:@"-padleft", padSize, @"-padright", padSize, nil];
			
	}
	
	aspect = [NSString stringWithFormat:@"%.0f:%.0f", aspectSize.width, aspectSize.height];

	ffmpeg = [[NSTask alloc] init];
	NSPipe *pipe2;
	NSPipe *errorPipe;

	//Check if we need to use movtoy4m to decode
	if (useQuickTime == YES)
	{
		quicktimeOptions = [NSArray arrayWithObjects:@"-f", @"yuv4mpegpipe", @"-i", @"-", nil];
	
		movtoy4m = [[NSTask alloc] init];
		pipe2 = [[NSPipe alloc] init];
		NSFileHandle *handle2;
		[movtoy4m setLaunchPath:[[NSBundle mainBundle] pathForResource:@"movtoy4m" ofType:@""]];
		[movtoy4m setArguments:[NSArray arrayWithObjects:@"-w",[NSString stringWithFormat:@"%i", inputWidth],@"-h",[NSString stringWithFormat:@"%i", inputHeight],@"-F",[NSString stringWithFormat:@"%f:1", inputFps],@"-a",[NSString stringWithFormat:@"%i:%i", inputWidth, inputHeight],path, nil]];
		[movtoy4m setStandardOutput:pipe2];
		
		if ([defaults boolForKey:@"KWDebug"] == NO)
		{
			errorPipe = [[NSPipe alloc] init];
			[movtoy4m setStandardError:[NSFileHandle fileHandleWithNullDevice]];
		}
	
		[ffmpeg setStandardInput:pipe2];
		handle2=[pipe2 fileHandleForReading];
		[KWCommonMethods logCommandIfNeeded:movtoy4m];
		[movtoy4m launch];
	}
	
	if (useWav == YES)
	{
		wavOptions = [NSArray arrayWithObjects:@"-i", [outputFile stringByAppendingString:@" (tmp).wav"], nil];
	}
	
	if (useWav == NO | useQuickTime == NO)
	{
		inputOptions = [NSArray arrayWithObjects:@"-i", path, nil];
	}

	NSPipe *pipe=[[NSPipe alloc] init];
	NSFileHandle *handle;
	NSData *data;
	
	[ffmpeg setLaunchPath:[KWCommonMethods ffmpegPath]];
	
	NSMutableArray *args;
	
	//QuickTime movie containers don't seem to like threads so only use it for the output file
	NSString *pathExtension = [path pathExtension];
	if ([pathExtension isEqualTo:@"mov"] | [pathExtension isEqualTo:@"m4v"] | [pathExtension isEqualTo:@"mp4"])
		args = [NSMutableArray array];
	else
		args = [NSMutableArray arrayWithObjects:@"-threads", [[defaults objectForKey:@"KWEncodingThreads"] stringValue], nil];
	
	[args addObjectsFromArray:quicktimeOptions];
	[args addObjectsFromArray:wavOptions];
	[args addObjectsFromArray:inputOptions];
	
	if ([pathExtension isEqualTo:@"mov"] | [pathExtension isEqualTo:@"m4v"] | [pathExtension isEqualTo:@"mp4"])
		[args addObjectsFromArray:[NSArray arrayWithObjects:@"-threads", [[defaults objectForKey:@"KWEncodingThreads"] stringValue], nil]];

	if (convertKind == 1 | convertKind == 2)
	{
		[args addObjectsFromArray:[NSArray arrayWithObjects:@"-target",ffmpegFormat,@"-ac",@"2",@"-aspect",aspect,nil]];
	}
	else if (convertKind == 4)
	{
		[args addObjectsFromArray:[NSArray arrayWithObjects:@"-vtag", @"DIVX", @"-acodec", nil]];
				
		if ([[defaults objectForKey:@"KWDefaultDivXSoundType"] integerValue] == 0)
		{
			[args addObject:@"libmp3lame"];
			[args addObject:@"-ac"];
			[args addObject:@"2"];
		}
		else
		{
			[args addObject:@"ac3"];
		}
					
		if ([defaults boolForKey:@"KWCustomDivXVideoBitrate"])
		{
			[args addObject:@"-b"];
			[args addObject:[NSString stringWithFormat:@"%i", [[defaults objectForKey:@"KWDefaultDivXVideoBitrate"] integerValue] * 1000]];
		}
					
		if ([defaults boolForKey:@"KWCustomDivXSoundBitrate"])
		{
			[args addObject:@"-ab"];
			[args addObject:[NSString stringWithFormat:@"%i", [[defaults objectForKey:@"KWDefaultDivxSoundBitrate"] integerValue] * 1000]];
		}
					
		if ([defaults boolForKey:@"KWCustomDivXSize"])
		{
			[args addObject:@"-s"];
			[args addObject:[NSString stringWithFormat:@"%@x%@", [defaults objectForKey:@"KWDefaultDivXWidth"], [defaults objectForKey:@"KWDefaultDivXHeight"]]];
		}
		else if (inputFormat > 0)
		{
			if (convertRegion == 1)
			{
				[args addObject:@"-s"];
				[args addObject:@"1024x576"];
			}
			else
			{
				[args addObject:@"-s"];
				[args addObject:@"1024x480"];
			}
		}
					
		if ([defaults boolForKey:@"KWCustomFPS"])
		{
			[args addObject:@"-r"];
			[args addObject:[defaults objectForKey:@"KWDefaultFPS"]];
		}
	}
	else if (convertKind == 3)
	{
		[args addObjectsFromArray:[NSArray arrayWithObjects:@"-target",ffmpegFormat,@"-ac",@"2", @"-vf", [NSString stringWithFormat:@"setdar=%@", aspect], @"-aspect",aspect,@"-acodec",nil]];
		
		if (copyAudio == NO)
		{
			if ([[defaults objectForKey:@"KWDefaultDVDSoundType"] integerValue] == 0)
				[args addObject:@"mp2"];
			else
				[args addObject:@"ac3"];
				
			if ([defaults boolForKey:@"KWCustomDVDSoundBitrate"])
			{
				[args addObject:@"-ab"];
				[args addObject:[NSString stringWithFormat:@"%i", [[defaults objectForKey:@"KWDefaultDVDSoundBitrate"] integerValue] * 1000]];
			}
			else if ([[defaults objectForKey:@"KWDefaultDVDSoundType"] integerValue] == 0)
			{
				[args addObject:@"-ab"];
				[args addObject:@"224000"];
			}
		}
		else
		{
			[args addObject:@"copy"];
		}
					
		if ([defaults boolForKey:@"KWCustomDVDVideoBitrate"])
		{
			[args addObject:@"-b"];
			[args addObject:[NSString stringWithFormat:@"%i", [[defaults objectForKey:@"KWDefaultDVDVideoBitrate"] integerValue] * 1000]];
		}
					
		
	}
	else if (convertKind == 5)
	{
		[args addObject:@"-ab"];
		[args addObject:[NSString stringWithFormat:@"%i", [[defaults objectForKey:@"KWDefaultMP3Bitrate"] integerValue] * 1000]];
		[args addObject:@"-ac"];
		[args addObject:[[defaults objectForKey:@"KWDefaultMP3Mode"] stringValue]];
		[args addObject:@"-ar"];
		[args addObject:@"44100"];
	}
		
	[args addObject:outFileWithExtension];

	//Fix for DV to mpeg2 conversion
	if (inputFormat == 1)
	{
		if (convertKind == 2)
		{
			//SVCD
			//[args addObjectsFromArray:[NSArray arrayWithObjects:@"-cropleft", @"22", @"-cropright", @"22", nil]];
			[args addObjectsFromArray:[NSArray arrayWithObjects:@"-vf", [NSString stringWithFormat:@"scale=%i:%i,crop=%i:%i:%i:%i", (NSInteger)outputSize.width + 12, (NSInteger)outputSize.height, (NSInteger)outputSize.width, (NSInteger)outputSize.height, 6, 0], nil]];
			
		}
		else if (convertKind == 3)
		{
			//DVD
			//[args addObjectsFromArray:[NSArray arrayWithObjects:@"-cropleft", @"24", @"-cropright", @"24", nil]];
			[args addObjectsFromArray:[NSArray arrayWithObjects:@"-vf", [NSString stringWithFormat:@"scale=%i:%i,crop=%i:%i:%i:%i", (NSInteger)outputSize.width + 16, (NSInteger)outputSize.height, (NSInteger)outputSize.width, (NSInteger)outputSize.height, 8, 0], nil]];
		}
	}
		
	[args addObjectsFromArray:padOptions];
		
	if ([defaults boolForKey:@"KWSaveBorders"] == YES)
	{
		NSNumber *borderSize = [[NSUserDefaults standardUserDefaults] objectForKey:@"KWSaveBorderSize"];
		NSInteger heightBorder = [borderSize integerValue];
		NSInteger widthBorder = [self convertToEven:[[NSNumber numberWithCGFloat:inputWidth / (inputHeight / [borderSize cgfloatValue])] stringValue]];
		
		if ([padOptions count] > 0 && [[padOptions objectAtIndex:0] isEqualTo:@"-padtop"])
		{
			//[args addObjectsFromArray:[NSArray arrayWithObjects:@"-padleft", widthBorder, @"-padright", widthBorder, nil]];
			[args addObjectsFromArray:[NSArray arrayWithObjects:@"-vf", [NSString stringWithFormat:@"scale=%i:%i,pad=%i:%i:%i:0:black", (NSInteger)outputSize.width - (widthBorder * 2), (NSInteger)outputSize.height, (NSInteger)outputSize.width, (NSInteger)outputSize.height, widthBorder], nil]];
		}
		else
		{
			//[args addObjectsFromArray:[NSArray arrayWithObjects:@"-padtop", heightBorder, @"-padbottom", heightBorder, nil]];
			[args addObjectsFromArray:[NSArray arrayWithObjects:@"-vf", [NSString stringWithFormat:@"scale=%i:%i,pad=%i:%i:0:%i:black", (NSInteger)outputSize.width, (NSInteger)outputSize.height - (heightBorder * 2), (NSInteger)outputSize.width, (NSInteger)outputSize.height, heightBorder], nil]];
			
			if ([padOptions count] == 0)
				[args addObjectsFromArray:[NSArray arrayWithObjects:@"-vf", [NSString stringWithFormat:@"scale=%i:%i,pad=%i:%i:%i:0:black", (NSInteger)outputSize.width - (widthBorder * 2), (NSInteger)outputSize.height, (NSInteger)outputSize.width, (NSInteger)outputSize.height, widthBorder], nil]];
				//[args addObjectsFromArray:[NSArray arrayWithObjects:@"-padleft", widthBorder, @"-padright", widthBorder, nil]];
				
		}
	}
		
	[ffmpeg setArguments:args];
	//ffmpeg uses stderr to show the progress
	[ffmpeg setStandardError:pipe];
	handle=[pipe fileHandleForReading];
	
	[KWCommonMethods logCommandIfNeeded:ffmpeg];
	[ffmpeg launch];

	if (useQuickTime == YES)
		status = 3;
	else
		status = 2;

	NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
	NSString *string = nil;

	//Here we go
	while([data=[handle availableData] length]) 
	{
		if (string)
			[string release];
	
		//The string containing ffmpeg's output
		string=[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	
		if ([defaults boolForKey:@"KWDebug"] == YES)
			NSLog(@"%@", string);
		
		//Format the time sting ffmpeg outputs and format it to percent
		if ([string rangeOfString:@"time="].length > 0)
		{
			NSString *currentTimeString = [[[[string componentsSeparatedByString:@"time="] objectAtIndex:1] componentsSeparatedByString:@" "] objectAtIndex:0];
			CGFloat percent = [currentTimeString cgfloatValue] / inputTotalTime * 100;
		
			if (inputTotalTime > 0)
			{
				if (percent < 101)
				{
					[[NSNotificationCenter defaultCenter] postNotificationName:@"KWStatusByAddingPercentChanged" object:[NSString stringWithFormat: @" (%.0f%@)", percent, @"%"]];
					[[NSNotificationCenter defaultCenter] postNotificationName:@"KWValueChanged" object:[NSNumber numberWithDouble:percent + (double)number * 100]];
				}
			}
			else
			{
				[[NSNotificationCenter defaultCenter] postNotificationName:@"KWStatusByAddingPercentChanged" object:@" (?%)"];
			}
		}

		data = nil;
	
		[innerPool release];
		innerPool = [[NSAutoreleasePool alloc] init];
	}

	//After there's no output wait for ffmpeg to stop
	[ffmpeg waitUntilExit];

	//Check if the encoding succeeded, if not remove the mpg file ,NOT POSSIBLE :-(
	NSInteger taskStatus = [ffmpeg terminationStatus];

	//Release ffmpeg
	[ffmpeg release];
	
	//If we used a wav file, delete it
	if (useWav == YES)
		[KWCommonMethods removeItemAtPath:[outputFile stringByAppendingString:@" (tmp).wav"]];
	
	if (useQuickTime == YES)
	{	
		[movtoy4m release];
		[pipe2 release];
	}
	
	[pipe release];
	
	//Return if ffmpeg failed or not
	if (taskStatus == 0)
	{
		status = 0;
		encodedOutputFile = outFileWithExtension;
	
		return 0;
	}
	else if (userCanceled == YES)
	{
		status = 0;
		
		[KWCommonMethods removeItemAtPath:outFileWithExtension];
		
		return 2;
	}
	else
	{
		status = 0;
		
		[KWCommonMethods removeItemAtPath:outFileWithExtension];
	
		[string release];
		
		return 1;
	}
}

//Encode sound to wav
- (NSInteger)encodeAudioAtPath:(NSString *)path
{
	NSFileManager *defaultFileManager = [NSFileManager defaultManager];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWStatusChanged" object:[NSString stringWithFormat:NSLocalizedString(@"Decoding sound: %@", nil), [[NSFileManager defaultManager] displayNameAtPath:path]]];

	//Output file (without extension)
	NSString *outputFile = [NSString stringWithFormat:@"%@/%@", convertDestination, [[path lastPathComponent] stringByDeletingPathExtension]];

	outputFile = [[KWCommonMethods uniquePathNameFromPath:[outputFile stringByAppendingPathExtension:convertExtension]] stringByDeletingPathExtension];

	if (convertKind != 6)
		outputFile = [NSString stringWithFormat:@"%@ (tmp)", outputFile];

	if ([defaultFileManager fileExistsAtPath:[outputFile stringByAppendingString:@".wav"]])
		[KWCommonMethods removeItemAtPath:[outputFile stringByAppendingString:@".wav"]];
	
	//movtowav encodes quicktime movie's sound to wav
	movtowav = [[NSTask alloc] init];
	[movtowav setLaunchPath:[[NSBundle mainBundle] pathForResource:@"movtowav" ofType:@""]];
	[movtowav setArguments:[NSArray arrayWithObjects:@"-o", [outputFile stringByAppendingString:@".wav"], path,nil]];
	NSInteger taskStatus;

	NSPipe *pipe=[[NSPipe alloc] init];
	NSFileHandle *handle=[pipe fileHandleForReading];
	[movtowav setStandardError:pipe];
	[KWCommonMethods logCommandIfNeeded:movtowav];
	[movtowav launch];
	NSString *string=[[NSString alloc] initWithData:[handle readDataToEndOfFile] encoding:NSUTF8StringEncoding];

	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWDebug"] == YES)
		NSLog(@"%@", string);

	status = 1;
	[movtowav waitUntilExit];
	taskStatus = [movtowav terminationStatus];
	[movtowav release];
	[pipe release];
	
	//Check if it all went OK if not remove the wave file and return NO
    if (!taskStatus == 0)
	{
		[KWCommonMethods removeItemAtPath:[outputFile stringByAppendingString:@".wav"]];
	
		status = 0;
		
		if (userCanceled == YES)
		{
			[string release];
		
			return 2;
		}
		else
		{
			//[KWCommonMethods writeLogWithFilePath:path withCommand:@"movtowav" withLog:string];
			[string release];

			return 1;
		}
	}
	
	[string release];

	//if (format == 5)
	//	[self testFile:[outputFile stringByAppendingString:@".wav"]];
	
	if (convertKind == 6)
	{
		[[NSNotificationCenter defaultCenter] postNotificationName:@"KWValueChanged" object:[NSNumber numberWithDouble:((double)number + 1) * 100]];
		encodedOutputFile = [outputFile stringByAppendingString:@".wav"];
		return 0;
	}
	
	return [self encodeFileAtPath:path];	
}

//Stop encoding (stop ffmpeg, movtowav and movtoy4m if they're running
- (void)cancelEncoding
{
	userCanceled = YES;
	
	if (status == 1 | status == 3)
	{
		[movtowav terminate];
	}
	
	if (status == 2 | status == 3)
	{
		[ffmpeg terminate];
	}
}

/////////////////////
// Test actions //
/////////////////////

#pragma mark -
#pragma mark •• Test actions

//Test if ffmpeg can encode, sound and/or video, and if it does have any sound
- (NSInteger)testFile:(NSString *)path
{
	NSString *displayName = [[NSFileManager defaultManager] displayNameAtPath:path];
	NSString *tempFile = [[[NSUserDefaults standardUserDefaults] objectForKey:@"KWTemporaryLocation"] stringByAppendingPathComponent:@"tempkf.mpg"];
	
	BOOL audioWorks = YES;
	BOOL videoWorks = YES;
	BOOL keepGoing = YES;

	while (keepGoing == YES)
	{
		NSMutableArray *arguments = [NSMutableArray arrayWithObjects:@"-t",@"0.1",@"-threads",[[NSNumber numberWithInteger:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWEncodingThreads"] integerValue]] stringValue],@"-i",path,@"-target",@"pal-vcd", nil];
			
		if (videoWorks == NO)
			[arguments addObject:@"-vn"];
		else if (audioWorks == NO)
			[arguments addObject:@"-an"];
				
		[arguments addObjectsFromArray:[NSArray arrayWithObjects:@"-ac",@"2",@"-r",@"25",@"-y", tempFile,nil]];
		
		NSString *string;
		[KWCommonMethods launchNSTaskAtPath:[KWCommonMethods ffmpegPath] withArguments:arguments outputError:YES outputString:YES output:&string];
		
		keepGoing = NO;
		
		NSInteger code = 0;
		NSString *error = @"%@ (Unknown error)";
		
		if ([string rangeOfString:@"Video: Apple Intermediate Codec"].length > 0)
		{
			if ([self setTimeAndAspectFromOutputString:string fromFile:path])
				return 2;
			else
				return 0;
		}
			
		if ([string rangeOfString:@"error reading header: -1"].length > 0 && [string rangeOfString:@"iDVD"].length > 0)
			code = 2;
	
		// Check if ffmpeg reconizes the file
		if ([string rangeOfString:@"Unknown format"].length > 0 && [string rangeOfString:@"Unknown format is not supported as input pixel format"].length == 0)
		{
			error = [NSString stringWithFormat:NSLocalizedString(@"%@ (Unknown format)", nil), displayName];
			[self setErrorStringWithString:error];
			
			return 0;
		}
		
		//Check if ffmpeg reconizes the codecs
		if ([string rangeOfString:@"could not find codec parameters"].length > 0)
			error = [NSString stringWithFormat:NSLocalizedString(@"%@ (Couldn't get attributes)", nil), displayName];
			
		//No audio
		if ([string rangeOfString:@"error: movie contains no audio tracks!"].length > 0 && convertKind < 5)
			error = [NSString stringWithFormat:NSLocalizedString(@"%@ (No audio)", nil), displayName];
	
		//Check if the movie is a (internet/local)reference file
		if ([self isReferenceMovie:string])
			code = 2;
			
		if (code == 0 | !error)
		{
			if ([string rangeOfString:@"edit list not starting at 0, a/v desync might occur, patch welcome"].length > 0)
				videoWorks = NO;
			
			if ([string rangeOfString:@"Unknown format is not supported as input pixel format"].length > 0)
				videoWorks = NO;
				
			if ([string rangeOfString:@"Resampling with input channels greater than 2 unsupported."].length > 0)
				audioWorks = NO;
			
			NSString *input = [[[[string componentsSeparatedByString:@"Output #0"] objectAtIndex:0] componentsSeparatedByString:@"Input #0"] objectAtIndex:1];
			if ([input rangeOfString:@"mp2"].length > 0 && [input rangeOfString:@"mov,"].length > 0)
				audioWorks = NO;
			
			BOOL hasVideoCheck = ([string rangeOfString:@"Video:"].length > 0);
			BOOL hasAudioCheck = ([string rangeOfString:@"Audio:"].length > 0);
			BOOL videoWorksCheck = [self streamWorksOfKind:@"Video" inOutput:string];
			BOOL audioWorksCheck = [self streamWorksOfKind:@"Audio" inOutput:string];
			
			if (hasVideoCheck && hasAudioCheck)
			{
				if (audioWorksCheck && videoWorksCheck && videoWorks && audioWorks)
				{
					code = 1;
				}
				else if (!audioWorksCheck | !videoWorksCheck)
				{
					if (videoWorks && audioWorks)
						keepGoing = YES;
				
					if (!audioWorksCheck)
						audioWorks = NO;
					else if (!videoWorksCheck)
						videoWorks = NO;
				}
			}
			else
			{
				if (!hasVideoCheck && !hasAudioCheck)
				{
					error = [NSString stringWithFormat:NSLocalizedString(@"%@ (No audio/video)", nil), displayName];
				}
				else if (!hasVideoCheck && hasAudioCheck)
				{
					if (convertKind < 5)
					{
						error = [NSString stringWithFormat:NSLocalizedString(@"%@ (No video)", nil), displayName];
					}
					else
					{
						code = 8;
						if (audioWorksCheck)
							code = 7;
					}
				}
				else if (hasVideoCheck && !hasAudioCheck)
				{
					if (convertKind > 4)
					{
						error = [NSString stringWithFormat:NSLocalizedString(@"%@ (No audio)", nil), displayName];
					}
					else
					{
						code = 6;
						if (videoWorksCheck)
							code = 5;
					}
				}
			}
		}
		
		if (!keepGoing)
		{
			if (code == 0 | !error)
			{
				if (videoWorks && !audioWorks)
				{
					if ([[[path pathExtension] lowercaseString] isEqualTo:@"mpg"] | [[[path pathExtension] lowercaseString] isEqualTo:@"mpeg"] | [[[path pathExtension] lowercaseString] isEqualTo:@"m2v"])
						error = [NSString stringWithFormat:NSLocalizedString(@"%@ (Unsupported audio)", nil), displayName];
					else
						code = 4;
				}
				else if (!videoWorks && audioWorks)
				{
					code = 3;
				}
				else if (!videoWorks && !audioWorks)
				{
					code = 2;
				}
			}
			
			useWav = (code == 2 | code == 4 | code == 8);
			useQuickTime = (code == 2 | code == 3 | code == 6);
			
			if (code > 0)
			{
				if ([self setTimeAndAspectFromOutputString:string fromFile:path])
					return code;
				else
					return 0;
			}
			else
			{
				[self setErrorStringWithString:error];
				
				return 0;
			}
		}
	}
	
	[KWCommonMethods removeItemAtPath:tempFile];
	
	return 0;
}

- (BOOL)streamWorksOfKind:(NSString *)kind inOutput:(NSString *)output
{
	NSString *one = [[[[[[output componentsSeparatedByString:@"Output #0"] objectAtIndex:0] componentsSeparatedByString:@"Stream #0.0"] objectAtIndex:1] componentsSeparatedByString:@": "] objectAtIndex:1];
	NSString *two = @"";
	
	if ([output rangeOfString:@"Stream #0.1"].length > 0)
		two = [[[[[[output componentsSeparatedByString:@"Output #0"] objectAtIndex:0] componentsSeparatedByString:@"Stream #0.1"] objectAtIndex:1] componentsSeparatedByString:@": "] objectAtIndex:1];

	//Is stream 0.0 audio or video
	if ([output rangeOfString:@"for input stream #0.0"].length > 0 | [output rangeOfString:@"Error while decoding stream #0.0"].length > 0)
	{
		if ([one isEqualTo:kind])
		{
			return NO;
		}
	}
			
	//Is stream 0.1 audio or video
	if ([output rangeOfString:@"for input stream #0.1"].length > 0| [output rangeOfString:@"Error while decoding stream #0.1"].length > 0)
	{
		if ([two isEqualTo:kind])
		{
			return NO;
		}
	}
	
	return YES;
}

- (BOOL)isReferenceMovie:(NSString *)output
{
	//Found in reference or streaming QuickTime movies
	return ([output rangeOfString:@"unsupported slice header"].length > 0 | [output rangeOfString:@"bitrate: 5 kb/s"].length > 0);
}

- (BOOL)setTimeAndAspectFromOutputString:(NSString *)output fromFile:(NSString *)file
{	
	NSString *inputString = [[output componentsSeparatedByString:@"Input"] objectAtIndex:1];

	inputWidth = 0;
	inputHeight = 0;
	inputFps = 0;
	inputTotalTime = 0;
	inputAspect = 0;
	inputFormat = 0;

	//Calculate the aspect ratio width / height	
	if ([[[inputString componentsSeparatedByString:@"Output"] objectAtIndex:0] rangeOfString:@"Video:"].length > 0)
	{
		//NSString *resolution;
		NSArray *resolutionArray = [[[[[[[inputString componentsSeparatedByString:@"Output"] objectAtIndex:0] componentsSeparatedByString:@"Video:"] objectAtIndex:1] componentsSeparatedByString:@"\n"] objectAtIndex:0] componentsSeparatedByString:@"x"];
		NSArray *fpsArray = [[[[[inputString componentsSeparatedByString:@"Output"] objectAtIndex:0] componentsSeparatedByString:@" tbc"] objectAtIndex:0] componentsSeparatedByString:@","];
		
		NSArray *beforeX = [[resolutionArray objectAtIndex:0] componentsSeparatedByString:@" "];
		NSArray *afterX = [[resolutionArray objectAtIndex:1] componentsSeparatedByString:@" "];
		
		inputWidth = [[beforeX objectAtIndex:[beforeX count] - 1] integerValue];
		inputHeight = [[afterX objectAtIndex:0] integerValue];
		inputFps = [[fpsArray objectAtIndex:[fpsArray count] - 1] integerValue];
	
		if (inputFps == 25 && [inputString rangeOfString:@"Video: dvvideo"].length > 0)
		{
			inputWidth = 720;
			inputHeight = 576;
		}
		
		inputAspect = (CGFloat)inputWidth / (CGFloat)inputHeight;
		
		
		if (inputWidth == 352 && (inputHeight == 288 | inputHeight == 240))
			inputAspect = (CGFloat)4 / (CGFloat)3;
		else if ((inputWidth == 480 | inputWidth == 720 | inputWidth == 784) && (inputHeight == 576 | inputHeight == 480))
			inputAspect = (CGFloat)4 / (CGFloat)3;

		//Check if the iMovie project is 4:3 or 16:9
		if ([inputString rangeOfString:@"Video: dvvideo"].length > 0)
		{
			if ([file rangeOfString:@".iMovieProject"].length > 0)
			{
				NSString *projectName = [[[[[file stringByDeletingLastPathComponent] stringByDeletingLastPathComponent] stringByDeletingLastPathComponent] stringByDeletingPathExtension] lastPathComponent];
				NSString *projectLocation = [[[file stringByDeletingLastPathComponent] stringByDeletingLastPathComponent]stringByDeletingLastPathComponent];
				NSString *projectSettings = [[projectLocation stringByAppendingPathComponent:projectName] stringByAppendingPathExtension:@"iMovieProj"];
			
				if ([[NSFileManager defaultManager] fileExistsAtPath:projectSettings])
				{
					if ([[KWCommonMethods stringWithContentsOfFile:projectSettings] rangeOfString:@"WIDE"].length > 0)
					{
						inputWidth = 1024;
						inputAspect = (CGFloat)16 / (CGFloat)9;
					}
					else
					{
						inputAspect = (CGFloat)4 / (CGFloat)3;
					}
				}
			}
			else 
			{
				if ([inputString rangeOfString:@"[PAR 59:54 DAR 295:216]"].length > 0 | [inputString rangeOfString:@"[PAR 10:11 DAR 15:11]"].length)
					inputAspect = (CGFloat)4 / (CGFloat)3;
				else if ([inputString rangeOfString:@"[PAR 118:81 DAR 295:162]"].length > 0 | [inputString rangeOfString:@"[PAR 40:33 DAR 20:11]"].length)
					inputAspect = (CGFloat)16 / (CGFloat)9;
			}
		
			inputFormat = 1;
		}

		if ([inputString rangeOfString:@"DAR 16:9"].length > 0)
		{
			inputAspect = (CGFloat)16 / (CGFloat)9;
			
			if ([inputString rangeOfString:@"mpeg2video"].length > 0)
			{
				inputWidth = 1024;
				inputFormat = 2;
			}
		}
	
		//iMovie projects with HDV 1080i are 16:9, ffmpeg guesses 4:3
		if ([inputString rangeOfString:@"Video: Apple Intermediate Codec"].length > 0)
		{
			//if ([file rangeOfString:@".iMovieProject"].length > 0)
			//{
				inputAspect = (CGFloat)16 / (CGFloat)9;
				inputWidth = 1024;
				inputHeight = 576;
			//}
		}
	}
	
	if ([inputString rangeOfString:@"DAR 119:90"].length > 0)
		inputAspect = (CGFloat)4 / (CGFloat)3;
	
	if ([inputString rangeOfString:@"Duration:"].length > 0)	
	{
		inputTotalTime = 0;
	
		if (![inputString rangeOfString:@"Duration: N/A,"].length > 0)
		{
			NSString *time = [[[[inputString componentsSeparatedByString:@"Duration: "] objectAtIndex:1] componentsSeparatedByString:@","] objectAtIndex:0];
			double hour = [[[time componentsSeparatedByString:@":"] objectAtIndex:0] doubleValue];
			double minute = [[[time componentsSeparatedByString:@":"] objectAtIndex:1] doubleValue];
			double second = [[[time componentsSeparatedByString:@":"] objectAtIndex:2] doubleValue];
			
			inputTotalTime  = (hour * 60 * 60) + (minute * 60) + second;
		}
	}
	
	BOOL hasOutput = YES;
	
	if (inputWidth == 0 && inputHeight == 0 && inputFps == 0 && convertKind < 5)
		hasOutput = NO;
		
	if (hasOutput)
	{
		return YES;
	}
	else
	{
		[self setErrorStringWithString:[NSString stringWithFormat:NSLocalizedString(@"%@ (Couldn't get attributes)", nil), [[NSFileManager defaultManager] displayNameAtPath:file]]];
		return NO;
	}
}

///////////////////////
// Compilant actions //
///////////////////////

#pragma mark -
#pragma mark •• Compilant actions

- (NSString *)ffmpegOutputForPath:(NSString *)path
{
	NSString *string;
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSArray *arguments = [NSArray arrayWithObjects:@"-threads", [[defaults objectForKey:@"KWEncodingThreads"] stringValue], @"-i", path, nil];
	[KWCommonMethods launchNSTaskAtPath:[KWCommonMethods ffmpegPath] withArguments:arguments outputError:YES outputString:YES output:&string];
	
	if (![string rangeOfString:@"Unknown format"].length > 0 && [string rangeOfString:@"Input #0"].length > 0)
		return [[string componentsSeparatedByString:@"Input #0"] objectAtIndex:1];
	else
		return nil;

}

//Check if the file is a valid VCD file (return YES if it is valid)
- (BOOL)isVCD:(NSString *)path
{
	NSString *string = [self ffmpegOutputForPath:path];
	
	if (string)
		return ([string rangeOfString:@"mpeg1video"].length > 0 && [string rangeOfString:@"352x288"].length > 0 | [string rangeOfString:@"352x240"].length > 0 && [string rangeOfString:@"25.00 tb(r)"].length > 0 | [string rangeOfString:@"29.97 tb(r)"].length > 0 | [string rangeOfString:@"25 tbr"].length > 0 | [string rangeOfString:@"29.97 tbr"].length > 0);

	return NO;
}

//Check if the file is a valid SVCD file (return YES if it is valid)
- (BOOL)isSVCD:(NSString *)path
{
	NSString *string = [self ffmpegOutputForPath:path];
	
	if (string)
		return ([string rangeOfString:@"mpeg2video"].length > 0 && [string rangeOfString:@"480x576"].length > 0 | [string rangeOfString:@"480x480"].length > 0 && [string rangeOfString:@"25.00 tb(r)"].length > 0 | [string rangeOfString:@"29.97 tb(r)"].length > 0 | [string rangeOfString:@"25 tbr"].length > 0 | [string rangeOfString:@"29.97 tbr"].length > 0);

	return NO;
}

//Check if the file is a valid DVD file (return YES if it is valid)
- (BOOL)isDVD:(NSString *)path isWideAspect:(BOOL *)wideAspect
{
	if ([[path pathExtension] isEqualTo:@"m2v"])
		return NO;
		
	NSString *string = [self ffmpegOutputForPath:path];
	
	if (string)
	{
		if ([string rangeOfString:@"DAR 16:9"].length > 0)
			*wideAspect = YES;
		else
			*wideAspect = NO;
	
		return ([string rangeOfString:@"mpeg2video"].length > 0 && [string rangeOfString:@"720x576"].length > 0 | [string rangeOfString:@"720x480"].length > 0 && [string rangeOfString:@"25.00 tb(r)"].length > 0 | [string rangeOfString:@"29.97 tb(r)"].length > 0 | [string rangeOfString:@"25 tbr"].length > 0 | [string rangeOfString:@"29.97 tbr"].length > 0);
	}
	
	return NO;
}

//Check if the file is a valid MPEG4 file (return YES if it is valid)
- (BOOL)isMPEG4:(NSString *)path
{
	NSString *string = [self ffmpegOutputForPath:path];
	
	if (string)
		return ([[[path pathExtension] lowercaseString] isEqualTo:@"avi"] && ([string rangeOfString:@"Video: mpeg4"].length > 0 | ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWAllowMSMPEG4"] == YES && [string rangeOfString:@"Video: msmpeg4"].length > 0)));

	return NO;
}

//Check if the file is allready an Audio-CD compatible file (2 or 5.1 channels)
- (BOOL)isAudioCDFile:(NSString *)path
{
	NSString *string = [self ffmpegOutputForPath:path];
	
	if (string)
		return ([string rangeOfString:@"pcm_s16le"].length > 0 && [string rangeOfString:@"44100"].length > 0 && [string rangeOfString:@"s16"].length > 0 && [string rangeOfString:@"1411 kb/s"].length > 0 && ([string rangeOfString:@"2 channels"].length > 0 | [string rangeOfString:@"5.1"].length > 0));

	return NO;
}

//Check for ac3 audio
- (BOOL)containsAC3:(NSString *)path
{
	NSString *string = [self ffmpegOutputForPath:path];
	
	if (string)
		return ([string rangeOfString:@"Audio: ac3"].length > 0);

	return NO;
}

///////////////////////
// Framework actions //
///////////////////////

#pragma mark -
#pragma mark •• Framework actions

- (NSArray *)succesArray
{
	return convertedFiles;
}

///////////////////
// Other actions //
///////////////////

#pragma mark -
#pragma mark •• Other actions

- (NSInteger)convertToEven:(NSString *)numberAsString
{
	NSString *convertedNumber = [[NSNumber numberWithInteger:[numberAsString integerValue]] stringValue];

	unichar ch = [convertedNumber characterAtIndex:[convertedNumber length] -1];
	NSString *lastCharacter = [NSString stringWithFormat:@"%C", ch];

	if ([lastCharacter isEqualTo:@"1"] | [lastCharacter isEqualTo:@"3"] | [lastCharacter isEqualTo:@"5"] | [lastCharacter isEqualTo:@"7"] | [lastCharacter isEqualTo:@"9"])
		return [[NSNumber numberWithInteger:[convertedNumber integerValue] + 1] integerValue];
	else
		return [convertedNumber integerValue];
}

- (NSInteger)getPadSize:(CGFloat)size withAspect:(NSSize)aspect withTopBars:(BOOL)topBars
{
	NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];

	CGFloat heightBorder = 0;
	CGFloat widthBorder = 0;

	if ([standardDefaults boolForKey:@"KWSaveBorders"] == YES)
	{
		heightBorder = [[standardDefaults objectForKey:@"KWSaveBorderSize"] cgfloatValue];
		widthBorder = aspect.width / (aspect.height / size);
	}
	
	if (topBars)
		return [self convertToEven:[[NSNumber numberWithCGFloat:(size - (size * aspect.width / aspect.height) / ((CGFloat)inputWidth / (CGFloat)inputHeight)) / 2 + heightBorder] stringValue]];
	else
		return [self convertToEven:[[NSNumber numberWithCGFloat:((size * aspect.width / aspect.height) / ((CGFloat)inputWidth / (CGFloat)inputHeight) - size) / 2 + widthBorder] stringValue]];
}

- (BOOL)remuxMPEG2File:(NSString *)path outPath:(NSString *)outFile
{
	status = 2;
	NSArray *arguments = [NSArray arrayWithObjects:@"-threads",[[NSNumber numberWithInteger:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWEncodingThreads"] integerValue]] stringValue],@"-i",path,@"-y",@"-acodec",@"copy",@"-vcodec",@"copy",@"-target",@"dvd",outFile,nil];
	//Not used yet
	NSString *errorsString;
	BOOL result = [KWCommonMethods launchNSTaskAtPath:[KWCommonMethods ffmpegPath] withArguments:arguments outputError:YES outputString:YES output:&errorsString];
	status = 0;
	
	if (result)
	{
		return YES;
	}
	else
	{
		[KWCommonMethods removeItemAtPath:outFile];
		return NO;
	}
}

- (BOOL)canCombineStreams:(NSString *)path
{
	NSFileManager *defaultManager = [NSFileManager defaultManager];
	NSString *pathWithOutExtension = [path stringByDeletingPathExtension];

	return ([defaultManager fileExistsAtPath:[pathWithOutExtension stringByAppendingPathExtension:@"mp2"]] | [defaultManager fileExistsAtPath:[pathWithOutExtension stringByAppendingPathExtension:@"ac3"]]);
}

- (BOOL)combineStreams:(NSString *)path atOutputPath:(NSString *)outputPath
{
	NSString *audioFile;
	
	NSFileManager *defaultManager = [NSFileManager defaultManager];
	NSString *pathWithOutExtension = [path stringByDeletingPathExtension];
	NSString *mp2File = [pathWithOutExtension stringByAppendingPathExtension:@"mp2"];
	NSString *ac3File = [pathWithOutExtension stringByAppendingPathExtension:@"ac3"];

	if ([defaultManager fileExistsAtPath:mp2File])
		audioFile = mp2File;
	else if ([defaultManager fileExistsAtPath:ac3File])
		audioFile = ac3File;

	if (audioFile)
	{
		status = 2;
		NSArray *arguments = [NSArray arrayWithObjects:@"-threads",[[NSNumber numberWithInteger:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWEncodingThreads"] integerValue]] stringValue],@"-i",path,@"-threads",[[NSNumber numberWithInteger:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWEncodingThreads"] integerValue]] stringValue],@"-i",audioFile,@"-y",@"-acodec",@"copy",@"-vcodec",@"copy",@"-target",@"dvd",outputPath,nil];
		//Not used yet
		NSString *errorsString;
		BOOL result = [KWCommonMethods launchNSTaskAtPath:[KWCommonMethods ffmpegPath] withArguments:arguments outputError:YES outputString:YES output:&errorsString];
		status = 0;

		if (result)
		{
			return YES;
		}
		else
		{
			[KWCommonMethods removeItemAtPath:outputPath];
			return NO;
		}
	}
	else
	{
		return NO;
	}
}

- (NSInteger)totalTimeInSeconds:(NSString *)path
{
	NSString *string = [self ffmpegOutputForPath:path];
	NSString *durationsString = [[[[string componentsSeparatedByString:@"Duration: "] objectAtIndex:1] componentsSeparatedByString:@"."] objectAtIndex:0];

	NSInteger hours = [[[durationsString componentsSeparatedByString:@":"] objectAtIndex:0] integerValue];
	NSInteger minutes = [[[durationsString componentsSeparatedByString:@":"] objectAtIndex:1] integerValue];
	NSInteger seconds = [[[durationsString componentsSeparatedByString:@":"] objectAtIndex:2] integerValue];

	return seconds + (minutes * 60) + (hours * 60 * 60);
}

- (NSString *)mediaTimeString:(NSString *)path
{
	NSString *string = [self ffmpegOutputForPath:path];
	return [[[[[[[string componentsSeparatedByString:@"Duration: "] objectAtIndex:1] componentsSeparatedByString:@","] objectAtIndex:0] componentsSeparatedByString:@":"] objectAtIndex:1] stringByAppendingString:[@":" stringByAppendingString:[[[[[[string componentsSeparatedByString:@"Duration: "] objectAtIndex:1] componentsSeparatedByString:@","] objectAtIndex:0] componentsSeparatedByString:@":"] objectAtIndex:2]]];
}

- (NSImage *)getImageAtPath:(NSString *)path atTime:(NSInteger)time isWideScreen:(BOOL)wide
{
	NSArray *arguments = [NSArray arrayWithObjects:@"-ss",[[NSNumber numberWithInteger:time] stringValue],@"-i",path,@"-vframes",@"1" ,@"-f",@"image2",@"-",nil];
	NSData *data;
	NSImage *image;
	BOOL result = [KWCommonMethods launchNSTaskAtPath:[KWCommonMethods ffmpegPath] withArguments:arguments outputError:NO outputString:NO output:&data];
	
	if (result && data)
	{
		image = [[NSImage alloc] initWithData:data];

		if (wide)
			[image setSize:NSMakeSize(720,404)];
			
		return image;
	}
	else if (result && !data && time > 1)
	{
		return [self getImageAtPath:path atTime:1 isWideScreen:wide];
	}
		
	return nil;
}

- (void)setErrorStringWithString:(NSString *)string
{
	if (errorString)
		errorString = [NSString stringWithFormat:@"%@\n%@", errorString, string];
	else
		errorString = [string retain];
}

@end