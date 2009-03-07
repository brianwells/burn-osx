//
//  KWDVDAuthorizer.m
//  KWDVDAuthorizer
//
//  Created by Maarten Foukhar on 16-3-07.
//  Copyright 2009 Kiwi Fruitware. All rights reserved.
//

#import "KWDVDAuthorizer.h"
#import "KWCommonMethods.h"
#import "KWConverter.h"

@implementation KWDVDAuthorizer

- (id) init
{
self = [super init];

userCanceled = NO;

[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(cancelAuthoring) name:@"KWCancelAuthoring" object:nil];
[[NSNotificationCenter defaultCenter] postNotificationName:@"KWCancelNotificationChanged" object:@"KWCancelAuthoring"];

return self;
}

- (void)dealloc
{
[[NSNotificationCenter defaultCenter] removeObserver:self];

[super dealloc];
}

- (void)cancelAuthoring
{
	if (spumux)
	[spumux terminate];
	
	if (dvdauthor)
	[dvdauthor terminate];
	
	if (ffmpeg)
	[ffmpeg terminate];
	
userCanceled = YES;
}

////////////////////////////
// DVD-Video without menu //
////////////////////////////

#pragma mark -
#pragma mark •• DVD-Video without menu

- (int)createStandardDVDFolderAtPath:(NSString *)path withFileArray:(NSArray *)fileArray withSize:(NSNumber *)size
{
	if (![[NSFileManager defaultManager] fileExistsAtPath:path])
	[[NSFileManager defaultManager] createDirectoryAtPath:path attributes:nil];

[self createStandardDVDXMLAtPath:path withFileArray:fileArray];

progressSize = size;

BOOL tempBOOL = [self authorDVDWithXMLFile:[path stringByAppendingPathComponent:@"dvdauthor.xml"] withFileArray:fileArray atPath:path];
int succes;

	if (tempBOOL == NO && userCanceled == NO)
	{
	[[NSFileManager defaultManager] removeFileAtPath:path handler:nil];
	succes = 1;
	}
	else if (tempBOOL == NO && userCanceled == YES)
	{
	[[NSFileManager defaultManager] removeFileAtPath:path handler:nil];
	succes = 2;
	}

[[NSFileManager defaultManager] removeFileAtPath:[path stringByAppendingPathComponent:@"dvdauthor.xml"] handler:nil];

succes = 0;

[[NSFileManager defaultManager] removeFileAtPath:[path stringByAppendingPathComponent:@"dvdauthor.xml"] handler:nil];

	if (succes == 0)
	{
	dvdauthor = [[NSTask alloc] init];
			
		if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWDebug"] == NO)
		{
		NSFileHandle *handle = [NSFileHandle fileHandleWithNullDevice];
		[dvdauthor setStandardError:handle];
		}
			
	[dvdauthor setLaunchPath:[[NSBundle mainBundle] pathForResource:@"dvdauthor" ofType:@""]];
	[dvdauthor setArguments:[NSArray arrayWithObjects:@"-T",@"-o",path,nil]];
	[dvdauthor launch];
	[dvdauthor waitUntilExit];
	succes = [dvdauthor terminationStatus];
	[dvdauthor release];
	dvdauthor = nil;
	}

	if (succes == 0)
	{
	return 0;
	}
	else if (succes == 1 && userCanceled == NO)
	{
	[[NSFileManager defaultManager] removeFileAtPath:path handler:nil];
	return 1;
	}
	else
	{
	[[NSFileManager defaultManager] removeFileAtPath:path handler:nil];
	return 2;
	}
}

- (void)createStandardDVDXMLAtPath:(NSString *)path withFileArray:(NSArray *)fileArray
{
NSString *xmlFile = [[@"<dvdauthor dest=\"" stringByAppendingString:path] stringByAppendingString:@"\">\n<titleset>\n<titles>\n<pgc>"];
	
	int x;
	for (x=0;x<[fileArray count];x++)
	{
	xmlFile = [xmlFile stringByAppendingString:[[@"\n<vob file=\"" stringByAppendingString:[[fileArray objectAtIndex:x] objectForKey:@"Path"]] stringByAppendingString:@"\""]];
	
		if ([[[fileArray objectAtIndex:x] objectForKey:@"Chapters"] count] > 0)
		{
		xmlFile = [xmlFile stringByAppendingString:@" chapters=\"00:00:00,"];
		
			int i;
			for (i=0;i<[[[fileArray objectAtIndex:x] objectForKey:@"Chapters"] count];i++)
			{
			int time = [[[[[fileArray objectAtIndex:x] objectForKey:@"Chapters"] objectAtIndex:i] objectForKey:@"RealTime"] intValue];
				
				if (time > 0)
				{
				xmlFile = [xmlFile stringByAppendingString:[KWCommonMethods formatTime:[[[[[fileArray objectAtIndex:x] objectForKey:@"Chapters"] objectAtIndex:i] objectForKey:@"RealTime"] intValue]]];
					if (i+1 < [[[[fileArray objectAtIndex:x] objectForKey:@"Chapters"] objectAtIndex:x] count])
					xmlFile = [xmlFile stringByAppendingString:@","];
					else
					xmlFile = [xmlFile stringByAppendingString:@"\""];
				}
			}
		}
	
	xmlFile = [xmlFile stringByAppendingString:@"/>\n"];
	}
	
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWLoopDVD"] == YES)
	xmlFile = [xmlFile stringByAppendingString:@"<post>jump title 1;</post>\n"];
	else
	xmlFile = [xmlFile stringByAppendingString:@"<post>exit;</post>\n"];
	
xmlFile = [xmlFile stringByAppendingString:@"</pgc>\n</titles>\n</titleset>\n</dvdauthor>"];

[xmlFile writeToFile:[path stringByAppendingPathComponent:@"dvdauthor.xml"] atomically:YES];
}

///////////////
// DVD-Audio //
///////////////

#pragma mark -
#pragma mark •• DVD-Audio

