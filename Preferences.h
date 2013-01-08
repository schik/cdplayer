/* vim: set ft=objc ts=4 nowrap: */

#ifndef __PREFERENCES_H_INCLUDED
#define __PREFERENCES_H_INCLUDED

#include <AppKit/AppKit.h>

@interface Preferences : NSObject
{
	NSPanel *window;
	NSButton *saveButton;
	NSButton *closeButton;

	NSPopUpButton *panelList;
	NSBox *panelBox;

	NSMutableDictionary *modules;
}

+ (id) singleInstance;

- (void) showPanel: (id) sender;
- (void) showSubPanel: (id) sender;
- (void) layoutWindow;

- (void) registerPreferenceClass: (Class) aClass;

@end

#endif
