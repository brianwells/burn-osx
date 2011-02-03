//
//  KWDVDAuthorizer.m
//  KWDVDAuthorizer
//
//  Created by Maarten Foukhar on 16-3-07.
//  Copyright 2009 Kiwi Fruitware. All rights reserved.
//

#import "KWDVDAuthorizer.h"
#import "KWConverter.h"

@implementation KWDVDAuthorizer

- (id) init
{
	self = [super init];

	userCanceled = NO;
	
	NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
	[defaultCenter addObserver:self selector:@selector(cancelAuthoring) name:@"KWCancelAuthoring" object:nil];
	[defaultCenter postNotificationName:@"KWCancelNotificationChanged" object:@"KWCancelAuthoring"];
	
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

- (NSInteger)createStandardDVDFolderAtPath:(NSString *)path withFileArray:(NSArray *)fileArray withSize:(NSNumber *)size errorString:(NSString **)error
{
	BOOL result;

	result = [KWCommonMethods createDirectoryAtPath:path errorString:&*error];

	//Create a xml file with chapters if there are any
	if (result)
		[self createStandardDVDXMLAtPath:path withFileArray:fileArray errorString:&*error];

	progressSize = size;

	//Author the DVD
	
	if (result)
		result = [self authorDVDWithXMLFile:[path stringByAppendingPathComponent:@"dvdauthor.xml"] withFileArray:fileArray atPath:path errorString:&*error];
	
	NSInteger succes = 0;

	if (result == NO)
	{
		if (userCanceled)
			succes = 2;
		else
			succes = 1;
	}

	[KWCommonMethods removeItemAtPath:[path stringByAppendingPathComponent:@"dvdauthor.xml"]];
	
	//Create TOC (Table Of Contents)
	if (succes == 0)
	{
		NSArray *arguments = [NSArray arrayWithObjects:@"-T", @"-o", path, nil];
		BOOL status = [KWCommonMethods launchNSTaskAtPath:[[NSBundle mainBundle] pathForResource:@"dvdauthor" ofType:@""] withArguments:arguments outputError:YES outputString:YES output:&*error];

		if (!status)
			succes = 1;
	}

	if (succes == 0)
	{
		return 0;
	}
	else
	{
		[KWCommonMethods removeItemAtPath:path];
	
		if (userCanceled)
			return 2;
		else
			return 1;
	}
}

- (void)createStandardDVDXMLAtPath:(NSString *)path withFileArray:(NSArray *)fileArray errorString:(NSString **)error
{
	NSString *xmlFile = [NSString stringWithFormat:@"<dvdauthor dest=\"%@\">\n<titleset>\n<titles>", path];
	
	NSInteger x;
	for (x = 0; x < [fileArray count]; x ++)
	{
		NSDictionary *fileDictionary = [fileArray objectAtIndex:x];
		NSString *path = [fileDictionary objectForKey:@"Path"];
		
		xmlFile = [NSString stringWithFormat:@"%@\n<pgc>\n<vob file=\"%@\"", xmlFile, path];
		
		NSArray *chapters = [fileDictionary objectForKey:@"Chapters"];
		if ([chapters count] > 0)
		{
			xmlFile = [NSString stringWithFormat:@"%@ chapters=\"00:00:00,", xmlFile];
		
			NSInteger i;
			for (i = 0; i < [chapters count]; i ++)
			{
				NSDictionary *chapterDictionary = [chapters objectAtIndex:i];
				CGFloat time = [[chapterDictionary objectForKey:@"RealTime"] cgfloatValue];
				
				if (time > 0)
				{
					NSString *endString;
					if (i + 1 < [chapters count])
						endString = @",";
					else
						endString = @"\"";
					
					xmlFile = [NSString stringWithFormat:@"%@%@%@", xmlFile, [KWCommonMethods formatTime:time withFrames:YES], endString];
				}
			}
		}
		
		xmlFile = [NSString stringWithFormat:@"%@/>", xmlFile];
		
		if (x < [fileArray count] - 1)
			xmlFile = [NSString stringWithFormat:@"%@\n<post>jump title %i;</post>\n</pgc>", xmlFile, x + 2];
	}
	
	NSString *loopString;
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWLoopDVD"])
		loopString = @"<post>jump title 1;</post>\n";
	else
		loopString = @"<post>exit;</post>\n";
	
	xmlFile = [NSString stringWithFormat:@"%@%@</pgc>\n</titles>\n</titleset>\n</dvdauthor>", xmlFile, loopString];

	[KWCommonMethods writeString:xmlFile toFile:[path stringByAppendingPathComponent:@"dvdauthor.xml"] errorString:&*error];
}

///////////////
// DVD-Audio //
///////////////

#pragma mark -
#pragma mark •• DVD-Audio

- (NSInteger)createStandardDVDAudioFolderAtPath:(NSString *)path withFiles:(NSArray *)files errorString:(NSString **)error
{
	NSFileManager *defaultManager = [NSFileManager defaultManager];
	fileSize = 0;
	
		NSInteger i;
		for (i = 0; i < [files count]; i ++)
		{
			fileSize = fileSize + [[[defaultManager fileAttributesAtPath:[files objectAtIndex:i] traverseLink:YES] objectForKey:NSFileSize] cgfloatValue] / 2048;
		}
		
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWMaximumValueChanged" object:[NSNumber numberWithCGFloat:fileSize]];
	
	NSPipe *pipe =[ [NSPipe alloc] init];
	NSFileHandle *handle;
	dvdauthor = [[NSTask alloc] init];
	[dvdauthor setLaunchPath:[[NSBundle mainBundle] pathForResource:@"dvda-author" ofType:@""]];
	NSMutableArray *options = [NSMutableArray arrayWithObjects:@"-p", @"278", @"-o", path, @"-g", nil];
	[options addObjectsFromArray:files];
	[options addObject:@"-P0"];
	[dvdauthor setArguments:options];
	[dvdauthor setStandardOutput:pipe];
	handle = [pipe fileHandleForReading];

	[self performSelectorOnMainThread:@selector(startTimer:) withObject:[path stringByAppendingPathComponent:@"AUDIO_TS/ATS_01_1.AOB"] waitUntilDone:NO];

	if ([defaultManager fileExistsAtPath:path])
		[KWCommonMethods removeItemAtPath:path];
	
	[KWCommonMethods logCommandIfNeeded:dvdauthor];
	[dvdauthor launch];
	NSString *string = [[[NSString alloc] initWithData:[handle readDataToEndOfFile] encoding:NSUTF8StringEncoding] autorelease];
	
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWDebug"])
		NSLog(@"%@", string);
		
	[dvdauthor waitUntilExit];
	[timer invalidate];

	NSInteger taskStatus = [dvdauthor terminationStatus];
	
	[pipe release];
	pipe = nil;
	
	[dvdauthor release];
	dvdauthor = nil;

	if (taskStatus == 0)
	{
		return 0;
	}
	else
	{
		[KWCommonMethods removeItemAtPath:path];
	
		if (userCanceled)
		{
			return 2;
		}
		else
		{
			if (![string isEqualTo:@""])
				*error = string;
				
			return 1;
		}
	}
}

- (void)startTimer:(NSArray *)object
{
	timer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(imageProgress:) userInfo:object repeats:YES];
}

- (void)imageProgress:(NSTimer *)theTimer
{
	NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];

	CGFloat currentSize = [[[[NSFileManager defaultManager] fileAttributesAtPath:[theTimer userInfo] traverseLink:YES] objectForKey:NSFileSize] cgfloatValue] / 2048;
	CGFloat percent = currentSize / fileSize * 100;
		
		if (percent < 101)
		[defaultCenter postNotificationName:@"KWStatusByAddingPercentChanged" object:[NSString stringWithFormat:@" (%.0f%@)", percent, @"%"]];

	[defaultCenter postNotificationName:@"KWValueChanged" object:[NSNumber numberWithCGFloat:currentSize]];
}

/////////////////////////
// DVD-Video with menu //
/////////////////////////

#pragma mark -
#pragma mark •• DVD-Video with menu

