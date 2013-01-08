/* All Rights reserved */

#ifndef __AUDIOCD_H_INCLUDED
#define __AUDIOCD_H_INCLUDED

#include <AppKit/AppKit.h>

#include <PrefsModule/PrefsModule.h>

@interface AudioCD : NSObject <PrefsModule>
{
  IBOutlet NSTableView *driveList;
  IBOutlet NSTextField *driveInput;
  IBOutlet NSButton *addButton;
  IBOutlet NSButton *removeButton;
  IBOutlet id view;
  IBOutlet NSWindow *_window;
}

- (IBAction) addButtonClicked: (id)sender;
- (IBAction) removeButtonClicked: (id)sender;

@end

#endif
