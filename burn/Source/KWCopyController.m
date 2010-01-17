#import "KWCopyController.h"
#import "KWCopyView.h"
#import "KWWindowController.h"
#import "KWCommonMethods.h"
#import "KWDiscCreator.h"
#import "KWTrackProducer.h"
#import "KWAlert.h"

@implementation KWCopyController

- (id) init
{
	awakeFromNib = NO;
	
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
		[currentPath release];
	
	if (mountedPath)
		[mountedPath release];
	
	if (imageMountedPath)
		[imageMountedPath release];

	[super dealloc];
}

- (BOOL)acceptsFirstResponder
{
	return YES;
}

- (void)awakeFromNib
{
	awakeFromNib = YES;
	[self clearDisk:self];
}

//////////////////
// Main actions //
//////////////////

#pragma mark -
#pragma mark •• Main actions

//Show open panel to open a image file
- (IBAction)openFiles:(id)sender
{
	if ([[browseButton title] isEqualTo:NSLocalizedString(@"Open...",nil)])
	{
		NSOpenPanel *sheet = [NSOpenPanel openPanel];
		[sheet setMessage:NSLocalizedString(@"Choose an image file",nil)];

		[sheet beginSheetForDirectory: nil file:nil types:[KWCommonMethods diskImageTypes] modalForWindow:mainWindow modalDelegate:self didEndSelector:@selector(openPanelDidEnd:returnCode:contextInfo:) contextInfo:nil];	
	}
	else
	{
		[self saveImage:self];
	}
}

//If the user clicked OK check the image file
- (void)openPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[sheet orderOut:self];

	if (returnCode == NSOKButton) 
		[self checkImage:[sheet filename]];
}

//Mount a image using hdiutil
- (IBAction)mountDisc:(id)sender
{
	if (![currentPath isEqualTo:@""] && [[mountButton title] isEqualTo:NSLocalizedString(@"Mount",nil)])
	{
		progressPanel = [[KWProgress alloc] init];
		[progressPanel setTask:NSLocalizedString(@"Mounting disk image",nil)];
		[progressPanel setStatus:[NSString stringWithFormat:NSLocalizedString(@"Mounting: %@", nil), [nameField stringValue]]];
		[progressPanel setIcon:[[NSWorkspace sharedWorkspace] iconForFileType:@"iso"]];
		[progressPanel setMaximumValue:[NSNumber numberWithDouble:0]];
		[progressPanel setCanCancel:NO];
		[progressPanel beginSheetForWindow:mainWindow];
	
		[NSThread detachNewThreadSelector:@selector(mount:) toTarget:self withObject:currentPath];
	}
	else
	{
		NSString *unmountPath;
		
		if ([[mountButton title] isEqualTo:NSLocalizedString(@"Eject",nil)]) //&& ![mountedPath isEqualTo:@""])
			unmountPath = mountedPath;
		else if ([[mountButton title] isEqualTo:NSLocalizedString(@"Unmount",nil)])
			unmountPath = imageMountedPath;
		
		[[NSWorkspace sharedWorkspace] unmountAndEjectDeviceAtPath:unmountPath];
	}
}

- (void)mount:(NSString *)path
{
	NSAutoreleasePool *pool=[[NSAutoreleasePool alloc] init];
	
	NSString *string;
	NSArray *arguments = [NSArray arrayWithObjects:@"mount",@"-plist",@"-noverify",@"-noautofsck",path, nil];
	BOOL status = [KWCommonMethods launchNSTaskAtPath:@"/usr/bin/hdiutil" withArguments:arguments outputError:NO outputString:YES output:&string];

	[progressPanel endSheet];
	[progressPanel release];

	if (!status | [string rangeOfString:@"<key>mount-point</key>"].length == 0)
	{
		KWAlert *alert = [[[KWAlert alloc] init] autorelease];
		[alert addButtonWithTitle:NSLocalizedString(@"OK",nil)];
		[alert setMessageText:NSLocalizedString(@"Mounting image failed",nil)];
		[alert setInformativeText:NSLocalizedString(@"There was a problem mounting the image",nil)];
		[alert setDetails:string];
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
	}

	[pool release];
}

