/* vim: set ft=objc ts=4 sw=4 expandtab nowrap: */
/*
 *  TrackList.m
 *
 *  Copyright (c) 2003, 2012
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


#import <AppKit/AppKit.h>
#import <AudioCD/AudioCDProtocol.h>

#ifdef NOTIFICATIONS
#import <DBusKit/DBusKit.h>
#endif

#import "TrackList.h"

static TrackList *sharedTrackList = nil;

//
// DBus stuff
#ifdef NOTIFICATIONS
@protocol Notifications
- (NSNumber *) Notify: (NSString *) appname
                     : (uint) replaceid
                     : (NSString *) appicon
                     : (NSString *) summary
                     : (NSString *) body
                     : (NSArray *) actions
                     : (NSDictionary *) hints
                     : (int) expires;
@end

static NSString * const DBUS_BUS = @"org.freedesktop.Notifications";
static NSString * const DBUS_PATH = @"/org/freedesktop/Notifications";

static const long MSG_TIMEOUT = 10000;
#endif


@implementation TrackList


- (id) init
{
    [self initWithNibName: @"TrackList"];
    return self;
}


- (id) initWithNibName: (NSString *) nibName;
{
    if (sharedTrackList) {
        [self dealloc];
    } else {
        self = [super init];
        if (![NSBundle loadNibNamed: nibName owner: self]) {
            NSLog (@"Could not load nib \"%@\".", nibName);
        } else {
            sharedTrackList = self;

            artist = [[NSString alloc] initWithString: _(@"Unknown")];
            title = [[NSString alloc] initWithString: _(@"Unknown")];

            [window setTitle: _(@"Track List")];
            [window setExcludedFromWindowsMenu: YES];
            [titleField setStringValue: _(@"No CD")];

            [window setFrameAutosaveName: @"CDTrackListWindow"];
            [window setFrameUsingName: @"CDTrackListWindow"];

            pathToFrontImage = nil;
        }
    }
    return sharedTrackList;
}

- (void) dealloc
{
    RELEASE(toc);
    RELEASE(artist);
    RELEASE(title);
#ifdef MUSICBRAINZ
    RELEASE(pathToFrontImage);
#endif
    [super dealloc];
}

- (void) activate
{
    [window makeKeyAndOrderFront: self];
}

- (BOOL) isVisible
{
    return [window isVisible];
}

- (NSString *) artist
{
    return artist;
}

- (NSString *) title
{
    return title;
}

- (NSString *) cdTitle
{
    return [titleField stringValue];
}

- (NSString *) trackTitle: (int) track
{
    NSString *msg = nil;
 
    if (track >= 0) {
        if (nil == toc) {
            msg = [NSString stringWithFormat: _(@"Track %d"), track];
        } else {
            NSArray *tracks = [toc objectForKey: @"tracks"];

            msg = [NSString stringWithFormat: @"%@",
                [[tracks objectAtIndex: track-1] objectForKey: @"title"]];
        }
    }
    return msg;
}

- (void) setTOC: (NSDictionary *) newTOC
{
    ASSIGN(toc, newTOC);
    DESTROY(artist);
    DESTROY(title);

    if (!toc) {
        [titleField setStringValue: _(@"No CD")];
    } else {
        /*
         * Try to get locally cached cddb data for the CD.
         */
        NSDictionary *cdInfo = nil;
        // TODO: CD Text

        if (cdInfo == nil) {
            // try to read (legacy) cache file
            cdInfo = [self getCdInfoFromCache: [toc objectForKey: @"cddbid"]];
        }
#ifdef MUSICBRAINZ
        if (cdInfo == nil) {
            cdInfo = [self queryMusicbrainz];
        }
#endif
#ifdef CDDB
        if (cdInfo == nil) {
            // Automatically query CDDB if disc is present
            cdInfo = [self queryCddb];
        }
#endif
        if (cdInfo != nil) {
            int i;
            NSString *dspTitle;
            NSArray *tracks;
 
            ASSIGN(artist, [[cdInfo objectForKey: @"artists"] objectAtIndex: 0]);
            ASSIGN(title, [cdInfo objectForKey: @"album"]);
 
            dspTitle = [NSString stringWithFormat: @"%@ - %@", artist, title];
 
            [titleField setStringValue: dspTitle];
 
            tracks = [toc objectForKey: @"tracks"];
 
            for (i = 0; i < [tracks count]; i++) {
                [[tracks objectAtIndex: i] setObject: [[cdInfo objectForKey: @"titles"] objectAtIndex: i]
                                            forKey: @"title"];
                [[tracks objectAtIndex: i] setObject: [[cdInfo objectForKey: @"artists"] objectAtIndex: i]
                                            forKey: @"artist"];
            }
        } else {
            artist = [[NSString alloc] initWithString: _(@"Unknown")];
            title = [[NSString alloc] initWithString: _(@"Unknown")];
            [titleField setStringValue: [NSString stringWithFormat: @"%@: %@", _(@"CD"), [toc objectForKey: @"cddbid"]]];
        }
    }

    [trackListView reloadData];
    [[NSApp mainMenu] update];
}

