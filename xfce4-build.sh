#!/bin/bash
#
#      xfce4-build.sh
#
#      Copyright 2006-2011 Enrico Tröger <enrico@xfce.org>
#      Copyright 2011 Christian Dywan <christian@twotoasts.de>
#
#      This program is free software; you can redistribute it and/or modify
#      it under the terms of the GNU General Public License as published by
#      the Free Software Foundation; either version 2 of the License, or
#      (at your option) any later version.
#
#      This program is distributed in the hope that it will be useful,
#      but WITHOUT ANY WARRANTY; without even the implied warranty of
#      MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#      GNU General Public License for more details.
#
#      You should have received a copy of the GNU General Public License
#      along with this program; if not, write to the Free Software
#      Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#

# TODOs:
# - evaluate a new environment variable to skip certain packages
# - fix uninstall
# - improve git cleaning (gc, prune)


# (only tested with bash)

# Autotools-only options passed to all modules
GLOBAL_OPTIONS="--enable-maintainer-mode --disable-debug"
# you should not need to change this
BASE_DIR="`pwd`"
START_AT=""
if [ "x$PREFIX" == "x" ]; then
	PREFIX="$BASE_DIR/install"
	export PREFIX
fi
if [ "x$BUILDIT" == "x" ]; then
	# assume buildit is in the PATH
	BUILDIT="buildit"
	export BUILDIT
fi



# additional configure arguments for certain packages
# to add options for other packages use OPTIONS_$packagename=...
OPTIONS_libxfcegui4="--disable-gladeui --with-libglade-module-path=$PREFIX/libglade/2.0"
OPTIONS_libxfce4ui="--disable-gladeui"
OPTIONS_xfwm4="--enable-startup-notification --disable-compositor --enable-randr"
OPTIONS_xfce4_session="--disable-session-screenshots --enable-libgnome-keyring"
OPTIONS_xfdesktop="--enable-thunarx --enable-exo"
OPTIONS_xfce4_panel="--enable-startup-notification"
OPTIONS_xfce_utils="--with-xsession-prefix=$PREFIX --disable-debug"
OPTIONS_xfce4_settings="--enable-sound-settings --enable-pluggable-dialogs"
OPTIONS_libxfce4uis_exo="--with-gio-module-dir=$PREFIX/lib/gio/modules"




# these packages are must be available on http://git.xfce.org/
# see init() for details
XFCE4_MODULES="\
xfce/xfce4-dev-tools \
xfce/libxfce4util \
xfce/xfconf \
xfce/libxfcegui4 \
xfce/libxfce4ui \
xfce/exo \
xfce/gtk-xfce-engine \
xfce/garcon \
xfce/thunar \
xfce/xfce4-panel \
xfce/xfce4-appfinder \
xfce/xfce4-session \
xfce/xfce4-settings \
xfce/xfce-utils \
xfce/xfdesktop \
xfce/xfwm4 \
xfce/tumbler \
xfce/thunar-volman \
xfce/xfce4-power-manager \
bindings/xfce4-vala \
apps/gigolo \
apps/midori \
apps/mousepad \
apps/orage \
apps/parole \
apps/ristretto \
apps/terminal \
apps/xfburn \
apps/xfce4-dict \
apps/xfce4-mixer \
apps/xfce4-notifyd \
apps/xfce4-screenshooter \
apps/xfce4-taskmanager \
art/xfce4-icon-theme \
panel-plugins/xfce4-clipman-plugin \
panel-plugins/xfce4-cpufreq-plugin \
panel-plugins/xfce4-datetime-plugin \
panel-plugins/xfce4-netload-plugin \
panel-plugins/xfce4-notes-plugin \
panel-plugins/xfce4-radio-plugin \
panel-plugins/xfce4-sensors-plugin \
panel-plugins/xfce4-systemload-plugin \
"


if [ "x$LOG" == "x" ]; then
	LOG="/dev/stdout"
fi
if [ "x$ERROR_LOG" == "x" ]; then
	ERROR_LOG="/dev/stderr"
fi

function echo_and_log()
{
	PRETTYLINE="======= $2 $1 ======="
	echo $PRETTYLINE
	if [ "x$LOG" != "x/dev/stdout" ]; then
		echo "" >>$LOG
		echo $PRETTYLINE >>$LOG
		echo "" >>$LOG
	fi
	if [ "x$ERROR_LOG" != "x/dev/stderr" ]; then
		echo "" >>$ERROR_LOG
		echo $PRETTYLINE >>$ERROR_LOG
		echo "" >>$ERROR_LOG
	fi
}

