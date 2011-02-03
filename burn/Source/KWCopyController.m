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
	self = [super init];

	temporaryFiles = [[NSMutableArray alloc] init];
	currentInformation = [[NSMutableDictionary alloc] init];

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
	temporaryFiles = nil;
	
	[currentInformation release];
	currentInformation = nil;

	[super dealloc];
}

- (BOOL)acceptsFirstResponder
{
	return YES;
}

- (void)awakeFromNib
{
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
	if ([[browseButton title] isEqualTo:NSLocalizedString(@"Open...", nil)])
	{
		NSOpenPanel *sheet = [NSOpenPanel openPanel];
		[sheet setMessage:NSLocalizedString(@"Choose an image file", nil)];

		[sheet beginSheetForDirectory:nil file:nil types:[KWCommonMethods diskImageTypes] modalForWindow:mainWindow modalDelegate:self didEndSelector:@selector(openPanelDidEnd:returnCode:contextInfo:) contextInfo:nil];	
	}
	else
	{
		[self saveImage:self];
	}
}

//If the user clicked OK check the image file
- (void)openPanelDidEnd:(NSOpenPanel *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	[sheet orderOut:self];

	if (returnCode == NSOKButton) 
		[self checkImage:[sheet filename]];
}

//Mount a image using hdiutil
- (IBAction)mountDisc:(id)sender
{
	NSString *path = [currentInformation objectForKey:@"Path"];

	if ([[mountButton title] isEqualTo:NSLocalizedString(@"Mount", nil)])
	{
		progressPanel = [[KWProgress alloc] init];
		[progressPanel setTask:NSLocalizedString(@"Mounting disk image", nil)];
		[progressPanel setStatus:[NSString stringWithFormat:NSLocalizedString(@"Mounting: %@", nil), [nameField stringValue]]];
		[progressPanel setIcon:[[NSWorkspace sharedWorkspace] iconForFileType:@"iso"]];
		[progressPanel setMaximumValue:[NSNumber numberWithDouble:0]];
		[progressPanel setCanCancel:NO];
		[progressPanel beginSheetForWindow:mainWindow];
		
		[NSThread detachNewThreadSelector:@selector(mount:) toTarget:self withObject:path];
	}
	else
	{
		NSString *unmountPath;
		
		if ([[mountButton title] isEqualTo:NSLocalizedString(@"Eject", nil)])
			unmountPath = [currentInformation objectForKey:@"Mounted Path"];
		else if ([[mountButton title] isEqualTo:NSLocalizedString(@"Unmount", nil)])
			unmountPath = [currentInformation objectForKey:@"Image Mounted Path"];
		
		[[NSWorkspace sharedWorkspace] unmountAndEjectDeviceAtPath:unmountPath];
	}
}

- (void)mount:(NSString *)path
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	[self isImageMounted:path showAlert:YES];

	[pool release];
}

