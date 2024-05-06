#!/bin/sh

#------------------------------------------------------------------------------#
#!/usr/bin/env bash
#
# Dieses Skript verändert NICHT die Bildwiederholrate!
#
# Das Ergebnis besteht immer aus folgendem Format:
#  - WebM:    webm   + VP9        + Opus    (kann nur das eine Untertitelformat WebVTT)
#  - MKV:     mkv    + AV1        + Vorbis  (das z.Z. beste Format, leider aber kein HTML5-Standard)
#  - MP4:     mp4    + H.264/AVC  + AAC     (das z.Z. mit Abstand kompatibelste Format)
#  - MP4:     mp4    + H.265/HEVC + AAC
#  - AVCHD:   m2ts   + H.264/AVC  + AC-3
#  - AVI:     avi    + DivX5      + MP3
#  - FLV:     flv    + FLV        + MP3     (Sorenson Spark: H.263)
#  - 3GPP:    3gp    + H.263      + AAC     (128x96 176x144 352x288 704x576 1408x1152)
#  - 3GPP2:   3g2    + H.263      + AAC     (128x96 176x144 352x288 704x576 1408x1152)
#  - OGG:     ogg    + Theora     + Vorbis
#  - MPEG:    mpg/ts + MPEG-1/2   + MP2/AC-3 (bei kleinen Bitraten ist MPEG-1 besser)
#
# https://de.wikipedia.org/wiki/Containerformat
#
#------------------------------------------------------------------------------#
#
# Es werden folgende Programme von diesem Skript verwendet:
#  - bash
#  - ffmpeg
#  - ffprobe
#  - ggf. noch externe Bibliotheken für ffmpeg
#  - und weitere Unix-Shell-Werkzeuge (z.B. du, sed und awk)
#
#------------------------------------------------------------------------------#

VERSION="v2024050600"			# erstellt

VERSION_METADATEN="${VERSION}"

#set -x
PATH="${PATH}:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

LANG=C					# damit AWK richtig rechnet
#FFMPEG_OPTIONEN="-benchmark -report"
FFMPEG_OPTIONEN="-benchmark"
Film2Standardformat_OPTIONEN="${@}"
TEST="Nein"
STOP="Nein"
BILDQUALIT="auto"
TONQUALIT="auto"
ORIGINAL_DAR="Ja"

AVERZ="$(dirname ${0})"			# Arbeitsverzeichnis, hier liegen diese Dateien

### die Pixel sollten wenigstens durch 2 teilbar sein! besser aber durch 8                          
TEILER="2"
##TEILER="4"
#TEILER="8"
###TEILER="16"

ZUFALL="$(head -c 100 /dev/urandom | base64 | tr -d '\n' | tr -cd '[:alnum:]' | cut -b-12)"

#------------------------------------------------------------------------------#
### diese Optionen sind für ffprobe und ffmpeg notwendeig,
### damit auch die Spuren gefunden werden, die später als 5 Sekunden nach
### Filmbeginn einsetzen

## -probesize 18446744070G		# I64_MAX
## -analyzeduration 18446744070G	# I64_MAX
#KOMPLETT_DURCHSUCHEN="-probesize 18446744070G -analyzeduration 18446744070G"

## Value 19807040624582983680.000000 for parameter 'analyzeduration' out of range [0 - 9.22337e+18]
## Value 19807040624582983680.000000 for parameter 'analyzeduration' out of range [0 - 9.22337e+18]
## -probesize 9223370Ki
## -analyzeduration 9223370Ki

if [ x = "x${FFPROBE_PROBESIZE}" ] ; then
	#FFPROBE_PROBESIZE="9223372036"		# Maximalwert in GiB auf einem Intel(R) Core(TM) i5-10600T CPU @ 2.40GHz
	FFPROBE_PROBESIZE="9223372036854"	# Maximalwert in MiB auf einem Intel(R) Core(TM) i5-10600T CPU @ 2.40GHz
fi

#==============================================================================#
### Funktionen

#------------------------------------------------------------------------------#

bildaufloesungen_namen()
{
### viele Namen von Bildauflösungen, sortiert nach Qualität (aufsteigend):
echo "
	-soll_xmaly SQCIF		# 128x96 4/3         ; Level 1.0 - es ist ein h263-Format
	-soll_xmaly QQVGA		# 160x120 4/3        ; Level 1.1
	-soll_xmaly 192x108		# 192x108 16/9       ; Level 1.1
	-soll_xmaly GB			# 160x144 4/3        ; Level 1.1
	-soll_xmaly QCIF		# 176x144 4/3        ; Level 1.1 - es ist ein h263-Format
	-soll_xmaly Palm_LoRes		# 160x160 1/1        ; Level 1.1
	-soll_xmaly GBA			# 240x160 3/2        ; Level 1.2
	-soll_xmaly VGA8		# 240x180 4/3        ; Level 1.2
	-soll_xmaly 3DS			# 256x192 4/3        ; Level 1.2
	-soll_xmaly 234p		# 416x234 16/9       ; level 1.3 - kleinstes HLS-Format
	-soll_xmaly VCD			# 352x288 4/3        ; Level 1.3 - MPEG-1; MPEG-2-Profil: Low; es ist ein h263-Format
	-soll_xmaly Palm_HiRes		# 320x320 1/1        ; Level 2.1
	-soll_xmaly WQVGA		# 432x240 9/5        ; Level 2.1
	-soll_xmaly QSVGA		# 400x300 4/3        ; Level 2.1
	-soll_xmaly PSP			# 480x272 16/9       ; Level 2.1
	-soll_xmaly VHS			# 240x576 4/3        ; Level 2.1 - minimale VHS-Auflösung
	-soll_xmaly VIDEO8		# 250x576 4/3        ; Level 2.1 - VHS und Video8 (Sony und Polaroid brachten Video8 1985 auf den Markt. Hi8 und Digital 8 sind unterschiedliche Standards. Hi8 ist der Nachfolger für Video8.)
	-soll_xmaly VHS2		# 260x576 4/3        ; Level 2.1 - maximale VHS-Auflösung
	-soll_xmaly HVGA		# 480x320 3/2        ; Level 2.1
	-soll_xmaly PSION5		# 640x240 8/3        ; Level 2.1
	-soll_xmaly TV			# 330x576 4/3        ; Level 3.0 - analoges Fernsehsignal über Antenne
	-soll_xmaly 2CIF		# 704x288 4/3        ; Level 2.1
	-soll_xmaly EGA			# 640x350 4/3        ; Level 3.0
	-soll_xmaly SVHS		# 400x576 4/3        ; Level 3.0 - Die Auflösung des Bildes in der Horizontalachse wurde auf 400 Linien erhöht (VHS = 240-260 Linien). Hi8 hat auch 400 Linien in der Horizontalachse (Spalten).
	-soll_xmaly QHD_ready		# 640x360 16/9       ; Level 3.0
	-soll_xmaly HSVGA		# 600x400 3/2        ; Level 3.0
	-soll_xmaly PAL0		# 352x704 4/3        ; Level 3.0 - wirklich aktiver Bereich von analogem PAL
	-soll_xmaly HGC			# 720x348 4/3        ; Level 3.0
	-soll_xmaly MDA			# 720x350 4/3        ; Level 3.0
	-soll_xmaly Apple_Lisa		# 720x364 4/3        ; Level 3.0
	-soll_xmaly SVCD		# 480x576 4/3        ; Level 3.0
	-soll_xmaly DV			# 500x576 4/3        ; Level 3.0 - verbessertes S-VHS
	-soll_xmaly WGA			# 720x400 9/5        ; Level 3.0
	-soll_xmaly VGA			# 640x480 4/3        ; Level 3.0
	-soll_xmaly DVD 		# 550x576 4/3        ; Level 3.1
	-soll_xmaly 432p		# 768x432 16/9       ; Level 3.0
	-soll_xmaly NTSC		# 720x480 4/3        ; Level 3.0
	-soll_xmaly WVGA3		# 800x480 5/3        ; Level 3.0
	-soll_xmaly WVGA2		# 720x540 4/3        ; Level 3.0
	-soll_xmaly 4CIF		# 704x576 4/3        ; Level 3.0 - es ist ein h263-Format
	-soll_xmaly WVGA4		# 848x480 16/9       ; Level 3.0
	-soll_xmaly WVGA5		# 852x480 16/9       ; Level 3.0
	-soll_xmaly FWVGA		# 854x480 16/9       ; Level 3.0 - Full Wide VGA - Nintendo Wii U GamePad, LG K3 (LGE K100, LS450)
	-soll_xmaly PAL			# 720x576 4/3        ; Level 3.0 - MPEG-2-Profil: Main; Eigentlich hat PAL 625 Zeilen aber 49 Zeilen (eigentlich 2x25 Zeilen) werden zum stabilisieren des Elektronenstrahls benötigt, hier wurde VideoText übertragen.
	-soll_xmaly WVGA7		# 864x480 9/5        ; Level 3.0
	-soll_xmaly WVGA6		# 858x484 16/9       ; Level 3.1
	-soll_xmaly PAL-D		# 768x576 4/3        ; Level 3.1
	-soll_xmaly BETA		# 800x576 4/3        ; Level 3.1 - Betacam (500-800 Spalten), stand in Konkurenz zu VHS, hat sich aber nicht durchgesetzt
	-soll_xmaly SVGA		# 800x600 4/3        ; Level 3.1
	-soll_xmaly QHD			# 960x540 16/9       ; Level 3.1
	-soll_xmaly HXGA		# 832x624 4/3        ; Level 3.1
	-soll_xmaly PS_Vita		# 964x544 16/9       ; Level 3.1
	-soll_xmaly iPad		# 1024x576 16/9      ; Level 3.1
	-soll_xmaly WSVGA		# 1024x600 16/9      ; Level 3.1
	-soll_xmaly DVGA		# 960x640 3/2        ; Level 3.1
	-soll_xmaly WSVGA2		# 1072x600 16/9      ; Level 3.1
	-soll_xmaly DVGA2		# 960x720 4/3        ; Level 3.1
	-soll_xmaly EVGA		# 1024x768 4/3       ; Level 3.1
	-soll_xmaly XGA			# 1024x768 4/3       ; Level 3.1
	-soll_xmaly 9CIF		# 1056x864 4/3       ; Level 3.1
	-soll_xmaly HDTV		# 1280x720 16/9      ; Level 3.1
	-soll_xmaly DSVGA		# 1200x800 3/2       ; Level 3.2
	-soll_xmaly WXGA		# 1280x768 5/3       ; Level 3.2
	-soll_xmaly XGA2		# 1152x864 4/3       ; Level 3.2
	-soll_xmaly WXGA1		# 1280x800 8/5       ; Level 3.2
	-soll_xmaly WXGA2		# 1360x768 16/9      ; Level 3.2
	-soll_xmaly WXGA3		# 1366x768 16/9      ; Level 3.2
	-soll_xmaly WXGA4		# 1376x768 16/9      ; Level 3.2
	-soll_xmaly OLPC		# 1200x900 4/3       ; Level 3.2
	-soll_xmaly SXVGA		# 1280x960 4/3       ; Level 3.2
	-soll_xmaly UWXGA		# 1600x768 2083/1000 ; Level 3.2
	-soll_xmaly WXGA+		# 1400x900 14/9      ; Level 3.2
	-soll_xmaly WXGA+2		# 1440x900 8/5       ; Level 4.0
	-soll_xmaly SXGA		# 1280x1024 5/4      ; Level 3.2
	-soll_xmaly WXGA+Apple		# 1440x960 3/2       ; Level 4.0
	-soll_xmaly WSXGA		# 1600x900 16/9      ; Level 4.0
	-soll_xmaly SXGA+		# 1400x1050 4/3      ; Level 4.0
	-soll_xmaly HDV 		# 1440x1080 4/3      ; Level 4.0
	-soll_xmaly 16CIF		# 1408x1152 4/3      ; Level 4.0 - es ist ein h263-Format
	-soll_xmaly WSXGA2		# 1600x1024 25/16    ; Level 4.0
	-soll_xmaly MPEG2H1440		# 1440x1152 4/3      ; Level 3.1 - MPEG-2-Profil: High 1440; HDTV 4:3
	-soll_xmaly WSXGA+		# 1680x1050 8/5      ; Level 4.0
	-soll_xmaly UXGA		# 1600x1200 4/3      ; Level 4.0
	-soll_xmaly HD			# 1920x1080 16/9     ; Level 4.0
	-soll_xmaly MPEG2H		# 1920x1152 16/9     ; Level 3.1 - MPEG-2-Profil: High; HDTV 16:9
	-soll_xmaly WUXGA		# 1920x1200 8/5      ; Level 5.0
	-soll_xmaly QWXGA		# 2048x1152 16/9     ; Level 5.0
	-soll_xmaly TXGA		# 1920x1400 1371     ; Level 5.0
	-soll_xmaly TXGA2		# 1920x1440 4/3      ; Level 5.0
	-soll_xmaly UW-UXGA		# 2560x1080 21/9     ; Level 5.0
	-soll_xmaly 2K			# 2048x1536 4/3      ; Level 5.0
	-soll_xmaly WQHD		# 2560x1440 16/9     ; Level 5.0
	-soll_xmaly WQXGA		# 2560x1600 8/5      ; Level 5.0
	-soll_xmaly UWQHD		# 3440x1440 21/9     ; Level 5.0
	-soll_xmaly QSXGA		# 2560x2048 5/4      ; Level 5.0
	-soll_xmaly QHD+		# 3200x1800 16/9     ; Level 5.1
	-soll_xmaly QSXGA+		# 2800x2100 4/3      ; Level 5.1
	-soll_xmaly UW4k		# 3840x1600 21/9     ; Level 5.1
	-soll_xmaly WQSXGA		# 3200x2048 25/16    ; Level 5.1
	-soll_xmaly QUXGA		# 3200x2400 4/3      ; Level 5.1
	-soll_xmaly UHD4K		# 3840x2160 16/9     ; Level 5.1
	-soll_xmaly 4K2K		# 4096x2160 19/10    ; Level 5.1
	-soll_xmaly WQUXGA		# 3840x2400 8/5      ; Level 5.1
	-soll_xmaly Retina4K		# 4096x2304 16/9     ; Level 5.1
	-soll_xmaly 4K			# 4096x3072 4/3      ; Level Das Seitenverhaeltnis wird von AVC nicht unterstuetzt!
	-soll_xmaly UHD+		# 5120x2880 16/9     ; Level Das Seitenverhaeltnis wird von AVC nicht unterstuetzt!
	-soll_xmaly WHXGA		# 5120x3200 8/5      ; Level Das Seitenverhaeltnis wird von AVC nicht unterstuetzt!
	-soll_xmaly HSXGA		# 5120x4096 5/4      ; Level Das Seitenverhaeltnis wird von AVC nicht unterstuetzt!
	-soll_xmaly WHSXGA		# 6400x4096 25/16    ; Level Das Seitenverhaeltnis wird von AVC nicht unterstuetzt!
	-soll_xmaly HUXGA		# 6400x4800 4/3      ; Level Das Seitenverhaeltnis wird von AVC nicht unterstuetzt!
	-soll_xmaly FUHD		# 7680x4320 16/9     ; Level Das Seitenverhaeltnis wird von AVC nicht unterstuetzt!
	-soll_xmaly UHXGA		# 7680x4800 8/5      ; Level Das Seitenverhaeltnis wird von AVC nicht unterstuetzt!
	-soll_xmaly QUHD		# 15360x8640 16/9    ; Level Das Seitenverhaeltnis wird von AVC nicht unterstuetzt!
"
}

#------------------------------------------------------------------------------#

ausgabe_hilfe()
{
echo "# 10
#==============================================================================#
"
grep -E -h '^[*][* ]' ${AVERZ}/Filmwandler_Format_*.txt
echo "# 20
#==============================================================================#
"
}

#------------------------------------------------------------------------------#

meta_daten_streams()
{
	KOMPLETT_DURCHSUCHEN="-probesize ${FFPROBE_PROBESIZE}M -analyzeduration ${FFPROBE_PROBESIZE}M"
	echo "# 30 meta_daten_streams: ffprobe -v error ${KOMPLETT_DURCHSUCHEN} -i \"${FILMDATEI}\" -show_streams"
	META_DATEN_STREAMS="$(ffprobe -v error ${KOMPLETT_DURCHSUCHEN} -i "${FILMDATEI}" -show_streams 2>> "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt)"
	if [ x = "x${META_DATEN_STREAMS}" ] ; then
		### Killed
		echo "# 40:
		Leider hat der erste ffprobe-Lauf nicht funktioniert,
		das deutet auf zu wenig verfügbaren RAM hin.
		Der ffprobe-Lauf wird erneut gestartet, jedoch wird
		jetzt nicht der komplette Film durchsucht.
		Das bedeutet, dass z.B. Untertitel, die erst später im Film beginnen,
		nicht gefunden und nicht berücksichtigt werden können.

		starte die Funktion: meta_daten_streams"

		FFPROBE_PROBESIZE="$(echo "${FFPROBE_PROBESIZE}" | awk '{printf "%.0f\n", $1/2 + 1}')"
		echo "# 50 META_DATEN_STREAMS: probesize ${FFPROBE_PROBESIZE}M"
		meta_daten_streams
	fi
}


BILD_DREHEN()
{
	if [ "x${IN_XY}" != x ] ; then
		IN_XY="$(echo "${IN_XY}" | awk -F'x' '{print $2"x"$1}')"
	fi

	unset ZWISCHENSPEICHER
	ZWISCHENSPEICHER="${BREITE}"
	BREITE="${HOEHE}"
	HOEHE="${ZWISCHENSPEICHER}"
	unset ZWISCHENSPEICHER

	if [ x = "x${BILD_SCALE}" ] ; then
		unset ZWISCHENSPEICHER
		ZWISCHENSPEICHER="${BILD_BREIT}"
		BILD_BREIT="${BILD_HOCH}"
		BILD_HOCH="${ZWISCHENSPEICHER}"
		unset ZWISCHENSPEICHER
	else
		BILD_BREIT="$(echo "${BILD_SCALE}" | sed 's/x/ /;s/^[^0-9][^0-9]*//;s/[^0-9][^0-9]*$//' | awk '{print $2}')"
		BILD_HOCH="$(echo "${BILD_SCALE}" | sed 's/x/ /;s/^[^0-9][^0-9]*//;s/[^0-9][^0-9]*$//' | awk '{print $1}')"
	fi
	BILD_SCALE="scale=${BILD_BREIT}x${BILD_HOCH},"

	if [ x = "x${SOLL_DAR}" ] ; then
		FORMAT_ANPASSUNG="setdar='${BREITE}/${HOEHE}',"
	fi
}


video_format()
{
	if [ x = "x${VIDEO_FORMAT}" ] ; then
		VIDEO_FORMAT=${ENDUNG}
	else
		VIDEO_FORMAT="$(echo "${VIDEO_FORMAT}" | awk '{print tolower($1)}')"
	fi
}


suche_video_encoder()
{
	ffmpeg -encoders 2>/dev/null | awk '/^ V/{print $2}' | grep -Fv '=' | grep -E "${1}" | head -n1
}


suche_audio_encoder()
{
	ffmpeg -encoders 2>/dev/null | awk '/^ A/{print $2}' | grep -Fv '=' | grep -E "${1}" | head -n1
}


#==============================================================================#

if [ x = "x${1}" ] ; then
        ${0} -h
	exit 60
fi

