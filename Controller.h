#ifndef __CONTROLLER_H_INCLUDED
#define __CONTROLLER_H_INCLUDED

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>


@interface Controller : NSObject
{
	id player;
	id infoPanel;
	BOOL stopFifo;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification;
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication;
- (BOOL)applicationShouldTerminate:(NSApplication *)sender;
- (void)showPrefPanel:(id)sender;

@end

#endif
