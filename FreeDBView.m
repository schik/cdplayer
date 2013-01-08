/* vim: set ft=objc ts=4 nowrap: */
/* All Rights reserved */

#include <AppKit/AppKit.h>
#include "FreeDBView.h"

#include <Cddb/Cddb.h>


static FreeDBView *singleInstance = nil;

@interface FreeDBView (Private)

- (void) initializeFromDefaults;

@end


@implementation FreeDBView (Private)

- (void) initializeFromDefaults
{
	if ( [[NSUserDefaults standardUserDefaults] objectForKey: @"FreedbSite"] ) {
		[serverTextField setStringValue: [[NSUserDefaults standardUserDefaults] 
			      stringForKey: @"FreedbSite"]];
      
	}
	if ([[NSUserDefaults standardUserDefaults] objectForKey: @"AutoQueryCddb"]) {
		[autoQueryButton setState: [[[NSUserDefaults standardUserDefaults] objectForKey:
							@"AutoQueryCddb"] intValue]];
	}
}

@end


@implementation FreeDBView

- (id) init
{
	int i;
	NSBundle *bundle;
	NSString *bundlePath;
	NSArray *searchPaths;

	if (nil != (self = [super init])) {
		// try to load the Cddb bundle
		searchPaths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,
							 NSUserDomainMask|NSLocalDomainMask|NSSystemDomainMask, YES);
		for (i = 0; i < [searchPaths count]; i++) {
			bundlePath = [NSString stringWithFormat: @"%@/Bundles/Cddb.bundle",
						[searchPaths objectAtIndex: i]];

			bundle = [NSBundle bundleWithPath: bundlePath];
			if (bundle) {
				cddbClass = [bundle principalClass];
				if (cddbClass) {
					break;
				} else {
					NSLog(@"Failed to get Class from Cddb.bundle");
				}
			} else {
				NSLog(@"Failed to get Cddb.bundle from %@", bundlePath);
			}
		}	// for (i = 0; i < [searchPaths count]; i++)

		// We link our view
		if (cddbClass) {
			siteList = [NSMutableArray new];
		}
	}
	return self;
}

- (void) dealloc
{
	singleInstance = nil;
	TEST_RELEASE(view);
	RELEASE(siteList);
	[super dealloc];
}

- (void) awakeFromNib
{
	// We get our defaults for this panel
	[self initializeFromDefaults];
}

// access methods

- (NSString *) name
{
	return @"FreeDB";
}

- (NSView *) view
{
	if (nil == view) {
		// We link our view
		if (![NSBundle loadNibNamed: @"FreeDB" owner: self]) {
			NSLog (@"General: Could not load nib \"General\".");
		} else {
			view = [window contentView];
			[view retain];
		}
	}
	return view;
}

// Data Source
- (void) tableViewSelectionDidChange: (NSNotification *) not
{
	[serverTextField setStringValue: [[siteList objectAtIndex: [[not object] selectedRow]]
                 objectForKey: @"site"]];
}

- (int) numberOfRowsInTableView: (NSTableView *) aView
{
	return [siteList count];
}

- (id) tableView: (NSTableView *) aView
           objectValueForTableColumn: (NSTableColumn *) aColumn
           row: (int) row
{
	return [[siteList objectAtIndex: row] objectForKey: [aColumn identifier]];
}


- (void) listOfSites: (id)sender
{
	/* insert your code here */
	Cddb *cddb;
	NSArray *siteArray = nil;
	int i;

	cddb = [cddbClass new];
   
	[siteList removeAllObjects];
	// Always get list from main site (www.freedb.org).
	[cddb setDefaultSite: @"http://freedb.freedb.org:80/~cddb/cddb.cgi"];

	if([cddb connect]) {
		siteArray = [cddb sites];
		[cddb disconnect];
	}
  
	if (siteArray == nil) {
		NSRunAlertPanel(_(@"Can't get list from internet"),
                    _(@"Can't get the list of public freedb sites.\nMake sure you have internet connection and the connection to the official freedb site (www.freedb.org) works."),
                    _(@"OK"),
                    nil,
                    nil);
		return;
	}

	for(i = 0; i < [siteArray count]; i++) {
		NSMutableDictionary *dict = [NSMutableDictionary new];
		NSString *site;
		if([[[siteArray objectAtIndex: i] objectForKey: @"protocol"] 
        	               isEqualToString: @"http"]) {
			site = [NSString stringWithFormat: @"%@://%@:%@%@",
				[[siteArray objectAtIndex: i] objectForKey: @"protocol"],
				[[siteArray objectAtIndex: i] objectForKey: @"site"],
				[[siteArray objectAtIndex: i] objectForKey: @"port"],
				[[siteArray objectAtIndex: i] objectForKey: @"address"]];
		} else {
			site = [NSString stringWithFormat: @"%@://%@:%@",
				[[siteArray objectAtIndex: i] objectForKey: @"protocol"],
				[[siteArray objectAtIndex: i] objectForKey: @"site"],
				[[siteArray objectAtIndex: i] objectForKey: @"port"]];
		}
		[dict setObject: site forKey: @"site"];
		[dict setObject: [[siteArray objectAtIndex: i] objectForKey: @"description"]
                	 forKey: @"location"];
		[siteList addObject: dict];
	}
	[serversTableView reloadData];
}

- (void) saveChanges
{
	[[NSUserDefaults standardUserDefaults] setObject: [serverTextField stringValue]
                                         forKey: @"FreedbSite"];
}


//
// class methods
//
+ (id) singleInstance
{
	if (singleInstance == nil) {
		singleInstance = [[FreeDBView alloc] init];
	}

	return singleInstance;
}

@end
