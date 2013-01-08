/* vim: set ft=objc ts=4 sw=4 expandtab nowrap: */
/*
 *  Player.m
 *
 *  Copyright (c) 1999 - 2003, 2012
 *
 *  Author: ACKyugo <ackyugo@geocities.co.jp>
 *      Andreas Schik <andreas@schik.de>
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

#import <Cynthiune/Output.h>

#include "Player.h"
#include "LED.h"
#include "TrackList.h"
#include "BundleManager.h"
#include "GeneralView.h"

#define AUDIOCD_PLAYING         0
#define AUDIOCD_PAUSED          1
#define AUDIOCD_STOPPED         2

static BOOL mustReadTOC = NO;
static Player *sharedPlayer = nil;

@interface Player (Private)
- (BOOL) loadBundles;
- (void) ensureOutput;
- (void) reInitOutputIfNeeded;
- (void) playLoopIteration;
@end

@implementation Player (Private)

- (BOOL) loadBundles
{
    int i;
    NSString    *path;
    NSArray     *searchPaths;
    BundleManager *bundleManager;

    // try to load the AudioCD bundle
    searchPaths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,
                            NSUserDomainMask|NSLocalDomainMask|NSSystemDomainMask, YES);

    for (i = 0; i < [searchPaths count]; i++) {
        NSBundle *bundle;
        NSString *bundlePath = [NSString stringWithFormat:
                        @"%@/Bundles/AudioCD.bundle",
                        [searchPaths objectAtIndex: i]];

        bundle = [NSBundle bundleWithPath: bundlePath];
        if (bundle) {
            audiocdClass = [bundle principalClass];
            if (audiocdClass) {
                break;
            }
        }
    }   // for (i = 0; i < [searchPaths count]; i++)

    if (!audiocdClass) {
        NSRunAlertPanel(@"CDPlayer",
                _(@"Couldn't find AudioCD bundle."),
                _(@"Exit"), nil, nil);
        exit(-1);
    }

    bundleManager = [BundleManager bundleManager];
    [bundleManager loadBundles];

    path = [[NSUserDefaults standardUserDefaults] stringForKey: @"Device"];
    drive = [[audiocdClass alloc] initWithHandler: self];
    [drive startPollingWithPreferredDevice: path];

    return YES;
}

- (void) reInitOutputIfNeeded
{
    // CDDA is always 2 ch with 44100 Hz smaple rate
    if (![output prepareDeviceWithChannels: 2
                                   andRate: 44100
                            withEndianness: LittleEndian]) {
        NSLog (@"error preparing output for 2 channels at a rate of 44100");
    }
}


- (void) ensureOutput
{
    GeneralView *gv;
    Class outputClass;

    gv = [GeneralView singleInstance];
    outputClass = [gv preferredOutputClass];
    if (output && [output class] != outputClass) {
        [output release];
        output = nil;
        [self reInitOutputIfNeeded];
    }

    if (!output) {
        outputIsThreaded = [outputClass isThreaded];
        output = [outputClass new];
        [output setParentPlayer: self];
        [self reInitOutputIfNeeded];
    }
}

- (void) playLoopIteration
{
    unsigned char buffer[DEFAULT_BUFFER_SIZE];
    int size;

    size = [drive readNextChunk: buffer withSize: DEFAULT_BUFFER_SIZE];

    if (size > 0) {
        NSData *streamChunk = [NSData dataWithBytes: buffer length: size];
        [output playChunk: streamChunk];
    } else {
        // If no data can be read, we assume that playing has stopped
        currentState = AUDIOCD_STOPPED;
    }
}
@end


@implementation Player

- init
{
    if (sharedPlayer) {
        [self dealloc];
    } else {
        self = [super init];

        sharedPlayer = self;

        currentTrack = 1;
        drive = nil;
        autoPlay = NO;
        currentState = AUDIOCD_STOPPED;
        output = nil;
        outputIsThreaded = NO;
        closingThread = NO;
        changePauseButton = NO;

        // we must already create the (hidden) track list
        [TrackList sharedTrackList];

        if (![self loadBundles]) {
            [self release];
            return nil;
        }

        timer = [NSTimer scheduledTimerWithTimeInterval: 1
                                    target: self
                                  selector: @selector(timer:)
                                  userInfo: self
                                   repeats: YES];

        [[NSNotificationCenter defaultCenter] addObserver: self
                               selector: @selector(playTrack:)
                               name: @"PlayTrack"
                               object: nil];
    }
    return sharedPlayer;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver: self
                       name: @"PlayTrack"
                       object: nil];
    [drive release];
    [timer invalidate];
    [timer release];

    [led release];
    [window release];
    [prev release];
    [play release];
    [pause release];
    [stop release];
    [next release];
    [volume release];

    [super dealloc];
}

- (int) readNextChunk: (unsigned char *) buffer
             withSize: (unsigned int) bufferSize
{
    int inputSize;
    if (!closingThread) {
        inputSize = [drive readNextChunk: buffer withSize: bufferSize];

        if (inputSize <= 0) {
            inputSize = 0;
            // If no data can be read, we assume that playing has stopped
            currentState = AUDIOCD_STOPPED;
        }
    } else {
        inputSize = 0;
    }

    return inputSize;
}

- (void) chunkFinishedPlaying
{
    if (currentState == AUDIOCD_PLAYING) {
        [self playLoopIteration];
    }
}

//
// 
//
- (void) timer: (id) timer
{
    int min, sec;

    // This must be done in any case. If the user removes the CD,
    // we must read the TOC and afterwards clear the display.
    if (mustReadTOC) {
        [[TrackList sharedTrackList] setTOC: [drive readTOC]];
        mustReadTOC = NO;
    }

    // is a disc in the drive?
    if ([drive cdPresent] == NO) {
        if (AUDIOCD_STOPPED != currentState) {
            currentState = AUDIOCD_STOPPED;
            [led setNoCD];
            [led display];
            [[TrackList sharedTrackList] setPlaysTrack: -1 andNotify: NO];
        }
        return;
    }

    if (autoPlay) {
        autoPlay = NO;
        currentTrack = 1;
        min = sec = 0;
        [self play: self];
        return;
    }

    currentTrack = 1;
    min = sec = 0;
    if (currentState == AUDIOCD_PLAYING) {
        currentTrack = [drive currentTrack];
        min = [drive currentMin];
        sec = [drive currentSec];
    }

    if (currentState != AUDIOCD_PAUSED) {
        [led setTrack: currentTrack];
        [led setMin: min];
        [led setSec: sec];
        [led display];
        [[TrackList sharedTrackList] setPlaysTrack: currentTrack andNotify: (currentState == AUDIOCD_PLAYING)];
    }

    if (YES == changePauseButton) {
        NSBundle *bundle = [NSBundle mainBundle];
        NSString *path = nil;
        NSImage *image;
        if (currentState == AUDIOCD_PAUSED) {
            path = [bundle pathForResource: @"pause_on" ofType: @"tiff"];
        } else {
            path = [bundle pathForResource: @"pause" ofType: @"tiff"];
        }
        image = [[[NSImage alloc] initWithContentsOfFile: path] autorelease];
        [pause setImage: image];
        changePauseButton = NO;
    }
}


//
//
//

- (void) playTrack: (NSNotification *) not
{
    int nextTrack = [[[not userInfo] objectForKey: @"Track"] intValue];

    currentTrack = nextTrack;

    if (currentState == AUDIOCD_PLAYING) {
        [self pause: self];
    }

    [drive seek: currentTrack];

    [self play: self];
}


- (void) play: (id) sender
{
    if([drive cdPresent] == NO) {
        return;
    }

    [self ensureOutput];

    if (AUDIOCD_PLAYING != currentState) {
        if (AUDIOCD_STOPPED == currentState) {
            if (NO == [output openDevice]) {
                return;
            }
            [drive seek: currentTrack];
        }
        [drive start];
        if (outputIsThreaded) {
            closingThread = NO;
            [output startThread];
        } else {
            [self playLoopIteration];
        }
        changePauseButton = YES;
        currentState = AUDIOCD_PLAYING;
    }
}

- (void) pause: (id) sender
{
    if ([drive cdPresent] == NO) {
        return;
    }

    if (currentState == AUDIOCD_PLAYING) {
        if (outputIsThreaded) {
            closingThread = YES;
            [output stopThread];
        }
        [drive stop];
        currentState = AUDIOCD_PAUSED;
    } else if (currentState == AUDIOCD_PAUSED) {
        [self play: self];
    }
    changePauseButton = YES;
}

- (void) stop: (id) sender
{
    // the 'stop' button is also 'eject' if CD is already halted,
    // but not the Controller, which may also stop the CD on exit
    if(sender == stop) {
        if(currentState == AUDIOCD_STOPPED) {
            [drive eject];
            return;
        }
    }

    if (AUDIOCD_PLAYING == currentState) {
        if (outputIsThreaded) {
            closingThread = YES;
            [output stopThread];
        }
        [drive stop];
    }

    [output closeDevice];
    currentState = AUDIOCD_STOPPED;
    currentTrack = 1;
    changePauseButton = YES;
}

- (void) eject: (id) sender
{
    if([drive cdPresent] == NO) {
        return;
    }

    [drive eject];
}

- (void) setVolume: (id) sender
{
    [drive setVolumeLevel: [volume floatValue]];
    [volume setToolTip: [NSString stringWithFormat: @"Volume: %f", [volume floatValue]]];
}

- (void) next: (id) sender
{
    BOOL restart = NO;
    if([drive cdPresent] == NO) {
        return;
    }

    currentTrack++;
    if(currentTrack > [drive totalTrack]) {
        currentTrack = 1;
    }

    if (currentState == AUDIOCD_PLAYING) {
        restart = YES;
        [self pause: self];
    }

    if((currentState == AUDIOCD_PLAYING) ||
       (currentState == AUDIOCD_PAUSED)) {
        [drive seek: currentTrack];
    }

    if (YES == restart) {
        [self play: self];
    }
}

- (void) prev: (id) sender
{
    BOOL restart = NO;
    if([drive cdPresent] == NO) {
        return;
    }

    // We jump back only if we are not playing at the moment
    // or if we are at the very beginning of a playing track.
    // The latter condition allows to jump back to the beginning
    // of the current track before jumping back one more track.
    if ((currentState == AUDIOCD_STOPPED) ||
        ([drive currentSec] == 0 && [drive currentMin] == 0)) {
        currentTrack--;
        if(currentTrack < 1) {
            currentTrack = [drive totalTrack];
        }
    }

    if (currentState == AUDIOCD_PLAYING) {
        restart = YES;
        [self pause: self];
    }

    if((currentState == AUDIOCD_PLAYING) ||
       (currentState == AUDIOCD_PAUSED)) {
        [drive seek: currentTrack];
    }

    if (YES == restart) {
        [self play: self];
    }
}


//
//
//
//
- (BOOL) audioCD: (id) sender error: (int) no message: (NSString *) msg
{
    // FIXME: Take appropriate action when an error occurs!!
//  NSRunAlertPanel(@"CDPlayer",
//          msg,
//          _(@"OK"), nil, nil);
    NSLog(@"CDPlayer error: %@", msg);
    return YES;
}

- (void) audioCDChanged: (id) sender
{
    mustReadTOC = YES;
}


- (BOOL) windowShouldClose: (id) sender
{
    [[NSApplication sharedApplication ] terminate: self];
    return YES;
}

- (void) buildInterface
{
    NSRect      frame;
    unsigned int    style = NSTitledWindowMask | NSClosableWindowMask |
                NSMiniaturizableWindowMask;
    NSBundle    *bundle = [NSBundle mainBundle];
    NSImage     *image;
    NSString    *path;

    frame = NSMakeRect(100, 100, 160, 93);
    window = [[NSWindow alloc] initWithContentRect: frame
                         styleMask: style
                           backing: NSBackingStoreRetained
                             defer: NO];
    [window setTitle: @"CDPlayer"];
    [window setDelegate: self];

    frame = NSMakeRect(5, 58, 150, 30);
    led = [[LED alloc]  initWithFrame: frame];

    [led setNoCD];
    [led display];
    [[window contentView] addSubview: led];

    path = [bundle pathForResource: @"prev" ofType: @"tiff"];
    image = [[[NSImage alloc] initWithContentsOfFile: path] autorelease];
    if(image == nil)    NSLog(@"cannot load prev.tiff");
    frame = NSMakeRect( 5, 25, 30, 30);
    prev = [[NSButton alloc] initWithFrame: frame];
    [prev setButtonType: NSMomentaryPushButton];
    [prev setImagePosition: NSImageOnly];
    [prev setImage: image];
    [prev setTarget: self];
    [prev setAction: @selector(prev:)];
    [[window contentView] addSubview: prev];

    path = [bundle pathForResource: @"play" ofType: @"tiff"];
    image = [[[NSImage alloc] initWithContentsOfFile: path] autorelease];
    if(image == nil)    NSLog(@"cannot load play.tiff");
    frame = NSMakeRect( 35, 25, 30, 30);
    play = [[NSButton alloc] initWithFrame: frame];
    [play setButtonType: NSMomentaryPushButton];
    [play setImagePosition: NSImageOnly];
    [play setImage: image];
    [play setTarget: self];
    [play setAction: @selector(play:)];
    [[window contentView] addSubview: play];

    path = [bundle pathForResource: @"pause" ofType: @"tiff"];
    image = [[[NSImage alloc] initWithContentsOfFile: path] autorelease];
    if(image == nil)    NSLog(@"cannot load pause.tiff");
    frame = NSMakeRect( 65, 25, 30, 30);
    pause = [[NSButton alloc] initWithFrame: frame];
    [pause setButtonType: NSMomentaryPushButton];
    [pause setImagePosition: NSImageOnly];
    [pause setImage: image];
    [pause setTarget: self];
    [pause setAction: @selector(pause:)];
    [[window contentView] addSubview: pause];

    path = [bundle pathForResource: @"next" ofType: @"tiff"];
    image = [[[NSImage alloc] initWithContentsOfFile: path] autorelease];
    if(image == nil)    NSLog(@"cannot load next.tiff");
    frame = NSMakeRect(95, 25, 30, 30);
    next = [[NSButton alloc] initWithFrame: frame];
    [next setButtonType: NSMomentaryPushButton];
    [next setImagePosition: NSImageOnly];
    [next setImage: image];
    [next setTarget: self];
    [next setAction: @selector(next:)];                                          
    [[window contentView] addSubview: next];

    path = [bundle pathForResource: @"stop" ofType: @"tiff"];
    image = [[[NSImage alloc] initWithContentsOfFile: path] autorelease];
    if(image == nil)    NSLog(@"cannot load stop.tiff");
    frame = NSMakeRect(125, 25, 30, 30);
    stop = [[NSButton alloc] initWithFrame: frame];
    [stop setButtonType: NSMomentaryPushButton];
    [stop setImagePosition: NSImageOnly];
    [stop setImage: image];
    [stop setTarget: self];
    [stop setAction: @selector(stop:)];
    [[window contentView] addSubview: stop];

    frame = NSMakeRect(5, 5, 150, 15);
    volume = [[NSSlider alloc] initWithFrame: frame];
    [[volume cell] setSliderType: NSLinearSlider];
    [volume setMinValue: 0.0f];
    [volume setMaxValue: 1.0f];
    [volume setFloatValue: 0.75f];
    [volume setContinuous: NO];
    [volume setTarget: self];
    [volume setAction: @selector(setVolume:)];
    [drive setVolumeLevel: [volume floatValue]];
    [volume setToolTip: [NSString stringWithFormat: @"Volume: %f", [volume floatValue]]];
    [[window contentView] addSubview: volume];

    [window orderFront: self];
    [window setFrameAutosaveName: @"CDPlayerWindow"];
    [window setFrameUsingName: @"CDPlayerWindow"];
}


//
// services methods
//

- (void) getTOC: (NSPasteboard *) pboard
       userData: (NSString *) userData
          error: (NSString **) error
{
    TrackList *tl = [TrackList sharedTrackList];
    int i, rows = [tl numberOfTracksInTOC];
    NSMutableArray *array;

    /*
     * If we don't have any rows, there is probably no CD.
     */
    if (rows == 0) {
        *error = _(@"No Audio CD found.");
        return;
    }

    array = [[NSMutableArray alloc] init];

    for (i = 0; i < rows; i++) {
        [array addObject: [NSNumber numberWithInt: i]];
    }

    /*
     * This is a small hack, but we can clean this up later.
     */
    if (![tl tableView: nil writeRows: array toPasteboard: pboard]) {
        *error = _(@"Could not write TOC to pasteboard.");
    } else {
    }

    RELEASE(array);
}

