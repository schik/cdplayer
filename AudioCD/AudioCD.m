/* vim: set ft=objc ts=4 sw=4 expandtab nowrap: */
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


#include <unistd.h>

#include "AudioCD.h"


static BOOL exitThread = NO;
static BOOL pollThreadRunning = NO;
static BOOL stopReading = NO;
static BOOL readerThreadRunning = NO;

@interface AudioCD (Private)

- (cdrom_drive_t *) deviceForCD: (NSString *) testDevice;
- (BOOL) checkAllDevicesForCD: (NSString *) customDevice;
- (void) checkDrivesThread: (id) anObject;
- (void) readerThread: (id) anObject;
- (uint32_t) cddbDiskid;

@end

@implementation AudioCD

- initWithHandler: (id<CDHandlerProtocol>)handler
{
    self = [super init];

    if (self != nil) {
        foundDevice = nil;
        drive = NULL;
        paranoia = NULL;
        startLsn = 0;
        currentLsn = 0;
        bytesRead = 0;
        rb = NULL;
        cdio_loglevel_default = CDIO_LOG_ERROR;
        [self setHandler: handler];
    }

    return self;
}

- (void)dealloc
{
    [self stopPolling];

    if (NULL != rb) {
        rb_free(rb);
    }

    if (NULL != drive) {
        cdda_close(drive);
    }

    if (NULL != paranoia) {
        paranoia_free(paranoia);
        paranoia = NULL;
    }

    [foundDevice release];

    [super dealloc];
}

- (void) startPollingWithPreferredDevice: (NSString *)device
{
    exitThread = NO;
    pollThreadRunning = YES;

    [NSThread detachNewThreadSelector: @selector(checkDrivesThread:)
                             toTarget: self
                           withObject: device];
}

- (void) stopPolling
{
    exitThread = YES;

    // wait for thethread to actually end
    do {
        [NSThread sleepUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.25]];
    } while (pollThreadRunning);
}

- (NSString *)device
{
    return [[foundDevice copy] autorelease];
}

- (void) setHandler: (id<CDHandlerProtocol>)handler
{
    _handler = handler;
}

- (NSMutableDictionary *)readTOC
{
    int i;
    NSMutableDictionary *toc = [NSMutableDictionary dictionaryWithCapacity: 6];
    NSMutableArray      *tracks;

    if (NULL == drive) {
        return nil;
    }

    tracks = [NSMutableArray arrayWithCapacity: drive->tracks];
    for (i = 1; i <= drive->tracks; i++) {
        NSMutableDictionary *track = [NSMutableDictionary dictionaryWithCapacity: 5];
        lsn_t start = cdda_track_firstsector(drive, i);
        lsn_t len = cdda_track_lastsector(drive, i) - start + 1;

        [track setObject: _(@"Unknown") forKey: @"artist"];
        [track setObject: [NSString stringWithFormat: _(@"Track%d"), i] forKey: @"title"];

        [track setObject: [NSString stringWithFormat: @"%d", len]
            forKey: @"length"];
        [track setObject: [NSString stringWithFormat: @"%d", start + CD_MSF_OFFSET]
            forKey: @"offset"];
        [track setObject: cdio_cddap_track_audiop(drive, i)?@"audio":@"data"
            forKey: @"type"];
        [tracks addObject: track];
    }

    [toc setObject: foundDevice forKey: @"device"];
    [toc setObject: _(@"Unknown") forKey: @"artist"];
    [toc setObject: _(@"Unknown") forKey: @"title"];

    [toc setObject: [NSString stringWithFormat: @"%08X", [self cddbDiskid]]
        forKey: @"cddbid"];
    [toc setObject: [NSString stringWithFormat: @"%d",
                    cdda_track_lastsector(drive, drive->tracks) - cdda_track_firstsector(drive, 1) + 1 + CD_MSF_OFFSET]
        forKey: @"discLength"];
    [toc setObject: [NSString stringWithFormat: @"%d", drive->tracks]
        forKey: @"numberOfTracks"];
    [toc setObject: tracks forKey: @"tracks"];

    return toc;
}

