#import "copyController.h"
#import "dropImageView.h"
#import "KWDocument.h"
#import "KWCommonMethods.h"
#import "discCreationController.h"
#import "KWTrackProducer.h"

@implementation copyController

- (id) init
{
self = [super init];

temporaryFiles = [[NSMutableArray alloc] init];

//The user hasn't canceled yet :-)
userCanceled = NO;

return self;
}

- (void)dealloc
{
//Stop listening to those notifications
[[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];
[[NSNotificationCenter defaultCenter] removeObserver:self];

[temporaryFiles release];

	//Release our strings if needed
	if (currentPath)
	{
	[currentPath release];
	currentPath = nil;
	}
	
	if (mountedPath)
	{
	[mountedPath release];
	mountedPath = nil;
	}
	
	if (imageMountedPath)
	{
	[imageMountedPath release];
	imageMountedPath = nil;
	}

[super dealloc];
}

- (BOOL)acceptsFirstResponder
{
return YES;
}

- (void)awakeFromNib
{
[iconView setImage:[[NSWorkspace sharedWorkspace] iconForFileType:@"iso"]];
}

//////////////////
// Main actions //
//////////////////

#pragma mark -
#pragma mark •• Main actions

//Show open panel to open a image file
- (IBAction)openFiles:(id)sender
{
	if ([[browseButton title] isEqualTo:NSLocalizedString(@"Open...",@"Localized")])
	{
	NSOpenPanel *sheet = [NSOpenPanel openPanel];
	[sheet setMessage:NSLocalizedString(@"Choose an image file",@"Localized")];

	[sheet beginSheetForDirectory: nil file:nil types:[KWCommonMethods diskImageTypes] modalForWindow:mainWindow modalDelegate:self didEndSelector:@selector(openPanelDidEnd:returnCode:contextInfo:) contextInfo:nil];	
	}
	else
	{
	[self saveImage];
	}
}

//If the user clicked OK check the image file
- (void)openPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
[sheet orderOut:self];

	if (returnCode == NSOKButton) 
	{
	NSArray *files = [sheet filenames];
	[self checkImage:[files objectAtIndex:0]];
	}
}

//Mount a image using hdiutil
- (IBAction)mountImage:(id)sender
{
	if (![currentPath isEqualTo:@""] && [[mountButton title] isEqualTo:NSLocalizedString(@"Mount",@"Localized")])
	{
	progressPanel = [[KWProgress alloc] init];
	[progressPanel setTask:NSLocalizedString(@"Mounting disk image",@"Localized")];
	[progressPanel setStatus:[NSLocalizedString(@"Mounting: ",@"Localized") stringByAppendingString:[nameField stringValue]]];
	[progressPanel setIcon:[[NSWorkspace sharedWorkspace] iconForFileType:@"iso"]];
	[progressPanel setMaximumValue:[NSNumber numberWithDouble:0]];
	[progressPanel beginSheetForWindow:mainWindow];
	
	[NSThread detachNewThreadSelector:@selector(mount:) toTarget:self withObject:currentPath];
	}
	else if ([[mountButton title] isEqualTo:NSLocalizedString(@"Eject",@"Localized")]) //&& ![mountedPath isEqualTo:@""])
	{
	[[NSWorkspace sharedWorkspace] unmountAndEjectDeviceAtPath:mountedPath];
	}
	else if ([[mountButton title] isEqualTo:NSLocalizedString(@"Unmount",@"Localized")])
	{
	[[NSWorkspace sharedWorkspace] unmountAndEjectDeviceAtPath:imageMountedPath];
	}
}

- (void)mount:(NSString *)path
{
NSAutoreleasePool *pool=[[NSAutoreleasePool alloc] init];
int status;
hdiutil = [[NSTask alloc] init];
[hdiutil setLaunchPath:@"/usr/bin/hdiutil"];
[hdiutil setArguments:[NSArray arrayWithObjects:@"mount",@"-plist",@"-noverify",@"-noautofsck",path, nil]];
NSPipe *pipe=[[NSPipe alloc] init];
[hdiutil setStandardOutput:pipe];
NSFileHandle *handle=[pipe fileHandleForReading];

[hdiutil launch];

[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stopHdiutil) name:@"imageStopHdiutil" object:nil];
[progressPanel setCancelNotification:@"imageStopHdiutil"];

