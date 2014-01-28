ARCHS=armv7 arm64
include /opt/theos/makefiles/common.mk

TWEAK_NAME = FastBlurredNotificationCenter7
FastBlurredNotificationCenter7_FILES = Tweak.xm
FastBlurredNotificationCenter7_FRAMEWORKS = UIKit QuartzCore

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 backboardd"