
include $(GNUSTEP_MAKEFILES)/common.make

# Subprojects 
SUBPROJECTS = \
	AudioCD \
	Cddb

APP_NAME = CDPlayer
CDPlayer_APPLICATION_ICON=app.tiff

# The Objective-C source files to be compiled
CDPlayer_OBJC_FILES = \
	CDPlayer_main.m \
	Controller.m \
	Player.m \
	Preferences.m \
	TrackList.m \
	TrackListView.m \
	FreeDBView.m \
	GeneralView.m \
	BundleManager.m \
	SliderCell.m \
	LED.m

CDPlayer_C_FILES = \
	rb.c

#
# Additional libraries
#
ifneq ($(notifications), no)
    CDPlayer_OBJCFLAGS += -DNOTIFICATIONS
    CDPlayer_GUI_LIBS = -lDBusKit
endif

# The Resource files to be copied into the app's resources directory
CDPlayer_RESOURCE_FILES = \
	Resources/TrackList.gorm \
	Images/*.tiff \
	CDPlayer.help

CDPlayer_LANGUAGES=English German French
CDPlayer_LOCALIZED_RESOURCE_FILES = \
	Localizable.strings \
	General.gorm \
	FreeDB.gorm

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/aggregate.make
include $(GNUSTEP_MAKEFILES)/application.make

-include GNUmakefile.postamble

