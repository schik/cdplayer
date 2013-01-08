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

#ifndef __AUDIOCD_VIEW_H_INCLUDED
#define __AUDIOCD_VIEW_H_INCLUDED

#include <AppKit/AppKit.h>


@interface AudioCDView: NSView
{
	NSTableView *driveList;
	NSScrollView *driveScroll;
	NSTextField *driveInput;
	NSButton *addButton;
	NSButton *removeButton;
	id owner;
}

- (id) initWithOwner: (id) anOwner andFrame: (NSRect) frameRect;

- (NSTableView *) driveList;
- (NSTextField *) driveInput;

@end

#endif
