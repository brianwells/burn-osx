//
//  KWDRFolder.m
//  Burn
//
//  Created by Maarten Foukhar on 28-4-07.
//  Copyright 2009 Kiwi Fruitware. All rights reserved.
//

#import "KWDRFolder.h"

@implementation KWDRFolder

- (id)init
{
	if (self = [super init])
	{
		expanded = NO;
		filePackage = NO;
		hfsStandard = NO;
		calculating = NO;
	}

	return self;
}

- (void)dealloc 
{
	if (folderIcon)
	{
		[folderIcon release];
		folderIcon = nil;
	}
	
	if (properties)
	{
		[properties release];
		properties = nil;
	}
	
	if (properties)
	{
		[properties release];
		properties = nil;
	}
	
	if (folderSize)
	{
		[folderSize release];
		folderSize = nil;
	}
	
	if (displayName)
	{
		[displayName release];
		displayName = nil;
	}
	
	if (originalName)
	{
		[originalName release];
		originalName = nil;
	}

	[super dealloc];
}

- (void)setFolderIcon:(NSImage *)image
{
	if (folderIcon)
	{
		[folderIcon release];
		folderIcon = nil;
	}

    if (image) 
	{
		folderIcon = [image retain];
    }
}

- (NSImage *)folderIcon
{
	return folderIcon;
}

- (void)setFolderSize:(NSString *)string
{
	if (folderSize)
	{
		[folderSize release];
		folderSize = nil;
	}
	
	folderSize = [string retain];
}

- (NSString *)folderSize
{
	return folderSize;
}

- (void)setDiscProperties:(NSDictionary *)dict
{
	if (properties)
	{
		[properties release];
		properties = nil;
	}

	if (dict)
		properties = [dict retain];
}

- (NSDictionary *)discProperties
{
	return properties;
}

- (void)setExpanded:(BOOL)exp
{
	expanded = exp;
}

- (BOOL)isExpanded
{
	return expanded;
}

- (void)setIsFilePackage:(BOOL)package
{
	filePackage = package;
}

- (BOOL)isFilePackage
{
	return filePackage;
}

- (void)setDisplayName:(NSString *)string
{
	if (displayName)
	{
		[displayName release];
		displayName = nil;
	}
	
	displayName = [string retain];
}

- (NSString *)displayName
{
	return displayName;
}

- (void)setOriginalName:(NSString *)string
{
 	if (originalName)
	{
		[originalName release];
		originalName = nil;
	}
	
	originalName = [string retain];
}
 
- (NSString *)originalName
{
	return originalName;
}

- (void)setHfsStandard:(BOOL)standard
{
	hfsStandard = standard;
}

- (BOOL)hfsStandard
{
	return hfsStandard;
}

- (void)addChild:(DRFSObject *)child
{
	[super addChild:child];

	if ([child isKindOfClass:[KWDRFolder class]] && [[NSUserDefaults standardUserDefaults] boolForKey:@"KWCalculateFolderSizes"] == YES)
		[NSThread detachNewThreadSelector:@selector(setFolderSizeOnThread:) toTarget:self withObject:child];
}

- (void)setFolderSizeOnThread:(KWDRFolder *)fsObj
{
	NSAutoreleasePool *pool=[[NSAutoreleasePool alloc] init];

	while (calculating == YES)
		usleep(1000000);

	calculating = YES;

	if (![fsObj isVirtual])
		[fsObj setFolderSize:[KWCommonMethods makeSizeFromFloat:[KWCommonMethods calculateRealFolderSize:[fsObj sourcePath]] * 2048]];
	else
		[fsObj setFolderSize:[KWCommonMethods makeSizeFromFloat:[KWCommonMethods calculateVirtualFolderSize:fsObj] * 2048]];

	if (![fsObj isVirtual] | ([fsObj isVirtual] && [[fsObj children] count] > 0))
		[[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotificationName:object:) withObject:@"KWReloadRequested" waitUntilDone:YES];
		//[[NSNotificationCenter defaultCenter] postNotificationName:@"KWReloadRequested" object:nil];
	
	calculating = NO;

	[pool release];
}

@end