NSString *string=[[NSString alloc] initWithData:[handle readDataToEndOfFile] encoding:NSASCIIStringEncoding];

	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWDebug"] == YES)
	NSLog(string);

[hdiutil waitUntilExit];

[[NSNotificationCenter defaultCenter] removeObserver:self name:@"imageStopHdiutil" object:nil];

status = [hdiutil terminationStatus];

[progressPanel endSheet];
[progressPanel release];

	if (!status == 0 && userCanceled == NO | [string rangeOfString:@"<key>mount-point</key>"].length > 0)
	{
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert addButtonWithTitle:NSLocalizedString(@"OK",@"Localized")];
	[alert setMessageText:NSLocalizedString(@"Mounting image failed",@"Localized")];
	[alert setInformativeText:NSLocalizedString(@"There was a problem mounting the image",@"Localized")];
	[alert setAlertStyle:NSWarningAlertStyle];
		
	[alert beginSheetModalForWindow:mainWindow modalDelegate:self didEndSelector:nil contextInfo:nil];
	}
	else
	{

		if (imageMountedPath)
		{
		[imageMountedPath release];
		imageMountedPath = nil;
		}

	imageMountedPath = [[[[[[[string componentsSeparatedByString:@"<key>mount-point</key>"] objectAtIndex:1] componentsSeparatedByString:@"<string>"] objectAtIndex:1] componentsSeparatedByString:@"</string>"] objectAtIndex:0] copy];
	userCanceled = NO;
	}

[string release];
string = nil;

[hdiutil release];
hdiutil = nil;

[pipe release];
pipe = nil;

[pool release];
}

