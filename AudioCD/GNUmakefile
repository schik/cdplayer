include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = AudioCD
BUNDLE_EXTENSION = .bundle

AudioCD_RESOURCE_FILES =

AudioCD_OBJC_FILES = AudioCD.m

AudioCD_HEADER_FILES = AudioCDProtocol.h

AudioCD_PRINCIPAL_CLASS = AudioCD

ADDITIONAL_OBJCFLAGS = -Wall

ADDITIONAL_INCLUDE_DIRS += -I..

ADDITIONAL_LIBS := -lcdio -lcdio_cdda -lcdio_paranoia

ifneq ($(musicbrainz), no)
    ADDITIONAL_OBJCFLAGS += -DMUSICBRAINZ
    ADDITIONAL_LIBS += -ldiscid
endif

ifeq (mingw32, $(GNUSTEP_TARGET_OS))
    ADDITIONAL_GUI_LIBS += $(ADDITIONAL_LIBS)
else
    BUNDLE_LIBS += $(ADDITIONAL_LIBS)
endif


-include GNUmakefile.preable

include $(GNUSTEP_MAKEFILES)/bundle.make

-include GNUmakefile.postamble
