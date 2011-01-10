//
//  KWDRFolder.h
//  Burn
//
//  Created by Maarten Foukhar on 28-4-07.
//  Copyright 2009 Kiwi Fruitware. All rights reserved.
//

#import <DiscRecording/DiscRecording.h>
#import <Cocoa/Cocoa.h>
#import "KWCommonMethods.h"

@interface KWDRFolder : DRFolder
{
	NSImage *folderIcon;
	NSString *folderSize;
	NSDictionary *properties;
	BOOL expanded;
	BOOL filePackage;
	BOOL hfsStandard;
	NSString *displayName;
	NSString *originalName;

	NSInteger myNumber;
}

- (void)setFolderIcon:(NSImage *)image;
- (NSImage *)folderIcon;
- (void)setFolderSize:(NSString *)string;
- (NSString *)folderSize;
- (void)setDiscProperties:(NSDictionary *)dict;
- (NSDictionary *)discProperties;
- (void)setExpanded:(BOOL)exp;
- (BOOL)isExpanded;
- (void)setIsFilePackage:(BOOL)package;
- (BOOL)isFilePackage;
- (void)setDisplayName:(NSString *)string;
- (NSString *)displayName;
- (void)setOriginalName:(NSString *)string;
- (NSString *)originalName;
- (void)setHfsStandard:(BOOL)standard;
- (BOOL)hfsStandard;

@end