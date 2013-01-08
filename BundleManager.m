/* BundleManager.m - this file is part of Cynthiune
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

#import <Foundation/NSArray.h>
#import <Foundation/NSBundle.h>
#import <Foundation/NSFileManager.h>
#import <Foundation/NSNotification.h>
#import <Foundation/NSPathUtilities.h>

#import <Cynthiune/CynthiuneBundle.h>
#import <Cynthiune/Output.h>
#import <Cynthiune/Preference.h>
//#import <Cynthiune/utils.h>

#import "GeneralView.h"
#import "Preferences.h"

#import "BundleManager.h"

static NSNotificationCenter *nc = nil;

@implementation BundleManager : NSObject

+ (void) initialize
{
  nc = [NSNotificationCenter defaultCenter];
}

+ (BundleManager *) bundleManager
{
  static BundleManager *bundleManager = nil;

  if (!bundleManager)
    bundleManager = [BundleManager new];

  return bundleManager;
}

- (void) _registerClass: (Class) class
{
	Preferences *prefs;
	GeneralView *gv;

	prefs = [Preferences singleInstance];
	gv = [GeneralView singleInstance];

	if ([class conformsToProtocol: @protocol(Preference)]) {
		[prefs registerPreferenceClass: class];
	}
	if ([class conformsToProtocol: @protocol(Output)]) {
		[gv registerOutputClass: class];
	}
}

- (void) loadBundlesForPath: (NSString *) path
            withFileManager: (NSFileManager *) fileManager
{
	NSEnumerator *files;
	NSString *file, *bundlePath;
	NSBundle *bundle;

	files = [[fileManager directoryContentsAtPath: path] objectEnumerator];

	while ((file = [files nextObject]) != nil) {
		if ([[file pathExtension] isEqualToString: @"output"]) {
			bundlePath = [path stringByAppendingPathComponent: file];
			bundle = [NSBundle bundleWithPath: bundlePath];
			if (bundle) {
				[nc addObserver: self
					selector: @selector (bundleDidLoad:)
					name: NSBundleDidLoadNotification
					object: bundle];
					[bundle load];
			}
		}
	}
}

- (void) bundleDidLoad: (NSNotification *) notification
{
  NSDictionary *dictionary;
  NSEnumerator *classNames;
  NSString *className;

  dictionary = [notification userInfo];
  classNames = [[dictionary objectForKey: NSLoadedClasses] objectEnumerator];

  while ((className = [classNames nextObject]) != nil)
    {
      [self _registerClass: NSClassFromString (className)];
    }

  [nc removeObserver: self
      name: NSBundleDidLoadNotification
      object: [notification object]];
}

- (void) loadBundlesInSystemDirectories: (NSFileManager *) fileManager
{
  NSEnumerator *paths;
  NSString *path;

  paths = [NSStandardLibraryPaths () objectEnumerator];
  while ((path = [paths nextObject]) != nil)
    {
      [self loadBundlesForPath:
              [path stringByAppendingPathComponent: @"Bundles/Cynthiune"]
            withFileManager: fileManager];
    }
}

- (void) loadBundles
{
  NSFileManager *fileManager;

  fileManager = [NSFileManager defaultManager];

  [self loadBundlesInSystemDirectories: fileManager];
}

@end
