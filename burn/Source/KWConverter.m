#import "KWConverter.h"
#import "KWCommonMethods.h"
#import <QuickTime/QuickTime.h>

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
inputWidth = @"";
inputHeight = @"";
inputTotalTime = @"";
inputFps = @"";
aspectValue = -1;
userCanceled = NO;
convertedFiles = [[NSMutableArray alloc] init];
failedFilesExplained = [[NSMutableArray alloc] init];
[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(cancelEncoding) name:@"KWStopConverter" object:nil];
[[NSNotificationCenter defaultCenter] postNotificationName:@"KWCancelNotificationChanged" object:@"KWStopConverter"];
	
return self;
}

- (void)dealloc
{
[convertedFiles release];
[failedFilesExplained release];
[[NSNotificationCenter defaultCenter] removeObserver:self];

[super dealloc];
}

/////////////////////
// Encode actions //
/////////////////////

#pragma mark -
#pragma mark •• Encode actions

- (int)batchConvert:(NSArray *)files destination:(NSString *)path useRegion:(NSString *)region useKind:(NSString *)kind
{
NSString *outputFolder = [path stringByAppendingString:@"/"];
int regionInt;
int kindInt;
NSString *formatTaskString;

	if ([region isEqualTo:@"PAL"])
	regionInt = 1;
	else
	regionInt = 2;
	
	if ([kind isEqualTo:@"VCD"])
	{
	formatTaskString = NSLocalizedString(@" to VCD mpg", Localized);
	kindInt = 1;
	}
	else if ([kind isEqualTo:@"SVCD"])
	{
	formatTaskString = NSLocalizedString(@" to SVCD mpg", Localized);
	kindInt = 2;
	}
	else if ([kind isEqualTo:NSLocalizedString(@"DVD-Video",@"Localized")])
	{
	formatTaskString = NSLocalizedString(@" to DVD mpg", Localized);
	kindInt = 3;
	}
	else if ([kind isEqualTo:@"DivX"])
	{
	formatTaskString = NSLocalizedString(@" to DivX avi", Localized);
	kindInt = 4;
	}
	else if ([kind isEqualTo:@"mp3"])
	{
	formatTaskString = NSLocalizedString(@" to mp3", Localized);
	kindInt = 5;
	}
	else if ([kind isEqualTo:@"wav"])
	{
	formatTaskString = NSLocalizedString(@" to wav", Localized);
	kindInt = 6;
	}
	
	
	int i;
	for (i=0;i<[files count];i++)
	{
		if (userCanceled == NO)
		{
		number = i;
		[[NSNotificationCenter defaultCenter] postNotificationName:@"KWTaskChanged" object:[[[[NSLocalizedString(@"Encoding file ", Localized) stringByAppendingString:[[NSNumber numberWithInt:i+1] stringValue]] stringByAppendingString:NSLocalizedString(@" of ", Localized)] stringByAppendingString:[[NSNumber numberWithInt:[files count]] stringValue]] stringByAppendingString:formatTaskString]];
		
		int output = [self encodeFile:[files objectAtIndex:i] setOutputFolder:outputFolder setRegion:regionInt setFormat:kindInt];
		
			if (output == 0)
			{
			[convertedFiles addObject:encodedOutputFile];
			}
			else if (output == 1)
			{
			[failedFilesExplained addObject:[[[NSFileManager defaultManager] displayNameAtPath:[files objectAtIndex:i]] stringByAppendingString:NSLocalizedString(@" (Unknown error)", Localized)]];
			}
			else if (output == 2)
			{
				if ([failedFilesExplained count] > 0)
				return 1;
				else
				return 2;
			}
		}
		else
		{
			if ([failedFilesExplained count] > 0)
			return 1;
			else
			return 2;
		}
	}
	
	if ([failedFilesExplained count] > 0)
	return 1;
	
return 0;
}

