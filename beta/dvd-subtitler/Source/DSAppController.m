//
//  DSAppController.m
//
//  Created by Maarten Foukhar on 14-06-10.
//  Copyright 2010 Kiwi Fruitware. All rights reserved.
//

#import "DSAppController.h"
#import "KWAlert.h"

@implementation DSAppController

- (id)init
{
	self = [super init];
	
	mpegTypes = [[NSArray alloc] initWithObjects:@"mpg",@"mpeg", nil];
	subTypes = [[NSArray alloc] initWithObjects:@"sub", @"srt", @"ssa", @"smi", @"rt" , @"txt", @"aqt", @"jss", @"js", @"as", nil];
	
	return self;
}

- (void)dealloc 
{
	[mpegPath release];
	[subPath release];
	[filePath release];
	[xmlPath release];
	[xmlContent release];

	[super dealloc];
}

//Main actions
- (IBAction)chooseMPEGFile:(id)sender
{
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	[openPanel beginSheetForDirectory:nil file:nil types:mpegTypes modalForWindow:mainWindow modalDelegate:self didEndSelector:@selector(mpegOpenPanelEnded:returnCode:contextInfo:) contextInfo:nil];
}

- (void)mpegOpenPanelEnded:(NSOpenPanel *)openPanel returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode == NSOKButton)
	{
		[self openMpegFile:[openPanel filename]];
	}
}

- (void)openMpegFile:(NSString *)path
{
	if (mpegPath)
	{
		[mpegPath release];
		mpegPath = nil;
	}
		
	mpegPath = [path retain];
	[mpegIcon setHidden:NO];
	[mpegIcon setImage:[[NSWorkspace sharedWorkspace] iconForFile:mpegPath]];
	[mpegName setHidden:NO];
	[mpegName setStringValue:[[NSFileManager defaultManager] displayNameAtPath:mpegPath]];
}

- (IBAction)chooseSubFile:(id)sender
{
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	[openPanel beginSheetForDirectory:nil file:nil types:subTypes modalForWindow:mainWindow modalDelegate:self didEndSelector:@selector(subOpenPanelEnded:returnCode:contextInfo:) contextInfo:nil];
}

- (void)subOpenPanelEnded:(NSOpenPanel *)openPanel returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode == NSOKButton)
	{
		[self openSubFile:[openPanel filename]];
	}
}

- (void)openSubFile:(NSString *)path
{
	if (subPath)
	{
		[subPath release];
		subPath = nil;
	}
		
	subPath = [path retain];
	[subIcon setHidden:NO];
	[subIcon setImage:[[NSWorkspace sharedWorkspace] iconForFile:subPath]];
	[subName setHidden:NO];
	[subName setStringValue:[[NSFileManager defaultManager] displayNameAtPath:subPath]];
}

