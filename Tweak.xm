#import <UIKit/UIKit2.h>
#import <QuartzCore/QuartzCore2.h>
#import <SpringBoard/SpringBoard.h>
#import <IOSurface/IOSurface.h>
#import <substrate.h>

@interface UIImage (IOSurface)
- (id)_initWithIOSurface:(IOSurfaceRef)surface scale:(CGFloat)scale orientation:(UIImageOrientation)orientation;
@end

@interface FastBlurredBackgroundView : UIView {
	UIImageView *_activeView;
}
- (void)setBackground:(UIImage *)background;
@end

@implementation FastBlurredBackgroundView : UIView
- (id)initWithFrame:(CGRect)frame {
	if ((self = [super initWithFrame:frame])) {
		self.clipsToBounds = YES;
	}
	return self;
}

- (void)dealloc {
	[_activeView release];
	_activeView = nil;
	[super dealloc];
}

- (void)setBackground:(UIImage *)background {
	if (_activeView) {
		_activeView.image = background;
		_activeView.frame = CGRectMake(0, 0, background.size.width, background.size.height);
	} else {
		_activeView = [[UIImageView alloc] initWithImage:background];
		static NSArray *filters = nil;
		if (!filters) {
			CAFilter *saturate = [CAFilter filterWithType:@"colorSaturate"];
			[saturate setValue:[NSNumber numberWithFloat:2.0f] forKey:@"inputAmount"];
			CAFilter *contrast = [CAFilter filterWithType:@"colorContrast"];
			[contrast setValue:[NSNumber numberWithFloat:0.75f] forKey:@"inputAmount"];
			CAFilter *filter = [CAFilter filterWithType:@"gaussianBlur"];
			[filter setValue:[NSNumber numberWithFloat:18.0f] forKey:@"inputRadius"];
			[filter setValue:[NSNumber numberWithBool:YES] forKey:@"inputHardEdges"];
			filters = [[NSArray alloc] initWithObjects:contrast, saturate, filter, nil];
		}
		CALayer *layer = _activeView.layer;
		layer.filters = filters;
		layer.shouldRasterize = YES;
		_activeView.alpha = 0.8f;
		[self addSubview:_activeView];
	}
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
	if ([keyPath isEqualToString:@"frame"]) {
		CGRect frame = [(UIView *)object frame];
		self.bounds = frame;
		frame.origin.y = 0;
		self.frame = frame;
	}
}

@end

%hook SBNotificationCenterViewController

- (id)_newBackgroundView {
	FastBlurredBackgroundView *backgroundView = [[%c(FastBlurredBackgroundView) alloc] initWithFrame:[UIScreen mainScreen].bounds];
	backgroundView.backgroundColor = [UIColor blackColor];
	return backgroundView;
}

- (void)viewWillAppear:(BOOL)animated {
	%orig;
	IOSurfaceRef surface = [UIWindow createScreenIOSurface];
	UIImageOrientation imageOrientation;
	switch ([(SpringBoard *)UIApp activeInterfaceOrientation]) {
		case UIInterfaceOrientationPortrait:
		default:
			imageOrientation = UIImageOrientationUp;
			break;
		case UIInterfaceOrientationPortraitUpsideDown:
			imageOrientation = UIImageOrientationDown;
			break;
		case UIInterfaceOrientationLandscapeLeft:
			imageOrientation = UIImageOrientationRight;
			break;
		case UIInterfaceOrientationLandscapeRight:
			imageOrientation = UIImageOrientationLeft;
			break;
	}
	UIImage *image = [[UIImage alloc] _initWithIOSurface:surface scale:[UIScreen mainScreen].scale orientation:imageOrientation];
	CFRelease(surface);
	[MSHookIvar<FastBlurredBackgroundView *>(self, "_backgroundView") setBackground:image];
	[image release];
	[MSHookIvar<UIView *>(self, "_containerView") addObserver:MSHookIvar<UIView *>(self, "_backgroundView") forKeyPath:@"frame" options:0 context:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
	%orig;
	[MSHookIvar<UIView *>(self, "_containerView") removeObserver:MSHookIvar<UIView *>(self, "_backgroundView") forKeyPath:@"frame"];
}

%end

%hook SBControlCenterContentContainerView

static FastBlurredBackgroundView *controlCenterBackground;

- (void)controlCenterWillPresent {
	%orig;
	if ([[[self subviews] firstObject] isKindOfClass:[%c(_UIBackdropView) class]]) {
		[(UIView *)[[self subviews] firstObject] removeFromSuperview];
		controlCenterBackground = [[%c(FastBlurredBackgroundView) alloc] initWithFrame:[UIScreen mainScreen].bounds];
		controlCenterBackground.backgroundColor = [UIColor whiteColor];
		[self insertSubview:controlCenterBackground atIndex:0];
	}
	IOSurfaceRef surface = [UIWindow createScreenIOSurface];
	UIImageOrientation imageOrientation;
	switch ([(SpringBoard *)UIApp activeInterfaceOrientation]) {
		case UIInterfaceOrientationPortrait:
		default:
			imageOrientation = UIImageOrientationUp;
			break;
		case UIInterfaceOrientationPortraitUpsideDown:
			imageOrientation = UIImageOrientationDown;
			break;
		case UIInterfaceOrientationLandscapeLeft:
			imageOrientation = UIImageOrientationRight;
			break;
		case UIInterfaceOrientationLandscapeRight:
			imageOrientation = UIImageOrientationLeft;
			break;
	}
	UIImage *image = [[UIImage alloc] _initWithIOSurface:surface scale:[UIScreen mainScreen].scale orientation:imageOrientation];
	CFRelease(surface);
	[controlCenterBackground setBackground:image];
	[image release];
	[self addObserver:controlCenterBackground forKeyPath:@"frame" options:0 context:nil];
}

- (void)controlCenterDidDismiss {
	%orig;
	[self removeObserver:controlCenterBackground forKeyPath:@"frame"];
}

- (void)dealloc {
	[controlCenterBackground release];
	controlCenterBackground = nil;
	%orig;
}

%end