- (BOOL) checkForCDWithId: (NSString *)cddbId
{
    NSString *temp;

    if (NULL == drive) {
        NSLog(@"no drive");
        return NO;
    }
    temp = [NSString stringWithFormat: @"%08X", [self cddbDiskid]];
    NSLog(@"cddbId: %@, temp: %@", cddbId, temp);
    if ([cddbId isEqual: temp]) {
        NSLog(@"strings are equal");
        return YES;
    }
    return NO;
}


- (void) start
{
    if ((NULL == drive) || (NULL == paranoia)) {
        return;
    }

    rb = rb_create(2 * sizeof(float) * (1<<20));

    stopReading = NO;
    readerThreadRunning = YES;

    [NSThread detachNewThreadSelector: @selector(readerThread:)
                             toTarget: self
                           withObject: nil];
}

- (void) stop
{
    stopReading = YES;

    // wait for the reader thread to actually end
    do {
        [NSThread sleepUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.25]];
    } while (readerThreadRunning);

    if (NULL != rb) {
        rb_free(rb);
    }
}

- (void) setVolumeLevel: (float) vLevel
{
    volumeLevel = vLevel;
}

- (int) readNextChunk: (unsigned char *) buffer
             withSize: (unsigned int) bufferSize
{
    unsigned int numread = 0;
    unsigned int n_avail = 0;

    // Wait until data is available or until reader thread stops
    while (!stopReading
            && ((n_avail = rb_read_space(rb)) < 1)
            && readerThreadRunning) {
        [NSThread sleepUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];
    }

    if (stopReading) {
        // user signalled stop -> end immediately
        return 0;
    }

    // Take available data data from buffer.
    // Note: If if reader thread stopped (readerThreadRunning == NO) we
    // do this, as we want to play the CD to its end unless the user
    // pressed the stop button.
    if (n_avail > bufferSize) {
        n_avail = bufferSize;
    }
    if (n_avail > 0) {
        int i;
        
        numread = rb_read(rb, (char*)buffer, n_avail);

        for (i = 0; i < numread / 2; i++) {
            float f = ((int16_t *)buffer)[i] * volumeLevel;
            ((int16_t *)buffer)[i] = f;
        }
        bytesRead += numread;
        currentLsn = startLsn + (bytesRead / CDIO_CD_FRAMESIZE_RAW);
    }
    return numread;
}

- (void) seek: (unsigned int) track
{
    if ((NULL == drive) || (NULL == paranoia)) {
        return;
    }

    // check whether track number is in range
    if (drive->tracks < track) {
        return;
    }

    // check whether track is audio track
    if (!cdda_track_audiop(drive, track)) {
        return;
    }

    currentLsn = cdda_track_firstsector(drive, track);
    paranoia_seek(paranoia, currentLsn, SEEK_SET);
}

- (void) eject
{
    if (NULL == drive) {
        return;
    }

    if(cdio_eject_media(&(drive->p_cdio)) != DRIVER_OP_SUCCESS) {
        [_handler audioCD: self
                    error: errno
                  message: [NSString stringWithCString: strerror(errno)]];
    }
}

- (BOOL) cdPresent
{
    return (NULL != drive) && (0 != drive->opened);
}

- (int) currentTrack
{
    track_t track = -1;
    if (NULL == drive) {
        return track;
    }

    track = cdio_cddap_sector_gettrack(drive, currentLsn);
    if (CDIO_INVALID_TRACK == track) {
        [_handler audioCD: self
                    error: errno
                  message: [NSString stringWithCString: strerror(errno)]];
        return -1;
    }

    return track;
}

- (int) currentMin
{
    track_t track = -1;
    lsn_t start = 0;
    lsn_t offset = 0;
    if (NULL == drive) {
        return -1;
    }

    track = [self currentTrack];
    if (-1 == track) {
        return -1;
    }

    start = cdda_track_firstsector(drive, track);
    offset = currentLsn - start + 1;
    return (offset / (CDIO_CD_FRAMES_PER_MIN));
}

- (int) currentSec
{
    track_t track = -1;
    lsn_t start = 0;
    lsn_t offset = 0;
    if (NULL == drive) {
        return track;
    }

    track = [self currentTrack];
    if (-1 == track) {
        return -1;
    }

    start = cdda_track_firstsector(drive, track);
    offset = currentLsn - start + 1;

    return ((offset / CDIO_CD_FRAMES_PER_SEC) % CDIO_CD_SECS_PER_MIN);
}