//Here we will be checking if it is a valid image / if the file exists
//Also we get the properties
- (BOOL)checkImage:(NSString *)path
{
	NSFileManager *defaultManager = [NSFileManager defaultManager];
	NSWorkspace *sharedWorkspace = [NSWorkspace sharedWorkspace];

	NSString *fileSystem = nil;
	int size = 0;
	BOOL canBeMounted = YES;
	NSString *browseButtonText = nil;
	NSString *realPath = nil;
	NSString *currentMountedPath = nil;

	NSString *alertMessage = nil;
	NSString *alertInformation = nil;
	
	NSString *workingPath = path;
	NSString *string;
			
	if ([KWCommonMethods OSVersion] >= 0x1060 && [self isImageMounted:path])
		workingPath = imageMountedPath;
	
	if ([[sharedWorkspace mountedLocalVolumePaths] containsObject:workingPath])
		realPath = [self getRealDevicePath:workingPath];
	else
		realPath = workingPath;

	if ([KWCommonMethods OSVersion] < 0x1040 && [[NSArray arrayWithObjects:@"sparseimage", @"img", @"dmg", nil] containsObject:[workingPath pathExtension]])
	{
		alertMessage = NSLocalizedString(@"Unsupported Image",nil);
		alertInformation = NSLocalizedString(@"Image not supported on Panther.\n\nTo still use it:\nMount the image and drop the mounted image in the window.",nil);
	}
	else if ([defaultManager fileExistsAtPath:workingPath])
	{
		if ([[[workingPath pathExtension] lowercaseString] isEqualTo:@"cue"])
		{
			fileSystem = NSLocalizedString(@"Cue file",nil);
			size = [self cueImageSizeAtPath:workingPath];
			canBeMounted = NO;
		
			if (size == -1)
			{
				alertMessage = NSLocalizedString(@"Missing files",nil);
				alertInformation = [NSString stringWithFormat:NSLocalizedString(@"Some files specified in the %@ file are missing.", nil), @"cue"];
			}
				
		}
		else if ([[[workingPath pathExtension] lowercaseString] isEqualTo:@"toc"] && [KWCommonMethods OSVersion] >= 0x1040)
		{
			//Check if there is a mode2, if so it's not supported by
			//Apple's Disc burning framework, so show a allert
			if (![[NSString stringWithContentsOfFile:workingPath] rangeOfString:@"MODE2"].length > 0)
			{
				NSDictionary *attrib;
				NSArray *paths = [[NSString stringWithContentsOfFile:workingPath] componentsSeparatedByString:@"FILE \""];
				NSString *filePath;
				NSString *previousPath;
				BOOL fileAreCorrect = YES;
				
				int z;
				for (z=1;z<[paths count];z++)
				{
					filePath = [[[paths objectAtIndex:z] componentsSeparatedByString:@"\""] objectAtIndex:0];
			
					if ([[filePath stringByDeletingLastPathComponent] isEqualTo:@""])
						filePath = [[workingPath stringByDeletingLastPathComponent] stringByAppendingPathComponent:filePath];
					
					if ([defaultManager fileExistsAtPath:filePath])
					{
						if (![filePath isEqualTo:previousPath])
						{
							attrib = [defaultManager fileAttributesAtPath:filePath traverseLink:YES];
							size = size + [[attrib objectForKey:NSFileSize] intValue];
						}
					}
					else
					{
						fileAreCorrect = NO;
						break;
					}
				
					previousPath = filePath;
				}
				
				if (fileAreCorrect)
				{
					fileSystem = NSLocalizedString(@"Toc file",nil);
					size = [self cueImageSizeAtPath:workingPath];
					canBeMounted = NO;
				}
				else
				{
					alertMessage = NSLocalizedString(@"Missing files",nil);
					alertInformation = [NSString stringWithFormat:NSLocalizedString(@"Some files specified in the %@ file are missing.", nil), @"toc"];
				}
			}
			else
			{
				alertMessage = NSLocalizedString(@"Unsuported Toc file",nil);
				alertInformation = NSLocalizedString(@"Only Mode1 and Audio tracks are supported",nil);
			}
		}
		else
		{
			NSArray *arguments = [NSArray arrayWithObjects:@"imageinfo",@"-plist",realPath, nil];
			BOOL status = [KWCommonMethods launchNSTaskAtPath:@"/usr/bin/hdiutil" withArguments:arguments outputError:NO outputString:YES output:&string];
			
			if (status)
			{
				if(![string isEqualToString:@""])
				{
					NSDictionary *root = [string propertyList];
					NSString *formatString = @"Format";
					
					if ([KWCommonMethods OSVersion] >= 0x1050)
						formatString = @"Format Description";
				
					fileSystem = NSLocalizedString([root objectForKey:@"Format"],nil);

					if ([[workingPath pathExtension] isEqualTo:@""])
						size = [KWCommonMethods getSizeFromMountedVolume:workingPath] * 512;
					else
						size = [[[defaultManager fileAttributesAtPath:workingPath traverseLink:YES] objectForKey:NSFileSize] intValue];
				}

				if ([[sharedWorkspace mountedLocalVolumePaths] containsObject:workingPath])
				{
					currentMountedPath = workingPath;
				}

				if ([self isAudioCD])
					fileSystem = NSLocalizedString(@"Audio CD",nil);
				else
					browseButtonText = NSLocalizedString(@"Save...",nil);
			}
			else
			{
				alertMessage = NSLocalizedString(@"Unknown disk image",nil);
				alertInformation = NSLocalizedString(@"Can't determine disc format",nil);
			}
			
			NSNotificationCenter *workspaceCenter = [sharedWorkspace notificationCenter];
			[workspaceCenter addObserver:self selector:@selector(deviceUnmounted:) name:NSWorkspaceDidUnmountNotification object:nil];
			[workspaceCenter addObserver:self selector:@selector(deviceMounted:) name:NSWorkspaceDidMountNotification object:nil];
		}
	}
	
	if (!alertMessage)
	{
		currentPath = [workingPath copy];
		[nameField setStringValue:[defaultManager displayNameAtPath:workingPath]];
		[iconView setImage:[sharedWorkspace iconForFile:workingPath]];
		[fileSystemField setStringValue:fileSystem];
		[sizeField setStringValue:[KWCommonMethods makeSizeFromFloat:size]];
		blocks = size / 2048;
		[mountButton setEnabled:canBeMounted];
				
		if (browseButtonText)
			[browseButton setTitle:browseButtonText];
			
		if (currentMountedPath)
			mountedPath = [currentMountedPath copy];
		
		[dropText setHidden:YES];
		[dropIcon setHidden:YES];
		[clearDisk setHidden:NO];
		
		[self changeMountState:YES forDevicePath:workingPath];
					
		[[NSNotificationCenter defaultCenter] postNotificationName:@"KWChangeBurnStatus" object:[NSNumber numberWithBool:YES]];

		return YES;
	}
	else
	{
		KWAlert *alert = [[[KWAlert alloc] init] autorelease];
		[alert addButtonWithTitle:NSLocalizedString(@"OK",nil)];
		[alert setMessageText:alertMessage];
		[alert setInformativeText:alertInformation];
		[alert setAlertStyle:NSWarningAlertStyle];
		[alert setDetails:string];
				
		[alert beginSheetModalForWindow:mainWindow modalDelegate:self didEndSelector:nil contextInfo:nil];
	
		return NO;
	}
}

