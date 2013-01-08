/* vim: set ft=objc ts=4 nowrap: */
/*
**  AudioCDProtocol.h
**
**  Copyright (c) 2002
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

#ifndef __AUDIOCD_PROTOCOL_H_INCLUDED
#define __AUDIOCD_PROTOCOL_H_INCLUDED

#include <Foundation/Foundation.h>

#define        CD_MSF_OFFSET   150     /* MSF offset of first frame */
#define        CD_FRAMES       75      /* per second */

@protocol CDHandlerProtocol <NSObject>

- (BOOL) audioCD: (id)sender error: (int)no message: (NSString *)msg;
- (void) audioCDChanged: (id)sender;

@end

@protocol AudioCDProtocol <NSObject>

- initWithHandler: (id<CDHandlerProtocol>)handler;

- (void) setHandler: (id<CDHandlerProtocol>)handler;

- (void) startPollingWithPreferredDevice: (NSString *)device;
- (void) stopPolling;

- (NSMutableDictionary *) readTOC;

- (void) setVolumeLevel: (float) vLevel;
- (void) start;
- (void) stop;

- (int) readNextChunk: (unsigned char *) buffer
             withSize: (unsigned int) bufferSize;
- (void) seek: (unsigned int) track;

- (void) eject;

- (BOOL) cdPresent;
- (BOOL) checkForCDWithId: (NSString *)cddbId;

- (int) currentTrack;
- (int) currentMin;
- (int) currentSec;
- (int) firstTrack;
- (int) totalTrack;
- (int) trackLength:(int)track;

@end

#endif