//Here we will be checking if it is a valid image / if the file exists
//Also we get the properties
- (BOOL)checkImage:(NSString *)path
{

	if ([KWCommonMethods isPanther] && [[NSArray arrayWithObjects:@"sparseimage", @"img", @"dmg", nil] containsObject:[path pathExtension]])
	{
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert addButtonWithTitle:NSLocalizedString(@"OK",@"Localized")];
	[alert setMessageText:NSLocalizedString(@"Unsupported Image",@"Localized")];
	[alert setInformativeText:NSLocalizedString(@"Image not supported on Panther.\n\nTo still use it:\nMount the image and drop the mounted image in the window.",@"Localized")];
	[alert setAlertStyle:NSWarningAlertStyle];
				
	[alert beginSheetModalForWindow:mainWindow modalDelegate:self didEndSelector:nil contextInfo:nil];
	}
	else if ([[NSFileManager defaultManager] fileExistsAtPath:path])
	{
	hdiutil=[[NSTask alloc] init];
	NSPipe *pipe=[[NSPipe alloc] init];
	NSFileHandle *handle;
	NSString *type;
	NSNumber *size;
	BOOL succes;
		
		if ([[[path pathExtension] lowercaseString] isEqualTo:@"cue"])
		{
		currentPath = [path copy];
		[nameField setStringValue:[[NSFileManager defaultManager] displayNameAtPath:path]];
		[iconView setImage:[[NSWorkspace sharedWorkspace] iconForFile:path]];
		[fileSystemField setStringValue:@"Cue/Bin"];
		[sizeField setStringValue:NSLocalizedString(@"Unknown",@"Localized")];
		[mountButton setEnabled:NO];
		[mountButton setTitle:NSLocalizedString(@"Mount",@"Localized")];
		
		[dropText setHidden:YES];
		[dropIcon setHidden:YES];
		[clearDisk setHidden:NO];
		
		[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(deviceUnmounted:) name:NSWorkspaceDidUnmountNotification object:nil];
		[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(deviceMounted:) name:NSWorkspaceDidMountNotification object:nil];
		
			//Check if there is a bin to get the size
			if ([[NSFileManager defaultManager] fileExistsAtPath:[[path stringByDeletingPathExtension] stringByAppendingPathExtension:@"bin"]])
			{
			NSDictionary *attrib = [[NSFileManager defaultManager] fileAttributesAtPath:[[path stringByDeletingPathExtension] stringByAppendingPathExtension:@"bin"] traverseLink:YES];
			[sizeField setStringValue:[KWCommonMethods makeSizeFromFloat:[[attrib objectForKey:NSFileSize] floatValue]]];
			blocks = [[attrib objectForKey:NSFileSize] unsignedLongValue] / 2048;
			}
			else
			{
			NSDictionary *attrib = [[NSFileManager defaultManager] fileAttributesAtPath:@"/dev/disk3s1" traverseLink:YES];
			[sizeField setStringValue:[KWCommonMethods makeSizeFromFloat:[[attrib objectForKey:NSFileSize] floatValue]]];
			blocks = [[attrib objectForKey:NSFileSize] unsignedLongValue] / 2048;
			}
		}
		else if ([[[path pathExtension] lowercaseString] isEqualTo:@"toc"] && ![KWCommonMethods isPanther])
		{
			//Check if there is a mode2, if so it's not supported by
			//Apple's Disc burning framework, so show a allert
			if (![[NSString stringWithContentsOfFile:path] rangeOfString:@"MODE2"].length > 0)
			{
			int size = 0;
			NSDictionary *attrib;
			int z;
			NSArray *paths = [[NSString stringWithContentsOfFile:path] componentsSeparatedByString:@"FILE \""];
			NSString *filePath;
			NSString *previousPath;
			BOOL fileAreCorrect = YES;
			
				for (z=1;z<[paths count];z++)
				{
				filePath = [[[paths objectAtIndex:z] componentsSeparatedByString:@"\""] objectAtIndex:0];
			
					if ([[filePath stringByDeletingLastPathComponent] isEqualTo:@""])
					filePath = [[path stringByDeletingLastPathComponent] stringByAppendingPathComponent:filePath];
					
					if ([[NSFileManager defaultManager] fileExistsAtPath:filePath] && fileAreCorrect == YES)
					{
						if (![filePath isEqualTo:previousPath])
						{
						attrib = [[NSFileManager defaultManager] fileAttributesAtPath:filePath traverseLink:YES];
						size = size + [[attrib objectForKey:NSFileSize] intValue];
						}
					}
					else
					{
					fileAreCorrect = NO;
					}
				
				previousPath = filePath;
				}
				
				if (fileAreCorrect == YES)
				{
				currentPath = [path copy];
				[nameField setStringValue:[[NSFileManager defaultManager] displayNameAtPath:path]];
				[iconView setImage:[[NSWorkspace sharedWorkspace] iconForFile:path]];
				[fileSystemField setStringValue:@"Toc"];
				[sizeField setStringValue:[KWCommonMethods makeSizeFromFloat:[[NSNumber numberWithInt:size] floatValue]]];
				blocks = [[NSNumber numberWithInt:size] unsignedLongValue] / 2048;
				[mountButton setEnabled:NO];
		
				[dropText setHidden:YES];
				[dropIcon setHidden:YES];
				[clearDisk setHidden:NO];
				
				[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(deviceUnmounted:) name:NSWorkspaceDidUnmountNotification object:nil];
				[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(deviceMounted:) name:NSWorkspaceDidMountNotification object:nil];
				}
				else
				{
				NSAlert *alert = [[[NSAlert alloc] init] autorelease];
				[alert addButtonWithTitle:NSLocalizedString(@"OK",@"Localized")];
				[alert setMessageText:NSLocalizedString(@"Missing files",@"Localized")];
				[alert setInformativeText:NSLocalizedString(@"Some files specified in the Toc file are missing.",@"Localized")];
				[alert setAlertStyle:NSWarningAlertStyle];
				
				[alert beginSheetModalForWindow:mainWindow modalDelegate:self didEndSelector:nil contextInfo:nil];
				}
			}
			else
			{
			NSAlert *alert = [[[NSAlert alloc] init] autorelease];
			[alert addButtonWithTitle:NSLocalizedString(@"OK",@"Localized")];
			[alert setMessageText:NSLocalizedString(@"Unsuported Toc file",@"Localized")];
			[alert setInformativeText:NSLocalizedString(@"Only Mode1 and Audio tracks are supported",@"Localized")];
			[alert setAlertStyle:NSWarningAlertStyle];
			
			[alert beginSheetModalForWindow:mainWindow modalDelegate:self didEndSelector:nil contextInfo:nil];
			}
		}
		else
		{
		[hdiutil setLaunchPath:@"/usr/bin/hdiutil"];
			if ([[[NSWorkspace sharedWorkspace] mountedLocalVolumePaths] containsObject:path])
			[hdiutil setArguments:[NSArray arrayWithObjects:@"imageinfo",@"-plist",[self getRealDevicePath:path], nil]];
			else
			[hdiutil setArguments:[NSArray arrayWithObjects:@"imageinfo",@"-plist",path, nil]];
		[hdiutil setStandardOutput:pipe];
		handle=[pipe fileHandleForReading];
		[hdiutil launch];
		NSString *string = [[NSString alloc] initWithData:[handle readDataToEndOfFile] encoding:NSASCIIStringEncoding]; // convert NSData -> NSString
		[hdiutil waitUntilExit];
			int status = [hdiutil terminationStatus];
			if (status == 0)
			succes = YES;
			else
			succes = NO;
		[pipe release];
		[hdiutil release];
	
			if (succes == YES)
			{
				if(![string isEqualToString: @""])
				{
				NSDictionary *root = [string propertyList];
				type = [self formatDescription:[root objectForKey:@"Format"]];

					if ([[path pathExtension] isEqualTo:@""])
					size = [NSNumber numberWithFloat:[KWCommonMethods getSizeFromMountedVolume:path] * 512];
					else
					size = [[[NSFileManager defaultManager] fileAttributesAtPath:path traverseLink:YES] objectForKey:NSFileSize];
				
				[string release];
				[[NSFileManager defaultManager] removeFileAtPath:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWTemporaryLocation"] stringByAppendingPathComponent:@"hdiutil.output"] handler:nil];
				}
	
			//Set the path field
			currentPath = [path copy];

			//Set the filename
			[nameField setStringValue:[[NSFileManager defaultManager] displayNameAtPath:currentPath]];

				if ([[[NSWorkspace sharedWorkspace] mountedLocalVolumePaths] containsObject:path])
				{
				currentPath = [[self getRealDevicePath:path] copy];
				mountedPath = path;
				[mountButton setTitle:NSLocalizedString(@"Eject",@"Localized")];
				}
				else
				{
					if ([self isImageMounted:currentPath])
					{
					[mountButton setTitle:NSLocalizedString(@"Unmount",@"Localized")];
					}
					else
					{
						if (mountedPath)
						{
						[mountedPath release];
						mountedPath = nil;
						}
						
					[mountButton setTitle:NSLocalizedString(@"Mount",@"Localized")];
					}
				}
				
			//Set image
			[iconView setImage:[[NSWorkspace sharedWorkspace] iconForFile:path]];
				
			[fileSystemField setStringValue:type];
			//Set the filesize, by converting it to a human readable format
			[sizeField setStringValue:[KWCommonMethods makeSizeFromFloat:[size floatValue]]];
			blocks = [[NSNumber numberWithInt:[size intValue]] unsignedLongValue] / 2048;
			//Is the image compressed or not
			[mountButton setEnabled:YES];
			
				if ([self isAudioCD])
				{
				[fileSystemField setStringValue:NSLocalizedString(@"Audio CD",@"Localized")];
				[browseButton setTitle:NSLocalizedString(@"Open...",@"Localized")];
				}
				else
				{
				[browseButton setTitle:NSLocalizedString(@"Save...",@"Localized")];
				}
			}
			else
			{
			[string release];
			
			NSAlert *alert = [[[NSAlert alloc] init] autorelease];
			[alert addButtonWithTitle:NSLocalizedString(@"OK",@"Localized")];
			[alert setMessageText:NSLocalizedString(@"Unknown disk image",@"Localized")];
			[alert setInformativeText:NSLocalizedString(@"Can't determine disc format",@"Localized")];
			[alert setAlertStyle:NSWarningAlertStyle];
			
			[alert beginSheetModalForWindow: mainWindow modalDelegate:self didEndSelector:nil contextInfo:nil];
			}
		}
		
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWChangeBurnStatus" object:[NSNumber numberWithBool:(!currentPath == nil)]];
		
		if (succes)
		{
		[dropText setHidden:YES];
		[dropIcon setHidden:YES];
		[clearDisk setHidden:NO];
		
		[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(deviceUnmounted:) name:NSWorkspaceDidUnmountNotification object:nil];
		[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(deviceMounted:) name:NSWorkspaceDidMountNotification object:nil];
		}
		
	return succes;
	}
	
[[NSNotificationCenter defaultCenter] postNotificationName:@"KWChangeBurnStatus" object:[NSNumber numberWithBool:(!currentPath == nil)]];

return NO;
}