//Create a menu with given files and chapters
- (NSInteger)createDVDMenuFiles:(NSString *)path withTheme:(NSDictionary *)currentTheme withFileArray:(NSArray *)fileArray withSize:(NSNumber *)size withName:(NSString *)name errorString:(NSString **)error
{
	NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
	NSString *themeFolderPath = [path stringByAppendingPathComponent:@"THEME_TS"];
	NSString *dvdXMLPath = [themeFolderPath stringByAppendingPathComponent:@"dvdauthor.xml"];
	progressSize = size;

	//Set value for our progress panel
	[defaultCenter postNotificationName:@"KWValueChanged" object:[NSNumber numberWithDouble:-1]];
	[defaultCenter postNotificationName:@"KWStatusChanged" object:NSLocalizedString(@"Creating DVD Theme", Localized)];

	//Load theme
	theme = currentTheme;

	BOOL succes = YES;

	//Create temp folders
	succes = [KWCommonMethods createDirectoryAtPath:path errorString:&*error];
	
	if (succes)
		succes = [KWCommonMethods createDirectoryAtPath:themeFolderPath errorString:&*error];
	
	if ([fileArray count] == 1 && [[[fileArray objectAtIndex:0] objectForKey:@"Chapters"] count] > 0)
	{
		//Create Chapter Root Menu
		if (succes)
			succes = [self createRootMenu:themeFolderPath withName:name withTitles:NO withSecondButton:YES errorString:&*error];
		
		//Create Chapter Selection Menu(s)
		if (succes)
			succes = [self createSelectionMenus:fileArray withChapters:YES atPath:themeFolderPath errorString:&*error];
	}
	else
	{
		//Create Root Menu
		if (succes)
			succes = [self createRootMenu:themeFolderPath withName:name withTitles:YES withSecondButton:([fileArray count] > 1) errorString:&*error];
		
		//Create Title Selection Menu(s)
		if (succes)
			succes = [self createSelectionMenus:fileArray withChapters:NO atPath:themeFolderPath errorString:&*error];
		
		//Create Chapter Menu
		if (succes)
			succes = [self createChapterMenus:themeFolderPath withFileArray:fileArray errorString:&*error];
		
		//Create Chapter Selection Menu(s)
		if (succes)
			succes = [self createSelectionMenus:fileArray withChapters:YES atPath:themeFolderPath errorString:&*error];
	}
	
	NSLog(@"Variables: %@", *error);
	
	//Create dvdauthor XML file
	if (succes)
		succes = [self createDVDXMLAtPath:dvdXMLPath withFileArray:fileArray atFolderPath:path errorString:&*error];
	
	NSLog(@"Variables: %@", *error);
	//Author DVD
	if (succes)
		succes = [self authorDVDWithXMLFile:dvdXMLPath withFileArray:fileArray atPath:path errorString:&*error];
	
	if (!succes)
	{
		if (userCanceled)
			return 2;
		else
			return 1;
	}

	[KWCommonMethods removeItemAtPath:themeFolderPath];

	return 0;
}

//////////////////
// Main actions //
//////////////////

#pragma mark -
#pragma mark •• Main actions

//Create root menu (Start and Titles)
- (BOOL)createRootMenu:(NSString *)path withName:(NSString *)name withTitles:(BOOL)titles withSecondButton:(BOOL)secondButton errorString:(NSString **)error
{
	BOOL succes;

	//Create Images
	NSImage *image = [self rootMenuWithTitles:titles withName:name withSecondButton:secondButton];
	NSImage *mask = [self rootMaskWithTitles:titles withSecondButton:secondButton];
		
	//Save mask as png
	succes = [KWCommonMethods saveImage:mask toPath:[path stringByAppendingPathComponent:@"Mask.png"] errorString:&*error];

	//Create mpg with menu in it
	if (succes)
		succes = [self createDVDMenuFile:[path stringByAppendingPathComponent:@"Title Menu.mpg"] withImage:image withMaskFile:[path stringByAppendingPathComponent:@"Mask.png"] errorString:&*error];
	
	if (!succes && *error == nil)
		*error = @"Failed to create root menu";
	
	return succes;
}

//Batch create title selection menus
- (BOOL)createSelectionMenus:(NSArray *)fileArray withChapters:(BOOL)chapters atPath:(NSString *)path errorString:(NSString **)error
{
	BOOL succes = YES;
	NSInteger menuSeries = 1;
	NSInteger numberOfpages = 0;
	NSMutableArray *titlesWithChapters = [[NSMutableArray alloc] init];
	NSMutableArray *indexes = [[NSMutableArray alloc] init];
	NSArray *objects = fileArray;

	if (chapters)
	{
		NSInteger i;
		for (i = 0; i < [fileArray count]; i ++)
		{
			NSArray *chapters = [[fileArray objectAtIndex:i] objectForKey:@"Chapters"];
			
			if ([chapters count] > 0)
			{
				[titlesWithChapters addObject:chapters];
				[indexes addObject:[NSNumber numberWithInteger:i]];
			}
		}

		objects = titlesWithChapters;
		menuSeries = [titlesWithChapters count];
	}

	NSInteger x;
	for (x = 0; x < menuSeries; x ++)
	{
		NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];

		if (chapters)
			objects = [titlesWithChapters objectAtIndex:x];

		NSMutableArray *images = [[NSMutableArray alloc] init];

		NSInteger i;
		for (i = 0; i < [objects count]; i ++)
		{
			NSDictionary *currentObject = [objects objectAtIndex:i];
			NSString *currentPath = [currentObject objectForKey:@"Path"];
			BOOL widescreen = [[currentObject objectForKey:@"WideScreen"] boolValue];
			NSImage *image;

			if (chapters)
			{
				image = [[[NSImage alloc] initWithData:[currentObject objectForKey:@"Image"]] autorelease];
			}
			else
			{
				image = [KWConverter getImageAtPath:currentPath atTime:[[theme objectForKey:@"KWScreenshotAtTime"] integerValue] isWideScreen:widescreen];
				
				//Too short movie
				if (!image)
					image = [KWConverter getImageAtPath:currentPath atTime:0 isWideScreen:widescreen];
			}
			
			[images addObject:image];
		}

		//create the menu's and masks
		NSString *outputName;
		if (chapters)
			outputName = @"Chapter Selection ";
		else
			outputName = @"Title Selection ";

		NSInteger number;
		if ([[theme objectForKey:@"KWSelectionMode"] integerValue] != 2)
			number = [[theme objectForKey:@"KWSelectionImagesOnAPage"] integerValue];
		else
			number = [[theme objectForKey:@"KWSelectionStringsOnAPage"] integerValue];

		NSInteger pages = [objects count] / number;

		if ([objects count] > number * pages)
			pages = pages + 1;

		NSRange firstRange;
		NSImage *image;
		NSImage *mask;

		if (pages > 1)
		{
			//Create first page range
			firstRange = NSMakeRange(0,number);

			NSInteger i;
			for (i = 1; i < pages - 1; i ++)
			{
				if (succes)
				{
					NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];

					NSRange range = NSMakeRange(number * i,number);
					NSArray *objectSubArray = [objects subarrayWithRange:range];
					image = [self selectionMenuWithTitles:(!chapters) withObjects:objectSubArray withImages:[images subarrayWithRange:range] addNext:YES addPrevious:YES];
					mask = [self selectionMaskWithTitles:(!chapters) withObjects:objectSubArray addNext:YES addPrevious:YES];
					succes = [KWCommonMethods saveImage:mask toPath:[path stringByAppendingPathComponent:@"Mask.png"] errorString:&*error];
				
					if (succes)
						succes = [self createDVDMenuFile:[[[path stringByAppendingPathComponent:outputName] stringByAppendingString:[[NSNumber numberWithInteger:i + 1 + numberOfpages] stringValue]] stringByAppendingString:@".mpg"] withImage:image withMaskFile:[path stringByAppendingPathComponent:@"Mask.png"] errorString:&*error];
				
					[innerPool release];
					innerPool = nil;
				}
			}

			if (succes)
			{
				NSRange range = NSMakeRange((pages - 1) * number,[objects count] - (pages - 1) * number);
				NSArray *objectSubArray = [objects subarrayWithRange:range];
				image = [self selectionMenuWithTitles:(!chapters) withObjects:objectSubArray withImages:[images subarrayWithRange:range] addNext:NO addPrevious:YES];
				mask = [self selectionMaskWithTitles:(!chapters) withObjects:objectSubArray addNext:NO addPrevious:YES];
				succes = [KWCommonMethods saveImage:mask toPath:[path stringByAppendingPathComponent:@"Mask.png"] errorString:&*error];
			
				if (succes)
					succes = [self createDVDMenuFile:[[[path stringByAppendingPathComponent:outputName] stringByAppendingString:[[NSNumber numberWithInteger:pages + numberOfpages] stringValue]] stringByAppendingString:@".mpg"] withImage:image withMaskFile:[path stringByAppendingPathComponent:@"Mask.png"] errorString:&*error];
			}
		}
		else
		{
			firstRange = NSMakeRange(0,[objects count]);
		}

		if (succes)
		{
			NSArray *objectSubArray = [objects subarrayWithRange:firstRange];
			image = [self selectionMenuWithTitles:(!chapters) withObjects:objectSubArray withImages:[images subarrayWithRange:firstRange] addNext:([objects count] > number) addPrevious:NO];
			mask = [self selectionMaskWithTitles:(!chapters) withObjects:objectSubArray addNext:([objects count] > number) addPrevious:NO];
			succes = [KWCommonMethods saveImage:mask toPath:[path stringByAppendingPathComponent:@"Mask.png"] errorString:&*error];
		
			if (succes)
				succes = [self createDVDMenuFile:[path stringByAppendingPathComponent:[[outputName stringByAppendingString:[[NSNumber numberWithInteger:1 + numberOfpages] stringValue]] stringByAppendingString:@".mpg"]] withImage:image withMaskFile:[path stringByAppendingPathComponent:@"Mask.png"] errorString:&*error];
		}

		numberOfpages = numberOfpages + pages;
		
		[images release];
		images = nil;
	
		[innerPool release];
	}
	
	[titlesWithChapters release];
	titlesWithChapters = nil;
	
	[indexes release];
	indexes = nil;
	
	if (!succes && !*error)
		*error = @"Failed to create selection menus";

	return succes;
}