while [ "${#}" -ne "0" ]; do
        case "${1}" in
                -q)
                        FILMDATEI="${2}"			# Name für die Quelldatei
                        shift
                        ;;
                -z)
                        ZIELPFAD="${2}"				# Name für die Zieldatei
                        shift
                        ;;
                -titel)
                        EIGENER_TITEL="${2}"			# Titel/Name des Filmes
                        shift
                        ;;
                -k)
                        KOMMENTAR="${2}"			# Kommentar/Beschreibung des Filmes
                        shift
                        ;;
                -c|-crop)
                        CROP="${2}"				# zum entfernen der schwarzen Balken: -vf crop=width:height:x:y
                        shift
                        ;;
                -drehen)
                        BILD_DREHUNG="${2}"			# es geht nur 90 (-vf transpose=1), 270 (-vf transpose=2) und 180 (-vf hflip,vflip) Grad
                        shift
                        ;;
                -dar)
                        IST_DAR="${2}"				# Display-Format, wenn ein anderes gewünscht wird als automatisch erkannt wurde
                        shift
                        ;;
                -std_dar)
			ORIGINAL_DAR="Nein"			# das Seitenverhältnis wird automatisch entweder auf 16/9 oder 4/3 geändert
                        shift
                        ;;
                -orig_dar)
			ORIGINAL_DAR="Ja"			# das originale Seitenverhältnis soll beibehalten werden
                        shift
                        ;;
                -fps|-soll_fps)
                        SOLL_FPS="${2}"				# FPS (Bilder pro Sekunde) für den neuen Film festlegen
                        shift
                        ;;
                -par)
                        IST_PAR="${2}"				# Pixel-Format
                        shift
                        ;;
                -in_xmaly|-ist_xmaly)
                        IST_XY="${2}"				# Bildauflösung/Rasterformat der Quelle
                        shift
                        ;;
                -out_xmaly|-soll_xmaly)
                        SOLL_XY="${2}"				# Bildauflösung/Rasterformat der Ausgabe
                        shift
                        ;;
                -aq|-soll_aq)
                        TONQUALIT="${2}"			# Audio-Qualität
                        shift
                        ;;
                -vq|-soll_vq)
                        BILDQUALIT="${2}"			# Video-Qualität
                        shift
                        ;;
                -vn)
                        VIDEO_NICHT_UEBERTRAGEN="0"		# Video nicht übertragen
                        shift
                        ;;
                -vd)
			# Wenn Audio- und Video-Spur nicht synchron sind,
			# dann muss das korrigiert werden.
			#
			# Wenn "-vd" und "-ad" zusammen im selben Kommando
			# verwendet werden, dann wird das erste vom zweiten überschrieben.
			#
			# Zeit in Sekunden,
			# um wieviel das Bild später (nach dem Ton) laufen soll
			#
			# Wenn der Ton 0,2 Sekunden zu spät kommt,
			# dann kann das Bild wie folgt um 0,2 Sekunden nach hinten
			# verschoben werden:
			# -vd 0.2
                        VIDEO_SPAETER="${2}"			# Video-Delay
                        shift
                        ;;
                -ad)
			# Wenn Audio- und Video-Spur nicht synchron sind,
			# dann muss das korrigiert werden.
			#
			# Wenn "-vd" und "-ad" zusammen im selben Kommando
			# verwendet werden, dann wird das erste vom zweiten überschrieben.
			#
			# Zeit in Sekunden,
			# um wieviel der Ton später (nach dem Bild) laufen soll
			#
			# Wenn das Bild 0,2 Sekunden zu spät kommt,
			# dann kann den Ton wie folgt um 0,2 Sekunden nach hinten
			# verschoben werden:
			# -ad 0.2
                        AUDIO_SPAETER="${2}"			# Video-Delay
                        shift
                        ;;
                -standard_ton)
                        # Wird diese Option nicht verwendet,
                        # dann wird die Einstellung aus dem Originalfilm übernommen
                        # "0" für die erste Tonspur
                        # "5" für die sechste Tonspur
                        AUDIO_STANDARD_SPUR="${2}"		# -standard_ton 5
                        shift
                        ;;
                -standard_u)
                        # Wird diese Option nicht verwendet,
                        # dann wird die Einstellung aus dem Originalfilm übernommen
                        # "0" für die erste Untertitelspur
                        # "5" für die sechste Untertitelspur
                        UNTERTITEL_STANDARD_SPUR="${2}" 	# -standard_u 5
                        shift
                        ;;
                -ton)
                        # Wird diese Option nicht verwendet, dann werden ALLE Tonspuren eingebettet
                        # "0" für die erste Tonspur
                        # "1" für die zweite Tonspur
                        # "0,1" für die erste und die zweite Tonspur
                        #
                        # die gewünschten Tonspuren (in der gewünschten Reihenfolge) angeben
                        # -ton 0,1,2,3,4
                        #
                        # Sprachen nach ISO-639-2 für Tonspuren können jetzt mit angegeben werden und überschreiben die Angaben aus der Quelle.
                        # für die angegebenen Tonspuren auch noch die entsprechende Sprache mit angeben
                        # -ton 0:deu,1:eng,2:spa,3:fra,4:ita
                        #
                        TON_SPUR_SPRACHE="${2}"			# -ton 0,1,2,3,4 / -ton 0:deu,1:eng,2:spa,3:fra,4:ita
                        shift
                        ;;
		-ffprobe)
			# Dieser Wert gibt an wie weit von beginn der Filmdatei an
			# ffprobe nach Tonspuren und Untertiteln suchen soll.
			# Ist der Wert zu klein, dann werden beispielsweise keine
			# Untertitel gefunden, die erst sehr spät beginnen.
                        # Der Wert sollte so groß sein wie der zu transkodierende Film ist.
                        # Die Voreinstellung ist "9223372036854" MiB
			# Das ist der praktisch ermittelte Maximalwert von einem
			# "Intel(R) Core(TM) i5-10600T CPU @ 2.40GHz"
			# auf einem "FreeBSD 13.0"-System mit 64 GiB RAM.
			# 
			# Hat der Film nur eine Tonspur, die ganz am Anfang des Films beginnt, und keine Untertitel,
			# dann kann der Wert sehr klein gehalten werden. Zum Beispiel: 10
                        FFPROBE_PROBESIZE="${2}"		# ffprobe-Scan-Größe in MiB
                        shift
                        ;;
                -stereo)
                        STEREO="Ja"
                        #STEREO="-ac 2"				# Stereo-Ausgabe erzwingen
			# Stereo-Ausgabe erzwingen 
                        # 5.1 mischen auf algorithmus von Dave_750 
                        # hier werden die tiefbass spur (LFE) mit abgemischt
                        # das trifft bei -ac 2 nicht zu (ATSC standards)
                        # -ac 2 als filter:
                        # -af "pan=stereo|FL < 1.0*FL + 0.707*FC + 0.707*BL|FR < 1.0*FR + 0.707*FC + 0.707*BR"
                        # Quelle: https://superuser.com/questions/852400/properly-downmix-5-1-to-stereo-using-ffmpeg/1410620#1410620
                        #STEREO="-filter_complex pan='stereo|FL=0.5*FC+0.707*FL+0.707*BL+0.5*LFE|FR=0.5*FC+0.707*FR+0.707*BR+0.5*LFE',volume='1.562500'"
                        # NighMode 
                        # The Nightmode Dialogue formula, created by Robert Collier on the Doom9 forum and sourced by Shane Harrelson in his answer, 
                        # results in a far better downmix than the ac -2 switch - instead of overly quiet dialogues, it brings them back to levels that are much closer to the source.
                        #STEREO="-filter_complex pan='stereo|FL=FC+0.30*FL+0.30*BL|FR=FC+0.30*FR+0.30*BR'"
                        shift
                        ;;
                -schnitt)
			SCHNITTZEITEN="$(echo "${2}" | sed 's/,/ /g')"	# zum Beispiel zum Werbung entfernen (in Sekunden, Dezimaltrennzeichen ist der Punkt): -schnitt 10-432,520-833,1050-1280
                        shift
                        ;;
                -test|-t)
                        TEST="Ja"		# um die richtigen CROP-Parameter zu ermitteln
                        shift
                        ;;
                -u)
                        # Wird diese Option nicht verwendet, dann werden ALLE Untertitelspuren eingebettet
                        # "=0" für keinen Untertitel
                        # "0" für die erste Untertitelspur
                        # "1" für die zweite Untertitelspur
                        # "0,1" für die erste und die zweite Untertitelspur
                        #
                        # die gewünschten Untertitelspuren (in der gewünschten Reihenfolge) angeben
                        # -u 0,1,2,3,4
                        #
                        # Sprachen nach ISO-639-2 für Untertitelspuren können jetzt mit angegeben werden und überschreiben die Angaben aus der Quelle.
                        # für die angegebenen Untertitelspuren auch noch die entsprechende Sprache mit angeben
                        # -u 0:deu,1:eng,2:spa,3:fra,4:ita
                        #
                        # Es können jetzt auch externe Untertiteldateien mit eingebunden werden.
                        # -u Deutsch.srt,English.srt
                        # -u Deutsch.srt:deu,English.srt:eng
                        # -u 0:deu,1:eng,Deutsch.srt:deu,English.srt:eng,2:spa,3:fra,4:ita
                        #
                        UNTERTITEL_SPUR_SPRACHE="${2}"	# -u 0,1,2,3,4 / -u 0:deu,1:eng,2:spa,3:fra,4:ita
                        shift
                        ;;
                -g)
			echo "${BILD_FORMATNAMEN_AUFLOESUNGEN}"
                        exit 70
                        ;;
                -h)
			#ausgabe_hilfe
                        echo "HILFE:
	# Video- und Audio-Spur in ein HTML5-kompatibles Format transkodieren

	# grundsaetzlich ist der Aufbau wie folgt,
	# die Reihenfolge der Optionen ist unwichtig
	${0} [Option] -q [Filmname] -z [Neuer_Filmname.mp4]
	${0} -q [Filmname] -z [Neuer_Filmname.mp4] [Option]

	# ein Beispiel mit minimaler Anzahl an Parametern
	-q Film.avi -z Film.mp4

	# ein Beispiel, bei dem die erste Untertitelspur (Zählweise beginnt mit '0'!) übernommen wird
	-q Film.avi -u 0 -z Film.mp4
	# ein Beispiel, bei dem die zweite Untertitelspur übernommen wird
	-q Film.avi -u 1 -z Film.mp4
	# ein Beispiel, bei dem die erste und die zweite Untertitelspur übernommen werden
	-q Film.avi -u 0,1 -z Film.mp4

	# Es duerfen in den Dateinamen keine Leerzeichen, Sonderzeichen
	# oder Klammern enthalten sein!
	# Leerzeichen kann aber innerhalb von Klammer trotzdem verwenden
	-q \"Filmname mit Leerzeichen.avi\" -z Film.mp4

	# Titel/Name des Filmes
	-titel \"Titel oder Name des Filmes\"
	-titel \"Battlestar Galactica\"

	# Kommentar zum Film / Beschreibung des Filmes
	-k 'Ein Kommentar zum Film.'

	# Wenn Audio- und Video-Spur nicht synchron sind,
	# dann muss das korrigiert werden.
	#
	# Wenn \"-vd\" und \"-ad\" zusammen im selben Kommando
	# verwendet werden, dann wird das erste vom zweiten überschrieben.
	#
	# Zeit in Sekunden,
	# um wieviel das Bild später (nach dem Ton) laufen soll
	#
	# Wenn der Ton 0,2 Sekunden zu spät kommt,
	# dann kann das Bild wie folgt um 0,2 Sekunden nach hinten
	# verschoben werden:
	-vd 0.2

	# Wenn Audio- und Video-Spur nicht synchron sind,
	# dann muss das korrigiert werden.
	#
	# Wenn \"-vd\" und \"-ad\" zusammen im selben Kommando
	# verwendet werden, dann wird das erste vom zweiten überschrieben.
	#
	# Zeit in Sekunden,
	# um wieviel der Ton später (nach dem Bild) laufen soll
	#
	# Wenn das Bild 0,2 Sekunden zu spät kommt,
	# dann kann den Ton wie folgt um 0,2 Sekunden nach hinten
	# verschoben werden:
	-ad 0.2

	# wenn der Film mehrer Tonspuren besitzt
	# und nicht die erste verwendet werden soll,
	# dann wird so die 2. Tonspur angegeben (die Zaehlweise beginnt mit 0)
	-ton 1

	# so wird die 1. Tonspur angegeben (die Zaehlweise beginnt mit 0)
	-ton 0

	# so wird so die 3. und 4. Untertitelspur angegeben (die Zaehlweise beginnt mit 0)
	-u 2,3

	# so wird Untertitel komplett abgeschaltet
	-u =0

	# so wird so die 3. und 4. Untertitelspur angegeben (die Zaehlweise beginnt mit 0)
	-u 2,3

	# so wird den Untertitelspuren noch eine Sprache mit angegeben
	-u 0:deu,1:eng,2:spa,3:fra,4:ita

	# so werden noch externe Untertitel-Dateien mit angegeben
	-u 0,1,Deutsch.srt,English.srt,2,3,4

	# so wird den Untertitelspuren und -dateien noch eine Sprache mit angegeben
	-u 0:deu,1:eng,Deutsch.srt:deu,English.srt:eng,2:spa,3:fra,4:ita

	# so sieht das aus, wenn die Untertitel-Dateien in einem Unterverzeichnis (Sub) liegen
	-u 0:deu,1:eng,Sub/Deutsch.srt:deu,Sub/English.srt:eng,2:spa,3:fra,4:ita

	# Wird diese Option nicht verwendet,
	# dann wird die Einstellung aus dem Originalfilm übernommen
	# Bei \"0\" wird die erste Tonspur automatisch gestartet
	# Bei \"5\" wird die sechste Tonspur automatisch gestartet
	-standard_ton 5

	# Wird diese Option nicht verwendet,
	# dann wird die Einstellung aus dem Originalfilm übernommen
	# Bei \"0\" wird die erste Untertitelspur automatisch gestartet
	# Bei \"5\" wird die sechste Untertitelspur automatisch gestartet
	-standard_u 5

	# Stereo-Ausgabe erzwingen
	# egal wieviele Audio-Kanäle der Originalfilm hat, der neue Film wird Stereo haben
	-stereo

	# Dieser Wert gibt an wie weit von beginn der Filmdatei an
	# ffprobe nach Tonspuren und Untertiteln suchen soll.
	# Ist der Wert zu klein, dann werden beispielsweise keine
	# Untertitel gefunden, die erst sehr spät beginnen.
	# Der Wert sollte so groß sein wie der zu transkodierende Film ist.
	# Die Voreinstellung ist \"9223372036854\" MiB
	# Das ist der praktisch ermittelte Maximalwert von einem
	# \"Intel Core i5-10600T CPU @ 2.40GHz\"
	# auf einem \"FreeBSD 13.0\"-System mit 64 GiB RAM.
	# 
	# Hat der Film nur eine Tonspur, die ganz am Anfang des Films beginnt, und keine Untertitel,
	# dann kann der Wert sehr klein gehalten werden. Zum Beispiel: 50
	-ffprobe 9223372036854
	-ffprobe 100000000000
	-ffprobe 50

        # folgenden Parameter werden durch Profile begrenzt: Auflösung
        # zukünftig ggf. auch noch: Farbtiefe, Profil, Level
	#
        # HD ready
        # Damit der Film auch auf gewöhnlichen Set-Top-Boxen abgespielt werden kann
        # Mindestanvorderungen des "HD ready"-Standards umsetzen
        #  4/3: maximal 1024×768 → XGA  (EVGA)
        # 16/9: maximal 1280×720 → WXGA (HDTV)
	#
	# HTTP Live Streaming -> HLS
	# Dieses Skript berücksichtigt vom HLS-Standard nur das Bildformat (16/9) und die Bildauflösungen (416x234, 640x360, 768x432, 960x540, 1280x720, 1920x1080, 2560x1440, 3840x2160).
	#
        # Das Profil "firetv" begrenzt die Hardware-Anforderungen auf Werte, die der "FireTV Gen 2" von Amazon verarbeiten kann.
        -profil hls
        -profil fullhd
        -profil hdready
        -profil firetv

        # Es kann statt eines konkreten Profilnamens auch eine frei wählbare Auflösung angegeben werden, die bei der Ausgabe nicht überschritten werden soll.
        # zum Beispiel:
	-profil 320x240
	-profil 640x480
	-profil 800x600
	-profil 960x540
	-profil 768x576
	-profil 1024x576
	-profil 1280x720
	-profil 1920x1080

	# Bildwiederholrate für den neuen Film festlegen,
	# manche Geräte können nur eine begrenzte Zahl an Bildern pro Sekunde (FPS)
	-soll_fps 15
	-fps 20

	# wenn die Bildaufloesung des Originalfilmes nicht automatisch ermittelt
	# werden kann, dann muss sie manuell als Parameter uebergeben werden
	-ist_xmaly 480x270
	-in_xmaly 480x270

	# die gewünschte Bildauflösung des neuen Filmes (Ausgabe)
	-soll_xmaly 720x576		# deutscher Parametername
	-out_xmaly 720x480		# englischer Parametername
	-soll_xmaly 965x543		# frei wählbares Bildformat kann angegeben werden
	-soll_xmaly VCD			# Name eines Bildformates kann angegeben werden

	# mit dieser Option wird das originale Seitenverhältnis beibehalten,
	# sonst wird automatisch auf 4:3 oder 16:9 umgerechnet
	-orig_dar

	# wenn das Bildformat des Originalfilmes nicht automatisch ermittelt
	# werden kann oder falsch ermittelt wurde,
	# dann muss es manuell als Parameter uebergeben werden;
	# es wird nur einer der beiden Parameter DAR oder PAR benötigt
	-dar 4:3		# TV (Röhre)
	-dar 16:9		# TV (Flat)
	-dar 480:201		# BluRay

	# wenn die Pixelgeometrie des Originalfilmes nicht automatisch ermittelt
	# werden kann oder falsch ermittelt wurde,
	# dann muss es manuell als Parameter uebergeben werden;
	# es wird nur einer der beiden Parameter DAR oder PAR benoetigt
	-par 16:15		# PAL
	-par 9:10		# NTSC
	-par 8:9		# NTSC-DVD
	-par 64:45		# NTSC / DVD / DVB
	-par 1:1		# BluRay

	# will man eine andere Video-Qualitaet, dann sie manuell als Parameter
	# uebergeben werden
	-vq 5
	-soll_vq 5

	# will man eine andere Audio-Qualitaet, dann sie manuell als Parameter
	# uebergeben werden
	-aq 3
	-soll_aq 3

	# Video nicht übertragen
	# das Ergebnis soll keine Video-Spur enthalten
	-vn

	# Man kann aus dem Film einige Teile entfernen, zum Beispiel Werbung.
	# Angaben muessen in Sekunden erfolgen,
	# Dezimaltrennzeichen ist der Punkt.
	# Die Zeit-Angaben beschreiben die Laufzeit des Filmes,
	# so wie der CLI-Video-Player 'MPlayer' sie
	# in der untersten Zeile anzeigt.
	# Hier werden zwei Teile (432-520 und 833.5-1050) aus dem vorliegenden
	# Film entfernt bzw. drei Teile (8.5-432 und 520-833.5 und 1050-1280)
	# aus dem vorliegenden Film zu einem neuen Film zusammengesetzt.
	-schnitt 8.5-432,520-833.5,1050-1280

	# will man z.B. von einem 4/3-Film, der als 16/9-Film (720x576)
	# mit schwarzen Balken an den Seiten, diese schwarzen Balken entfernen,
	# dann könnte das zum Beispiel so gemacht werden:
	# -crop Ausschnittsbreite:Ausschnittshöhe:Abstand_von_links:Abstand_von_oben
	-crop 540:576:90:0

	# hat man mit dem SmartPhone ein Video aufgenommen, dann kann es sein,
	# dass es verdreht ist; mit dieser Option kann man das Video wieder
	# in die richtige Richtung drehen
	# es geht nur 90 (-vf transpose=1), 270 (-vf transpose=2) und 180 (-vf hflip,vflip) Grad
	-drehen 90
	-drehen 180
	-drehen 270

	mögliche Namen von Grafikauflösungen anzeigen
	=> ${0} -g
                        "
                        exit 80
                        ;;
                *)
                        if [ "$(echo "${1}" | grep -E '^-')" ] ; then
                                echo "Der Parameter '${1}' wird nicht unterstützt!"
				export STOP="Ja"
                        fi
                        shift
                        ;;
        esac
done


#==============================================================================#
### Programm

PROGRAMM="$(which ffmpeg)"
if [ x = "x${PROGRAMM}" ] ; then
	PROGRAMM="$(which avconv)"
	if [ x = "x${PROGRAMM}" ] ; then
		echo "Weder avconv noch ffmpeg konnten gefunden werden. Abbruch!"
		exit 90
	fi
fi

#==============================================================================#
### Trivialitäts-Check

if [ "Ja" = "${STOP}" ] ; then
        echo "Bitte korrigieren sie die falschen Parameter. Abbruch!"
        exit 100
fi

#------------------------------------------------------------------------------#

if [ "auto" = "${BILDQUALIT}" ] ; then
        BILDQUALIT="5"
fi

if [ "auto" = "${TONQUALIT}" ] ; then
        TONQUALIT="5"
fi

#------------------------------------------------------------------------------#

if [ ! -r "${FILMDATEI}" ] ; then
        echo "Der Film '${FILMDATEI}' konnte nicht gefunden werden. Abbruch!"
        exit 110
fi

#------------------------------------------------------------------------------#
# damit die Zieldatei mit Verzeichnis angegeben werden kann

QUELL_DATEI="$(basename "${FILMDATEI}")"
ZIELVERZ="$(dirname "${ZIELPFAD}")"
ZIELDATEI="$(basename "${ZIELPFAD}")"

#==============================================================================#
# Das Video-Format wird nach der Dateiendung ermittelt
# deshalb muss ermittelt werden, welche Dateiendung der Name der Ziel-Datei hat
#
# Wenn der Name der Quell-Datei und der Name der Ziel-Datei gleich sind,
# dann wird dem Namen der Ziel-Datei ein "Nr2" vor der Endung angehängt
#

QUELL_BASIS_NAME="$(echo "${QUELL_DATEI}" | awk '{print tolower($0)}')"
ZIEL_BASIS_NAME="$(echo "${ZIELDATEI}" | awk '{print tolower($0)}')"

