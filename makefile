#
# Maestix Library
#
# Copyright (C) 2021 Richard "Shred" Koerber
#	http://maestix.shredzone.org
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.
#

SRCP      = src
INCP      = include
REFP      = reference
DSTP      = distribution
OBJP      = build
RELP      = release
DOCP      = docs

MA_OBJS   = $(OBJP)/MA_Main.o $(OBJP)/MA_Hardware.o $(OBJP)/MA_Interrupt.o \
		$(OBJP)/MA_FIFO.o $(OBJP)/MA_Realtime.o $(OBJP)/MA_EndCode.o

GOPTS     = -esc -sc \
		-I $(INCP) -I $(REFP) -I ${AMIGA_NDK}/Include/include_i/ -I ${AMIGA_INCLUDES} \
		-D_MAKE_68020
AOPTS     = -Fhunk $(GOPTS)
COPTS     = +aos68k -c99 -lauto -lamiga -cpu=68020 \
		-I${VBCC}/targets/m68k-amigaos/include \
		-I$(REFP) -I${AMIGA_NDK}/Include/include_h/ -I${AMIGA_INCLUDES} \
		-L=${AMIGA_NDK}/Include/linker_libs/
LOPTS     = -bamigahunk -mrel -s \
		-L ${AMIGA_NDK}/Include/linker_libs/ -l debug -l amiga

.PHONY : all clean release check

all: $(OBJP) \
		$(REFP)/inline/maestix_protos.h \
		$(REFP)/proto/maestix.h \
		$(OBJP)/MaestixFX \
		$(OBJP)/maestix.library \
		$(OBJP)/AllocMstx \
		$(OBJP)/FreeMstx \
		$(OBJP)/MaestroPEG \
		$(OBJP)/SetMstx \
		$(OBJP)/examples/AnalyzeInput \
		$(OBJP)/examples/CSBchanger \
		$(OBJP)/examples/LevelWindow \
		$(OBJP)/examples/Realtime \
		$(OBJP)/examples/RealtimeEcho \
		$(OBJP)/examples/SineTone \
		$(OBJP)/examples/Surround \
		$(OBJP)/maestropro.audio \
		$(OBJP)/MAESTROPRO

clean:
	rm -rf $(OBJP) $(RELP) $(REFP)/inline/maestix_protos.h $(REFP)/proto/maestix.h