//Create a chapter menu (Start and Chapters)
- (BOOL)createChapterMenus:(NSString *)path withFileArray:(NSArray *)fileArray errorString:(NSString **)error
{
	BOOL succes = YES;

	//Check if there are any chapters
	NSInteger i;
	for (i = 0; i < [fileArray count]; i ++)
	{
		NSDictionary *fileDictionary = [fileArray objectAtIndex:i];
	
		if ([[fileDictionary objectForKey:@"Chapters"] count] > 0)
		{
			NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
		
			NSString *name = [[[fileDictionary objectForKey:@"Path"] lastPathComponent] stringByDeletingPathExtension];

			//Create Images
			NSImage *image = [self rootMenuWithTitles:NO withName:name withSecondButton:YES];
			NSImage *mask = [self rootMaskWithTitles:NO withSecondButton:YES];
		
			//Save mask as png
			succes = [KWCommonMethods saveImage:mask toPath:[path stringByAppendingPathComponent:@"Mask.png"] errorString:&*error];

			//Create mpg with menu in it
			if (succes)
				succes = [self createDVDMenuFile:[path stringByAppendingPathComponent:[name stringByAppendingString:@".mpg"]] withImage:image withMaskFile:[path stringByAppendingPathComponent:@"Mask.png"] errorString:&*error];
		
			[innerPool release];
		}
	}
	
	if (!succes && !*error)
		*error = @"Failed to create chapter menus";
	
	return succes;
}

/////////////////
// DVD actions //
/////////////////

#pragma mark -
#pragma mark •• DVD actions

- (BOOL)createDVDMenuFile:(NSString *)path withImage:(NSImage *)image withMaskFile:(NSString *)maskFile errorString:(NSString **)error
{
	NSString *xmlFile = [NSString stringWithFormat:@"<subpictures>\n<stream>\n<spu\nforce=\"yes\"\nstart=\"00:00:00.00\" end=\"00:00:00.00\"\nhighlight=\"%@\"\nautooutline=\"infer\"\noutlinewidth=\"6\"\nautoorder=\"rows\"\n>\n</spu>\n</stream>\n</subpictures>", [maskFile lastPathComponent]];
	BOOL succes = [KWCommonMethods writeString:xmlFile toFile:[[path stringByDeletingPathExtension] stringByAppendingPathExtension:@"xml"] errorString:&*error];
	
	if (succes)
	{
		NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
		NSPipe *pipe = [[NSPipe alloc] init];
		NSPipe *pipe2 = [[NSPipe alloc] init];
		NSFileHandle *myHandle = [pipe fileHandleForWriting];
		NSFileHandle *myHandle2 = [pipe2 fileHandleForReading];
		ffmpeg = [[NSTask alloc] init];
		NSString *format;
	
		if ([[standardUserDefaults objectForKey:@"KWDefaultRegion"] integerValue] == 0)
			format = @"pal-dvd";
		else
			format = @"ntsc-dvd";

		[ffmpeg setLaunchPath:[KWCommonMethods ffmpegPath]];
		
		NSString *threads = [[standardUserDefaults objectForKey:@"KWEncodingThreads"] stringValue];
		
		NSArray *arguments;
		if ([[standardUserDefaults objectForKey:@"KWDVDThemeFormat"] integerValue] == 0)
			arguments = [NSArray arrayWithObjects:@"-shortest", @"-f", @"image2pipe", @"-threads", threads, @"-i", @"pipe:.jpg", @"-f", @"s16le", @"-ac", @"2", @"-i", @"/dev/zero", @"-target", format, @"-", @"-an", nil];
		else
			arguments = [NSArray arrayWithObjects:@"-shortest", @"-f", @"image2pipe", @"-threads", threads, @"-i", @"pipe:.jpg", @"-f", @"s16le", @"-ac", @"2", @"-i", @"/dev/zero", @"-target", format, @"-", @"-an", @"-aspect", @"16:9", nil];
	
		[ffmpeg setArguments:arguments];
		[ffmpeg setStandardInput:pipe];
		[ffmpeg setStandardOutput:pipe2];
		[ffmpeg setStandardError:[NSFileHandle fileHandleWithNullDevice]];

		spumux = [[NSTask alloc] init];
		
		if (![KWCommonMethods createFileAtPath:path attributes:nil errorString:&*error])
			return NO;
		
		[spumux setStandardOutput:[NSFileHandle fileHandleForWritingAtPath:path]];
		[spumux setStandardInput:myHandle2];
		[spumux setLaunchPath:[[NSBundle mainBundle] pathForResource:@"spumux" ofType:@""]];
		[spumux setCurrentDirectoryPath:[path stringByDeletingLastPathComponent]];
		[spumux setArguments:[NSArray arrayWithObject:[[path stringByDeletingPathExtension] stringByAppendingPathExtension:@"xml"]]];
		NSPipe *errorPipe = [[NSPipe alloc] init];
		NSFileHandle *handle;
		[spumux setStandardError:errorPipe];
		handle = [errorPipe fileHandleForReading];
		[KWCommonMethods logCommandIfNeeded:spumux];
		[spumux launch];
		[KWCommonMethods logCommandIfNeeded:ffmpeg];
		[ffmpeg launch];
	
		NSData *tiffData = [image TIFFRepresentation];
		NSBitmapImageRep *bitmap = [NSBitmapImageRep imageRepWithData:tiffData];
		
		NSData *jpgData = [bitmap representationUsingType:NSJPEGFileType properties:[NSDictionary dictionaryWithObject:[NSNumber numberWithCGFloat:1.0] forKey:NSImageCompressionFactor]];
		
		NSInteger q = 0;
		while (q < 25)
		{
			q = q + 1;
			[myHandle writeData:jpgData];
		}
		
		[myHandle closeFile];

		[ffmpeg waitUntilExit];
		[ffmpeg release];
		ffmpeg = nil;
	
		[pipe release];
		pipe = nil;
		
		[pipe2 release];
		pipe2 = nil;

		NSString *string = [[[NSString alloc] initWithData:[handle readDataToEndOfFile] encoding:NSUTF8StringEncoding] autorelease];
	
		if ([standardUserDefaults boolForKey:@"KWDebug"])
			NSLog(@"%@", string);

		[spumux waitUntilExit];

		succes = ([spumux terminationStatus] == 0);

		[spumux release];
		spumux = nil;
		
		[errorPipe release];
		errorPipe = nil;
		
		if (!succes)
		{
			[KWCommonMethods removeItemAtPath:path];
			*error = string;
		}

		[KWCommonMethods removeItemAtPath:maskFile];
		[KWCommonMethods removeItemAtPath:[[path stringByDeletingPathExtension] stringByAppendingPathExtension:@"xml"]];
	}
	
	return succes;
}