### leider kommt (Stand 2021) ffmpeg mit Umlauten nicht richtig zurecht
### sie werden als Sonderzeichen identifiziert und somit gilt soein
### Dateiname als "unsicher"
#
# [concat @ 0x80664f000] Unsafe file name 'iWRoMVJd7uIg_01_Jesus_war_Vegetarier_und_die_Texte_über_die_Opfergaben_im_AT_sind_Fälschungen.mp4'
#
if [ x = "x$(echo "${ZIELDATEI}" | grep -Ei 'ä|ö|ü|ß')" ] ; then
	ZIELNAME="$(echo "${ZIELDATEI}" | awk '{sub("[.][^.]*$","");print $0}')"
	ZIEL_FILM="${ZIELNAME}"
	ENDUNG="$(echo "${ZIEL_BASIS_NAME}" | rev | sed 's/[a-zA-Z0-9\_\-\+/][a-zA-Z0-9\_\-\+/]*[.]/&"/;s/[.]".*//' | rev)"
	if [ "${ENDUNG}" != "webm" ] ; then 
		echo "Fehler: Die Endung der Zieldatei darf nur 'webm' sein."
		exit 119
	fi
else
	echo
	echo 'Der Dateiname'
	echo "'${ZIELDATEI}'"
	echo 'enthält Umlaute, damit kommt ffmpeg leider nicht immer klar!'
	exit 120
fi

#------------------------------------------------------------------------------#
### ggf das Format ändern

video_format

#------------------------------------------------------------------------------#

if [ x = "x${SOLL_FPS}" ] ; then
	unset FPS
else
	FPS="-r ${SOLL_FPS}"
fi

if [ x = "x${SOLL_FPS}" ] ; then
	SOLL_FPS_RUND="$(echo "${IN_FPS}" | awk '{printf "%.0f\n", $1}')"			# für Vergleiche, "if" erwartet einen Integerwert
else
	SOLL_FPS_RUND="$(echo "${SOLL_FPS}" | awk '{printf "%.0f\n", $1}')"			# für Vergleiche, "if" erwartet einen Integerwert
fi

if [ "${ZIEL_BASIS_NAME}" = "${VIDEO_FORMAT}" ] ; then
	echo 'Die Zieldatei muß eine Endung haben!'
	ls ${AVERZ}/Filmwandler_Format_*.txt | sed 's/.*Filmwandler_Format_//;s/[.]txt//'
	exit 130
fi

if [ "${QUELL_BASIS_NAME}" = "${ZIEL_BASIS_NAME}" ] ; then
	ZIELNAME="${ZIELNAME}_Nr2"
fi

#------------------------------------------------------------------------------#
### ab hier kann in die Log-Datei geschrieben werden

PROTOKOLLDATEI="$(echo "${ZIELNAME}.${ENDUNG}" | sed 's/[ ][ ]*/_/g;')"

echo "# 140
# $(date +'%F %T')
# ${0} ${Film2Standardformat_OPTIONEN}
#
# ZIEL_BASIS_NAME='${ZIEL_BASIS_NAME}'
# QUELL_DATEI='${QUELL_DATEI}'
# ZIELVERZ='${ZIELVERZ}'
# ZIELDATEI='${ZIELDATEI}'
#
# ZIELNAME='${ZIELNAME}'
# ZIEL_FILM='${ZIEL_FILM}'
#
# ENDUNG='${ENDUNG}'
# VIDEO_FORMAT='${VIDEO_FORMAT}'
" | tee "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt

#exit 150

#------------------------------------------------------------------------------#
### Parameter zum reparieren defekter Container

#REPARATUR_PARAMETER="-fflags +genpts"
REPARATUR_PARAMETER="-fflags +genpts+igndts"

#==============================================================================#
### maximale Anzahl an CPU-Kernen im System ermitteln

BS=$(uname -s)
if [ "FreeBSD" = "${BS}" ] ; then
	CPU_KERNE="$(sysctl -n kern.smp.cores)"
	if [ "x" = "x${CPU_KERNE}" ] ; then
		CPU_KERNE="$(sysctl -n hw.ncpu)"
	fi
elif [ "Darwin" = "${BS}" ] ; then
	CPU_KERNE="$(sysctl -n hw.physicalcpu)"
	if [ "x" = "x${CPU_KERNE}" ] ; then
		CPU_KERNE="$(sysctl -n hw.logicalcpu)"
	fi
elif [ "Linux" = "${BS}" ] ; then
	CPU_KERNE="$(lscpu -p=CORE | grep -E '^[0-9]' | sort | uniq | wc -l)"
	if [ "x" = "x${CPU_KERNE}" ] ; then
		CPU_KERNE="$(awk '/^cpu cores/{print $NF}' /proc/cpuinfo | head -n1)"
		if [ "x" = "x${CPU_KERNE}" ] ; then
			CPU_KERNE="$(sed 's/.,//' /sys/devices/system/cpu/cpu0/topology/core_cpus_list)"
			if [ "x" = "x${CPU_KERNE}" ] ; then
				CPU_KERNE="$(grep -m 1 'cpu cores' /proc/cpuinfo | sed 's/.* //')"
				if [ "x" = "x${CPU_KERNE}" ] ; then
					CPU_KERNE="$(grep -m 1 'cpu cores' /proc/cpuinfo | awk '{print $NF}')"
					if [ "x" = "x${CPU_KERNE}" ] ; then
						CPU_KERNE="$(nproc --all)"
					fi
				fi
			fi
		fi
	fi
fi

if [ "x" = "x${CPU_KERNE}" ] ; then
	echo "Es konnte nicht ermittelt werden, wieviele CPU-Kerne in diesem System stecken."
	echo "Es wird nun nur ein Kern benuzt."
	CPU_KERNE="1"
fi

echo "# 160
BS='${BS}'
CPU_KERNE='${CPU_KERNE}'
" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt

#==============================================================================#
#==============================================================================#
### Video
#
# IN-Daten (META-Daten) aus der Filmdatei lesen
#

#------------------------------------------------------------------------------#
### FFmpeg verwendet drei verschiedene Zeitangaben:
#
# http://ffmpeg-users.933282.n4.nabble.com/What-does-the-output-of-ffmpeg-mean-tbr-tbn-tbc-etc-td941538.html
# http://stackoverflow.com/questions/3199489/meaning-of-ffmpeg-output-tbc-tbn-tbr
# tbn = the time base in AVStream that has come from the container
# tbc = the time base in AVCodecContext for the codec used for a particular stream
# tbr = tbr is guessed from the video stream and is the value users want to see when they look for the video frame rate
#
#------------------------------------------------------------------------------#
### Meta-Daten auslesen

meta_daten_streams
echo "# 170 META_DATEN_STREAMS:
${META_DATEN_STREAMS}
"

if [ x = "x${META_DATEN_STREAMS}" ] ; then
	### Killed
	echo "# 180:
	Leider hat der erste ffprobe-Lauf nicht funktioniert,
	das deutet auf zu wenig verfügbaren RAM hin.
	Der ffprobe-Lauf wird erneut gestartet.

	starte die Funktion: meta_daten_streams" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt

	FFPROBE_PROBESIZE="$(du -sm "${FILMDATEI}" | awk '{print $1}')"
	meta_daten_streams
fi

echo "# 190
# FFPROBE_PROBESIZE='${FFPROBE_PROBESIZE}'M (letzter Versuch)
" | head -n 40 | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt
#exit 209

if [ x = "x${META_DATEN_STREAMS}" ] ; then
	echo "# 200: Die probesize von '${FFPROBE_PROBESIZE}M' ist weiterhin zu groß, bitte Rechner rebooten."
	exit 210
fi

echo "# 220: META_DATEN_ZEILENWEISE_STREAMS"
### es werden durch Semikolin getrennte Schlüssel ausgegeben bzw. in der Variablen gespeichert
META_DATEN_ZEILENWEISE_STREAMS="$(echo "${META_DATEN_STREAMS}" | tr -s '\r' '\n' | tr -s '\n' ';' | sed 's/;\[STREAM\]/³[STREAM]/g' | tr -s '³' '\n')"
#echo "${META_DATEN_ZEILENWEISE_STREAMS}" > /tmp/META_DATEN_ZEILENWEISE_STREAMS.txt
#exit 221

# index=1
# codec_type=audio
# TAG:language=ger
# index=2
# codec_type=audio
# TAG:language=eng
# index=3
# codec_type=subtitle
# TAG:language=eng
#
#   0 video eng 
#   1 audio ger 
#   2 audio eng 
#   3 subtitle eng 
META_DATEN_SPURSPRACHEN_01="$(echo "${META_DATEN_ZEILENWEISE_STREAMS}" | grep -E 'TAG:language=' | while read Z ; do echo "${Z}" | tr -s ';' '\n' | awk -F'=' '/^index=|^codec_type=|^TAG:language=/{print $2}' | tr -s '\n' ' ' ; echo ; done)"
META_DATEN_SPURSPRACHEN="$(echo "${META_DATEN_ZEILENWEISE_STREAMS}" | grep -F 'codec_type=' | nl | while read ZNR M_DATEN
do
	SP_DATEN="$(echo "${M_DATEN}" | grep -E 'TAG:language=' | tr -s ';' '\n' | awk -F'=' '/^index=|^codec_type=|^TAG:language=/{print $2}' | tr -s '\n' ' ')"
	if [ x = "x${SP_DATEN}" ] ; then
		SP_DATEN="$( (echo "${M_DATEN}" | tr -s ';' '\n' | awk -F'=' '/^index=|^codec_type=/{print $2}'; echo "und") | tr -s '\n' ' ')"
	fi
	echo "${SP_DATEN}"
done)"

# https://techbeasts.com/fmpeg-commands/
# Video um 90° drehen: ffmpeg -i input.mp4 -filter:v 'transpose=1' ouput.mp4
# Video 2 mal um 90° drehen: ffmpeg -i input.mp4 -filter:v 'transpose=2' ouput.mp4
# Video um 180° drehen: ffmpeg -i input.mp4 -filter:v 'transpose=2,transpose=2' ouput.mp4
#   http://www.borniert.com/2016/03/rasch-mal-ein-video-drehen/
#   ffmpeg -i in.mp4 -c copy -metadata:s:v:0 rotate=90 out.mp4
#  https://stackoverflow.com/questions/3937387/rotating-videos-with-ffmpeg
#  ffmpeg -vfilters "rotate=90" -i input.mp4 output.mp4
# https://stackoverflow.com/questions/3937387/rotating-videos-with-ffmpeg
# 0 = 90CounterCLockwise and Vertical Flip (default)
# 1 = 90Clockwise
# 2 = 90CounterClockwise
# 3 = 90Clockwise and Vertical Flip
# 180 Grad: -vf "transpose=2,transpose=2"
if [ x = "x${BILD_DREHUNG}" ] ; then
	BILD_DREHUNG="$(echo "${META_DATEN_STREAMS}" | sed -ne '/index=0/,/index=1/p' | awk -F'=' '/TAG:rotate=/{print $NF}' | head -n1)"	# TAG:rotate=180 -=> 180
fi

# TAG:rotate=180
# TAG:creation_time=2015-02-16T13:25:51.000000Z
# TAG:language=eng
# TAG:handler_name=VideoHandle
# [SIDE_DATA]
# side_data_type=Display Matrix
# displaymatrix=
# 00000000:       -65536           0           0
# 00000001:            0      -65536           0
# 00000002:            0           0  1073741824
#
# rotation=-180
# [/SIDE_DATA]
# [/STREAM]
# ffprobe -v error -i 20150216_142433.mp4 -show_streams | sed -ne '/index=0/,/index=1/p' | grep -F -i rotat
# TAG:rotate=180
# rotation=-180

echo "# 230
# META_DATEN_SPURSPRACHEN='${META_DATEN_SPURSPRACHEN}'
# BILD_DREHUNG='${BILD_DREHUNG}'
" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt

#exit 240

#------------------------------------------------------------------------------#

#FFPROBE_SHOW_DATA="$(ffprobe -v error ${KOMPLETT_DURCHSUCHEN} -i "${FILMDATEI}" -show_data 2>&1)"
ORIGINAL_TITEL="$(ffprobe -v error ${KOMPLETT_DURCHSUCHEN} -i "${FILMDATEI}" -show_entries format_tags=title -of compact=p=0:nk=1)"

METADATEN_TITEL="-metadata title="
if [ x = "x${EIGENER_TITEL}" ] ; then
	echo "# 250: EIGENER_TITEL"
	#EIGENER_TITEL="$(echo "${FFPROBE_SHOW_DATA}" | grep -E 'title[ ]*: ' | sed 's/[ ]*title[ ]*: //' | head -n1)"
	EIGENER_TITEL="${ORIGINAL_TITEL}"

	if [ x = "x${EIGENER_TITEL}" ] ; then
		echo "# 260:"
		EIGENER_TITEL="${ZIELNAME}"
	fi
fi

METADATEN_BESCHREIBUNG="-metadata description="
if [ x = "x${KOMMENTAR}" ] ; then
	echo "# 270: KOMMENTAR"
	COMMENT_DESCRIPTION="$(ffprobe -v error ${KOMPLETT_DURCHSUCHEN} -i "${FILMDATEI}" -show_entries format_tags=comment -of compact=p=0:nk=1) $(ffprobe -v error ${KOMPLETT_DURCHSUCHEN} -i "${FILMDATEI}" -show_entries format_tags=description -of compact=p=0:nk=1)"
	KOMMENTAR="$(echo "${COMMENT_DESCRIPTION}" | sed 's/^[ \t]*//')"

	if [ x = "x${KOMMENTAR}" ] ; then
		echo "# 280: github.com"
		METADATEN_BESCHREIBUNG="-metadata description='https://github.com/FlatheadV8/Filmwandler:${VERSION_METADATEN}'"
	fi
fi

echo "# 290
ORIGINAL_TITEL='${ORIGINAL_TITEL}'
METADATEN_TITEL='${METADATEN_TITEL}'
EIGENER_TITEL='${EIGENER_TITEL}'

METADATEN_BESCHREIBUNG=${METADATEN_BESCHREIBUNG}
KOMMENTAR='${KOMMENTAR}'

AUDIO_STANDARD_SPUR='${AUDIO_STANDARD_SPUR}'
" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt

STARTZEITPUNKT="$(date +'%s')"

#--- VIDEO_SPUR ---------------------------------------------------------------#
#------------------------------------------------------------------------------#

VIDEO_SPUR="$(echo "${META_DATEN_STREAMS}" | grep -F 'codec_type=video' | head -n1)"
if [ "${VIDEO_SPUR}" != "codec_type=video" ] ; then
	VIDEO_NICHT_UEBERTRAGEN=0
fi

echo "# 300
# VIDEO_SPUR='${VIDEO_SPUR}'
# VIDEO_NICHT_UEBERTRAGEN='${VIDEO_NICHT_UEBERTRAGEN}'
" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt

#exit 310

#------------------------------------------------------------------------------#
### hier wird eine Liste externer verfügbarer Codecs erstellt

FFMPEG_LIB="$( (ffmpeg -formats >/dev/null) 2>&1 | tr -s ' ' '\n' | grep -E '^[-][-]enable[-]' | sed 's/^[-]*enable[-]*//;s/[-]/_/g' | grep -E '^lib')"
FFMPEG_FORMATS="$(ffmpeg -formats 2>/dev/null | awk '/^[ \t]*[ ][DE]+[ ]/{print $2}')"

#------------------------------------------------------------------------------#
### alternative Methode zur Ermittlung der FPS

FPS_TEILE="$(echo "${META_DATEN_STREAMS}" | grep -E '^codec_type=|^r_frame_rate=' | grep -E -A1 '^codec_type=video' | awk -F'=' '/^r_frame_rate=/{print $2}' | sed 's|/| |')"
TEIL_ZWEI="$(echo "${FPS_TEILE}" | awk '{print $2}')"
if [ x = "x${TEIL_ZWEI}" ] ; then
	R_FPS="$(echo "${FPS_TEILE}" | awk '{print $1}')"
else
	R_FPS="$(echo "${FPS_TEILE}" | awk '{print $1/$2}')"
fi

#------------------------------------------------------------------------------#
### hier wird ermittelt, ob der film progressiv oder im Zeilensprungverfahren vorliegt

# tbn (FPS vom Container)            = the time base in AVStream that has come from the container
# tbc (FPS vom Codec)                = the time base in AVCodecContext for the codec used for a particular stream
# tbr (FPS vom Video-Stream geraten) = tbr is guessed from the video stream and is the value users want to see when they look for the video frame rate

### "field_order" gibt bei "interlaced" an in welcher Richtung (von oben nach unten oder von links nach rechts)
### "field_order" gibt nicht an, ob ein Film "progressive" ist
SCAN_TYPE="$(echo "${META_DATEN_STREAMS}" | awk -F'=' '/^field_order=/{print $2}' | grep -Ev '^$' | head -n1)"

echo "# 320
SCAN_TYPE='${SCAN_TYPE}'
" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt

if [ "${SCAN_TYPE}" != "progressive" ] ; then
    if [ "${SCAN_TYPE}" != "unknown" ] ; then
        ### wenn der Film im Zeilensprungverfahren vorliegt
        #ZEILENSPRUNG="yadif,"
	#
	# https://ffmpeg.org/ffmpeg-filters.html#yadif-1
	# https://ffmpeg.org/ffmpeg-filters.html#mcdeint
        #ZEILENSPRUNG="yadif=3:1,mcdeint=2:1,"
        #ZEILENSPRUNG="yadif=1/3,mcdeint=mode=extra_slow,"
        ZEILENSPRUNG="yadif=1:-1:0,"
    fi
fi

# META_DATEN_STREAMS=" width=720 "
# META_DATEN_STREAMS=" height=576 "
IN_BREIT="$(echo "${META_DATEN_STREAMS}" | sed -ne '/video/,/STREAM/ p' | awk -F'=' '/^width=/{print $2}' | grep -Fv 'N/A' | head -n1)"
IN_HOCH="$(echo "${META_DATEN_STREAMS}" | sed -ne '/video/,/STREAM/ p' | awk -F'=' '/^height=/{print $2}' | grep -Fv 'N/A' | head -n1)"
IN_XY="${IN_BREIT}x${IN_HOCH}"
O_BREIT="${IN_BREIT}"
O_HOCH="${IN_HOCH}"

echo "# 330
# 1 IN_XY='${IN_XY}'
# 1 IN_BREIT='${IN_BREIT}'
# 1 IN_HOCH='${IN_HOCH}'
# 1 O_BREIT='${O_BREIT}'
# 1 O_HOCH='${O_HOCH}'
" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt

#exit 340

if [ x = "x${IN_XY}" ] ; then
	# META_DATEN_STREAMS=" coded_width=0 "
	# META_DATEN_STREAMS=" coded_height=0 "
	IN_BREIT="$(echo "${META_DATEN_ZEILENWEISE_STREAMS}" | grep -F ';codec_type=video;' | tr -s ';' '\n' | awk -F'=' '/^coded_width=/{print $2}' | grep -Fv 'N/A' | grep -Ev '^0$' | head -n1)"
	IN_HOCH="$(echo "${META_DATEN_ZEILENWEISE_STREAMS}" | grep -F ';codec_type=video;' | tr -s ';' '\n' | awk -F'=' '/^coded_height=/{print $2}' | grep -Fv 'N/A' | grep -Ev '^0$' | head -n1)"
	IN_XY="${IN_BREIT}x${IN_HOCH}"
	echo "# 350
	2 IN_XY='${IN_XY}'
	2 IN_BREIT='${IN_BREIT}'
	2 IN_HOCH='${IN_HOCH}'
	" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt

	# http://www.borniert.com/2016/03/rasch-mal-ein-video-drehen/
	# ffmpeg -i in.mp4 -c copy -metadata:s:v:0 rotate=90 out.mp4
	if [ "x${BILD_DREHUNG}" != x ] ; then
		if [ "90" = "${BILD_DREHUNG}" ] ; then
			IN_XY="$(echo "${IN_XY}" | awk -F'x' '{print $2"x"$1}')"
		elif [ "270" = "${BILD_DREHUNG}" ] ; then
			IN_XY="$(echo "${IN_XY}" | awk -F'x' '{print $2"x"$1}')"
		fi
	fi
	IN_BREIT="$(echo "${IN_XY}" | awk -F'x' '{print $1}')"
	IN_HOCH="$(echo  "${IN_XY}" | awk -F'x' '{print $2}')"
fi

#------------------------------------------------------------------------------#

IN_PAR="$(echo "${META_DATEN_STREAMS}" | sed -ne '/video/,/STREAM/ p' | awk -F'=' '/^sample_aspect_ratio=/{print $2}' | grep -Fv 'N/A' | head -n1)"
echo "# 360
1 IN_PAR='${IN_PAR}'
" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt
if [ x = "x${IN_PAR}" ] ; then
	IN_PAR="$(echo "${META_DATEN_ZEILENWEISE_STREAMS}" | grep -F ';codec_type=video;' | tr -s ';' '\n' | awk -F'=' '/^sample_aspect_ratio=/{print $2}' | grep -Fv 'N/A' | grep -Ev '^0$' | head -n1)"
	echo "# 370
	2 IN_PAR='${IN_PAR}'
	" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt
fi

if [ x = "x${IN_PAR}" ] ; then
	IN_PAR="1:1"
	echo "# 380
	3 IN_PAR='${IN_PAR}'
	" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt
fi

#------------------------------------------------------------------------------#

