/* All Rights reserved */

#include <AppKit/AppKit.h>
#include "AudioCD_SysPrefs.h"
#include "AudioCDView.h"

@interface AudioCD (Private)

- (void) preferencesFromDefaults;
- (void) updateUI;

@end

@implementation AudioCD (Private)

static NSUserDefaults		*defaults = nil;
static NSMutableDictionary	*domain = nil;
static NSMutableArray		*devices = nil;

- (void) preferencesFromDefaults
{
	devices = [[domain objectForKey: @"Devices"] mutableCopy];

	if (!devices) {
		devices = [NSMutableArray new];
	}

	return;
}

- (void) updateUI
{
	[driveList reloadData];
	return;
}

@end

@implementation AudioCD


- (void)mainViewDidLoad
{
	defaults = [NSUserDefaults standardUserDefaults];
	domain = [[defaults persistentDomainForName: @"AudioCD"] mutableCopy];
	if (domain == nil) {
		domain = [NSMutableDictionary new];
		[defaults setPersistentDomain: domain forName: @"AudioCD"];
		[defaults synchronize];
	}
	[self preferencesFromDefaults];

	[self updateUI];
}

- (int) numberOfRowsInTableView: (NSTableView *) aTableView
{
	return [devices count];
}

- (id) tableView: (NSTableView *) aTableView
			objectValueForTableColumn: (NSTableColumn *) aTableColumn
			row: (int) rowIndex
{
	return [devices objectAtIndex: rowIndex];
}

- (void) addButtonClicked: (id)sender
{
	NSString *newDev = [driveInput stringValue];

	if (!newDev || ![newDev length])
		return;

	[devices addObject: newDev];
	[driveInput setStringValue: @""];

	[self updateUI];

	[domain setObject: devices forKey: @"Devices"];
	[defaults setPersistentDomain: domain forName: @"AudioCD"];
	[defaults synchronize];

	[self updateUI];

	return;
}


- (void) removeButtonClicked: (id)sender
{
	int i;

	for (i = [driveList numberOfRows]-1; i >= 0; i--) {
		if ([driveList isRowSelected: i]){
			[devices removeObjectAtIndex: i];
		}
	}
	if ([devices count] != 0)
		[domain setObject: devices forKey: @"Devices"];
	else
		[domain removeObjectForKey: @"Devices"];

	[defaults setPersistentDomain: domain forName: @"AudioCD"];
	[defaults synchronize];

	[self updateUI];

	return;
}

@end
