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
#import <Cddb/Cddb.h>
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
        }
    }
    return sharedTrackList;
}

- (void) dealloc
{
    RELEASE(toc);
    RELEASE(artist);
    RELEASE(title);
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
        NSDictionary *cdInfo = [self getCddbResultFromCache: [toc objectForKey: @"cddbid"]];
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

                    [remote Notify: @"CDPlayer" 
                                  : 0 
                                  : iconPath 
                                  : [titleField stringValue]
                                  : msg
                                  : [NSArray array]
                                  : [NSDictionary dictionary]
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

    // without a TOC (=> no CD) we are not going to query
    // a FreeDB database
    if (sel_isEqual(action, @selector(queryCddb:))) {
        if (nil == toc)
            return NO;
    }
    return YES;
}
 
 
- (NSString *) createCddbQuery: (NSDictionary *) theTOC
{
    int i;
    NSArray *tracks;
    NSMutableString *cddbQuery;
 
    tracks = [theTOC objectForKey: @"tracks"];
    cddbQuery = [NSMutableString stringWithFormat: @"%@ %d",
                            [theTOC objectForKey: @"cddbid"],
                            [[theTOC objectForKey: @"numberOfTracks"] intValue]];
 
    for (i = 0; i < [tracks count]; i++) {
        [cddbQuery appendFormat: @" %d", [[[tracks objectAtIndex: i] objectForKey: @"offset"] intValue]];
    }
 
    [cddbQuery appendFormat: @" %d", [[theTOC objectForKey: @"discLength"] intValue] / CD_FRAMES];
 
    return cddbQuery;
}
 
 
 
- (void) queryCddb: (id) sender
{
    NSString *cddbServer;
    Cddb *cddb = nil;
 
    if (nil == toc)
        return;
 
    cddbServer = [[NSUserDefaults standardUserDefaults] objectForKey: @"FreedbSite"];
 
    if (cddbServer && [cddbServer length]) {
        int i;
        NSArray *searchPaths;
        NSString *bundlePath;
        NSBundle *bundle;
        Class bundleClass;
 
        // try to load the Cddb bundle
        searchPaths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,
                                                    NSUserDomainMask|NSLocalDomainMask|NSSystemDomainMask, YES);
 
        for (i = 0; i < [searchPaths count]; i++) {
            bundlePath = [NSString stringWithFormat: @"%@/Bundles/Cddb.bundle", [searchPaths objectAtIndex: i]];

            bundle = [NSBundle bundleWithPath: bundlePath];
            if (bundle) {
                bundleClass = [bundle principalClass];
                if (bundleClass) {
                    cddb = [bundleClass new];
                    break;
                } else {
                }
            } else {
            }
        }    // for (i = 0; i < [searchPaths count]; i++)
    }    // if (cddbServer) {
 
    if (cddb != nil) {
        NSArray *matches;
        NSDictionary *cdInfo;
        NSString *queryString = [self createCddbQuery: toc];
        NSArray *tracks;
 
        [cddb setDefaultSite: cddbServer];
        matches = [cddb query: queryString];
        if ((matches != nil) && [matches count]) {
            cdInfo = [cddb readWithCategory: [[matches objectAtIndex: 0] objectForKey: @"category"]
                            discid: [[matches objectAtIndex: 0] objectForKey: @"discid"]
                            postProcess: YES];
 
            if (cdInfo != nil) {
                int i;
                NSString *dspTitle;
 
                [self saveCddbResultInCache: [toc objectForKey: @"cddbid"] cdInfo: cdInfo];
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
                [trackListView reloadData];
            } else {   // if (cdInfo != nil)
                NSRunAlertPanel(@"CDPlayer",
                        _(@"Couldn't read CD information."),
                        _(@"OK"), nil, nil);
            }
        } else {
            NSRunAlertPanel(@"CDPlayer",
                    _(@"Couldn't find any matches."),
                    _(@"OK"), nil, nil);
        }
    } else {    // if (cddb != nil)
        NSRunAlertPanel(@"CDPlayer",
                _(@"Couldn't find Cddb bundle."),
                _(@"OK"), nil, nil);
    }
}

- (void) saveCddbResultInCache: (NSString *) discid
                        cdInfo: (NSDictionary *) cdInfo
{
    NSString *basePath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
    NSString *cacheDir = [basePath stringByAppendingPathComponent: @"CDPlayer"];
    NSString *cacheFile;
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isdir;

    if (([fm fileExistsAtPath: cacheDir isDirectory: &isdir] & isdir) == NO) {
        if ([fm createDirectoryAtPath: cacheDir attributes: nil] == NO) {
            NSLog(@"unable to create: %@", cacheDir);
            return;
        }
    }
    cacheDir = [cacheDir stringByAppendingPathComponent: @"discinfo"];

    if (([fm fileExistsAtPath: cacheDir isDirectory: &isdir] & isdir) == NO) {
        if ([fm createDirectoryAtPath: cacheDir attributes: nil] == NO) {
            NSLog(@"unable to create: %@", cacheDir);
            return;
        }
    }
    cacheFile = [cacheDir stringByAppendingPathComponent: discid];
    if ([fm fileExistsAtPath: cacheFile isDirectory: &isdir] == NO) {
        [cdInfo writeToFile: cacheFile atomically: YES];
    }
}

- (NSDictionary *) getCddbResultFromCache: (NSString *) discid
{
    NSDictionary *result = nil;
    NSString *basePath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
    NSString *cacheDir = [basePath stringByAppendingPathComponent: @"CDPlayer"];
    NSString *cacheFile;
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isdir;

    // Automatically query CDDB if not turned off and if disc is present
    if (nil != toc) {
        NSUserDefaults	*defaults = [NSUserDefaults standardUserDefaults];
        if (![defaults integerForKey: @"SuppressAutomaticCddbQuery"]) {
            [self queryCddb: self];
        }
    }
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
