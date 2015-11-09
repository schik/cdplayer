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
#import "MusicBrainz/MusicBrainz.h"

#import "TrackList.h"

static NSString *QUERY_AGENT = @"cdplayer-0.8.0";

static MusicBrainz *mb = nil;

@interface TrackList (MusicBrainzPrivate)
- (BOOL) doesCoverArtCacheExist;
- (void) loadMusicBrainzBundle;
@end

@implementation TrackList (MusicBrainzPrivate)

- (void) loadMusicBrainzBundle
{
    if (nil != mb) {
        return;
    }

    int i;
    NSArray *searchPaths;
    NSString *bundlePath;
    NSBundle *bundle;
    Class bundleClass;

    // try to load the Cddb bundle
    searchPaths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,
            NSUserDomainMask|NSLocalDomainMask|NSSystemDomainMask, YES);

    for (i = 0; i < [searchPaths count]; i++) {
        bundlePath = [NSString stringWithFormat: @"%@/Bundles/MusicBrainz.bundle",
                   [searchPaths objectAtIndex: i]];

        bundle = [NSBundle bundleWithPath: bundlePath];
        if (bundle) {
            bundleClass = [bundle principalClass];
            if (bundleClass) {
                mb = [[bundleClass alloc] initWithAgentName: QUERY_AGENT];
                break;
            }
        } else {
        }
    }

    if (nil == mb) {
        NSDebugLog(@"CDPlayer: Couldn't find MusicBrainz bundle.");
    }
}

- (BOOL) doesCoverArtCacheExist
{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *basePath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
    NSString *cacheDir = [basePath stringByAppendingPathComponent: @"CDPlayer"];
    BOOL isdir;

    if (([fm fileExistsAtPath: cacheDir isDirectory: &isdir] & isdir) == NO) {
        if ([fm createDirectoryAtPath: cacheDir attributes: nil] == NO) {
            NSLog(@"unable to create: %@", cacheDir);
            return NO;
        }
    }

    cacheDir = [cacheDir stringByAppendingPathComponent: @"coverart"];
    if (([fm fileExistsAtPath: cacheDir isDirectory: &isdir] & isdir) == NO) {
        if ([fm createDirectoryAtPath: cacheDir attributes: nil] == NO) {
            NSLog(@"unable to create: %@", cacheDir);
            return NO;
        }
    }
    return YES;
}

@end

@implementation TrackList (MusicBrainz)

- (NSDictionary *) queryMusicbrainz
{
    if (nil == toc) {
        return nil;
    }

    [self loadMusicBrainzBundle];
    if (nil == mb) {
        return nil;
    }

    NSDictionary *cdInfo = [mb queryAlbumInfoByDiscId: [toc objectForKey: @"mbDiscId"]];

    return cdInfo;
}

- (NSImage *) getCoverArtFromCache
{
    NSImage *image = nil;
    [window setMiniwindowImage: [NSApp applicationIconImage]];

    [self loadMusicBrainzBundle];
    if (nil == mb) {
        return image;
    }

    if ((nil != toc)  && [self doesCoverArtCacheExist]) {
        NSString *mbid = [mb queryMusicbrainzId: [toc objectForKey: @"mbDiscId"]];
        if ([mbid length] != 0) {
            NSFileManager *fm = [NSFileManager defaultManager];
            NSString *basePath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
            NSString *cacheDir = [basePath stringByAppendingPathComponent: @"CDPlayer"];
            cacheDir = [cacheDir stringByAppendingPathComponent: @"coverart"];
            NSString *cacheFile = [cacheDir stringByAppendingPathComponent: [NSString stringWithFormat: @"%@.jpg", mbid]];
            BOOL isdir;
            if ([fm fileExistsAtPath: cacheFile isDirectory: &isdir] == NO) {
                NSData *data = [mb queryCover: mbid];
                if (data != nil) {
                    [fm createFileAtPath: cacheFile contents: data attributes:nil];
                }
            }
            if ([fm fileExistsAtPath: cacheFile isDirectory: &isdir] == YES) {
                ASSIGN(pathToFrontImage, cacheFile);
                image = [[[NSImage alloc] initWithContentsOfFile: cacheFile] autorelease];
                NSImage *imgCopy = [image copy];
                [imgCopy setScalesWhenResized: YES];
                [imgCopy setSize: NSMakeSize(48,48)];
                [window setMiniwindowImage: imgCopy];
                RELEASE(imgCopy);
            }
        }
    }

    return image;
}

@end