IN_DAR="$(echo "${META_DATEN_ZEILENWEISE_STREAMS}" | grep -F ';codec_type=video;' | tr -s ';' '\n' | awk -F'=' '/^display_aspect_ratio=/{print $2}' | grep -Fv 'N/A' | head -n1)"
echo "# 390
1 IN_DAR='${IN_DAR}'
" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt
if [ x = "x${IN_DAR}" ] ; then
	IN_DAR="$(echo "${META_DATEN_ZEILENWEISE_STREAMS}" | grep -F ';codec_type=video;' | tr -s ';' '\n' | awk -F'=' '/^display_aspect_ratio=/{print $2}' | grep -Fv 'N/A' | grep -Ev '^0$' | head -n1)"
	echo "# 400
	2 IN_DAR='${IN_DAR}'
	" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt
fi

if [ x = "x${IN_DAR}" ] ; then
	IN_DAR="$(echo "${IN_XY} ${IN_PAR}" | awk '{gsub("[:/x]"," "); print ($1*$3)/($2*$4)}' | head -n1)"
	echo "# 410
	3 IN_DAR='${IN_DAR}'
	" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt
fi

#------------------------------------------------------------------------------#

# META_DATEN_STREAMS=" r_frame_rate=25/1 "
# META_DATEN_STREAMS=" avg_frame_rate=25/1 "
# META_DATEN_STREAMS=" codec_time_base=1/25 "
FPS_TEILE="$(echo "${META_DATEN_STREAMS}" | sed -ne '/video/,/STREAM/ p' | awk -F'=' '/^r_frame_rate=/{print $2}' | grep -Fv 'N/A' | head -n1 | awk -F'/' '{print $1,$2}')"
TEIL_ZWEI="$(echo "${FPS_TEILE}" | awk '{print $2}')"
if [ x = "x${TEIL_ZWEI}" ] ; then
	IN_FPS="$(echo "${FPS_TEILE}" | awk '{print $1}')"
else
	IN_FPS="$(echo "${FPS_TEILE}" | awk '{print $1/$2}')"
fi
echo "# 420
1 IN_FPS='${IN_FPS}'
" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt

if [ x = "x${IN_FPS}" ] ; then
	IN_FPS="$(echo "${META_DATEN_STREAMS}" | sed -ne '/video/,/STREAM/ p' | awk -F'=' '/^avg_frame_rate=/{print $2}' | grep -Fv 'N/A' | head -n1 | awk -F'/' '{print $1}')"
	echo "# 430
	2 IN_FPS='${IN_FPS}'
	" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt
	if [ x = "x${IN_FPS}" ] ; then
		IN_FPS="$(echo "${META_DATEN_STREAMS}" | sed -ne '/video/,/STREAM/ p' | awk -F'=' '/^codec_time_base=/{print $2}' | grep -Fv 'N/A' | head -n1 | awk -F'/' '{print $2}')"
		echo "# 440
		3 IN_FPS='${IN_FPS}'
		" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt
	fi
fi

### Dieser Wert wird für AVI und MPG benötigt
IN_FPS_RUND="$(echo "${IN_FPS}" | awk '{printf "%.0f\n", $1}')"			# für Vergleiche, "if" erwartet einen Integerwert

IN_BIT_RATE="$(echo "${META_DATEN_STREAMS}" | sed -ne '/video/,/STREAM/ p' | awk -F'=' '/^bit_rate=/{print $2}' | grep -Fv 'N/A' | head -n1)"
echo "# 450
1 IN_BIT_RATE='${IN_BIT_RATE}'
" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt
if [ x = "x${IN_BIT_RATE}" ] ; then
	IN_BIT_RATE="$(echo "${META_DATEN_ZEILENWEISE_STREAMS}" | grep -F ';codec_type=video;' | tr -s ';' '\n' | awk -F'=' '/^bit_rate=/{print $2}' | grep -Fv 'N/A' | grep -Ev '^0$' | head -n1)"
	echo "# 460
	2 IN_BIT_RATE='${IN_BIT_RATE}'
	" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt
fi

IN_BIT_EINH="$(echo "${IN_BIT_RATE}" | awk '{print $2}')"
case "${IN_BIT_EINH}" in
        [Kk]b[p/]s|[Kk]b[/]s)
                        IN_BITRATE_KB="$(echo "${IN_BIT_RATE}" | awk '{print $1}')"
                        ;;
        [Mm]b[p/]s|[Mm]b[/]s)
                        IN_BITRATE_KB="$(echo "${IN_BIT_RATE}" | awk '{print $1 * 1024}')"
                        ;;
esac

echo "# 470
# IN_XY='${IN_XY}'
# BILD_DREHUNG='${BILD_DREHUNG}'
# IN_BREIT='${IN_BREIT}'
# IN_HOCH='${IN_HOCH}'
# IN_PAR='${IN_PAR}'
# IN_DAR='${IN_DAR}'
# IN_FPS='${IN_FPS}'
# IN_FPS_RUND='${IN_FPS_RUND}'
# IN_BIT_RATE='${IN_BIT_RATE}'
# IN_BIT_EINH='${IN_BIT_EINH}'
# IN_BITRATE_KB='${IN_BITRATE_KB}'
# BILDQUALIT='${BILDQUALIT}'
# TONQUALIT='${TONQUALIT}'
" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt

unset IN_BIT_RATE
unset IN_BIT_EINH

#exit 480

if [ x = "x${IN_DAR}" ] ; then
	echo "# 490
	Fehler!
	IN_DAR='${IN_DAR}'
	" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt
	exit 500
fi

INDAR="$(echo "${IN_DAR}" | grep -E '[0-9][:][0-9]' | head -n1)"
echo "# 510
IN_DAR='${IN_DAR}'
INDAR='${INDAR}'
" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt

if [ x = "x${INDAR}" ] ; then
	IN_DAR="${IN_DAR}:1"
	echo "# 520
	IN_DAR='${IN_DAR}'
	" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt
fi

echo "# 530
# ORIGINAL_DAR='${ORIGINAL_DAR}'
# IN_DAR='${IN_DAR}'
" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt

#exit 540

#==============================================================================#
#==============================================================================#
### Video

### diese Informationen müssen bereits jetzt abrufbar sein
### und können nicht erst unten bei der Untertitelverarbeitung ausgelesen werden
UT_VORHANDEN="$(echo "${META_DATEN_ZEILENWEISE_STREAMS}" | grep -F codec_type=subtitle)"
IST_UT_FORMAT="$(echo "${UT_VORHANDEN}" | tr -s ';' '\n' | awk -F'=' '/^codec_name=/{print $2}')"

echo "# 545
# UT_VORHANDEN='${UT_VORHANDEN}'
# IST_UT_FORMAT='${IST_UT_FORMAT}'
" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt

#------------------------------------------------------------------------------#
### Seitenverhältnis des Bildes (DAR) muss hier bekannt sein!

#------------------------------------------------------------------------------#

echo "# 10 Video
" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt

#==============================================================================#
### Korrektur: gelesene IN-Daten mit übergebenen IST-Daten überschreiben
###
### Es wird unbedingt das Rasterformat der Bildgröße (Breite x Höhe) benötigt!
###
### Weiterhin wird das Seitenverhältnis des Bildes (DAR) benötigt,
### dieser Wert kann aber auch aus dem Seitenverhältnis der Bildpunkte (PAR/SAR)
### errechnet werden.
###
### Sollte die Bildgröße bzw. DAR+PAR/SAR fehlen, bricht die Bearbeitung ab!
###
### zum Beispiel:
###	IN_XY  = 720 x 576 (Rasterformat der Bildgröße)
###	IN_PAR =  15 / 16  (PAR / SAR)
###	IN_DAR =   4 / 3   (DAR)
###
#------------------------------------------------------------------------------#
### Hier wird versucht dort zu interpolieren, wo es erforderlich ist.
### Es kann jedoch von den vier Werten (Breite+Höhe+DAR+PAR) nur einer
### mit Hilfe der drei vorhandenen Werte interpoliert werden.

#------------------------------------------------------------------------------#
### Rasterformat der Bildgröße

if [ -n "${IST_XY}" ] ; then
	IN_XY="${IST_XY}"
fi


if [ -z "${IN_XY}" ] ; then
	echo "# 20 Video"
	echo "Es konnte die Video-Auflösung nicht ermittelt werden."
	echo "versuchen Sie es mit diesem Parameter nocheinmal:"
	echo "-in_xmaly"
	echo "z.B. (PAL)     : -in_xmaly 720x576"
	echo "z.B. (NTSC)    : -in_xmaly 720x486"
	echo "z.B. (NTSC-DVD): -in_xmaly 720x480"
	echo "z.B. (iPad)    : -in_xmaly 1024x576"
	echo "z.B. (HDTV)    : -in_xmaly 1280x720"
	echo "z.B. (HD)      : -in_xmaly 1920x1080"
	echo "ABBRUCH!"
	exit 30
fi

echo "# 40 Video
# IN_XY='${IN_XY}'
# IN_BREIT='${IN_BREIT}'
# IN_HOCH='${IN_HOCH}'
# O_BREIT='${O_BREIT}'
# O_HOCH='${O_HOCH}'

# IST_XY='${IST_XY}'
# IN_DAR='${IN_DAR}'
# IN_PAR='${IST_PAR}'
# IST_DAR='${IST_DAR}'
# IST_PAR='${IST_PAR}'
" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt

#exit 50

#------------------------------------------------------------------------------#
### Seitenverhältnis des Bildes (DAR)

if [ x != "x${IST_DAR}" ] ; then
	IN_DAR="${IST_DAR}"
fi

#----------------------------------------------------------------------#
### Seitenverhältnis der Bildpunkte (PAR / SAR)

if [ x != "x${IST_PAR}" ] ; then
	IN_PAR="${IST_PAR}"
fi

#----------------------------------------------------------------------#
### Seitenverhältnis der Bildpunkte - Arbeitswerte berechnen (PAR / SAR)

ARBEITSWERTE_PAR()
{
if [ x != "x${IN_PAR}" ] ; then
	PAR="$(echo "${IN_PAR}" | grep -E '[:/]')"
	if [ x != "x${PAR}" ] ; then
		PAR_KOMMA="$(echo "${PAR}" | grep -E '[:/]' | awk '{gsub("[:/]"," ");print $1/$2}')"
		PAR_FAKTOR="$(echo "${PAR}" | grep -E '[:/]' | awk '{gsub("[:/]"," ");printf "%u\n", ($1*100000)/$2}')"
	else
		PAR="$(echo "${IN_PAR}" | grep -F '.')"
		PAR_KOMMA="${PAR}"
		PAR_FAKTOR="$(echo "${PAR}" | grep -F '.' | awk '{printf "%u\n", $1*100000}')"
	fi
fi
}

ARBEITSWERTE_PAR

echo "# 60 Video
# IN_BREIT='${IN_BREIT}'
# IN_HOCH='${IN_HOCH}'
# IN_XY='${IN_XY}'
# IN_DAR='${IN_DAR}'
# IN_PAR='${IST_PAR}'
# IST_DAR='${IST_DAR}'
# IST_PAR='${IST_PAR}'
# PAR='${PAR}'
# PAR_KOMMA='${PAR_KOMMA}'
# PAR_FAKTOR='${PAR_FAKTOR}'
# VIDEO_SPUR='${VIDEO_SPUR}'
# VIDEO_NICHT_UEBERTRAGEN='${VIDEO_NICHT_UEBERTRAGEN}'
" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt

#exit 70

#----------------------------------------------------------------------#
### Kontrolle Seitenverhältnis des Bildes (DAR)

if [ x = "x${IN_DAR}" -o x != "x${IST_PAR}" ] ; then
	IN_DAR="$(echo "${IN_BREIT} ${IN_HOCH} ${PAR_KOMMA}" | awk '{printf("%.16f\n",($1*$3)/$2)}')"

	echo "# 80 Video
	IN_BREIT='${IN_BREIT}'
	IN_HOCH='${IN_HOCH}'
	IN_DAR='${IN_DAR}'
	" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt
fi

INDAR="$(echo "${IN_DAR}" | grep -E '[:/]')"
if [ x = "x${INDAR}" ] ; then
	IN_DAR="${IN_DAR}/1"
fi

if [ x != "x${IST_PAR}" ] ; then
	IST_DAR="${IN_DAR}"
fi

O_DAR="${IN_DAR}"
ODAR="$(echo "${O_DAR}" | grep -E '[:/]')"
if [ -n "${ODAR}" ] ; then
	O_DAR_1="$(echo "${O_DAR}" | grep -E '[:/]' | awk '{gsub("[:/]"," ");print $1}')"
	O_DAR_2="$(echo "${O_DAR}" | grep -E '[:/]' | awk '{gsub("[:/]"," ");print $2}')"
else
	O_DAR_1="${O_DAR}"
	O_DAR_2="1"
fi

echo "# 90 Video
O_BREIT=${O_BREIT}
O_HOCH=${O_HOCH}
O_DAR=${O_DAR}
" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt

#exit 91

if [ "${VIDEO_NICHT_UEBERTRAGEN}" != "0" ] ; then
    echo "# 100 Video" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt
    if [ -z "${IN_DAR}" ] ; then
	echo "# 110 Video" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt
	echo "Es konnte das Seitenverhältnis des Bildes nicht ermittelt werden."
	echo "versuchen Sie es mit einem dieser beiden Parameter nocheinmal:"
	echo "-in_dar"
	echo "z.B. (Röhre)   : -in_dar 4:3"
	echo "z.B. (Flat)    : -in_dar 16:9"
	echo "z.B. (BluRay)  : -in_dar 480:201"
	echo "-in_par"
	echo "z.B. (PAL)     : -in_par 16:15"
	echo "z.B. (NTSC)    : -in_par  9:10"
	echo "z.B. (NTSC-DVD): -in_par  8:9"
	echo "z.B. (DVB/DVD) : -in_par 64:45"
	echo "z.B. (BluRay)  : -in_par  1:1"
	echo "ABBRUCH!"
	exit 120
    fi
fi

#----------------------------------------------------------------------#
### Seitenverhältnis des Bildes - Arbeitswerte berechnen (DAR)

DAR="$(echo "${IN_DAR}" | grep -E '[:/]')"
if [ x = "x${DAR}" ] ; then
	echo "# 130 Video" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt
	DAR="$(echo "${IN_DAR}" | grep -F '.')"
	DAR_KOMMA="${DAR}"
	DAR_FAKTOR="$(echo "${DAR}" | grep -F '.' | awk '{printf "%u\n", $1*100000}')"
else
	echo "# 140 Video" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt
	DAR_KOMMA="$(echo "${DAR}" | grep -E '[:/]' | awk '{gsub("[:/]"," ");print $1/$2}')"
	DAR_FAKTOR="$(echo "${DAR}" | grep -E '[:/]' | awk '{gsub("[:/]"," ");printf "%u\n", ($1*100000)/$2}')"
fi


#----------------------------------------------------------------------#
### Kontrolle Seitenverhältnis der Bildpunkte (PAR / SAR)

if [ x = "x${IN_PAR}" ] ; then
	echo "# 150 Video" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt
	IN_PAR="$(echo "${IN_BREIT} ${IN_HOCH} ${DAR_KOMMA}" | awk '{printf "%.16f\n", ($2*$3)/$1}')"
fi


ARBEITSWERTE_PAR

#==============================================================================#
### Bildausschnitt

### CROPing
#
# oben und unten die schwarzen Balken entfernen
# crop=720:432:0:72
#
# von den Seiten die schwarzen Balken entfernen
# crop=540:576:90:0
#
if [ x = "x${CROP}" ] ; then
	echo "# 160 Video" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt
	IN_BREIT="$(echo "${IN_XY}" | awk -F'x' '{print $1}')"
	IN_HOCH="$(echo  "${IN_XY}" | awk -F'x' '{print $2}')"
else
	#set -x
	### CROP-Seiten-Format
	echo "# 170 Video" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt
	# -vf crop=width:height:x:y
	# -vf crop=in_w-100:in_h-100:100:100
	IN_BREIT="$(echo "${CROP}" | awk '{gsub("[:/]"," ");print $1}')"
	IN_HOCH="$(echo "${CROP}" | awk '{gsub("[:/]"," ");print $2}')"
	#X="$(echo "${CROP}" | awk '{gsub("[:/]"," ");print $3}')"
	#Y="$(echo "${CROP}" | awk '{gsub("[:/]"," ");print $4}')"

	### Display-Seiten-Format
	DAR_FAKTOR="$(echo "${PAR_FAKTOR} ${IN_BREIT} ${IN_HOCH}" | awk '{printf "%u\n", ($1*$2)/$3}')"
	DAR_KOMMA="$(echo "${DAR_FAKTOR}" | awk '{print $1/100000}')"
	IN_DAR="$(echo "${O_BREIT} ${O_HOCH} ${O_DAR_1} ${O_DAR_2} ${IN_BREIT} ${IN_HOCH}" | awk '{gsub("[:/]"," ");print $2 * $3 * $5 / $1 / $4 / $6}'):1"

	CROP="crop=${CROP},"
fi

echo "# 180 Video
O_BREIT='${O_BREIT}'
O_HOCH='${O_HOCH}'
O_DAR='${O_DAR}'
IN_DAR='${IN_DAR}'
PAR_FAKTOR='${PAR_FAKTOR}'
IN_BREIT='${IN_BREIT}'
IN_HOCH='${IN_HOCH}'
DAR_FAKTOR='${DAR_FAKTOR}'
DAR_KOMMA='${DAR_KOMMA}'
CROP='${CROP}'
" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt

#exit 190

#------------------------------------------------------------------------------#

if [ -z "${DAR_FAKTOR}" ] ; then
	echo "# 200 Video" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt
	echo "Es konnte das Display-Format nicht ermittelt werden."
	echo "versuchen Sie es mit diesem Parameter nocheinmal:"
	echo "-dar"
	echo "z.B.: -dar 16:9"
	echo "ABBRUCH!"
	exit 210
fi

#------------------------------------------------------------------------------#
#------------------------------------------------------------------------------#
### quadratische Bildpunkte sind der Standard

# https://ffmpeg.org/ffmpeg-filters.html#setdar_002c-setsar
FORMAT_ANPASSUNG="setsar='1/1',"

#------------------------------------------------------------------------------#

#------------------------------------------------------------------------------#
### Wenn die Bildpunkte vom Quell-Film und vom Ziel-Film quadratisch sind,
### dann ist es ganz einfach.
### Aber wenn nicht, dann sind diese Berechnungen nötig.

echo "# 219 Video" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt
if [ "x${ORIGINAL_DAR}" = "xNein" ] ; then
	echo "# 220 Video" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt
	if [ "x${SOLL_DAR}" != "x" ] ; then
		echo "# 230 Video" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt
		# hier sind Modifikationen nötig, weil viele der auswählbaren Bildformate
		# keine quadratischen Pixel vorsehen
		INBREITE_DAR="$(echo "${IN_DAR}" | awk '{gsub("[:/]"," ");print $1}')"
		INHOEHE_DAR="$(echo "${IN_DAR}" | awk '{gsub("[:/]"," ");print $2}')"
		echo "# 240 Video
		# SOLL_DAR='${SOLL_DAR}'
		# INBREITE_DAR='${INBREITE_DAR}'
		# INHOEHE_DAR='${INHOEHE_DAR}'
		# BILD_BREIT='${BILD_BREIT}'
		# BILD_HOCH='${BILD_HOCH}'
		" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt
		PIXELVERZERRUNG="$(echo "${SOLL_DAR} ${INBREITE_DAR} ${INHOEHE_DAR} ${BILD_BREIT} ${BILD_HOCH}" | awk '{gsub("[:/]"," ") ; pfmt=$1*$6/$2/$5 ; AUSGABE=1 ; if (pfmt < 1) AUSGABE=0 ; if (pfmt > 1) AUSGABE=2 ; print AUSGABE}')"
		#
		unset PIXELKORREKTUR

		if [ x = "x${PIXELVERZERRUNG}" ] ; then
			echo "# 250 Video
			# PIXELVERZERRUNG='${PIXELVERZERRUNG}'
			" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt
			exit 260
		elif [ "${PIXELVERZERRUNG}" -eq 1 ] ; then
			BREITE="$(echo "${SOLL_DAR}" | awk '{gsub("[:/]"," ");print $1}')"
			HOEHE="$(echo "${SOLL_DAR}" | awk '{gsub("[:/]"," ");print $2}')"
			echo "# 270 Video
			# quadratische Pixel
			# PIXELVERZERRUNG = 1 : ${PIXELVERZERRUNG}
			# BREITE='${BREITE}'
			# HOEHE='${HOEHE}'
			" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt
			#
			unset PIXELKORREKTUR
		elif [ "${PIXELVERZERRUNG}" -le 1 ] ; then
			BREITE="$(echo "${SOLL_DAR} ${INBREITE_DAR} ${INHOEHE_DAR} ${BILD_BREIT} ${BILD_HOCH}" | awk '{gsub("[:/]"," ");print $2 * $2 * $5 / $1 / $6}')"
			HOEHE="$(echo "${SOLL_DAR}" | awk '{gsub("[:/]"," ");print $2}')"
			echo "# 280 Video
			# lange Pixel: breit ziehen
			# 4CIF (Test 2)
			# PIXELVERZERRUNG < 1 : ${PIXELVERZERRUNG}
			# BREITE='${BREITE}'
			# HOEHE='${HOEHE}'
			" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt
			#
			PIXELKORREKTUR="scale=${BILD_BREIT}x${BILD_HOCH},"
		elif [ "${PIXELVERZERRUNG}" -ge 1 ] ; then
			BREITE="$(echo "${SOLL_DAR}" | awk '{gsub("[:/]"," ");print $1}')"
			HOEHE="$(echo "${SOLL_DAR} ${INBREITE_DAR} ${INHOEHE_DAR} ${BILD_BREIT} ${BILD_HOCH}" | awk '{gsub("[:/]"," ");print $1 * $1 * $6 / $2 / $5}')"
			echo "# 290 Video
			# breite Pixel: lang ziehen
			# 2CIF (Test 1)
			# PIXELVERZERRUNG > 1 : ${PIXELVERZERRUNG}
			# BREITE='${BREITE}'
			# HOEHE='${HOEHE}'
			" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt
			#
			PIXELKORREKTUR="scale=${BILD_BREIT}x${BILD_HOCH},"
		fi
	else
		if [ "${DAR_FAKTOR}" -lt "149333" ] ; then
			BREITE="4"
			HOEHE="3"
			echo "# 300: 4/3"
			# BREITE='${BREITE}'
			# HOEHE='${HOEHE}'
			" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt
		else
			BREITE="16"
			HOEHE="9"
			echo "# 310: 16/9"
			# BREITE='${BREITE}'
			# HOEHE='${HOEHE}'
			" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt
		fi
		FORMAT_ANPASSUNG="setdar='${BREITE}/${HOEHE}',"

		echo "# 320 Video
		BREITE='${BREITE}'
		HOEHE='${HOEHE}'
		FORMAT_ANPASSUNG='${FORMAT_ANPASSUNG}'
		" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt
	fi
