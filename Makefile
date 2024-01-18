TARGET = simulator:clang:latest:10.0
ARCHS = x86_64 i386

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = EmojiCategoryMS
$(TWEAK_NAME)_FILES = Tweak.xm
$(TWEAK_NAME)_USE_SUBSTRATE = 1

include $(THEOS_MAKE_PATH)/tweak.mk

all::
	@rm -f /opt/simject/$(TWEAK_NAME).dylib
	@cp -v $(THEOS_OBJ_DIR)/$(TWEAK_NAME).dylib /opt/simject
	@cp -v $(PWD)/$(TWEAK_NAME).plist /opt/simject