//Create a xml file for dvdauthor
-(BOOL)createDVDXMLAtPath:(NSString *)path withFileArray:(NSArray *)fileArray atFolderPath:(NSString *)folderPath errorString:(NSString **)error
{	
	NSInteger numberOfFiles = [fileArray count];
	NSString *xmlContent;

	NSString *aspect1 = @"";
	NSString *aspect2 = @"";
		
	if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDVDThemeFormat"] integerValue] == 1)
	{
		aspect1 = @" aspect=\"16:9\"";
		aspect2 = @"<video aspect=\"16:9\"></video>\n";
	}
		
	NSString *titleset = @"";
		
	if (numberOfFiles > 1 | [[[fileArray objectAtIndex:0] objectForKey:@"Chapters"] count] > 0)
		titleset = @"<button>jump titleset 1 menu entry root;</button>\n";
		
	xmlContent = [NSString stringWithFormat:@"<dvdauthor dest=\"../\" jumppad=\"1\">\n<vmgm>\n<menus>\n<video %@></video>\n<pgc entry=\"title\">\n<vob file=\"Title Menu.mpg\"></vob>\n<button>jump titleset 1 title 1;</button>\n%@</pgc>\n</menus>\n</vmgm>\n<titleset>\n<menus>\n%@", aspect1, titleset, aspect2];

	NSInteger number;
	if ([[theme objectForKey:@"KWSelectionMode"] integerValue] != 2)
		number = [[theme objectForKey:@"KWSelectionImagesOnAPage"] integerValue];
	else
		number = [[theme objectForKey:@"KWSelectionStringsOnAPage"] integerValue];

	NSInteger numberOfMenus = [fileArray count] / number;

	if (numberOfFiles - (numberOfMenus * number) > 0)
		numberOfMenus = numberOfMenus + 1;

	NSInteger chapterMenu = numberOfMenus + 1;
	NSInteger menuItem = 0;

	if (numberOfFiles == 1)
	{
		numberOfMenus = 0;
		chapterMenu = 1;
	}

	NSInteger i;
	for (i = 0; i < numberOfMenus; i ++)
	{
		menuItem = menuItem + 1;
		xmlContent = [NSString stringWithFormat:@"%@<pgc>\n<vob file=\"Title Selection %i.mpg\"></vob>\n", xmlContent, i + 1];
		
		NSInteger o;
		for (o = 0; o < number; o ++)
		{
			if (numberOfFiles > i * number + o)
			{
				NSInteger jumpNumber = o + 1 + i * number;
				NSString *jumpKind;
				
				NSArray *chapters = [[fileArray objectAtIndex:jumpNumber - 1] objectForKey:@"Chapters"];
				if ([chapters count] > 0)
				{
					jumpKind = @"menu";
					jumpNumber = chapterMenu;
					
					NSInteger chapterMenuCount = [chapters count] / number;
					
					if ([chapters count] - (chapterMenuCount * number) > 0)
						chapterMenuCount = chapterMenuCount + 1;
					
					chapterMenu = chapterMenu + chapterMenuCount;
				}
				else
				{
					jumpKind = @"title";
				}
				
				xmlContent = [NSString stringWithFormat:@"%@<button>jump %@ %i;</button>\n", xmlContent, jumpKind, jumpNumber];
			}
		}
		
		if (i > 0)
			xmlContent = [NSString stringWithFormat:@"%@<button>jump menu %i;</button>\n", xmlContent, i];

		if (i < numberOfMenus - 1)
			xmlContent = [NSString stringWithFormat:@"%@<button>jump menu %i;</button>\n", xmlContent, i + 2];

		xmlContent = [NSString stringWithFormat:@"%@</pgc>\n", xmlContent];
	}

	NSMutableArray *titlesWithChapters = [[NSMutableArray alloc] init];
	NSMutableArray *titlesWithChaptersNames = [[NSMutableArray alloc] init];
	for (i = 0; i < [fileArray count]; i ++)
	{
		NSDictionary *fileDictionary = [fileArray objectAtIndex:i];
		NSArray *chapters = [fileDictionary objectForKey:@"Chapters"];
	
		if ([chapters count] > 0)
		{
			[titlesWithChapters addObject:[NSNumber numberWithInteger:i]];
			[titlesWithChaptersNames addObject:[[[fileDictionary objectForKey:@"Path"] lastPathComponent] stringByDeletingPathExtension]];
		}
	}

	NSInteger chapterSelection = 1;
	for (i = 0; i < [titlesWithChapters count]; i ++)
	{
		NSArray *chapters = [[fileArray objectAtIndex:[[titlesWithChapters objectAtIndex:i] integerValue]] objectForKey:@"Chapters"];
		NSInteger numberOfChapters = [chapters count];
		NSInteger numberOfMenus = numberOfChapters / number;

		if (numberOfChapters - numberOfMenus * number > 0)
			numberOfMenus = numberOfMenus + 1;

		NSInteger y;
		for (y = 0; y < numberOfMenus; y ++)
		{
			menuItem = menuItem + 1;
			
			xmlContent = [NSString stringWithFormat:@"%@<pgc>\n<vob file=\"Chapter Selection %i.mpg\"></vob>\n", xmlContent, chapterSelection];
			
			chapterSelection = chapterSelection + 1;
		
			NSInteger o;
			for (o = 0; o < number; o ++)
			{
				NSInteger addNumber;
				if ([[[chapters objectAtIndex:0] objectForKey:@"RealTime"] integerValue] == 0)
					addNumber = 1;
				else
					addNumber = 2;
			
				if (numberOfChapters > y * number + o)
					xmlContent = [NSString stringWithFormat:@"%@<button>jump title %i chapter %i;</button>\n", xmlContent, [[titlesWithChapters objectAtIndex:i] integerValue] + 1, y * number + o + addNumber];
			}
		
		if (y > 0)
		{
			xmlContent = [NSString stringWithFormat:@"%@<button>jump menu %i;</button>\n", xmlContent, menuItem - 1];
		}
		
		if (y < numberOfMenus - 1)
		{
			xmlContent = [NSString stringWithFormat:@"%@<button>jump menu %i;</button>\n", xmlContent, menuItem + 1];
		}
		
			xmlContent = [NSString stringWithFormat:@"%@</pgc>\n", xmlContent];
		}
	}
		
		xmlContent = [NSString stringWithFormat:@"%@</menus>\n<titles>\n", xmlContent];
	
	for (i = 0; i < [fileArray count]; i ++)
	{
		NSDictionary *fileDictionary = [fileArray objectAtIndex:i];
		NSArray *chapters = [[fileArray objectAtIndex:i] objectForKey:@"Chapters"];
	
		xmlContent = [NSString stringWithFormat:@"%@<pgc>\n<vob file=\"%@\"", xmlContent, [fileDictionary objectForKey:@"Path"]];
	
		if ([chapters count] > 0)
		{
			xmlContent = [NSString stringWithFormat:@"%@ chapters=\"00:00:00,", xmlContent];
			
			NSInteger x;
			for (x = 0; x < [chapters count]; x ++)
			{
				NSDictionary *currentChapter = [chapters objectAtIndex:x];
				CGFloat time = [[currentChapter objectForKey:@"RealTime"] cgfloatValue];
				
				if (time > 0)
				{
					NSString *endString;
					if (x + 1 < [chapters count])
						endString = @",";
					else
						endString = @"\"";
					
					xmlContent = [NSString stringWithFormat:@"%@%@%@", xmlContent, [KWCommonMethods formatTime:time withFrames:YES], endString];
				}
			}
		}
	
		xmlContent = [NSString stringWithFormat:@"%@></vob>\n", xmlContent];

		if (i + 1 < [fileArray count] | [[NSUserDefaults standardUserDefaults] boolForKey:@"KWLoopDVD"] == YES)
		{
			NSInteger title;
			if (i + 1 < [fileArray count])
				title = i + 2;
			else
				title = 1;
				
			xmlContent = [NSString stringWithFormat:@"%@<post>jump title %i;</post>", xmlContent, title];
		}
		else
		{
			xmlContent = [NSString stringWithFormat:@"%@<post>call vmgm menu;</post>", xmlContent];
		}

		xmlContent = [NSString stringWithFormat:@"%@</pgc>\n", xmlContent];
	}
	
	xmlContent = [NSString stringWithFormat:@"%@</titles>\n</titleset>\n</dvdauthor>", xmlContent];

	[titlesWithChapters release];
	titlesWithChapters = nil;
	
	[titlesWithChaptersNames release];
	titlesWithChaptersNames = nil;

	return [KWCommonMethods writeString:xmlContent toFile:path errorString:&*error];
}