- (int)createStandardDVDAudioFolderAtPath:(NSString *)path withFiles:(NSArray *)files
{
fileSize = 0;
	
		int i;
		for (i=0;i<[files count];i++)
		{
		fileSize = fileSize + [[[[NSFileManager defaultManager] fileAttributesAtPath:[files objectAtIndex:i] traverseLink:YES] objectForKey:NSFileSize] floatValue] / 2048;
		}
		
[[NSNotificationCenter defaultCenter] postNotificationName:@"KWMaximumValueChanged" object:[NSNumber numberWithFloat:fileSize]];

NSMutableArray *options = [NSMutableArray array];
NSPipe *pipe=[[NSPipe alloc] init];
NSFileHandle *handle;
NSData *data;

dvdauthor = [[NSTask alloc] init];
[dvdauthor setLaunchPath:[[NSBundle mainBundle] pathForResource:@"dvda-author" ofType:@""]];
[options addObject:@"-o"];
[options addObject:path];
[options addObject:@"-g"];
[options addObjectsFromArray:files];
[options addObject:@"-P0"];

[dvdauthor setArguments:options];
[dvdauthor setStandardOutput:pipe];
handle=[pipe fileHandleForReading];

//int currentFile = 1;

[self performSelectorOnMainThread:@selector(startTimer:) withObject:[path stringByAppendingPathComponent:@"AUDIO_TS/ATS_01_1.AOB"] waitUntilDone:NO];

	if ([[NSFileManager defaultManager] fileExistsAtPath:path])
	[[NSFileManager defaultManager] removeFileAtPath:path handler:nil];

[dvdauthor launch];

NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
NSString *string = nil;

	while([data=[handle availableData] length])
	{
	string=[[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
	
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWDebug"] == YES)
	NSLog(string);
		
		/*if ([string rangeOfString:@"Processing "].length > 0)
		{
		[[NSNotificationCenter defaultCenter] postNotificationName:@"KWStatusChanged" object:[[NSLocalizedString(@"Processing: ", Localized) stringByAppendingString:[[NSFileManager defaultManager] displayNameAtPath:[[[[string componentsSeparatedByString:@"Processing "] objectAtIndex:1] componentsSeparatedByString:@"\n"] objectAtIndex:0]]] stringByAppendingString:[[[@" " stringByAppendingString:[[NSNumber numberWithInt:currentFile] stringValue]] stringByAppendingString:NSLocalizedString(@" of ", Localized)] stringByAppendingString:[[NSNumber numberWithInt:[files count]] stringValue]]]];
		
		currentFile = currentFile + 1;
		}*/
	
	[string release];
	string = nil;
	data = nil;
	
	[innerPool release];
	innerPool = [[NSAutoreleasePool alloc] init];
	}

[dvdauthor waitUntilExit];
[timer invalidate];

int taskStatus = [dvdauthor terminationStatus];
[pipe release];
[dvdauthor release];
dvdauthor = nil;

	if (taskStatus == 0)
	{
	return 0;
	}
	else if (taskStatus == 1 && userCanceled == NO)
	{
	[[NSFileManager defaultManager] removeFileAtPath:path handler:nil];
	return 1;
	}
	else
	{
	[[NSFileManager defaultManager] removeFileAtPath:path handler:nil];
	return 2;
	}
}

- (void)startTimer:(NSArray *)object
{
timer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(imageProgress:) userInfo:object repeats:YES];
}

- (void)imageProgress:(NSTimer *)theTimer
{
float currentSize = [[[[NSFileManager defaultManager] fileAttributesAtPath:[theTimer userInfo] traverseLink:YES] objectForKey:NSFileSize] floatValue] / 2048;
	double percent = [[[[[NSNumber numberWithDouble:currentSize / fileSize * 100] stringValue] componentsSeparatedByString:@"."] objectAtIndex:0] doubleValue];
		if (percent < 101)
		[[NSNotificationCenter defaultCenter] postNotificationName:@"KWStatusByAddingPercentChanged" object:[[@" (" stringByAppendingString:[[NSNumber numberWithDouble:percent] stringValue]] stringByAppendingString:@"%)"]];
[[NSNotificationCenter defaultCenter] postNotificationName:@"KWValueChanged" object:[NSNumber numberWithFloat:currentSize]];
}

/////////////////////////
// DVD-Video with menu //
/////////////////////////

#pragma mark -
#pragma mark •• DVD-Video with menu

//Create a menu with given files and chapters
- (int)createDVDMenuFiles:(NSString *)path withTheme:(NSDictionary *)currentTheme withFileArray:(NSArray *)fileArray withSize:(NSNumber *)size withName:(NSString *)name
{ 
progressSize = size;

//Set value for our progress panel
[[NSNotificationCenter defaultCenter] postNotificationName:@"KWValueChanged" object:[NSNumber numberWithDouble:-1]];
[[NSNotificationCenter defaultCenter] postNotificationName:@"KWStatusChanged" object:NSLocalizedString(@"Creating DVD Theme", Localized)];

//Load theme
theme = currentTheme;

BOOL succes;

	//Create temp folders
	if (![[NSFileManager defaultManager] fileExistsAtPath:path])
	succes = [[NSFileManager defaultManager] createDirectoryAtPath:path attributes:nil];
	
	if (succes)
	succes = [[NSFileManager defaultManager] createDirectoryAtPath:[path stringByAppendingPathComponent:@"THEME_TS"] attributes:nil];

	if ([fileArray count] == 1 && [[[fileArray objectAtIndex:0] objectForKey:@"Chapters"] count] > 0)
	{
		//Create Chapter Root Menu
		if (succes)
		succes = [self createRootMenu:[path stringByAppendingPathComponent:@"THEME_TS"] withName:name withTitles:NO withSecondButton:YES];

		//Create Chapter Selection Menu(s)
		if (succes)
		succes = [self createSelectionMenus:fileArray withChapters:YES atPath:[path stringByAppendingPathComponent:@"THEME_TS"]];
	}
	else
	{
		//Create Root Menu
		if (succes)
		succes = [self createRootMenu:[path stringByAppendingPathComponent:@"THEME_TS"] withName:name withTitles:YES withSecondButton:([fileArray count] > 1)];

		//Create Title Selection Menu(s)
		if (succes)
		succes = [self createSelectionMenus:fileArray withChapters:NO atPath:[path stringByAppendingPathComponent:@"THEME_TS"]];

		//Create Chapter Menu
		if (succes)
		succes = [self createChapterMenus:[path stringByAppendingPathComponent:@"THEME_TS"] withFileArray:fileArray];

		//Create Chapter Selection Menu(s)
		if (succes)
		succes = [self createSelectionMenus:fileArray withChapters:YES atPath:[path stringByAppendingPathComponent:@"THEME_TS"]];
	}

	//Create dvdauthor XML file
	if (succes)
	succes = [self createDVDXMLAtPath:[[path stringByAppendingPathComponent:@"THEME_TS"] stringByAppendingPathComponent:@"dvdauthor.xml"] withFileArray:fileArray atFolderPath:path];

	//Author DVD
	if (succes)
	succes = [self authorDVDWithXMLFile:[[path stringByAppendingPathComponent:@"THEME_TS"] stringByAppendingPathComponent:@"dvdauthor.xml"] withFileArray:fileArray atPath:path];

	if (!succes)
	{
	//[[NSFileManager defaultManager] removeFileAtPath:path handler:nil];
	
		if (userCanceled)
		return 2;
		else
		return 1;
	}

[[NSFileManager defaultManager] removeFileAtPath:[path stringByAppendingPathComponent:@"THEME_TS"] handler:nil];

return 0;
}

//////////////////
// Main actions //
//////////////////

#pragma mark -
#pragma mark •• Main actions

//Create root menu (Start and Titles)
- (BOOL)createRootMenu:(NSString *)path withName:(NSString *)name withTitles:(BOOL)titles withSecondButton:(BOOL)secondButton
{
BOOL succes;

NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];

//Create Images
NSImage *image = [self rootMenuWithTitles:titles withName:name withSecondButton:secondButton];
NSImage *mask = [self rootMaskWithTitles:titles withSecondButton:secondButton];
		
//Save mask as png
succes = [self saveImage:mask toPath:[path stringByAppendingPathComponent:@"Mask.png"]];

	//Create mpg with menu in it
	if (succes)
	succes = [self createDVDMenuFile:[path stringByAppendingPathComponent:@"Title Menu.mpg"] withImage:image withMaskFile:[path stringByAppendingPathComponent:@"Mask.png"]];

[innerPool release];
	
return succes;
}

//Batch create title selection menus
- (BOOL)createSelectionMenus:(NSArray *)fileArray withChapters:(BOOL)chapters atPath:(NSString *)path
{
BOOL succes = YES;
int menuSeries = 1;
int numberOfpages = 0;
NSMutableArray *titlesWithChapters = [[NSMutableArray alloc] init];
NSMutableArray *indexes = [[NSMutableArray alloc] init];
NSArray *objects = fileArray;

	if (chapters)
	{
		int i;
		for (i=0;i<[fileArray count];i++)
		{
			if ([[[fileArray objectAtIndex:i] objectForKey:@"Chapters"] count] > 0)
			{
			[titlesWithChapters addObject:[[fileArray objectAtIndex:i] objectForKey:@"Chapters"]];
			[indexes addObject:[NSNumber numberWithInt:i]];
			}
		}

	objects = titlesWithChapters;
	menuSeries = [titlesWithChapters count];
	}

	int x;
	for (x=0;x<menuSeries;x++)
	{
	NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];

		if (chapters)
		objects = [titlesWithChapters objectAtIndex:x];

	NSMutableArray *images = [[NSMutableArray alloc] init];

		int i;
		for (i=0;i<[objects count];i++)
		{
			if (chapters)
			[images addObject:[[[NSImage alloc] initWithData:[[objects objectAtIndex:i] objectForKey:@"Image"]] autorelease]];
			else
			[images addObject:[[KWConverter alloc] getImageAtPath:[[objects objectAtIndex:i] objectForKey:@"Path"] atTime:[[theme objectForKey:@"KWScreenshotAtTime"] intValue] isWideScreen:[[[objects objectAtIndex:i] objectForKey:@"WideScreen"] boolValue]]];
		}

		//create the menu's and masks
		NSString *outputName;
		if (chapters)
		outputName = @"Chapter Selection ";
		else
		outputName = @"Title Selection ";

		int number;
		if ([[theme objectForKey:@"KWSelectionMode"] intValue] != 2)
		number = [[theme objectForKey:@"KWSelectionImagesOnAPage"] intValue];
		else
		number = [[theme objectForKey:@"KWSelectionStringsOnAPage"] intValue];

	int pages = [objects count] / number;

		if ([objects count] > number * pages)
		pages = pages + 1;

	NSRange firstRange;
	NSImage *image;
	NSImage *mask;

		if (pages > 1)
		{
		//Create first page range
		firstRange = NSMakeRange(0,number);

			int i;
			for (i=1;i<pages - 1;i++)
			{
				if (succes)
				{
				NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];

				NSRange range = NSMakeRange(number * i,number);
				image = [self selectionMenuWithTitles:(!chapters) withObjects:[objects subarrayWithRange:range] withImages:[images subarrayWithRange:range] addNext:YES addPrevious:YES];
				mask = [self selectionMaskWithTitles:(!chapters) withObjects:[objects subarrayWithRange:range] addNext:YES addPrevious:YES];
				succes = [self saveImage:mask toPath:[path stringByAppendingPathComponent:@"Mask.png"]];
				
					if (succes)
					succes = [self createDVDMenuFile:[[[path stringByAppendingPathComponent:outputName] stringByAppendingString:[[NSNumber numberWithInt:i + 1 + numberOfpages] stringValue]] stringByAppendingString:@".mpg"] withImage:image withMaskFile:[path stringByAppendingPathComponent:@"Mask.png"]];
				
				[innerPool release];
				}
			}

			if (succes)
			{
			NSRange range = NSMakeRange((pages - 1) * number,[objects count] - (pages - 1) * number);
			image = [self selectionMenuWithTitles:(!chapters) withObjects:[objects subarrayWithRange:range] withImages:[images subarrayWithRange:range] addNext:NO addPrevious:YES];
			mask = [self selectionMaskWithTitles:(!chapters) withObjects:[objects subarrayWithRange:range] addNext:NO addPrevious:YES];
			succes = [self saveImage:mask toPath:[path stringByAppendingPathComponent:@"Mask.png"]];
			
				if (succes)
				succes = [self createDVDMenuFile:[[[path stringByAppendingPathComponent:outputName] stringByAppendingString:[[NSNumber numberWithInt:pages + numberOfpages] stringValue]] stringByAppendingString:@".mpg"] withImage:image withMaskFile:[path stringByAppendingPathComponent:@"Mask.png"]];
			}
		}
		else
		{
		firstRange = NSMakeRange(0,[objects count]);
		}

		if (succes)
		{
		image = [self selectionMenuWithTitles:(!chapters) withObjects:[objects subarrayWithRange:firstRange] withImages:[images subarrayWithRange:firstRange] addNext:([objects count] > number) addPrevious:NO];
		mask = [self selectionMaskWithTitles:(!chapters) withObjects:[objects subarrayWithRange:firstRange] addNext:([objects count] > number) addPrevious:NO];
		succes = [self saveImage:mask toPath:[path stringByAppendingPathComponent:@"Mask.png"]];
		
			if (succes)
			succes = [self createDVDMenuFile:[path stringByAppendingPathComponent:[[outputName stringByAppendingString:[[NSNumber numberWithInt:1 + numberOfpages] stringValue]] stringByAppendingString:@".mpg"]] withImage:image withMaskFile:[path stringByAppendingPathComponent:@"Mask.png"]];
		}

	numberOfpages = numberOfpages + pages;
	[images release];
	images = nil;
	
	[innerPool release];
	}
	
