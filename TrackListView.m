/* vim: set ft=objc ts=4 sw=4 expandtab nowrap: */
/*
 *  TrackListView.m
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

#include "TrackListView.h"

/* This class is for displaying the drag image.
 */
@interface TrackTable : NSTableView
{
}

@end

@implementation TrackTable

- (NSImage *) dragImageForRows: (NSArray *) dragRows
                         event: (NSEvent *) dragEvent 
               dragImageOffset: (NSPoint *) dragImageOffset
{
    if ([dragRows count] > 1) {
        return [NSImage imageNamed: @"iconDnDAudioMulti.tiff"];
    } else {
        return [NSImage imageNamed: @"iconDnDAudio.tiff"];
    }
}


- (NSDragOperation) draggingSourceOperationMaskForLocal: (BOOL) isLocal
{
    if (isLocal) {
        return [super draggingSourceOperationMaskForLocal: isLocal];
    } else {
        return NSDragOperationPrivate;
    }
}

@end


@implementation TrackListView

- (id) initWithFrame: (NSRect) frameRect
{
    NSTableColumn *column;
    NSRect frame = NSMakeRect(0,0,frameRect.size.width,frameRect.size.height);

    self = [super initWithFrame: frameRect];
    if (self) {
        table = [[TrackTable alloc] initWithFrame: frame];
        [table setIntercellSpacing: NSMakeSize (0.0, 0.0)];
        [table setAllowsMultipleSelection: YES];
        [table setAllowsEmptySelection: NO];
        [table setAllowsColumnSelection: NO];
        [table setDrawsGrid: NO];
        [table setAllowsColumnResizing: YES];
        [table setAutoresizesAllColumnsToFit: YES];
        [table setVerticalMotionCanBeginDrag: YES];
        [table setTarget: self];
        [table setDoubleAction: @selector(tableDoubleClicked:)];
        // we set the delegate and data source in awakeFromNib!!
        // we don't know them, yet!!

        column = [[NSTableColumn alloc] initWithIdentifier: @"Nr"];
        [column setEditable: NO];
        [column setResizable: YES];
        [[column headerCell] setStringValue: _(@"Nr")];
        [[column dataCell] setAlignment: NSCenterTextAlignment];
        [[column dataCell] setDrawsBackground: YES];
        [column setMinWidth: 20];
        [column setMaxWidth: 40];
        [column setWidth: 30];

        [table addTableColumn: column];
        [column release];

        column = [[NSTableColumn alloc] initWithIdentifier: @"Artist"];
        [column setEditable: NO];
        [column setResizable: YES];
        [[column headerCell] setStringValue: _(@"Artist")];
        [[column dataCell] setDrawsBackground: YES];
        [column setMinWidth: 20];
        [column setMaxWidth: 100000];
        [column setWidth: 120];

        [table addTableColumn: column];
        [column release];

        column = [[NSTableColumn alloc] initWithIdentifier: @"Title"];
        [column setEditable: NO];
        [column setResizable: YES];
        [[column headerCell] setStringValue: _(@"Title")];
        [[column dataCell] setDrawsBackground: YES];
        [column setMinWidth: 20];
        [column setMaxWidth: 100000];
        [column setWidth: 120];

        [table addTableColumn: column];
        [column release];

        column = [[NSTableColumn alloc] initWithIdentifier: @"Duration"];
        [column setEditable: NO];
        [column setResizable: NO];
        [[column headerCell] setStringValue: _(@"Duration")];
        [[column dataCell] setAlignment: NSRightTextAlignment];
        [[column dataCell] setDrawsBackground: YES];
        [column setMinWidth: 20];
        [column setMaxWidth: 80];
        [column setWidth: 80];

        [table addTableColumn: column];
        [column release];

        scroll = [[NSScrollView alloc] initWithFrame: frame];
        [scroll setHasHorizontalScroller: NO];
        [scroll setHasVerticalScroller: YES];
        [scroll setDocumentView: table];
        [scroll setBorderType: NSBezelBorder];
        [scroll setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];

        [self addSubview: scroll];
    }

    return self;
}

- (void) dealloc
{
    [table release];
    [scroll release];
    [super dealloc];
}

- (void) awakeFromNib
{
    [table setDelegate: delegate];
    [table setDataSource: delegate];
}

- (void) reloadData
{
    [table reloadData];
}

- (void) forwardInvocation: (NSInvocation *)invocation
{
    if ([table respondsToSelector: [invocation selector]])
        [invocation invokeWithTarget: table];
    else
        [self doesNotRecognizeSelector: [invocation selector]];
}

- (void) tableDoubleClicked: (id)sender
{
    int track = [table selectedRow]+1;
    NSDictionary* dict = [NSDictionary dictionaryWithObjectsAndKeys:
                [NSNumber numberWithInt: track], @"Track", nil];

    [[NSNotificationCenter defaultCenter]
            postNotificationName: @"PlayTrack"
                          object: nil
                        userInfo: dict];
}

@end