- (BOOL)isImageMounted:(NSString *)path
{
int status;
hdiutil = [[NSTask alloc] init];
[hdiutil setLaunchPath:@"/usr/bin/hdiutil"];
[hdiutil setArguments:[NSArray arrayWithObjects:@"info",@"-plist", nil]];
NSPipe *pipe=[[NSPipe alloc] init];
[hdiutil setStandardOutput:pipe];
NSFileHandle *handle=[pipe fileHandleForReading];
[hdiutil launch];
	
NSString *string=[[NSString alloc] initWithData:[handle readDataToEndOfFile] encoding:NSASCIIStringEncoding];

	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWDebug"] == YES)
	NSLog(string);
			
[hdiutil waitUntilExit];
status = [hdiutil terminationStatus];
[hdiutil release];
hdiutil = nil;
[pipe release];

	if (status == 0)
	{
		if ([string rangeOfString:path].length > 0 && [string rangeOfString:@"mount-point"].length > 0)
		{
			if (imageMountedPath)
			{
			[imageMountedPath release];
			imageMountedPath = nil;
			}
		
		imageMountedPath = [[[[[[[string componentsSeparatedByString:@"<key>mount-point</key>"] objectAtIndex:1] componentsSeparatedByString:@"<string>"] objectAtIndex:1] componentsSeparatedByString:@"</string>"] objectAtIndex:0] copy];
		[string release];
		return YES;
		}
		else
		{
		[string release];
		return NO;
		}
	}

[string release];

return NO;
}