- (int) firstTrack
{
    track_t i;
  
    if (NULL == drive) {
        return -1;
    }

    // search the first audio track
    for (i = 1; i <= drive->tracks; i++) {
        if (cdda_track_audiop(drive, i)) {
            return i;
        }
    }
    return -1;
}

- (int) totalTrack
{
    if (NULL == drive) {
        return -1;
    }
    return drive->tracks;
}

- (int) trackLength: (int)track
{
    if (NULL == drive) {
        return -1;
    }
    lsn_t start = cdda_track_firstsector(drive, track);
    lsn_t len = cdda_track_lastsector(drive, track) - start + 1;
    return (len / CDIO_CD_FRAMES_PER_SEC);
}

@end


//
// private methods
//

@implementation AudioCD (Private)

- (BOOL) checkAllDevicesForCD: (NSString *)customDevice
{
    char *pos;
    const char *dev;

    // destroy old structures
    if (NULL != paranoia) {
        paranoia_free(paranoia);
        paranoia = NULL;
    }

    if (NULL != drive) {
        cdda_close(drive);
        drive = NULL;
    }


    if (customDevice && [customDevice length]) {
        dev = [customDevice cString];
        if(dev && (pos = strchr(dev, '?'))) {
            char j;

            /* try first eight of each device */
            for(j = 0; (j < 4) && (NULL == drive); j++) {
                char *temp = strdup(dev);

                /* number, then letter */
                temp[pos - dev] = j + 48;
                drive = [self deviceForCD: [NSString stringWithCString: temp]];
                if (NULL == drive) {
                    temp[pos - dev] = j + 97;
                    drive = [self deviceForCD: [NSString stringWithCString: temp]];
                }
                free(temp);
            }
        } else {
            /* Name.  Go for it. */
            drive = [self deviceForCD: [NSString stringWithCString: dev]];
        }
    }
    if (NULL == drive) {
        driver_id_t driver_id;
        char **ppsz_cd_drives = cdio_get_devices_with_cap_ret(NULL,  
                                    CDIO_FS_AUDIO, 
                                    0,
                                    &driver_id);
        if (ppsz_cd_drives && *ppsz_cd_drives) {
            // Use the 1st one from the list
            drive = [self deviceForCD: [NSString stringWithCString: *ppsz_cd_drives]];
        }
    
        cdio_free_device_list(ppsz_cd_drives);
    }
    if (NULL != drive) {
        paranoia = paranoia_init(drive);
        paranoia_modeset(paranoia, PARANOIA_MODE_FULL^PARANOIA_MODE_NEVERSKIP);
    }


    return NULL != drive;
}

- (cdrom_drive_t *) deviceForCD: (NSString *) testDevice
{
    cdrom_drive_t *d;

    RELEASE(foundDevice);
    foundDevice = nil;

    d = cdio_cddap_identify([testDevice cString], CDDA_MESSAGE_FORGETIT, NULL);
    if (NULL != d) {
        int res = cdio_cddap_open(d);
        if ((0 == res) && (0 != d->opened)) {
            // cdda_open does not tell us when no media was detected, hence
            // we must check the flag in the drive struct
            // stop here, we found a CD
            cdda_verbose_set(d, CDDA_MESSAGE_FORGETIT, CDDA_MESSAGE_FORGETIT);
            foundDevice = [testDevice copy];
            if (d->bigendianp == -1) {
                d->bigendianp = data_bigendianp(d);
            }
            // New CD -> reset read pointer
            currentLsn = 0;
        }
    }
    if (nil == foundDevice) {
        cdda_close(d);
        d = NULL;
    }
    return d;
}

- (void) checkDrivesThread: (id)anObject
{
    id pool;
    NSString *device;
    BOOL present = NO;

    pool = [NSAutoreleasePool new];
    device = [[(NSString *)anObject copy] autorelease];

    do {
        if ((NULL == drive) || (0 != cdio_get_media_changed(drive->p_cdio))) {
            [self checkAllDevicesForCD: device];
        }

        // is a disc present in the drive?
        if([self cdPresent] != present) {
            present = !present;
            // send a message to owner
            [_handler audioCDChanged: self];
        }

        // wait a second for the next check
        [NSThread sleepUntilDate: [NSDate dateWithTimeIntervalSinceNow: 1.]];
    } while (!exitThread);

    RELEASE(pool);
    pollThreadRunning = NO;
}

