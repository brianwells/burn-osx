#import "KWDataView.h"
#import "KWDataController.h"

@implementation KWDataView

- (void)awakeFromNib
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setViewState:) name:@"KWSetDropState" object:nil];
}

- (id)initWithFrame:(NSRect)frameRect
{
	if ((self = [super initWithFrame:frameRect]) != nil) 
		[self registerForDraggedTypes:[NSArray arrayWithObjects:NSFilenamesPboardType, nil]];

	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[self unregisterDraggedTypes];

	[super dealloc];
}

- (void)drawRect:(NSRect)rect
{
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
    if ((NSDragOperationGeneric & [sender draggingSourceOperationMask]) == NSDragOperationGeneric)
    {
		//this means that the sender is offering the type of operation we want
		//return that we want the NSDragOperationGeneric operation that they 
		//are offering
		return NSDragOperationGeneric;
    }
    else
    {
		//since they aren't offering the type of operation we want, we have 
		//to tell them we aren't interested
		return NSDragOperationNone;
    }
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
{
    if ((NSDragOperationGeneric & [sender draggingSourceOperationMask]) == NSDragOperationGeneric)
    {
		//this means that the sender is offering the type of operation we want
		//return that we want the NSDragOperationGeneric operation that they 
		//are offering
		return NSDragOperationGeneric;
    }
    else
    {
		//since they aren't offering the type of operation we want, we have 
		//to tell them we aren't interested
		return NSDragOperationNone;
    }
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
	return YES;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
	NSPasteboard *paste = [sender draggingPasteboard];
	//gets the dragging-specific pasteboard from the sender
	NSArray *types = [NSArray arrayWithObjects:NSFilenamesPboardType, nil];
	//a list of types that we can accept
	NSString *desiredType = [paste availableTypeFromArray:types];
	NSData *carriedData = [paste dataForType:desiredType];

    if (nil == carriedData)
    {
        //the operation failed for some reason
        return NO;
    }
    else
    {
        if ([desiredType isEqualToString:NSFilenamesPboardType])
        {
            //we have a list of file names in an NSData object
            NSArray *fileArray = [paste propertyListForType:@"NSFilenamesPboardType"];
                //be caseful since this method returns id.  
                //We just happen to know that it will be an array.
            NSString *path = [fileArray objectAtIndex:0];
                //assume that we can ignore all but the first path in the list
            
			BOOL isDir;
			if ([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir])
			{
				if (isDir == YES)
				{
					[myController setDiskName:[path lastPathComponent]];
				
					NSArray *files = [[NSFileManager defaultManager] directoryContentsAtPath:path];
					NSMutableArray *fulPaths = [[NSMutableArray alloc] init];
					NSInteger i = 0;
					for (i=0;i<[files count];i++)
					{
						[fulPaths addObject:[path stringByAppendingPathComponent:[files objectAtIndex:i]]];
					}
					
					[myController addFiles:fulPaths removeFiles:YES];
					[fulPaths release];
				}
			}
        }
    }

	return YES;
}

- (void)setViewState:(NSNotification *)notif
{
	if ([[notif object] boolValue])
		[self registerForDraggedTypes:[NSArray arrayWithObjects:NSFilenamesPboardType, nil]];
	else
		[self unregisterDraggedTypes];
}

@end