/* vim: set ft=objc ts=4 nowrap: */
/*
 *  TrackListView.h
 *
 *  Copyright (c) 2003
 *
 *  Author: Andreas Schik <andreas@schik.de>
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#ifndef __TRACKLIST_VIEW_H_INCLUDED
#define __TRACKLIST_VIEW_H_INCLUDED

#include <AppKit/AppKit.h>

@interface TrackListView : NSView
{
	NSTableView *table;
	NSScrollView *scroll;
	id delegate;
}

- (void) tableDoubleClicked: (id)sender;

@end

#endif
