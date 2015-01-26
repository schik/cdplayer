/* vim: set ft=objc ts=4 sw=4 expandtab nowrap: */
/*
 *  TrackList.h
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

#ifndef __TRACKLIST_H_INCLUDED
#define __TRACKLIST_H_INCLUDED


#include <AppKit/AppKit.h>

@interface TrackList : NSObject
{
    id window;
    id titleField;
    id trackListView;

    int playsTrack;
    NSDictionary *toc;
    NSString *artist;
    NSString *title;
#ifdef COVERART
    NSString *pathToFrontImage;
#endif
}

- (id) init;
- (id) initWithNibName: (NSString *) nibName;

- (void) activate;
- (BOOL) isVisible;

- (void) setTOC: (NSDictionary *) newTOC;
- (void) setPlaysTrack: (int) track andNotify: (BOOL) andNotify;

- (void) queryCddb: (id) sender;
- (NSString *) createCddbQuery: (NSDictionary *) theTOC;
- (void) saveCddbResultInCache: (NSString *) discid
                        cdInfo: (NSDictionary *) cdInfo;

- (NSString *) artist;
- (NSString *) title;
- (NSString *) cdTitle;
- (NSString *) trackTitle: (int) track;
#ifdef COVERART
- (NSImage *) getCoverArtFromCache;
#endif

/**
 * <p>Tries to retrieve cached cddb data for a CD from the local cache.
 * This method is executed exactly once when the CD has been detected.</p>
 * <br />
 * <strong>Inputs</strong><br />
 * <deflist>
 * <term>discid</term>
 * <desc>The cddb ID for the CD.</desc>
 * </deflist>
 */
- (NSDictionary *) getCddbResultFromCache: (NSString *) discid;

- (int) numberOfTracksInTOC;

- (id) validRequestorForSendType: (NSString *) sendType
                      returnType: (NSString *) returnType;

- (BOOL) writeSelectionToPasteboard: (NSPasteboard *) pboard
                              types: (NSArray *) types;

//
// class methods
//
+ (void) initialize;
+ (id) sharedTrackList;

@end

#endif
