#include <Foundation/NSAutoreleasePool.h>
#include <AppKit/AppKit.h>
#include "Controller.h"


int main(int argc, const char *argv[])
{
	id		pool = [NSAutoreleasePool new];
	NSApplication	*theApp;

	theApp = [NSApplication sharedApplication];
	[theApp setDelegate: [[Controller alloc] init]];

	NSApplicationMain(argc, argv);

	[pool release];
	
	return 0;
}

