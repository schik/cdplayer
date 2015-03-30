/* vim: set ft=objc ts=4 nowrap: */
/*
 *  Player.h
 *
 *  Copyright (c) 1999 - 2003
 *
 *  Author: ACKyugo <ackyugo@geocities.co.jp>
 *	    Andreas Schik <andreas@schik.de>
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

#ifndef __PLAYER_H_INCLUDED
#define __PLAYER_H_INCLUDED

#include <AppKit/AppKit.h>

#include <AudioCD/AudioCDProtocol.h>

@class	NSTimer;

@protocol Output;

@interface Player : NSObject<CDHandlerProtocol>
{
	Class audiocdClass;
	id<AudioCDProtocol> drive;
	id<Output> output;
	BOOL outputIsThreaded;
	BOOL closingThread;
	BOOL togglePlayButton;
	BOOL togglePauseButton;
	BOOL doRepeat;

	NSTimer		*timer;

	int		currentTrack;
	BOOL	present;
	BOOL	autoPlay;
	int		currentState;

	NSWindow	*window;
	id coverArt;
	id cdLabel;
	id trackLabel;
	id timeLabel;
	id prev;
	id play;
	id pause;
	id stop;
	id next;
	id repeat;
	id eject;
	id trackList;
	id volume;
}

- init;
- (id) initWithNibName: (NSString *) nibName;

- (void) pause: (id) sender;
- (void) stop: (id) sender;
- (void) next: (id) sender;
- (void) prev: (id) sender;
- (void) eject: (id) sender;
- (void) showTrackList:(id)sender;
- (void) setVolume: (id) sender;
- (void) repeat: (id) sender;

- (void) playTrack: (NSNotification *)not;
- (void) play: (id)sender;

//
// services methods
//

- (void) getTOC: (NSPasteboard *) pboard
	   userData: (NSString *) userData
		  error: (NSString **) error;

- (void) playCD: (NSPasteboard *) pboard
	   userData: (NSString *) userData
		  error: (NSString **) error;

- (void) playCD: (NSString *) device;

//
// class methods
//
+ (Player *) sharedPlayer;

@end

#endif