- (BOOL)isImageMounted:(NSString *)path
{
	NSString *string;
	NSArray *arguments = [NSArray arrayWithObjects:@"info",@"-plist", nil];
	BOOL status = [KWCommonMethods launchNSTaskAtPath:@"/usr/bin/hdiutil" withArguments:arguments outputError:NO outputString:YES output:&string];

	if (status)
	{
		if ([string rangeOfString:path].length > 0 && [string rangeOfString:@"mount-point"].length > 0)
		{
			if (imageMountedPath)
			{
				[imageMountedPath release];
				imageMountedPath = nil;
			}
		
			imageMountedPath = [[[[[[[string componentsSeparatedByString:@"<key>mount-point</key>"] objectAtIndex:1] componentsSeparatedByString:@"<string>"] objectAtIndex:1] componentsSeparatedByString:@"</string>"] objectAtIndex:0] copy];
			
			return YES;
		}
		else
		{
			return NO;
		}
	}

	return NO;
}

- (IBAction)scanDisks:(id)sender
{
	scanner = [[KWDiscScanner alloc] init];
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
}

- (IBAction)clearDisk:(id)sender
{
	NSWorkspace *sharedWorkspace = [NSWorkspace sharedWorkspace];

	[[sharedWorkspace notificationCenter] removeObserver:self];

	[iconView setImage:[sharedWorkspace iconForFileType:@"iso"]];
	[nameField setStringValue:NSLocalizedString(@"Copy",nil)];
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
	[dropText setHidden:NO];
	[dropIcon setHidden:NO];
	[clearDisk setHidden:YES];
	[mountButton setTitle:NSLocalizedString(@"Mount",nil)];
	[mountMenu setTitle:NSLocalizedString(@"Mount Image", nil)];
	[browseButton setTitle:NSLocalizedString(@"Open...",nil)];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KWChangeBurnStatus" object:[NSNumber numberWithBool:NO]];
}

///////////////////////////
// Disc creation actions //
///////////////////////////