release: clean all
	cp -r $(DSTP) $(RELP)				# Create base structure and static files
	mkdir $(RELP)/Maestix/c
	mkdir $(RELP)/Maestix/examples
	mkdir $(RELP)/Maestix/include
	mkdir $(RELP)/Maestix/libs
	mkdir $(RELP)/MaestixAHI/devs
	mkdir $(RELP)/MaestixAHI/devs/AHI
	mkdir $(RELP)/MaestixAHI/devs/AudioModes

	cp $(OBJP)/MaestixFX $(RELP)/Maestix/				# Tools

	cp $(OBJP)/AllocMstx $(RELP)/Maestix/c/				# C
	cp $(OBJP)/FreeMstx $(RELP)/Maestix/c/
	cp $(OBJP)/MaestroPEG $(RELP)/Maestix/c/
	cp $(OBJP)/SetMstx $(RELP)/Maestix/c/

	cp -r $(SRCP)/examples/* $(RELP)/Maestix/examples/		# Examples
	cp -r $(OBJP)/examples/* $(RELP)/Maestix/examples/

	cp -r $(REFP)/* $(RELP)/Maestix/include/			# Includes

	cp $(OBJP)/maestix.library $(RELP)/Maestix/libs/	# Libraries

	cp $(OBJP)/maestropro.audio $(RELP)/MaestixAHI/devs/AHI		# AHI
	cp $(OBJP)/MAESTROPRO $(RELP)/MaestixAHI/devs/AudioModes

	cp $(DOCP)/maestix.doc $(RELP)/Maestix/				# Docs
	cp $(DOCP)/Maestix.guide $(RELP)/Maestix/
	cp $(DOCP)/MaestixAHI.guide $(RELP)/MaestixAHI/

	rm -f $(OBJP)/Maestix.lha							# Package
	cd $(RELP) ; lha c -q1 ../$(OBJP)/Maestix.lha *
	mv $(OBJP)/Maestix.lha $(RELP)/
	cp $(DOCP)/Maestix.readme $(RELP)/

check:
	# Check for umlauts and other characters that are not platform neutral.
	# The following command will show the files and lines, and highlight the
	# illegal character. It should be replaced with an escape sequence.
	LC_ALL=C grep -R --color='auto' -P -n "[^\x00-\x7F]" $(SRCP) $(INCP) $(REFP) ; true

$(OBJP):
	mkdir -p $(OBJP)
	mkdir -p $(OBJP)/examples

#-- pragmas

$(REFP)/inline/maestix_protos.h: $(REFP)/fd/maestix_lib.fd $(REFP)/clib/maestix_protos.h
	mkdir -p $(REFP)/inline/
	fd2pragma --infile $(REFP)/fd/maestix_lib.fd --clib $(REFP)/clib/maestix_protos.h \
		--to $(REFP)/inline/ --special 70 --autoheader --comment

$(REFP)/proto/maestix.h: $(REFP)/fd/maestix_lib.fd $(REFP)/clib/maestix_protos.h
	mkdir -p $(REFP)/proto/
	fd2pragma --infile $(REFP)/fd/maestix_lib.fd --clib $(REFP)/clib/maestix_protos.h \
		--to $(REFP)/proto/ --special 38 --autoheader --comment

#-- maestix.library

$(OBJP)/maestix.library: $(MA_OBJS)
	vlink $(LOPTS) -o $(OBJP)/maestix.library -s $(MA_OBJS)

$(OBJP)/MA_Main.o: $(SRCP)/library/MA_Main.s
	vasmm68k_mot $(AOPTS) -o $(OBJP)/MA_Main.o $(SRCP)/library/MA_Main.s

$(OBJP)/MA_Hardware.o: $(SRCP)/library/MA_Hardware.s
	vasmm68k_mot $(AOPTS) -o $(OBJP)/MA_Hardware.o $(SRCP)/library/MA_Hardware.s

$(OBJP)/MA_Interrupt.o: $(SRCP)/library/MA_Interrupt.s
	vasmm68k_mot $(AOPTS) -o $(OBJP)/MA_Interrupt.o $(SRCP)/library/MA_Interrupt.s

$(OBJP)/MA_FIFO.o: $(SRCP)/library/MA_FIFO.s
	vasmm68k_mot $(AOPTS) -o $(OBJP)/MA_FIFO.o $(SRCP)/library/MA_FIFO.s

$(OBJP)/MA_Realtime.o: $(SRCP)/library/MA_Realtime.s
	vasmm68k_mot $(AOPTS) -o $(OBJP)/MA_Realtime.o $(SRCP)/library/MA_Realtime.s

$(OBJP)/MA_EndCode.o: $(SRCP)/library/MA_EndCode.s
	vasmm68k_mot $(AOPTS) -o $(OBJP)/MA_EndCode.o $(SRCP)/library/MA_EndCode.s

#-- maestix tools

$(OBJP)/AllocMstx: $(SRCP)/tools/MA_T_AllocMstx.s
	vasmm68k_mot $(AOPTS) -o $(OBJP)/MA_T_AllocMstx.o $(SRCP)/tools/MA_T_AllocMstx.s
	vlink $(LOPTS) -o $(OBJP)/AllocMstx -s $(OBJP)/MA_T_AllocMstx.o

$(OBJP)/FreeMstx: $(SRCP)/tools/MA_T_FreeMstx.s
	vasmm68k_mot $(AOPTS) -o $(OBJP)/MA_T_FreeMstx.o $(SRCP)/tools/MA_T_FreeMstx.s
	vlink $(LOPTS) -o $(OBJP)/FreeMstx -s $(OBJP)/MA_T_FreeMstx.o

$(OBJP)/MaestroPEG: $(SRCP)/maestropeg/MaestroPEG.c
	vc $(COPTS) -o=$(OBJP)/MaestroPEG $(SRCP)/maestropeg/MaestroPEG.c

$(OBJP)/SetMstx: $(SRCP)/tools/MA_T_SetMstx.s
	vasmm68k_mot $(AOPTS) -o $(OBJP)/MA_T_SetMstx.o $(SRCP)/tools/MA_T_SetMstx.s
	vlink $(LOPTS) -o $(OBJP)/SetMstx -s $(OBJP)/MA_T_SetMstx.o

$(OBJP)/MaestixFX : $(SRCP)/maestixfx/MaestixFX.c
	vc $(COPTS) -o=$(OBJP)/MaestixFX  $(SRCP)/maestixfx/MaestixFX.c

#-- examples

$(OBJP)/examples/AnalyzeInput: $(SRCP)/examples/AnalyzeInput.s
	vasmm68k_mot $(AOPTS) -o $(OBJP)/AnalyzeInput.o $(SRCP)/examples/AnalyzeInput.s
	vlink $(LOPTS) -o $(OBJP)/examples/AnalyzeInput -s $(OBJP)/AnalyzeInput.o

$(OBJP)/examples/CSBchanger: $(SRCP)/examples/CSBchanger.s
	vasmm68k_mot $(AOPTS) -o $(OBJP)/CSBchanger.o $(SRCP)/examples/CSBchanger.s
	vlink $(LOPTS) -o $(OBJP)/examples/CSBchanger -s $(OBJP)/CSBchanger.o

$(OBJP)/examples/LevelWindow: $(SRCP)/examples/LevelWindow.s
	vasmm68k_mot $(AOPTS) -o $(OBJP)/LevelWindow.o $(SRCP)/examples/LevelWindow.s
	vlink $(LOPTS) -o $(OBJP)/examples/LevelWindow -s $(OBJP)/LevelWindow.o

$(OBJP)/examples/Realtime: $(SRCP)/examples/Realtime.s
	vasmm68k_mot $(AOPTS) -o $(OBJP)/Realtime.o $(SRCP)/examples/Realtime.s
	vlink $(LOPTS) -o $(OBJP)/examples/Realtime -s $(OBJP)/Realtime.o

$(OBJP)/examples/RealtimeEcho: $(SRCP)/examples/RealtimeEcho.s
	vasmm68k_mot $(AOPTS) -o $(OBJP)/RealtimeEcho.o $(SRCP)/examples/RealtimeEcho.s
	vlink $(LOPTS) -o $(OBJP)/examples/RealtimeEcho -s $(OBJP)/RealtimeEcho.o

$(OBJP)/examples/SineTone: $(SRCP)/examples/SineTone.s
	vasmm68k_mot $(AOPTS) -o $(OBJP)/SineTone.o $(SRCP)/examples/SineTone.s
	vlink $(LOPTS) -o $(OBJP)/examples/SineTone -s $(OBJP)/SineTone.o

$(OBJP)/examples/Surround: $(SRCP)/examples/Surround.s
	vasmm68k_mot $(AOPTS) -o $(OBJP)/Surround.o $(SRCP)/examples/Surround.s
	vlink $(LOPTS) -o $(OBJP)/examples/Surround -s $(OBJP)/Surround.o

#-- AHI driver

$(OBJP)/maestropro.audio: $(SRCP)/ahi/AHI_MaestroPro.s
	vasmm68k_mot $(AOPTS) -o $(OBJP)/AHI_MaestroPro.o $(SRCP)/ahi/AHI_MaestroPro.s
	vlink $(LOPTS) -o $(OBJP)/maestropro.audio -s $(OBJP)/AHI_MaestroPro.o

$(OBJP)/MAESTROPRO: $(SRCP)/ahi/AHI_PrefsFile.s
	vasmm68k_mot -Fbin $(GOPTS) -o $(OBJP)/MAESTROPRO $(SRCP)/ahi/AHI_PrefsFile.s