- (NSString *)formatDescription:(NSString *)format
{
	if ([format isEqualTo:@"DC42"])
	return NSLocalizedString(@"Disk Copy 4.2",@"Localized");
	else if ([format isEqualTo:@"RdWr"])
	return NSLocalizedString(@"NDIF read/write",@"Localized");
	else if ([format isEqualTo:@"Rdxx"])
	return NSLocalizedString(@"NDIF read-only",@"Localized");
	else if ([format isEqualTo:@"ROCo"])
	return NSLocalizedString(@"NDIF compressed",@"Localized");
	else if ([format isEqualTo:@"Rken"])
	return NSLocalizedString(@"NDIF compressed (KenCode)",@"Localized");
	else if ([format isEqualTo:@"UDRO"])
	return NSLocalizedString(@"Read-only",@"Localized");
	else if ([format isEqualTo:@"UDCO"])
	return NSLocalizedString(@"Compressed (ADC)",@"Localized");
	else if ([format isEqualTo:@"UDZO"])
	return NSLocalizedString(@"Compressed",@"Localized");
	else if ([format isEqualTo:@"UDBZ"])
	return NSLocalizedString(@"Compressed (bzip2)",@"Localized");
	else if ([format isEqualTo:@"UFBI"])
	return NSLocalizedString(@"Whole device",@"Localized");
	else if ([format isEqualTo:@"IPOD"])
	return NSLocalizedString(@"iPod image",@"Localized");
	else if ([format isEqualTo:@"UDxx"])
	return NSLocalizedString(@"UDIF-stub",@"Localized");
	else if ([format isEqualTo:@"UDRW"])
	return NSLocalizedString(@"Read/write",@"Localized");
	else if ([format isEqualTo:@"UDTO"])
	return NSLocalizedString(@"DVD/CD-master",@"Localized");
	else if ([format isEqualTo:@"UDSP"])
	return NSLocalizedString(@"Limited",@"Localized");
	else if ([format isEqualTo:@"RAW*"])
	return NSLocalizedString(@"Raw",@"Localized");
	else if ([format isEqualTo:@"RAWW"])
	return NSLocalizedString(@"Raw",@"Localized");
	else
	return NSLocalizedString(@"Unknown",@"Localized");
}

