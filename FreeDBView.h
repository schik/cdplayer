/* vim: set ft=objc ts=4 nowrap: */
/* All Rights reserved */

#ifndef FREEDBVIEW_H_INCLUDED
#define FREEDBVIEW_H_INCLUDED

#include <AppKit/AppKit.h>

@interface FreeDBView : NSObject
{
  id view;
  id window;
  id autoQueryButton;
  id serverTextField;
  id serversTableView;

  // Other ivars
  NSMutableArray *siteList;
  Class cddbClass;
}

- (id) init;

- (void) saveChanges;

- (NSString *) name;
- (NSView *) view;

- (void) listOfSites: (id)sender;

- (void) tableViewSelectionDidChange: (NSNotification *) not;
- (int) numberOfRowsInTableView: (NSTableView *) aView;
- (id) tableView: (NSTableView *) aView
           objectValueForTableColumn: (NSTableColumn *) aColumn
           row: (int) row;

+ (id) singleInstance;

@end

#endif