function build_error()
{
	echo Build failed! To continue from here, run:
	echo `basename $0` build --start "$1"
	exit 1
}

function build()
{
	# TODO basically we want to uninstall before installing again but this
	# breaks the build for xfce4-screenshooter, needs to be debugged
	#uninstall $1

	echo_and_log "Configuring and building in $1" "$2"
	cd "$1"

	# prepare and read package-specific options
	base_name=`basename $1`
	clean_name=`echo $base_name | sed 's/-/_/g'`
	options=`eval echo '$OPTIONS_'$clean_name`
	if [ -f configure.in -o -f configure.ac ]; then
		options="$GLOBAL_OPTIONS $options"
	fi

	# building
	# FIXME: xfce4-dev-tools autogen without xfce4-dev-tools is broken
	"$BUILDIT" install $options >>$LOG 2>>$ERROR_LOG || build_error $1

	cd $BASE_DIR
}

function clean()
{
	echo_and_log "Cleaning in $1" "$2"
	cd "$1"
		"$BUILDIT" clean >>$LOG 2>>$ERROR_LOG || exit 1
	cd $BASE_DIR
}

function uninstall()
{
	#~ echo_and_log "Uninstalling in $1" "$2"
	cd "$1"
		"$BUILDIT" uninstall >>$LOG 2>>$ERROR_LOG || exit 1
	cd $BASE_DIR
}

function distclean()
{
	echo_and_log "Cleaning in $1" "$2"
	cd "$1"
	if [ -x waf -a -f wscript ]; then
		./waf distclean >>$LOG 2>>$ERROR_LOG || exit 1
	else
		make distclean >>$LOG 2>>$ERROR_LOG || exit 1
	fi
	cd $BASE_DIR
}

function update()
{
	echo_and_log "Updating in $1" "$2"
	cd "$1"
	# do not pull the history, we are not interested in, we just need a checkout
	git pull
	# auto cleanup the repository
	# TODO make this less aggressive
	git gc
	git prune
	cd $BASE_DIR
}

function init()
{
	if [ ! -d "$1" ]
	then
		echo_and_log "Cloning $1" "$2"
		git clone --depth=1 git://git.xfce.org/$1 $1
	fi
}

# main()  ;-)

if [ "x$1" = "x" -o "x$1" = "xhelp" ]
then
	echo "You should enter a command. Here is a list of possible commands:"
	echo
	echo "Usage:"
	echo " " `basename $0` "command [packages...]"
	echo
	echo "commands:"
	echo "init      - downloads all needed packages from the GIT server"
	echo "update    - runs 'git pull' on all package subdirectories"
	echo "clean     - runs 'make clean' on all package subdirectories"
	echo "distclean - runs 'make distclean' on all package subdirectories"
	echo "build     - runs 'configure', 'make' and 'make install' on all package subdirectories"
	echo "echo      - just prints all package modules"
	echo "help      - shows this help screen"
	echo
	echo "The commands update, clean, build and echo take as second argument a comma separated list of package names, e.g."
	echo "$0 build apps/midori apps/gigolo"
	echo "(this is useful if you updated all packages and there were only changes in some packages, so you don't have to rebuild all packages)"
	echo "If the second argument is omitted, the command takes all packages."
	echo
	exit 1
else
	cmd="$1"
	shift
	case $cmd in
		init|update|clean|distclean|build|uninstall|echo)
			;;
		*)
			echo '"'$cmd'"' is not a known command
			exit 1
			;;
	esac
	if [ "$1" = "--start" ]
	then
		START_AT="$2"
		shift 2
	fi
	shift
	if [ $# -gt 0 ]
	then
		XFCE4_MODULES="$@"
	fi

	XFCE4_MODULES_A=( $XFCE4_MODULES )
	COUNT=${#XFCE4_MODULES_A[@]}
	INDEX=0
	for i in $XFCE4_MODULES
	do
		let INDEX+=1
		if [ -n "$START_AT" -a "$i" != "$START_AT" ]
		then
			continue
		fi
		START_AT=""
		# FIXME: Allow multiple skip packages
		case $SKIP in $i)
			echo_and_log "Skipping $i" "$INDEX/$COUNT"
			continue
			;;
		esac
		"$cmd" $i "$INDEX/$COUNT"
	done
fi