//Here we will be checking if it is a valid image / if the file exists
//Also we get the properties
- (BOOL)checkImage:(NSString *)path
{
	NSFileManager *defaultManager = [NSFileManager defaultManager];
	NSWorkspace *sharedWorkspace = [NSWorkspace sharedWorkspace];
	
	NSString *workingPath = path;
	NSString *fileSystem;
	long long size = 0;
	BOOL canBeMounted = YES;
	NSString *browseButtonText = nil;
	NSString *currentMountedPath = nil;
	NSString *realPath;

	NSString *alertMessage = nil;
	NSString *alertInformation;
	
	NSString *string;

	BOOL isPanther = ([KWCommonMethods OSVersion] < 0x1040);
			
	if ([KWCommonMethods OSVersion] >= 0x1060 && [self isImageMounted:path showAlert:NO])
		workingPath = [currentInformation objectForKey:@"Image Mounted Path"];
		
	if ([[sharedWorkspace mountedLocalVolumePaths] containsObject:workingPath])
		realPath = [self getRealDevicePath:workingPath];
	else
		realPath = workingPath;
		
	NSString *pathExtension = [[workingPath pathExtension] lowercaseString];

	if (isPanther && [[NSArray arrayWithObjects:@"sparseimage", @"img", @"dmg", nil] containsObject:pathExtension])
	{
		alertMessage = NSLocalizedString(@"Unsupported Image", nil);
		alertInformation = NSLocalizedString(@"Image not supported on Panther.\n\nTo still use it:\nMount the image and drop the mounted image in the window.", nil);
	}
	else if ([defaultManager fileExistsAtPath:workingPath])
	{
		if ([pathExtension isEqualTo:@"dvd"])
			realPath = [self getIsoForDvdFileAtPath:workingPath];
		
		if ([pathExtension isEqualTo:@"cue"])
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
		else if ([pathExtension isEqualTo:@"isoinfo"])
		{
			fileSystem = NSLocalizedString(@"Audio-CD Image",nil);
			NSDictionary *infoDict = [NSDictionary dictionaryWithContentsOfFile:workingPath];
			
			NSArray *sessions = [infoDict objectForKey:@"Sessions"];

			NSInteger i;
			size = 0;
			for (i = 0; i < [sessions count]; i++)
			{
				NSDictionary *session = [sessions objectAtIndex:i];
				
				size = size + [[session objectForKey:@"Leadout Block"] integerValue];
			}
			
			size = size * 2352;

			canBeMounted = NO;
			
		}
		else if ([pathExtension isEqualTo:@"toc"] && !isPanther)
		{
			//Check if there is a mode2, if so it's not supported by
			//Apple's Disc burning framework, so show a alert
			if (![[KWCommonMethods stringWithContentsOfFile:workingPath] rangeOfString:@"MODE2"].length > 0)
			{
				NSDictionary *attrib;
				NSArray *paths = [[KWCommonMethods stringWithContentsOfFile:workingPath] componentsSeparatedByString:@"FILE \""];
				NSString *filePath;
				NSString *previousPath;
				BOOL fileAreCorrect = YES;
				
				NSInteger i;
				for (i = 1; i < [paths count]; i ++)
				{
					filePath = [[[paths objectAtIndex:i] componentsSeparatedByString:@"\""] objectAtIndex:0];
			
					if ([[filePath stringByDeletingLastPathComponent] isEqualTo:@""])
						filePath = [[workingPath stringByDeletingLastPathComponent] stringByAppendingPathComponent:filePath];
					
					if ([defaultManager fileExistsAtPath:filePath])
					{
						if (![filePath isEqualTo:previousPath])
						{
							attrib = [defaultManager fileAttributesAtPath:filePath traverseLink:YES];
							size = size + [[attrib objectForKey:NSFileSize] integerValue];
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
			NSArray *arguments = [NSArray arrayWithObjects:@"imageinfo", @"-plist", realPath, nil];
			BOOL status = [KWCommonMethods launchNSTaskAtPath:@"/usr/bin/hdiutil" withArguments:arguments outputError:NO outputString:YES output:&string];
			
			if (status)
			{
				if(![string isEqualToString:@""])
				{
					NSDictionary *root = [string propertyList];
				
					fileSystem = NSLocalizedString([root objectForKey:@"Format"], nil);

					if ([pathExtension isEqualTo:@""])
					{
						size = [KWCommonMethods getSizeFromMountedVolume:workingPath] * 512;
					}
					else
					{
						id tmp = [[defaultManager fileAttributesAtPath:realPath traverseLink:YES] objectForKey:NSFileSize];
						size = [tmp longLongValue];
					}
				}

				if ([[sharedWorkspace mountedLocalVolumePaths] containsObject:workingPath])
				{
					currentMountedPath = workingPath;
				}

				if ([self isAudioCD])
					fileSystem = NSLocalizedString(@"Audio CD", nil);
				else
					browseButtonText = NSLocalizedString(@"Save...", nil);
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
		//Set window image information
		[iconView setImage:[sharedWorkspace iconForFile:workingPath]];
		[nameField setStringValue:[defaultManager displayNameAtPath:workingPath]];
		[fileSystemField setStringValue:fileSystem];
		[sizeField setStringValue:[KWCommonMethods makeSizeFromFloat:size]];
		[mountButton setEnabled:canBeMounted];
		
		//Set current file information for later use
		[currentInformation setObject:workingPath forKey:@"Path"];
		[currentInformation setObject:[[workingPath pathExtension] lowercaseString] forKey:@"Extension"];
		[currentInformation setObject:[NSNumber numberWithCGFloat:size / 2048] forKey:@"Blocks"];
		
		if (currentMountedPath)
		{
			[currentInformation setObject:currentMountedPath forKey:@"Mounted Path"];
			[currentInformation setObject:realPath forKey:@"Device Path"];
		}
				
		if (browseButtonText)
			[browseButton setTitle:browseButtonText];
		
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

- (BOOL)isImageMounted:(NSString *)path showAlert:(BOOL)alert
{
	NSString *string;
	NSArray *arguments = [NSArray arrayWithObjects:@"info",@"-plist", nil];
	BOOL status = [KWCommonMethods launchNSTaskAtPath:@"/usr/bin/hdiutil" withArguments:arguments outputError:NO outputString:YES output:&string];
	
	if (alert && progressPanel)
	{
		[progressPanel endSheet];
		[progressPanel release];
		progressPanel = nil;
	}

	if (status && [string rangeOfString:path].length > 0 && [string rangeOfString:@"mount-point"].length > 0)
	{
		NSString *mountPoint = [[[[[[string componentsSeparatedByString:@"<key>mount-point</key>"] objectAtIndex:1] componentsSeparatedByString:@"<string>"] objectAtIndex:1] componentsSeparatedByString:@"</string>"] objectAtIndex:0];
		[currentInformation setObject:mountPoint forKey:@"Image Mounted Path"];
		
		return YES;
	}
	else if (alert)
	{
		KWAlert *alert = [[[KWAlert alloc] init] autorelease];
		[alert addButtonWithTitle:NSLocalizedString(@"OK",nil)];
		[alert setMessageText:NSLocalizedString(@"Mounting image failed",nil)];
		[alert setInformativeText:NSLocalizedString(@"There was a problem mounting the image",nil)];
		[alert setDetails:string];
		[alert beginSheetModalForWindow:mainWindow modalDelegate:self didEndSelector:nil contextInfo:nil];
	}

	return NO;
}

- (IBAction)scanDisks:(id)sender
{
	scanner = [[KWDiscScanner alloc] init];
	[scanner beginSetupSheetForWindow:mainWindow modelessDelegate:self didEndSelector:@selector(scannerDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

- (void)scannerDidEnd:(NSPanel *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	[sheet orderOut:self];

	if (returnCode == NSOKButton) 
	{
		[self checkImage:[scanner disk]];
	}

	[scanner release];
	scanner = nil;
}

- (IBAction)clearDisk:(id)sender
{
	NSWorkspace *sharedWorkspace = [NSWorkspace sharedWorkspace];

	[[sharedWorkspace notificationCenter] removeObserver:self];

	[iconView setImage:[sharedWorkspace iconForFileType:@"iso"]];
	[nameField setStringValue:NSLocalizedString(@"Copy", nil)];
	[sizeField setStringValue:@""];
	[fileSystemField setStringValue:@""];

	[currentInformation removeAllObjects];
	
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

	[myDiscCreationController burnDiscWithName:[nameField stringValue] withType:3];
}

- (void)saveImage:(id)sender
{
	shouldBurn = NO;

	[myDiscCreationController saveImageWithName:[nameField stringValue] withType:3 withFileSystem:@""];
}

- (id)myTrackWithErrorString:(NSString **)error andLayerBreak:(NSNumber **)layerBreak
{
	NSString *currentPath = [currentInformation objectForKey:@"Path"];
	NSString *pathExtension = [currentInformation objectForKey:@"Extension"];
	NSString *mountedPath = [currentInformation objectForKey:@"Mounted Path"];
	
	BOOL isPanther = ([KWCommonMethods OSVersion] < 0x1040);

	if ([pathExtension isEqualTo:@"isoinfo"])
	{
		NSDictionary *infoDict = [NSDictionary dictionaryWithContentsOfFile:currentPath];
	
		return [[KWTrackProducer alloc] getTracksOfAudioCD:[[currentPath stringByDeletingPathExtension] stringByAppendingPathExtension:@"iso"] withToc:infoDict];
	}

	if (!mountedPath)
	{
		if ([pathExtension isEqualTo:@"cue"] && isPanther)
		{
			return [[KWTrackProducer alloc] getTracksOfCueFile:currentPath];
		}
		else
		{
			NSString *workPath;
			if ([pathExtension isEqualTo:@"dvd"]) 
			{
				workPath  = [self getIsoForDvdFileAtPath: currentPath];
				*layerBreak = [self getLayerBreakForDvdFileAtPath: currentPath];
			}
			else
				workPath  = currentPath;
			
			if (isPanther)
				return [[KWTrackProducer alloc] getTrackForImage:workPath withSize:0];
			#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_4
			else
				return [DRBurn layoutForImageFile:workPath];
			#endif
		}
	}
	else
	{
		NSString *deviceMediaPath;

		if ([[[KWCommonMethods savedDevice] status] objectForKey:DRDeviceMediaInfoKey])
			deviceMediaPath = [@"/dev/" stringByAppendingString:[[[[KWCommonMethods savedDevice] status] objectForKey:DRDeviceMediaInfoKey] objectForKey:DRDeviceMediaBSDNameKey]];
		else
			deviceMediaPath = @"";
		
		NSString *workingPath = currentPath;
		if ([[[NSWorkspace sharedWorkspace] mountedLocalVolumePaths] containsObject:workingPath])
			workingPath = [self getRealDevicePath:currentPath];
	
		NSString *disc = [@"/dev/disk" stringByAppendingString:[[[[workingPath componentsSeparatedByString:@"/dev/disk"] objectAtIndex:1] componentsSeparatedByString:@"s"] objectAtIndex:0]];
		NSString *outputFile;
		NSDictionary *tocFile = nil;
	
		if (![disc isEqualTo:deviceMediaPath] | shouldBurn == NO)
		{
			outputFile = workingPath;
			[[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];
		}
		else
		{
			outputFile = [KWCommonMethods temporaryLocation:[[nameField stringValue] stringByAppendingPathExtension:@"iso"] saveDescription:NSLocalizedString(@"Choose a location to save a copy of the disc",nil)];
			
			if (outputFile)
				[temporaryFiles addObject:outputFile];
			else
				return [NSNumber numberWithInteger:2];
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
				return [NSNumber numberWithInteger:0];
			}
		}
	
		if ([disc isEqualTo:deviceMediaPath] && shouldBurn == YES)
		{
			cp = [[NSTask alloc] init];
			[cp setLaunchPath:@"/bin/cp"];
			[cp setArguments:[NSArray arrayWithObjects:workingPath, outputFile, nil]];
			NSFileHandle *handle = [NSFileHandle fileHandleWithNullDevice];
			NSPipe *errorPipe = [[NSPipe alloc] init];
			NSFileHandle *errorHandle = [errorPipe fileHandleForReading];
			[cp setStandardOutput:handle];
			[cp setStandardError:errorPipe];
			
			
			NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
			
			[defaultCenter addObserver:self selector:@selector(stopImageing) name:@"KWStopImaging" object:nil];
			[defaultCenter postNotificationName:@"KWCancelNotificationChanged" object:@"KWStopImaging"];
			[defaultCenter postNotificationName:@"KWStatusChanged" object:NSLocalizedString(@"Copying disc", Localized)];
			[defaultCenter postNotificationName:@"KWMaximumValueChanged" object:[NSNumber numberWithCGFloat:[[self totalSize] cgfloatValue]]];
		
			[self performSelectorOnMainThread:@selector(startTimer:) withObject:outputFile waitUntilDone:NO];
			
			[KWCommonMethods logCommandIfNeeded:cp];
			[cp launch];
			
			*error = [NSString stringWithFormat:@"KWConsole:\nTask: cp\n%@", [[[NSString alloc] initWithData:[errorHandle readDataToEndOfFile] encoding:NSUTF8StringEncoding] autorelease]];
			
			[cp waitUntilExit];
			
			[defaultCenter postNotificationName:@"KWCancelNotificationChanged" object:nil];
			[defaultCenter removeObserver:self name:@"KWStopImaging" object:nil];
			[timer invalidate];
			
			NSInteger status = [cp terminationStatus];
			
			[cp release];
		
			if (!status == 0 && userCanceled == NO)
			{
				[KWCommonMethods removeItemAtPath:outputFile];
				[self remount:disc];
				
				return [NSNumber numberWithInteger:1];
			}
			else if (!status == 0 && userCanceled == YES)
			{
				[KWCommonMethods removeItemAtPath:outputFile];
				[self remount:disc];
				
				return [NSNumber numberWithInteger:2];
			}
			
			if (![[KWCommonMethods savedDevice] ejectMedia])
				return [NSNumber numberWithInteger:1];
		}
		
		if (tocFile)
		{
			if (![workingPath isEqualTo:deviceMediaPath] | shouldBurn == NO)
			{
				[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(remount:) name:@"KWDoneBurning" object:nil];
			
				return [[KWTrackProducer alloc] getTracksOfAudioCD:workingPath withToc:tocFile];
			}
			else
			{
				NSString *infoFile = [[outputFile stringByDeletingPathExtension] stringByAppendingPathExtension:@"isoInfo"];
				[tocFile writeToFile:infoFile atomically:YES];
			
				return [[KWTrackProducer alloc] getTracksOfAudioCD:outputFile withToc:tocFile];
			}
		}
		else if ([KWCommonMethods OSVersion] < 0x1040)
		{
			float blocks = [[currentInformation objectForKey:@"Blocks"] cgfloatValue];
			return [[KWTrackProducer alloc] getTrackForImage:outputFile withSize:blocks];
		}
		#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_4
		else
		{
			return [DRBurn layoutForImageFile:outputFile];
		}
		#endif
	}
	
	return [NSNumber numberWithInteger:0];
}

- (void)startTimer:(NSArray *)object
{
	timer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(imageProgress:) userInfo:object repeats:YES];
}

- (void)imageProgress:(NSTimer *)theTimer
{
	NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];

	CGFloat currentSize = [[[[NSFileManager defaultManager] fileAttributesAtPath:[theTimer userInfo] traverseLink:YES] objectForKey:NSFileSize] cgfloatValue] / 2048;
	CGFloat percent = currentSize / [[self totalSize] cgfloatValue] * 100;
		
		if (percent < 101)
		[defaultCenter postNotificationName:@"KWStatusByAddingPercentChanged" object:[NSString stringWithFormat:@" (%.0f%@)", percent, @"%"]];

	[defaultCenter postNotificationName:@"KWValueChanged" object:[NSNumber numberWithCGFloat:currentSize]];
}

- (void)stopImageing
{
	userCanceled = YES;
	[cp terminate];
}

- (void)remount:(id)object
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"KWDoneBurning" object:nil];
	
	NSString *path;
	
	if (object)
	{
		if ([object isKindOfClass:[NSString class]])
			path = object;
	}
	else
	{
		path = [currentInformation objectForKey:@"Real Device"];
	}

	NSArray *arguments = [NSArray arrayWithObjects:@"mount", path, nil];
	
	NSString *errorsString;
	[KWCommonMethods launchNSTaskAtPath:@"/usr/bin/hdiutil" withArguments:arguments outputError:NO outputString:YES output:&errorsString];
	
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
	return [currentInformation objectForKey:@"Device Path"];
}

- (NSNumber *)totalSize
{
	return [currentInformation objectForKey:@"Blocks"];
}

- (BOOL)respondsToSelector:(SEL)aSelector
{
	if (aSelector == @selector(mountDisc:) && ![mountButton isEnabled])
		return NO;
		
	if (aSelector == @selector(burn:) | aSelector == @selector(saveImage:) && [currentInformation objectForKey:@"Path"] == nil)
		return NO;
		
	return [super respondsToSelector:aSelector];
}

- (NSInteger)numberOfRows
{
	NSInteger rows;
	
	if ([currentInformation objectForKey:@"Path"] != nil)
		rows = 1;
	else 
		rows = 0;

	return rows;
}

- (BOOL)isMounted
{
	return ([[mountButton title] isEqualTo:NSLocalizedString(@"Unmount", nil)]);
}

- (BOOL)isRealDisk
{
	return ([[mountButton title] isEqualTo:NSLocalizedString(@"Eject", nil)]);
}

- (BOOL)isCompatible
{
	return (![self isCueFile] | ![self isAudioCD] | ![[currentInformation objectForKey:@"Extension"] isEqualTo:@"toc"]);
}

- (BOOL)isCueFile
{
	return ([[currentInformation objectForKey:@"Extension"] isEqualTo:@"cue"]);
}

- (BOOL)isAudioCD
{ 
	return ([[NSFileManager defaultManager] fileExistsAtPath:[[currentInformation objectForKey:@"Mounted Path"] stringByAppendingPathComponent:@".TOC.plist"]]);
}

- (NSString *)getRealDevicePath:(NSString *)path
{
	NSString *string;
	NSArray *arguments = [NSArray arrayWithObject:path];
	[KWCommonMethods launchNSTaskAtPath:@"/bin/df" withArguments:arguments outputError:NO outputString:YES output:&string];
	
	NSString *saveDevicePath = [NSString stringWithFormat:@"/dev/r%@", [[[[string componentsSeparatedByString:@"/dev/"] objectAtIndex:1] componentsSeparatedByString:@" "] objectAtIndex:0]];

	return saveDevicePath;
}

- (void)changeMountState:(BOOL)state forDevicePath:(NSString *)path
{	
	NSString *mountedPath = [currentInformation objectForKey:@"Mounted Path"];
	NSString *imageMountedPath = [currentInformation objectForKey:@"Image Mounted Path"];

	if (state)
	{
		if ([path isEqualTo:mountedPath])
		{
			[mountButton setTitle:NSLocalizedString(@"Eject",nil)];
			[mountMenu setTitle:NSLocalizedString(@"Eject Disc", nil)];
		}
		else if ([path isEqualTo:imageMountedPath] | [self isImageMounted:[currentInformation objectForKey:@"Path"] showAlert:NO])
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

- (void)deleteTemporayFiles:(NSNumber *)needed
{
	if ([needed boolValue])
	{
		NSInteger i;
		for (i=0;i<[temporaryFiles count];i++)
		{
			[KWCommonMethods removeItemAtPath:[temporaryFiles objectAtIndex:i]];
		}
	}
	
	[temporaryFiles removeAllObjects];
}

- (NSInteger)cueImageSizeAtPath:(NSString *)path
{
	return 0;
}


- (NSString *)getIsoForDvdFileAtPath:(NSString *)path
{
	NSString *info = [KWCommonMethods stringWithContentsOfFile:path];
	NSArray *arrayOfLines = [info componentsSeparatedByString:@"\n"];
	NSMutableString *iso = [NSMutableString stringWithString:[arrayOfLines objectAtIndex:1]];
	[iso replaceOccurrencesOfString:@"\r" withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [iso length])];
	if ([iso isAbsolutePath])
		return iso;
	return [[path stringByDeletingLastPathComponent] stringByAppendingPathComponent: iso];
}

- (NSNumber *)getLayerBreakForDvdFileAtPath:(NSString *)path
{
	NSString *info = [KWCommonMethods stringWithContentsOfFile:path];
	NSArray *arrayOfLines = [info componentsSeparatedByString:@"\n"];
	NSMutableString *lbreak = [NSMutableString stringWithString:[arrayOfLines objectAtIndex:0]];
	[lbreak replaceOccurrencesOfString:@"\r" withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [lbreak length])];
	[lbreak replaceOccurrencesOfString:@"LayerBreak=" withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [lbreak length])];
	NSScanner* textscanner = [NSScanner scannerWithString:lbreak];
	long long val;
	
	if (![textscanner scanLongLong:&val])
		val = 0.5;
			
	return [NSNumber numberWithLongLong:val];
}

- (NSDictionary *)isoInfo
{
	NSString *mountedPath = [currentInformation objectForKey:@"Mounted Path"];

	if ([[NSFileManager defaultManager] fileExistsAtPath:[mountedPath stringByAppendingPathComponent:@".TOC.plist"]])
		return [NSDictionary dictionaryWithContentsOfFile:[mountedPath stringByAppendingPathComponent:@".TOC.plist"]];
		
	return nil;
}

@end