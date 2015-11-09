include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = MusicBrainz
BUNDLE_EXTENSION = .bundle

MusicBrainz_RESOURCE_FILES =

MusicBrainz_OBJC_FILES = MusicBrainz.m

MusicBrainz_HEADERS = MusicBrainz.h

MusicBrainz_PRINCIPAL_CLASS = MusicBrainz

MusicBrainz_HEADER_FILES = MusicBrainz.h
MusicBrainz_HEADER_FILES_DIR = .
MusicBrainz_HEADER_FILES_INSTALL_DIR = MusicBrainz

ADDITIONAL_OBJCFLAGS = -Wall

ADDITIONAL_INCLUDE_DIRS += -I..

ADDITIONAL_GUI_LIBS += -lmusicbrainz5 -lcoverart

-include GNUmakefile.preable

include $(GNUSTEP_MAKEFILES)/bundle.make

-include GNUmakefile.postamble