[titlesWithChapters release];
[indexes release];

return succes;
}

//Create a chapter menu (Start and Chapters)
- (BOOL)createChapterMenus:(NSString *)path withFileArray:(NSArray *)fileArray
{
BOOL succes = YES;

	//Check if there are any chapters
	int i;
	for (i=0;i<[fileArray count];i++)
	{
		if ([[[fileArray objectAtIndex:i] objectForKey:@"Chapters"] count] > 0)
		{
		NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
		
		NSString *name = [[[[fileArray objectAtIndex:i] objectForKey:@"Path"] lastPathComponent] stringByDeletingPathExtension];

		//Create Images
		NSImage *image = [self rootMenuWithTitles:NO withName:name withSecondButton:YES];
		NSImage *mask = [self rootMaskWithTitles:NO withSecondButton:YES];
		
		//Save mask as png
		succes = [self saveImage:mask toPath:[path stringByAppendingPathComponent:@"Mask.png"]];

			//Create mpg with menu in it
			if (succes)
			succes = [self createDVDMenuFile:[path stringByAppendingPathComponent:[name stringByAppendingString:@".mpg"]] withImage:image withMaskFile:[path stringByAppendingPathComponent:@"Mask.png"]];
		
		[innerPool release];
		}
	}
	
return succes;
}

/////////////////
// DVD actions //
/////////////////

#pragma mark -
#pragma mark •• DVD actions