//Encode the file, use wav file if quicktime created it, use pipe (from movtoy4m)
-(int)encodeFile:(NSString *)path useWavFile:(BOOL)wav useQuickTime:(BOOL)mov setOutputFolder:(NSString *)outputFolder setRegion:(int)region setFormat:(int)format
{
[[NSNotificationCenter defaultCenter] postNotificationName:@"KWStatusChanged" object:[NSLocalizedString(@"Encoding: ", Localized) stringByAppendingString:[[NSFileManager defaultManager] displayNameAtPath:path]]];
// Encoder options for ffmpeg, movtoy4m
NSString *aspect;
NSString *ffmpegFormat = @"";
NSString *outputFile = [outputFolder stringByAppendingString:[[path lastPathComponent] stringByDeletingPathExtension]];
	
	if (format == 4)
	{
	outputFile = [[KWCommonMethods uniquePathNameFromPath:[outputFile stringByAppendingString:@".avi"] withLength:0] stringByDeletingPathExtension];
	}
	else if (format == 5)
	{
	outputFile = [[KWCommonMethods uniquePathNameFromPath:[outputFile stringByAppendingString:@".mp3"] withLength:0] stringByDeletingPathExtension];
	}
	else if (format == 6)
	{
	outputFile = [[KWCommonMethods uniquePathNameFromPath:[outputFile stringByAppendingString:@".wav"] withLength:0] stringByDeletingPathExtension];
	}
	else
	{
	outputFile = [[KWCommonMethods uniquePathNameFromPath:[outputFile stringByAppendingString:@".mpg"] withLength:0] stringByDeletingPathExtension];
	}
	
// To keep the aspect ratio ffmpeg needs to pad the movie
NSString *padTop = @"";
NSString *padBottom = @"";
NSString *padTopSize = @"";
NSString *padBottomSize = @"";
		
	//VCD
	if (format == 1)
	{
		//PAL
		if (region == 1)
		{
		aspect = @"4:3";
		ffmpegFormat = @"pal-vcd";
			
			if (aspectValue == 1)
			{
			NSString *padSize = [self getPadSize:288 withAspectW:4 withAspectH:3 withWidth:1.85 withHeight:1 withBlackBars:YES];
			padTop = @"-padtop";
			padBottom = @"-padbottom";
			padTopSize = padSize;		
			padBottomSize = padSize;
			}
			else if (aspectValue == 2)
			{
			NSString *padSize = [self getPadSize:288 withAspectW:4 withAspectH:3 withWidth:16 withHeight:9 withBlackBars:YES];
			padTop = @"-padtop";
			padBottom = @"-padbottom";
			padTopSize = padSize;		
			padBottomSize = padSize;
			}
			else if (aspectValue == 3)
			{
			NSString *padSize = [self getPadSize:288 withAspectW:4 withAspectH:3 withWidth:2.35 withHeight:1 withBlackBars:YES];
			padTop = @"-padtop";
			padBottom = @"-padbottom";
			padTopSize = padSize;		
			padBottomSize = padSize;
			}
			else if (aspectValue == 4)
			{
			NSString *padSize = [self getPadSize:288 withAspectW:4 withAspectH:3 withWidth:2.20 withHeight:1 withBlackBars:YES];
			padTop = @"-padtop";
			padBottom = @"-padbottom";
			padTopSize = padSize;		
			padBottomSize = padSize;
			}
			else if (aspectValue == 5)
			{
			aspect = @"4:3";
			}
			else if (aspectValue == 6)
			{
			NSString *padSize = [self getPadSize:288 withAspectW:4 withAspectH:3 withWidth:[inputWidth floatValue] withHeight:[inputHeight floatValue] withBlackBars:YES];
			padTop = @"-padtop";
			padBottom = @"-padbottom";
			padTopSize = padSize;		
			padBottomSize = padSize;
			}
			else if (aspectValue == 7)
			{
			NSString *padSize = [self getPadSize:288 withAspectW:4 withAspectH:3 withWidth:[inputWidth floatValue] withHeight:[inputHeight floatValue] withBlackBars:YES];
			padTop = @"-padtop";
			padBottom = @"-padbottom";
			padTopSize = padSize;		
			padBottomSize = padSize;
			}
			else if (aspectValue == 8)
			{
			NSString *padSize = [self getPadSize:352 withAspectW:4 withAspectH:3 withWidth:[inputWidth floatValue] withHeight:[inputHeight floatValue] withBlackBars:NO];
			padTop = @"-padleft";
			padBottom = @"-padright";
			padTopSize = padSize;		
			padBottomSize = padSize;
			}
		}
		//NTSC
		else if (region == 2)
		{
		aspect = @"4:3";
		ffmpegFormat = @"ntsc-vcd";
		
			if (aspectValue == 1)
			{
			NSString *padSize = [self getPadSize:240 withAspectW:4 withAspectH:3 withWidth:1.85 withHeight:1 withBlackBars:YES];
			padTop = @"-padtop";
			padBottom = @"-padbottom";
			padTopSize = padSize;		
			padBottomSize = padSize;
			}
			else if (aspectValue == 2)
			{
			NSString *padSize = [self getPadSize:240 withAspectW:4 withAspectH:3 withWidth:16 withHeight:9 withBlackBars:YES];
			padTop = @"-padtop";
			padBottom = @"-padbottom";
			padTopSize = padSize;		
			padBottomSize = padSize;
			}
			else if (aspectValue == 3)
			{
			NSString *padSize = [self getPadSize:240 withAspectW:4 withAspectH:3 withWidth:2.35 withHeight:1 withBlackBars:YES];
			padTop = @"-padtop";
			padBottom = @"-padbottom";
			padTopSize = padSize;		
			padBottomSize = padSize;
			}
			else if (aspectValue == 4)
			{
			NSString *padSize = [self getPadSize:240 withAspectW:4 withAspectH:3 withWidth:2.20 withHeight:1 withBlackBars:YES];
			padTop = @"-padtop";
			padBottom = @"-padbottom";
			padTopSize = padSize;		
			padBottomSize = padSize;
			}
			else if (aspectValue == 5)
			{
			aspect = @"4:3";
			}
			else if (aspectValue == 6)
			{
			NSString *padSize = [self getPadSize:240 withAspectW:4 withAspectH:3 withWidth:[inputWidth floatValue] withHeight:[inputHeight floatValue] withBlackBars:YES];
			padTop = @"-padtop";
			padBottom = @"-padbottom";
			padTopSize = padSize;		
			padBottomSize = padSize;
			}
			else if (aspectValue == 7)
			{
			NSString *padSize = [self getPadSize:240 withAspectW:4 withAspectH:3 withWidth:[inputWidth floatValue] withHeight:[inputHeight floatValue] withBlackBars:YES];
			padTop = @"-padtop";
			padBottom = @"-padbottom";
			padTopSize = padSize;		
			padBottomSize = padSize;
			}
			else if (aspectValue == 8)
			{
			NSString *padSize = [self getPadSize:352 withAspectW:4 withAspectH:3 withWidth:[inputWidth floatValue] withHeight:[inputHeight floatValue] withBlackBars:NO];
			padTop = @"-padleft";
			padBottom = @"-padright";
			padTopSize = padSize;		
			padBottomSize = padSize;
			}
		}
	}
	//SVCD
	else if (format == 2)
	{
		//PAL
		if (region == 1)
		{
		aspect = @"4:3";
		ffmpegFormat = @"pal-svcd";
		
			if (aspectValue == 1)
			{
			NSString *padSize = [self getPadSize:576 withAspectW:4 withAspectH:3 withWidth:1.85 withHeight:1 withBlackBars:YES];
			padTop = @"-padtop";
			padBottom = @"-padbottom";
			padTopSize = padSize;		
			padBottomSize = padSize;
			}
			else if (aspectValue == 2)
			{
			NSString *padSize = [self getPadSize:576 withAspectW:4 withAspectH:3 withWidth:16 withHeight:9 withBlackBars:YES];
			padTop = @"-padtop";
			padBottom = @"-padbottom";
			padTopSize = padSize;		
			padBottomSize = padSize;
			}
			else if (aspectValue == 3)
			{
			NSString *padSize = [self getPadSize:576 withAspectW:4 withAspectH:3 withWidth:2.35 withHeight:1 withBlackBars:YES];
			padTop = @"-padtop";
			padBottom = @"-padbottom";
			padTopSize = padSize;		
			padBottomSize = padSize;
			}
			else if (aspectValue == 4)
			{
			NSString *padSize = [self getPadSize:576 withAspectW:4 withAspectH:3 withWidth:2.20 withHeight:1 withBlackBars:YES];
			padTop = @"-padtop";
			padBottom = @"-padbottom";
			padTopSize = padSize;		
			padBottomSize = padSize;
			}
			else if (aspectValue == 5)
			{
			aspect = @"4:3";
			}
			else if (aspectValue == 6)
			{
			NSString *padSize = [self getPadSize:576 withAspectW:4 withAspectH:3 withWidth:[inputWidth floatValue] withHeight:[inputHeight floatValue] withBlackBars:YES];
			padTop = @"-padtop";
			padBottom = @"-padbottom";
			padTopSize = padSize;		
			padBottomSize = padSize;
			}
			else if (aspectValue == 7)
			{
			NSString *padSize = [self getPadSize:576 withAspectW:4 withAspectH:3 withWidth:[inputWidth floatValue] withHeight:[inputHeight floatValue] withBlackBars:YES];
			padTop = @"-padtop";
			padBottom = @"-padbottom";
			padTopSize = padSize;		
			padBottomSize = padSize;
			}
			else if (aspectValue == 8)
			{
			NSString *padSize = [self getPadSize:480 withAspectW:4 withAspectH:3 withWidth:[inputWidth floatValue] withHeight:[inputHeight floatValue] withBlackBars:NO];
			padTop = @"-padleft";
			padBottom = @"-padright";
			padTopSize = padSize;		
			padBottomSize = padSize;
			}
		}
		//NTSC
		else if (region == 2)
		{
		aspect = @"4:3";
		ffmpegFormat = @"ntsc-svcd";
			
			if (aspectValue == 1)
			{
			NSString *padSize = [self getPadSize:480 withAspectW:4 withAspectH:3 withWidth:1.85 withHeight:1 withBlackBars:YES];
			padTop = @"-padtop";
			padBottom = @"-padbottom";
			padTopSize = padSize;		
			padBottomSize = padSize;
			}
			else if (aspectValue == 2)
			{
			NSString *padSize = [self getPadSize:480 withAspectW:4 withAspectH:3 withWidth:16 withHeight:9 withBlackBars:YES];
			padTop = @"-padtop";
			padBottom = @"-padbottom";
			padTopSize = padSize;		
			padBottomSize = padSize;
			}
			else if (aspectValue == 3)
			{
			NSString *padSize = [self getPadSize:480 withAspectW:4 withAspectH:3 withWidth:2.35 withHeight:1 withBlackBars:YES];
			padTop = @"-padtop";
			padBottom = @"-padbottom";
			padTopSize = padSize;		
			padBottomSize = padSize;
			}
			else if (aspectValue == 4)
			{
			NSString *padSize = [self getPadSize:480 withAspectW:4 withAspectH:3 withWidth:2.20 withHeight:1 withBlackBars:YES];
			padTop = @"-padtop";
			padBottom = @"-padbottom";
			padTopSize = padSize;		
			padBottomSize = padSize;
			}
			else if (aspectValue == 5)
			{
			aspect = @"4:3";
			}
			else if (aspectValue == 6)
			{
			NSString *padSize = [self getPadSize:480 withAspectW:4 withAspectH:3 withWidth:[inputWidth floatValue] withHeight:[inputHeight floatValue] withBlackBars:YES];
			padTop = @"-padtop";
			padBottom = @"-padbottom";
			padTopSize = padSize;		
			padBottomSize = padSize;
			}
			else if (aspectValue == 7)
			{
			NSString *padSize = [self getPadSize:480 withAspectW:4 withAspectH:3 withWidth:[inputWidth floatValue] withHeight:[inputHeight floatValue] withBlackBars:YES];
			padTop = @"-padtop";
			padBottom = @"-padbottom";
			padTopSize = padSize;		
			padBottomSize = padSize;
			}
			else if (aspectValue == 8)
			{
			NSString *padSize = [self getPadSize:480 withAspectW:4 withAspectH:3 withWidth:[inputWidth floatValue] withHeight:[inputHeight floatValue] withBlackBars:NO];
			padTop = @"-padleft";
			padBottom = @"-padright";
			padTopSize = padSize;		
			padBottomSize = padSize;
			}
		}
	}
	//DVD
	else if (format == 3)
	{
		//PAL
		if (region == 1)
		{
		ffmpegFormat = @"pal-dvd";
		
			if (aspectValue == 1)
			{
				NSString *padSize;
				if (![[NSUserDefaults standardUserDefaults] boolForKey:@"KWDVDForce43"])
				{
				padSize = [self getPadSize:576 withAspectW:16 withAspectH:9 withWidth:1.85 withHeight:1 withBlackBars:YES];
				aspect = @"16:9";
				}
				else
				{
				padSize = [self getPadSize:576 withAspectW:4 withAspectH:3 withWidth:1.85 withHeight:1 withBlackBars:YES];
				aspect = @"4:3";
				}
			
			padTop = @"-padtop";
			padBottom = @"-padbottom";
			padTopSize = padSize;		
			padBottomSize = padSize;
			}
			else if (aspectValue == 2)
			{
				NSString *padSize;
				if (![[NSUserDefaults standardUserDefaults] boolForKey:@"KWDVDForce43"])
				{
				aspect = @"16:9";
				}
				else
				{
				padSize = [self getPadSize:576 withAspectW:4 withAspectH:3 withWidth:16 withHeight:9 withBlackBars:YES];
				aspect = @"4:3";
				
				padTop = @"-padtop";
				padBottom = @"-padbottom";
				padTopSize = padSize;		
				padBottomSize = padSize;
				}
			}
			else if (aspectValue == 3)
			{
				NSString *padSize;
				if (![[NSUserDefaults standardUserDefaults] boolForKey:@"KWDVDForce43"])
				{
				padSize = [self getPadSize:576 withAspectW:16 withAspectH:9 withWidth:2.35 withHeight:1 withBlackBars:YES];
				aspect = @"16:9";
				}
				else
				{
				padSize = [self getPadSize:576 withAspectW:4 withAspectH:3 withWidth:2.35 withHeight:1 withBlackBars:YES];
				aspect = @"4:3";
				}
			
			padTop = @"-padtop";
			padBottom = @"-padbottom";
			padTopSize = padSize;		
			padBottomSize = padSize;
			}
			else if (aspectValue == 4)
			{
				NSString *padSize;
				if (![[NSUserDefaults standardUserDefaults] boolForKey:@"KWDVDForce43"])
				{
				padSize = [self getPadSize:576 withAspectW:16 withAspectH:9 withWidth:2.20 withHeight:1 withBlackBars:YES];
				aspect = @"16:9";
				}
				else
				{
				padSize = [self getPadSize:576 withAspectW:4 withAspectH:3 withWidth:2.20 withHeight:1 withBlackBars:YES];
				aspect = @"4:3";
				}
			
			padTop = @"-padtop";
			padBottom = @"-padbottom";
			padTopSize = padSize;		
			padBottomSize = padSize;
			}
			else if (aspectValue == 5)
			{
			aspect = @"4:3";
			}
			else if (aspectValue == 6)
			{
				NSString *padSize;
				if (![[NSUserDefaults standardUserDefaults] boolForKey:@"KWDVDForce43"])
				{
				padSize = [self getPadSize:576 withAspectW:16 withAspectH:9 withWidth:[inputWidth floatValue] withHeight:[inputHeight floatValue] withBlackBars:YES];
				aspect = @"16:9";
				}
				else
				{
				padSize = [self getPadSize:576 withAspectW:4 withAspectH:3 withWidth:[inputWidth floatValue] withHeight:[inputHeight floatValue] withBlackBars:YES];
				aspect = @"4:3";
				}
			
			padTop = @"-padtop";
			padBottom = @"-padbottom";
			padTopSize = padSize;		
			padBottomSize = padSize;
			}
			else if (aspectValue == 7)
			{
				NSString *padSize;
				if (![[NSUserDefaults standardUserDefaults] boolForKey:@"KWDVDForce43"])
				{
				padSize = [self getPadSize:720 withAspectW:16 withAspectH:9 withWidth:[inputWidth floatValue] withHeight:[inputHeight floatValue] withBlackBars:NO];
				aspect = @"16:9";
				}
				else
				{
				padSize = [self getPadSize:720 withAspectW:4 withAspectH:3 withWidth:[inputWidth floatValue] withHeight:[inputHeight floatValue] withBlackBars:NO];
				aspect = @"4:3";
				}
			
			padTop = @"-padleft";
			padBottom = @"-padright";
			padTopSize = padSize;		
			padBottomSize = padSize;
			}
			else if (aspectValue == 8)
			{
			NSString *padSize = [self getPadSize:720 withAspectW:4 withAspectH:3 withWidth:[inputWidth floatValue] withHeight:[inputHeight floatValue] withBlackBars:NO];
			aspect = @"4:3";
			
			padTop = @"-padleft";
			padBottom = @"-padright";
			padTopSize = padSize;		
			padBottomSize = padSize;
			}
		}
		//NTSC
		else if (region == 2)
		{
		ffmpegFormat = @"ntsc-dvd";
		
			if (aspectValue == 1)
			{
				NSString *padSize;
				if (![[NSUserDefaults standardUserDefaults] boolForKey:@"KWDVDForce43"])
				{
				padSize = [self getPadSize:480 withAspectW:16 withAspectH:9 withWidth:1.85 withHeight:1 withBlackBars:YES];
				aspect = @"16:9";
				}
				else
				{
				padSize = [self getPadSize:480 withAspectW:4 withAspectH:3 withWidth:1.85 withHeight:1 withBlackBars:YES];
				aspect = @"4:3";
				}
			
			padTop = @"-padtop";
			padBottom = @"-padbottom";
			padTopSize = padSize;		
			padBottomSize = padSize;
			}
			else if (aspectValue == 2)
			{
				NSString *padSize;
				if (![[NSUserDefaults standardUserDefaults] boolForKey:@"KWDVDForce43"])
				{
				aspect = @"16:9";
				}
				else
				{
				padSize = [self getPadSize:480 withAspectW:4 withAspectH:3 withWidth:16 withHeight:9 withBlackBars:YES];
				aspect = @"4:3";
				
				padTop = @"-padtop";
				padBottom = @"-padbottom";
				padTopSize = padSize;		
				padBottomSize = padSize;
				}
			}
			else if (aspectValue == 3)
			{
				NSString *padSize;
				if (![[NSUserDefaults standardUserDefaults] boolForKey:@"KWDVDForce43"])
				{
				padSize = [self getPadSize:480 withAspectW:16 withAspectH:9 withWidth:2.35 withHeight:1 withBlackBars:YES];
				aspect = @"16:9";
				}
				else
				{
				padSize = [self getPadSize:480 withAspectW:4 withAspectH:3 withWidth:2.35 withHeight:1 withBlackBars:YES];
				aspect = @"4:3";
				}
			
			padTop = @"-padtop";
			padBottom = @"-padbottom";
			padTopSize = padSize;		
			padBottomSize = padSize;
			}
			else if (aspectValue == 4)
			{
				NSString *padSize;
				if (![[NSUserDefaults standardUserDefaults] boolForKey:@"KWDVDForce43"])
				{
				padSize = [self getPadSize:480 withAspectW:16 withAspectH:9 withWidth:2.20 withHeight:1 withBlackBars:YES];
				aspect = @"16:9";
				}
				else
				{
				padSize = [self getPadSize:480 withAspectW:4 withAspectH:3 withWidth:2.20 withHeight:1 withBlackBars:YES];
				aspect = @"4:3";
				}
			
			padTop = @"-padtop";
			padBottom = @"-padbottom";
			padTopSize = padSize;		
			padBottomSize = padSize;
			}
			else if (aspectValue == 5)
			{
			aspect = @"4:3";
			}
			else if (aspectValue == 6)
			{
				NSString *padSize;
				if (![[NSUserDefaults standardUserDefaults] boolForKey:@"KWDVDForce43"])
				{
				padSize = [self getPadSize:480 withAspectW:16 withAspectH:9 withWidth:[inputWidth floatValue] withHeight:[inputHeight floatValue] withBlackBars:YES];
				aspect = @"16:9";
				}
				else
				{
				padSize = [self getPadSize:480 withAspectW:4 withAspectH:3 withWidth:[inputWidth floatValue] withHeight:[inputHeight floatValue] withBlackBars:YES];
				aspect = @"4:3";
				}
			
			padTop = @"-padtop";
			padBottom = @"-padbottom";
			padTopSize = padSize;		
			padBottomSize = padSize;
			}
			else if (aspectValue == 7)
			{
				NSString *padSize;
				if (![[NSUserDefaults standardUserDefaults] boolForKey:@"KWDVDForce43"])
				{
				padSize = [self getPadSize:720 withAspectW:16 withAspectH:9 withWidth:[inputWidth floatValue] withHeight:[inputHeight floatValue] withBlackBars:NO];
				aspect = @"16:9";
				}
				else
				{
				padSize = [self getPadSize:720 withAspectW:4 withAspectH:3 withWidth:[inputWidth floatValue] withHeight:[inputHeight floatValue] withBlackBars:NO];
				aspect = @"4:3";
				}
			
			padTop = @"-padleft";
			padBottom = @"-padright";
			padTopSize = padSize;		
			padBottomSize = padSize;
			}
			else if (aspectValue == 8)
			{
			NSString *padSize = [self getPadSize:720 withAspectW:4 withAspectH:3 withWidth:[inputWidth floatValue] withHeight:[inputHeight floatValue] withBlackBars:NO];
			aspect = @"4:3";
			
			padTop = @"-padleft";
			padBottom = @"-padright";
			padTopSize = padSize;		
			padBottomSize = padSize;
			}
		}	
	}

ffmpeg = [[NSTask alloc] init];
NSPipe *pipe2;
NSPipe *errorPipe;

	//Check if we need to use movtoy4m to decode
	if (mov == YES)
	{
	movtoy4m = [[NSTask alloc] init];
	pipe2 = [[NSPipe alloc] init];
	NSFileHandle *handle2;
	[movtoy4m setLaunchPath:[[NSBundle mainBundle] pathForResource:@"movtoy4m" ofType:@""]];
		if (format == 4)
		[movtoy4m setArguments:[NSArray arrayWithObjects:@"-w",inputWidth,@"-h",inputHeight,@"-F",[inputFps stringByAppendingString:@":1"],@"-a",[[inputWidth stringByAppendingString:@":"] stringByAppendingString:inputHeight],path, nil]];
		else
		[movtoy4m setArguments:[NSArray arrayWithObjects:@"-w",inputWidth,@"-h",inputHeight,@"-F",[inputFps stringByAppendingString:@":1"],@"-a",[[inputWidth stringByAppendingString:@":"] stringByAppendingString:inputHeight],path, nil]];
		
	[movtoy4m setStandardOutput:pipe2];
		if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWDebug"] == NO)
		{
		errorPipe = [[NSPipe alloc] init];
		[movtoy4m setStandardError:errorPipe];
		}
	[ffmpeg setStandardInput:pipe2];
	handle2=[pipe2 fileHandleForReading];
	[movtoy4m launch];
	}

NSPipe *pipe=[[NSPipe alloc] init];
NSFileHandle *handle;
NSData *data;
	
[ffmpeg setLaunchPath:[KWCommonMethods ffmpegPath]];


	//check again if ffmpeg should use movtoy4m as input
	if (mov == NO)
	{
		//Check if we use a wave file or not
		if (wav == NO)
		{
			//Check if we need to make a DIVX
			if (format == 4 | format == 3)
			{
				if (format == 4)
				{
				NSMutableArray *args = [[NSMutableArray alloc] init];
				args = [[NSArray arrayWithObjects:@"-threads",[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWEncodingThreads"] intValue]] stringValue],@"-i",path,@"-vtag",@"DIVX",@"-acodec",nil] mutableCopy];
				
					if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultDivXSoundType"] intValue] == 0)
					{
					[args addObject:@"libmp3lame"];
					[args addObject:@"-ac"];
					[args addObject:@"2"];
					}
					else
					{
					[args addObject:@"ac3"];
					}
				
				
					
					if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWCustomDivXVideoBitrate"])
					{
					[args addObject:@"-b"];
					[args addObject:[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultDivXVideoBitrate"] intValue]*1000] stringValue]];
					}
					
					if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWCustomDivXSoundBitrate"])
					{
					[args addObject:@"-ab"];
					[args addObject:[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultDivxSoundBitrate"] intValue]*1000] stringValue]];
					}
					
					if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWCustomDivXSize"])
					{
					[args addObject:@"-s"];
					[args addObject:[[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultDivXWidth"] stringByAppendingString:@"x"] stringByAppendingString:[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultDivXHeight"]]];
					}
					else if ([inputFormat isEqualTo:@"DV"] && aspectValue == 2)
					{
						if (region == 1)
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
					else if ([inputFormat isEqualTo:@"MPEG2"] && aspectValue == 2)
					{
						if (region == 1)
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
					
					if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWCustomFPS"])
					{
					[args addObject:@"-r"];
					[args addObject:[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultFPS"]];
					}
				
				[args addObject:[outputFile stringByAppendingString:@".avi"]];
				[ffmpeg setArguments:[args copy]];
				
				[args release];
				}
				else if (format == 3)
				{
				NSMutableArray *args = [[NSArray arrayWithObjects:@"-threads",[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWEncodingThreads"] intValue]] stringValue],@"-i",path,@"-target",ffmpegFormat,@"-ac",@"2",@"-aspect",aspect,@"-acodec",nil] mutableCopy];
				
					if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultDVDSoundType"] intValue] == 0)
					[args addObject:@"mp2"];
					else
					[args addObject:@"ac3"];
					
					if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWCustomDVDVideoBitrate"])
					{
					[args addObject:@"-b"];
					[args addObject:[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultDVDVideoBitrate"] intValue]*1000] stringValue]];
					}
					
					if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWCustomDVDSoundBitrate"])
					{
					[args addObject:@"-ab"];
					[args addObject:[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultDVDSoundBitrate"] intValue]*1000] stringValue]];
					}
					else if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"Default DVD audio format"] intValue] == 0)
					{
					[args addObject:@"-ab"];
					[args addObject:@"224000"];
					}
				
				[args addObject:[outputFile stringByAppendingString:@".mpg"]];
				
					//Check if there is padding needed
					if (![padTop isEqualTo:@""])
					{
					[args addObject:padTop];
					[args addObject:padTopSize];
					[args addObject:padBottom];
					[args addObject:padBottomSize];
					}
					
				[ffmpeg setArguments:[args copy]];
				
				[args release];
				}
			}
			else if (format == 5)
			{
			[ffmpeg setArguments:[NSArray arrayWithObjects:@"-threads",[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWEncodingThreads"] intValue]] stringValue],@"-i",path,@"-ab",[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultMP3Bitrate"] intValue]*1000] stringValue],@"-ac",[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultMP3Mode"] intValue] + 1] stringValue],@"-ar",@"44100",[outputFile stringByAppendingString:@".mp3"],nil]];
			}
			else if (format == 6)
			{
			[ffmpeg setArguments:[NSArray arrayWithObjects:@"-threads",[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWEncodingThreads"] intValue]] stringValue],@"-i",path,[outputFile stringByAppendingString:@".wav"],nil]];
			}
			else
			{
				//Check if there is padding needed
				if (![padTop isEqualTo:@""])
				[ffmpeg setArguments:[NSArray arrayWithObjects:@"-threads",[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWEncodingThreads"] intValue]] stringValue],@"-i",path,@"-target",ffmpegFormat,@"-ac",@"2",@"-aspect",aspect,[outputFile stringByAppendingString:@".mpg"],padTop, padTopSize, padBottom, padBottomSize,nil]];
				else
				[ffmpeg setArguments:[NSArray arrayWithObjects:@"-threads",[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWEncodingThreads"] intValue]] stringValue],@"-i",path,@"-target",ffmpegFormat,@"-ac",@"2",@"-aspect",aspect,[outputFile stringByAppendingString:@".mpg"],nil]];
			}
		}
		else
		{
			//Check if we need to make a DIVX (Since were not changing settings here
			if (format == 4 | format == 3)
			{
				if (format == 4)
				{
				NSMutableArray *args = [[NSMutableArray alloc] init];
				args = [[NSArray arrayWithObjects:@"-threads",[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWEncodingThreads"] intValue]] stringValue],@"-i",[outputFile stringByAppendingString:@".wav"],@"-threads",[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWEncodingThreads"] intValue]] stringValue],@"-i",path,@"-vtag",@"DIVX",@"-acodec",nil] mutableCopy];
					
					if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultDivXSoundType"] intValue] == 0)
					{
					[args addObject:@"libmp3lame"];
					[args addObject:@"-ac"];
					[args addObject:@"2"];
					}
					else
					{
					[args addObject:@"ac3"];
					}
				
					if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWCustomDivXVideoBitrate"])
					{
					[args addObject:@"-b"];
					[args addObject:[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultDivXVideoBitrate"] intValue]*1000] stringValue]];
					}
					
					if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWCustomDivXSoundBitrate"])
					{
					[args addObject:@"-ab"];
					[args addObject:[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultDivxSoundBitrate"] intValue]*1000] stringValue]];
					}
					
					if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWCustomDivXSize"])
					{
					[args addObject:@"-s"];
					[args addObject:[[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultDivXWidth"] stringByAppendingString:@"x"] stringByAppendingString:[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultDivXHeight"]]];
					}
					else if ([inputFormat isEqualTo:@"DV"] && aspectValue == 2)
					{
						if (region == 1)
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
					else if ([inputFormat isEqualTo:@"MPEG2"] && aspectValue == 2)
					{
						if (region == 1)
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
					
					if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWCustomFPS"])
					{
					[args addObject:@"-r"];
					[args addObject:[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultFPS"]];
					}
				
				[args addObject:[outputFile stringByAppendingString:@".avi"]];
				[ffmpeg setArguments:[args copy]];
				
				[args release];
				}
				else if (format == 3)
				{
				NSMutableArray *args = [[NSMutableArray alloc] init];
				args = [[NSArray arrayWithObjects:@"-threads",[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWEncodingThreads"] intValue]] stringValue],@"-i",[outputFile stringByAppendingString:@".wav"],@"-threads",[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWEncodingThreads"] intValue]] stringValue],@"-i",path,@"-target",ffmpegFormat,@"-ac",@"2",@"-aspect",aspect,@"-acodec",nil] mutableCopy];
					
					if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultDVDSoundType"] intValue] == 0)
					[args addObject:@"mp2"];
					else
					[args addObject:@"ac3"];
				
					if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWCustomDVDVideoBitrate"])
					{
					[args addObject:@"-b"];
					[args addObject:[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultDVDVideoBitrate"] intValue]*1000] stringValue]];
					}
					
					if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWCustomDVDSoundBitrate"])
					{
					[args addObject:@"-ab"];
					[args addObject:[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultDVDSoundBitrate"] intValue]*1000] stringValue]];
					}
					else if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"Default DVD audio format"] intValue] == 0)
					{
					[args addObject:@"-ab"];
					[args addObject:@"224000"];
					}
				
				[args addObject:[outputFile stringByAppendingString:@".mpg"]];
				
					//Check if there is padding needed
					if (![padTop isEqualTo:@""])
					{
					[args addObject:padTop];
					[args addObject:padTopSize];
					[args addObject:padBottom];
					[args addObject:padBottomSize];
					}
					
				[ffmpeg setArguments:[args copy]];
				
				[args release];
				}
			}
			else if (format == 5)
			{
			[ffmpeg setArguments:[NSArray arrayWithObjects:@"-threads",[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWEncodingThreads"] intValue]] stringValue],@"-i",[outputFile stringByAppendingString:@".wav"],@"-ab",[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultMP3Bitrate"] intValue]*1000] stringValue],@"-ac",[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultMP3Mode"] intValue] + 1] stringValue],@"-ar",@"44100",[outputFile stringByAppendingString:@".mp3"],nil]];
			}
			else
			{
				//Check if there is padding needed
				if (![padTop isEqualTo:@""])
				[ffmpeg setArguments:[NSArray arrayWithObjects:@"-threads",[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWEncodingThreads"] intValue]] stringValue],@"-i",[outputFile stringByAppendingString:@".wav"],@"-threads",[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWEncodingThreads"] intValue]] stringValue],@"-i",path,@"-target",ffmpegFormat,@"-ac",@"2",@"-aspect",aspect,[outputFile stringByAppendingString:@".mpg"],padTop, padTopSize, padBottom, padBottomSize,nil]];
				else
				[ffmpeg setArguments:[NSArray arrayWithObjects:@"-threads",[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWEncodingThreads"] intValue]] stringValue],@"-i",[outputFile stringByAppendingString:@".wav"],@"-threads",[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWEncodingThreads"] intValue]] stringValue],@"-i",path,@"-target",ffmpegFormat,@"-ac",@"2",@"-aspect",aspect,[outputFile stringByAppendingString:@".mpg"],nil]];			
			}
		}
	}
	else
	{
		//Check if we need to make a DIVX (Since were not changing settings here
		if (format == 4 | format == 3)
		{
			//Check if we use a wave file or not
			if (wav == NO)
			{
				if (format == 4)
				{
				NSMutableArray *args = [[NSMutableArray alloc] init];
				args = [[NSArray arrayWithObjects:@"-f", @"yuv4mpegpipe",@"-threads",[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWEncodingThreads"] intValue]] stringValue],@"-i",@"-",@"-threads",[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWEncodingThreads"] intValue]] stringValue],@"-i",path,@"-vtag",@"DIVX",@"-acodec",nil] mutableCopy];
					
					if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultDivXSoundType"] intValue] == 0)
					{
					[args addObject:@"libmp3lame"];
					[args addObject:@"-ac"];
					[args addObject:@"2"];
					}
					else
					{
					[args addObject:@"ac3"];
					}
				
					if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWCustomDivXVideoBitrate"])
					{
					[args addObject:@"-b"];
					[args addObject:[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultDivXVideoBitrate"] intValue]*1000] stringValue]];
					}
					
					if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWCustomDivXSoundBitrate"])
					{
					[args addObject:@"-ab"];
					[args addObject:[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultDivxSoundBitrate"] intValue]*1000] stringValue]];
					}
					
					if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWCustomDivXSize"])
					{
					[args addObject:@"-s"];
					[args addObject:[[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultDivXWidth"] stringByAppendingString:@"x"] stringByAppendingString:[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultDivXHeight"]]];
					}
					else if ([inputFormat isEqualTo:@"DV"] && aspectValue == 2)
					{
						if (region == 1)
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
					else if ([inputFormat isEqualTo:@"MPEG2"] && aspectValue == 2)
					{
						if (region == 1)
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
					
					if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWCustomFPS"])
					{
					[args addObject:@"-r"];
					[args addObject:[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultFPS"]];
					}
				
				[args addObject:[outputFile stringByAppendingString:@".avi"]];
				[ffmpeg setArguments:[args copy]];
				
				[args release];
				}
				else if (format == 3)
				{
				NSMutableArray *args = [[NSMutableArray alloc] init];
				args = [[NSArray arrayWithObjects:@"-f", @"yuv4mpegpipe",@"-threads",[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWEncodingThreads"] intValue]] stringValue],@"-i",@"-",@"-threads",[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWEncodingThreads"] intValue]] stringValue],@"-i",path,@"-target",ffmpegFormat,@"-ac",@"2",@"-aspect",aspect,@"-acodec",nil] mutableCopy];
					
					if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultDVDSoundType"] intValue] == 0)
					[args addObject:@"mp2"];
					else
					[args addObject:@"ac3"];
				
					if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWCustomDVDVideoBitrate"])
					{
					[args addObject:@"-b"];
					[args addObject:[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultDVDVideoBitrate"] intValue]*1000] stringValue]];
					}
					
					if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWCustomDVDSoundBitrate"])
					{
					[args addObject:@"-ab"];
					[args addObject:[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultDVDSoundBitrate"] intValue]*1000] stringValue]];
					}
					else if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"Default DVD audio format"] intValue] == 0)
					{
					[args addObject:@"-ab"];
					[args addObject:@"224000"];
					}
				
				[args addObject:[outputFile stringByAppendingString:@".mpg"]];
				
					//Check if there is padding needed
					if (![padTop isEqualTo:@""])
					{
					[args addObject:padTop];
					[args addObject:padTopSize];
					[args addObject:padBottom];
					[args addObject:padBottomSize];
					}
				
				[ffmpeg setArguments:[args copy]];
				
				[args release];
				}
			}
			else
			{
			//This is a problem with earlier versions of ffmpeg
			//[ffmpeg setArguments:[NSArray arrayWithObjects:@"-f", @"yuv4mpegpipe",@"-threads",[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWEncodingThreads"] intValue]] stringValue],@"-i",@"-",@"-threads",[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWEncodingThreads"] intValue]] stringValue],@"-i",[outputFile stringByAppendingString:@".wav"],@"-acodec",@"mp3",@"-vtag",@"DIVX",[outputFile stringByAppendingString:@".avi"],nil]];
			[ffmpeg setArguments:[NSArray arrayWithObjects:@"-f", @"yuv4mpegpipe",@"-threads",[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWEncodingThreads"] intValue]] stringValue],@"-i",@"-",@"-threads",[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWEncodingThreads"] intValue]] stringValue],@"-i",[outputFile stringByAppendingString:@".wav"],@"-acodec",@"libmp3lame",@"-vtag",@"DIVX",[outputFile stringByAppendingString:@".avi"],nil]];	
				if (format == 4)
				{
				NSMutableArray *args = [[NSMutableArray alloc] init];
				args = [[NSArray arrayWithObjects:@"-f", @"yuv4mpegpipe",@"-threads",[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWEncodingThreads"] intValue]] stringValue],@"-i",@"-",@"-threads",[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWEncodingThreads"] intValue]] stringValue],@"-i",[outputFile stringByAppendingString:@".wav"],@"-vtag",@"DIVX",@"-acodec",nil] mutableCopy];
					
					if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultDivXSoundType"] intValue] == 0)
					{
					[args addObject:@"libmp3lame"];
					[args addObject:@"-ac"];
					[args addObject:@"2"];
					}
					else
					{
					[args addObject:@"ac3"];
					}
				
					if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWCustomDivXVideoBitrate"])
					{
					[args addObject:@"-b"];
					[args addObject:[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultDivXVideoBitrate"] intValue]*1000] stringValue]];
					}
					
					if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWCustomDivXSoundBitrate"])
					{
					[args addObject:@"-ab"];
					[args addObject:[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultDivxSoundBitrate"] intValue]*1000] stringValue]];
					}
					
					if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWCustomDivXSize"])
					{
					[args addObject:@"-s"];
					[args addObject:[[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultDivXWidth"] stringByAppendingString:@"x"] stringByAppendingString:[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultDivXHeight"]]];
					}
					else if ([inputFormat isEqualTo:@"DV"] && aspectValue == 2)
					{
						if (region == 1)
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
					else if ([inputFormat isEqualTo:@"MPEG2"] && aspectValue == 2)
					{
						if (region == 1)
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
					
					if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWCustomFPS"])
					{
					[args addObject:@"-r"];
					[args addObject:[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultFPS"]];
					}
				
				[args addObject:[outputFile stringByAppendingString:@".avi"]];
				[ffmpeg setArguments:[args copy]];
				
				[args release];
				}
				else if (format == 3)
				{
				NSMutableArray *args = [[NSMutableArray alloc] init];
				args = [[NSArray arrayWithObjects:@"-f", @"yuv4mpegpipe",@"-threads",[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWEncodingThreads"] intValue]] stringValue],@"-i",@"-",@"-threads",[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWEncodingThreads"] intValue]] stringValue],@"-i",[outputFile stringByAppendingString:@".wav"],@"-target",ffmpegFormat,@"-ac",@"2",@"-aspect",aspect,@"-acodec",nil] mutableCopy];
					
					if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultDVDSoundType"] intValue] == 0)
					[args addObject:@"mp2"];
					else
					[args addObject:@"ac3"];
				
					if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWCustomDVDVideoBitrate"])
					{
					[args addObject:@"-b"];
					[args addObject:[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultDVDVideoBitrate"] intValue]*1000] stringValue]];
					}
					
					if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWCustomDVDSoundBitrate"])
					{
					[args addObject:@"-ab"];
					[args addObject:[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultDVDSoundBitrate"] intValue]*1000] stringValue]];
					}
					else if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"Default DVD audio format"] intValue] == 0)
					{
					[args addObject:@"-ab"];
					[args addObject:@"224000"];
					}
				
				[args addObject:[outputFile stringByAppendingString:@".mpg"]];
				
					//Check if there is padding needed
					if (![padTop isEqualTo:@""])
					{
					[args addObject:padTop];
					[args addObject:padTopSize];
					[args addObject:padBottom];
					[args addObject:padBottomSize];
					}
				
				[ffmpeg setArguments:[args copy]];
				
				[args release];
				}
			}
		}
		else
		{
			//Check if we need padding
			if (![padTop isEqualTo:@""])
			{
				//Check if we use a wave file or not
				if (wav == NO)
				[ffmpeg setArguments:[NSArray arrayWithObjects:@"-f", @"yuv4mpegpipe",@"-threads",[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWEncodingThreads"] intValue]] stringValue],@"-i",@"-",@"-threads",[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWEncodingThreads"] intValue]] stringValue],@"-i",path,@"-target",ffmpegFormat,@"-ac",@"2",@"-aspect",aspect,[outputFile stringByAppendingString:@".mpg"],padTop, padTopSize, padBottom, padBottomSize,nil]];
				else
				[ffmpeg setArguments:[NSArray arrayWithObjects:@"-f", @"yuv4mpegpipe",@"-threads",[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWEncodingThreads"] intValue]] stringValue],@"-i",@"-",@"-threads",[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWEncodingThreads"] intValue]] stringValue],@"-i",[outputFile stringByAppendingString:@".wav"],@"-target",ffmpegFormat,@"-ac",@"2",@"-aspect",aspect,[outputFile stringByAppendingString:@".mpg"],padTop, padTopSize, padBottom, padBottomSize,nil]];		
			}
			else
			{
				//Check if we use a wave file or not
				if (wav == NO)
				[ffmpeg setArguments:[NSArray arrayWithObjects:@"-f", @"yuv4mpegpipe",@"-threads",[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWEncodingThreads"] intValue]] stringValue],@"-i",@"-",@"-threads",[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWEncodingThreads"] intValue]] stringValue],@"-i",path,@"-target",ffmpegFormat,@"-ac",@"2",@"-aspect",aspect,[outputFile stringByAppendingString:@".mpg"],nil]];
				else
				[ffmpeg setArguments:[NSArray arrayWithObjects:@"-f", @"yuv4mpegpipe",@"-threads",[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWEncodingThreads"] intValue]] stringValue],@"-i",@"-",@"-threads",[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWEncodingThreads"] intValue]] stringValue],@"-i",[outputFile stringByAppendingString:@".wav"],@"-target",ffmpegFormat,@"-ac",@"2",@"-aspect",aspect,[outputFile stringByAppendingString:@".mpg"],nil]];
			}
		}
	}
//ffmpeg uses stderr to show the progress
[ffmpeg setStandardError:pipe];
handle=[pipe fileHandleForReading];

	if ([inputFormat isEqualTo:@"DV"] && region == 1)
	{
		if (format == 2)
		{
		//SVCD
		NSMutableArray *tempMute = [[ffmpeg arguments] mutableCopy];
		[tempMute addObject:@"-cropleft"];
		[tempMute addObject:@"22"];
		[tempMute addObject:@"-cropright"];
		[tempMute addObject:@"22"];
		[ffmpeg setArguments:[tempMute copy]];
		}
		else if (format == 3)
		{
		//DVD
		NSMutableArray *tempMute = [[ffmpeg arguments] mutableCopy];
		[tempMute addObject:@"-cropleft"];
		[tempMute addObject:@"24"];
		[tempMute addObject:@"-cropright"];
		[tempMute addObject:@"24"];
		[ffmpeg setArguments:[tempMute copy]];
		}
		
		if (![padTop isEqualTo:@""])
		{
		NSMutableArray *tempMute = [[ffmpeg arguments] mutableCopy];
		[tempMute addObject:padTop];
		[tempMute addObject:padTopSize];
		[tempMute addObject:padBottom];
		[tempMute addObject:padBottomSize];
		[ffmpeg setArguments:[tempMute copy]];
		}
	}
	
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWSaveBorders"] == YES)
	{
	NSMutableArray *tempMute = [[ffmpeg arguments] mutableCopy];
	NSNumber *borderSize = [[NSUserDefaults standardUserDefaults] objectForKey:@"KWSaveBorderSize"];
	NSString *heightBorder = [borderSize stringValue];
	NSString *widthBorder = [self convertToEven:[[NSNumber numberWithFloat:[inputWidth floatValue] / ([inputHeight floatValue] / [borderSize floatValue])] stringValue]];
	
		if ([padTop isEqualTo:@"-padtop"])
		{
		[tempMute addObject:@"-padleft"];
		[tempMute addObject:widthBorder];
		[tempMute addObject:@"-padright"];
		[tempMute addObject:widthBorder];
		}
		else
		{
		[tempMute addObject:@"-padtop"];
		[tempMute addObject:heightBorder];
		[tempMute addObject:@"-padbottom"];
		[tempMute addObject:heightBorder];
		
			if ([padTop isEqualTo:@""])
			{
			[tempMute addObject:@"-padleft"];
			[tempMute addObject:widthBorder];
			[tempMute addObject:@"-padright"];
			[tempMute addObject:widthBorder];
			}
		}
	
	[ffmpeg setArguments:[tempMute copy]];
	}
	
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWDebug"] == YES)
	{
	NSArray *showArgs = [ffmpeg arguments];
	NSString *command = @"ffmpeg";

		int i;
		for (i=0;i<[showArgs count];i++)
		{
		command = [command stringByAppendingString:@" "];
		command = [command stringByAppendingString:[showArgs objectAtIndex:i]];
		}
	
	NSLog(command);
	}
	
[ffmpeg launch];

	if (mov == YES)
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
	string=[[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
	
		if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWDebug"] == YES)
		NSLog(string);
		
		//Format the time sting ffmpeg outputs and format it to percent
		if ([string rangeOfString:@"time="].length > 0)
		{
		NSString *currentTimeString = [[[[string componentsSeparatedByString:@"time="] objectAtIndex:1] componentsSeparatedByString:@" "] objectAtIndex:0];
		double percent = [[[[[NSNumber numberWithDouble:[currentTimeString doubleValue] / [inputTotalTime doubleValue] * 100] stringValue] componentsSeparatedByString:@"."] objectAtIndex:0] doubleValue];
		
			if ([inputTotalTime doubleValue] > 0)
			{
				if (percent < 101)
				{
				[[NSNotificationCenter defaultCenter] postNotificationName:@"KWStatusByAddingPercentChanged" object:[[@" (" stringByAppendingString:[[NSNumber numberWithDouble:percent] stringValue]] stringByAppendingString:@"%)"]];
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
int taskStatus = [ffmpeg terminationStatus];

//Release ffmpeg
[ffmpeg release];
	
	//If we used a wav file, delete it
	if (wav == YES)
	[[NSFileManager defaultManager] removeFileAtPath:[outputFile stringByAppendingString:@".wav"] handler:nil];
	
	if (mov == YES)
	{	
	[movtoy4m release];
	[pipe2 release];
		if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWDebug"] == NO)
		[errorPipe release];
	}
	
[pipe release];
inputTotalTime = @"";
	
	//Return if ffmpeg failed or not
	if (taskStatus == 0)
	{
	status = 0;
	
		if (format == 4)
		encodedOutputFile = [outputFile stringByAppendingString:@".avi"];
		else if (format == 5)
		encodedOutputFile = [outputFile stringByAppendingString:@".mp3"];
		else if (format == 6)
		encodedOutputFile = [outputFile stringByAppendingString:@".wav"];
		else
		encodedOutputFile = [outputFile stringByAppendingString:@".mpg"];
	
	return 0;
	}
	else if (userCanceled == YES)
	{
	status = 0;
	
		//Delete the mpg file if ffmpeg was canceled
		if (format == 4)
		[[NSFileManager defaultManager] removeFileAtPath:[outputFile stringByAppendingString:@".avi"] handler:nil];
		else if (format == 5)
		[[NSFileManager defaultManager] removeFileAtPath:[outputFile stringByAppendingString:@".mp3"] handler:nil];
		else if (format == 6)
		[[NSFileManager defaultManager] removeFileAtPath:[outputFile stringByAppendingString:@".wav"] handler:nil];
		else
		[[NSFileManager defaultManager] removeFileAtPath:[outputFile stringByAppendingString:@".mpg"] handler:nil];
		
	return 2;
	}
	else
	{
	status = 0;
	
		//Delete the mpg file if ffmpeg failed
		if (format == 4)
		[[NSFileManager defaultManager] removeFileAtPath:[outputFile stringByAppendingString:@".avi"] handler:nil];
		else if (format == 5)
		[[NSFileManager defaultManager] removeFileAtPath:[outputFile stringByAppendingString:@".mp3"] handler:nil];
		else if (format == 6)
		[[NSFileManager defaultManager] removeFileAtPath:[outputFile stringByAppendingString:@".wav"] handler:nil];
		else
		[[NSFileManager defaultManager] removeFileAtPath:[outputFile stringByAppendingString:@".mpg"] handler:nil];
		
	[KWCommonMethods writeLogWithFilePath:path withCommand:@"ffmpeg" withLog:string];
	[string release];
		
	return 1;
	}
}

//Encode sound to wav
-(int)encodeAudio:(NSString *)path useQuickTimeToo:(BOOL)mov setOutputFolder:(NSString *)outputFolder setRegion:(int)region setFormat:(int)format
{
[[NSNotificationCenter defaultCenter] postNotificationName:@"KWStatusChanged" object:[NSLocalizedString(@"Decoding sound: ", Localized) stringByAppendingString:[[NSFileManager defaultManager] displayNameAtPath:path]]];

//Output file (without extension)
NSString *outputFile = [outputFolder stringByAppendingString:[[path lastPathComponent] stringByDeletingPathExtension]];

	if (format == 4)
	{
	outputFile = [[KWCommonMethods uniquePathNameFromPath:[outputFile stringByAppendingString:@".avi"] withLength:0] stringByDeletingPathExtension];
	}
	else if (format == 5)
	{
	outputFile = [[KWCommonMethods uniquePathNameFromPath:[outputFile stringByAppendingString:@".mp3"] withLength:0] stringByDeletingPathExtension];
	}
	else
	{
	outputFile = [[KWCommonMethods uniquePathNameFromPath:[outputFile stringByAppendingString:@".mpg"] withLength:0] stringByDeletingPathExtension];
	}

	if ([[NSFileManager defaultManager] fileExistsAtPath:[outputFile stringByAppendingString:@".wav"]])
	[[NSFileManager defaultManager] removeFileAtPath:[outputFile stringByAppendingString:@".wav"] handler:nil];
	
//movtowav encodes quicktime movie's sound to wav
movtowav = [[NSTask alloc] init];
[movtowav setLaunchPath:[[NSBundle mainBundle] pathForResource:@"movtowav" ofType:@""]];
[movtowav setArguments:[NSArray arrayWithObjects:@"-o",[outputFile stringByAppendingString:@".wav"],path,nil]];
int taskStatus;

NSPipe *pipe=[[NSPipe alloc] init];
NSFileHandle *handle=[pipe fileHandleForReading];
[movtowav setStandardError:pipe];
[movtowav launch];
NSString *string=[[NSString alloc] initWithData:[handle readDataToEndOfFile] encoding:NSASCIIStringEncoding];

	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWDebug"] == YES)
	NSLog(string);

status = 1;
[movtowav waitUntilExit];
taskStatus = [movtowav terminationStatus];
[movtowav release];
[pipe release];
	
//Check if it all went OK if not remove the wave file and return NO
    if (!taskStatus == 0)
	{
	[[NSFileManager defaultManager] removeFileAtPath:[outputFile stringByAppendingString:@".wav"] handler:nil];
	
	status = 0;
		
		if (userCanceled == YES)
		{
		[string release];
		
		return 2;
		}
		else
		{
		[KWCommonMethods writeLogWithFilePath:path withCommand:@"movtowav" withLog:string];
		[string release];

		return 1;
		}
	}
	
	[string release];

	if (format == 5)
	[self testFile:[outputFile stringByAppendingString:@".wav"] setOutputFolder:[outputFile stringByDeletingLastPathComponent] isType:5];
	
	if (format == 6)
	{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWValueChanged" object:[NSNumber numberWithDouble:((double)number + 1) * 100]];
	encodedOutputFile = [outputFile stringByAppendingString:@".wav"];
	return 0;
	}
	
	//Check if the movie needs to be decoded too, and start encoding with ffmpeg
	if (mov == YES)
	return [self encodeFile:path useWavFile:YES useQuickTime:YES setOutputFolder:outputFolder setRegion:region setFormat:format];
	else
	return [self encodeFile:path useWavFile:YES useQuickTime:NO setOutputFolder:outputFolder setRegion:region setFormat:format];	
}

//Encode the given file (return YES if it all went OK)
- (int)encodeFile:(NSString *)path setOutputFolder:(NSString *)outputFolder setRegion:(int)region setFormat:(int)format
{
int testResult = [self testFile:path setOutputFolder:outputFolder isType:format];

[[NSFileManager defaultManager] removeFileAtPath:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWTemporaryLocation"] stringByAppendingPathComponent:@"tempkf.mpg"] handler:nil];

	if (testResult == 0)
	{
	return 3;
	}
	
	//video=ffmpeg audio=ffmpeg
	if (testResult == 1)
	return [self encodeFile:path useWavFile:NO useQuickTime:NO setOutputFolder:outputFolder setRegion:region setFormat:format];
	//video=qt audio=qt
	else if (testResult == 2)
	return [self encodeAudio:path useQuickTimeToo:YES setOutputFolder:outputFolder setRegion:region setFormat:format];
	//video=qt audio=ffmpeg
	else if (testResult == 3)
	return [self encodeFile:path useWavFile:NO useQuickTime:YES setOutputFolder:outputFolder setRegion:region setFormat:format];
	//video=ffmpeg audio=qt
	else if (testResult == 4)
	return [self encodeAudio:path useQuickTimeToo:NO setOutputFolder:outputFolder setRegion:region setFormat:format];
	//video=ffmpeg
	else if (testResult == 5)
	return [self encodeFile:path useWavFile:NO useQuickTime:NO setOutputFolder:outputFolder setRegion:region setFormat:format];
	//video=qt
	else if (testResult == 6)
	return [self encodeFile:path useWavFile:NO useQuickTime:YES setOutputFolder:outputFolder setRegion:region setFormat:format];
	//audio=ffmpeg
	else if (testResult == 7)
	return [self encodeFile:path useWavFile:NO useQuickTime:NO setOutputFolder:outputFolder setRegion:region setFormat:format];
	//audio=qt
	else if (testResult == 8)
	return [self encodeAudio:path useQuickTimeToo:NO setOutputFolder:outputFolder setRegion:region setFormat:format];
	else 
	return 1;
}

//Stop encoding (stop ffmpeg, movtowav and movtoy4m if they're running
- (void)cancelEncoding
{
userCanceled = YES;
	
	if (status == 1)
	{
	[movtowav terminate];
	}
	else if (status == 2)
	{
	[ffmpeg terminate];
	}
	else if (status == 3)
	{
	[movtoy4m terminate];
	[ffmpeg terminate];
	}
}

/////////////////////
// Test actions //
/////////////////////

#pragma mark -
#pragma mark •• Test actions

//Test if ffmpeg can encode, sound and/or video, and if it does have any sound
-(int)testFile:(NSString *)path setOutputFolder:(NSString *)outputFolder isType:(int)type
{
int referenceTest = 0;
[self isReferenceMovie:path isType:type];

	if (referenceTest == 0)
	{
	BOOL audioWorks = YES;
	BOOL videoWorks = YES;
	BOOL keepGoing = YES;

		while (keepGoing == YES)
		{
		ffmpeg=[[NSTask alloc] init];
		NSPipe *pipe=[[NSPipe alloc] init];
		NSFileHandle *handle;

		[ffmpeg setLaunchPath:[KWCommonMethods ffmpegPath]];
	
			if (audioWorks == YES && videoWorks == YES)
			[ffmpeg setArguments:[NSArray arrayWithObjects:@"-t",@"0.1",@"-threads",[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWEncodingThreads"] intValue]] stringValue],@"-i",path,@"-target",@"pal-vcd",@"-ac",@"2",@"-r",@"25",@"-y",[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWTemporaryLocation"] stringByAppendingPathComponent:@"tempkf.mpg"],nil]];
			if (audioWorks == NO)
			[ffmpeg setArguments:[NSArray arrayWithObjects:@"-t",@"0.1",@"-threads",[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWEncodingThreads"] intValue]] stringValue],@"-i",path,@"-target",@"pal-vcd",@"-an",@"-ac",@"2",@"-r",@"25",@"-y",[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWTemporaryLocation"] stringByAppendingPathComponent:@"tempkf.mpg"],nil]];
			if (videoWorks == NO)
			[ffmpeg setArguments:[NSArray arrayWithObjects:@"-t",@"0.1",@"-threads",[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWEncodingThreads"] intValue]] stringValue],@"-i",path,@"-target",@"pal-vcd",@"-vn",@"-ac",@"2",@"-r",@"25",@"-y",[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWTemporaryLocation"] stringByAppendingPathComponent:@"tempkf.mpg"],nil]];
	
		[ffmpeg setStandardError:pipe];
		handle=[pipe fileHandleForReading];
		[ffmpeg launch];
		NSString *string = [[[NSString alloc] initWithData:[handle readDataToEndOfFile] encoding:NSASCIIStringEncoding] autorelease];

		[ffmpeg waitUntilExit];
		[ffmpeg release];
		[pipe release];
		
			if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWDebug"] == YES)
			NSLog(string);
		
		keepGoing = NO;	
		
			if ([string rangeOfString:@"edit list not starting at 0, a/v desync might occur, patch welcome"].length > 0)
			{
			videoWorks = NO;
			}
			
			if ([string rangeOfString:@"error reading header: -1"].length > 0 && [string rangeOfString:@"iDVD"].length > 0)
			{
				//works audio=qt video=qt
				if ([self setiMovieProjectTimeAndAspect:path])
				{
				return 2;
				}
				else
				{
				[failedFilesExplained addObject:[[[NSFileManager defaultManager] displayNameAtPath:path] stringByAppendingString:NSLocalizedString(@" (Couldn't get attributes)", Localized)]];
				return 0;
				}
			}
	
			// Check if ffmpeg reconizes the file
			if ([string rangeOfString:@"Unknown format"].length > 0)
			{
			//ffmpeg doesn't reconize it
			[failedFilesExplained addObject:[[[NSFileManager defaultManager] displayNameAtPath:path] stringByAppendingString:NSLocalizedString(@" (Unknown format)", Localized)]];
			return 0;
			}
	
			//Check if ffmpeg reconizes the codecs
			if ([string rangeOfString:@"could not find codec parameters"].length > 0)
			{
			[failedFilesExplained addObject:[[[NSFileManager defaultManager] displayNameAtPath:path] stringByAppendingString:NSLocalizedString(@" (Couldn't get attributes)", Localized)]];
			return 0;
			}
			
			//No audio
			if ([string rangeOfString:@"error: movie contains no audio tracks!"].length > 0 && type < 5)
			{
			[failedFilesExplained addObject:[[[NSFileManager defaultManager] displayNameAtPath:path] stringByAppendingString:NSLocalizedString(@" (No audio)", Localized)]];
			return 0;
			}
	
			//Check if the movie is a (internet/local)reference file
			if ([self isReferenceMovie:string])
			{
				//works audio=qt video=qt
				if ([self setTimeAndAspect:string isType:type fromFile:path])
				{
				return 2;
				}
				else
				{
				[failedFilesExplained addObject:[[[NSFileManager defaultManager] displayNameAtPath:path] stringByAppendingString:NSLocalizedString(@" (Couldn't get attributes)", Localized)]];
				return 0;
				}
			}
			
			NSString *input = [[[[string componentsSeparatedByString:@"Output #0"] objectAtIndex:0] componentsSeparatedByString:@"Input #0"] objectAtIndex:1];
			if ([input rangeOfString:@"mp2"].length > 0 && [input rangeOfString:@"mov,"].length > 0)
			{
			audioWorks = NO;
			}
		
			if ([self hasVideo:string] && [self hasAudio:string])
			{
				if ([self audioWorks:string] && [self videoWorks:string] && videoWorks == YES && audioWorks == YES)
				{
					//works audio=ffmpeg video=ffmpeg
					if ([self setTimeAndAspect:string isType:type fromFile:path])
					{
					return 1;
					}
					else
					{
					[failedFilesExplained addObject:[[[NSFileManager defaultManager] displayNameAtPath:path] stringByAppendingString:NSLocalizedString(@" (Couldn't get attributes)", Localized)]];
					return 0;
					}
				}
				else if (![self audioWorks:string])
				{
					if (videoWorks == YES && audioWorks == YES)
					keepGoing = YES;
			
				audioWorks = NO;
				}
				else if (![self videoWorks:string])
				{
					if (videoWorks == YES && audioWorks == YES)
					keepGoing = YES;
				
				videoWorks = NO;
				}
			}
			else
			{
					if (![self hasVideo:string] && ![self hasAudio:string])
					{
					[failedFilesExplained addObject:[[[NSFileManager defaultManager] displayNameAtPath:path] stringByAppendingString:NSLocalizedString(@" (No audio/video)", Localized)]];
					return 0;
					}
					else if (![self hasVideo:string] && [self hasAudio:string])
					{
						if ([self audioWorks:string])
						{
							//works audio=ffmpeg
							if ([self setTimeAndAspect:string isType:type fromFile:path])
							{
							return 7;
							}
							else
							{
							[failedFilesExplained addObject:[[[NSFileManager defaultManager] displayNameAtPath:path] stringByAppendingString:NSLocalizedString(@" (No video)", Localized)]];
							return 0;
							}
						}
						else
						{
							//works audio=qt
							if ([self setTimeAndAspect:string isType:type fromFile:path])
							{
							return 8;
							}
							else
							{
							[failedFilesExplained addObject:[[[NSFileManager defaultManager] displayNameAtPath:path] stringByAppendingString:NSLocalizedString(@" (No video)", Localized)]];
							return 0;
							}
						}
					}
					else if ([self hasVideo:string] && ![self hasAudio:string])
					{
						if ([self videoWorks:string])
						{
							//works video=ffmpeg
							if ([self setTimeAndAspect:string isType:type fromFile:path] && type < 5)
							{
							return 5;
							}
							else if (type == 4)
							{
							[failedFilesExplained addObject:[[[NSFileManager defaultManager] displayNameAtPath:path] stringByAppendingString:NSLocalizedString(@" (Couldn't get attributes)", Localized)]];
							return 0;
							}
							else
							{
							[failedFilesExplained addObject:[[[NSFileManager defaultManager] displayNameAtPath:path] stringByAppendingString:NSLocalizedString(@" (No audio)", Localized)]];
							return 0;
							}
						}
						else
						{
							//works video=qt
							if ([self setTimeAndAspect:string isType:type fromFile:path] && type < 5)
							{
							return 6;
							}
							else if (type == 4)
							{
							[failedFilesExplained addObject:[[[NSFileManager defaultManager] displayNameAtPath:path] stringByAppendingString:NSLocalizedString(@" (Couldn't get attributes)", Localized)]];
							return 0;
							}
							else
							{
							[failedFilesExplained addObject:[[[NSFileManager defaultManager] displayNameAtPath:path] stringByAppendingString:NSLocalizedString(@" (No audio)", Localized)]];
							return 0;
							}
						}
					//}
				}
			}
		
			if (keepGoing == NO)
			{
				if (videoWorks == YES && audioWorks == NO)
				{
					//works half video=ffmpeg audio=qt
					if ([[[path pathExtension] lowercaseString] isEqualTo:@"mpg"] | [[[path pathExtension] lowercaseString] isEqualTo:@"mpeg"] | [[[path pathExtension]  lowercaseString] isEqualTo:@"m2v"])
					{
					[failedFilesExplained addObject:[[[NSFileManager defaultManager] displayNameAtPath:path] stringByAppendingString:NSLocalizedString(@" (Unsupported audio)", Localized)]];
					return 0;
					}
					else
					{
						if ([self setTimeAndAspect:string isType:type fromFile:path])
						{
						return 4;
						}
						else
						{
						[failedFilesExplained addObject:[[[NSFileManager defaultManager] displayNameAtPath:path] stringByAppendingString:NSLocalizedString(@" (Couldn't get attributes)", Localized)]];
						return 0;
						}
					}
				}
				else if (videoWorks == NO && audioWorks == YES)
				{
					//works half video=qt audio=ffmpeg
					if ([self setTimeAndAspect:string isType:type fromFile:path])
					{
					return 3;
					}
					else
					{
					[failedFilesExplained addObject:[[[NSFileManager defaultManager] displayNameAtPath:path] stringByAppendingString:NSLocalizedString(@" (Couldn't get attributes)", Localized)]];
					return 0;
					}
				}
				else if (videoWorks == NO && audioWorks == NO)
				{
					//works audio=qt video=qt
					if ([self setTimeAndAspect:string isType:type fromFile:path])
					{
					return 2;
					}
					else
					{
					[failedFilesExplained addObject:[[[NSFileManager defaultManager] displayNameAtPath:path] stringByAppendingString:NSLocalizedString(@" (Couldn't get attributes)", Localized)]];
					return 0;
					}
				}
			}
		}

	[failedFilesExplained addObject:[[[NSFileManager defaultManager] displayNameAtPath:path] stringByAppendingString:NSLocalizedString(@" (Unknown error)", Localized)]];
	return 0;
	}
	else if (referenceTest = 1)
	{
	return 2;
	}
	else if (referenceTest = 2)
	{
	[failedFilesExplained addObject:[[[NSFileManager defaultManager] displayNameAtPath:path] stringByAppendingString:NSLocalizedString(@" (Unknown error)", Localized)]];
	return 0;
	}
	else
	{
	return 0;
	}
}

- (BOOL)hasVideo:(NSString *)output
{
	if ([output rangeOfString:@"Video:"].length > 0)
	return YES;
	else
	return NO;
}

- (BOOL)hasAudio:(NSString *)output
{
	if ([output rangeOfString:@"Audio:"].length > 0)
	return YES;
	else
	return NO;
}

- (BOOL)audioWorks:(NSString *)output
{
NSString *one = [[[[[[output componentsSeparatedByString:@"Output #0"] objectAtIndex:0] componentsSeparatedByString:@"Stream #0.0"] objectAtIndex:1] componentsSeparatedByString:@": "] objectAtIndex:1];
NSString *two = @"";
	
	if ([output rangeOfString:@"Stream #0.1"].length > 0)
	two = [[[[[[output componentsSeparatedByString:@"Output #0"] objectAtIndex:0] componentsSeparatedByString:@"Stream #0.1"] objectAtIndex:1] componentsSeparatedByString:@": "] objectAtIndex:1];

	//Is stream 0.0 audio or video
	if ([output rangeOfString:@"for input stream #0.0"].length > 0 | [output rangeOfString:@"Error while decoding stream #0.0"].length > 0)
	{
		if ([one isEqualTo:@"Audio"])
		{
		return NO;
		}
	}
			
	//Is stream 0.1 audio or video
	if ([output rangeOfString:@"for input stream #0.1"].length > 0| [output rangeOfString:@"Error while decoding stream #0.1"].length > 0)
	{
		if ([two isEqualTo:@"Audio"])
		{
		return NO;
		}
	}
	
return YES;
}

- (BOOL)videoWorks:(NSString *)output
{
NSString *one = [[[[[[output componentsSeparatedByString:@"Output #0"] objectAtIndex:0] componentsSeparatedByString:@"Stream #0.0"] objectAtIndex:1] componentsSeparatedByString:@": "] objectAtIndex:1];
NSString *two = @"";
	
	if ([output rangeOfString:@"Stream #0.1"].length > 0)
	two = [[[[[[output componentsSeparatedByString:@"Output #0"] objectAtIndex:0] componentsSeparatedByString:@"Stream #0.1"] objectAtIndex:1] componentsSeparatedByString:@": "] objectAtIndex:1];

	//Is stream 0.0 audio or video
	if ([output rangeOfString:@"for input stream #0.0"].length > 0 | [output rangeOfString:@"Error while decoding stream #0.0"].length > 0)
	{
		if ([one isEqualTo:@"Video"])
		{
		return NO;
		}
	}
			
	//Is stream 0.1 audio or video
	if ([output rangeOfString:@"for input stream #0.1"].length > 0| [output rangeOfString:@"Error while decoding stream #0.1"].length > 0)
	{
		if ([two isEqualTo:@"Video"])
		{
		return NO;
		}
	}
	
return YES;
}

- (BOOL)isReferenceMovie:(NSString *)output
{
	//Found in reference quicktime movies
	if ([output rangeOfString:@"unsupported slice header"].length > 0)
	{
	return YES;
	}
	
	//Found in streaming quicktime movies
	//if ([output rangeOfString:@"bitrate: 0 kb/s"].length > 0)
	//{
	//return YES;
	//}
			
	//Found in streaming quicktime movies
	if ([output rangeOfString:@"bitrate: 5 kb/s"].length > 0)
	{
	return YES;
	}
return NO;
}

//When a iMovie reference movie doesn't work, we fall back on this method
- (BOOL)setiMovieProjectTimeAndAspect:(NSString *)file
{
NSString *projectName = [[[[[file stringByDeletingLastPathComponent] stringByDeletingLastPathComponent] stringByDeletingLastPathComponent] lastPathComponent] stringByDeletingPathExtension];
NSString *settingsFile = [[[[[file stringByDeletingLastPathComponent] stringByDeletingLastPathComponent] stringByDeletingLastPathComponent] stringByAppendingPathComponent:projectName] stringByAppendingPathExtension:@"iMovieProj"];
NSDictionary *loadedSettings = [NSDictionary dictionaryWithContentsOfFile:settingsFile];

	if ([[loadedSettings objectForKey:@"videoStandard"] isEqualTo:@"DV-PAL"])
	{
	inputWidth = @"768";
	inputHeight = @"576";
	inputFps = @"25";
	aspectValue = 5;
	}
	
	int duration;
	float tMovieWidth,tMovieHeight;

	NSMovie *theMovie = [[NSMovie alloc] initWithURL:[NSURL fileURLWithPath:file] byReference:NO];
	duration = GetMovieDuration([theMovie QTMovie]) / GetMovieTimeScale([theMovie QTMovie]);
	
	inputTotalTime = [[NSNumber numberWithInt:duration] stringValue];
	
	Rect tRect;
	GetMovieBox([theMovie QTMovie],&tRect);
	tMovieWidth=tRect.right-tRect.left;
	tMovieHeight=tRect.bottom-tRect.top;
	
	[theMovie release];
	return YES;
	
return NO;
}

- (BOOL)setTimeAndAspect:(NSString *)output isType:(int)type fromFile:(NSString *)file
{
	//Calculate the aspect ratio width / height	
	if ([[[output componentsSeparatedByString:@"Output"] objectAtIndex:0] rangeOfString:@"Video:"].length > 0)
	{
	NSString *resolution;
	NSArray *keepingRes = [[[[[[[output componentsSeparatedByString:@"Output"] objectAtIndex:0] componentsSeparatedByString:@"Video:"] objectAtIndex:1] componentsSeparatedByString:@"\n"] objectAtIndex:0] componentsSeparatedByString:@", "];
		
		if ([keepingRes count] > 2)
		resolution = [keepingRes objectAtIndex:2];
		else
		resolution = [keepingRes objectAtIndex:1];
		
		if ([[resolution componentsSeparatedByString:@"x"] count] < 2)
		resolution = [keepingRes objectAtIndex:[keepingRes count]-2];
		
		double width;
		double height;
	
		if ([[resolution componentsSeparatedByString:@"x"] count] > 1)
		{
		NSArray *tmp = [[[[[output componentsSeparatedByString:@"Output"] objectAtIndex:0] componentsSeparatedByString:@" fps"] objectAtIndex:0] componentsSeparatedByString:@","];
		width = [[[resolution componentsSeparatedByString:@"x"] objectAtIndex:0] doubleValue];
		height = [[[[[resolution componentsSeparatedByString:@"x"] objectAtIndex:1] componentsSeparatedByString:@"\n"] objectAtIndex:0] doubleValue];
		inputWidth = [[resolution componentsSeparatedByString:@"x"] objectAtIndex:0];
		inputHeight = [[resolution componentsSeparatedByString:@"x"] objectAtIndex:1];
		inputHeight = [[inputHeight componentsSeparatedByString:@")"] objectAtIndex:0];
		inputFps = [tmp objectAtIndex:[tmp count]-1];
		}
		else if ([file rangeOfString:@".iMovieProject"].length > 0  && [output rangeOfString:@"Video: mpeg4"].length > 0)
		{
		NSArray *tmp = [[[[[output componentsSeparatedByString:@"Output"] objectAtIndex:0] componentsSeparatedByString:@" fps"] objectAtIndex:0] componentsSeparatedByString:@","];
		width = 640;
		height = 480;
		inputWidth = @"640";
		inputHeight = @"480";
		inputFps = [tmp objectAtIndex:[tmp count]-1];
		}
	
		if ([inputFps rangeOfString:@"25.00"].length > 0 && [output rangeOfString:@"Video: dvvideo"].length > 0)
		{
		width = 720;
		height = 576;
		inputWidth = @"720";
		inputHeight = @"576";
		}
		
	double aspect = width / height;
	NSString *aspectString = [[NSNumber numberWithDouble:aspect] stringValue];
	
		// 1.85:1
		if ([aspectString rangeOfString:@"1.8"].length > 0)
		aspectValue = 1;
		// 16:9
		else if ([aspectString rangeOfString:@"1.7"].length > 0)
		aspectValue = 2;
		// 2.35:1
		else if ([aspectString rangeOfString:@"2.3"].length > 0 | [aspectString rangeOfString:@"2.4"].length > 0)
		aspectValue = 3;
		// 2.20:1
		else if ([aspectString rangeOfString:@"2.2"].length > 0)
		aspectValue = 4;
		// 4:3
		else if ([aspectString rangeOfString:@"1.3"].length > 0)
		aspectValue = 5;
		// wider than 16:9
		else if (aspect > 1.7)
		aspectValue = 6;
		// wider than 4:3
		else if (aspect > 1.3)
		aspectValue = 7;
		// 4:3 with pillarbox
		else
		aspectValue = 8;
		
		
		if (width == 352 && (height == 288 | height == 240))
		aspectValue = 5;
		else if ((width == 480 | width == 720) && (height == 576 | height == 480))
		aspectValue = 5;
		
		//Check if the iMovie project is 4:3 or 16:9
		if ([output rangeOfString:@"Video: dvvideo"].length > 0)
		{
			if ([file rangeOfString:@".iMovieProject"].length > 0)
			{
			NSString *projectName = [[[[[file stringByDeletingLastPathComponent] stringByDeletingLastPathComponent] stringByDeletingLastPathComponent] stringByDeletingPathExtension] lastPathComponent];
			NSString *projectLocation = [[[file stringByDeletingLastPathComponent] stringByDeletingLastPathComponent]stringByDeletingLastPathComponent];
			NSString *projectSettings = [[projectLocation stringByAppendingPathComponent:projectName] stringByAppendingPathExtension:@"iMovieProj"];
			
				if ([[NSFileManager defaultManager] fileExistsAtPath:projectSettings])
				{
					if ([[NSString stringWithContentsOfFile:projectSettings] rangeOfString:@"WIDE"].length > 0)
					aspectValue = 2;
					else
					aspectValue = 5;
				}
			}
		else 
		{
			if ([output rangeOfString:@"[PAR 59:54 DAR 295:216]"].length > 0 | [output rangeOfString:@"[PAR 10:11 DAR 15:11]"].length)
			aspectValue = 5;
			else if ([output rangeOfString:@"[PAR 118:81 DAR 295:162]"].length > 0 | [output rangeOfString:@"[PAR 40:33 DAR 20:11]"].length)
			aspectValue = 2;
		}
		
		inputFormat = @"DV";
		}
		else
		{
		inputFormat = @"notDV";
		}
		
	if ([output rangeOfString:@"DAR 16:9"].length > 0 && [output rangeOfString:@"mpeg2video"].length > 0)
	{
	aspectValue = 2;
	inputFormat = @"MPEG2";
	}
		
		
		//iMovie projects with HDV 1080i are 16:9, ffmpeg guesses 4:3
		if ([output rangeOfString:@"Video: Apple Intermediate Codec"].length > 0)
		{
			if ([file rangeOfString:@".iMovieProject"].length > 0)
			{
			aspectValue = 2;
			}
		}
	}
	else
	{
	aspectValue = -1;
	}
	
	if ([output rangeOfString:@"Duration:"].length > 0)	
	{
	double total = 0;
	
		if (![output rangeOfString:@"Duration: N/A,"].length > 0)
		{
		NSString *time = [[[[output componentsSeparatedByString:@"Duration: "] objectAtIndex:1] componentsSeparatedByString:@","] objectAtIndex:0];
		double hour = [[[time componentsSeparatedByString:@":"] objectAtIndex:0] doubleValue];
		double minute = [[[time componentsSeparatedByString:@":"] objectAtIndex:1] doubleValue];
		double second = [[[time componentsSeparatedByString:@":"] objectAtIndex:2] doubleValue];
		total  = (hour*60*60) + (minute*60) + second;
		}
		
	inputTotalTime = [[NSNumber numberWithDouble:total] stringValue];
	}
	
	if (![inputWidth isEqualTo:@""] && ![inputHeight isEqualTo:@""] && ![inputFps isEqualTo:@""])
	return YES;
	else if (type == 5 | type == 6)
	return YES;
	else
	return NO;
}

//Check if the file is a DV, since DV's cause problems
- (int)isReferenceMovie:(NSString *)path isType:(int)type
{
ffmpeg=[[NSTask alloc] init];
NSPipe *pipe=[[NSPipe alloc] init];
NSFileHandle *handle;
NSString *string;
int returnCode;

[ffmpeg setLaunchPath:[KWCommonMethods ffmpegPath]];

[ffmpeg setArguments:[NSArray arrayWithObjects:@"-threads",[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWEncodingThreads"] intValue]] stringValue],@"-i",path,nil]];
[ffmpeg setStandardError:pipe];
handle=[pipe fileHandleForReading];
[ffmpeg launch];
string=[[NSString alloc] initWithData:[handle readDataToEndOfFile] encoding:NSASCIIStringEncoding];

	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWDebug"] == YES)
	NSLog(string);
		
	if ([string rangeOfString:@"Could not find codec parameters"].length > 0 && [string rangeOfString:@"mov,mp4,"].length > 0)
	{
		//works audio=qt video=qt
		if ([self setTimeAndAspect:string isType:type fromFile:path])
		{
		returnCode = 1;
		}
		else
		{
		returnCode = 2;
		}
	}
	else
	{
	returnCode = 0;
	}

[ffmpeg waitUntilExit];
[string release];
[pipe release];
[ffmpeg release];

return returnCode;
}

///////////////////////
// Compilant actions //
///////////////////////

#pragma mark -
#pragma mark •• Compilant actions

//Check if the file is a valid VCD file (return YES if it is valid)
- (BOOL)isVCD:(NSString *)path
{
ffmpeg=[[NSTask alloc] init];
NSPipe *pipe=[[NSPipe alloc] init];
NSFileHandle *handle;
NSString *string;
BOOL returnCode;

[ffmpeg setLaunchPath:[KWCommonMethods ffmpegPath]];

[ffmpeg setArguments:[NSArray arrayWithObjects:@"-threads",[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWEncodingThreads"] intValue]] stringValue],@"-i",path,nil]];
[ffmpeg setStandardError:pipe];
handle=[pipe fileHandleForReading];
[ffmpeg launch];
string=[[NSString alloc] initWithData:[handle readDataToEndOfFile] encoding:NSASCIIStringEncoding];

	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWDebug"] == YES)
	NSLog(string);
	
	if (![string rangeOfString:@"Unknown format"].length > 0 && [string rangeOfString:@"Input #0"].length > 0)
	{
	NSString *saveString = [[string componentsSeparatedByString:@"Input #0"] objectAtIndex:1];
		
		if ([saveString rangeOfString:@"mpeg1video"].length > 0 
		&& [saveString rangeOfString:@"352x288"].length > 0 | [saveString rangeOfString:@"352x240"].length > 0
		&& [saveString rangeOfString:@"25.00 tb(r)"].length > 0 | [saveString rangeOfString:@"29.97 tb(r)"].length > 0)
		//&& [string rangeOfString:@"mp2"].length > 0
		//&& [string rangeOfString:@"224 kb/s"].length > 0
		//&& [string rangeOfString:@"stereo"].length > 0)
		returnCode = YES;
		else
		returnCode = NO;
	}
	else
	{
	returnCode = NO;
	}

[ffmpeg waitUntilExit];
[string release];
[pipe release];
[ffmpeg release];

return returnCode;
}

//Check if the file is a valid SVCD file (return YES if it is valid)
- (BOOL)isSVCD:(NSString *)path
{
ffmpeg=[[NSTask alloc] init];
NSPipe *pipe=[[NSPipe alloc] init];
NSFileHandle *handle;
NSString *string;
BOOL returnCode;
    
[ffmpeg setLaunchPath:[KWCommonMethods ffmpegPath]];

[ffmpeg setArguments:[NSArray arrayWithObjects:@"-threads",[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWEncodingThreads"] intValue]] stringValue],@"-i",path,nil]];
[ffmpeg setStandardError:pipe];
handle=[pipe fileHandleForReading];
[ffmpeg launch];
string=[[NSString alloc] initWithData:[handle readDataToEndOfFile] encoding:NSASCIIStringEncoding];

	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWDebug"] == YES)
	NSLog(string);
	
	if (![string rangeOfString:@"Unknown format"].length > 0 && [string rangeOfString:@"Input #0"].length > 0)
	{
	NSString *saveString = [[string componentsSeparatedByString:@"Input #0"] objectAtIndex:1];
		
		if ([saveString rangeOfString:@"mpeg2video"].length > 0 
		&& [saveString rangeOfString:@"480x576"].length > 0 | [saveString rangeOfString:@"480x480"].length > 0
		&& [saveString rangeOfString:@"25.00 tb(r)"].length > 0 | [saveString rangeOfString:@"29.97 tb(r)"].length > 0)
		//&& [string rangeOfString:@"mp2"].length > 0
		//&& [string rangeOfString:@"224 kb/s"].length > 0
		//&& [string rangeOfString:@"stereo"].length > 0)
		returnCode = YES;
		else
		returnCode = NO;
	}
	else
	{
	returnCode = NO;
	}

[ffmpeg waitUntilExit];
[string release];
[pipe release];
[ffmpeg release];

return returnCode;
}

//Check if the file is a valid DVD file (return YES if it is valid)
- (NSNumber *)isDVD:(NSString *)path
{
	if ([[path pathExtension] isEqualTo:@"m2v"])
	return NO;

ffmpeg = [[NSTask alloc] init];
NSPipe *pipe=[[NSPipe alloc] init];
NSFileHandle *handle;
NSString *string;
BOOL returnCode;
BOOL isWide;
 
[ffmpeg setLaunchPath:[KWCommonMethods ffmpegPath]];

[ffmpeg setArguments:[NSArray arrayWithObjects:@"-threads",[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWEncodingThreads"] intValue]] stringValue],@"-i",path,nil]];
[ffmpeg setStandardError:pipe];
handle=[pipe fileHandleForReading];
[ffmpeg launch];
string=[[NSString alloc] initWithData:[handle readDataToEndOfFile] encoding:NSASCIIStringEncoding];

	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWDebug"] == YES)
	NSLog(string);

	if (![string rangeOfString:@"Unknown format"].length > 0 && [string rangeOfString:@"Input #0"].length > 0)
	{
	NSString *saveString = [[string componentsSeparatedByString:@"Input #0"] objectAtIndex:1];

		if ([saveString rangeOfString:@"mpeg2video"].length > 0 
		&& [saveString rangeOfString:@"720x576"].length > 0 | [saveString rangeOfString:@"720x480"].length > 0
		&& [saveString rangeOfString:@"25.00 tb(r)"].length > 0 | [saveString rangeOfString:@"29.97 tb(r)"].length > 0)
		returnCode = YES;
		else
		returnCode = NO;
	}
	else
	{
	returnCode = NO;
	}
	
	if ([string rangeOfString:@"DAR 16:9"].length > 0)
	isWide = YES;
	else
	isWide = NO;
	
[ffmpeg waitUntilExit];	
[string release];
[pipe release];
[ffmpeg release];

	if (returnCode)
	return [NSNumber numberWithBool:isWide];
	else
	return nil;
}

//Check if the file is a valid MPEG4 file (return YES if it is valid)
- (BOOL)isMPEG4:(NSString *)path
{
ffmpeg=[[NSTask alloc] init];
NSPipe *pipe=[[NSPipe alloc] init];
NSFileHandle *handle;
NSString *string;
BOOL returnCode;
    
[ffmpeg setLaunchPath:[KWCommonMethods ffmpegPath]];

[ffmpeg setArguments:[NSArray arrayWithObjects:@"-threads",[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWEncodingThreads"] intValue]] stringValue],@"-i",path,nil]];
[ffmpeg setStandardError:pipe];
handle=[pipe fileHandleForReading];
[ffmpeg launch];
string=[[NSString alloc] initWithData:[handle readDataToEndOfFile] encoding:NSASCIIStringEncoding];

	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWDebug"] == YES)
	NSLog(string);
	
	if (![string rangeOfString:@"Unknown format"].length > 0 && [string rangeOfString:@"Input #0"].length > 0)
	{
	NSString *saveString = [[string componentsSeparatedByString:@"Input #0"] objectAtIndex:1];

		if ([saveString rangeOfString:@"Video: mpeg4"].length > 0 && [[[path pathExtension] lowercaseString] isEqualTo:@"avi"])
		returnCode = YES;
		else if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWAllowMSMPEG4"] == YES && [saveString rangeOfString:@"Video: msmpeg4"].length > 0 && [[[path pathExtension]  lowercaseString] isEqualTo:@"avi"])
		returnCode = YES;
		else
		returnCode = NO;
	}
	else
	{
	returnCode = NO;
	}

[ffmpeg waitUntilExit];
[string release];
[pipe release];
[ffmpeg release];

return returnCode;
}

///////////////////////
// Framework actions //
///////////////////////

#pragma mark -
#pragma mark •• Framework actions

- (NSArray *)failureArray
{
return failedFilesExplained;
}

- (NSArray *)succesArray
{
return convertedFiles;
}

///////////////////
// Other actions //
///////////////////

#pragma mark -
#pragma mark •• Other actions

- (NSString *)convertToEven:(NSString *)numberAsString
{
NSString *convertedNumber = [[NSNumber numberWithInt:[numberAsString intValue]] stringValue];

unichar ch = [convertedNumber characterAtIndex:[convertedNumber length]-1];
NSString *lastCharacter = [NSString stringWithFormat:@"%C", ch];

	if ([lastCharacter isEqualTo:@"1"] | [lastCharacter isEqualTo:@"3"] | [lastCharacter isEqualTo:@"5"] | [lastCharacter isEqualTo:@"7"] | [lastCharacter isEqualTo:@"9"])
	return [[NSNumber numberWithInt:[convertedNumber intValue]+1] stringValue];
	else
	return convertedNumber;
}

- (NSString *)getPadSize:(float)size withAspectW:(float)aspectW withAspectH:(float)aspectH withWidth:(float)width withHeight:(float)height withBlackBars:(BOOL)blackBars
{
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWSaveBorders"] == YES)
	{
	float heightBorder = [[[NSUserDefaults standardUserDefaults] objectForKey:@"KWSaveBorderSize"] floatValue];
	float widthBorder = aspectW / (aspectH / size);
	
		if (blackBars == YES)
		return [self convertToEven:[[NSNumber numberWithFloat:(size - (size * aspectW / aspectH) / (width / height)) / 2 + heightBorder] stringValue]];
		else
		return [self convertToEven:[[NSNumber numberWithFloat:((size * aspectW / aspectH) / (width / height) - size) / 2 + widthBorder] stringValue]];
	}
	else
	{
		if (blackBars == YES)
		return [self convertToEven:[[NSNumber numberWithFloat:(size - (size * aspectW / aspectH) / (width / height)) / 2] stringValue]];
		else
		return [self convertToEven:[[NSNumber numberWithFloat:((size * aspectW / aspectH) / (width / height) - size) / 2] stringValue]];
	}
}

- (BOOL)remuxMPEG2File:(NSString *)path outPath:(NSString *)outFile
{
ffmpeg=[[NSTask alloc] init];
NSPipe *pipe=[[NSPipe alloc] init];
NSFileHandle *handle;
NSString *string;

[ffmpeg setStandardError:pipe];
handle=[pipe fileHandleForReading];
    
[ffmpeg setLaunchPath:[KWCommonMethods ffmpegPath]];

[ffmpeg setArguments:[NSArray arrayWithObjects:@"-threads",[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWEncodingThreads"] intValue]] stringValue],@"-i",path,@"-y",@"-acodec",@"copy",@"-vcodec",@"copy",@"-target",@"dvd",outFile,nil]];
status = 2;
[ffmpeg launch];
string=[[NSString alloc] initWithData:[handle readDataToEndOfFile] encoding:NSASCIIStringEncoding];

	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWDebug"] == YES)
	NSLog(string);

[ffmpeg waitUntilExit];
int taskStatus = [ffmpeg terminationStatus];
[ffmpeg release];
status = 0;
[pipe release];
[string release];

	if (taskStatus == 0)
	{
	return YES;
	}
	else
	{
	[[NSFileManager defaultManager] removeFileAtPath:outFile handler:nil];
	return NO;
	}
}

- (BOOL)canCombineStreams:(NSString *)path
{
	if ([[NSFileManager defaultManager] fileExistsAtPath:[[path stringByDeletingPathExtension] stringByAppendingPathExtension:@"mp2"]])
	return YES;
	else if ([[NSFileManager defaultManager] fileExistsAtPath:[[path stringByDeletingPathExtension] stringByAppendingPathExtension:@"ac3"]])
	return YES;
	
return NO;
}

- (BOOL)combineStreams:(NSString *)path atOutputPath:(NSString *)outputPath
{
NSString *audioFile = @"";

	if ([[NSFileManager defaultManager] fileExistsAtPath:[[path stringByDeletingPathExtension] stringByAppendingPathExtension:@"mp2"]])
	audioFile = [[path stringByDeletingPathExtension] stringByAppendingPathExtension:@"mp2"];
	else if ([[NSFileManager defaultManager] fileExistsAtPath:[[path stringByDeletingPathExtension] stringByAppendingPathExtension:@"ac3"]])
	audioFile = [[path stringByDeletingPathExtension] stringByAppendingPathExtension:@"ac3"];

	if (![audioFile isEqualTo:@""])
	{
	ffmpeg=[[NSTask alloc] init];
	NSPipe *pipe=[[NSPipe alloc] init];
	NSFileHandle *handle;
	NSString *string;

	[ffmpeg setStandardError:pipe];
	handle=[pipe fileHandleForReading];
    
[ffmpeg setLaunchPath:[KWCommonMethods ffmpegPath]];

	[ffmpeg setArguments:[NSArray arrayWithObjects:@"-threads",[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWEncodingThreads"] intValue]] stringValue],@"-i",path,@"-threads",[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWEncodingThreads"] intValue]] stringValue],@"-i",audioFile,@"-y",@"-acodec",@"copy",@"-vcodec",@"copy",@"-target",@"dvd",outputPath,nil]];
	status = 2;
	[ffmpeg launch];
	string=[[NSString alloc] initWithData:[handle readDataToEndOfFile] encoding:NSASCIIStringEncoding];
	
		if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWDebug"] == YES)
		NSLog(string);
	
	[ffmpeg waitUntilExit];
	int taskStatus = [ffmpeg terminationStatus];
	[ffmpeg release];
	status = 0;
	[pipe release];
	[string release];
	
		if (taskStatus == 0)
		{
		return YES;
		}
		else
		{
		[[NSFileManager defaultManager] removeFileAtPath:[[path stringByDeletingPathExtension] stringByAppendingPathExtension:@"mpg"] handler:nil];
		return NO;
		}
	}
	else
	{
	return NO;
	}
}

- (int)totalTimeInSeconds:(NSString *)path
{
ffmpeg=[[NSTask alloc] init];
NSPipe *pipe=[[NSPipe alloc] init];
NSFileHandle *handle;
NSString *string;

[ffmpeg setLaunchPath:[KWCommonMethods ffmpegPath]];

[ffmpeg setArguments:[NSArray arrayWithObjects:@"-threads",[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWEncodingThreads"] intValue]] stringValue],@"-i",path,nil]];
[ffmpeg setStandardError:pipe];
handle=[pipe fileHandleForReading];
[ffmpeg launch];
string=[[NSString alloc] initWithData:[handle readDataToEndOfFile] encoding:NSASCIIStringEncoding];

	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWDebug"] == YES)
	NSLog(string);
		
NSString *durationsString = [[[[string componentsSeparatedByString:@"Duration: "] objectAtIndex:1] componentsSeparatedByString:@"."] objectAtIndex:0];

int hours = [[[durationsString componentsSeparatedByString:@":"] objectAtIndex:0] intValue];
int minutes = [[[durationsString componentsSeparatedByString:@":"] objectAtIndex:1] intValue];
int seconds = [[[durationsString componentsSeparatedByString:@":"] objectAtIndex:2] intValue];

int totalTime = seconds + (minutes * 60) + (hours * 60 * 60);

[string release];
[pipe release];
[ffmpeg release];

return totalTime;
}

- (NSImage *)getImageAtPath:(NSString *)path atTime:(int)time isWideScreen:(BOOL)wide
{
ffmpeg=[[NSTask alloc] init];
NSPipe *pipe=[[NSPipe alloc] init];
NSPipe *outputPipe=[[NSPipe alloc] init];
NSFileHandle *handle;
NSFileHandle *outputHandle;
NSImage *image;
[ffmpeg setLaunchPath:[KWCommonMethods ffmpegPath]];
[ffmpeg setArguments:[NSArray arrayWithObjects:@"-ss",[[NSNumber numberWithInt:time] stringValue],@"-i",path,@"-vframes",@"1" ,@"-f",@"image2",@"-",nil]];
[ffmpeg setStandardOutput:outputPipe];
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWDebug"] == NO)
	{
	[ffmpeg setStandardError:pipe];
	handle=[pipe fileHandleForReading];
	}
outputHandle=[outputPipe fileHandleForReading];
[ffmpeg launch];
image = [[NSImage alloc] initWithData:[outputHandle readDataToEndOfFile]];

	if (wide)
	[image setSize:NSMakeSize(720,404)];

[pipe release];
[outputPipe release];
[ffmpeg release];

	if (!image && time > 1)
	return [self getImageAtPath:path atTime:1 isWideScreen:wide];

return [image autorelease];
}

@end