/**
  * Thread method to read raw CDDDA data into ring buffer. This
  * method assumes that non-audio tracks are either at the beginning
  * or at the end of the CD and skips them.
  */
- (void) readerThread: (id)anObject
{
    int i;
    id pool = [NSAutoreleasePool new];;
    int curtrack = -1;
    lsn_t cursor = 0;
    lsn_t lastLsn = cdda_track_lastsector(drive, drive->tracks);

    // skip non-audio tracks at beginning of CD
    curtrack = cdio_cddap_sector_gettrack(drive, currentLsn);
    while ((curtrack <= drive->tracks)
            && !cdda_track_audiop(drive, curtrack)) {
        // skip non-audio tracks
        curtrack++;
        currentLsn = cdio_cddap_track_firstsector(drive, curtrack);
    }

    // skip non-audio tracks at end of CD
    curtrack = drive->tracks;
    while ((curtrack >= 1)
            && !cdda_track_audiop(drive, curtrack)) {
        // skip non-audio tracks
        curtrack--;
        lastLsn = cdda_track_lastsector(drive, curtrack);
    }

    cursor = currentLsn;
    bytesRead = 0;
    startLsn = currentLsn;
    // synchronize paranoia with our current position
    paranoia_seek(paranoia, currentLsn, SEEK_SET);

    while ((NO == stopReading) && (cursor < lastLsn)) {
        int16_t *readbuf = NULL;
        char *err = NULL;
        char *mes = NULL;

        // If there is too little space in the buffer, wait
        while ((NO == stopReading)
                && (rb_write_space(rb) < CDIO_CD_FRAMESIZE_RAW * 10)) {
            [NSThread sleepUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];
        }
        if (YES == stopReading) {
            break;
        }

        readbuf = paranoia_read(paranoia, NULL);
        err = cdda_errors(drive);
        mes = cdda_messages(drive);

        if (mes || err) {
            NSLog(@"%s%s", mes?mes:"", err?err:"");
        }
        if (err) free(err);
        if (mes) free(mes);
        if(NULL == readbuf) {
            NSLog(@"paranoia_read: Unrecoverable error, bailing.");
            stopReading = YES;
        } else {
            cursor++;
            if (1 == drive->bigendianp) {
                for (i = 0; i < CDIO_CD_FRAMESIZE_RAW / 2; i++) {
                    readbuf[i] = UINT16_SWAP_LE_BE_C(readbuf[i]);
                }
            }

            for (i = 0; i < CDIO_CD_FRAMESIZE_RAW / 2; i++) {
                rb_write(rb, (char *)&readbuf[i], 2);
            }
        }
    }
    if (stopReading) {
        NSDebugLog(@"Reader thread received stop signal");
    }
    if (cursor >= lastLsn) {
        NSDebugLog(@"Reader thread reached end of CD");
        // TODO: signal end of reading to handler
    }
    if (rb_write_space(rb) <= CDIO_CD_FRAMESIZE_RAW * 2) {
        NSDebugLog(@"Reader thread ended because buffer is full. This should NEVER happen!");
    }

    RELEASE(pool);
    readerThreadRunning = NO;
}

/**
  Returns the sum of the decimal digits in a number. Eg. 1955 = 20
  */
static int cddb_dec_digit_sum(int n)
{
    int ret = 0;
  
    while (0 != n) {
        ret += n%10;
        n = n/10;
    }
    return ret;
}

- (uint32_t) cddbDiskid
{
    int i, t, n=0;
    msf_t start_msf;
    msf_t msf;

    if (NULL == drive) {
        return 0;
    }
 
    for (i = 1; i <= drive->tracks; i++) {
        cdio_get_track_msf(drive->p_cdio, i, &msf);
        n += cddb_dec_digit_sum(cdio_audio_get_msf_seconds(&msf));
    }

    cdio_get_track_msf(drive->p_cdio, 1, &start_msf);
    cdio_get_track_msf(drive->p_cdio, CDIO_CDROM_LEADOUT_TRACK, &msf);
  
    t = cdio_audio_get_msf_seconds(&msf)-cdio_audio_get_msf_seconds(&start_msf);
  
    return ((n % 0xff) << 24 | t << 8 | drive->tracks);
}

@end