else
	echo "# 330 Video" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt
	ORIG_DAR_BREITE="$(echo "${IN_DAR}" | awk '{gsub("[:/]"," "); print $1}')"
	ORIG_DAR_HOEHE="$(echo "${IN_DAR}" | awk '{gsub("[:/]"," "); print $2}')"
	BREITE="${ORIG_DAR_BREITE}"
	HOEHE="${ORIG_DAR_HOEHE}"
	FORMAT_ANPASSUNG="setdar='${BREITE}/${HOEHE}',"
fi

if [ x != "x${BREITE}" -a x = "x${HOEHE}" ] ; then
	HOEHE="1"
fi

echo "# 331 Video
IN_DAR=${IN_DAR}
ORIG_DAR_BREITE="${ORIG_DAR_BREITE}"
ORIG_DAR_HOEHE="${ORIG_DAR_HOEHE}"
BREITE="${BREITE}"
HOEHE="${HOEHE}"
" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt

#exit 332
#==============================================================================#
### Profile werden hier ausgeführt

echo "# 340 Video
SOLL_XY='${SOLL_XY}'
" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt

#exit 360

#==============================================================================#
#------------------------------------------------------------------------------#
### gewünschtes Rasterformat der Bildgröße (Auflösung)
### wenn ein bestimmtes Format gewünscht ist, dann muss es am Ende auch rauskommen

if [ x = "x${SOLL_XY}" ] ; then
	echo "# 370 Video" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt
	unset BILD_SCALE
	unset SOLL_XY

	### ob die Pixel bereits quadratisch sind
	if [ "${PAR_FAKTOR}" -ne "100000" ] ; then
		### Umrechnung in quadratische Pixel
		#
		### [swscaler @ 0x81520d000] Warning: data is not aligned! This can lead to a speed loss
		### laut Googel müssen die Pixel durch 16 teilbar sein, beseitigt aber leider dieses Problem nicht

		echo "# 380 Video
		O_BREIT=${O_BREIT}
		O_HOCH=${O_HOCH}
		O_DAR=${O_DAR}
		IN_BREIT=${IN_BREIT}
		IN_HOCH=${IN_HOCH}
		IN_DAR=${IN_DAR}
		" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt

		#exit 390

		IN_DAR="$(echo "${O_BREIT} ${O_HOCH} ${O_DAR_1} ${O_DAR_2} ${IN_BREIT} ${IN_HOCH}" | awk '{gsub(":"," ");print $2 * $3 * $5 / $1 / $4 / $6}')"
		DARFAKTOR_0="$(echo "${IN_DAR}" | awk '{printf "%u\n", ($1*100000)}')"
		#TEIL_HOEHE="$(echo "${IN_BREIT} ${IN_HOCH} ${IN_DAR} ${TEILER}" | awk '{gsub(":"," ");printf "%.0f\n", sqrt($1 * $2 * $3 / $4) / $3 / $5, $5}' | awk '{print $1 * $2}')"
		if [ "${DARFAKTOR_0}" -lt "149333" ] ; then
			echo "# 400: 4/3" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt
			TEIL_HOEHE="$(echo "${IN_BREIT} ${IN_HOCH} ${IN_DAR} ${TEILER}" | awk '{printf "%.0f %.0f\n", sqrt($1 * $2 / $3) / $4, $4}' | awk '{print $1 * $2}')"
			BILD_BREIT="$(echo "${TEIL_HOEHE} ${BREITE} ${HOEHE} ${TEILER}" | awk '{printf "%.0f %.0f\n", ($1 * $2 / $3) / $4, $4}' | awk '{print $1 * $2}')"
			BILD_HOCH="${TEIL_HOEHE}"
		else
			echo "# 410: 16/9" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt
			TEIL_BREIT="$(echo "${IN_BREIT} ${IN_HOCH} ${IN_DAR} ${TEILER}" | awk '{printf "%.0f %.0f\n", sqrt($1 * $2 * $3) / $4, $4}' | awk '{print $1 * $2}')"
			BILD_BREIT="${TEIL_BREIT}"
			BILD_HOCH="$(echo "${TEIL_BREIT} ${BREITE} ${HOEHE} ${TEILER}" | awk '{printf "%.0f %.0f\n", ($1 * $3 / $2) / $4, $4}' | awk '{print $1 * $2}')"
		fi
		BILD_SCALE="scale=${BILD_BREIT}x${BILD_HOCH},"

		echo "# 420 Video
		DARFAKTOR_0=${DARFAKTOR_0}
		BREITE='${BREITE}'
		HOEHE='${HOEHE}'
		O_BREIT='${O_BREIT}'
		O_HOCH='${O_HOCH}'
		O_DAR='${O_DAR}'
		IN_BREIT='${IN_BREIT}'
		IN_HOCH='${IN_HOCH}'
		IN_DAR='${IN_DAR}'
		TEIL_BREIT='${TEIL_BREIT}'
		TEIL_HOEHE='${TEIL_HOEHE}'
		BILD_BREIT='${BILD_BREIT}'
		BILD_HOCH='${BILD_HOCH}'
		BILD_SCALE='${BILD_SCALE}'
		" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt

		#exit 421
	else
		### wenn die Pixel bereits quadratisch sind
		BILD_BREIT="${IN_BREIT}"
		BILD_HOCH="${IN_HOCH}"

		echo "# 430 Video
		BILD_BREIT='${BILD_BREIT}'
		BILD_HOCH='${BILD_HOCH}'
		" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt
	fi
else
	echo "# 440 Video" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt
	### Übersetzung von Bildauflösungsnamen zu Bildauflösungen
	### tritt nur bei manueller Auswahl der Bildauflösung in Kraft
	AUFLOESUNG_ODER_NAME="$(echo "${SOLL_XY}" | grep -E '[0-9][0-9][0-9][x][0-9][0-9]')"
	if [ x = "x${AUFLOESUNG_ODER_NAME}" ] ; then
		echo "# 450 Video" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt
		### manuelle Auswahl der Bildauflösung per Namen
		if [ x = "x${BILD_FORMATNAMEN_AUFLOESUNGEN}" ] ; then
			echo "# 460 Video" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt
			echo "Die gewünschte Bildauflösung wurde als 'Name' angegeben: '${SOLL_XY}'"
			echo "Für die Übersetzung wird die Datei 'Filmwandler_grafik.txt' benötigt."
			echo "Leider konnte die Datei '${AVERZ}/Filmwandler_grafik.txt' nicht gelesen werden."
			exit 470
		else
			echo "# 480 Video" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt
			NAME_XY_DAR="$(echo "${BILD_FORMATNAMEN_AUFLOESUNGEN}" | grep -E '[-]soll_xmaly ' | awk '{print $2,$4,$5}' | grep -E -i "^${SOLL_XY} ")"
			SOLL_XY="$(echo "${NAME_XY_DAR}" | awk '{print $2}')"
			SOLL_DAR="$(echo "${NAME_XY_DAR}" | awk '{print $3}')"

			# https://ffmpeg.org/ffmpeg-filters.html#setdar_002c-setsar
			FORMAT_ANPASSUNG="setdar='${SOLL_DAR}',"
		fi
	fi

	BILD_BREIT="$(echo "${SOLL_XY}" | sed 's/x/ /;s/^[^0-9][^0-9]*//;s/[^0-9][^0-9]*$//' | awk '{print $1}')"
	BILD_HOCH="$(echo "${SOLL_XY}" | sed 's/x/ /;s/^[^0-9][^0-9]*//;s/[^0-9][^0-9]*$//' | awk '{print $2}')"
	BILD_SCALE="scale=${SOLL_XY},"

	echo "# 490 Video
	BILD_BREIT='${BILD_BREIT}'
	BILD_HOCH='${BILD_HOCH}'
	BILD_SCALE='${BILD_SCALE}'
	" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt
fi

#exit 500
#------------------------------------------------------------------------------#

if [ "x${PIXELKORREKTUR}" != x ] ; then
	echo "# 510 Video
	BILD_SCALE='${BILD_SCALE}'
	" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt

	BILD_SCALE="${PIXELKORREKTUR}"

	echo "# 520 Video
	BILD_SCALE='${BILD_SCALE}'
	" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt
fi

#exit 530
#------------------------------------------------------------------------------#
### wenn das Bild hochkannt steht, dann müssen die Seiten-Höhen-Parameter vertauscht werden
### Breite, Höhe, PAD, SCALE

echo "# 540 Video
SOLL_XY		='${SOLL_XY}'
BILD_BREIT		='${BILD_BREIT}'
BILD_HOCH		='${BILD_HOCH}'
BILD_SCALE		='${BILD_SCALE}'
PIXELKORREKTUR	='${PIXELKORREKTUR}'
SOLL_BILD_SCALE 	='${SOLL_BILD_SCALE}'
" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt

#exit 550

if [ "x${BILD_DREHUNG}" != x ] ; then
	if [ "90" = "${BILD_DREHUNG}" ] ; then
		BILD_DREHEN
		BILD_DREHUNG=",transpose=1"
	elif [ "180" = "${BILD_DREHUNG}" ] ; then
		BILD_DREHUNG=",hflip,vflip"
	elif [ "270" = "${BILD_DREHUNG}" ] ; then
		BILD_DREHEN
		BILD_DREHUNG=",transpose=2"
	else
		echo "nur diese beiden Gradzahlen werden von der Option '-drehen' unterstützt:"
		echo "90° nach links drehen:"
		echo "		${0} -drehen 90"
		echo "90° nach rechts drehen:"
		echo "		${0} -drehen 270"
		echo "komplett einmal umdrehen:"
		echo "		${0} -drehen 180"
		exit 560
	fi
fi

#------------------------------------------------------------------------------#

echo "# 570 Video
O_BREIT		='${O_BREIT}'
O_HOCH		='${O_HOCH}'
FORMAT_ANPASSUNG	='${FORMAT_ANPASSUNG}'
PIXELVERZERRUNG	='${PIXELVERZERRUNG}'
BREITE		='${BREITE}'
HOEHE			='${HOEHE}'
NAME_XY_DAR		='${NAME_XY_DAR}'
IN_DAR		='${IN_DAR}'
IN_BREIT		='${IN_BREIT}'
IN_HOCH		='${IN_HOCH}'
CROP			='${CROP}'
SOLL_DAR		='${SOLL_DAR}'
INBREITE_DAR		='${INBREITE_DAR}'
INHOEHE_DAR		='${INHOEHE_DAR}'
IN_XY			='${IN_XY}'
Originalauflösung	='${IN_BREIT}x${IN_HOCH}'
PIXELZAHL		='${PIXELZAHL}'
SOLL_XY		='${SOLL_XY}'

BILD_BREIT		='${BILD_BREIT}'
BILD_HOCH		='${BILD_HOCH}'
BILD_SCALE		='${BILD_SCALE}'
#==============================================================================#
" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt

#exit 580

#------------------------------------------------------------------------------#
### PAD
# https://ffmpeg.org/ffmpeg-filters.html#pad-1
# pad=640:480:0:40:violet
# pad=width=640:height=480:x=0:y=40:color=violet
#
# max(iw\,ih*(16/9)) => https://ffmpeg.org/ffmpeg-filters.html#maskedmax
#
# pad=Bild vor dem padden:Bildecke oben links:Hintergrundfarbe
# Bild vor dem padden           = iw:ih
# Bildecke oben links           = (ow-iw)/2:(oh-ih)/2
# Hintergrundfarbe (Bildfläche) = ow:oh
#
# iw = Bildbreite vor  dem padden
# ih = Bildhöhe   vor  dem padden
# ow = Bildbreite nach dem padden
# oh = Bildhöhe   nach dem padden
#  a = iw / ih
#
# DAR = Display Aspect Ratio
# SAR = Sample  Aspect Ratio = PAR
# PAR = Pixel   Aspect Ratio = SAR
#
# PAL-TV         (720x576) : DAR  4/3, SAR 16:15 = 1,066666666666666666
# NTNC-TV        (720x486) : DAR  4/3, SAR  9:10 = 0,9
# NTSC-DVD       (720x480) : DAR 16/9, SAR 32:27 = 1,185185185185185185
# PAL-DVD / DVB  (720x576) : DAR 16/9, SAR 64:45 = 1,422222222222222222
# BluRay        (1920x1080): DAR 16/9, SAR  1:1  = 1,0
#

BASISWERTE="${O_BREIT} ${O_HOCH} ${O_DAR_1} ${O_DAR_2} ${IN_BREIT} ${IN_HOCH} ${TEILER}"
BREIT_QUADRATISCH="$(echo "${BASISWERTE}" | awk '{gsub("[:/]"," ") ; printf "%.0f %.0f\n", $2 * $3 * $5 / $1 / $4 / $NF, $NF}' | awk '{printf "%.0f\n", $1*$2}')"
HOCH_QUADRATISCH="$( echo "${BASISWERTE}" | awk '{gsub("[:/]"," ") ; printf "%.0f %.0f\n", $1 * $4 * $6 / $2 / $3 / $NF, $NF}' | awk '{printf "%.0f\n", $1*$2}')"

echo "# 590 Video
# BILD_DAR_HOEHE='${BILD_DAR_HOEHE}'
# BASISWERTE='${BASISWERTE}'
# BREIT_QUADRATISCH='${BREIT_QUADRATISCH}'
# HOCH_QUADRATISCH='${HOCH_QUADRATISCH}'
# IN_BREIT='${IN_BREIT}'
# IN_HOCH='${IN_HOCH}'
"

### -=-
if [ "${BREIT_QUADRATISCH}" -gt "${IN_BREIT}" ] ; then
	ZWISCHENFORMAT_QUADRATISCH="scale=${BREIT_QUADRATISCH}x${IN_HOCH},"
elif [ "${HOCH_QUADRATISCH}" -gt "${IN_HOCH}" ] ; then
	ZWISCHENFORMAT_QUADRATISCH="scale=${IN_BREIT}x${HOCH_QUADRATISCH},"
else
	ZWISCHENFORMAT_QUADRATISCH=""
fi
#
### hier wird die schwarze Hintergrundfläche definiert, auf der dann das Bild zentriert wird
# pad='[hier wird "ow" gesetzt]:[hier wird "oh" gesetzt]:[hier wird der linke Abstand gesetzt]:[hier wird der obere Abstand gesetzt]:[hier wird die padding-Farbe gesetzt]'
#  4/3 => PAD="pad='max(iw\,ih*(4/3)):ow/(4/3):(ow-iw)/2:(oh-ih)/2:black',"
# 16/9 => PAD="pad='max(iw\,ih*(16/9)):ow/(16/9):(ow-iw)/2:(oh-ih)/2:black',"
PAD="${ZWISCHENFORMAT_QUADRATISCH}pad='max(iw\\,ih*(${BREITE}/${HOEHE})):ow/(${BREITE}/${HOEHE}):(ow-iw)/2:(oh-ih)/2:black',"

echo "# 600 Video
# O_BREIT='${O_BREIT}'
# O_HOCH='${O_HOCH}'
# IN_DAR='${IN_DAR}'
# BILD_DAR_HOEHE='${BILD_DAR_HOEHE}'
# BREITE='${BREITE}'
# HOEHE='${HOEHE}'
# IN_BREIT='${IN_BREIT}'
# IN_HOCH='${IN_HOCH}'
# BASISWERTE='${BASISWERTE}'
# BREIT_QUADRATISCH='${BREIT_QUADRATISCH}'
# HOCH_QUADRATISCH='${HOCH_QUADRATISCH}'
# ZWISCHENFORMAT_QUADRATISCH='${ZWISCHENFORMAT_QUADRATISCH}'
# PAD='${PAD}'

# ENDUNG=${ENDUNG}
# VIDEO_FORMAT=${VIDEO_FORMAT}
" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt

#exit 610

#------------------------------------------------------------------------------#
### hier wird ausgerechnen wieviele Pixel der neue Film pro Bild haben wird
### und die gewünschte Breite und Höhe wird festgelegt, damit in anderen
### Funktionen weitere Berechningen für Modus, Bitrate u.a. errechnet werden
### kann

if [ x = "x${SOLL_XY}" ] ; then
	PIXELZAHL="$(echo "${IN_BREIT} ${IN_HOCH}" | awk '{print $1 * $2}')"
	VERGLEICH_BREIT="${IN_BREIT}"
	VERGLEICH_HOCH="${IN_HOCH}"
else
	P_BREIT="$(echo "${SOLL_XY}" | awk -F'x' '{print $1}')"
	P_HOCH="$(echo "${SOLL_XY}" | awk -F'x' '{print $2}')"
	PIXELZAHL="$(echo "${P_BREIT} ${P_HOCH}" | awk '{print $1 * $2}')"
	VERGLEICH_BREIT="${P_BREIT}"
	VERGLEICH_HOCH="${P_HOCH}"
fi

#------------------------------------------------------------------------------#

#exit 550

#------------------------------------------------------------------------------#
### BILD_BREIT und BILD_HOCH prüfen

echo "# 560
# ORIGINAL_DAR='${ORIGINAL_DAR}'
# BILD_BREIT='${BILD_BREIT}'
# BILD_HOCH='${BILD_HOCH}'
" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt

#set -x
if [ x = "x${BILD_BREIT}" -o x = "x${BILD_HOCH}" ] ; then
	echo "# 570: ${BILD_BREIT}x${BILD_HOCH}"
	exit 570
fi

#exit 580

#------------------------------------------------------------------------------#

echo "# 590
# ENDUNG=${ENDUNG}
# VIDEO_FORMAT=${VIDEO_FORMAT}
" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt

VIDEO_ENDUNG="$(echo "${ENDUNG}" | awk '{print tolower($1)}')"

#------------------------------------------------------------------------------#
### Variable FORMAT füllen

echo "# 600 CONSTANT_QUALITY
# CONSTANT_QUALITY='${CONSTANT_QUALITY}'
# VIDEOCODEC='${VIDEOCODEC}'
# AUDIOCODEC='${AUDIOCODEC}'
" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt

#exit 601

#==============================================================================#
#
# WEBM -> HTML5
#
# Only VP8 or VP9 or AV1 video and Vorbis or Opus audio and WebVTT subtitles are supported for WebM.
#
#==============================================================================#
#
# ffmpeg -h encoder=libopus
# http://opus-codec.org/
# http://ffmpeg.org/ffmpeg-codecs.html#libopus-1
# https://wiki.xiph.org/Opus_Recommended_Settings
#
#==============================================================================#

# Format
FORMAT="webm"

#==============================================================================#
#
# Opus
#
#==============================================================================#
#
# Der native Opus-Encoder ist noch im experimentellen Stadium (2019).
# Der externe Opus-Encoder ist nicht mehr im experimentellen Stadium (2019).
#
#------------------------------------------------------------------------------#

### https://trac.ffmpeg.org/wiki/Encode/HighQualityAudio
#
#   Seit 2017 verfügt FFmpeg über einen eigenen, nativen Opus-Encoder
#   und -Decoder.
#   Die Mobil-Plattform Android unterstützt ab Version 5 (Lollipop)
#   Opus eingebettet in das Matroska-Containerformat nativ.

#------------------------------------------------------------------------------#

CODEC_PATTERN="opus"			# Beispiel: "h265|hevc"