- (IBAction)saveFile:(id)sender
{
	if (mpegPath && subPath)
	{
		NSFileManager *defaultManager = [NSFileManager defaultManager];
		NSString *spumuxPath = [NSHomeDirectory() stringByAppendingPathComponent:@".spumux"];
		
		if (![defaultManager fileExistsAtPath:spumuxPath])
		{
			[defaultManager createDirectoryAtPath:spumuxPath attributes:nil];
		
			NSMutableArray *fontFolderPaths = [NSMutableArray arrayWithObjects:@"/System/Library/Fonts", @"/Library/Fonts", nil];
			NSString *homeFontsFolder = [[NSHomeDirectory() stringByAppendingPathComponent:@"Library"] stringByAppendingPathComponent:@"Fonts"];
		
			if ([defaultManager fileExistsAtPath:homeFontsFolder])
			{
				[fontFolderPaths addObject:homeFontsFolder];
			
				NSString *msFonts = [homeFontsFolder stringByAppendingPathComponent:@"Microsoft"];
			
				if ([defaultManager fileExistsAtPath:homeFontsFolder])
					[fontFolderPaths addObject:msFonts];
			}
			
			int x;
			for (x=0;x<[fontFolderPaths count];x++)
			{
				NSString *folderPath = [fontFolderPaths objectAtIndex:x];
				NSArray *fonts = [defaultManager subpathsAtPath:folderPath];

				int i;
				for (i=0;i<[fonts count];i++)
				{
					NSString *font = [fonts objectAtIndex:i];
			
					if ([[font pathExtension] isEqualTo:@"ttf"])
					{
						NSString *newFontPath = [spumuxPath stringByAppendingPathComponent:font];
					
						if (![defaultManager fileExistsAtPath:newFontPath])
							[defaultManager createSymbolicLinkAtPath:[spumuxPath stringByAppendingPathComponent:font] pathContent:[folderPath stringByAppendingPathComponent:font]];
					}
				}
			}
		}
		
		NSArray *fonts = [defaultManager subpathsAtPath:spumuxPath];
		[fontPopup removeAllItems];

		int y;
		for (y=0;y<[fonts count];y++)
		{
			NSString *font = [fonts objectAtIndex:y];
			
			if ([[font pathExtension] isEqualTo:@"ttf"])
			{
				NSString *fontName = [font stringByDeletingPathExtension];
				NSFont *newFont = [NSFont fontWithName:fontName size:12.0];
				
				if (newFont)
				{
					[fontPopup addItemWithTitle:fontName];
				
					NSAttributedString *titleString;
					NSMutableDictionary *titleAttr = [NSMutableDictionary dictionary];
					[titleAttr setObject:newFont forKey:NSFontAttributeName];
					titleString = [[NSAttributedString alloc] initWithString:fontName attributes:titleAttr];
				
					[[fontPopup lastItem] setAttributedTitle:titleString];

					[titleString release];
				}
				else
				{
					[fontPopup addItemWithTitle:[NSString stringWithFormat:NSLocalizedString(@"%@ (no preview)", nil), fontName]];
				}
			}
		}
		
		NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];
		NSString *savedFont = [standardDefaults objectForKey:@"DSFont"];
		NSNumber *savedFontSize = [standardDefaults objectForKey:@"DSFontSize"];
		
		if (savedFont)
			[fontPopup selectItemWithTitle:savedFont];
			
		if (savedFontSize)
			[fontSize setObjectValue:savedFontSize];

		NSSavePanel *savePanel = [NSSavePanel savePanel];
		[savePanel setAccessoryView:subSettingsView];
		[savePanel setRequiredFileType:@"mpg"];
		[savePanel setCanSelectHiddenExtension:YES];
		[savePanel setExtensionHidden:NO];
		[savePanel beginSheetForDirectory:nil file:[[[[mpegPath lastPathComponent] stringByDeletingPathExtension] stringByAppendingString:NSLocalizedString(@" (subtitles)", nil)] stringByAppendingPathExtension:@"mpg"] modalForWindow:mainWindow modalDelegate:self didEndSelector:@selector(mpegSavePanelEnded:returnCode:contextInfo:) contextInfo:nil];
	}
	else
	{
		NSBeep();
	}
}

- (void)mpegSavePanelEnded:(NSSavePanel *)savePanel returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[savePanel orderOut:self];

	if (returnCode == NSOKButton)
	{
		hiddenExtension = [savePanel isExtensionHidden];
		NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];
		[standardDefaults setObject:[fontPopup title] forKey:@"DSFont"];
		[standardDefaults setObject:[fontSize objectValue] forKey:@"DSFontSize"];
		
		if (filePath)
		{
			[filePath release];
			filePath = nil;
		}
		
		filePath = [[savePanel filename] retain];
		
		if (xmlPath)
		{
			[xmlPath release];
			xmlPath = nil;
		}
		
		xmlPath = [[NSTemporaryDirectory() stringByAppendingPathComponent:@"spumux.xml"] retain];
		
		if (xmlContent)
		{
			[xmlContent release];
			xmlContent = nil;
		}
		
		xmlContent = [[NSString alloc] initWithFormat:@"<subpictures><stream><textsub filename=\"%@\" characterset=\"ISO8859-1\" fontsize=\"%@\" font=\"%@\" horizontal-alignment=\"left\" vertical-alignment=\"bottom\" left-margin=\"60\" right-margin=\"60\" top-margin=\"20\" bottom-margin=\"30\" subtitle-fps=\"25\" movie-fps=\"25\" movie-width=\"720\" movie-height=\"574\" force=\"yes\"/></stream></subpictures>", subPath, [fontSize stringValue], [[fontPopup title] stringByAppendingPathExtension:@"ttf"]];	
		
		if ([self OSVersion] < 0x1040)
			[xmlContent writeToFile:xmlPath atomically:YES];
		else
			[xmlContent writeToFile:xmlPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
		
		[NSThread detachNewThreadSelector:@selector(muxSubs) toTarget:self withObject:nil];
		
		[progressIndicator setMaxValue:[[[[NSFileManager defaultManager] fileAttributesAtPath:mpegPath traverseLink:YES] objectForKey:NSFileSize] doubleValue]];
		[progressIndicator setDoubleValue:0];
		[progressIndicator setIndeterminate:NO];
		[NSApp beginSheet:progressSheet modalForWindow:mainWindow modalDelegate:self didEndSelector:nil contextInfo:nil];
		timer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(saveProgress:) userInfo:nil repeats:YES];
	}
}

