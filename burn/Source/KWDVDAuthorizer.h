//
//  KWDVDAuthorizer.h
//  KWDVDAuthorizer
//
//  Created by Maarten Foukhar on 16-3-07.
//  Copyright 2007 Kiwi Fruitware. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface KWDVDAuthorizer : NSObject 
{
	NSTask *dvdauthor;
	BOOL userCanceled;
	NSTimer *timer;
	NSTask *ffmpeg;
	NSTask *spumux;
	
	NSDictionary *theme;
	
	NSNumber *progressSize;
	int fileSize;
}

//Standard DVD-Video
- (int)createStandardDVDFolderAtPath:(NSString *)path withFileArray:(NSArray *)fileArray withSize:(NSNumber *)size;
- (void)createStandardDVDXMLAtPath:(NSString *)path withFileArray:(NSArray *)fileArray;
//Standard DVD-Audio
- (int)createStandardDVDAudioFolderAtPath:(NSString *)path withFiles:(NSArray *)files;
- (void)startTimer:(NSArray *)object;
- (void)imageProgress:(NSTimer *)theTimer;

//DVD-Video with menu
//Create a menu with given files and chapters
- (int)createDVDMenuFiles:(NSString *)path withTheme:(NSDictionary *)currentTheme withFileArray:(NSArray *)fileArray withSize:(NSNumber *)size withName:(NSString *)name;

//Main actions
//Create root menu (Start and Titles)
- (BOOL)createRootMenu:(NSString *)path withName:(NSString *)name withTitles:(BOOL)titles withSecondButton:(BOOL)secondButton;
//Batch create title selection menus
- (BOOL)createSelectionMenus:(NSArray *)fileArray withChapters:(BOOL)chapters atPath:(NSString *)path;
//Create a chapter menu (Start and Chapters)
- (BOOL)createChapterMenus:(NSString *)path withFileArray:(NSArray *)fileArray;

//DVD actions
- (BOOL)createDVDMenuFile:(NSString *)path withImage:(NSImage *)image withMaskFile:(NSString *)maskFile;
//Create a xml file for dvdauthor
-(BOOL)createDVDXMLAtPath:(NSString *)path withFileArray:(NSArray *)fileArray atFolderPath:(NSString *)folderPath;
//Create DVD folders with dvdauthor
- (BOOL)authorDVDWithXMLFile:(NSString *)xmlFile withFileArray:(NSArray *)fileArray atPath:(NSString *)path;

//Theme actions
//Create menu image with titles or chapters
- (NSImage *)rootMenuWithTitles:(BOOL)titles withName:(NSString *)name withSecondButton:(BOOL)secondButton;
//Create menu image mask with titles or chapters
- (NSImage *)rootMaskWithTitles:(BOOL)titles withSecondButton:(BOOL)secondButton;
//Create menu image
- (NSImage *)selectionMenuWithTitles:(BOOL)titles withObjects:(NSArray *)objects withImages:(NSArray *)images addNext:(BOOL)next addPrevious:(BOOL)previous;
//Create menu mask
- (NSImage *)selectionMaskWithTitles:(BOOL)titles withObjects:(NSArray *)objects addNext:(BOOL)next addPrevious:(BOOL)previous;

//Other actions
- (NSImage *)getPreviewImageFromTheme:(NSDictionary *)currentTheme ofType:(int)type;
- (NSImage *)previewImage;
- (void)drawString:(NSString *)string inRect:(NSRect)rect onImage:(NSImage *)image withFontName:(NSString *)fontName withSize:(int)size withColor:(NSColor *)color useAlignment:(NSTextAlignment)alignment;
- (void)drawBoxInRect:(NSRect)rect lineWidth:(int)width onImage:(NSImage *)image;
- (void)drawImage:(NSImage *)drawImage inRect:(NSRect)rect onImage:(NSImage *)image;
- (BOOL)saveImage:(NSImage *)image toPath:(NSString *)path;
- (NSImage *)resizeImage:(NSImage *)image;

@end