- (IBAction)scanDisks:(id)sender
{
scanner = [[KWDiskScanner alloc] init];
[scanner beginSetupSheetForWindow:mainWindow modelessDelegate:self didEndSelector:@selector(scannerDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

- (void)scannerDidEnd:(NSPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
[sheet orderOut:self];

	if (returnCode == NSOKButton) 
	{
	[self checkImage:[scanner disk]];
	}

[scanner release];
[sheet release];
}

- (IBAction)clearDisk:(id)sender
{
[[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];

[iconView setImage:[[NSWorkspace sharedWorkspace] iconForFileType:@"iso"]];
[nameField setStringValue:NSLocalizedString(@"Copy",@"Localized")];
[sizeField setStringValue:@""];
[fileSystemField setStringValue:@""];

	if (currentPath)
	{
	[currentPath release];
	currentPath = nil;
	}
	
	if (mountedPath)
	{
	[mountedPath release];
	mountedPath = nil;
	}
	
	if (imageMountedPath)
	{
	[imageMountedPath release];
	imageMountedPath = nil;
	}
	
[mountButton setEnabled:NO];
[[NSNotificationCenter defaultCenter] postNotificationName:@"KWChangeBurnStatus" object:[NSNumber numberWithBool:NO]];
[dropText setHidden:NO];
[dropIcon setHidden:NO];
[clearDisk setHidden:YES];
[mountButton setTitle:NSLocalizedString(@"Mount",@"Localized")];
[browseButton setTitle:NSLocalizedString(@"Open...",@"Localized")];
}

- (void)stopHdiutil
{
[hdiutil terminate];
userCanceled = YES;
}

///////////////////////////
// Disc creation actions //
///////////////////////////

#pragma mark -
#pragma mark •• Disc creation actions

- (void)burn
{
shouldBurn = YES;

	if (mountedPath)
	{
	NSString *path = [@"/dev/" stringByAppendingString:[[currentPath componentsSeparatedByString:@"r"] objectAtIndex:1]];
	NSString *disc = [@"/dev/disk" stringByAppendingString:[[[[path componentsSeparatedByString:@"/dev/disk"] objectAtIndex:1] componentsSeparatedByString:@"s"] objectAtIndex:0]];
	savedPath = [disc copy];
	}

[myDiscCreationController burnDiscWithName:[nameField stringValue] withType:3];
}

- (void)saveImage
{
shouldBurn = NO;

[myDiscCreationController saveImageWithName:[nameField stringValue] withType:3 withFileSystem:@""];
}

- (id)myTrack
{
	if (!mountedPath)
	{
		if ([[currentPath pathExtension] isEqualTo:@"cue"] && [KWCommonMethods isPanther])
		{
		return [[KWTrackProducer alloc] getTracksOfCueFile:currentPath];
		}
		else
		{
			if ([KWCommonMethods isPanther])
			{
			return [[KWTrackProducer alloc] getTrackForImage:currentPath withSize:0];
			}
			else
			{
			return [DRBurn layoutForImageFile:currentPath];
			}
		}
	}
	else
	{
	NSString *deviceMediaPath;

		if ([[[KWCommonMethods savedDevice] status] objectForKey:DRDeviceMediaInfoKey])
		deviceMediaPath = [@"/dev/" stringByAppendingString:[[[[KWCommonMethods savedDevice] status] objectForKey:DRDeviceMediaInfoKey] objectForKey:DRDeviceMediaBSDNameKey]];
		else
		deviceMediaPath = @"";

	NSString *path = [@"/dev/" stringByAppendingString:[[currentPath componentsSeparatedByString:@"r"] objectAtIndex:1]];
	NSString *disc = [@"/dev/disk" stringByAppendingString:[[[[path componentsSeparatedByString:@"/dev/disk"] objectAtIndex:1] componentsSeparatedByString:@"s"] objectAtIndex:0]];
	NSString *outputFile;
	NSDictionary *tocFile = nil;
	
		if (![disc isEqualTo:deviceMediaPath] | shouldBurn == NO)
		{
		outputFile = currentPath;
		[[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];
		}
		else
		{
		outputFile = [KWCommonMethods temporaryLocation:[[nameField stringValue] stringByAppendingPathExtension:@"iso"] saveDescription:NSLocalizedString(@"Choose a location to save a copy of the disc",@"Localized")];
			
			if (outputFile)
			[temporaryFiles addObject:outputFile];
			else
			return [NSNumber numberWithInt:2];
		}
		
		if ([[NSFileManager defaultManager] fileExistsAtPath:[mountedPath stringByAppendingPathComponent:@".TOC.plist"]])
		{
		tocFile = [NSDictionary dictionaryWithContentsOfFile:[mountedPath stringByAppendingPathComponent:@".TOC.plist"]];
		
		hdiutil = [[NSTask alloc] init];
		[hdiutil setLaunchPath:@"/usr/bin/hdiutil"];
		[hdiutil setArguments:[NSArray arrayWithObjects:@"unmount",mountedPath,nil]];
		NSFileHandle *handle = [NSFileHandle fileHandleWithNullDevice];
		[hdiutil setStandardOutput:handle];
		[hdiutil setStandardError:handle];
		[hdiutil launch];
		[hdiutil waitUntilExit];
		[hdiutil release];
		}
		else
		{
		path = currentPath;
		}
	
		if ([disc isEqualTo:deviceMediaPath] && shouldBurn == YES)
		{
		cp = [[NSTask alloc] init];
		[cp setLaunchPath:@"/bin/cp"];
		[cp setArguments:[NSArray arrayWithObjects:path,outputFile,nil]];
		NSFileHandle *handle = [NSFileHandle fileHandleWithNullDevice];
		[cp setStandardOutput:handle];
		[cp setStandardError:handle];
		[cp launch];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stopImageing) name:@"KWStopImaging" object:nil];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"KWCancelNotificationChanged" object:@"KWStopImaging"];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"KWStatusChanged" object:NSLocalizedString(@"Copying disc", Localized)];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"KWMaximumValueChanged" object:[NSNumber numberWithFloat:[self totalSize]]];
		[self performSelectorOnMainThread:@selector(startTimer:) withObject:outputFile waitUntilDone:NO];
		
		[cp waitUntilExit];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"KWCancelNotificationChanged" object:nil];
		[[NSNotificationCenter defaultCenter] removeObserver:self name:@"KWStopImaging" object:nil];
		[timer invalidate];
		int status = [cp terminationStatus];
		[cp release];
		
			if (!status == 0 && userCanceled == NO)
			{
			[[NSFileManager defaultManager] removeFileAtPath:outputFile handler:nil];
			[self remount:disc];
			return [NSNumber numberWithInt:1];
			}
			else if (!status == 0 && userCanceled == YES)
			{
			[[NSFileManager defaultManager] removeFileAtPath:outputFile handler:nil];
			[self remount:disc];
			return [NSNumber numberWithInt:2];
			}
			
			if (![[KWCommonMethods savedDevice] ejectMedia])
			return [NSNumber numberWithInt:1];
		}

		if (tocFile)
		{
			if (![path isEqualTo:deviceMediaPath] | shouldBurn == NO)
			{
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(remount:) name:@"KWDoneBurning" object:nil];
			
			return [[KWTrackProducer alloc] getTracksOfAudioCD:path withToc:tocFile];
			}
			else
			{
			return [[KWTrackProducer alloc] getTracksOfAudioCD:outputFile withToc:tocFile];
			}
		}
		else if ([KWCommonMethods isPanther])
		{
		return [[KWTrackProducer alloc] getTrackForImage:outputFile withSize:blocks];
		}
		else
		{
		return [DRBurn layoutForImageFile:outputFile];
		}
	}
	
