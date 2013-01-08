/* vim: set ft=objc ts=4 nowrap: */

#include <Cynthiune/Preference.h>
#include "Preferences.h"
#include "FreeDBView.h"
#include "GeneralView.h"

static	Preferences *singleInstance = nil;

@implementation Preferences

+ (id) singleInstance
{
	if (singleInstance == nil) {
		singleInstance = [[Preferences alloc] init];
	}
  
	return singleInstance;
}

- (id) init
{
	id module = nil;

	self = [super init];
	modules = [[NSMutableDictionary alloc] initWithCapacity: 2];
	
	[self layoutWindow];

	// initialise all sub panels
	module = [GeneralView singleInstance];
	if (module) {
		[modules setObject: module forKey: [(GeneralView*)module name]];
	}
	[panelList addItemWithTitle: [(GeneralView*)module name]];
	[module release];

	module = [FreeDBView singleInstance];
	if (module) {
		[modules setObject: module forKey: [(FreeDBView*)module name]];
	}
	[panelList addItemWithTitle: [(FreeDBView*)module name]];
	[module release];
  
	return self;
}

- (void) dealloc
{
	[window release];
	[panelList release];
	[saveButton release];
	[closeButton release];
	[panelBox release];

	[modules release];
  
	[super dealloc];
}

- (void) windowWillClose: (NSNotification *)theNotification
{
	AUTORELEASE(self);
	singleInstance = nil;
}

- (void) showPanel: (id) sender
{
	[panelList selectItemAtIndex: 0];
	[self showSubPanel: self];
	[NSApp runModalForWindow: window];
}

- (void) save: (id) sender
{
	int i;
	id theModules = [modules allValues];

	for (i = 0; i < [theModules count]; i++) {
		id module = [theModules objectAtIndex: i];
		if ([module conformsToProtocol: @protocol(Preference)]) {
			[module save];
		} else {
			[module saveChanges];
		}
	}

	[[NSUserDefaults standardUserDefaults] synchronize];
}

- (void) close: (id) sender
{
	[NSApp stopModal];
	[window performClose: self];
}

- (void) showSubPanel: (id) sender
{
	id module = nil;
	
	module = [modules objectForKey: [panelList titleOfSelectedItem]];

	if (module) {
		NSView *moduleView;
		if ([module conformsToProtocol: @protocol(Preference)]) {
			moduleView = [module preferenceSheet];
		} else {
			moduleView = [module view];
		}
		if ([panelBox contentView] != moduleView) {
			[panelBox setContentView: moduleView];
			[panelBox setTitle: [panelList titleOfSelectedItem]];
		}
	}
}

- (void) layoutWindow
{
	NSRect frame;
	unsigned int style = NSTitledWindowMask|NSClosableWindowMask|NSMiniaturizableWindowMask;

	frame = NSMakeRect(100, 100, 370,395);
	window = [[NSPanel alloc] initWithContentRect: frame
			    styleMask: style
			    backing: NSBackingStoreRetained
			    defer: NO];
	[window setTitle: _(@"Preferences")];
	[window setMaxSize: frame.size];
	[window setMinSize: frame.size];
  
	frame = NSMakeRect(195, 10, 80, 28);
	saveButton = [[NSButton alloc] initWithFrame: frame];
	[saveButton setButtonType: NSMomentaryPushButton];
	[saveButton setTitle: _(@"Save")];
	[saveButton setTarget: self];
	[saveButton setAction: @selector(save:)];
	[[window contentView] addSubview: saveButton];

	frame = NSMakeRect(285, 10, 80, 28);
	closeButton = [[NSButton alloc] initWithFrame: frame];
	[closeButton setTitle: _(@"Close")];
	[closeButton setTarget: self];
	[closeButton setAction: @selector(close:)];
	[[window contentView] addSubview: closeButton];

	frame = NSMakeRect(135, 315, 100, 25);
	panelList = [[NSPopUpButton alloc] initWithFrame: frame pullsDown: NO];
	[panelList setAutoenablesItems: NO];
	[panelList setEnabled: YES];
	[panelList setTarget: self];
	[panelList setAction: @selector(showSubPanel:)];
	[[window contentView] addSubview: panelList];

	panelBox = [[NSBox alloc] initWithFrame: NSMakeRect(5,45,360,265)];
	[panelBox setTitlePosition: NSAtTop];
	[panelBox setBorderType: NSGrooveBorder];
	[[window contentView] addSubview: panelBox];

	[window center];
}

- (void) registerPreferenceClass: (Class) aClass
{
	NSString *cname = NSStringFromClass (aClass);
	if ([aClass conformsToProtocol: @protocol(Preference)]
		   	&& (nil == [modules objectForKey: cname])) {
		id<Preference> module = [aClass instance];
		if (module) {
			[modules setObject: module forKey: [module preferenceTitle]];
			[panelList addItemWithTitle: [module preferenceTitle]];
			[module release];
		}
	}
}

@end
