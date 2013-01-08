/* All Rights reserved */

#include <AppKit/AppKit.h>
#include "GeneralView.h"
#import <Cynthiune/Output.h>

#ifdef __MACOSX__
#define defaultOutputBundle @"MacOSXPlayer"
#else
#ifdef __linux__
#define defaultOutputBundle @"ALSA"
#else
#ifdef __OpenBSD__
#define defaultOutputBundle @"Sndio"
#else
#ifdef __WIN32__
#define defaultOutputBundle @"WaveOut"
#else
#define defaultOutputBundle @"OSS"
#endif
#endif
#endif
#endif

static GeneralView *singleInstance = nil;

@interface GeneralView (Private)

- (void) initializeFromDefaults;

@end


@implementation GeneralView(Private)

- (void) initializeFromDefaults
{
	NSUserDefaults	*defaults = [NSUserDefaults standardUserDefaults];
	NSString	*device;
	int		onExit;
	static BOOL initted = NO;

	if (!initted) {
		device = [defaults stringForKey: @"Device"];
		[deviceField setStringValue: device];

		onExit = [defaults integerForKey: @"OnExit"];
		[exitMatrix selectCellAtRow: onExit column: 0];

		outputBundle = [defaults stringForKey: @"OutputBundle"];
		if (!outputBundle
			|| !([playersList containsObject: NSClassFromString (outputBundle)])) {
		    outputBundle = defaultOutputBundle;
		}
		initted = YES;
	}
}

@end


@implementation GeneralView

- (id) init
{
	if (nil != (self = [super init])) {
		playersList = [NSMutableArray new];
		view = nil;
	}
	return self;
}

- (void) dealloc
{
	singleInstance = nil;
	TEST_RELEASE(view);
	[playersList release];
	[super dealloc];
}

- (void) awakeFromNib
{
	int count, max;
	Class currentClass;

	// We get our defaults for this panel
	[self initializeFromDefaults];

	[outputList removeAllItems];
	max = [playersList count];
	if (max > 0) {
		for (count = 0; count < max; count++) {
			currentClass = [playersList objectAtIndex: count];
			[outputList addItemWithTitle: NSStringFromClass (currentClass)];
		}
	} else {
		[outputList addItemWithTitle: @"None"];
	}

	[outputList selectItemWithTitle: outputBundle];
}

- (void) outputListChanged: (id) sender
{
  NSString *newTitle = [sender titleOfSelectedItem];
  [sender setTitle: newTitle];
  [sender synchronizeTitleAndSelectedItem];
  outputBundle = newTitle;
}


// access methods

- (NSString *) name
{
	return _(@"General");
}

- (NSView *) view
{
	if (nil == view) {
		// We link our view
		if (![NSBundle loadNibNamed: @"General" owner: self]) {
			NSLog (@"General: Could not load nib \"General\".");
		} else {
			view = [window contentView];
			[view retain];
		}
	}
	return view;
}

- (void) saveChanges
{
	NSUserDefaults	*defaults = [NSUserDefaults standardUserDefaults];
	NSString *device = [deviceField stringValue];
	[defaults setObject: device?device:@"" forKey: @"Device"];
	[defaults setInteger: [exitMatrix selectedRow] forKey: @"OnExit"];
	[defaults setObject: outputBundle forKey: @"OutputBundle"];
}

- (void) registerOutputClass: (Class) aClass
{
	if ([aClass conformsToProtocol: @protocol(Output)]) {
		if (![playersList containsObject: aClass]) {
			[playersList addObject: aClass];
		}
	} else {
		NSLog (@"Class '%@' not conform to the 'Output' protocol...\n",
			NSStringFromClass (aClass));
	}
}

- (Class) preferredOutputClass
{
	[self initializeFromDefaults];

	return NSClassFromString (outputBundle);
}


//
// class methods
//
+ (id) singleInstance
{
	if (singleInstance == nil) {
		singleInstance = [[GeneralView alloc] init];
	}

	return singleInstance;
}

@end