- (void) playCD: (NSPasteboard *) pboard
       userData: (NSString *) userData
          error: (NSString **) error
{
    NSArray *types = [pboard types];

    // If CD is currently playing, we reject the request
    if(currentState == AUDIOCD_PLAYING) {
        *error = _(@"Player.alreadyPlaying");
        return;
    }

    /*
     * Do we have at least one valid pasteboard type?
     */
    if (![types containsObject: NSFilenamesPboardType] &&
            ![types containsObject: NSStringPboardType]) {
        *error = _(@"Player.noValidPboardType");
        return;
    }

    /*
     * Try to add as much as possible, i.e. even if one pasteboard
     * type fails try the other one (if it exists in the pasteboard).
     */
    if ([types containsObject: NSFilenamesPboardType] ||
            [types containsObject: NSStringPboardType]) {
        // Get the device name from the pboard
        NSString *device = nil;
        NSArray *devices = [pboard propertyListForType: NSFilenamesPboardType];
        if (devices != nil) {
            if ([devices count] != 1) {
                *error = _(@"Player.tooManyFileNames");
                return;
            }
            device = [devices objectAtIndex: 0];
        } else {
            device = [pboard propertyListForType: NSStringPboardType];
        }
        if (device == nil) {
            *error = _(@"Player.noDeviceNameFound");
            return;
        }
        autoPlay = YES;
        [drive stopPolling];
        [drive startPollingWithPreferredDevice: device];
    }
}

//
// class methods
//
+ (Player *) sharedPlayer
{
    if (!sharedPlayer) {
        sharedPlayer = [[Player alloc] init];
    }
    return sharedPlayer;
}


@end
