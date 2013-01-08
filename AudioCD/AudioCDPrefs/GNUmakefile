include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = AudioCD

ifeq ($(prefs), sysprefs)
  BUNDLE_EXTENSION = .prefPane

  ifeq ($(findstring darwin, $(GNUSTEP_TARGET_OS)), darwin)
    ADDITIONAL_GUI_LIBS += -lGSPreferencePanes
  else
    ADDITIONAL_GUI_LIBS += -lPreferencePanes
  endif
  ADDITIONAL_CPPFLAGS += -DSYSPREFS=1
else
  BUNDLE_EXTENSION = .prefs
  ADDITIONAL_CPPFLAGS += -DSYSPREFS=0
endif

AudioCD_HAS_RESOURCE_BUNDLE = yes
AudioCD_PRINIPAL_CLASS = AudioCD

AudioCD_LANGUAGES = \
	English \
	German \
	French

AudioCD_LOCALIZED_RESOURCE_FILES = \
	AudioCD.gorm \
	Localizable.strings

AudioCD_RESOURCE_FILES = AudioCD.tiff
#ifeq ($(prefs), sysprefs)
#  AudioCD_RESOURCE_FILES += Info.plist
#endif

AudioCD_OBJC_FILES = AudioCDView.m
ifeq ($(prefs), sysprefs)
  AudioCD_OBJC_FILES += AudioCD_SysPrefs.m
else
  AudioCD_OBJC_FILES += AudioCD.m
endif

AudioCD_HEADERS = AudioCDView.h
ifeq ($(prefs), sysprefs)
  AudioCD_HEADERS += AudioCD_SysPrefs.h
else
  AudioCD_HEADERS += AudioCD.h
endif

AudioCD_PRINCIPAL_CLASS= \
	AudioCD

include $(GNUSTEP_MAKEFILES)/bundle.make

-include GNUmakefile.preamble
-include GNUmakefile.postamble
