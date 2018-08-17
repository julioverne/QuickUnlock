include $(THEOS)/makefiles/common.mk

TWEAK_NAME = QuickUnlock

QuickUnlock_FILES = /mnt/d/codes/quickunlock/Tweak.xm
QuickUnlock_FRAMEWORKS = CoreGraphics QuartzCore CydiaSubstrate
QuickUnlock_PRIVATE_FRAMEWORKS = 
QuickUnlock_LDFLAGS = -Wl,-segalign,4000

export ARCHS = armv7 arm64
QuickUnlock_ARCHS = armv7 arm64

include $(THEOS_MAKE_PATH)/tweak.mk
	
all::
