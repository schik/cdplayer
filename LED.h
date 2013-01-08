#ifndef __LED_H_INCLUDED
#define __LED_H_INCLUDED

#include <AppKit/AppKit.h>


@interface LED : NSView
{
	NSImage		*led[13];

	int		track;
	int		min;
	int		sec;
}

- initWithFrame:(NSRect)frame;

- (void)setTrack:(int)track;
- (void)setMin:(int)min;
- (void)setSec:(int)sec;
- (void)setNoCD;

@end

#endif
