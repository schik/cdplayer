/* vim: set ft=objc ts=4 sw=4 expandtab nowrap: */
/*
 *  Controller.m
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
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>

#include "Controller.h"
#include "Player.h"
#include "Preferences.h"
#include "TrackList.h"

@interface Controller (Private)
- (void) readFromFifoThread: (id) obj;
- (void) createMenu;
@end

@implementation Controller (Private)

/**
  * This function runs in a background thread and reads commands from
  * a FIFO file to control the player.
  */
- (void) readFromFifoThread: (id) obj
{
    id pool = [NSAutoreleasePool new];
    NSString *command = nil;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *tmpFileName = [NSString stringWithFormat: @"%@/cdplayer.fifo", NSTemporaryDirectory()];
    #define BUF_SIZE 256
    char buffer[BUF_SIZE];

    if ([fm fileExistsAtPath: tmpFileName] == YES) {
        while (!stopFifo) {
            char *p = buffer;
            int count = BUF_SIZE-1;
            int ret = 1;
            int fd = open([tmpFileName cString], O_RDONLY);
            if (fd == -1) {
                NSLog(@"Could not open %@", tmpFileName);
                break;
            }

            memset(buffer, '\0', BUF_SIZE);

            while ((count > 0) && ret) {
                ret = read(fd, p, count);
                if (ret < 0) {
                    count = 0;
                } else if (ret > 0) {
                    count -= ret;
                    p+=ret;
                }
            }
            close(fd);
            command = [[NSString stringWithCString: buffer
                              encoding: NSASCIIStringEncoding]
                      stringByTrimmingCharactersInSet:
                            [NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if ([command isEqualToString: @"play"]) {
                [[Player sharedPlayer] play: self];
            } else if ([command isEqualToString: @"pause"]) {
                [[Player sharedPlayer] pause: self];
            } else if ([command isEqualToString: @"resume"]) {
                [[Player sharedPlayer] play: self];
            } else if ([command isEqualToString: @"stop"]) {
                [[Player sharedPlayer] stop: self];
            } else if ([command isEqualToString: @"prev"]) {
                [[Player sharedPlayer] prev: self];
            } else if ([command isEqualToString: @"next"]) {
                [[Player sharedPlayer] next: self];
            }
         }
    }
    RELEASE(pool);
}

- (void) createMenu
{
    NSMenu *menu;
    NSMenu *info;
    NSMenu *services;
    NSMenu *windows;
    SEL action = @selector(method:);


    ///// Create the app menu /////
	menu = AUTORELEASE([NSMenu new]);

    [menu addItemWithTitle: _(@"Info")
                    action: action
             keyEquivalent: @""];

    [menu addItemWithTitle: _(@"Show Track List")
                    action: @selector(showTrackList:)
             keyEquivalent: @"l"];

    [menu addItemWithTitle: _(@"Query CDDB")
                    action: @selector(queryCddb:)
             keyEquivalent: @"Q"];

    [menu addItemWithTitle: _(@"Windows")
                    action: action
             keyEquivalent: @""];

    [menu addItemWithTitle: _(@"Services")
                    action: action
             keyEquivalent: @""];

    [menu addItemWithTitle: _(@"Hide")
                    action: @selector(hide:)
             keyEquivalent: @"h"];

    [menu addItemWithTitle: _(@"Quit")
                    action: @selector(terminate:)
             keyEquivalent: @"q"];

    ///// Create the info submenu /////
    info = AUTORELEASE([NSMenu new]);
    [menu setSubmenu: info
             forItem: [menu itemWithTitle: _(@"Info")]];

    [info addItemWithTitle: _(@"Info Panel...")
                    action: @selector(orderFrontStandardInfoPanel:)
             keyEquivalent: @""];

    [info addItemWithTitle: _(@"Preferences...")
                    action: @selector(showPrefPanel:)
             keyEquivalent: @""];

    [info addItemWithTitle: _(@"Help")
                    action: @selector(showMyHelp:)
             keyEquivalent: @"?"];

    ///// Create the windows submenu /////
    windows = AUTORELEASE([NSMenu new]);
    [menu setSubmenu: windows
             forItem: [menu itemWithTitle: _(@"Windows")]];
    [windows addItemWithTitle:_(@"Arrange")
	                   action:@selector(arrangeInFront:)
                keyEquivalent:@""];
    [windows addItemWithTitle:_(@"Miniaturize")
                       action:@selector(performMiniaturize:)
                keyEquivalent:@"m"];
    [windows addItemWithTitle:_(@"Close")
                       action:@selector(performClose:)
                keyEquivalent:@"w"];

    ///// Create the services submenu /////
    services = AUTORELEASE([NSMenu new]);
    [menu setSubmenu: services
             forItem: [menu itemWithTitle: _(@"Services")]];

    [NSApp setServicesMenu: services];
    [NSApp setWindowsMenu: windows];
    [NSApp setMainMenu: menu];

    [menu update];
    [menu display];
}

@end

@implementation Controller

- (id) init
{
    self = [super init];
    if (nil != self) {
        stopFifo = NO;
    }
    return self;
}

- (void) dealloc
{
    RELEASE(player);
    [super dealloc];
}

- (void)applicationWillFinishLaunching:(NSNotification *)not
{
    [self createMenu];
    player = [Player sharedPlayer];
    [NSApp setServicesProvider: player];
    [player buildInterface];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    NSUserDefaults  *defaults = [NSUserDefaults standardUserDefaults];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *tmpFileName = nil;

    [TrackList sharedTrackList];
    if ([defaults integerForKey: @"ShowTrackListOnStartup"]) {
        [self showTrackList: self];
    }

    tmpFileName =[NSString stringWithFormat: @"%@/cdplayer.fifo", NSTemporaryDirectory()];
    if ([fm fileExistsAtPath: tmpFileName] == NO) {
        mkfifo([tmpFileName cString], (S_IRUSR | S_IWUSR | S_IRGRP | S_IWGRP | S_IROTH | S_IWOTH));
    }

    [NSThread detachNewThreadSelector: @selector(readFromFifoThread:)
                 toTarget: self
                   withObject: nil];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication
{
    return NO;
}

- (BOOL)applicationShouldTerminate:(NSApplication *)sender
{
    NSUserDefaults  *defaults = [NSUserDefaults standardUserDefaults];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *tmpFileName = nil;

    switch ([defaults integerForKey: @"OnExit"])
    {
    // auto stop
    case 1:
        [player stop: self];
        break;
    // auto eject
    case 2:
        [player eject: self];
        break;
    // none
    case 0:
    default:
        break;
    }

    stopFifo = YES;

    tmpFileName =[NSString stringWithFormat: @"%@/cdplayer.fifo", NSTemporaryDirectory()];
    if ([fm fileExistsAtPath: tmpFileName] == YES) {
        [fm removeFileAtPath: tmpFileName handler: nil];
    }
    return YES;
}

- (BOOL) application: (NSApplication*)app openFile: (NSString*)file
{
    [player playCD: file];
    return YES;
}

- (void) showPrefPanel: (id)sender
{
    [[Preferences singleInstance] showPanel: self];
}

- (void) showTrackList: (id)sender
{
    [[TrackList sharedTrackList] activate];
}
 
- (void) queryCddb: (id)sender
{
    [[TrackList sharedTrackList] queryCddb: sender];
}

- (void) showMyHelp: (id)sender
{
    NSBundle *mb = [NSBundle mainBundle];
    NSString *file = [mb pathForResource: @"CDPlayer" ofType: @"help"]; 
 
    if (file) {
        [[NSWorkspace sharedWorkspace] openFile: file];
        return;
    }
    NSBeep();
}
 
- (BOOL) validateMenuItem: (NSMenuItem*)item
{
    BOOL ret = [[TrackList sharedTrackList] validateMenuItem: item];
    if (!ret)
        return ret;

    return YES;
}


@end