#pragma mark -
#pragma mark •• Disc creation actions

- (void)burn:(id)sender
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

- (void)saveImage:(id)sender
{
	shouldBurn = NO;

	[myDiscCreationController saveImageWithName:[nameField stringValue] withType:3 withFileSystem:@""];
}

- (id)myTrackWithErrorString:(NSString **)error
{
	if (!mountedPath)
	{
		if ([[currentPath pathExtension] isEqualTo:@"cue"] && [KWCommonMethods OSVersion] < 0x1040)
		{
			return [[KWTrackProducer alloc] getTracksOfCueFile:currentPath];
		}
		else
		{
			if ([KWCommonMethods OSVersion] < 0x1040)
				return [[KWTrackProducer alloc] getTrackForImage:currentPath withSize:0];
			else
				return [DRBurn layoutForImageFile:currentPath];
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
			outputFile = [KWCommonMethods temporaryLocation:[[nameField stringValue] stringByAppendingPathExtension:@"iso"] saveDescription:NSLocalizedString(@"Choose a location to save a copy of the disc",nil)];
			
			if (outputFile)
				[temporaryFiles addObject:outputFile];
			else
				return [NSNumber numberWithInt:2];
		}
		
		if ([[NSFileManager defaultManager] fileExistsAtPath:[mountedPath stringByAppendingPathComponent:@".TOC.plist"]])
		{
			tocFile = [NSDictionary dictionaryWithContentsOfFile:[mountedPath stringByAppendingPathComponent:@".TOC.plist"]];
		
			NSArray *arguments = [NSArray arrayWithObjects:@"unmount",mountedPath,nil];
			NSString *errorString;
			BOOL status = [KWCommonMethods launchNSTaskAtPath:@"/usr/bin/hdiutil" withArguments:arguments outputError:NO outputString:YES output:&errorString];
			
			if (!status)
			{
				*error = [NSString stringWithFormat:@"KWConsole:\nTask: hdiutil\n%@", errorString];
				return [NSNumber numberWithInt:0];
			}
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
			NSPipe *errorPipe = [[NSPipe alloc] init];
			NSFileHandle *errorHandle = [errorPipe fileHandleForReading];
			[cp setStandardOutput:handle];
			[cp setStandardError:errorHandle];
			
			
			NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
			
			[defaultCenter addObserver:self selector:@selector(stopImageing) name:@"KWStopImaging" object:nil];
			[defaultCenter postNotificationName:@"KWCancelNotificationChanged" object:@"KWStopImaging"];
			[defaultCenter postNotificationName:@"KWStatusChanged" object:NSLocalizedString(@"Copying disc", Localized)];
			[defaultCenter postNotificationName:@"KWMaximumValueChanged" object:[NSNumber numberWithFloat:[self totalSize]]];
		
			[self performSelectorOnMainThread:@selector(startTimer:) withObject:outputFile waitUntilDone:NO];
			
			*error = [[[NSString alloc] initWithData:[errorHandle readDataToEndOfFile] encoding:NSUTF8StringEncoding] autorelease];
			
			[cp launch];
			[cp waitUntilExit];
			
			[defaultCenter postNotificationName:@"KWCancelNotificationChanged" object:nil];
			[defaultCenter removeObserver:self name:@"KWStopImaging" object:nil];
			[timer invalidate];
			
			int status = [cp terminationStatus];
			
			[cp release];
		
			if (!status == 0 && userCanceled == NO)
			{
				[KWCommonMethods removeItemAtPath:outputFile];
				[self remount:disc];
				
				return [NSNumber numberWithInt:1];
			}
			else if (!status == 0 && userCanceled == YES)
			{
				[KWCommonMethods removeItemAtPath:outputFile];
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
		else if ([KWCommonMethods OSVersion] < 0x1040)
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

- (void)startTimer:(NSArray *)object
{
	timer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(imageProgress:) userInfo:object repeats:YES];
}

- (void)imageProgress:(NSTimer *)theTimer
{
	NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];

	float currentSize = [[[[NSFileManager defaultManager] fileAttributesAtPath:[theTimer userInfo] traverseLink:YES] objectForKey:NSFileSize] floatValue] / 2048;
	float percent = currentSize / [self totalSize] * 100;
		
		if (percent < 101)
		[defaultCenter postNotificationName:@"KWStatusByAddingPercentChanged" object:[NSString stringWithFormat:@" (%.0f%@)", percent, @"%"]];

	[defaultCenter postNotificationName:@"KWValueChanged" object:[NSNumber numberWithFloat:currentSize]];
}

- (void)stopImageing
{
	userCanceled = YES;
	[cp terminate];
}

- (void)remount:(id)object
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"KWDoneBurning" object:nil];
	
	NSString *path = currentPath;
	
	if ([object isKindOfClass:[NSString class]])
		path = object;
		
	NSArray *arguments = [NSArray arrayWithObjects:@"mount",path,nil];
	[KWCommonMethods launchNSTaskAtPath:@"/usr/bin/hdiutil" withArguments:arguments outputError:NO outputString:YES output:nil];
	
	NSNotificationCenter *workspaceCenter = [[NSWorkspace sharedWorkspace] notificationCenter];
	[workspaceCenter addObserver:self selector:@selector(deviceUnmounted:) name:NSWorkspaceDidUnmountNotification object:nil];
	[workspaceCenter addObserver:self selector:@selector(deviceMounted:) name:NSWorkspaceDidMountNotification object:nil];
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

- (BOOL)respondsToSelector:(SEL)aSelector
{
	
	if (awakeFromNib && aSelector == @selector(mountDisc:) && ![mountButton isEnabled])
		return NO;
		
	if (aSelector == @selector(burn:) | aSelector == @selector(saveImage:) && currentPath == nil)
		return NO;
		
	return [super respondsToSelector:aSelector];
}

- (int)numberOfRows
{
	int rows;
	
	if (currentPath != nil)
		rows = 1;
	else 
		rows = 0;

	return rows;
}

- (BOOL)isMounted
{
	return ([[mountButton title] isEqualTo:NSLocalizedString(@"Unmount",nil)]);
}

- (BOOL)isRealDisk
{
	return ([[mountButton title] isEqualTo:NSLocalizedString(@"Eject",nil)]);
}

- (BOOL)isCompatible
{
	return (![self isCueFile] | ![self isAudioCD] | ![[[currentPath pathExtension] lowercaseString] isEqualTo:@"toc"]);
}

- (BOOL)isCueFile
{
	return ([[[currentPath pathExtension] lowercaseString] isEqualTo:@"cue"]);
}

- (BOOL)isAudioCD
{ 
	return ([[NSFileManager defaultManager] fileExistsAtPath:[mountedPath stringByAppendingPathComponent:@".TOC.plist"]]);
}

- (NSString *)getRealDevicePath:(NSString *)path
{
	NSString *string;
	NSArray *arguments = [NSArray arrayWithObject:path];
	[KWCommonMethods launchNSTaskAtPath:@"/bin/df" withArguments:arguments outputError:NO outputString:YES output:&string];

	string = [@"/dev/r" stringByAppendingString:[[[[string componentsSeparatedByString:@"/dev/"] objectAtIndex:1] componentsSeparatedByString:@" "] objectAtIndex:0]];

	return string;
}

- (void)changeMountState:(BOOL)state forDevicePath:(NSString *)path
{	
	if (state)
	{
		if ([path isEqualTo:mountedPath])
		{
			[mountButton setTitle:NSLocalizedString(@"Eject",nil)];
			[mountMenu setTitle:NSLocalizedString(@"Eject Disc", nil)];
		}
		else if ([path isEqualTo:imageMountedPath] | [self isImageMounted:currentPath])
		{
			[mountButton setTitle:NSLocalizedString(@"Unmount",nil)];
			[mountMenu setTitle:NSLocalizedString(@"Unmount Image", nil)];
		}
	}
	else 
	{
		if ([path isEqualTo:mountedPath])
		{
			[self clearDisk:self];
		}
		else if ([path isEqualTo:imageMountedPath])
		{
			[mountButton setTitle:NSLocalizedString(@"Mount",nil)];
			[mountMenu setTitle:NSLocalizedString(@"Mount Image", nil)];
		}
	}

}

- (void)deviceUnmounted:(NSNotification *)notif
{
	[self changeMountState:NO forDevicePath:[[notif userInfo] objectForKey:@"NSDevicePath"]];
}

- (void)deviceMounted:(NSNotification *)notif
{
	[self changeMountState:YES forDevicePath:[[notif userInfo] objectForKey:@"NSDevicePath"]];
}

- (void)deleteTemporayFiles:(BOOL)needed
{
	if (needed)
	{
		int i;
		for (i=0;i<[temporaryFiles count];i++)
		{
			[KWCommonMethods removeItemAtPath:[temporaryFiles objectAtIndex:i]];
		}
	}
	
	[temporaryFiles removeAllObjects];
}

- (int)cueImageSizeAtPath:(NSString *)path
{
	return 0;
}

@end