return [NSNumber numberWithInt:0];
}

- (void)removeObservers
{
[[NSNotificationCenter defaultCenter] removeObserver:self name:NSWorkspaceDidMountNotification object:nil];
[[NSNotificationCenter defaultCenter] removeObserver:self name:NSWorkspaceDidUnmountNotification object:nil];
}

- (void)startTimer:(NSArray *)object
{
timer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(imageProgress:) userInfo:object repeats:YES];
}

- (void)imageProgress:(NSTimer *)theTimer
{
float currentSize = [[[[NSFileManager defaultManager] fileAttributesAtPath:[theTimer userInfo] traverseLink:YES] objectForKey:NSFileSize] floatValue] / 2048;
double percent = [[[[[NSNumber numberWithDouble:currentSize / [self totalSize] * 100] stringValue] componentsSeparatedByString:@"."] objectAtIndex:0] doubleValue];
		
		if (percent < 101)
		[[NSNotificationCenter defaultCenter] postNotificationName:@"KWStatusByAddingPercentChanged" object:[[@" (" stringByAppendingString:[[NSNumber numberWithDouble:percent] stringValue]] stringByAppendingString:@"%)"]];

[[NSNotificationCenter defaultCenter] postNotificationName:@"KWValueChanged" object:[NSNumber numberWithFloat:currentSize]];
}

- (void)stopImageing
{
userCanceled = YES;
[cp terminate];
}

