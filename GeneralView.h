/* vim: set ft=objc ts=4 nowrap: */
/* All Rights reserved */

#ifndef GENERALVIEW_H_INCLUDED
#define GENERALVIEW_H_INCLUDED

#include <AppKit/AppKit.h>

@interface GeneralView : NSObject
{
	id view;
	id window;
	id exitMatrix;
	id deviceField;
	id outputList;
	NSString *outputBundle;

	NSMutableArray *playersList;
}

- (id) init;

- (void) saveChanges;

- (NSString *) name;
- (NSView *) view;

- (void) registerOutputClass: (Class) aClass;
- (Class) preferredOutputClass;

+ (id) singleInstance;

@end

#endif
