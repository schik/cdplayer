/* vim: set ft=objc ts=4 nowrap: */
/*
	AudioCDView.h

	Copyright (C) 2002

	Author: Andreas Schik <andreas@schik.de>

	This program is free software; you can redistribute it and/or
	modify it under the terms of the GNU General Public License as
	published by the Free Software Foundation; either version 2 of
	the License, or (at your option) any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

	See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public
	License along with this program; if not, write to:

		Free Software Foundation, Inc.
		59 Temple Place - Suite 330
		Boston, MA  02111-1307, USA
*/

#include <AppKit/AppKit.h>

#include "AudioCDView.h"
#if SYSPREFS==1
  #include "AudioCD_SysPrefs.h"
#else
  #include "AudioCD.h"
#endif

@implementation AudioCDView
/*
	This class shouldn't be necessary. With working "nibs", it isn't.
*/
- (id) initWithOwner: (id) anOwner andFrame: (NSRect) frameRect
{
	id temp = nil;
	NSLog(@"iwo 1");
	owner = anOwner;

	if ((self = [super initWithFrame: frameRect])) {
	NSLog(@"iwo 2");
		temp = [[NSBox alloc] initWithFrame: NSMakeRect (0, 0, 384, 176)];
		[temp setTitlePosition: NSAtTop];
		[temp setBorderType: NSGrooveBorder];
		[temp setTitle: NSLocalizedStringFromTableInBundle(@"Audio CD Drives", @"Localizable", [NSBundle bundleForClass: [self class]], @"")];
		[self addSubview: [temp autorelease]];
	NSLog(@"iwo 3");

		temp = [[NSTableColumn alloc] initWithIdentifier: @"Drives"];
		[temp setEditable: NO];
		[temp setResizable: NO];
		[[temp headerCell] setStringValue: NSLocalizedStringFromTableInBundle(@"Audio CD Drives", @"Localizable", [NSBundle bundleForClass: [self class]], @"")];
		[temp setMinWidth: 144];
		[temp setWidth: 144];
	NSLog(@"iwo 4");

		driveList = [[NSTableView alloc] initWithFrame: NSMakeRect(10,10,167,147)];
		[driveList addTableColumn: temp];
		[driveList setAllowsColumnSelection: NO];
		[driveList setAllowsColumnReordering: NO];
		[driveList setAllowsColumnResizing: NO];
		[driveList setAllowsEmptySelection: NO];
		[driveList setAllowsMultipleSelection: NO];
		[driveList setDrawsGrid: NO];
		[driveList setAutoresizesAllColumnsToFit: YES];
		[driveList sizeLastColumnToFit];
		[driveList setDelegate: owner];
		[driveList setDataSource: owner];
	NSLog(@"iwo 5");

		driveScroll = [[NSScrollView alloc] initWithFrame: NSMakeRect(10,10,167,147)];
		[driveScroll setHasHorizontalScroller: NO];
		[driveScroll setHasVerticalScroller: YES];
		[driveScroll setDocumentView: driveList];
		[driveScroll setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
	NSLog(@"iwo 6");

		[self addSubview: [driveScroll autorelease]];
	NSLog(@"iwo 1");
  
		driveInput = [[NSTextField alloc] initWithFrame: NSMakeRect(211,136,163,21)];
		[driveInput setAutoresizingMask: NSViewMinYMargin];
		[driveInput setEditable: YES];
		[driveInput setSelectable: YES];
		[driveInput setStringValue: @""];
		[self addSubview: driveInput];
	NSLog(@"iwo 7");

		addButton = [[NSButton alloc] initWithFrame: NSMakeRect (211,102,90,24)];
		[addButton setTitle: NSLocalizedStringFromTableInBundle(@"Add", @"Localizable", [NSBundle bundleForClass: [self class]], @"")];
		[addButton setTarget: owner];
		[addButton setAction: @selector(addButtonClicked:)];
		[self addSubview: [addButton autorelease]];
	NSLog(@"iwo 8");

		removeButton = [[NSButton alloc] initWithFrame: NSMakeRect (211,63,90,24)];
		[removeButton setTitle: NSLocalizedStringFromTableInBundle(@"Remove", @"Localizable", [NSBundle bundleForClass: [self class]], @"")];
		[removeButton setTarget: owner];
		[removeButton setAction: @selector(removeButtonClicked:)];
		[self addSubview: [removeButton autorelease]];
	NSLog(@"iwo 9");

	}
	NSLog(@"iwo 10");
	return self;
}

- (NSTableView *) driveList
{
	return driveList;
}

- (NSTextField *) driveInput
{
	return driveInput;
}

@end
