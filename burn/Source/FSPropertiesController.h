/*
     File:       FSPropertiesController.h
 
     Contains:   Base class providing most of the functionality needed to handle
                 setting the various properties associated with the files/folders
                 in a burn hierarchy.
 
     Version:    Technology: Mac OS X
                 Release:    Mac OS X
 
     Copyright:  (c) 2002 by Apple Computer, Inc., all rights reserved
 
     Bugs?:      For bug reports, consult the following page on
                 the World Wide Web:
 
                     http://developer.apple.com/bugreporter/
*/

/*
 IMPORTANT:  This Apple software is supplied to you by Apple Computer, Inc. ("Apple") in
 consideration of your agreement to the following terms, and your use, installation, 
 modification or redistribution of this Apple software constitutes acceptance of these 
 terms.  If you do not agree with these terms, please do not use, install, modify or 
 redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and subject to these 
 terms, Apple grants you a personal, non-exclusive license, under Apple‚Äôs copyrights in 
 this original Apple software (the "Apple Software"), to use, reproduce, modify and 
 redistribute the Apple Software, with or without modifications, in source and/or binary 
 forms; provided that if you redistribute the Apple Software in its entirety and without 
 modifications, you must retain this notice and the following text and disclaimers in all 
 such redistributions of the Apple Software.  Neither the name, trademarks, service marks 
 or logos of Apple Computer, Inc. may be used to endorse or promote products derived from 
 the Apple Software without specific prior written permission from Apple. Except as expressly
 stated in this notice, no other rights or licenses, express or implied, are granted by Apple
 herein, including but not limited to any patent rights that may be infringed by your 
 derivative works or by other works in which the Apple Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE MAKES NO WARRANTIES, 
 EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, 
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS 
 USE AND OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL OR CONSEQUENTIAL 
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS 
 OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, 
 REPRODUCTION, MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED AND 
 WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE), STRICT LIABILITY OR 
 OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#import <Cocoa/Cocoa.h>
#import <DiscRecording/DiscRecording.h>

@interface FSPropertiesController : NSObject 
{
	NSArray *inspectedItems;

	IBOutlet id	included;
	IBOutlet id	contentView;
	
	IBOutlet id	baseName;
	IBOutlet id	specificName;
	IBOutlet id	mangledName;

	IBOutlet id	creationDate;
	IBOutlet id	contentModDate;
	IBOutlet id	attributeModDate;
	IBOutlet id	lastAccessedDate;
	IBOutlet id	backupDate;

	IBOutlet id	uid;
	IBOutlet id	gid;
	IBOutlet id	perms;
	
	NSArray* propertyMappings;
}

- (NSString*)filesystem;
- (DRFilesystemInclusionMask)mask;

- (void)inspect:(NSArray *)items;
- (BOOL)checkForFileSystemMasksInObjects:(NSArray *)objects;
- (BOOL)checkForFileSystemMasksInParentsOfObjects:(NSArray *)objects;
- (id)getPropertyForKey:(NSString *)key;

- (void)updateNames;
- (void)updateDates;
- (void)updatePOSIX;
- (void)updateSpecific;

- (void)clearForMultipleSelection;

- (IBAction)setIncludedBit:(id)sender;
- (IBAction)setFileName:(id)sender;
- (IBAction)setProperty:(id)sender;
- (IBAction)setPOSIXModeProperty:(id)sender;

@end