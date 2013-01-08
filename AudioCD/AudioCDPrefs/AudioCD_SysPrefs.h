/* All Rights reserved */

#ifndef __AUDIOCD_H_INCLUDED
#define __AUDIOCD_H_INCLUDED

#include <AppKit/AppKit.h>

#ifdef __APPLE__
  #include <GSPreferencePanes/PreferencePanes.h>
#else
  #include <PreferencePanes/PreferencePanes.h>
#endif

@interface AudioCD : NSPreferencePane
{
  IBOutlet NSTableView *driveList;
  IBOutlet NSTextField *driveInput;
  IBOutlet NSButton *addButton;
  IBOutlet NSButton *removeButton;
}

- (IBAction) addButtonClicked: (id)sender;
- (IBAction) removeButtonClicked: (id)sender;

@end

#endif