//Create DVD folders with dvdauthor
- (BOOL)authorDVDWithXMLFile:(NSString *)xmlFile withFileArray:(NSArray *)fileArray atPath:(NSString *)path errorString:(NSString **)error
{
	NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
	NSFileManager *defaultManager = [NSFileManager defaultManager];

	dvdauthor=[[NSTask alloc] init];
	NSPipe *pipe2 = [[NSPipe alloc] init];
	NSPipe *pipe = [[NSPipe alloc] init];
	NSFileHandle *handle;
	NSFileHandle *handle2;
	NSData *data;
	BOOL returnCode;
	[dvdauthor setLaunchPath:[[NSBundle mainBundle] pathForResource:@"dvdauthor" ofType:@""]];
	[dvdauthor setCurrentDirectoryPath:[xmlFile stringByDeletingLastPathComponent]];

	[dvdauthor setArguments:[NSArray arrayWithObjects:@"-x",xmlFile,nil]];
	[dvdauthor setStandardError:pipe];
	[dvdauthor setStandardOutput:pipe2];
	
	handle = [pipe fileHandleForReading];
	handle2 = [pipe2 fileHandleForReading];

	CGFloat totalSize = 0;

	if ([defaultManager fileExistsAtPath:[path stringByAppendingPathComponent:@"THEME_TS"]])
	{
		totalSize = totalSize + [KWCommonMethods calculateRealFolderSize:[path stringByAppendingPathComponent:@"THEME_TS"]];
	}

	NSInteger i;
	for (i = 0; i < [fileArray count]; i ++)
	{
		NSDictionary *attrib = [defaultManager fileAttributesAtPath:[[fileArray objectAtIndex:i] objectForKey:@"Path"] traverseLink:YES];
		totalSize = totalSize + ([[attrib objectForKey:NSFileSize] cgfloatValue]);
	}

	NSInteger currentFile = 1;
	NSInteger currentProcces = 1;
	
	[KWCommonMethods logCommandIfNeeded:dvdauthor];
	[dvdauthor launch];

	totalSize = totalSize / 1024 / 1024;

	NSMutableString *errorString = [[NSMutableString alloc] initWithString:@""];
	NSString *string = [[NSString alloc] init];

	while([data = [handle availableData] length])
	{
		NSAutoreleasePool *subpool = [[NSAutoreleasePool alloc] init];

		if (string)
		{
			[string release];
			string = nil;
		}
	
		string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

		if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWDebug"])
			NSLog(@"%@", string);

		if (string)	
			[errorString appendString:string];

		if ([string rangeOfString:@"Processing /"].length > 0)
		{
			NSString *fileName = [defaultManager displayNameAtPath:[[[[string componentsSeparatedByString:@"Processing "] objectAtIndex:1] componentsSeparatedByString:@"..."] objectAtIndex:0]];
			[defaultCenter postNotificationName:@"KWStatusChanged" object:[NSString stringWithFormat:NSLocalizedString(@"Processing: %@ (%i of %i)", nil), fileName, currentFile, [fileArray count]]];
			
			currentFile = currentFile + 1;
		}
		
		if ([string rangeOfString:@"Generating VTS with the following video attributes"].length > 0)
		{
			[defaultCenter postNotificationName:@"KWStatusChanged" object:NSLocalizedString(@"Generating DVD folder", Localized)];
			currentProcces = 2;
		}

		if ([string rangeOfString:@"MB"].length > 0 && [string rangeOfString:@"at "].length > 0)
		{
			CGFloat progressValue;

			if (currentProcces == 1)
			{
				progressValue = [[[[[string componentsSeparatedByString:@"MB"] objectAtIndex:0] componentsSeparatedByString:@"at "] objectAtIndex:1] cgfloatValue] / totalSize * 100;
				[defaultCenter postNotificationName:@"KWValueChanged" object:[NSNumber numberWithInteger:(([progressSize cgfloatValue] / 100) * progressValue)]];
			}
			else
			{
				progressValue = [[[[[string componentsSeparatedByString:@" "] objectAtIndex:[[string componentsSeparatedByString:@" "] count]-1] componentsSeparatedByString:@")"] objectAtIndex:0] cgfloatValue];

				if (progressValue > 0 && progressValue < 101)
				{
					[defaultCenter postNotificationName:@"KWValueChanged" object:[NSNumber numberWithInteger:([progressSize cgfloatValue])+(([progressSize cgfloatValue] / 100) * progressValue)]];
					[defaultCenter postNotificationName:@"KWStatusChanged" object:[NSString stringWithFormat:NSLocalizedString(@"Generating DVD folder: (%.0f%@)", nil), progressValue, @"%"]];
				}
			}
		}
		
		data = nil;
		[subpool release];
		subpool = nil;
	}

	[dvdauthor waitUntilExit];
	
	returnCode = ([dvdauthor terminationStatus] == 0 && userCanceled == NO);
	
	[errorString appendString:[[[NSString alloc] initWithData:[handle2 readDataToEndOfFile] encoding:NSUTF8StringEncoding] autorelease]];
	errorString = [errorString autorelease];
	
	if (!returnCode)
		*error = [NSString stringWithFormat:@"KWConsole:\nTask: dvdauthor\n%@", errorString];
	
	[string release];
	string = nil;
	
	[pipe release];
	pipe = nil;
	
	[pipe2 release];
	pipe2 = nil;
	
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
	
	NSInteger y = [[theme objectForKey:@"KWStartButtonY"] integerValue];

	if (titles)
	{
		if (![[theme objectForKey:@"KWDVDNameDisableText"] boolValue])
			[self drawString:name inRect:NSMakeRect([[theme objectForKey:@"KWDVDNameX"] integerValue],[[theme objectForKey:@"KWDVDNameY"] integerValue],[[theme objectForKey:@"KWDVDNameW"] integerValue],[[theme objectForKey:@"KWDVDNameH"] integerValue]) onImage:newImage withFontName:[theme objectForKey:@"KWDVDNameFont"] withSize:[[theme objectForKey:@"KWDVDNameFontSize"] integerValue] withColor:(NSColor *)[NSUnarchiver unarchiveObjectWithData:[theme objectForKey:@"KWDVDNameFontColor"]] useAlignment:NSCenterTextAlignment];
	}
	else
	{
		if (![[theme objectForKey:@"KWVideoNameDisableText"] boolValue])
			[self drawString:name inRect:NSMakeRect([[theme objectForKey:@"KWVideoNameX"] integerValue],[[theme objectForKey:@"KWVideoNameY"] integerValue],[[theme objectForKey:@"KWVideoNameW"]  integerValue],[[theme objectForKey:@"KWVideoNameH"]  integerValue]) onImage:newImage withFontName:[theme objectForKey:@"KWVideoNameFont"] withSize:[[theme objectForKey:@"KWVideoNameFontSize"] integerValue] withColor:(NSColor *)[NSUnarchiver unarchiveObjectWithData:[theme objectForKey:@"KWVideoNameFontColor"]] useAlignment:NSCenterTextAlignment];
	}
	
	if (![[theme objectForKey:@"KWStartButtonDisable"] boolValue])
	{
		NSImage *startButtonImage = [[[NSImage alloc] initWithData:[theme objectForKey:@"KWStartButtonImage"]] autorelease];
		NSRect rect = NSMakeRect([[theme objectForKey:@"KWStartButtonX"] integerValue],y,[[theme objectForKey:@"KWStartButtonW"]  integerValue],[[theme objectForKey:@"KWStartButtonH"] integerValue]);

		if (!startButtonImage)
			[self drawString:[theme objectForKey:@"KWStartButtonString"] inRect:rect onImage:newImage withFontName:[theme objectForKey:@"KWStartButtonFont"] withSize:[[theme objectForKey:@"KWStartButtonFontSize"] integerValue] withColor:(NSColor *)[NSUnarchiver unarchiveObjectWithData:[theme objectForKey:@"KWStartButtonFontColor"]] useAlignment:NSCenterTextAlignment];
		else
			[self drawImage:startButtonImage inRect:rect onImage:newImage];
	}

	//Draw titles if needed
	if (titles)
	{
		if (![[theme objectForKey:@"KWTitleButtonDisable"] boolValue] && secondButton)
		{
			NSImage *titleButonImage = [[[NSImage alloc] initWithData:[theme objectForKey:@"KWTitleButtonImage"]] autorelease];
			NSRect rect = NSMakeRect([[theme objectForKey:@"KWTitleButtonX"] integerValue],[[theme objectForKey:@"KWTitleButtonY"] integerValue],[[theme objectForKey:@"KWTitleButtonW"] integerValue],[[theme objectForKey:@"KWTitleButtonH"] integerValue]);

			if (!titleButonImage)
				[self drawString:[theme objectForKey:@"KWTitleButtonString"] inRect:rect onImage:newImage withFontName:[theme objectForKey:@"KWTitleButtonFont"] withSize:[[theme objectForKey:@"KWTitleButtonFontSize"] integerValue] withColor:(NSColor *)[NSUnarchiver unarchiveObjectWithData:[theme objectForKey:@"KWTitleButtonFontColor"]] useAlignment:NSCenterTextAlignment];
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
			NSRect rect = NSMakeRect([[theme objectForKey:@"KWChapterButtonX"] integerValue],[[theme objectForKey:@"KWChapterButtonY"] integerValue],[[theme objectForKey:@"KWChapterButtonW"] integerValue],[[theme objectForKey:@"KWChapterButtonH"] integerValue]);

			if (!chapterButtonImage)
				[self drawString:[theme objectForKey:@"KWChapterButtonString"] inRect:rect onImage:newImage withFontName:[theme objectForKey:@"KWChapterButtonFont"] withSize:[[theme objectForKey:@"KWChapterButtonFontSize"] integerValue] withColor:(NSColor *)[NSUnarchiver unarchiveObjectWithData:[theme objectForKey:@"KWChapterButtonFontColor"]] useAlignment:NSCenterTextAlignment];
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
	
	CGFloat factor;
	if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDVDThemeFormat"] integerValue] == 0)
		factor = 1;
	else
		factor = 1.5; 

	NSInteger y = [[theme objectForKey:@"KWStartButtonMaskY"] integerValue] * factor;

	NSImage *startMaskButtonImage = [[[NSImage alloc] initWithData:[theme objectForKey:@"KWStartButtonMaskImage"]] autorelease];
	NSRect rect = NSMakeRect([[theme objectForKey:@"KWStartButtonMaskX"] integerValue],y-5,[[theme objectForKey:@"KWStartButtonMaskW"] integerValue],[[theme objectForKey:@"KWStartButtonMaskH"] integerValue] * factor);

	if (!startMaskButtonImage)
		[self drawBoxInRect:rect lineWidth:[[theme objectForKey:@"KWStartButtonMaskLineWidth"] integerValue] onImage:newImage];
	else
		[self drawImage:startMaskButtonImage inRect:rect onImage:newImage];

	if (titles)
	{
		if (secondButton)
		{
			NSImage *titleMaskButtonImage = [[[NSImage alloc] initWithData:[theme objectForKey:@"KWTitleButtonMaskImage"]] autorelease];
			NSRect rect = NSMakeRect([[theme objectForKey:@"KWTitleButtonMaskX"] integerValue],[[theme objectForKey:@"KWTitleButtonMaskY"] integerValue] * factor,[[theme objectForKey:@"KWTitleButtonMaskW"] integerValue],[[theme objectForKey:@"KWTitleButtonMaskH"] integerValue] * factor);

			if (!titleMaskButtonImage)
				[self drawBoxInRect:rect lineWidth:[[theme objectForKey:@"KWTitleButtonMaskLineWidth"] integerValue] onImage:newImage];
			else
				[self drawImage:titleMaskButtonImage inRect:rect onImage:newImage];
		}
	}
	else
	{
		NSImage *chapterMaskButtonImage = [[[NSImage alloc] initWithData:[theme objectForKey:@"KWChapterButtonMaskImage"]] autorelease];
		NSRect rect = NSMakeRect([[theme objectForKey:@"KWChapterButtonMaskX"] integerValue],[[theme objectForKey:@"KWChapterButtonMaskY"] integerValue] * factor,[[theme objectForKey:@"KWChapterButtonMaskW"] integerValue],[[theme objectForKey:@"KWChapterButtonMaskH"] integerValue] * factor);
	
		if (!chapterMaskButtonImage)
			[self drawBoxInRect:rect lineWidth:[[theme objectForKey:@"KWChapterButtonMaskLineWidth"] integerValue] onImage:newImage];
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

	NSInteger x;
	NSInteger y;
	NSInteger newRow = 0;
	NSString *pageKey;

	if ([[theme objectForKey:@"KWSelectionMode"] integerValue] == 2)
		pageKey = @"KWSelectionStringsOnAPage";
	else
		pageKey = @"KWSelectionImagesOnAPage";

	if ([[theme objectForKey:@"KWSelectionMode"] integerValue] != 2)
	{
		x = [[theme objectForKey:@"KWSelectionImagesX"] integerValue];
		y = [[theme objectForKey:@"KWSelectionImagesY"] integerValue];
	}
	else
	{
		if ([[theme objectForKey:@"KWSelectionStringsX"] integerValue] == -1)
			x = 0;
		else
			x = [[theme objectForKey:@"KWSelectionStringsX"] integerValue];
	
		if ([[theme objectForKey:@"KWSelectionStringsY"] integerValue] == -1)
		{
			if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDVDThemeFormat"] integerValue] == 0)
				y = 576 - (576 - [objects count] * [[theme objectForKey:@"KWSelectionStringsSeperation"] integerValue]) / 2;
			else
				y = 384 - (384 - [objects count] * [[theme objectForKey:@"KWSelectionStringsSeperation"] integerValue]) / 2;
		}
		else
		{
			y = [[theme objectForKey:@"KWSelectionStringsY"] integerValue];
		}
	}
	
	NSInteger i;
	for (i=0;i<[objects count];i++)
	{
		if ([[theme objectForKey:@"KWSelectionMode"] integerValue] != 2)
		{
			NSImage *previewImage = [images objectAtIndex:i];
			CGFloat width;
			CGFloat height;
	
			if ([previewImage size].width / [previewImage size].height < 1)
			{
				height = [[theme objectForKey:@"KWSelectionImagesH"] integerValue];
				width = [[theme objectForKey:@"KWSelectionImagesH"] integerValue] * ([previewImage size].width / [previewImage size].height);
			}
			else
			{
				if ([[theme objectForKey:@"KWSelectionImagesW"] integerValue] / ([previewImage size].width / [previewImage size].height) <= [[theme objectForKey:@"KWSelectionImagesH"] integerValue])
				{
					width = [[theme objectForKey:@"KWSelectionImagesW"] integerValue];
					height = [[theme objectForKey:@"KWSelectionImagesW"] integerValue] / ([previewImage size].width / [previewImage size].height);
				}
				else
				{
					height = [[theme objectForKey:@"KWSelectionImagesH"] integerValue];
					width = [[theme objectForKey:@"KWSelectionImagesH"] integerValue] * ([previewImage size].width / [previewImage size].height);
				}
			}
		
			NSRect inputRect = NSMakeRect(0,0,[previewImage size].width,[previewImage size].height);
			[newImage lockFocus];
			[previewImage drawInRect:NSMakeRect(x + (([[theme objectForKey:@"KWSelectionImagesW"] integerValue] - width) / 2),y + (([[theme objectForKey:@"KWSelectionImagesH"] integerValue] - height) / 2),width,height) fromRect:inputRect operation:NSCompositeCopy fraction:1.0]; 
			[newImage unlockFocus];
		}
		
		if ([[theme objectForKey:@"KWSelectionMode"] integerValue] == 0)
		{
			NSString *name;
		
			if (titles)
				name = [[[[objects objectAtIndex:i] objectForKey:@"Path"] lastPathComponent] stringByDeletingPathExtension];
			else
				name = [[objects objectAtIndex:i] objectForKey:@"Title"];

			[self drawString:name inRect:NSMakeRect(x,y-[[theme objectForKey:@"KWSelectionImagesH"] integerValue],[[theme objectForKey:@"KWSelectionImagesW"] integerValue],[[theme objectForKey:@"KWSelectionImagesH"] integerValue]) onImage:newImage withFontName:[theme objectForKey:@"KWSelectionImagesFont"] withSize:[[theme objectForKey:@"KWSelectionImagesFontSize"] integerValue] withColor:(NSColor *)[NSUnarchiver unarchiveObjectWithData:[theme objectForKey:@"KWSelectionImagesFontColor"]] useAlignment:NSCenterTextAlignment];
		}
		else if ([[theme objectForKey:@"KWSelectionMode"] integerValue] == 2)
		{
			NSTextAlignment alignment;
			
			if ([[theme objectForKey:@"KWSelectionStringsX"] integerValue] == -1)
				alignment = NSCenterTextAlignment;
			else
				alignment = NSLeftTextAlignment;
			
			NSString *name;
			if (titles)
				name = [[[[objects objectAtIndex:i] objectForKey:@"Path"] lastPathComponent] stringByDeletingPathExtension];
			else
				name = [[objects objectAtIndex:i] objectForKey:@"Title"];

			[self drawString:name inRect:NSMakeRect(x,y,[[theme objectForKey:@"KWSelectionStringsW"] integerValue],[[theme objectForKey:@"KWSelectionStringsH"] integerValue]) onImage:newImage withFontName:[theme objectForKey:@"KWSelectionStringsFont"] withSize:[[theme objectForKey:@"KWSelectionStringsFontSize"] integerValue] withColor:(NSColor *)[NSUnarchiver unarchiveObjectWithData:[theme objectForKey:@"KWSelectionStringsFontColor"]] useAlignment:alignment];
		}
	
		if ([[theme objectForKey:@"KWSelectionMode"] integerValue] != 2)
		{
			x = x + [[theme objectForKey:@"KWSelectionImagesSeperationW"] integerValue];
		
			if (newRow == [[theme objectForKey:@"KWSelectionImagesOnARow"] integerValue]-1)
			{
				y = y - [[theme objectForKey:@"KWSelectionImagesSeperationH"] integerValue];
				x = [[theme objectForKey:@"KWSelectionImagesX"] integerValue];
				newRow = 0;
			}
			else
			{
				newRow = newRow + 1;
			}
		
		}
		else
		{
			y = y - [[theme objectForKey:@"KWSelectionStringsSeperation"] integerValue];
		}
	}
	
	if (![[theme objectForKey:@"KWPreviousButtonDisable"] boolValue] && previous)
	{
		NSImage *previousButtonImage = [[[NSImage alloc] initWithData:[theme objectForKey:@"KWPreviousButtonImage"]] autorelease];
		NSRect rect = NSMakeRect([[theme objectForKey:@"KWPreviousButtonX"] integerValue],[[theme objectForKey:@"KWPreviousButtonY"] integerValue],[[theme objectForKey:@"KWPreviousButtonW"] integerValue],[[theme objectForKey:@"KWPreviousButtonH"] integerValue]);

		if (!previousButtonImage)
			[self drawString:[theme objectForKey:@"KWPreviousButtonString"] inRect:rect onImage:newImage withFontName:[theme objectForKey:@"KWPreviousButtonFont"] withSize:[[theme objectForKey:@"KWPreviousButtonFontSize"] integerValue] withColor:(NSColor *)[NSUnarchiver unarchiveObjectWithData:[theme objectForKey:@"KWPreviousButtonFontColor"]] useAlignment:NSCenterTextAlignment];
		else
			[self drawImage:previousButtonImage inRect:rect onImage:newImage];
	}

	if (![[theme objectForKey:@"KWNextButtonDisable"] boolValue] && next)
	{
		NSImage *nextButtonImage = [[[NSImage alloc] initWithData:[theme objectForKey:@"KWNextButtonImage"]] autorelease];
		NSRect rect = NSMakeRect([[theme objectForKey:@"KWNextButtonX"] integerValue],[[theme objectForKey:@"KWNextButtonY"] integerValue],[[theme objectForKey:@"KWNextButtonW"] integerValue],[[theme objectForKey:@"KWNextButtonH"] integerValue]);

		if (!nextButtonImage)
			[self drawString:[theme objectForKey:@"KWNextButtonString"] inRect:rect onImage:newImage withFontName:[theme objectForKey:@"KWNextButtonFont"] withSize:[[theme objectForKey:@"KWNextButtonFontSize"] integerValue] withColor:(NSColor *)[NSUnarchiver unarchiveObjectWithData:[theme objectForKey:@"KWNextButtonFontColor"]] useAlignment:NSCenterTextAlignment];
		else
			[self drawImage:nextButtonImage inRect:rect onImage:newImage];
	}

	if (!titles)
	{
		if (![[theme objectForKey:@"KWChapterSelectionDisable"] boolValue])
		{
			NSImage *chapterSelectionButtonImage = [[[NSImage alloc] initWithData:[theme objectForKey:@"KWChapterSelectionImage"]] autorelease];
			NSRect rect = NSMakeRect([[theme objectForKey:@"KWChapterSelectionX"] integerValue],[[theme objectForKey:@"KWChapterSelectionY"] integerValue],[[theme objectForKey:@"KWChapterSelectionW"] integerValue],[[theme objectForKey:@"KWChapterSelectionH"] integerValue]);

			if (!chapterSelectionButtonImage)
				[self drawString:[theme objectForKey:@"KWChapterSelectionString"] inRect:rect onImage:newImage withFontName:[theme objectForKey:@"KWChapterSelectionFont"] withSize:[[theme objectForKey:@"KWChapterSelectionFontSize"] integerValue] withColor:(NSColor *)[NSUnarchiver unarchiveObjectWithData:[theme objectForKey:@"KWChapterSelectionFontColor"]] useAlignment:NSCenterTextAlignment];
			else
				[self drawImage:chapterSelectionButtonImage inRect:rect onImage:newImage];
		}
	}
	else
	{
		if (![[theme objectForKey:@"KWTitleSelectionDisable"] boolValue])
		{
			NSImage *titleSelectionButtonImage = [[[NSImage alloc] initWithData:[theme objectForKey:@"KWTitleSelectionImage"]] autorelease];
			NSRect rect = NSMakeRect([[theme objectForKey:@"KWTitleSelectionX"] integerValue],[[theme objectForKey:@"KWTitleSelectionY"] integerValue],[[theme objectForKey:@"KWTitleSelectionW"] integerValue],[[theme objectForKey:@"KWTitleSelectionH"] integerValue]);

			if (!titleSelectionButtonImage)
				[self drawString:[theme objectForKey:@"KWTitleSelectionString"] inRect:rect onImage:newImage withFontName:[theme objectForKey:@"KWTitleSelectionFont"] withSize:[[theme objectForKey:@"KWTitleSelectionFontSize"] integerValue] withColor:(NSColor *)[NSUnarchiver unarchiveObjectWithData:[theme objectForKey:@"KWTitleSelectionFontColor"]] useAlignment:NSCenterTextAlignment];
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

	//if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDVDThemeFormat"] integerValue] == 0)
		newImage = [[[NSImage alloc] initWithSize: NSMakeSize(720,576)] autorelease];
	//else
	//newImage = [[[NSImage alloc] initWithSize: NSMakeSize(720,384)] autorelease];
	
	CGFloat factor;
	if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDVDThemeFormat"] integerValue] == 0)
		factor = 1;
	else
		factor = 1.5;
	
	NSInteger newRow = 0;
	NSInteger x;
	NSInteger y;

	NSString *pageKey;

	if ([[theme objectForKey:@"KWSelectionMode"] integerValue] == 2)
		pageKey = @"KWSelectionStringsOnAPage";
	else
		pageKey = @"KWSelectionImagesOnAPage";

	if ([[theme objectForKey:@"KWSelectionMode"] integerValue] != 2)
	{
		x = [[theme objectForKey:@"KWSelectionImagesMaskX"] integerValue];
		y = [[theme objectForKey:@"KWSelectionImagesMaskY"] integerValue] * factor;
	}
	else
	{
		if ([[theme objectForKey:@"KWSelectionStringsMaskX"] integerValue] == -1)
			x = (720 - [[theme objectForKey:@"KWSelectionStringsMaskW"] integerValue]) / 2;
		else
			x = [[theme objectForKey:@"KWSelectionStringsMaskX"] integerValue];
	
		if ([[theme objectForKey:@"KWSelectionStringsMaskY"] integerValue] == -1)
		{
			//if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDVDThemeFormat"] integerValue] == 0)
			y = 576 - (576 - [objects count] * ([[theme objectForKey:@"KWSelectionStringsMaskSeperation"] integerValue] * factor)) / 2;
			//else
			//y = 384 - (384 - [objects count] * ([[theme objectForKey:@"KWSelectionStringsMaskSeperation"] integerValue] * factor)) / 2;
		}
		else
		{
			y = [[theme objectForKey:@"KWSelectionImagesMaskY"] integerValue] * factor;
		}
	}
	
	NSInteger i;
	for (i=0;i<[objects count];i++)
	{
		if ([[theme objectForKey:@"KWSelectionMode"] integerValue] == 2)
		{
			NSImage *selectionStringsMaskButtonImage  = [[[NSImage alloc] initWithData:[theme objectForKey:@"KWSelectionStringsImage"]] autorelease];
			NSRect rect = NSMakeRect(x,y,[[theme objectForKey:@"KWSelectionStringsMaskW"] integerValue],[[theme objectForKey:@"KWSelectionStringsMaskH"] integerValue] * factor);
		
			if (!selectionStringsMaskButtonImage)
				[self drawBoxInRect:rect lineWidth:[[theme objectForKey:@"KWSelectionStringsMaskLineWidth"] integerValue] onImage:newImage];
			else
				[self drawImage:selectionStringsMaskButtonImage inRect:rect onImage:newImage];
		}
		else
		{
			NSImage *selectionImageMaskButtonImage = [[[NSImage alloc] initWithData:[theme objectForKey:@"KWSelectionImagesImage"]] autorelease];
			NSRect rect = NSMakeRect(x,y,[[theme objectForKey:@"KWSelectionImagesMaskW"] integerValue],[[theme objectForKey:@"KWSelectionImagesMaskH"] integerValue] * factor);
		
			if (!selectionImageMaskButtonImage)
				[self drawBoxInRect:rect lineWidth:[[theme objectForKey:@"KWSelectionImagesMaskLineWidth"] integerValue] onImage:newImage];
			else
				[self drawImage:selectionImageMaskButtonImage inRect:rect onImage:newImage];
		}
	
		if ([[theme objectForKey:@"KWSelectionMode"] integerValue] != 2)
		{
			x = x + [[theme objectForKey:@"KWSelectionImagesMaskSeperationW"] integerValue];
	
			if (newRow == [[theme objectForKey:@"KWSelectionImagesOnARow"] integerValue]-1)
			{
				y = y - [[theme objectForKey:@"KWSelectionImagesMaskSeperationH"] integerValue] * factor;
				x = [[theme objectForKey:@"KWSelectionImagesMaskX"] integerValue];
				newRow = 0;
			}
			else
			{
				newRow = newRow + 1;
			}
		}
		else
		{
			y = y - [[theme objectForKey:@"KWSelectionStringsMaskSeperation"] integerValue] * factor;
		}
	}
	
		if (previous)
		{
			NSImage *previousMaskButtonImage = [[[NSImage alloc] initWithData:[theme objectForKey:@"KWPreviousButtonMaskImage"]] autorelease];
			NSRect rect = NSMakeRect([[theme objectForKey:@"KWPreviousButtonMaskX"] integerValue],[[theme objectForKey:@"KWPreviousButtonMaskY"] integerValue] * factor,[[theme objectForKey:@"KWPreviousButtonMaskW"] integerValue],[[theme objectForKey:@"KWPreviousButtonMaskH"] integerValue] * factor);
	
			if (!previousMaskButtonImage)
				[self drawBoxInRect:rect lineWidth:[[theme objectForKey:@"KWPreviousButtonMaskLineWidth"] integerValue] onImage:newImage];
			else
				[self drawImage:previousMaskButtonImage inRect:rect onImage:newImage];
		}
	
		if (next)
		{
			NSImage *nextMaskButtonImage = [[[NSImage alloc] initWithData:[theme objectForKey:@"KWNextButtonMaskImage"]] autorelease];
			NSRect rect = NSMakeRect([[theme objectForKey:@"KWNextButtonMaskX"] integerValue],[[theme objectForKey:@"KWNextButtonMaskY"] integerValue] * factor,[[theme objectForKey:@"KWNextButtonMaskW"] integerValue],[[theme objectForKey:@"KWNextButtonMaskH"] integerValue] * factor);
	
			if (!nextMaskButtonImage)
				[self drawBoxInRect:rect lineWidth:[[theme objectForKey:@"KWNextButtonMaskLineWidth"] integerValue] onImage:newImage];
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

- (NSImage *)getPreviewImageFromTheme:(NSDictionary *)currentTheme ofType:(NSInteger)type
{
	theme = currentTheme;
	NSImage *image;

	if (type == 0)
	{
		image = [self rootMenuWithTitles:YES withName:NSLocalizedString(@"Title Menu",nil) withSecondButton:YES];
	}
	else if (type == 1)
	{
		image = [self rootMenuWithTitles:NO withName:NSLocalizedString(@"Chapter Menu",nil) withSecondButton:YES];
	}
	else if (type == 2 | type == 3)
	{
		NSInteger number;
		if ([[currentTheme objectForKey:@"KWSelectionMode"] integerValue] != 2)
			number = [[currentTheme objectForKey:@"KWSelectionImagesOnAPage"] integerValue];
		else
			number = [[currentTheme objectForKey:@"KWSelectionStringsOnAPage"] integerValue];
	
		NSMutableArray *images = [NSMutableArray array];
		NSMutableArray *nameArray = [NSMutableArray array];
	
		NSInteger i;
		for (i=0;i<number;i++)
		{
			NSMutableDictionary *nameDict = [NSMutableDictionary dictionary];
	
			[images addObject:[self previewImage]];
	
			NSString *name = NSLocalizedString(@"Preview",nil);
	
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
	
	if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDVDThemeFormat"] integerValue] == 1)
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

- (void)drawString:(NSString *)string inRect:(NSRect)rect onImage:(NSImage *)image withFontName:(NSString *)fontName withSize:(NSInteger)size withColor:(NSColor *)color useAlignment:(NSTextAlignment)alignment
{
	NSFont *labelFont = [NSFont fontWithName:fontName size:size];
	NSMutableParagraphStyle *centeredStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
	[centeredStyle setAlignment:alignment];
	NSDictionary *attsDict = [NSDictionary dictionaryWithObjectsAndKeys:centeredStyle, NSParagraphStyleAttributeName,color, NSForegroundColorAttributeName, labelFont, NSFontAttributeName, [NSNumber numberWithInteger:NSNoUnderlineStyle], NSUnderlineStyleAttributeName, nil];
	[centeredStyle release];
	centeredStyle = nil;
		
	[image lockFocus];
	[string drawInRect:rect withAttributes:attsDict]; 
	[image unlockFocus];
}

- (void)drawBoxInRect:(NSRect)rect lineWidth:(NSInteger)width onImage:(NSImage *)image
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

- (NSImage *)resizeImage:(NSImage *)image
{
	NSImage *resizedImage = [[[NSImage alloc] initWithSize: NSMakeSize(720, 576)] autorelease];

	NSSize originalSize = [image size];

	[resizedImage lockFocus];
	[image drawInRect: NSMakeRect(0, 0, 720, 576) fromRect: NSMakeRect(0, 0, originalSize.width, originalSize.height) operation:NSCompositeSourceOver fraction: 1.0];
	[resizedImage unlockFocus];

	return resizedImage;
}

- (NSImage *)imageForAudioTrackWithName:(NSString *)name withTheme:(NSDictionary *)currentTheme
{
	theme = currentTheme;

	NSImage *newImage = [[[NSImage alloc] initWithData:[theme objectForKey:@"KWDefaultImage"]] autorelease];
	
	if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDVDThemeFormat"] integerValue] == 0)
	{
		[self drawString:@"♫" inRect:NSMakeRect(20, ((NSInteger)[newImage size].height - 600) / 2 , (NSInteger)[newImage size].width - 40, 600) onImage:newImage withFontName:[theme objectForKey:@"KWDVDNameFont"] withSize:400 withColor:(NSColor *)[NSUnarchiver unarchiveObjectWithData:[theme objectForKey:@"KWDVDNameFontColor"]] useAlignment:NSCenterTextAlignment];
		[self drawString:name inRect:NSMakeRect(62, 56, 720, 30) onImage:newImage withFontName:[theme objectForKey:@"KWDVDNameFont"] withSize:24 withColor:(NSColor *)[NSUnarchiver unarchiveObjectWithData:[theme objectForKey:@"KWDVDNameFontColor"]] useAlignment:NSLeftTextAlignment];
	}
	else
	{
		[self drawString:@"♫" inRect:NSMakeRect(20, ((NSInteger)[newImage size].height - 420) / 2 , (NSInteger)[newImage size].width - 40, 420) onImage:newImage withFontName:[theme objectForKey:@"KWDVDNameFont"] withSize:300 withColor:(NSColor *)[NSUnarchiver unarchiveObjectWithData:[theme objectForKey:@"KWDVDNameFontColor"]] useAlignment:NSCenterTextAlignment];
		[self drawString:name inRect:NSMakeRect(42, 38, 720, 24) onImage:newImage withFontName:[theme objectForKey:@"KWDVDNameFont"] withSize:16 withColor:(NSColor *)[NSUnarchiver unarchiveObjectWithData:[theme objectForKey:@"KWDVDNameFontColor"]] useAlignment:NSLeftTextAlignment];
	}
	
	return newImage;//[self resizeImage:newImage];
}

@end