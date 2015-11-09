/* vim: set ft=objc ts=4 sw=4 expandtab nowrap: */
/*
**  MusicBrainz.h
**
**  Copyright (c) 2015
**
**  Author: Andreas Schik <andreas@schik.de>
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


@interface MusicBrainz: NSObject
{
    NSString *agentName;
}

- (id) initWithAgentName: (NSString *)_agentName;
- (NSString *) queryMusicbrainzId: (NSString *)discId;
- (NSData *) queryCover: (NSString *)mbId;
- (NSDictionary *) queryAlbumInfoByDiscId: (NSString *)discId;

@end
