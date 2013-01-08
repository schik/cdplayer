/* vim: set ft=objc ts=4 nowrap: */
/*
 *  AudioCD.m
 *
 *  Copyright (c) 2002 - 2003, 2012
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

#ifndef __AUDIOCD_H_INCLUDED
#define __AUDIOCD_H_INCLUDED

#include <Foundation/Foundation.h>
#include "AudioCDProtocol.h"
#include <cdio/cdio.h>
#include <cdio/cdda.h>
#include <cdio/cd_types.h>
#include <cdio/paranoia.h>
#include <cdio/bytesex.h>
#include <cdio/audio.h>
#include <cdio/logging.h>
#include "rb.h"

@interface AudioCD : NSObject<AudioCDProtocol>
{
	cdrom_drive_t *drive;
	cdrom_paranoia_t *paranoia;

	/**
	  * The ring buffer used internally to prefetch audio data.
	  * Necessary for fluid audio output.
	  */
	rb_t *rb;

	/**
	  * Reader thread started here. Important to calculate the
	  * current track and the offset into the track.
	  */
	lsn_t startLsn;

	/**
	  * The current reading position. Denotes the last data frame
	  * read from the internal buffer and delivered to the output.
	  */
	lsn_t currentLsn;

	/**
	  * The total amount of bytes read from the internal buffer
	  * since the reader thread started to fill the buffer.
	  * Important to calculate the current track and the offset
	  * into the track.
	  */
	unsigned int bytesRead;

	/**
	  * A multiplier to adjust the volume. Allowed range is from
	  * 0.0 to 1.0.
	  */
	float volumeLevel;

	NSString *foundDevice;

	id<CDHandlerProtocol> _handler;
}


@end


#endif
