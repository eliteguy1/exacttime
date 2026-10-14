ARCHS = arm64 arm64e
export TARGET = iphone:clang:latest:16.5
include $(THEOS)/makefiles/common.mk

FINALPACKAGE=1

TWEAK_NAME = ExactTime ExactTimeMail ExactTimePhone ExactTimeMessages

ExactTime_FILES = ExactTime.xm
ExactTime_CFLAGS = -fno-objc-arc -Wno-deprecated-declarations -Wno-unused-variable
ExactTime_FRAMEWORKS = UIKit Foundation CoreFoundation

ExactTimeMail_FILES = ExactTimeMail.x
ExactTimeMail_CFLAGS = -fno-objc-arc -Wno-deprecated-declarations -Wno-unused-variable
ExactTimeMail_FRAMEWORKS = UIKit Foundation CoreFoundation

ExactTimePhone_FILES = ExactTimePhone.x
ExactTimePhone_CFLAGS = -fno-objc-arc -Wno-deprecated-declarations -Wno-unused-variable
ExactTimePhone_FRAMEWORKS = UIKit Foundation CoreFoundation

ExactTimeMessages_FILES = ExactTimeMessages.xm
ExactTimeMessages_CFLAGS = -fno-objc-arc -Wno-deprecated-declarations -Wno-unused-variable
ExactTimeMessages_FRAMEWORKS = UIKit Foundation CoreFoundation

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += exacttimeprefs
include $(THEOS)/makefiles/aggregate.mk
