//
//  main.m
//  Burn
//
//  Created by Maarten Foukhar on 26-2-07.
//  Copyright Kiwi Fruitware 2009 . All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>

int main(int argc, char *argv[])
{
/*NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
NSArray *args = [[NSProcessInfo processInfo] arguments];
	
	if ([args count] > 1)
	{
		if ([[args objectAtIndex:1] isEqualTo:@"--help"])
		{
		fprintf(stderr,"Usage: Burn <verb> <options>\n<verb> is one of the following:\nadd\nburn\nconvert");
		//NSTask *open = [[NSTask init] alloc];
		//[open setLaunchPath:@"/usr/bin/open"];
		//[open setArguments:[NSArray arrayWithObjects:@"-a",@"Burn",[args objectAtIndex:2],nil]];
		//[open launch];
		//[[NSWorkspace sharedWorkspace] openFile:[args objectAtIndex:2] withApplication:[[NSBundle mainBundle] bundlePath]];
		}
		else if ([[args objectAtIndex:1] isEqualTo:@"add"])
		{
		[NSApp application:NSApp openFile:[args objectAtIndex:2]];
		return NSApplicationMain(argc, (const char **) argv);
		}
	}
	else
	{
	[pool release];
	return NSApplicationMain(argc, (const char **) argv);
	}
	
[pool release];*/
//return 0;
return NSApplicationMain(argc, (const char **) argv);
}
