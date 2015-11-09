/* vim: set ft=objc ts=4 sw=4 expandtab nowrap: */
/*
 *  TrackList+Cddb.m
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

#import "TrackList.h"

@implementation TrackList (Cddb)
 
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
 
 
 
- (NSDictionary *) queryCddb
{
    NSString *cddbServer;
    Cddb *cddb = nil;
 
    if (nil == toc) {
        return nil;
    }
 
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
                }
            } else {
            }
        }
    } else {
        return nil;
    }
 
    NSDictionary *cdInfo = nil;
    if (cddb != nil) {
        NSArray *matches;
        NSString *queryString = [self createCddbQuery: toc];
 
        [cddb setDefaultSite: cddbServer];
        matches = [cddb query: queryString];
        if ((matches != nil) && [matches count]) {
            cdInfo = [cddb readWithCategory: [[matches objectAtIndex: 0] objectForKey: @"category"]
                            discid: [[matches objectAtIndex: 0] objectForKey: @"discid"]
                            postProcess: YES];
 
            if (cdInfo == nil) {
                NSDebugLog(@"CDPlayer: Couldn't read CD information.");
            }
        } else {
            NSDebugLog(@"CDPlayer: Couldn't find any matches.");
        }
    } else {    // if (cddb != nil)
        NSDebugLog(@"CDPlayer: Couldn't find Cddb bundle.");
    }
    return cdInfo;
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

@end
