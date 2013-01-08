#include "LED.h"


#define	LED_COLLON	10
#define	LED_NONE	11
#define	LED_MINUS	12


@implementation LED

- initWithFrame:(NSRect)frameRect
{
	NSBundle	*bundle = [NSBundle mainBundle];
	NSString	*imagePath;
	int		i;


	self = [super initWithFrame: frameRect];

	for(i = 0; i < 13; i++)
	{
		imagePath = [bundle pathForResource: [NSString stringWithFormat: @"led%d", i] ofType: @"tiff"];
		led[i] = [[NSImage alloc] initWithContentsOfFile: imagePath];
		if(led[i] == nil)	NSLog(@"Couldn't load led%d.tiff", i);
	}


	return self;
}

- (void)dealloc
{
	int	i;

	for(i = 0; i < 13; i++)
	{
		[led[i] release];
	}

	[super dealloc];
}

- (void)setTrack:(int)_track
{
	track = _track;
}

- (void)setMin:(int)_min
{
	min = _min;
}

- (void)setSec:(int)_sec
{
	sec = _sec;
}

- (void)setNoCD
{
	sec = -1;
	min = -1;
	track = -1;
}

- (void)drawRect:(NSRect)_rect
{
	NSPoint		point;
	NSRect		rect = [self bounds];
	float		pad_x = (rect.size.width - 124) / 3;
	float		pad_y = (rect.size.height - 22) / 2;


	// 枠の描画
	PSsetgray(NSBlack);
	NSRectFill(rect);
	PSsetgray(NSWhite);
	PSmoveto(1, 1);
	PSlineto(rect.size.width - 1, 1);
	PSlineto(rect.size.width - 1, rect.size.height);
	PSstroke();

	// コロンの描画
	point = NSMakePoint(pad_x + 40 + pad_x + 40 , pad_y);
	[led[10] compositeToPoint: point operation: NSCompositeCopy];


	// 数字の部分の描画
	if(sec < 0)
	{
		// CDが入っていない時
		point = NSMakePoint(pad_x + 40 + pad_x + 40 + 4, pad_y);
		[led[12] compositeToPoint: point operation: NSCompositeCopy];
		point = NSMakePoint(pad_x + 40 + pad_x + 40 + 4 + 20, pad_y);
		[led[12] compositeToPoint: point operation: NSCompositeCopy];
		point = NSMakePoint(pad_x + 40 + pad_x, pad_y);
		[led[12] compositeToPoint: point operation: NSCompositeCopy];
		point = NSMakePoint(pad_x + 40 + pad_x + 20, pad_y);
		[led[12] compositeToPoint: point operation: NSCompositeCopy];
		point = NSMakePoint(pad_x, pad_y);
		[led[12] compositeToPoint: point operation: NSCompositeCopy];
		point = NSMakePoint(pad_x + 20, pad_y);
		[led[12] compositeToPoint: point operation: NSCompositeCopy];
	}
	else
	{
		int		n1;
		int		n2;


		n1 = (sec % 100) / 10;
		n2 = sec % 10;
		point = NSMakePoint(pad_x + 40 + pad_x + 40 + 4, pad_y);
		[led[n1] compositeToPoint: point operation: NSCompositeCopy];
		point = NSMakePoint(pad_x + 40 + pad_x + 40 + 4 + 20, pad_y );
		[led[n2] compositeToPoint: point operation: NSCompositeCopy];

		n1 = (min % 100) / 10;
		n2 = min % 10;
		point = NSMakePoint(pad_x + 40 + pad_x, pad_y);
		[led[n1] compositeToPoint: point operation: NSCompositeCopy];
		point = NSMakePoint(pad_x + 40 + pad_x + 20, pad_y);
		[led[n2] compositeToPoint: point operation: NSCompositeCopy];

		n1 = (track % 100) / 10;
		n2 = track % 10;
		point = NSMakePoint(pad_x, pad_y);
		[led[n1] compositeToPoint: point operation: NSCompositeCopy];
		point = NSMakePoint(pad_x + 20, pad_y);
		[led[n2] compositeToPoint: point operation: NSCompositeCopy];
	}
}

@end
