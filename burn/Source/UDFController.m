#import "UDFController.h"

@implementation UDFController

- (id) init
{
	if (self = [super init])
	{
		// Like in other places, we're doing an object tag -> property mapping to easily
		// convert between the two worlds.
		propertyMappings = [[NSArray alloc] initWithObjects:	DRCreationDate,					//0
																DRContentModificationDate,		//1
																DRAttributeModificationDate,	//2
																DRAccessDate,					//3
																DRBackupDate,					//4
																DREffectiveDate,				//5
																DRExpirationDate,				//6
																DRRecordingDate,				//7
																DRPosixFileMode,				//8
																DRPosixUID,						//9
																DRPosixGID,						//10
																DRInvisible,					//11
																nil];
	}
	
	return self;
}

- (NSString*) filesystem
{
// We're the controller for the UDF filesystem, so return the correct value.
return DRUDF;
}

- (DRFilesystemInclusionMask) mask
{
// We're the controller for the UDF filesystem, so return the correct value.
return DRFilesystemInclusionMaskUDF;
}

- (void)updateSpecific
{
[invisible setObjectValue:[self getPropertyForKey:DRInvisible]];

[effectiveDate setObjectValue:[self getPropertyForKey:[propertyMappings objectAtIndex:[effectiveDate tag]]]];
[expirationDate setObjectValue:[self getPropertyForKey:[propertyMappings objectAtIndex:[expirationDate tag]]]];
[recordingDate setObjectValue:[self getPropertyForKey:[propertyMappings objectAtIndex:[recordingDate tag]]]];
}

@end