- (void) setPlaysTrack: (int) track andNotify: (BOOL) andNotify
{
    NSString *msg = [self trackTitle: track];

#ifdef NOTIFICATIONS
    if ((playsTrack != track) && andNotify) {
        // display message
        NSConnection *c;
        id <NSObject,Notifications> remote;

        NS_DURING {
            c = [NSConnection
                connectionWithReceivePort: [DKPort port]
                                 sendPort: [[DKPort alloc] initWithRemote: DBUS_BUS]];

            if (c) {
                remote = (id <NSObject,Notifications>)[c proxyAtPath: DBUS_PATH];
                if (remote) {
                    NSBundle *bundle = [NSBundle bundleForClass: [self class]];
                    NSString *iconPath = [bundle pathForResource: @"app" ofType: @"tiff"];
#ifdef MUSICBRAINZ
                    if (nil != pathToFrontImage) {
                        iconPath = pathToFrontImage;
                    }
#endif

                    [remote Notify: @"CDPlayer" 
                                  : 0 
                                  : @""
                                  : [titleField stringValue]
                                  : msg
                                  : [NSArray array]
                                  : [NSDictionary dictionaryWithObjectsAndKeys: iconPath, @"image-path", nil]
                                  : MSG_TIMEOUT];
                }
                [c invalidate];
            }
        }
        NS_HANDLER
        {
        }
        NS_ENDHANDLER
    }
#endif
    if (playsTrack == track) {
        return;
    }
    playsTrack = track;

    if (track >= 0) {
        [[[NSApp iconWindow] contentView] setToolTip:
            [NSString stringWithFormat: _(@"CD: %@\nTrack: %@"), [titleField stringValue], msg]];
    } else {
        [[[NSApp iconWindow] contentView] setToolTip: @""];
    }
    [trackListView reloadData];
}
 
- (BOOL) validateMenuItem: (NSMenuItem*) item
{
    SEL action = [item action];

#ifdef CDDB
    // without a TOC (=> no CD) we are not going to query
    // a FreeDB database
    if (sel_isEqual(action, @selector(queryCddb:))) {
        if (nil == toc)
            return NO;
    }
#endif
    return YES;
}

- (NSDictionary *) getCdInfoFromCache: (NSString *) discid
{
    NSDictionary *result = nil;
    NSString *basePath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
    NSString *cacheDir = [basePath stringByAppendingPathComponent: @"CDPlayer"];
    NSString *cacheFile;
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isdir;

    if (([fm fileExistsAtPath: cacheDir isDirectory: &isdir] & isdir) == NO) {
        return nil;
    }
    cacheDir = [cacheDir stringByAppendingPathComponent: @"discinfo"];

    if (([fm fileExistsAtPath: cacheDir isDirectory: &isdir] & isdir) == NO) {
        return nil;
    }
    cacheFile = [cacheDir stringByAppendingPathComponent: discid];
    result = [[NSDictionary alloc] initWithContentsOfFile: cacheFile];
    return result;
}

- (int) numberOfTracksInTOC
{
    if (!toc)
        return 0;
    else
        return [[toc objectForKey: @"numberOfTracks"] intValue];
}


//
// NSTableView data source methods
//
- (int) numberOfRowsInTableView: (NSTableView *) tableView
{
    return [self numberOfTracksInTOC];
}

- (id) tableView: (NSTableView *) tableView
    objectValueForTableColumn: (NSTableColumn *) tableColumn
                          row: (int) rowIndex
{
    NSString *identifier = [tableColumn identifier];
    NSArray *tracks = [toc objectForKey: @"tracks"];
    NSDictionary *track = nil;

    if ([identifier isEqual: @"Nr"])
        return [NSString stringWithFormat: @"%02d", rowIndex+1];

    track = [tracks objectAtIndex: rowIndex];
    if ([identifier isEqual: @"Duration"]) {
        long min, sec, frames;
        long totalTime;     // Frames

        totalTime = [[track objectForKey: @"length"] intValue];

        frames = totalTime % 75;
        sec = totalTime / 75;
        min = sec / 60;
        sec = sec % 60;

        return [NSString stringWithFormat: @"%02d:%02d.%02d", min, sec, frames];
    }
    if ([identifier isEqual: @"Artist"]) {
        return [track objectForKey: @"artist"];
    }
    if ([[track objectForKey: @"type"] isEqualToString: @"data"])
        return [NSString stringWithFormat: _(@"%@ [Data]"),
                                        [track objectForKey: @"title"]];
    else
        return [track objectForKey: @"title"];
}

