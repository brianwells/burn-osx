#import "growlController.h"

@implementation growlController

/////////////////////
// Default actions //
/////////////////////

#pragma mark -
#pragma mark •• Default actions

- (id) init
{
self = [super init];
[GrowlApplicationBridge setGrowlDelegate:self];
[self registrationDictionaryForGrowl];
	
[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(finishedConverting:) name:@"growlFinishedConverting" object:nil];
[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(failedConverting:) name:@"growlFailedConverting" object:nil];
[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(finishedBurning:) name:@"growlFinishedBurning" object:nil];
[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(failedBurning:) name:@"growlFailedBurning" object:nil];
[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(createdDiskImage:) name:@"growlCreateImage" object:nil];
[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(failedDiskImage:) name:@"growlFailedImage" object:nil];
[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(finishedErasing:) name:@"growlFinishedErasing" object:nil];
[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(failedErasing:) name:@"growlFailedErasing" object:nil];

return self;
}

- (void)dealloc
{
[super dealloc];
}

- (NSDictionary *)registrationDictionaryForGrowl
{
NSArray *notifications = [NSArray arrayWithObjects:NSLocalizedString(@"Finished converting",@"Localized"),NSLocalizedString(@"Failed converting",@"Localized"),NSLocalizedString(@"Finished burning",@"Localized"),NSLocalizedString(@"Burning failed",@"Localized"),NSLocalizedString(@"Image created",@"Localized"),NSLocalizedString(@"Image failed",@"Localized"),NSLocalizedString(@"Finished erasing",@"Localized"),NSLocalizedString(@"Erasing failed",@"Localized"), nil];

return [NSDictionary dictionaryWithObjectsAndKeys:notifications, GROWL_NOTIFICATIONS_ALL, notifications, GROWL_NOTIFICATIONS_DEFAULT, nil];
}

//////////////////////////
// Notification actions //
//////////////////////////

#pragma mark -
#pragma mark •• Notification actions

- (void)finishedConverting:(NSNotification *)notif
{
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWUseSoundEffects"])
	[[NSSound soundNamed:@"complete"] play];

[GrowlApplicationBridge notifyWithTitle:NSLocalizedString(@"Finished converting",@"Localized") description:[notif object] notificationName:NSLocalizedString(@"Finished converting",@"Localized") iconData:[NSData dataWithData:[[NSImage imageNamed:@"Burn"] TIFFRepresentation]] priority:0 isSticky:NO clickContext:nil];
}

- (void)failedConverting:(NSNotification *)notif
{
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWUseSoundEffects"])
	[[NSSound soundNamed:@"Basso"] play];

[GrowlApplicationBridge notifyWithTitle:NSLocalizedString(@"Failed converting",@"Localized") description:[notif object] notificationName:NSLocalizedString(@"Failed converting",@"Localized") iconData:[NSData dataWithData:[[NSImage imageNamed:@"Burn"] TIFFRepresentation]] priority:0 isSticky:NO clickContext:nil];
}

- (void)finishedBurning:(NSNotification *)notif
{
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWUseSoundEffects"])
	[[NSSound soundNamed:@"complete"] play];

[GrowlApplicationBridge notifyWithTitle:NSLocalizedString(@"Finished burning",@"Localized") description:[notif object] notificationName:NSLocalizedString(@"Finished burning",@"Localized") iconData:[NSData dataWithData:[[NSImage imageNamed:@"Burn"] TIFFRepresentation]] priority:0 isSticky:NO clickContext:nil];
}

- (void)failedBurning:(NSNotification *)notif
{
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWUseSoundEffects"])
	[[NSSound soundNamed:@"Basso"] play];

[GrowlApplicationBridge notifyWithTitle:NSLocalizedString(@"Burning failed",@"Localized") description:[notif object] notificationName:NSLocalizedString(@"Burning failed",@"Localized") iconData:[NSData dataWithData:[[NSImage imageNamed:@"Burn"] TIFFRepresentation]] priority:0 isSticky:NO clickContext:nil];
}

- (void)createdDiskImage:(NSNotification *)notif
{
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWUseSoundEffects"])
	[[NSSound soundNamed:@"complete"] play];

[GrowlApplicationBridge notifyWithTitle:NSLocalizedString(@"Image created",@"Localized") description:[notif object] notificationName:NSLocalizedString(@"Image created",@"Localized") iconData:[NSData dataWithData:[[NSImage imageNamed:@"Burn"] TIFFRepresentation]] priority:0 isSticky:NO clickContext:nil];
}

- (void)failedDiskImage:(NSNotification *)notif
{
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWUseSoundEffects"])
	[[NSSound soundNamed:@"Basso"] play];

[GrowlApplicationBridge notifyWithTitle:NSLocalizedString(@"Image failed",@"Localized") description:[notif object] notificationName:NSLocalizedString(@"Image failed",@"Localized") iconData:[NSData dataWithData:[[NSImage imageNamed:@"Burn"] TIFFRepresentation]] priority:0 isSticky:NO clickContext:nil];
}

- (void)finishedErasing:(NSNotification *)notif
{
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWUseSoundEffects"])
	[[NSSound soundNamed:@"complete"] play];

[GrowlApplicationBridge notifyWithTitle:NSLocalizedString(@"Finished erasing",@"Localized") description:[notif object] notificationName:NSLocalizedString(@"Finished erasing",@"Localized") iconData:[NSData dataWithData:[[NSImage imageNamed:@"Burn"] TIFFRepresentation]] priority:0 isSticky:NO clickContext:nil];
}

- (void)failedErasing:(NSNotification *)notif
{
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWUseSoundEffects"])
	[[NSSound soundNamed:@"Basso"] play];

[GrowlApplicationBridge notifyWithTitle:NSLocalizedString(@"Erasing failed",@"Localized") description:[notif object] notificationName:NSLocalizedString(@"Erasing failed",@"Localized") iconData:[NSData dataWithData:[[NSImage imageNamed:@"Burn"] TIFFRepresentation]] priority:0 isSticky:NO clickContext:nil];
}

@end
