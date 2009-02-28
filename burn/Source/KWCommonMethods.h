//
//  KWCommonMethods.h
//  Burn
//
//  Created by Maarten Foukhar on 22-4-07.
//  Copyright 2009 Kiwi Fruitware. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <DiscRecording/DiscRecording.h>

@interface KWCommonMethods : NSObject 
{

}

//OS actions
//Check if OS is Panther (we need this one a lot :-)
+ (BOOL)isPanther;
//Check is QuickTime 7 is installed (QTKit)
+ (BOOL)isQuickTimeSevenInstalled;

//String format actions
//Make Untitled look like "Untitled"
+ (NSString *)commentString:(NSString *)string;
//Format time (example: 90 seconds to 0:00:90)
+ (NSString *)formatTime:(int)totalSeconds;
//Make 1048576 bytes look like 1 MB
+ (NSString *)makeSizeFromFloat:(float)size;

//File actions
//Check if there is iDVD folder in the iMovie project folder
+ (BOOL)isSavediMovieProject:(NSString *)path;
//Get a non existing file name (example Folder 1, Folder 2 etc.) with length if needed (like in HFS Standard)
+ (NSString *)uniquePathNameFromPath:(NSString *)path withLength:(unsigned int)length;
//Get the temporary location and ask it if set in the preferences
+ (NSString *)temporaryLocation:(NSString *)file saveDescription:(NSString *)description;
//Create a folder to test if the given extension is a bundle extension
+ (BOOL)isBundleExtension:(NSString *)extension;

//Icon actions
//Check if the file has a custom icon in the Finder or by extension
+ (BOOL)hasCustomIcon:(DRFSObject *)object;
//Get the current folder icon
+ (NSImage *)getFolderIcon:(DRFSObject *)fsObj;
//Get the current file icon
+ (NSImage *)getFileIcon:(DRFSObject *)fsObj;

//Filesystem actions
//Check if the virtual or real file / folder is vissible
+ (BOOL)isDRFSObjectVisible:(DRFSObject *)object;
//Check if the current filesystem includes HFS+
+ (BOOL)fsObjectContainsHFS:(DRFSObject *)object;
//Get the right name for the data list or data inspector
+ (NSString *)fsObjectFileName:(DRFSObject *)object;
//Get the Finder Flags at a given path
+ (unsigned long)getFinderFlagsAtPath:(NSString *)path;
//Check if a virtual or real folder contains .localized
+ (BOOL)isDRFolderIsLocalized:(DRFolder *)folder;

//Other actions
//Take all real folders and calculate the total size 
+ (float)calculateRealFolderSize:(NSString *)path;
//Take all virtual folders and calculate the total size 
+ (float)calculateVirtualFolderSize:(DRFSObject *)obj;
//Get the selected items in the audio tableview for inspection
+ (NSArray*)allSelectedItemsInTableView:(NSTableView *)tableView fromArray:(NSArray *)array;
//Get the current device
+ (DRDevice *)getCurrentDevice;
//Get the first Burn window
+ (NSWindow *)firstBurnWindow;
//Convert a string base output to a dictionary
+ (NSDictionary *)getDictionaryFromString:(NSString *)string;
//Use df to get the size of a mounted volume
+ (int)getSizeFromMountedVolume:(NSString *)mountPoint;
//Write an error log for a unix command
+ (void)writeLogWithFilePath:(NSString *)path withCommand:(NSString *)command withLog:(NSString *)log;
//Get the current device
+ (DRDevice *)savedDevice;
//Get the default media size
+ (NSString *)defaultSizeForMedia:(int)media;
//Get a image from our custom image database
+ (NSImage *)getImageForName:(NSString *)name;
//Setup a burner popup
+ (void)setupBurnerPopup:(NSPopUpButton *)popup;
//Get used ffmpeg
+ (NSString *)ffmpegPath;
//Get the types for diskimages
+ (NSArray *)diskImageTypes;

@end