AUDIOCODEC="$(suche_audio_encoder "libopus")"
if [ "x${AUDIOCODEC}" = "x" ] ; then
	AUDIOCODEC="$(suche_audio_encoder "${CODEC_PATTERN}")"
	if [ "x${AUDIOCODEC}" = "x" ] ; then
		AUDIOCODEC="$(echo "${FFMPEG_LIB}" | grep -E "${CODEC_PATTERN}" | head -n1)"
		if [ "x${AUDIOCODEC}" = "x" ] ; then
			AUDIOCODEC="$(echo "${FFMPEG_FORMATS}" | grep -E "${CODEC_PATTERN}" | head -n1)"
			if [ "x${AUDIOCODEC}" = "x" ] ; then
				echo ""
				echo "CODEC_PATTERN='${CODEC_PATTERN}'"
				echo "AUDIOCODEC='${AUDIOCODEC}'"
				echo "Leider wird dieser Codec von der aktuell installierten Version"
				echo "von FFmpeg nicht unterstützt!"
				echo ""
#				exit 1

				AUDIOCODEC="opus"
			fi
		fi
	fi
fi

#------------------------------------------------------------------------------#
# https://ffmpeg.org/pipermail/ffmpeg-devel/2016-June/195178.html
#
# Example usage:
#
# > wget https://samples.ffmpeg.org/A-codecs/wavpcm/8_Channel_ID.wav -O in.wav
#
# Use the old behavior. Header contains layout, but no masking
# > ./ffmpeg -y -i in.wav -c:a opus -mapping_family -1 out.ogg
#
# Use libopus surround mode. Masking + automatic channel coupling
# > ./ffmpeg -y -i in.wav -c:a opus -mapping_family 1 out.ogg
#
# Use libopus with independent channels. No header info, no masking,
# no coupling
# > ./ffmpeg -y -i in.wav -c:a opus -mapping_family 255 out.ogg
#
# This patch also makes it possible to encode up to 254 channels with opus
# using channel mapping family 255.
#
#------------------------------------------------------------------------------#

#------------------------------------------------------------------------------#
### leider ist "opus" noch experimentel und kann nur Stereo

if [ "${AUDIOCODEC}" = "opus" ] ; then
	# diese Option wird mit dem Codec zusammen, nur einmal für alle Kanäle zusammen,
	# angegeben und nicht für jeden Kanal extra
	AUDIO_OPTION_GLOBAL="-strict -2 -ac 2"		# opus
else
	# diese Option wird mit dem Codec zusammen, nur einmal für alle Kanäle zusammen,
	# angegeben und nicht für jeden Kanal extra
	AUDIO_OPTION_GLOBAL="-compression_level 10"	# libopus
fi

#------------------------------------------------------------------------------#
#AUDIOCODEC="libopus"

echo "# 1001
TS_ANZAHL=${TS_ANZAHL}
AUDIO_OPTION_GLOBAL='${AUDIO_OPTION_GLOBAL}'
" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt

#exit 1001

#==============================================================================#

### libopus
## -vbr 0 (Use constant bit rate)
## -vbr 1 (Use variable bit rate)
## -vbr 2 (Use constrained VBR)
## Mehrkanalton kann libopus aber nur mit mapping_family (-1, 1, 255)

F_AUDIO_QUALITAET()
{
	AUDIO_BIT_kBIT_PRO_KANAL="
	24
	32
	40
	48
	56
	64
	64
	64
	64
	64
	"

	if [ "${AUDIOCODEC}" = "libopus" ] ; then
		AUDIO_BIT_RATE="$(echo "${AUDIO_KANAELE} $(echo "${AUDIO_BIT_kBIT_PRO_KANAL}" | grep -Ev '#|^[ \t]*$' | head -n${AUDIO_VON_OBEN} | tail -n1) 64 2" | awk '{print $1 * $2}')k"
		if [ "${AUDIO_KANAELE}" -gt 2 ] ; then
        		echo "-b:a:${1} ${AUDIO_BIT_RATE} -vbr:a:${1} on -mapping_family:a:${1} 1 -filter:a:${1} aformat=channel_layouts='7.1|6.1|5.1|5.0|quad|3.0'"
		else
        		echo "-b:a:${1} ${AUDIO_BIT_RATE} -vbr:a:${1} on -mapping_family:a:${1} 0 -filter:a:${1} aformat=channel_layouts='stereo|mono'"
		fi
	else
		AUDIO_BIT_RATE="$(echo "2 $(echo "${AUDIO_BIT_kBIT_PRO_KANAL}" | grep -Ev '#|^[ \t]*$' | head -n${AUDIO_VON_OBEN} | tail -n1) 64 2" | awk '{print $1 * $2}')k"
        	echo "-b:a:${1} ${AUDIO_BIT_RATE} "
	fi
}


#==============================================================================#
#
# AV1
#
# https://trac.ffmpeg.org/wiki/Encode/AV1
#
#==============================================================================#
#
# https://ffmpeg.org/ffmpeg-codecs.html
#   ffmpeg -h encoder=av1
#   ffmpeg -h encoder=libaom-av1
#   ffmpeg -h encoder=libsvtav1
#
#==============================================================================#

CODEC_PATTERN="av1|aom"			# Beispiel: "h265|hevc"

#==============================================================================#
### vollautomatische Kodeksuche wurde in diesem Fall abgeschaltet,
### bei der auch nach bisher unbekannten Kodeks gesucht wird

#VIDEOCODEC="$(suche_video_encoder "libaom")"
VIDEOCODEC="$(suche_video_encoder "svtav1")"
if [ "x${VIDEOCODEC}" = "x" ] ; then
	VIDEOCODEC="$(suche_video_encoder "${CODEC_PATTERN}")"
	if [ "x${VIDEOCODEC}" = "x" ] ; then
		VIDEOCODEC="$(echo "${FFMPEG_LIB}" | grep -Fv libdav1d | grep -E "${CODEC_PATTERN}" | head -n1)"
		if [ "x${VIDEOCODEC}" = "x" ] ; then
			VIDEOCODEC="$(echo "${FFMPEG_FORMATS}" | grep -E "${CODEC_PATTERN}" | head -n1)"
			if [ "x${VIDEOCODEC}" = "x" ] ; then
				echo ""
				echo "CODEC_PATTERN='${CODEC_PATTERN}'"
				echo "VIDEOCODEC='${VIDEOCODEC}'"
				echo "Leider wird dieser Codec von der aktuell installierten Version"
				echo "von FFmpeg nicht unterstützt!"
				echo ""
#				exit 1

				VIDEOCODEC="av1"
			fi
		fi
	fi
fi

echo "# AV1 01
# VIDEOCODEC='${VIDEOCODEC}'
"

#==============================================================================#

#------------------------------------------------------------------------------#
#------------------------------------------------------------------------------#
# HDR_FARBRAUM="-colorspace bt2020nc -color_trc smpte2084 -color_primaries bt2020"	# diese verwendet YouTube
#------------------------------------------------------------------------------#
#------------------------------------------------------------------------------#

#VIDEOCODEC="av1"		# AOM-AV1 erzwingen / ist der langsamste und bietet die beste Qualität
#VIDEOCODEC="libsvtav1"		# SVT-AV1 erzwingen / ist der schnellste und bietet ausreichende Qualität
#VIDEOCODEC="librav1e"		# Rav1E erzwingen (Version < 1) / hat leider Version 1 noch nicht erreicht / ist mittelmäßig schnell bietet aber schnellerer Einstellung, bessere Qualität als AOM-AV1

################################################################################
if [ libaom-av1 = "${VIDEOCODEC}" -o av1 = "${VIDEOCODEC}" ] ; then
	echo "# libaom_av1"

	#------------------------------------------------------------------------------#
	### kurz gesagt:
	# - Qualität und Dateigröße ist von "-crf" abhängig;
	# - Transkodier-Geschwindigkeit und Dateigröße ist von "-cpu-used" abhängig;
	#------------------------------------------------------------------------------#
	### https://streaminglearningcenter.com/blogs/good-news-av1-encoding-times-drop-to-near-reasonable-levels.html
	### -cpu-used 0-8	- bei "8": höchste Verarbeitsungsgeschwindigkeit
	#------------------------------------------------------------------------------#

	VIDEO_OPTION="-cpu-used 8 -row-mt 1 -aq-mode 1 -tune 1 -threads ${CPU_KERNE}"	# -aom-params fp-mt=1 geht mit 2-Pass nicht
	VIDEO_QUALITAET_0="-crf 58 ${VIDEO_OPTION}"
	VIDEO_QUALITAET_1="-crf 54 ${VIDEO_OPTION}"
	VIDEO_QUALITAET_2="-crf 50 ${VIDEO_OPTION}"
	VIDEO_QUALITAET_3="-crf 46 ${VIDEO_OPTION}"
	VIDEO_QUALITAET_4="-crf 42 ${VIDEO_OPTION}"
	VIDEO_QUALITAET_5="-crf 38 ${VIDEO_OPTION}"
	VIDEO_QUALITAET_6="-crf 34 ${VIDEO_OPTION}"
	VIDEO_QUALITAET_7="-crf 30 ${VIDEO_OPTION}"
	VIDEO_QUALITAET_8="-crf 26 ${VIDEO_OPTION}"
	VIDEO_QUALITAET_9="-crf 22 ${VIDEO_OPTION}"
elif [ libsvtav1 = "${VIDEOCODEC}" ] ; then
	echo "# libsvtav1"

	#------------------------------------------------------------------------------#
	# https://trac.ffmpeg.org/wiki/Encode/AV1#SVT-AV1
	# ffmpeg -h encoder=libsvt_av1
	#------------------------------------------------------------------------------#
	#
	# https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/master/Docs/CommonQuestions.md#what-presets-do
	#  -preset 10 -crf 35	: Für eine schnelle Codierung muss das "preset" ausreichend hoch sein, damit Ihre CPU ohne Stottern codieren kann. Höhere Voreinstellungen sind schneller, aber weniger effizient.
	#  -preset 5 -crf 32	: Für einen Medienserver oder HTPC, sind eine höhere Effizienz und vernünftige Codierzeiten wünschenswert.
	#  -preset 2 -crf 25	: Für professionelle VOD-Anwendungen wird oft die bestmögliche Effizienz gewünscht.
	#
	#------------------------------------------------------------------------------#
	# Voreinstellung: -crf 35 -preset 10 -svtav1-params tune=1:fast-decode=1
	#
	# Ähnlich wie CRF in x264 und x265 versucht diese Rate-Control-Methode (CRF) sicherzustellen, dass jeder Frame die Anzahl an Bits erhält, die er verdient, um ein bestimmtes (wahrnehmungsbezogenes) Qualitätsniveau zu erreichen.
	# CRF           : 0...63	# kleinere Werte ergeben eine bessere Qualität und deutlich größere Dateien
	#
	# Der Kompromiss zwischen Kodierungsgeschwindigkeit und Komprimierungseffizienz wird mit der Option -preset verwaltet.
	# preset        : 0...12	# kleinere Werte ergeben eine etwas kleinere Dateie und eine deutlich langsamere Kodierungsgeschwindigkeit
	#
	#------------------------------------------------------------------------------#
	# CLI-Test:
	# > for BILD_HOCH in $(seq 1 36 | awk '{print $1*120}'); do echo -e "9 1\n$(seq 0 44 | nl | awk '{printf "%.0f %.0f\n", $1+18,120*((36^(1/44))^$2)}')" | awk -v b="${BILD_HOCH}" '{if ($2 >= b) crf=$1 ; if ($2 < b) crf="#" ; print crf,b" | "$1,$2}' | grep -Ev '^#' | head -n1; done
	#------------------------------------------------------------------------------#

	#KORREKTUR="9"	# Fokus auf Qualität
	KORREKTUR="3"	# Fokus auf Dateigröße
	CRF="$(echo -e "9 1\n$(seq 0 44 | nl | awk '{printf "%.0f %.0f\n", $1+18,120*((36^(1/44))^$2)}')" | awk -v b="${BILD_HOCH}" -v q="${BILDQUALIT}" '{if ($2 >= b) crf=$1-q ; if ($2 < b) crf="#" ; print crf}' | grep -Ev '^#' | head -n1 | awk -v k="${KORREKTUR}" '{crf=$1; if ((10+k) >= $1) crf=(10+k) ; if ((60+k) <= $1) crf=(60+k) ; print crf-k}')"
	echo "# -crf ${CRF}"
	VIDEO_OPTION="-svtav1-params enable-overlays=1:enable-tf=0:film-grain=0:film-grain-denoise=0:keyint=5s:scd=1:tune=0:fast-decode=0"

	# Fokus auf Qualität
	VIDEO_QUALITAET_0="-crf ${CRF} -preset 9 ${VIDEO_OPTION}"		# größte Datei, schnellstes, schlechteste Qualität
	VIDEO_QUALITAET_1="-crf ${CRF} -preset 8 ${VIDEO_OPTION}"		# 
	VIDEO_QUALITAET_2="-crf ${CRF} -preset 7 ${VIDEO_OPTION}"		# 
	VIDEO_QUALITAET_3="-crf ${CRF} -preset 6 ${VIDEO_OPTION}"		# 
	VIDEO_QUALITAET_4="-crf ${CRF} -preset 5 ${VIDEO_OPTION}"		# 
	VIDEO_QUALITAET_5="-crf ${CRF} -preset 4 ${VIDEO_OPTION}"		# "-vq 5 ist" Standard
	VIDEO_QUALITAET_6="-crf ${CRF} -preset 3 ${VIDEO_OPTION}"		# 
	VIDEO_QUALITAET_7="-crf ${CRF} -preset 2 ${VIDEO_OPTION}"		# 
	VIDEO_QUALITAET_8="-crf ${CRF} -preset 1 ${VIDEO_OPTION}"		# 
	VIDEO_QUALITAET_9="-crf ${CRF} -preset 0 ${VIDEO_OPTION}"		# kleinste Datei, langsamstes, beste Qualität

	# Fokus auf Kodierungsgeschwindigkeit
	#VIDEO_QUALITAET_0="-crf ${CRF} -preset 10 ${VIDEO_OPTION}"		# größte Datei, schnellstes, schlechteste Qualität
	#VIDEO_QUALITAET_1="-crf ${CRF} -preset 9 ${VIDEO_OPTION}"		# 
	#VIDEO_QUALITAET_2="-crf ${CRF} -preset 8 ${VIDEO_OPTION}"		# 
	#VIDEO_QUALITAET_3="-crf ${CRF} -preset 7 ${VIDEO_OPTION}"		# 
	#VIDEO_QUALITAET_4="-crf ${CRF} -preset 6 ${VIDEO_OPTION}"		# 
	#VIDEO_QUALITAET_5="-crf ${CRF} -preset 5 ${VIDEO_OPTION}"		# "-vq 5 ist" Standard
	#VIDEO_QUALITAET_6="-crf ${CRF} -preset 4 ${VIDEO_OPTION}"		# 
	#VIDEO_QUALITAET_7="-crf ${CRF} -preset 3 ${VIDEO_OPTION}"		# 
	#VIDEO_QUALITAET_8="-crf ${CRF} -preset 2 ${VIDEO_OPTION}"		# 
	#VIDEO_QUALITAET_9="-crf ${CRF} -preset 1 ${VIDEO_OPTION}"		# kleinste Datei, langsamstes, beste Qualität
elif [ librav1e = "${VIDEOCODEC}" ] ; then
	echo "# librav1e"

	#   ffmpeg -h encoder=librav1e
	#
	# https://ffmpeg.org/ffmpeg-codecs.html
	#  -c:v librav1e
	#  -qp            "-1 bis 255"    (default 100; kleinerer Wert steht für bessere Qualität)
	#  -speed         "-1 bis 10"     (default -1) / wie "preset" bei libsvtav1
	#  -tiles         "-1 to I64_MAX" (default 0)  / wie "threads" zu betrachten
	#  -tile-rows     "-1 to I64_MAX" (default 0)
	#  -tile-columns  "-1 to I64_MAX" (default 0)
	#  -rav1e-params
	#    :speed=5     "0 bis 10"
	#    :low_latency=true
	#    :tune=psnr                                / Dateigröße: mit psnr 2,8MB; ohne psnr 3MB
	#
	#------------------------------------------------------------------------------#

	VIDEO_OPTION="-qp 80 -tiles ${CPU_KERNE}"
	VIDEO_QUALITAET_0="${VIDEO_OPTION} -rav1e-params speed=10:low_latency=false"	# speed=0-10
	VIDEO_QUALITAET_1="${VIDEO_OPTION} -rav1e-params speed=9:low_latency=false"	# speed=0-10
	VIDEO_QUALITAET_2="${VIDEO_OPTION} -rav1e-params speed=8:low_latency=false"	# speed=0-10
	VIDEO_QUALITAET_3="${VIDEO_OPTION} -rav1e-params speed=7:low_latency=false"	# speed=0-10
	VIDEO_QUALITAET_4="${VIDEO_OPTION} -rav1e-params speed=6:low_latency=false"	# speed=0-10
	VIDEO_QUALITAET_5="${VIDEO_OPTION} -rav1e-params speed=5:low_latency=false"	# speed=0-10
	VIDEO_QUALITAET_6="${VIDEO_OPTION} -rav1e-params speed=4:low_latency=false"	# speed=0-10
	VIDEO_QUALITAET_7="${VIDEO_OPTION} -rav1e-params speed=3:low_latency=false"	# speed=0-10
	VIDEO_QUALITAET_8="${VIDEO_OPTION} -rav1e-params speed=2:low_latency=false"	# speed=0-10
	VIDEO_QUALITAET_9="${VIDEO_OPTION} -rav1e-params speed=1:low_latency=false"	# speed=0-10
elif [ av1_nvenc = "${VIDEOCODEC}" ] ; then
	echo "# av1_nvenc"

	VIDEO_OPTION=""
	VIDEO_QUALITAET_0="-qp 15 ${VIDEO_OPTION}"		# von "-1" bis "255"
	VIDEO_QUALITAET_1="-qp 30 ${VIDEO_OPTION}"		# von "-1" bis "255"
	VIDEO_QUALITAET_2="-qp 45 ${VIDEO_OPTION}"		# von "-1" bis "255"
	VIDEO_QUALITAET_3="-qp 50 ${VIDEO_OPTION}"		# von "-1" bis "255"
	VIDEO_QUALITAET_4="-qp 65 ${VIDEO_OPTION}"		# von "-1" bis "255"
	VIDEO_QUALITAET_5="-qp 80 ${VIDEO_OPTION}"		# von "-1" bis "255"
	VIDEO_QUALITAET_6="-qp 95 ${VIDEO_OPTION}"		# von "-1" bis "255"
	VIDEO_QUALITAET_7="-qp 110 ${VIDEO_OPTION}"		# von "-1" bis "255"
	VIDEO_QUALITAET_8="-qp 125 ${VIDEO_OPTION}"		# von "-1" bis "255"
	VIDEO_QUALITAET_9="-qp 140 ${VIDEO_OPTION}"		# von "-1" bis "255"
fi
################################################################################

echo "# AV1 02
# VIDEOCODEC='${VIDEOCODEC}'
# VIDEO_OPTION='${VIDEO_OPTION}'
"

#------------------------------------------------------------------------------#

#==============================================================================#

FORMAT_BESCHREIBUNG="
********************************************************************************
* Name:                 WebM                                                   *
* ENDUNG:               .webm                                                  *
* Video-Kodierung:      AV1  (freie Alternative zu H.265 für 4K)               *
* Audio-Kodierung:      Opus (freie Alternative zu AAC)                        *
* Beschreibung:                                                                *
*       - mit HTML5-Unterstützung                                              *
*       - WebM kann leider nur das eine Untertitelformat "WebVTT" (Text)       *
*       - 'Royalty free' (komplett frei von patentierten Technologien)         *
*       - WebM wird seit Android  2.3 'Gingerbread' unterstützt                *
*       - Opus wird seit Android 5 'Lollipop' unterstützt                      *
********************************************************************************
"

echo "# 630 CONSTANT_QUALITY
# CONSTANT_QUALITY='${CONSTANT_QUALITY}'
# VIDEOCODEC='${VIDEOCODEC}'
# AUDIOCODEC='${AUDIOCODEC}'
# VIDEO_FORMAT='${VIDEO_FORMAT}'
" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt

#exit 631

#------------------------------------------------------------------------------#
### Container-Format nach Wunsch setzen

if [ "${VIDEO_FORMAT}" != "${VIDEO_ENDUNG}" ] ; then
	FORMAT="${CONTAINER_FORMAT}"
fi

START_ZIEL_FORMAT="-f ${FORMAT}"

#------------------------------------------------------------------------------#

echo "# 660
# $(date +'%F %T')
#
# CONSTANT_QUALITY='${CONSTANT_QUALITY}'
# ENDUNG='${ENDUNG}'
# VIDEO_ENDUNG='${VIDEO_ENDUNG}'
# VIDEO_FORMAT='${VIDEO_FORMAT}'
# VIDEOCODEC='${VIDEOCODEC}'
# AUDIOCODEC='${AUDIOCODEC}'
# FORMAT='${FORMAT}'
# VIDEO_OPTION='${VIDEO_OPTION}'
# VIDEO_OPTION_BD='${VIDEO_OPTION_BD}'
# VIDEO_OPTION_00='${VIDEO_OPTION_00}'
# VIDEOOPTION='${VIDEOOPTION}'
" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt

