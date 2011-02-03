#import "KWGrowlController.h"
#import "KWCommonMethods.h"

@implementation KWGrowlController

/////////////////////
// Default actions //
/////////////////////

#pragma mark -
#pragma mark •• Default actions

- (id) init
{
	self = [super init];
	
	notifications = [[NSArray alloc] initWithObjects:	NSLocalizedString(@"Finished converting",nil),
														NSLocalizedString(@"Finished burning",nil),
														NSLocalizedString(@"Image created",nil),
														NSLocalizedString(@"Finished erasing",nil),
														NSLocalizedString(@"Failed converting",nil),
														NSLocalizedString(@"Burning failed",nil),
														NSLocalizedString(@"Image failed",nil),
														NSLocalizedString(@"Erasing failed",nil),
														nil];
														
	notificationNames = [[NSArray alloc] initWithObjects:	@"growlFinishedConverting",
															@"growlFinishedBurning",
															@"growlCreateImage",
															@"growlFinishedErasing",
															@"growlFailedConverting",
															@"growlFailedBurning",
															@"growlFailedImage",
															@"growlFailedErasing",
															nil];
	
	NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
	NSInteger i;
	for (i=0;i< [notificationNames count];i++)
	{
		[defaultCenter addObserver:self selector:@selector(growlMessage:) name:[notificationNames objectAtIndex:i] object:nil];
	}
	
	[GrowlApplicationBridge setGrowlDelegate:self];
	[self registrationDictionaryForGrowl];

	return self;
}

- (void)dealloc
{
	[notifications release];
	notifications = nil;
	
	[notificationNames release];
	notificationNames = nil;

	[super dealloc];
}

- (NSDictionary *)registrationDictionaryForGrowl
{
	return [NSDictionary dictionaryWithObjectsAndKeys:notifications, GROWL_NOTIFICATIONS_ALL, notifications, GROWL_NOTIFICATIONS_DEFAULT, nil];
}

//////////////////////////
// Notification actions //
//////////////////////////

#pragma mark -
#pragma mark •• Notification actions

- (void)growlMessage:(NSNotification *)notif
{
	NSInteger index = [notificationNames indexOfObject:[notif name]];
	
		if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWUseSoundEffects"])
		{
			NSString *soundName;
			if (index > 3)
				soundName = @"Basso";
			else
				soundName = @"complete";
			
			[[NSSound soundNamed:soundName] play];
		}
	
	NSString *notificationName = [notifications objectAtIndex:index];
	
	[GrowlApplicationBridge notifyWithTitle:notificationName description:[notif object] notificationName:notificationName iconData:[NSData dataWithData:[[NSImage imageNamed:@"Burn"] TIFFRepresentation]] priority:0 isSticky:NO clickContext:nil];
}

@end