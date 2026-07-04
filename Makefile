DEBUG = 0
FINALPACKAGE = 1
ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:14.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = BetterLinkedIn
BetterLinkedIn_FILES = Tweak.x
BetterLinkedIn_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