#exit 670

#------------------------------------------------------------------------------#
### Video-Codec

echo "# 690 CONSTANT_QUALITY
# VIDEOCODEC='${VIDEOCODEC}'
# AUDIOCODEC='${AUDIOCODEC}'
# CONSTANT_QUALITY='${CONSTANT_QUALITY}'
# VIDEOOPTION='${VIDEOOPTION}'
# VIDEO_OPTION_BD='${VIDEO_OPTION_BD}'
# VIDEO_OPTION_00='${VIDEO_OPTION_00}'
# VIDEOOPTION='${VIDEOOPTION}'
" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt

#exit 692

#==============================================================================#
#==============================================================================#
# Audio

#------------------------------------------------------------------------------#

echo "# 700
TON_SPUR_SPRACHE='${TON_SPUR_SPRACHE}'
" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt

#------------------------------------------------------------------------------#

if [ x = "x${TON_SPUR_SPRACHE}" ] ; then
	TSNAME="$(echo "${META_DATEN_STREAMS}" | grep -F 'codec_type=audio' | nl | awk '{print $1 - 1}' | tr -s '\n' ',' | sed 's/^,//;s/,$//')"
else
	# 0:deu,1:eng,2:spa,3,4
	TSNAME="${TON_SPUR_SPRACHE}"
fi

# 0 1 2 3 4
TS_LISTE="$(echo "${TSNAME}" | sed 's/:[a-z]*/ /g;s/,/ /g')"
# 5
TS_ANZAHL="$(echo "${TSNAME}" | sed 's/,/ /g' | wc -w | awk '{print $1}')"

echo "# 710
TS_LISTE='${TS_LISTE}'
TS_ANZAHL='${TS_ANZAHL}'
" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt

#------------------------------------------------------------------------------#
### FLV unterstützt nur eine einzige Tonspur
#   flv    + FLV        + MP3     (Sorenson Spark: H.263)

if [ "flv" = "${ENDUNG}" ] ; then
	if [ "1" -lt "${TS_ANZAHL}" ] ; then
		echo '# 720
		FLV unterstützt nur eine einzige Tonspur!
		' | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt
		exit 730
	fi
fi

#==============================================================================#
### Sprachen der Spuren

echo "# 740
TON_SPUR_SPRACHE='${TON_SPUR_SPRACHE}'
AUDIO_SPUR_SPRACHE='${AUDIO_SPUR_SPRACHE}'
UNTERTITEL_SPUR_SPRACHE='${UNTERTITEL_SPUR_SPRACHE}'
IST_UT_FORMAT='${IST_UT_FORMAT}'
" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt

# -metadata:s:a:${A} language=${C}
if [ x = "x${TON_SPUR_SPRACHE}" ] ; then
	echo "# 750" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt
	AUDIO_SPUR_SPRACHE="$(echo "${META_DATEN_SPURSPRACHEN}" | grep -F ' audio ' | nl | awk '{print $1 - 1,$4}' | grep -E '^[0-9]')"
else
	echo "# 760" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt
	AUDIO_SPUR_SPRACHE="$(echo "${TON_SPUR_SPRACHE}" | grep -Ev '^$'  | tr -s ',' '\n' | sed 's/:/ /g;s/.*/& und/' | awk '{print $1,$2}' | grep -E '^[0-9]')"
fi

# -metadata:s:s:${A} language=${C}
if [ x = "x${UNTERTITEL_SPUR_SPRACHE}" ] ; then
	echo "# 770" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt
	NOTA_SPUR_SPRACHE="$(echo "${META_DATEN_SPURSPRACHEN}" | grep -F ' subtitle ' | nl | awk '{print $1 - 1,$4}' | grep -E '^[0-9]')"
else
	echo "# 780" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt
	NOTA_SPUR_SPRACHE="$(echo "${UNTERTITEL_SPUR_SPRACHE}" | grep -Ev '^$'  | tr -s ',' '\n' | sed 's/:/ /g;s/.*/& und/' | awk '{print $1,$2}' | grep -E '^[0-9]')"
fi

echo "# 790
TON_SPUR_SPRACHE='${TON_SPUR_SPRACHE}'
AUDIO_SPUR_SPRACHE='${AUDIO_SPUR_SPRACHE}'
UNTERTITEL_SPUR_SPRACHE='${UNTERTITEL_SPUR_SPRACHE}'
NOTA_SPUR_SPRACHE='${NOTA_SPUR_SPRACHE}'
" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt

#exit 800
#==============================================================================#
#------------------------------------------------------------------------------#
### STANDARD-AUDIO-SPUR

### Die Bezeichnungen (Sprache) für die Audiospuren werden automatisch übernommen.
if [ x = "x${AUDIO_STANDARD_SPUR}" ] ; then
	### wenn nichts angegeben wurde, dann
	### Deutsch als Standard-Sprache voreinstellen
	AUDIO_STANDARD_SPUR="$(echo "${AUDIO_SPUR_SPRACHE}" | grep -Ei " deu| ger" | awk '{print $1}' | head -n1)"

	if [ x = "x${AUDIO_STANDARD_SPUR}" ] ; then
		### wenn nichts angegeben wurde
		### und es keine als deutsch gekennzeichnete Spur gibt, dann
		### STANDARD-AUDIO-SPUR vom Originalfilm übernehmen
		### DISPOSITION:default=1
		AUDIO_STANDARD_SPUR="$(echo "${META_DATEN_ZEILENWEISE_STREAMS}" | grep -F ';codec_type=audio;' | tr -s ';' '\n' | grep -F 'DISPOSITION:default=1' | grep -E 'default=[0-9]' | awk -F'=' '{print $2-1}')"
		if [ x = "x${AUDIO_STANDARD_SPUR}" ] ; then
			### wenn es keine STANDARD-AUDIO-SPUR im Originalfilm gibt, dann
			### alternativ einfach die erste Tonspur zur STANDARD-AUDIO-SPUR machen
			AUDIO_STANDARD_SPUR=0
		fi
	fi
fi

echo "# 810
# TS_LISTE='${TS_LISTE}'
# TON_SPUR_SPRACHE='${TON_SPUR_SPRACHE}'
# AUDIO_SPUR_SPRACHE='${AUDIO_SPUR_SPRACHE}'
# AUDIO_STANDARD_SPUR='${AUDIO_STANDARD_SPUR}'
" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt

#exit 820

#------------------------------------------------------------------------------#
### Audio-Codec

echo "# 840
# IN_FPS='${IN_FPS}'
# OP_QUELLE='${OP_QUELLE}'
# STEREO='${STEREO}'
#
# ENDUNG='${ENDUNG}'
# VIDEO_FORMAT='${VIDEO_FORMAT}'
# VIDEOCODEC='${VIDEOCODEC}'
# AUDIOCODEC='${AUDIOCODEC}'
# CONSTANT_QUALITY='${CONSTANT_QUALITY}'
" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt

#exit 850

#==============================================================================#
### Qualität
#
# Qualitäts-Parameter-Übersetzung
# https://slhck.info/video/2017/02/24/vbr-settings.html
#

#------------------------------------------------------------------------------#
#------------------------------------------------------------------------------#
### Audio-Qualität

#------------------------------------------------------------------------------#

AUDIO_VON_OBEN="$(echo "${TONQUALIT}" | awk '{print $1 + 1}')"

#exit 860

echo "# 870
TONQUALIT='${TONQUALIT}'
AUDIO_OPTION_GLOBAL='${AUDIO_OPTION_GLOBAL}'
AUDIO_SPUR_SPRACHE='${AUDIO_SPUR_SPRACHE}'
AUDIOCODEC='${AUDIOCODEC}'
AUDIO_QUALITAET_5='${AUDIO_QUALITAET_5}'
TS_ANZAHL='${TS_ANZAHL}'
TS_LISTE='${TS_LISTE}'
STEREO='${STEREO}'
" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt

#exit 880

if [ 0 -lt "${TS_ANZAHL}" ] ; then
	echo "# 881: Es sind im Film Tonspuren vorhanden, die jetzt ausgewertet werden..." | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt
	#----------------------------------------------------------------------#
	# AUDIO_SPUR_SPRACHE='0 de'
	AUDIO_VERARBEITUNG_01="${AUDIO_OPTION_GLOBAL} $(echo "${AUDIO_SPUR_SPRACHE}" | grep -Ev '^$' | nl | while read AKN TS_NR TS_SP
	do
		LFD_NR="$(echo "${AKN}" | awk '{print $1 - 1}')"
		AUDIO_KANAELE="$(echo "${META_DATEN_ZEILENWEISE_STREAMS}" | grep -F ';codec_type=audio;' | head -n${AKN} | tail -n1 | tr -s ';' '\n' | grep -E '^channels=' | awk -F'=' '{print $2}')"
		echo "# 890 AUDIO_KANAELE='${AUDIO_KANAELE}'" >> "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt

		if [ x = "x${AUDIO_KANAELE}" ] ; then
			AKL10="$(echo "${META_DATEN_ZEILENWEISE_STREAMS}" | grep -F ';codec_type=audio;' | head -n${AKN} | tail -n1 | tr -s ';' '\n' | grep -E 'channel_layout=mono')"
			AKL20="$(echo "${META_DATEN_ZEILENWEISE_STREAMS}" | grep -F ';codec_type=audio;' | head -n${AKN} | tail -n1 | tr -s ';' '\n' | grep -E 'channel_layout=stereo')"
			AKL30="$(echo "${META_DATEN_ZEILENWEISE_STREAMS}" | grep -F ';codec_type=audio;' | head -n${AKN} | tail -n1 | tr -s ';' '\n' | grep -E 'channel_layout=3.0')"
			AKL40="$(echo "${META_DATEN_ZEILENWEISE_STREAMS}" | grep -F ';codec_type=audio;' | head -n${AKN} | tail -n1 | tr -s ';' '\n' | grep -E 'channel_layout=4.0')"
			AKL50="$(echo "${META_DATEN_ZEILENWEISE_STREAMS}" | grep -F ';codec_type=audio;' | head -n${AKN} | tail -n1 | tr -s ';' '\n' | grep -E 'channel_layout=5.0')"
			AKL51="$(echo "${META_DATEN_ZEILENWEISE_STREAMS}" | grep -F ';codec_type=audio;' | head -n${AKN} | tail -n1 | tr -s ';' '\n' | grep -E 'channel_layout=5.1')"
			AKL61="$(echo "${META_DATEN_ZEILENWEISE_STREAMS}" | grep -F ';codec_type=audio;' | head -n${AKN} | tail -n1 | tr -s ';' '\n' | grep -E 'channel_layout=6.1')"
			AKL71="$(echo "${META_DATEN_ZEILENWEISE_STREAMS}" | grep -F ';codec_type=audio;' | head -n${AKN} | tail -n1 | tr -s ';' '\n' | grep -E 'channel_layout=7.1')"

			echo "
			# 900
			# AKL10='${AKL10}'
			# AKL20='${AKL20}'
			# AKL30='${AKL30}'
			# AKL40='${AKL40}'
			# AKL50='${AKL50}'
			# AKL51='${AKL51}'
			# AKL61='${AKL61}'
			# AKL71='${AKL71}'
			" >> "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt

			if [ "x${AKL10}" != "x" ] ; then
				AUDIO_KANAELE=1
			elif [ "x${AKL20}" != "x" ] ; then
				AUDIO_KANAELE=2
			elif [ "x${AKL30}" != "x" ] ; then
				AUDIO_KANAELE=3
			elif [ "x${AKL40}" != "x" ] ; then
				AUDIO_KANAELE=4
			elif [ "x${AKL50}" != "x" ] ; then
				AUDIO_KANAELE=5
			elif [ "x${AKL51}" != "x" ] ; then
				AUDIO_KANAELE=6
			elif [ "x${AKL61}" != "x" ] ; then
				AUDIO_KANAELE=7
			elif [ "x${AKL71}" != "x" ] ; then
				AUDIO_KANAELE=8
			fi
		fi

		echo "# 910 - ${LFD_NR}
		AUDIO_KANAELE='${AUDIO_KANAELE}'
		LFD_NR='${LFD_NR}'
		" >> "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt

		#--------------------------------------------------------------#

		AUDIO_OPTION_PRO_TONSPUR="$(F_AUDIO_QUALITAET ${LFD_NR})"

		#--------------------------------------------------------------#

		echo "# 920 - ${LFD_NR}
		AUDIO_OPTION_PRO_TONSPUR='${AUDIO_OPTION_PRO_TONSPUR}'
		AUDIO_SPUR_SPRACHE='${AUDIO_SPUR_SPRACHE}'
		" >> "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt

		if [ 0 -lt "${TS_ANZAHL}" ] ; then
			echo "# 930
			AUDIO_VERARBEITUNG_01:
			AUDIOQUALITAET='${AUDIOQUALITAET}'
			" >> "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt

			echo "-map 0:a:${TS_NR} -c:a:${LFD_NR} ${AUDIOCODEC} ${AUDIO_OPTION_PRO_TONSPUR} -metadata:s:a:${LFD_NR} language=${TS_SP}" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt

			echo "# 940
			AUDIO_SPUR_SPRACHE='${AUDIO_SPUR_SPRACHE}'
			AUDIO_STANDARD_SPUR='${AUDIO_STANDARD_SPUR}'
			" >> "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt

			#------------------------------------------------------#

			if [ x != "x${AUDIO_STANDARD_SPUR}" ] ; then
				if [ "${LFD_NR}" = "${AUDIO_STANDARD_SPUR}" ] ; then
					echo "# 950" >> "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt
					echo "-disposition:a:${LFD_NR} default" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt
				else
					echo "# 960" >> "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt
					echo "-disposition:a:${LFD_NR} 0" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt
				fi
			fi
		else
			echo "# 970" >> "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt
			echo "-an" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt
		fi
	done | tr -s '\n' ' ')"

	#----------------------------------------------------------------------#

	TS_KOPIE="$(seq 0 ${TS_ANZAHL} | head -n ${TS_ANZAHL})"
	AUDIO_VERARBEITUNG_02="$(for DIE_TS in ${TS_KOPIE}
	do
		#TONSPUR_SPRACHE="$(echo "${AUDIO_SPUR_SPRACHE}" | grep -E "^${DIE_TS} " | awk '{print $NF}' | head -n1)"

		echo "# 980
		AUDIO_VERARBEITUNG_02=' -map 0:a:${DIE_TS} -c:a:${DIE_TS} copy'
		" >> "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt

		echo "-map 0:a:${DIE_TS} -c:a:${DIE_TS} copy"
	done | tr -s '\n' ' ')"
else
	AUDIO_VERARBEITUNG_01="-an"
	AUDIO_VERARBEITUNG_02="-an"
fi

echo "" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt
echo "# 990
# AUDIO_KANAELE='${AUDIO_KANAELE}'
# TONQUALIT='${TONQUALIT}'
# AUDIOQUALITAET='${AUDIOQUALITAET}'
# BEREITS_AK2='${BEREITS_AK2}'
# TS_LISTE='${TS_LISTE}'
# TS_KOPIE='${TS_KOPIE}'
# AUDIO_STANDARD_SPUR='${AUDIO_STANDARD_SPUR}'
# AUDIO_VERARBEITUNG_01='${AUDIO_VERARBEITUNG_01}'
# AUDIO_VERARBEITUNG_02='${AUDIO_VERARBEITUNG_02}'
" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt

#exit 1000

#==============================================================================#
### Untertitel
#
# Multiple -c, -codec, -acodec, -vcodec, -scodec or -dcodec options specified for stream 9, only the last option '-c:s copy' will be used.
#

# -map 0:s:0 -c:s:0 copy -map 0:s:1 -c:s:1 copy		# "0" für die erste Untertitelspur
# -map 0:s:${i} -scodec copy				# alt
# -map 0:s:${i} -c:s:${i} copy				# neu
# UNTERTITEL_SPUR_SPRACHE="0,1,2,3,4"
# UNTERTITEL_SPUR_SPRACHE="0:deu,1:eng,2:spa,3:fra,4:ita"
# UNTERTITEL_SPUR_SPRACHE="0:de,1:en,2:sp,3:fr,4:it"
# NOTA_SPUR_SPRACHE="0 de
# 1 en
# 2 sp
# 3 fr
# 4 it"

if [ x = "x${NOTA_SPUR_SPRACHE}" ] ; then
	IST_UT_ANZAHL="$(echo "${NOTA_SPUR_SPRACHE}" | grep -Ev '^$' | wc -l)"
	if [ 0 -eq ${IST_UT_ANZAHL} ] ; then
		UNTERTITEL_SPUR_SPRACHE="=0"
	fi
fi

echo "# 1005
# UT_HLS='${UT_HLS}'
"

if [ "kein Text" = "${UT_HLS}" ] ; then
	U_TITEL_FF_01="-sn"
	U_TITEL_FF_02="-sn"
	UNTERTITEL_STANDARD_SPUR=""