- (void)  tableView: (NSTableView *) tableView
    willDisplayCell: (id) cell 
     forTableColumn: (NSTableColumn *) tableColumn
                row: (int) rowIndex
{
    NSColor *color = nil;
    if (rowIndex == playsTrack-1) {
        [cell setFont: [NSFont boldSystemFontOfSize: 0]];
        color = [NSColor colorWithDeviceRed: 0.88
                                      green: 0.88
                                       blue: 1.0
                                      alpha: 1.0];
    } else {
        [cell setFont: [NSFont systemFontOfSize: 0]];
        color = [NSColor controlBackgroundColor];
    }
    if ([tableView isRowSelected: rowIndex]) {
        color = [NSColor selectedControlColor];
    }
    [cell setHighlighted: [tableView isRowSelected: rowIndex]];
    [cell setBackgroundColor: color];
}

- (BOOL) tableView: (NSTableView *) tableView
         writeRows: (NSArray *) rows
      toPasteboard: (NSPasteboard *) pboard
{
    int i;
    NSMutableDictionary *propertyList;
    NSMutableDictionary *cdProperties;
    NSMutableArray *tracks;

    propertyList = [[NSMutableDictionary alloc] initWithCapacity: 1];
    cdProperties = [[NSMutableDictionary alloc] initWithCapacity: 3];
    tracks = [[NSMutableArray alloc] initWithCapacity: [rows count]];

    [cdProperties setObject: artist forKey: @"artist"];
    [cdProperties setObject: title forKey: @"title"];

    for (i = 0; i < [rows count]; i++) {
        int row;
        id track;
        NSMutableDictionary *addTrack = [NSMutableDictionary new];

        row = [[rows objectAtIndex: i] intValue];
        track = [[toc objectForKey: @"tracks"] objectAtIndex: row];

        [addTrack setObject: [track objectForKey: @"title"]
                     forKey: @"title"];
        [addTrack setObject: [track objectForKey: @"length"]
                     forKey: @"length"];
        [addTrack setObject: [track objectForKey: @"type"]
                     forKey: @"type"];
        [addTrack setObject: [NSString stringWithFormat: @"%d", row+1]
                     forKey: @"index"];

        [tracks addObject: [addTrack autorelease]];
    }

    // add properties for tracks and cd to proplist
    [cdProperties setObject: tracks
                     forKey: @"tracks"];
    [propertyList setObject: cdProperties
                     forKey: [toc objectForKey: @"cddbid"]];

    // Set property list of paste board
    [pboard declareTypes: [NSArray arrayWithObject: @"AudioCDPboardType"]
                   owner: self];
    [pboard setPropertyList: propertyList forType: @"AudioCDPboardType"];
    RELEASE(propertyList);
 
    return YES;
}

- (id)validRequestorForSendType: (NSString *)sendType
                     returnType: (NSString *)returnType
{
    if (!returnType && [sendType isEqual: @"AudioCDPboardType"]) {
        if ([trackListView numberOfSelectedRows] > 0)
            return self;
    }
    return nil;
}

- (BOOL) writeSelectionToPasteboard: (NSPasteboard *) pboard
                              types: (NSArray * )types
{
    BOOL ret;
    id row;
    NSMutableArray *array = [NSMutableArray new];
    NSEnumerator *selectedRows = [trackListView selectedRowEnumerator];

    if ([types containsObject: @"AudioCDPboardType"] == NO) {
        return NO;
    }

    /*
     * Add selected rows to the array and make myself write the
     * corresponding track data to the pasteboard.
     */
    while ((row = [selectedRows nextObject]) != 0) {
        [array addObject: row];
    }

    ret = [self tableView: trackListView
                writeRows: array
             toPasteboard: pboard];

    RELEASE(array);
    return ret;
}

+ (void) initialize
{
    static BOOL initialized = NO;

    /* Make sure code only gets executed once. */
    if (initialized == YES) return;
    initialized = YES;

    [NSApp registerServicesMenuSendTypes: [NSArray arrayWithObjects: @"AudioCDPboardType", nil]
                             returnTypes: nil];

    return;
}

+ (id) sharedTrackList
{
    if (sharedTrackList == nil) {
        sharedTrackList = [[TrackList alloc] init];
    }

    return sharedTrackList;
}

@end
