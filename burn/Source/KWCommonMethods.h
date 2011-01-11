//
//  KWCommonMethods.h
//  Burn
//
//  Created by Maarten Foukhar on 22-4-07.
//  Copyright 2009 Kiwi Fruitware. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <DiscRecording/DiscRecording.h>

#if MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_X_VERSION_10_5
typedef int NSInteger;
typedef unsigned int NSUInteger;
#endif

@interface KWCommonMethods : NSObject 
{

}

//OS actions
//Check for Snow Leopard (used to show new sizes divided by 1000 instead of 1024)
+ (NSInteger)OSVersion;
//Check is QuickTime 7 is installed (QTKit)
+ (BOOL)isQuickTimeSevenInstalled;

//String format actions
//Format time (example: 90 seconds to 00:00:90)
+ (NSString *)formatTime:(NSInteger)time;
//Format time for chapters on DVD (exact: 90 seconds to 00:00:90.00)
+ (NSString *)formatTimeForChapter:(float)time;
//Make 1048576 bytes look like 1 MB
+ (NSString *)makeSizeFromFloat:(float)size;

//File actions
//Get a non existing file name (example Folder 1, Folder 2 etc.)
+ (NSString *)uniquePathNameFromPath:(NSString *)path;
//Get the temporary location and ask it if set in the preferences
+ (NSString *)temporaryLocation:(NSString *)file saveDescription:(NSString *)description;
//Create a folder to test if the given extension is a bundle extension
+ (BOOL)isBundleExtension:(NSString *)extension;

//Icon actions
//Check if the file has a custom icon in the Finder or by extension
+ (BOOL)hasCustomIcon:(DRFSObject *)object;
//Get the current icon
+ (NSImage *)getIcon:(DRFSObject *)fsObj;

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
//Get the max lable size
+ (NSInteger)maxLabelLength:(DRFolder *)folder;

//Error actions
+ (BOOL)createDirectoryAtPath:(NSString *)path errorString:(NSString **)error;
+ (BOOL)copyItemAtPath:(NSString *)inPath toPath:(NSString *)newPath errorString:(NSString **)error;
+ (BOOL)createSymbolicLinkAtPath:(NSString *)path withDestinationPath:(NSString *)dest errorString:(NSString **)error;
+ (BOOL)removeItemAtPath:(NSString *)path;
+ (BOOL)writeString:(NSString *)string toFile:(NSString *)path errorString:(NSString **)error;
+ (BOOL)writeDictionary:(NSDictionary *)dictionary toFile:(NSString *)path errorString:(NSString **)error;
+ (BOOL)saveImage:(NSImage *)image toPath:(NSString *)path errorString:(NSString **)error;
+ (BOOL)createFileAtPath:(NSString *)path attributes:(NSDictionary *)attributes errorString:(NSString **)error;

//Other actions
//Take all real folders and calculate the total size 
+ (float)calculateRealFolderSize:(NSString *)path;
//Take all virtual folders and calculate the total size 
+ (float)calculateVirtualFolderSize:(DRFSObject *)obj;
//Get the selected items in the audio tableview for inspection
+ (NSArray*)allSelectedItemsInTableView:(NSTableView *)tableView fromArray:(NSArray *)array;
//Get the current device
+ (DRDevice *)getCurrentDevice;
//Convert a string base output to a dictionary
+ (NSDictionary *)getDictionaryFromString:(NSString *)string;
//Use df to get the size of a mounted volume
+ (NSInteger)getSizeFromMountedVolume:(NSString *)mountPoint;
//Get the current device
+ (DRDevice *)savedDevice;
//Get the default media size
+ (float)defaultSizeForMedia:(NSString *)media;
//Get a image from our custom image database
+ (NSImage *)getImageForName:(NSString *)name;
//Setup a burner popup
+ (void)setupBurnerPopup:(NSPopUpButton *)popup;
//Get used ffmpeg
+ (NSString *)ffmpegPath;
//Get the types for diskimages
+ (NSArray *)diskImageTypes;
//Create an array with indexes of selected rows in a tableview in an array
+ (NSArray *)selectedRowsAtRowIndexes:(NSIndexSet *)indexSet;
//Get ffmpeg and qt types
+ (NSArray *)mediaTypes;
//Get qt types
+ (NSArray *)quicktimeTypes;
//Create a compilant DVD-Video or Audio folder
+ (NSInteger)createDVDFolderAtPath:(NSString *)path ofType:(NSInteger)type fromTableData:(id)tableData errorString:(NSString **)error;
//Log command with arguments for easier debugging
+ (void)logCommandIfNeeded:(NSTask *)command;
//Conveniant method to load a NSTask
+ (BOOL)launchNSTaskAtPath:(NSString *)path withArguments:(NSArray *)arguments outputError:(BOOL)error outputString:(BOOL)string output:(id *)data;
//Standard informative alert
+ (void)standardAlertWithMessageText:(NSString *)message withInformationText:(NSString *)information withParentWindow:(NSWindow *)parent;
//Get chapters using QTKit
+ (NSMutableArray *)quicktimeChaptersFromFile:(NSString *)path;

@end