else
    if [ "=0" = "${UNTERTITEL_SPUR_SPRACHE}" ] ; then
	U_TITEL_FF_01="-sn"
	U_TITEL_FF_02="-sn"
	UNTERTITEL_STANDARD_SPUR=""
    else
	#======================================================================#
	### STANDARD-UNTERTITEL-SPUR

	### META-Daten der Untertitel-Spuren
	DN=0
	UNTERTITEL_VERARBEITUNG_01="$(echo "${NOTA_SPUR_SPRACHE}" | nl | awk '{print $1 - 1,$2,$3}' | while read UN UB US
	do
		if [ -r "${UB}" ] ; then
			DN="$(echo "0${DN}" | awk '{print $1 + 1}')";
			echo "${DN} ${UN} ${UB} ${US}";
		else
			echo     "0 ${UN} ${UB} ${US}";
		fi ;
	done | while read DN UN UB US REST
	do
		echo "-map ${DN}:s:${UB}"
		W_US="$(echo "${US}" | wc -w)"

		if [ 1 -gt ${W_US} ] ; then
			US="$(echo "${META_DATEN_SPURSPRACHEN}" | grep -F ' subtitle ' | nl | awk '{print $1 - 1,$4}' | grep -E "^${UB} " | awk '{print $2}')"
			if [ x = "x${US}" ] ; then
				US="und"
			fi
		fi
		echo "-metadata:s:s:${UN} language=${US}"

		#----------------------------------------------------------------------#
		### externe Untertiteldateien einbinden "-i"

		#      1  7_English.srt eng
		#      2  8_English.srt eng
		D_SUB="$(echo "${NOTA_SPUR_SPRACHE}" | nl | while read XUM XUD XUS; do if [ -r "${XUD}" ] ; then echo "${XUM} ${XUD} ${XUS}"; fi ; done | nl)"
		if [ x = "x${D_SUB}" ] ; then
			echo "# 1010: Es wurden keine externen Untertitel-Dateien übergeben." >> "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt
		else
			I_SUB="$(echo "${D_SUB}" | while read XUN XUM XUD XUS REST; do echo "-i ${XUD}"; done | tr -s '\n' ' ')"
		fi

		#----------------------------------------------------------------------#

		### Die Bezeichnungen (Sprache) für die Audiospuren werden automatisch übernommen.
		if [ x = "x${UNTERTITEL_STANDARD_SPUR}" ] ; then
			### wenn nichts angegeben wurde, dann
			### Deutsch als Standard-Sprache voreinstellen
			UNTERTITEL_STANDARD_SPUR="$(echo "${NOTA_SPUR_SPRACHE}" | grep -Ei " de| ger" | awk '{print $1}' | head -n1)"

			if [ x = "x${UNTERTITEL_STANDARD_SPUR}" ] ; then
				### wenn nichts angegeben wurde
				### und es keine als deutsch gekennzeichnete Spur gibt, dann
				### STANDARD-UNTERTITEL-SPUR vom Originalfilm übernehmen
				### DISPOSITION:default=1
				UNTERTITEL_STANDARD_SPUR="$(echo "${META_DATEN_ZEILENWEISE_STREAMS}" | grep -F ';codec_type=subtitle;' | tr -s ';' '\n' | grep -F 'DISPOSITION:default=1' | grep -E 'default=[0-9]' | awk -F'=' '{print $2-1}')"
				if [ x = "x${UNTERTITEL_STANDARD_SPUR}" ] ; then
					### wenn es keine STANDARD-UNTERTITEL-SPUR im Originalfilm gibt, dann
					### alternativ einfach die erste Tonspur zur STANDARD-UNTERTITEL-SPUR machen
					UNTERTITEL_STANDARD_SPUR=0
				fi
			fi
		else
			#----------------------------------------------------------------------#
			### Die Werte für "Disposition" für die Untertitelspur werden nach dem eigenen Wunsch gesetzt.
			# -disposition:s:0 default
			# -disposition:s:1 0
			# -disposition:s:2 0

			if [ "${UN}" = "${UNTERTITEL_STANDARD_SPUR}" ] ; then
				echo "-disposition:s:${UN} default"
			else
				echo "-disposition:s:${UN} 0"
			fi
		fi
	done | tr -s '\n' ' ')"

	#----------------------------------------------------------------------#

	UT_KOPIE="$(echo "${NOTA_SPUR_SPRACHE}" | nl | awk '{print $1}')"
	UNTERTITEL_VERARBEITUNG_02="$(echo "${NOTA_SPUR_SPRACHE}" | nl | awk '{print $1 - 1,$2,$3}' | while read UN UB US
	do
		#UNTERTITEL_SPRACHE="$(echo "${NOTA_SPUR_SPRACHE}" | grep -E "^${UN} " | awk '{print $NF}' | head -n1)"

		echo "# 1020
		UNTERTITEL_VERARBEITUNG_02=' -map 0:s:${UN} -c:s:${UN} copy'
		" >> "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt

		echo "-map 0:s:${UN} -c:s:${UN} copy"
	done | tr -s '\n' ' ')"

	#----------------------------------------------------------------------#

	if [ x = "x${NOTA_SPUR_SPRACHE}" ] ; then
		UTNAME="$(echo "${META_DATEN_STREAMS}" | grep -F 'codec_type=subtitle' | nl | awk '{print $1 - 1}' | tr -s '\n' ',' | sed 's/^,//;s/,$//')"
		UT_META_DATEN="$(echo "${META_DATEN_STREAMS}" | grep -F 'codec_type=subtitle')"
		if [ "x${UT_META_DATEN}" != "x" ] ; then
			UT_LISTE="$(echo "${UT_META_DATEN}" | nl | awk '{print $1 - 1}' | tr -s '\n' ' ')"
		fi

		UT_LISTE="$(echo "${UTNAME}"      | sed 's/:[a-z]*/ /g;s/,/ /g')"
		UT_ANZAHL="$(echo "${UTNAME}"     | sed 's/,/ /g' | wc -w | awk '{print $1}')"
	else
		UT_LISTE="$(echo "${NOTA_SPUR_SPRACHE}"  | awk '{print $1}' | tr -s '\n' ' ')"
		UT_ANZAHL="$(echo "${NOTA_SPUR_SPRACHE}" | nl | tail -n1 | awk '{print $1}')"
	fi

	#----------------------------------------------------------------------#
	### Untertitel im Text-Format identifizieren

	if [ x = "x${UT_VORHANDEN}" ] ; then
		echo "# 1025
		# Es gibt in diesem Film keine Untertitel.
		" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt
		unset UT_LISTE
		unset UT_ANZAHL
		unset UT_KOPIE
		unset UT_FORMAT
		unset U_TITEL_FF_01
		unset U_TITEL_FF_02
		U_TITEL_FF_01="-sn"
		U_TITEL_FF_02="-sn"
	else
		UNTERTITEL_TEXT_CODEC="$(echo "${IST_UT_FORMAT}" | grep -Ei 'SRT|VTT|SSA|ASS|SMIL|TTML|DFXP|SBV|irc|cap|SCC|itt|DFXP|mov_text')"
		if [ x = "x${UNTERTITEL_TEXT_CODEC}" ] ; then
			#------------------------------------------------------#
			### unveränderliches Untertitelformat kann nur kopiert
			### werden oder man muß ohne Untertitel weiter arbeiten
			echo "# 1030
			# Untertitel liegen im Bild-Format vor.
			# Diese können mit diesem Skript nicht verändert werden
			# und müssen entweder kopiert werden (ffmpeg ... -c:s copy)
			# oder können nicht in den neuen Film mit übertragen werden (${0} -u =0).
			" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt

			### Film bzw. Filmteile transkodieren
			U_TITEL_FF_01="-c:s copy"
			#------------------------------------------------------#
		else
			#------------------------------------------------------#
			### Wenn der Untertitel in einem Text-Format vorliegt, dann muss er ggf. auch transkodiert werden.
			echo "# 1035
			# Untertitel liegen im Text-Format vor.
			" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt

			if [ "mp4" = "${ENDUNG}" ] ; then
				UT_FORMAT="mov_text"
			else
				UT_FORMAT="webvtt"
			fi

			### Film bzw. Filmteile transkodieren
			U_TITEL_FF_01="-c:s ${UT_FORMAT}"
			#------------------------------------------------------#
		fi

		### ffmpeg -f concat
		U_TITEL_FF_02="-c:s copy"
	fi

	echo "# 1040
	# Untertitel im Text-Format identifizieren
	# UT_VORHANDEN='${UT_VORHANDEN}'
	# UNTERTITEL_TEXT_CODEC='${UNTERTITEL_TEXT_CODEC}'
	# UT_FORMAT='${UT_FORMAT}'
	" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt
    fi
fi

echo "# 1050
# TS_LISTE='${TS_LISTE}'
#
# UT_META_DATEN='${UT_META_DATEN}'
#
# NOTA_SPUR_SPRACHE='${NOTA_SPUR_SPRACHE}'
# UT_LISTE='${UT_LISTE}'
# UT_FORMAT='${UT_FORMAT}'
# U_TITEL_FF_01='${U_TITEL_FF_01}'
# U_TITEL_FF_02='${U_TITEL_FF_02}'
# UNTERTITEL_VERARBEITUNG_01='${UNTERTITEL_VERARBEITUNG_01}'
# UNTERTITEL_VERARBEITUNG_02='${UNTERTITEL_VERARBEITUNG_02}'
#
# AUDIO_STANDARD_SPUR='${AUDIO_STANDARD_SPUR}'
" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt

#exit 1060

#==============================================================================#
### Video-Qualität

case "${BILDQUALIT}" in
	0)
		VIDEOQUALITAET="${VIDEO_QUALITAET_0}"
		;;
	1)
		VIDEOQUALITAET="${VIDEO_QUALITAET_1}"
		;;
	2)
		VIDEOQUALITAET="${VIDEO_QUALITAET_2}"
		;;
	3)
		VIDEOQUALITAET="${VIDEO_QUALITAET_3}"
		;;
	4)
		VIDEOQUALITAET="${VIDEO_QUALITAET_4}"
		;;
	5)
		VIDEOQUALITAET="${VIDEO_QUALITAET_5}"
		;;
	6)
		VIDEOQUALITAET="${VIDEO_QUALITAET_6}"
		;;
	7)
		VIDEOQUALITAET="${VIDEO_QUALITAET_7}"
		;;
	8)
		VIDEOQUALITAET="${VIDEO_QUALITAET_8}"
		;;
	9)
		VIDEOQUALITAET="${VIDEO_QUALITAET_9}"
		;;
esac

#------------------------------------------------------------------------------#
# Transkodierung
#
# vor PAD muss eine Auflösung, die der Originalauflösung entspricht, die aber
# für quadratische Pixel ist;
# oder man muss die Seitenverhältnisse für FFmpeg um den gleichen Wert verzerren,
# wie die Bildpunkte im Quell-Film;
# hinter PAD muss dann die endgültig gewünschte Auflösung für quadratische Pixel
# stehen
#
if [ "Ja" = "${TEST}" ] ; then
	if [ x = "x${CROP}" ] ; then
		VIDEOOPTION="$(echo "${VIDEOQUALITAET}" | sed 's/[,]$//')"
	else
		VIDEOOPTION="$(echo "${VIDEOQUALITAET} -vf ${CROP}${BILD_DREHUNG}" | sed 's/[,]$//;s/[,][,]/,/g')"
	fi
else
	if [ x = "x${ZEILENSPRUNG}${CROP}${HLS_SCALE}${PAD}${BILD_SCALE}${h263_BILD_FORMAT}${FORMAT_ANPASSUNG}" ] ; then
		VIDEOOPTION="$(echo "${VIDEOQUALITAET}" | sed 's/[,]$//')"
	else
		VIDEOOPTION="$(echo "${VIDEOQUALITAET} -vf ${ZEILENSPRUNG}${CROP}${HLS_SCALE}${PAD}${BILD_SCALE}${h263_BILD_FORMAT}${FORMAT_ANPASSUNG}${BILD_DREHUNG}" | sed 's/[,]$//;s/[,][,]/,/g')"
	fi
fi

#------------------------------------------------------------------------------#

SCHNITT_ANZAHL="$(echo "${SCHNITTZEITEN}" | wc -w | awk '{print $1}')"

#------------------------------------------------------------------------------#

echo "# 1090
# SCHNITTZEITEN='${SCHNITTZEITEN}'
# SCHNITT_ANZAHL='${SCHNITT_ANZAHL}'
#
# TS_LISTE='${TS_LISTE}'
# TS_ANZAHL='${TS_ANZAHL}'
#
# BILDQUALIT='${BILDQUALIT}'
# VIDEOCODEC='${VIDEOCODEC}'
# VIDEOQUALITAET='${VIDEOQUALITAET}'
#
# AUDIO_VERARBEITUNG_01='${AUDIO_VERARBEITUNG_01}'
# AUDIO_VERARBEITUNG_02='${AUDIO_VERARBEITUNG_02}'
#
# VIDEOOPTION='${VIDEOOPTION}'
# FORMAT='${FORMAT}'
# START_ZIEL_FORMAT='${START_ZIEL_FORMAT}'
" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt

#exit 1100

#set -x

#------------------------------------------------------------------------------#
#------------------------------------------------------------------------------#
#------------------------------------------------------------------------------#
### Wenn Audio- und Video-Spur nicht synchron sind,
### dann muss das korrigiert werden.

if [ x = "x${VIDEO_SPAETER}" ] ; then
	unset VIDEO_DELAY
else
	VIDEO_DELAY="-itsoffset ${VIDEO_SPAETER}"
fi

if [ x = "x${AUDIO_SPAETER}" ] ; then
	unset VIDEO_DELAY
else
	VIDEO_DELAY="-itsoffset -${AUDIO_SPAETER}"
fi

#------------------------------------------------------------------------------#
#--- Video --------------------------------------------------------------------#
#------------------------------------------------------------------------------#
#------------------------------------------------------------------------------#
### Bei VCD und DVD
### werden die Codecs nicht direkt angegeben

CODEC_ODER_TARGET="$(echo "${VIDEOCODEC}" | grep -F -- '-target ')"
if [ x = "x${CODEC_ODER_TARGET}" ] ; then
	VIDEO_PARAMETER_TRANS="-map 0:v:0 -c:v ${VIDEOCODEC} ${VIDEOOPTION}"
else
	VIDEO_PARAMETER_TRANS="-map 0:v:0 ${VIDEOCODEC} ${VIDEOOPTION}"
fi

VIDEO_PARAMETER_KOPIE="-map 0:v:0 -c:v copy"

if [ "0" = "${VIDEO_NICHT_UEBERTRAGEN}" ] ; then
	VIDEO_PARAMETER_TRANS="-vn"
	VIDEO_PARAMETER_KOPIE="-vn"
	U_TITEL_FF_01="-sn"
	U_TITEL_FF_02="-sn"
fi

#------------------------------------------------------------------------------#
#------------------------------------------------------------------------------#
#------------------------------------------------------------------------------#
### Funktionen

#------------------------------------------------------------------------------#
# Es wird nur ein einziges Stück transkodiert
transkodieren_1_1()
{
	### 1001
	pwd
	echo "# 1110
	${PROGRAMM} ${FFMPEG_OPTIONEN} ${VIDEO_DELAY} ${KOMPLETT_DURCHSUCHEN} ${REPARATUR_PARAMETER} -i \"${FILMDATEI}\" ${I_SUB} ${VIDEO_PARAMETER_TRANS} ${AUDIO_VERARBEITUNG_01} ${U_TITEL_FF_01} ${UNTERTITEL_VERARBEITUNG_01} ${FPS} ${SCHNELLSTART} ${METADATEN_TITEL}\"${EIGENER_TITEL}\" ${METADATEN_BESCHREIBUNG}'${KOMMENTAR}' ${START_ZIEL_FORMAT} -y \"${ZIELVERZ}\"/\"${ZIEL_FILM}\".${ENDUNG}"

	${PROGRAMM} ${FFMPEG_OPTIONEN} ${VIDEO_DELAY} ${KOMPLETT_DURCHSUCHEN} ${REPARATUR_PARAMETER} -i "${FILMDATEI}" ${I_SUB} ${VIDEO_PARAMETER_TRANS} ${AUDIO_VERARBEITUNG_01} ${U_TITEL_FF_01} ${UNTERTITEL_VERARBEITUNG_01} ${FPS} ${SCHNELLSTART} ${METADATEN_TITEL}"${EIGENER_TITEL}" ${METADATEN_BESCHREIBUNG}"${KOMMENTAR}" ${START_ZIEL_FORMAT} -y "${ZIELVERZ}"/"${ZIEL_FILM}".${ENDUNG} >> "${ZIELVERZ}"/${PROTOKOLLDATEI}.out 2>&1 && WEITER=OK || WEITER=Fehler
	echo "# 1140
	WEITER='${WEITER}'
	"
}

#------------------------------------------------------------------------------#
# Es werden mehrere Teile aus dem Original transkodiert und am Ende zu einem Film zusammengesetzt
transkodieren_4_1()
{
	### 1004
	pwd
	echo "# 1230
        ${PROGRAMM} ${FFMPEG_OPTIONEN} ${VIDEO_DELAY} ${KOMPLETT_DURCHSUCHEN} ${REPARATUR_PARAMETER} -i \"${FILMDATEI}\" ${I_SUB} ${VIDEO_PARAMETER_TRANS} ${AUDIO_VERARBEITUNG_01} ${U_TITEL_FF_01} ${UNTERTITEL_VERARBEITUNG_01} -ss ${VON} -to ${BIS} ${FPS} ${METADATEN_TITEL}\"${EIGENER_TITEL}\" ${METADATEN_BESCHREIBUNG}\"${KOMMENTAR}\" ${START_ZIEL_FORMAT} -y \"${ZIELVERZ}\"/${ZUFALL}_${NUMMER}_\"${ZIEL_FILM}\".${ENDUNG}"

        ${PROGRAMM} ${FFMPEG_OPTIONEN} ${VIDEO_DELAY} ${KOMPLETT_DURCHSUCHEN} ${REPARATUR_PARAMETER} -i "${FILMDATEI}" ${I_SUB} ${VIDEO_PARAMETER_TRANS} ${AUDIO_VERARBEITUNG_01} ${U_TITEL_FF_01} ${UNTERTITEL_VERARBEITUNG_01} -ss ${VON} -to ${BIS} ${FPS} ${METADATEN_TITEL}"${EIGENER_TITEL}" ${METADATEN_BESCHREIBUNG}"${KOMMENTAR}" ${START_ZIEL_FORMAT} -y "${ZIELVERZ}"/${ZUFALL}_${NUMMER}_"${ZIEL_FILM}".${ENDUNG} >> "${ZIELVERZ}"/${PROTOKOLLDATEI}.out 2>&1 && WEITER=OK || WEITER=Fehler
	echo "# 1260
	WEITER='${WEITER}'
	"
}

#------------------------------------------------------------------------------#
# Hiermit werden alle transkodierten Teile zu einem Film zusammengesetzt
transkodieren_7_1()
{
	### 1007
	# https://hatchjs.com/ffmpeg-unsafe-file-name/
	pwd
	echo "# 1350
	${PROGRAMM} ${FFMPEG_OPTIONEN} -f concat -safe 0 -i ${ZUFALL}_${PROTOKOLLDATEI}_Filmliste.txt ${I_SUB} ${VIDEO_PARAMETER_KOPIE} ${AUDIO_VERARBEITUNG_02} ${SCHNELLSTART} ${U_TITEL_FF_02} ${UNTERTITEL_VERARBEITUNG_02} ${METADATEN_TITEL}\"${EIGENER_TITEL}\" ${METADATEN_BESCHREIBUNG}'${KOMMENTAR}' ${START_ZIEL_FORMAT} -y \"${ZIEL_FILM}\".${ENDUNG}"

	${PROGRAMM} ${FFMPEG_OPTIONEN} -f concat -safe 0 -i ${ZUFALL}_${PROTOKOLLDATEI}_Filmliste.txt ${I_SUB} ${VIDEO_PARAMETER_KOPIE} ${AUDIO_VERARBEITUNG_02} ${SCHNELLSTART} ${U_TITEL_FF_02} ${UNTERTITEL_VERARBEITUNG_02} ${METADATEN_TITEL}"${EIGENER_TITEL}" ${METADATEN_BESCHREIBUNG}"${KOMMENTAR}" ${START_ZIEL_FORMAT} -y "${ZIEL_FILM}".${ENDUNG} >> ${PROTOKOLLDATEI}.out 2>&1 && WEITER=OK || WEITER=kaputt
	echo "# 1360
	WEITER='${WEITER}'
	"
}

#------------------------------------------------------------------------------#
#------------------------------------------------------------------------------#
#------------------------------------------------------------------------------#

#exit 1370
#------------------------------------------------------------------------------#
if [ ${SCHNITT_ANZAHL} -lt 1 ] ; then
	if [ ${SCHNITT_ANZAHL} -eq 1 ] ; then
		VON="-ss $(echo "${SCHNITTZEITEN}" | tr -d '"' | awk -F'-' '{print $1}')"
		BIS="-to $(echo "${SCHNITTZEITEN}" | tr -d '"' | awk -F'-' '{print $2}')"
	fi

	###------------------------------------------------------------------###
	### hier der Film transkodiert                                       ###
	###------------------------------------------------------------------###
	echo
	### 1001
	transkodieren_1_1 | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt

else

	echo '
	### 1002
	#----------------------------------------------------------------------#
	# Quelle: https://hatchjs.com/ffmpeg-unsafe-file-name/
	# unsichere Dateinamen sind Dateinamen, die folgende Eigenschaften aufweisen:
	# - Dateinamen enthalten Leerzeichen oder andere Sonderzeichen
	# - Dateinamen enthalten einen Punkt
	# - Dateinamen die mit einem "$" oder "!" enden
	# - Dateinamen die ".exe", ".bat", oder ".cmd" enthalten
	# - Dateinamen enthalten einen absoluten Pfad
	# [concat @ 0x2d36e484c000] Unsafe file name '/Test/tTt7OsNf5PJ5_01_Test.mp4'
	#----------------------------------------------------------------------#'
	# Leerzeichen will ich mal erlauben... :-)
	#echo "${ZIEL_FILM}" | grep -E '[ ]|[$]|[.]exe|[.]bat|[.]cmd' && exit 1
	echo "${ZIEL_FILM}" | grep -E '[$]|[.]exe|[.]bat|[.]cmd' && exit 1
	echo "${ZIEL_FILM}" | grep -F '!' && exit 1
	#----------------------------------------------------------------------#
	rm -f "${ZIELVERZ}"/${ZUFALL}_${PROTOKOLLDATEI}_Filmliste.txt
	NUMMER="0"
	for _SCHNITT in ${SCHNITTZEITEN}
	do
		echo "---------------------------------------------------------" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt

		NUMMER="$(echo "${NUMMER}" | awk '{printf "%2.0f\n", $1+1}' | tr -s ' ' '0')"
		VON="$(echo "${_SCHNITT}" | tr -d '"' | awk -F'-' '{print $1}')"
		BIS="$(echo "${_SCHNITT}" | tr -d '"' | awk -F'-' '{print $2}')"

		###----------------------------------------------------------###
		### hier werden die Teile zwischen der Werbung transkodiert  ###
		###----------------------------------------------------------###
		echo
		### 1004
		transkodieren_4_1 | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt

		ffprobe -v error -i "${ZIELVERZ}"/${ZUFALL}_${NUMMER}_"${ZIEL_FILM}".${ENDUNG} | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt

                ### den Film in die Filmliste eintragen
		### CONCAT akzeptiert nur Dateinamen, keine Pfadnamen:
		### [concat @ 0x2d36e484c000] Unsafe file name '/daten/mm/oeffentlich/Video/Test/tTt7OsNf5PJ5_01_Test.mp4'
                echo "echo \"file '${ZUFALL}_${NUMMER}_${ZIEL_FILM}.${ENDUNG}'\" >> \"${ZIELVERZ}\"/${ZUFALL}_${PROTOKOLLDATEI}_Filmliste.txt" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt
                echo "file '${ZUFALL}_${NUMMER}_${ZIEL_FILM}.${ENDUNG}'" >> "${ZIELVERZ}"/${ZUFALL}_${PROTOKOLLDATEI}_Filmliste.txt

		echo "---------------------------------------------------------" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt
	done

	### 1007
	echo "### 1007"
	(cd "${ZIELVERZ}"/ && transkodieren_7_1 | tee -a ${PROTOKOLLDATEI}.txt)
	echo "### 1008"

	rm -f "${ZIELVERZ}"/${ZUFALL}_*.txt

	ffprobe -v error -i "${ZIELVERZ}"/"${ZIEL_FILM}".${ENDUNG} | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt

	#ls -lh ${ZUFALL}_*.${ENDUNG}
	rm -f "${ZIELVERZ}"/${ZUFALL}_*.${ENDUNG} ffmpeg2pass-0.log

fi

#------------------------------------------------------------------------------#

ls -lh "${ZIELVERZ}"/"${ZIEL_FILM}".${ENDUNG} "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt

LAUFZEIT="$(echo "${STARTZEITPUNKT} $(date +'%s')" | awk '{print $2 - $1}')"
echo "# 1380
$(date +'%F %T') (${LAUFZEIT})" | tee -a "${ZIELVERZ}"/${PROTOKOLLDATEI}.txt

#exit 1390

