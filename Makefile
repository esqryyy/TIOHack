ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:16.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = TIOHack
TIOHack_FILES = Tweak.m
TIOHack_CFLAGS = -fobjc-arc
TIOHack_LIBRARIES = substrate

include $(THEOS)/makefiles/tweak.mk
