/* vim: set ft=objc ts=4 sw=4 expandtab nowrap: */
/* SliderCell.m
 *
 * Copyright (C) 2005 Wolfgang Sourdeau
 *
 * Author: Wolfgang Sourdeau <Wolfgang@Contre.COM>
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 *
 * This file is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; see the file COPYING.  If not, write to
 * the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

#import <AppKit/NSColor.h>
#import <AppKit/NSGraphics.h>
#import <AppKit/NSImage.h>

#import <Foundation/NSString.h>

#import <math.h>

#import "SliderCell.h"

@implementation SliderCell : NSSliderCell

- (id) init
{
    if ((self = [super init])) {
        knobCell = [NSCell new];
    }

    return self;
}

- (void) setEnabled: (BOOL) enabled
{
    [super setEnabled: enabled];
    [knobCell setImage: [NSImage imageNamed: ((enabled)
                                            ? @"slider-knob-enabled"
                                            : @"slider-knob-disabled")]];
}

- (void) drawKnob: (NSRect) rect
{
    [knobCell drawInteriorWithFrame: rect inView: [self controlView]];
}

- (void) drawBarInside: (NSRect) cellFrame
               flipped: (BOOL) flipped;
{
    NSRect rect;

    rect = cellFrame;
    rect.size.height = cellFrame.size.height / 4;
    rect.origin.y += cellFrame.size.height / 4 + 2;
        
    [[NSColor colorWithCalibratedHue: .0 saturation: .0 brightness: .34 alpha: 1.] set];
    NSRectFill(rect);
}

- (BOOL) isOpaque
{
    return NO;
}

- (CGFloat) knobThickness
{
    NSSize size;
    size = [[knobCell image] size];
    return size.width;
}

@end