- (BOOL)createDVDMenuFile:(NSString *)path withImage:(NSImage *)image withMaskFile:(NSString *)maskFile
{
BOOL succes = [[[@"<subpictures>\n<stream>\n<spu\nforce=\"yes\"\nstart=\"00:00:00.00\" end=\"00:00:00.00\"\nhighlight=\"" stringByAppendingString:[maskFile lastPathComponent]] stringByAppendingString:@"\"\nautooutline=\"infer\"\noutlinewidth=\"6\"\nautoorder=\"rows\"\n>\n</spu>\n</stream>\n</subpictures>"] writeToFile:[[path stringByDeletingPathExtension] stringByAppendingPathExtension:@"xml"] atomically:YES];

	if (succes)
	{
	NSPipe *pipe=[[NSPipe alloc] init];
	NSPipe *pipe2=[[NSPipe alloc] init];
	NSFileHandle *myHandle = [pipe fileHandleForWriting];
	NSFileHandle *myHandle2 = [pipe2 fileHandleForReading];
	ffmpeg = [[NSTask alloc] init];
	NSString *format;
	
		if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultRegion"] intValue] == 0)
		format = @"pal-dvd";
		else
		format = @"ntsc-dvd";

	[ffmpeg setLaunchPath:[KWCommonMethods ffmpegPath]];

		if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDVDThemeFormat"] intValue] == 0)
		[ffmpeg setArguments:[NSArray arrayWithObjects:@"-f",@"image2pipe",@"-threads",[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWEncodingThreads"] intValue]] stringValue],@"-i",@"pipe:.jpg",@"-target",format,@"-",@"-an",nil]];
		else
		[ffmpeg setArguments:[NSArray arrayWithObjects:@"-f",@"image2pipe",@"-threads",[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWEncodingThreads"] intValue]] stringValue],@"-i",@"pipe:.jpg",@"-target",format,@"-",@"-an",@"-aspect",@"16:9",nil]];

	[ffmpeg setStandardInput:pipe];
	[ffmpeg setStandardOutput:pipe2];
	[ffmpeg setStandardError:[NSFileHandle fileHandleWithNullDevice]];

	spumux = [[NSTask alloc] init];
	[[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil];
	[spumux setStandardOutput:[NSFileHandle fileHandleForWritingAtPath:path]];
	[spumux setStandardInput:myHandle2];
	[spumux setLaunchPath:[[NSBundle mainBundle] pathForResource:@"spumux" ofType:@""]];
	[spumux setCurrentDirectoryPath:[path stringByDeletingLastPathComponent]];
	[spumux setArguments:[NSArray arrayWithObject:[[path stringByDeletingPathExtension] stringByAppendingPathExtension:@"xml"]]];
	NSPipe *errorPipe=[[NSPipe alloc] init];
	NSFileHandle *handle;
	[spumux setStandardError:errorPipe];
	handle=[errorPipe fileHandleForReading];
	[spumux launch];

	[ffmpeg launch];
	
	NSData *tiffData = [image TIFFRepresentation];
	NSBitmapImageRep *bitmap = [NSBitmapImageRep imageRepWithData:tiffData];
	[myHandle writeData:[bitmap representationUsingType:NSJPEGFileType properties:[NSDictionary dictionaryWithObject:[NSNumber numberWithFloat:1.0] forKey:NSImageCompressionFactor]]];
	[myHandle closeFile];

	[ffmpeg waitUntilExit];
	[ffmpeg release];
	ffmpeg = nil;
	
	[pipe release];
	[pipe2 release];

	NSString *string=[[NSString alloc] initWithData:[handle readDataToEndOfFile] encoding:NSASCIIStringEncoding];
	
		if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWDebug"] == YES)
		NSLog(string);

	[spumux waitUntilExit];

	succes = ([spumux terminationStatus] == 0);

	[spumux release];
	spumux = nil;
	[errorPipe release];
	[string release];
	string = nil;
	
		if (!succes)
		[[NSFileManager defaultManager] removeFileAtPath:path handler:nil];

	[[NSFileManager defaultManager] removeFileAtPath:maskFile handler:nil];
	[[NSFileManager defaultManager] removeFileAtPath:[[path stringByDeletingPathExtension] stringByAppendingPathExtension:@"xml"] handler:nil];
	}
	
return succes;
}

//Create a xml file for dvdauthor
-(BOOL)createDVDXMLAtPath:(NSString *)path withFileArray:(NSArray *)fileArray atFolderPath:(NSString *)folderPath
{
NSString *xmlContent;

	if ([fileArray count] == 1 && [[[fileArray objectAtIndex:0] objectForKey:@"Chapters"] count] == 0)
	{
		if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDVDThemeFormat"] intValue] == 0)
		xmlContent = [[@"<dvdauthor dest=\"" stringByAppendingString:@"../"] stringByAppendingString:@"\" jumppad=\"1\">\n<vmgm>\n<menus>\n<video format=\"pal\"></video>\n<pgc entry=\"title\">\n<vob file=\"Title Menu.mpg\"></vob>\n<button>jump titleset 1 title 1;</button>\n</pgc>\n</menus>\n</vmgm>\n<titleset>\n<menus>\n"];
		else
		xmlContent = [[@"<dvdauthor dest=\"" stringByAppendingString:@"../"] stringByAppendingString:@"\" jumppad=\"1\">\n<vmgm>\n<menus>\n<video format=\"pal\" aspect=\"16:9\"></video>\n<pgc entry=\"title\">\n<vob file=\"Title Menu.mpg\"></vob>\n<button>jump titleset 1 title 1;</button>\n</pgc>\n</menus>\n</vmgm>\n<titleset>\n<menus>\n<video format=\"pal\" aspect=\"16:9\"></video>\n"];
	}
	else
	{
		if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDVDThemeFormat"] intValue] == 0)
		xmlContent = [[@"<dvdauthor dest=\"" stringByAppendingString:@"../"] stringByAppendingString:@"\" jumppad=\"1\">\n<vmgm>\n<menus>\n<video format=\"pal\"></video>\n<pgc entry=\"title\">\n<vob file=\"Title Menu.mpg\"></vob>\n<button>jump titleset 1 title 1;</button>\n<button>jump titleset 1 menu entry root;</button>\n</pgc>\n</menus>\n</vmgm>\n<titleset>\n<menus>\n"];
		else
		xmlContent = [[@"<dvdauthor dest=\"" stringByAppendingString:@"../"] stringByAppendingString:@"\" jumppad=\"1\">\n<vmgm>\n<menus>\n<video format=\"pal\" aspect=\"16:9\"></video>\n<pgc entry=\"title\">\n<vob file=\"Title Menu.mpg\"></vob>\n<button>jump titleset 1 title 1;</button>\n<button>jump titleset 1 menu entry root;</button>\n</pgc>\n</menus>\n</vmgm>\n<titleset>\n<menus>\n<video format=\"pal\" aspect=\"16:9\"></video>\n"];
	}

	int number;
	if ([[theme objectForKey:@"KWSelectionMode"] intValue] != 2)
	number = [[theme objectForKey:@"KWSelectionImagesOnAPage"] intValue];
	else
	number = [[theme objectForKey:@"KWSelectionStringsOnAPage"] intValue];

int numberOfMenus = [fileArray count] / number;

	if ([fileArray count] - numberOfMenus * number > 0)
	numberOfMenus = numberOfMenus + 1;

int chapterMenu = numberOfMenus + 1;
int menuItem = 0;

	if ([fileArray count] == 1)
	{
	numberOfMenus = 0;
	chapterMenu = 1;
	}

	int i;
	for (i=0;i<numberOfMenus;i++)
	{
	menuItem = menuItem + 1;
	xmlContent = [xmlContent stringByAppendingString:@"<pgc>\n"];
	xmlContent = [xmlContent stringByAppendingString:[[@"<vob file=\"Title Selection " stringByAppendingString:[[NSNumber numberWithInt:i+1] stringValue]] stringByAppendingString:@".mpg\"></vob>\n"]];

		int o;
		for (o=0;o<number;o++)
		{
			if ([fileArray count] > i * number + o)
			{
				if ([[[fileArray objectAtIndex:o+1+i*number-1] objectForKey:@"Chapters"] count] > 0)
				{
				xmlContent = [xmlContent stringByAppendingString:[[@"<button>jump menu " stringByAppendingString:[[NSNumber numberWithInt:chapterMenu] stringValue]] stringByAppendingString:@";</button>\n"]];
				chapterMenu = chapterMenu + 1;
				}
				else
				{
				xmlContent = [xmlContent stringByAppendingString:[[@"<button>jump title " stringByAppendingString:[[NSNumber numberWithInt:o+1+i*number] stringValue]] stringByAppendingString:@";</button>\n"]];
				}
			}
		}
		if (i > 0)
		xmlContent = [xmlContent stringByAppendingString:[[@"<button>jump menu " stringByAppendingString:[[NSNumber numberWithInt:i] stringValue]] stringByAppendingString:@";</button>\n"]];

		if (i < numberOfMenus - 1)
		xmlContent = [xmlContent stringByAppendingString:[[@"<button>jump menu " stringByAppendingString:[[NSNumber numberWithInt:i+2] stringValue]] stringByAppendingString:@";</button>\n"]];

	xmlContent = [xmlContent stringByAppendingString:@"</pgc>\n"];
	}

	NSMutableArray *titlesWithChapters = [[NSMutableArray alloc] init];
	NSMutableArray *titlesWithChaptersNames = [[NSMutableArray alloc] init];
	for (i=0;i<[fileArray count];i++)
	{
		if ([[[fileArray objectAtIndex:i] objectForKey:@"Chapters"] count] > 0)
		{
		[titlesWithChapters addObject:[NSNumber numberWithInt:i]];
		[titlesWithChaptersNames addObject:[[[[fileArray objectAtIndex:i] objectForKey:@"Path"] lastPathComponent] stringByDeletingPathExtension]];
		}
	}
	
	if ([fileArray count] > 1)
	{
		for (i=0;i<[titlesWithChapters count];i++)
		{
		menuItem = menuItem + 1;
	
			if (i > 0)
			chapterMenu = chapterMenu + ([[[fileArray objectAtIndex:[[titlesWithChapters objectAtIndex:i-1] intValue]] objectForKey:@"Chapters"] count] / number);
	
		xmlContent = [xmlContent stringByAppendingString:@"<pgc>\n"];
		xmlContent = [xmlContent stringByAppendingString:[[@"<vob file=\"" stringByAppendingString:[[titlesWithChaptersNames objectAtIndex:i] stringByAppendingString:@".mpg"]] stringByAppendingString:@"\"></vob>\n"]];
		xmlContent = [xmlContent stringByAppendingString:[[@"<button>jump title " stringByAppendingString:[[NSNumber numberWithInt:[[titlesWithChapters objectAtIndex:i] intValue]+1] stringValue]] stringByAppendingString:@";</button>\n"]];
		xmlContent = [xmlContent stringByAppendingString:[[@"<button>jump menu " stringByAppendingString:[[NSNumber numberWithInt:chapterMenu] stringValue]] stringByAppendingString:@";</button>\n"]];
		chapterMenu = chapterMenu + 1;
		xmlContent = [xmlContent stringByAppendingString:@"</pgc>\n"];
		}
	}

	int chapterSelection = 1;
	for (i=0;i<[titlesWithChapters count];i++)
	{
	numberOfMenus = [[[fileArray objectAtIndex:[[titlesWithChapters objectAtIndex:i] intValue]] objectForKey:@"Chapters"] count] / number;

		if ([[[fileArray objectAtIndex:[[titlesWithChapters objectAtIndex:i] intValue]] objectForKey:@"Chapters"] count] - numberOfMenus * number > 0)
		numberOfMenus = numberOfMenus + 1;

		int y;
		for (y=0;y<numberOfMenus;y++)
		{
		menuItem = menuItem + 1;
		xmlContent = [xmlContent stringByAppendingString:@"<pgc>\n"];
		xmlContent = [xmlContent stringByAppendingString:[[@"<vob file=\"Chapter Selection " stringByAppendingString:[[NSNumber numberWithInt:chapterSelection] stringValue]] stringByAppendingString:@".mpg\"></vob>\n"]];
		chapterSelection = chapterSelection + 1;
		
			int o;
			for (o=0;o<number;o++)
			{
				int addNumber;
				if ([[[[[fileArray objectAtIndex:[[titlesWithChapters objectAtIndex:i] intValue]] objectForKey:@"Chapters"] objectAtIndex:0] objectForKey:@"RealTime"] intValue] == 0)
				addNumber = 1;
				else
				addNumber = 2;
			
				if ([[[fileArray objectAtIndex:[[titlesWithChapters objectAtIndex:i] intValue]] objectForKey:@"Chapters"] count] > y * number + o)
				xmlContent = [xmlContent stringByAppendingString:[[@"<button>jump title " stringByAppendingString:[[NSNumber numberWithInt:[[titlesWithChapters objectAtIndex:i] intValue]+1] stringValue]] stringByAppendingString:[[@" chapter " stringByAppendingString:[[NSNumber numberWithInt:y*number+o+addNumber] stringValue]] stringByAppendingString:@";</button>\n"]]];
			}
		
		if (y > 0)
		{
		xmlContent = [xmlContent stringByAppendingString:[[@"<button>jump menu " stringByAppendingString:[[NSNumber numberWithInt:menuItem-1] stringValue]] stringByAppendingString:@";</button>\n"]];
		}
		
		if (y < numberOfMenus - 1)
		{
		xmlContent = [xmlContent stringByAppendingString:[[@"<button>jump menu " stringByAppendingString:[[NSNumber numberWithInt:menuItem+1] stringValue]] stringByAppendingString:@";</button>\n"]];
		}
		
		xmlContent = [xmlContent stringByAppendingString:@"</pgc>\n"];
		}
	}
	
	xmlContent = [xmlContent stringByAppendingString:@"</menus>\n<titles>\n"];
	
	for (i=0;i<[fileArray count];i++)
	{
	xmlContent = [xmlContent stringByAppendingString:@"<pgc>\n"];
	xmlContent = [xmlContent stringByAppendingString:[[@"<vob file=\"" stringByAppendingString:[[fileArray objectAtIndex:i] objectForKey:@"Path"]] stringByAppendingString:@"\""]];
		if ([[[fileArray objectAtIndex:i] objectForKey:@"Chapters"] count] > 0)
		{
		xmlContent = [xmlContent stringByAppendingString:@" chapters=\"00:00:00,"];
			int x;
			for (x=0;x<[[[fileArray objectAtIndex:i] objectForKey:@"Chapters"] count];x++)
			{
			int time = [[[[[fileArray objectAtIndex:i] objectForKey:@"Chapters"] objectAtIndex:x] objectForKey:@"RealTime"] intValue];
				
				if (time > 0)
				{
				xmlContent = [xmlContent stringByAppendingString:[KWCommonMethods formatTime:[[[[[fileArray objectAtIndex:i] objectForKey:@"Chapters"] objectAtIndex:x] objectForKey:@"RealTime"] intValue]]];
					if (x+1 < [[[fileArray objectAtIndex:i] objectForKey:@"Chapters"] count])
					xmlContent = [xmlContent stringByAppendingString:@","];
					else
					xmlContent = [xmlContent stringByAppendingString:@"\""];
				}
			}
		}
		
	xmlContent = [xmlContent stringByAppendingString:@"></vob>\n"];
		if (i+1 < [fileArray count])
		xmlContent = [[[xmlContent stringByAppendingString:@"<post>jump title "] stringByAppendingString:[[NSNumber numberWithInt:i+2] stringValue]] stringByAppendingString:@";</post>"];
		else if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWLoopDVD"] == YES)
		xmlContent = [[xmlContent stringByAppendingString:@"<post>jump title 1"] stringByAppendingString:@";</post>"];
		else
		xmlContent = [xmlContent stringByAppendingString:@"<post>call vmgm menu;</post>"];
	xmlContent = [xmlContent stringByAppendingString:@"</pgc>\n"];
	}
	
	xmlContent = [xmlContent stringByAppendingString:@"</titles>\n</titleset>\n</dvdauthor>"];

[titlesWithChapters release];
[titlesWithChaptersNames release];

return [xmlContent writeToFile:path atomically:YES];
}

//Create DVD folders with dvdauthor
- (BOOL)authorDVDWithXMLFile:(NSString *)xmlFile withFileArray:(NSArray *)fileArray atPath:(NSString *)path
{
dvdauthor=[[NSTask alloc] init];
NSPipe *pipe=[[NSPipe alloc] init];
NSFileHandle *handle;
NSData *data;
BOOL returnCode;
[dvdauthor setLaunchPath:[[NSBundle mainBundle] pathForResource:@"dvdauthor" ofType:@""]];
[dvdauthor setCurrentDirectoryPath:[xmlFile stringByDeletingLastPathComponent]];

[dvdauthor setArguments:[NSArray arrayWithObjects:@"-x",xmlFile,nil]];
[dvdauthor setStandardError:pipe];
handle=[pipe fileHandleForReading];

float totalSize = 0;

	if ([[NSFileManager defaultManager] fileExistsAtPath:[path stringByAppendingPathComponent:@"THEME_TS"]])
	{
	totalSize = totalSize + [KWCommonMethods calculateRealFolderSize:[path stringByAppendingPathComponent:@"THEME_TS"]];
	}

	int i;
	for (i=0;i<[fileArray count];i++)
	{
	NSDictionary *attrib = [[NSFileManager defaultManager] fileAttributesAtPath:[[fileArray objectAtIndex:i] objectForKey:@"Path"] traverseLink:YES];
	totalSize = totalSize + ([[attrib objectForKey:NSFileSize] floatValue]);
	}

int currentFile = 1;
int currentProcces = 1;

[dvdauthor launch];

totalSize = totalSize / 1024 / 1024;

NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
NSString *string = nil;

	while([data=[handle availableData] length])
	{
	string=[[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];

		if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWDebug"] == YES)
		NSLog(string);

		if ([string rangeOfString:@"Processing /"].length > 0)
		{
		[[NSNotificationCenter defaultCenter] postNotificationName:@"KWStatusChanged" object:[[NSLocalizedString(@"Processing: ", Localized) stringByAppendingString:[[NSFileManager defaultManager] displayNameAtPath:[[[[string componentsSeparatedByString:@"Processing "] objectAtIndex:1] componentsSeparatedByString:@"..."] objectAtIndex:0]]] stringByAppendingString:[[[[@" (" stringByAppendingString:[[NSNumber numberWithInt:currentFile] stringValue]] stringByAppendingString:NSLocalizedString(@" of ", Localized)] stringByAppendingString:[[NSNumber numberWithInt:[fileArray count]] stringValue]] stringByAppendingString:@")"]]];
		currentFile = currentFile + 1;
		}
		
		if ([string rangeOfString:@"Generating VTS with the following video attributes"].length > 0)
		{
		[[NSNotificationCenter defaultCenter] postNotificationName:@"KWStatusChanged" object:NSLocalizedString(@"Generating DVD folder", Localized)];
		currentProcces = 2;
		}

		if ([string rangeOfString:@"MB"].length > 0 && [string rangeOfString:@"at "].length > 0)
		{
		float progressValue;

			if (currentProcces == 1)
			{
			progressValue = [[[[[string componentsSeparatedByString:@"MB"] objectAtIndex:0] componentsSeparatedByString:@"at "] objectAtIndex:1] floatValue] / totalSize * 100;
			[[NSNotificationCenter defaultCenter] postNotificationName:@"KWValueChanged" object:[NSNumber numberWithInt:(([progressSize floatValue] / 100)*progressValue)]];
			}
			else
			{
			progressValue = [[[[[string componentsSeparatedByString:@" "] objectAtIndex:[[string componentsSeparatedByString:@" "] count]-1] componentsSeparatedByString:@")"] objectAtIndex:0] floatValue];

				if (progressValue > 0 && progressValue < 101)
				{
				[[NSNotificationCenter defaultCenter] postNotificationName:@"KWValueChanged" object:[NSNumber numberWithInt:([progressSize floatValue])+(([progressSize floatValue] / 100)*progressValue)]];
				[[NSNotificationCenter defaultCenter] postNotificationName:@"KWStatusChanged" object:[[[NSLocalizedString(@"Generating DVD folder", Localized) stringByAppendingString:@": "] stringByAppendingString:[[NSNumber numberWithFloat:progressValue] stringValue]] stringByAppendingString:@"%"]];
				}
			}
		}

	[string release];
	string = nil;
	data = nil;
	[innerPool release];
	innerPool = [[NSAutoreleasePool alloc] init];
	}

[innerPool release];
[dvdauthor waitUntilExit];
	
returnCode = ([dvdauthor terminationStatus] == 0 && userCanceled == NO);
[pipe release];
[dvdauthor release];
dvdauthor = nil;

return returnCode;
}

///////////////////
// Theme actions //
///////////////////

#pragma mark -
#pragma mark •• Theme actions

//Create menu image with titles or chapters
- (NSImage *)rootMenuWithTitles:(BOOL)titles withName:(NSString *)name withSecondButton:(BOOL)secondButton
{
NSImage *newImage = nil;

	if (titles)
	newImage = [[[NSImage alloc] initWithData:[theme objectForKey:@"KWAltRootImage"]] autorelease];
	else
	newImage = [[[NSImage alloc] initWithData:[theme objectForKey:@"KWAltChapterImage"]] autorelease];

	if (!newImage)
	newImage = [[[NSImage alloc] initWithData:[theme objectForKey:@"KWDefaultImage"]] autorelease];
	
int y = [[theme objectForKey:@"KWStartButtonY"] intValue];

	if (titles)
	{
		if (![[theme objectForKey:@"KWDVDNameDisableText"] boolValue])
		[self drawString:name inRect:NSMakeRect([[theme objectForKey:@"KWDVDNameX"] intValue],[[theme objectForKey:@"KWDVDNameY"] intValue],[[theme objectForKey:@"KWDVDNameW"] intValue],[[theme objectForKey:@"KWDVDNameH"] intValue]) onImage:newImage withFontName:[theme objectForKey:@"KWDVDNameFont"] withSize:[[theme objectForKey:@"KWDVDNameFontSize"] intValue] withColor:(NSColor *)[NSUnarchiver unarchiveObjectWithData:[theme objectForKey:@"KWDVDNameFontColor"]] useAlignment:NSCenterTextAlignment];
	}
	else
	{
		if (![[theme objectForKey:@"KWVideoNameDisableText"] boolValue])
		[self drawString:name inRect:NSMakeRect([[theme objectForKey:@"KWVideoNameX"] intValue],[[theme objectForKey:@"KWVideoNameY"] intValue],[[theme objectForKey:@"KWVideoNameW"]  intValue],[[theme objectForKey:@"KWVideoNameH"]  intValue]) onImage:newImage withFontName:[theme objectForKey:@"KWVideoNameFont"] withSize:[[theme objectForKey:@"KWVideoNameFontSize"] intValue] withColor:(NSColor *)[NSUnarchiver unarchiveObjectWithData:[theme objectForKey:@"KWVideoNameFontColor"]] useAlignment:NSCenterTextAlignment];
	}
	
	if (![[theme objectForKey:@"KWStartButtonDisable"] boolValue])
	{
	NSImage *startButtonImage = [[[NSImage alloc] initWithData:[theme objectForKey:@"KWStartButtonImage"]] autorelease];
	NSRect rect = NSMakeRect([[theme objectForKey:@"KWStartButtonX"] intValue],y,[[theme objectForKey:@"KWStartButtonW"]  intValue],[[theme objectForKey:@"KWStartButtonH"] intValue]);

		if (!startButtonImage)
		[self drawString:[theme objectForKey:@"KWStartButtonString"] inRect:rect onImage:newImage withFontName:[theme objectForKey:@"KWStartButtonFont"] withSize:[[theme objectForKey:@"KWStartButtonFontSize"] intValue] withColor:(NSColor *)[NSUnarchiver unarchiveObjectWithData:[theme objectForKey:@"KWStartButtonFontColor"]] useAlignment:NSCenterTextAlignment];
		else
		[self drawImage:startButtonImage inRect:rect onImage:newImage];
	}

	//Draw titles if needed
	if (titles)
	{
		if (![[theme objectForKey:@"KWTitleButtonDisable"] boolValue] && secondButton)
		{
		NSImage *titleButonImage = [[[NSImage alloc] initWithData:[theme objectForKey:@"KWTitleButtonImage"]] autorelease];
		NSRect rect = NSMakeRect([[theme objectForKey:@"KWTitleButtonX"] intValue],[[theme objectForKey:@"KWTitleButtonY"] intValue],[[theme objectForKey:@"KWTitleButtonW"] intValue],[[theme objectForKey:@"KWTitleButtonH"] intValue]);

			if (!titleButonImage)
			[self drawString:[theme objectForKey:@"KWTitleButtonString"] inRect:rect onImage:newImage withFontName:[theme objectForKey:@"KWTitleButtonFont"] withSize:[[theme objectForKey:@"KWTitleButtonFontSize"] intValue] withColor:(NSColor *)[NSUnarchiver unarchiveObjectWithData:[theme objectForKey:@"KWTitleButtonFontColor"]] useAlignment:NSCenterTextAlignment];
			else
			[self drawImage:titleButonImage inRect:rect onImage:newImage];
		}
	}
	//Draw chapters if needed
	else
	{
		if (![[theme objectForKey:@"KWChapterButtonDisable"] boolValue])
		{
		NSImage *chapterButtonImage = [[[NSImage alloc] initWithData:[theme objectForKey:@"KWChapterButtonImage"]] autorelease];
		NSRect rect = NSMakeRect([[theme objectForKey:@"KWChapterButtonX"] intValue],[[theme objectForKey:@"KWChapterButtonY"] intValue],[[theme objectForKey:@"KWChapterButtonW"] intValue],[[theme objectForKey:@"KWChapterButtonH"] intValue]);

			if (!chapterButtonImage)
			[self drawString:[theme objectForKey:@"KWChapterButtonString"] inRect:rect onImage:newImage withFontName:[theme objectForKey:@"KWChapterButtonFont"] withSize:[[theme objectForKey:@"KWChapterButtonFontSize"] intValue] withColor:(NSColor *)[NSUnarchiver unarchiveObjectWithData:[theme objectForKey:@"KWChapterButtonFontColor"]] useAlignment:NSCenterTextAlignment];
			else
			[self drawImage:chapterButtonImage inRect:rect onImage:newImage];
		}
	}

	NSImage *overlay = nil;
	
		if (titles)
		overlay = [[[NSImage alloc] initWithData:[theme objectForKey:@"KWRootOverlayImage"]] autorelease];
		else
		overlay = [[[NSImage alloc] initWithData:[theme objectForKey:@"KWChapterOverlayImage"]] autorelease];

	if (overlay)
	[self drawImage:overlay inRect:NSMakeRect(0,0,[newImage size].width,[newImage size].height) onImage:newImage];

return [self resizeImage:newImage];
}

//Create menu image mask with titles or chapters
- (NSImage *)rootMaskWithTitles:(BOOL)titles withSecondButton:(BOOL)secondButton
{
NSImage *newImage = [[[NSImage alloc] initWithSize: NSMakeSize(720,576)] autorelease]; 
	
	float factor;
	if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDVDThemeFormat"] intValue] == 0)
	factor = 1;
	else
	factor = 1.5; 

int y = [[theme objectForKey:@"KWStartButtonMaskY"] intValue] * factor;

NSImage *startMaskButtonImage = [[[NSImage alloc] initWithData:[theme objectForKey:@"KWStartButtonMaskImage"]] autorelease];
NSRect rect = NSMakeRect([[theme objectForKey:@"KWStartButtonMaskX"] intValue],y-5,[[theme objectForKey:@"KWStartButtonMaskW"] intValue],[[theme objectForKey:@"KWStartButtonMaskH"] intValue] * factor);

	if (!startMaskButtonImage)
	[self drawBoxInRect:rect lineWidth:[[theme objectForKey:@"KWStartButtonMaskLineWidth"] intValue] onImage:newImage];
	else
	[self drawImage:startMaskButtonImage inRect:rect onImage:newImage];

	if (titles)
	{
		if (secondButton)
		{
		NSImage *titleMaskButtonImage = [[[NSImage alloc] initWithData:[theme objectForKey:@"KWTitleButtonMaskImage"]] autorelease];
		NSRect rect = NSMakeRect([[theme objectForKey:@"KWTitleButtonMaskX"] intValue],[[theme objectForKey:@"KWTitleButtonMaskY"] intValue] * factor,[[theme objectForKey:@"KWTitleButtonMaskW"] intValue],[[theme objectForKey:@"KWTitleButtonMaskH"] intValue] * factor);

			if (!titleMaskButtonImage)
			[self drawBoxInRect:rect lineWidth:[[theme objectForKey:@"KWTitleButtonMaskLineWidth"] intValue] onImage:newImage];
			else
			[self drawImage:titleMaskButtonImage inRect:rect onImage:newImage];
		}
	}
	else
	{
	NSImage *chapterMaskButtonImage = [[[NSImage alloc] initWithData:[theme objectForKey:@"KWChapterButtonMaskImage"]] autorelease];
	NSRect rect = NSMakeRect([[theme objectForKey:@"KWChapterButtonMaskX"] intValue],[[theme objectForKey:@"KWChapterButtonMaskY"] intValue] * factor,[[theme objectForKey:@"KWChapterButtonMaskW"] intValue],[[theme objectForKey:@"KWChapterButtonMaskH"] intValue] * factor);
	
		if (!chapterMaskButtonImage)
		[self drawBoxInRect:rect lineWidth:[[theme objectForKey:@"KWChapterButtonMaskLineWidth"] intValue] onImage:newImage];
		else
		[self drawImage:chapterMaskButtonImage inRect:rect onImage:newImage];
	}

return newImage;
}

//Create menu image
- (NSImage *)selectionMenuWithTitles:(BOOL)titles withObjects:(NSArray *)objects withImages:(NSArray *)images addNext:(BOOL)next addPrevious:(BOOL)previous
{
NSImage *newImage = nil;

	if (titles)
	newImage = [[[NSImage alloc] initWithData:[theme objectForKey:@"KWAltTitleSelectionImage"]] autorelease];
	else
	newImage = [[[NSImage alloc] initWithData:[theme objectForKey:@"KWAltChapterSelectionImage"]] autorelease];
	
	if (!newImage)
	newImage = [[[NSImage alloc] initWithData:[theme objectForKey:@"KWDefaultImage"]] autorelease];

int x;
int y;
int newRow = 0;
NSString *pageKey;

	if ([[theme objectForKey:@"KWSelectionMode"] intValue] == 2)
	pageKey = @"KWSelectionStringsOnAPage";
	else
	pageKey = @"KWSelectionImagesOnAPage";

	if ([[theme objectForKey:@"KWSelectionMode"] intValue] != 2)
	{
	x = [[theme objectForKey:@"KWSelectionImagesX"] intValue];
	y = [[theme objectForKey:@"KWSelectionImagesY"] intValue];
	}
	else
	{
		if ([[theme objectForKey:@"KWSelectionStringsX"] intValue] == -1)
		x = 0;
		else
		x = [[theme objectForKey:@"KWSelectionStringsX"] intValue];
	
		if ([[theme objectForKey:@"KWSelectionStringsY"] intValue] == -1)
		{
			if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDVDThemeFormat"] intValue] == 0)
			y = 576 - (576 - [objects count] * [[theme objectForKey:@"KWSelectionStringsSeperation"] intValue]) / 2;
			else
			y = 384 - (384 - [objects count] * [[theme objectForKey:@"KWSelectionStringsSeperation"] intValue]) / 2;
		}
		else
		{
		y = [[theme objectForKey:@"KWSelectionStringsY"] intValue];
		}
	}
	
	int i;
	for (i=0;i<[objects count];i++)
	{
		if ([[theme objectForKey:@"KWSelectionMode"] intValue] != 2)
		{
		NSImage *previewImage = [images objectAtIndex:i];
		float width;
		float height;
	
			if ([previewImage size].width / [previewImage size].height < 1)
			{
			height = [[theme objectForKey:@"KWSelectionImagesH"] intValue];
			width = [[theme objectForKey:@"KWSelectionImagesH"] intValue] * ([previewImage size].width / [previewImage size].height);
			}
			else
			{
				if ([[theme objectForKey:@"KWSelectionImagesW"] intValue] / ([previewImage size].width / [previewImage size].height) <= [[theme objectForKey:@"KWSelectionImagesH"] intValue])
				{
				width = [[theme objectForKey:@"KWSelectionImagesW"] intValue];
				height = [[theme objectForKey:@"KWSelectionImagesW"] intValue] / ([previewImage size].width / [previewImage size].height);
				}
				else
				{
				height = [[theme objectForKey:@"KWSelectionImagesH"] intValue];
				width = [[theme objectForKey:@"KWSelectionImagesH"] intValue] * ([previewImage size].width / [previewImage size].height);
				}
			}
		
		NSRect inputRect = NSMakeRect(0,0,[previewImage size].width,[previewImage size].height);
		[newImage lockFocus];
		[previewImage drawInRect:NSMakeRect(x + (([[theme objectForKey:@"KWSelectionImagesW"] intValue] - width) / 2),y + (([[theme objectForKey:@"KWSelectionImagesH"] intValue] - height) / 2),width,height) fromRect:inputRect operation:NSCompositeCopy fraction:1.0]; 
		[newImage unlockFocus];
		}
		
		if ([[theme objectForKey:@"KWSelectionMode"] intValue] == 0)
		{
		NSString *name;
		
			if (titles)
			name = [[[[objects objectAtIndex:i] objectForKey:@"Path"] lastPathComponent] stringByDeletingPathExtension];
			else
			name = [[objects objectAtIndex:i] objectForKey:@"Title"];

		[self drawString:name inRect:NSMakeRect(x,y-[[theme objectForKey:@"KWSelectionImagesH"] intValue],[[theme objectForKey:@"KWSelectionImagesW"] intValue],[[theme objectForKey:@"KWSelectionImagesH"] intValue]) onImage:newImage withFontName:[theme objectForKey:@"KWSelectionImagesFont"] withSize:[[theme objectForKey:@"KWSelectionImagesFontSize"] intValue] withColor:(NSColor *)[NSUnarchiver unarchiveObjectWithData:[theme objectForKey:@"KWSelectionImagesFontColor"]] useAlignment:NSCenterTextAlignment];
		}
		else if ([[theme objectForKey:@"KWSelectionMode"] intValue] == 2)
		{
		NSTextAlignment alignment;
			
			if ([[theme objectForKey:@"KWSelectionStringsX"] intValue] == -1)
			alignment = NSCenterTextAlignment;
			else
			alignment = NSLeftTextAlignment;
			
			NSString *name;
			if (titles)
			name = [[[[objects objectAtIndex:i] objectForKey:@"Path"] lastPathComponent] stringByDeletingPathExtension];
			else
			name = [[objects objectAtIndex:i] objectForKey:@"Title"];

		[self drawString:name inRect:NSMakeRect(x,y,[[theme objectForKey:@"KWSelectionStringsW"] intValue],[[theme objectForKey:@"KWSelectionStringsH"] intValue]) onImage:newImage withFontName:[theme objectForKey:@"KWSelectionStringsFont"] withSize:[[theme objectForKey:@"KWSelectionStringsFontSize"] intValue] withColor:(NSColor *)[NSUnarchiver unarchiveObjectWithData:[theme objectForKey:@"KWSelectionStringsFontColor"]] useAlignment:alignment];
		}
	
		if ([[theme objectForKey:@"KWSelectionMode"] intValue] != 2)
		{
		x = x + [[theme objectForKey:@"KWSelectionImagesSeperationW"] intValue];
		
			if (newRow == [[theme objectForKey:@"KWSelectionImagesOnARow"] intValue]-1)
			{
			y = y - [[theme objectForKey:@"KWSelectionImagesSeperationH"] intValue];
			x = [[theme objectForKey:@"KWSelectionImagesX"] intValue];
			newRow = 0;
			}
			else
			{
			newRow = newRow + 1;
			}
		
		}
		else
		{
		y = y - [[theme objectForKey:@"KWSelectionStringsSeperation"] intValue];
		}
	}
	
	if (![[theme objectForKey:@"KWPreviousButtonDisable"] boolValue] && previous)
	{
	NSImage *previousButtonImage = [[[NSImage alloc] initWithData:[theme objectForKey:@"KWPreviousButtonImage"]] autorelease];
	NSRect rect = NSMakeRect([[theme objectForKey:@"KWPreviousButtonX"] intValue],[[theme objectForKey:@"KWPreviousButtonY"] intValue],[[theme objectForKey:@"KWPreviousButtonW"] intValue],[[theme objectForKey:@"KWPreviousButtonH"] intValue]);

		if (!previousButtonImage)
		[self drawString:[theme objectForKey:@"KWPreviousButtonString"] inRect:rect onImage:newImage withFontName:[theme objectForKey:@"KWPreviousButtonFont"] withSize:[[theme objectForKey:@"KWPreviousButtonFontSize"] intValue] withColor:(NSColor *)[NSUnarchiver unarchiveObjectWithData:[theme objectForKey:@"KWPreviousButtonFontColor"]] useAlignment:NSCenterTextAlignment];
		else
		[self drawImage:previousButtonImage inRect:rect onImage:newImage];
	}

	if (![[theme objectForKey:@"KWNextButtonDisable"] boolValue] && next)
	{
	NSImage *nextButtonImage = [[[NSImage alloc] initWithData:[theme objectForKey:@"KWNextButtonImage"]] autorelease];
	NSRect rect = NSMakeRect([[theme objectForKey:@"KWNextButtonX"] intValue],[[theme objectForKey:@"KWNextButtonY"] intValue],[[theme objectForKey:@"KWNextButtonW"] intValue],[[theme objectForKey:@"KWNextButtonH"] intValue]);

		if (!nextButtonImage)
		[self drawString:[theme objectForKey:@"KWNextButtonString"] inRect:rect onImage:newImage withFontName:[theme objectForKey:@"KWNextButtonFont"] withSize:[[theme objectForKey:@"KWNextButtonFontSize"] intValue] withColor:(NSColor *)[NSUnarchiver unarchiveObjectWithData:[theme objectForKey:@"KWNextButtonFontColor"]] useAlignment:NSCenterTextAlignment];
		else
		[self drawImage:nextButtonImage inRect:rect onImage:newImage];
	}

	if (!titles)
	{
		if (![[theme objectForKey:@"KWChapterSelectionDisable"] boolValue])
		{
		NSImage *chapterSelectionButtonImage = [[[NSImage alloc] initWithData:[theme objectForKey:@"KWChapterSelectionImage"]] autorelease];
		NSRect rect = NSMakeRect([[theme objectForKey:@"KWChapterSelectionX"] intValue],[[theme objectForKey:@"KWChapterSelectionY"] intValue],[[theme objectForKey:@"KWChapterSelectionW"] intValue],[[theme objectForKey:@"KWChapterSelectionH"] intValue]);

			if (!chapterSelectionButtonImage)
			[self drawString:[theme objectForKey:@"KWChapterSelectionString"] inRect:rect onImage:newImage withFontName:[theme objectForKey:@"KWChapterSelectionFont"] withSize:[[theme objectForKey:@"KWChapterSelectionFontSize"] intValue] withColor:(NSColor *)[NSUnarchiver unarchiveObjectWithData:[theme objectForKey:@"KWChapterSelectionFontColor"]] useAlignment:NSCenterTextAlignment];
			else
			[self drawImage:chapterSelectionButtonImage inRect:rect onImage:newImage];
		}
	}
	else
	{
		if (![[theme objectForKey:@"KWTitleSelectionDisable"] boolValue])
		{
		NSImage *titleSelectionButtonImage = [[[NSImage alloc] initWithData:[theme objectForKey:@"KWTitleSelectionImage"]] autorelease];
		NSRect rect = NSMakeRect([[theme objectForKey:@"KWTitleSelectionX"] intValue],[[theme objectForKey:@"KWTitleSelectionY"] intValue],[[theme objectForKey:@"KWTitleSelectionW"] intValue],[[theme objectForKey:@"KWTitleSelectionH"] intValue]);

			if (!titleSelectionButtonImage)
			[self drawString:[theme objectForKey:@"KWTitleSelectionString"] inRect:rect onImage:newImage withFontName:[theme objectForKey:@"KWTitleSelectionFont"] withSize:[[theme objectForKey:@"KWTitleSelectionFontSize"] intValue] withColor:(NSColor *)[NSUnarchiver unarchiveObjectWithData:[theme objectForKey:@"KWTitleSelectionFontColor"]] useAlignment:NSCenterTextAlignment];
			else
			[self drawImage:titleSelectionButtonImage inRect:rect onImage:newImage];
		}
	}

	NSImage *overlay = nil;
	
		if (titles)
		overlay = [[[NSImage alloc] initWithData:[theme objectForKey:@"KWTitleSelectionOverlayImage"]] autorelease];
		else
		overlay = [[[NSImage alloc] initWithData:[theme objectForKey:@"KWChapterSelectionOverlayImage"]] autorelease];

	if (overlay)
	[self drawImage:overlay inRect:NSMakeRect(0,0,[newImage size].width,[newImage size].height) onImage:newImage];

return [self resizeImage:newImage];
}

//Create menu mask
- (NSImage *)selectionMaskWithTitles:(BOOL)titles withObjects:(NSArray *)objects addNext:(BOOL)next addPrevious:(BOOL)previous
{
NSImage *newImage;

	//if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDVDThemeFormat"] intValue] == 0)
	newImage = [[[NSImage alloc] initWithSize: NSMakeSize(720,576)] autorelease];
	//else
	//newImage = [[[NSImage alloc] initWithSize: NSMakeSize(720,384)] autorelease];
	
	float factor;
	if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDVDThemeFormat"] intValue] == 0)
	factor = 1;
	else
	factor = 1.5;
	
int newRow = 0;
int x;
int y;

NSString *pageKey;

	if ([[theme objectForKey:@"KWSelectionMode"] intValue] == 2)
	pageKey = @"KWSelectionStringsOnAPage";
	else
	pageKey = @"KWSelectionImagesOnAPage";

	if ([[theme objectForKey:@"KWSelectionMode"] intValue] != 2)
	{
	x = [[theme objectForKey:@"KWSelectionImagesMaskX"] intValue];
	y = [[theme objectForKey:@"KWSelectionImagesMaskY"] intValue] * factor;
	}
	else
	{
		if ([[theme objectForKey:@"KWSelectionStringsMaskX"] intValue] == -1)
		x = (720 - [[theme objectForKey:@"KWSelectionStringsMaskW"] intValue]) / 2;
		else
		x = [[theme objectForKey:@"KWSelectionStringsMaskX"] intValue];
	
		if ([[theme objectForKey:@"KWSelectionStringsMaskY"] intValue] == -1)
		{
			//if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDVDThemeFormat"] intValue] == 0)
			y = 576 - (576 - [objects count] * ([[theme objectForKey:@"KWSelectionStringsMaskSeperation"] intValue] * factor)) / 2;
			//else
			//y = 384 - (384 - [objects count] * ([[theme objectForKey:@"KWSelectionStringsMaskSeperation"] intValue] * factor)) / 2;
		}
		else
		{
		y = [[theme objectForKey:@"KWSelectionImagesMaskY"] intValue] * factor;
		}
	}
	
	int i;
	for (i=0;i<[objects count];i++)
	{
		if ([[theme objectForKey:@"KWSelectionMode"] intValue] == 2)
		{
		NSImage *selectionStringsMaskButtonImage  = [[[NSImage alloc] initWithData:[theme objectForKey:@"KWSelectionStringsImage"]] autorelease];
		NSRect rect = NSMakeRect(x,y,[[theme objectForKey:@"KWSelectionStringsMaskW"] intValue],[[theme objectForKey:@"KWSelectionStringsMaskH"] intValue] * factor);
		
			if (!selectionStringsMaskButtonImage)
			[self drawBoxInRect:rect lineWidth:[[theme objectForKey:@"KWSelectionStringsMaskLineWidth"] intValue] onImage:newImage];
			else
			[self drawImage:selectionStringsMaskButtonImage inRect:rect onImage:newImage];
		}
		else
		{
		NSImage *selectionImageMaskButtonImage = [[[NSImage alloc] initWithData:[theme objectForKey:@"KWSelectionImagesImage"]] autorelease];
		NSRect rect = NSMakeRect(x,y,[[theme objectForKey:@"KWSelectionImagesMaskW"] intValue],[[theme objectForKey:@"KWSelectionImagesMaskH"] intValue] * factor);
		
			if (!selectionImageMaskButtonImage)
			[self drawBoxInRect:rect lineWidth:[[theme objectForKey:@"KWSelectionImagesMaskLineWidth"] intValue] onImage:newImage];
			else
			[self drawImage:selectionImageMaskButtonImage inRect:rect onImage:newImage];
		}
	
		if ([[theme objectForKey:@"KWSelectionMode"] intValue] != 2)
		{
		x = x + [[theme objectForKey:@"KWSelectionImagesMaskSeperationW"] intValue];
	
			if (newRow == [[theme objectForKey:@"KWSelectionImagesOnARow"] intValue]-1)
			{
			y = y - [[theme objectForKey:@"KWSelectionImagesMaskSeperationH"] intValue] * factor;
			x = [[theme objectForKey:@"KWSelectionImagesMaskX"] intValue];
			newRow = 0;
			}
			else
			{
			newRow = newRow + 1;
			}
		}
		else
		{
		y = y - [[theme objectForKey:@"KWSelectionStringsMaskSeperation"] intValue] * factor;
		}
	}
	
		if (previous)
		{
		NSImage *previousMaskButtonImage = [[[NSImage alloc] initWithData:[theme objectForKey:@"KWPreviousButtonMaskImage"]] autorelease];
		NSRect rect = NSMakeRect([[theme objectForKey:@"KWPreviousButtonMaskX"] intValue],[[theme objectForKey:@"KWPreviousButtonMaskY"] intValue] * factor,[[theme objectForKey:@"KWPreviousButtonMaskW"] intValue],[[theme objectForKey:@"KWPreviousButtonMaskH"] intValue] * factor);
	
			if (!previousMaskButtonImage)
			[self drawBoxInRect:rect lineWidth:[[theme objectForKey:@"KWPreviousButtonMaskLineWidth"] intValue] onImage:newImage];
			else
			[self drawImage:previousMaskButtonImage inRect:rect onImage:newImage];
		}
	
		if (next)
		{
		NSImage *nextMaskButtonImage = [[[NSImage alloc] initWithData:[theme objectForKey:@"KWNextButtonMaskImage"]] autorelease];
		NSRect rect = NSMakeRect([[theme objectForKey:@"KWNextButtonMaskX"] intValue],[[theme objectForKey:@"KWNextButtonMaskY"] intValue] * factor,[[theme objectForKey:@"KWNextButtonMaskW"] intValue],[[theme objectForKey:@"KWNextButtonMaskH"] intValue] * factor);
	
			if (!nextMaskButtonImage)
			[self drawBoxInRect:rect lineWidth:[[theme objectForKey:@"KWNextButtonMaskLineWidth"] intValue] onImage:newImage];
			else
			[self drawImage:nextMaskButtonImage inRect:rect onImage:newImage];
		}
		
return newImage;
}

///////////////////
// Other Actions //
///////////////////

#pragma mark -
#pragma mark •• Other actions

- (NSImage *)getPreviewImageFromTheme:(NSDictionary *)currentTheme ofType:(int)type
{
theme = currentTheme;
NSImage *image;

	if (type == 0)
	{
	image = [self rootMenuWithTitles:YES withName:NSLocalizedString(@"Title Menu",@"Localized") withSecondButton:YES];
	}
	else if (type == 1)
	{
	image = [self rootMenuWithTitles:NO withName:NSLocalizedString(@"Chapter Menu",@"Localized") withSecondButton:YES];
	}
	else if (type == 2 | type == 3)
	{
		int number;
		if ([[currentTheme objectForKey:@"KWSelectionMode"] intValue] != 2)
		number = [[currentTheme objectForKey:@"KWSelectionImagesOnAPage"] intValue];
		else
		number = [[currentTheme objectForKey:@"KWSelectionStringsOnAPage"] intValue];
	
		NSMutableArray *images = [NSMutableArray array];
		NSMutableArray *nameArray = [NSMutableArray array];
	
		int i;
		for (i=0;i<number;i++)
		{
		NSMutableDictionary *nameDict = [NSMutableDictionary dictionary];
	
		[images addObject:[self previewImage]];
	
		NSString *name = NSLocalizedString(@"Preview",@"Localized");
	
			if (type == 2)
			[nameDict setObject:name forKey:@"Path"];
			else
			[nameDict setObject:name forKey:@"Title"];
	
		[nameArray addObject:nameDict];
		}

		if (type == 2)
		image = [self selectionMenuWithTitles:YES withObjects:nameArray withImages:images addNext:YES addPrevious:YES];
		else
		image = [self selectionMenuWithTitles:NO withObjects:nameArray withImages:images addNext:YES addPrevious:YES];
	}
	
	if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDVDThemeFormat"] intValue] == 1)
	{
	[image setScalesWhenResized:YES];
	[image setSize:NSMakeSize(720,404)];
	}
	
return image;	
}

- (NSImage *)previewImage
{
NSImage *newImage = [[[NSImage alloc] initWithSize: NSMakeSize(320,240)] autorelease];

[newImage lockFocus];
[[NSColor whiteColor] set];
NSBezierPath *path;
path = [NSBezierPath bezierPathWithRect:NSMakeRect(0,0,320,240)];
[path fill];
[[NSImage imageNamed:@"Theme document"] drawInRect:NSMakeRect(96,56,128,128) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
[newImage unlockFocus];

return newImage;
}

- (void)drawString:(NSString *)string inRect:(NSRect)rect onImage:(NSImage *)image withFontName:(NSString *)fontName withSize:(int)size withColor:(NSColor *)color useAlignment:(NSTextAlignment)alignment
{
NSFont *labelFont = [NSFont fontWithName:fontName size:size];
NSMutableParagraphStyle *centeredStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
[centeredStyle setAlignment:alignment];
NSDictionary *attsDict = [NSDictionary dictionaryWithObjectsAndKeys:centeredStyle, NSParagraphStyleAttributeName,color, NSForegroundColorAttributeName, labelFont, NSFontAttributeName, [NSNumber numberWithInt:NSNoUnderlineStyle], NSUnderlineStyleAttributeName, nil];
[centeredStyle release];
centeredStyle = nil;
		
[image lockFocus];
[string drawInRect:rect withAttributes:attsDict]; 
[image unlockFocus];
}

- (void)drawBoxInRect:(NSRect)rect lineWidth:(int)width onImage:(NSImage *)image
{
[image lockFocus];
[[NSGraphicsContext currentContext] setShouldAntialias:NO];
[[NSColor whiteColor] set];
NSBezierPath *path = [NSBezierPath bezierPathWithRect:rect];
[path setLineWidth:width]; 
[path stroke];
[image unlockFocus];
}

- (void)drawImage:(NSImage *)drawImage inRect:(NSRect)rect onImage:(NSImage *)image
{
[image lockFocus];
[drawImage drawInRect:rect fromRect:NSZeroRect operation:NSCompositeHighlight fraction:1.0];
[image unlockFocus];
}

- (BOOL)saveImage:(NSImage *)image toPath:(NSString *)path
{
NSData *tiffData = [image TIFFRepresentation];
NSBitmapImageRep *bitmap = [NSBitmapImageRep imageRepWithData:tiffData];
return [[bitmap representationUsingType:NSPNGFileType properties:nil] writeToFile:path atomically:YES];
}

- (NSImage *)resizeImage:(NSImage *)image
{
NSImage *resizedImage = [[[NSImage alloc] initWithSize: NSMakeSize(720, 576)] autorelease];

NSSize originalSize = [image size];

[resizedImage lockFocus];
[image drawInRect: NSMakeRect(0, 0, 720, 576) fromRect: NSMakeRect(0, 0, originalSize.width, originalSize.height) operation:NSCompositeSourceOver fraction: 1.0];
[resizedImage unlockFocus];

return resizedImage;
}

@end