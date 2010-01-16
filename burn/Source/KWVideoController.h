//
//  KWVideoController.h
//  Burn
//
//  Created by Maarten Foukhar on 13-09-09.
//  Copyright 2009 Kiwi Fruitware. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KWMediaListController.h"
#import <KWDVDAuthorizer.h>
#import <QTKit/QTKit.h>

@interface KWVideoController : KWMediaListController {
	
	//Options menu
	IBOutlet id dvdOptionsPopup;
	IBOutlet id divxOptionsPopup;
	
	//Variables
	NSMutableArray *VCDTableData;
	NSMutableArray *SVCDTableData;
	NSMutableArray *DVDTableData;
	NSMutableArray *DIVXTableData;
	KWDVDAuthorizer *DVDAuthorizer;
	
	NSArray *dvdOptionsMappings;
	NSArray *divxOptionsMappings;
}

//Main actions
- (void)addFile:(NSString *)path isSelfEncoded:(BOOL)selfEncoded;

//Disc creation actions
//Set type temporary to video for burning
- (void)burn:(id)sender;
//Create a track for burning
- (int)authorizeFolderAtPathIfNeededAtPath:(NSString *)path errorString:(NSString **)error;

//Other actions
//Get files from the tableData
- (NSArray *)files;
//Only DivX can be combined, since it's created using Apples framework
- (BOOL)isCombinable;
//Set an empty info
- (void)volumeLabelSelected:(NSNotification *)notif;

@end