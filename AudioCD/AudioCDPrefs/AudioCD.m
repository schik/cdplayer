/* All Rights reserved */

#include <AppKit/AppKit.h>
#include "AudioCD.h"
#include "AudioCDView.h"

@interface AudioCD (Private)

- (void) preferencesFromDefaults;
- (void) updateUI;

@end

@implementation AudioCD (Private)

static id <PrefsController>	controller;
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

static AudioCD			*sharedInstance = nil;
static id <PrefsApplication>	owner = nil;

- (id) initWithOwner: (id <PrefsApplication>) anOwner
{
	if (sharedInstance) {
		[self dealloc];
	} else {
		self = [super init];
		owner = anOwner;
		controller = [owner prefsController];
		defaults = [NSUserDefaults standardUserDefaults];
		domain = [[defaults persistentDomainForName: @"AudioCD"] mutableCopy];
		if (domain == nil) {
			domain = [NSMutableDictionary new];
			[defaults setPersistentDomain: domain forName: @"AudioCD"];
			[defaults synchronize];
		}
		[self preferencesFromDefaults];

		[controller registerPrefsModule: self];
		if (![NSBundle loadNibNamed: @"AudioCD" owner: self]) {
			NSLog (@"PrefsApp: Could not load nib \"AudioCD\", using compiled-in version");
			view = [[AudioCDView alloc] initWithOwner: self andFrame: NSMakeRect(0,0,384,176)];

			// hook up to our outlet(s)
			driveList = [view driveList];
			driveInput = [view driveInput];
		} else {
			view = [_window contentView];
		}
		[view retain];
		[self updateUI];

		sharedInstance = self;
	}
	return sharedInstance;
}

- (void) showView: (id) sender;
{
	[controller setCurrentModule: self];
	[view setNeedsDisplay: YES];
}

- (NSView *) view
{
	return view;
}

- (NSString *) buttonCaption
{
	return NSLocalizedStringFromTableInBundle(@"Audio CD Drives", @"Localizable", [NSBundle bundleForClass: [self class]], @"");
}

- (NSImage *) buttonImage
{
	NSBundle *aBundle;
	
	aBundle = [NSBundle bundleForClass: [self class]];
	
	return AUTORELEASE([[NSImage alloc] initWithContentsOfFile:
					[aBundle pathForResource: @"AudioCD" ofType: @"tiff"]]);
}

- (SEL) buttonAction
{
	return @selector(showView:);
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
