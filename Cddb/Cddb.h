/*
**  Cddb.h
**
**  Copyright (c) 2002
**
**  Author: Yen-Ju  <yjchenx@hotmail.com>
**
**  This program is free software; you can redistribute it and/or modify
**  it under the terms of the GNU Lesser General Public License as published by
**  the Free Software Foundation; either version 2 of the License, or
**  (at your option) any later version.
**
**  This program is distributed in the hope that it will be useful,
**  but WITHOUT ANY WARRANTY; without even the implied warranty of
**  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
**  GNU General Public License for more details.
**
**  You should have received a copy of the GNU Lesser General Public License
**  along with this program; if not, write to the Free Software
**  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/

#import <Foundation/Foundation.h>

#define CD_FPS 75
#define FRAMES_TO_MSF(f, M, S, F) {                                     \
        int value = f;                                                  \
        *(F) = value%CD_FPS;                                            \
        value /= CD_FPS;                                                \
        *(S) = value%60;                                                \
        value /= 60;                                                    \
        *(M) = value;                                                   \
}
#define FRAMES_TO_SECONDS(f, s) \
        s = f / CD_FPS;

@interface Cddb: NSObject
{
  NSURL *defaultSite;
  NSFileHandle *fileHandler;
  int level;
}

/* If the return value is NSString or NSDictionary, nil for nothing (failed).
 * If the return value is NSArray, empty array for nothing (failed), not nil.
 */

- (BOOL) connect; /* return YES when success. */
- (void) disconnect;
- (NSString *) request: (NSString *) command;

/* High-level methods*/
/* Return the discid either through cddb site or calculated locally
 * The number of object in NSArray are the number of tracks.
 * The keys of NSDictionary are "length" and "offset".
 */
- (NSString *) discidWithCDTracks: (NSArray *) tracks
                          locally: (BOOL) locally;

/* Return the query using a NSArray of NSDictionary.
 * The number of object in NSArray are the number of tracks.
 * The keys of NSDictionary are "length" and "offset".
 * The return value are a NSArray of NSDictionary.
 * The keys of return NSDictionary are "category", "discid", "description".
 */
- (NSArray *) queryWithCDTracks: (NSArray *) tracks;

/* Return the read using category and discid
 * The class of objects and keys of returned value are:
 * NSString, "discid"
 * NSString, "album"
 * NSString, "year" (level 4 or up)
 * NSString, "genre" (level 4 or up)
 * NSArray, "titles" (title of each track)
 * NSString, "extdata" (extra data about this album)
 * NSArray, "exttitles" (extra-title of each track)
 */
- (NSDictionary *) readWithCategory: (NSString *) category
                             discid: (NSString *) discid
                        postProcess: (BOOL) postProcess;

/* Low-level methods */
/* Input format:
 * "category discid"
 */
- (NSDictionary *) read: (NSString *) input;

/* Input format:
 * "discid ntrks off_1 off_2 ... off_n nsecs"
 * The returned array of NSDictionary have these keys:
 * "category", "discid", "description"
 */
- (NSArray *) query: (NSString *) input;

/* It would be better to calculate it locally.
 * Input format:
 * "ntrks off_1 off_2 ... off_n nsecs"
 */
- (NSString *) discid: (NSString *) input;

/* Array of NSDictionary, the keys are:
 * site, port, latitude, longitude, description
 */
- (NSArray *) sites;

- (NSArray *) category;
- (NSString *) version;
- (int) proto; /* Ask the proto */
- (int) proto: (int) level; /* Set proto, and return the result */

- (void) setDefaultSite: (NSString *) site;
- (NSString *) defaultSite;

@end