- (void)remount:(id)object
{
[[NSNotificationCenter defaultCenter] removeObserver:self name:@"KWDoneBurning" object:nil];

hdiutil = [[NSTask alloc] init];
[hdiutil setLaunchPath:@"/usr/bin/hdiutil"];
	
	if ([object isKindOfClass:[NSString class]])
	[hdiutil setArguments:[NSArray arrayWithObjects:@"mount",object,nil]];
	else
	[hdiutil setArguments:[NSArray arrayWithObjects:@"mount",currentPath,nil]];

NSFileHandle *handle = [NSFileHandle fileHandleWithNullDevice];
[hdiutil setStandardOutput:handle];
[hdiutil setStandardError:handle];
[hdiutil launch];
[hdiutil waitUntilExit];
[hdiutil release];

[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(deviceUnmounted:) name:NSWorkspaceDidUnmountNotification object:nil];
[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(deviceMounted:) name:NSWorkspaceDidMountNotification object:nil];
}

///////////////////
// Other actions //
///////////////////

#pragma mark -
#pragma mark •• Other actions

- (NSString *)myDisc
{
return savedPath;
}

- (float)totalSize
{
return blocks;
}

- (BOOL)hasRows
{
[dropText setHidden:(currentPath != nil)];
[dropIcon setHidden:(currentPath != nil)];
[clearDisk setHidden:(currentPath == nil)];
	
return (currentPath != nil);
}

- (BOOL)isMounted
{
return ([[mountButton title] isEqualTo:NSLocalizedString(@"Unmount",@"Localized")]);
}

- (BOOL)isRealDisk
{
return ([[mountButton title] isEqualTo:NSLocalizedString(@"Eject",@"Localized")]);
}

- (BOOL)isCompatible
{
	if ([self isCueFile] | [self isAudioCD] | [[[currentPath pathExtension] lowercaseString] isEqualTo:@"toc"])
	return NO;
	else
	return YES;
}

- (BOOL)isCueFile
{
	if ([[[currentPath pathExtension] lowercaseString] isEqualTo:@"cue"])
	return YES;
	
return NO;
}

- (BOOL)isAudioCD
{
	if ([[NSFileManager defaultManager] fileExistsAtPath:[mountedPath stringByAppendingPathComponent:@".TOC.plist"]])
	return YES;
	
return NO;
}

- (NSString *)getRealDevicePath:(NSString *)path
{
NSTask *df = [[NSTask alloc] init];
NSPipe *pipe=[[NSPipe alloc] init];
NSFileHandle *handle;
NSString *string;
    
[df setLaunchPath:@"/bin/df"];
[df setArguments:[NSArray arrayWithObject:path]];
[df setStandardOutput:pipe];
handle=[pipe fileHandleForReading];

[df launch];
    
string=[[[NSString alloc] initWithData:[handle readDataToEndOfFile] encoding:NSASCIIStringEncoding] autorelease];
    
string = [@"/dev/r" stringByAppendingString:[[[[string componentsSeparatedByString:@"/dev/"] objectAtIndex:1] componentsSeparatedByString:@" "] objectAtIndex:0]];
    
[pipe release];
[df release];

return string;
}

- (void)deviceUnmounted:(NSNotification *)notif
{
	if ([[[notif userInfo] objectForKey:@"NSDevicePath"] isEqualTo:mountedPath])
	{
	[self clearDisk:self];
	}
	else if ([[[notif userInfo] objectForKey:@"NSDevicePath"] isEqualTo:imageMountedPath])
	{
	[mountButton setTitle:NSLocalizedString(@"Mount",@"Localized")];
	}
	
[[NSNotificationCenter defaultCenter] postNotificationName:@"controlMenus" object:mainWindow];
}

- (void)deviceMounted:(NSNotification *)notif
{
	if ([[[notif userInfo] objectForKey:@"NSDevicePath"] isEqualTo:mountedPath])
	{
	[mountButton setTitle:NSLocalizedString(@"Eject",@"Localized")];
	}
	else if ([[[notif userInfo] objectForKey:@"NSDevicePath"] isEqualTo:imageMountedPath])
	{
	[mountButton setTitle:NSLocalizedString(@"Unmount",@"Localized")];
	}
	else if ([self isImageMounted:currentPath])
	{
	[mountButton setTitle:NSLocalizedString(@"Unmount",@"Localized")];
	}
	
[[NSNotificationCenter defaultCenter] postNotificationName:@"controlMenus" object:mainWindow];
}

- (void)deleteTemporayFiles:(BOOL)needed
{
	if (needed)
	{
		int i;
		for (i=0;i<[temporaryFiles count];i++)
		{
		[[NSFileManager defaultManager] removeFileAtPath:[temporaryFiles objectAtIndex:i] handler:nil];
		}
	}
	
[temporaryFiles removeAllObjects];
}

@end