- (void)saveProgress:(NSTimer *)timer
{
	NSFileManager *defaultManager = [NSFileManager defaultManager];
	float currentBytes = [[[defaultManager fileAttributesAtPath:filePath traverseLink:YES] objectForKey:NSFileSize] doubleValue];
	float percentage = currentBytes / [progressIndicator maxValue] * 100.0; 
	[progressIndicator setDoubleValue:currentBytes];
	[statusText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Creating: %@ (%0.f%%)", nil), [defaultManager displayNameAtPath:filePath], percentage]];
}

- (void)muxSubs
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	NSFileManager *defaultManager = [NSFileManager defaultManager];
	[defaultManager createFileAtPath:filePath contents:[NSData data] attributes:nil];
	
	spumux = [[NSTask alloc] init];
	NSFileHandle *inputHandle = [NSFileHandle fileHandleForReadingAtPath:mpegPath];
	NSFileHandle *outputHandle = [NSFileHandle fileHandleForWritingAtPath:filePath];
	[spumux setStandardOutput:outputHandle];
	[spumux setStandardInput:inputHandle];
	[spumux setLaunchPath:[[NSBundle mainBundle] pathForResource:@"spumux" ofType:@""]];
	[spumux setCurrentDirectoryPath:[filePath stringByDeletingLastPathComponent]];
	[spumux setArguments:[NSArray arrayWithObject: xmlPath]];
	NSPipe *pipe = [[NSPipe alloc] init];
	NSFileHandle *errorHandle = [pipe fileHandleForReading];
	[spumux setStandardError:pipe];
	[spumux launch];
	NSString *errorString = [[[NSString alloc] initWithData:[errorHandle readDataToEndOfFile] encoding:NSUTF8StringEncoding] autorelease];
	[spumux waitUntilExit];
	int result = [spumux terminationStatus];
	[spumux release];
	spumux = nil;
	[timer invalidate];
	[NSApp endSheet:progressSheet];
	[progressSheet orderOut:self];
	
	if (result == 0)
	{
		NSSound *sound = [NSSound soundNamed:@"complete.aif"];
		[sound play];
	}
	else
	{
		[defaultManager removeFileAtPath:filePath handler:nil];
		
		NSSound *sound = [NSSound soundNamed:@"Basso"];
		[sound play];
		
		KWAlert *alert = [KWAlert alertWithMessageText:NSLocalizedString(@"Failed to create DVD mpg with subtitles", nil) defaultButton:NSLocalizedString(@"OK", nil) alternateButton:@"" otherButton:@"" informativeTextWithFormat:NSLocalizedString(@"See details for what went wrong", nil)];
		[alert setDetails:errorString];
		[alert beginSheetModalForWindow:mainWindow modalDelegate:self didEndSelector:nil contextInfo:nil];
	}
	
	[defaultManager removeFileAtPath:xmlPath handler:nil];
	
	[pool release];
}

//Sheet actions
- (IBAction)cancelProgress:(id)sender
{
	if (spumux)
		[spumux terminate];
}

//Other actions

- (void)openFiles:(NSArray *)files
{
	NSString *mFile = nil;
	NSString *sFile = nil;

	int i;
	for (i=0;i<[files count];i++)
	{
		NSString *file = [files objectAtIndex:i];
		NSString *pathExtension = [file pathExtension];
		
		if (!mFile && [mpegTypes containsObject:pathExtension])
			mFile = file;
		else if (!sFile  && [subTypes containsObject:pathExtension])
			sFile = file;
	}
	
	if (mFile)
		[self openMpegFile:mFile];
		
	if (sFile)
		[self openSubFile:sFile];
}

- (int)OSVersion
{
	SInt32 MacVersion;
	
	Gestalt(gestaltSystemVersion, &MacVersion);
	
	return (int)MacVersion;
}

@end
