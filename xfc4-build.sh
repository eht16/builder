#!/bin/bash
#
#      xfce4-build.sh
#
#      Copyright 2006-2011 Enrico Tröger <enrico@xfce.org>
#      Copyright 2011 Christian Dywan <>
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

# (only tested with bash)

# set this to the desired prefix, e.g. /usr/local
prefix="/usr/local"
global_options="--enable-maintainer-mode --disable-debug"


# additional configure arguments for certain packages
# to add options for other packages use opts_$packagename=...
opts_libxfcegui4="--disable-gladeui --with-libglade-module-path=$prefix/libglade/2.0/"
opts_libxfce4ui="--disable-gladeui"
opts_xfwm4="--enable-startup-notification --disable-compositor --enable-randr"
opts_xfce4_session="--disable-session-screenshots --enable-libgnome-keyring"
opts_xfdesktop="--enable-thunarx --enable-exo"
opts_xfce4_panel="--enable-startup-notification"
opts_xfce_utils="--with-xsession-prefix=$prefix --disable-debug"
opts_xfce4_settings="--enable-sound-settings --enable-pluggable-dialogs"
opts_exo="--with-gio-module-dir=$prefix/lib/gio/modules"



# you should not need to change this
export PATH="$prefix/bin:$PATH"
export PKG_CONFIG_PATH="$prefix/lib/pkgconfig:$PKG_CONFIG_PATH"
BASE_DIR="`pwd`"
START_AT=""
SUDO_CMD=""


# these packages are must be available on http://git.xfce.org/
# see init() for details
xfce4_modules="\
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


log="/tmp/xfce-build.log"
elog="/tmp/xfce-ebuild.log"


function check_for_sudo()
{
	if [ ! -w "$prefix" ]
	then
		# if the user can't write into the prefix, we use sudo and hope the user
		# configured it properly
		SUDO_CMD=$(command -v sudo)
	fi
}

function run_make()
{
	if [ -x waf -a -f wscript ]
	then
		$2 ./waf $1 >>$log 2>>$elog
	else
		$2 make $1 >>$log 2>>$elog
	fi
	if [ ! "x$?" = "x0" ]
	then
		exit 1;
	fi
}

function build()
{
	# TODO basically we want to uninstall before installing again but this
	# breaks the build for xfce4-screenshooter, needs to be debugged
	#uninstall $1

	echo "====================configuring and building in $1===================="
	cd "$1"

	# configuring
	if [ ! -f Makefile -o wscript -nt .lock-wscript -o configure.ac -nt configure \
		-o configure.ac.in -nt configure -o configure.in -nt configure \
		-o configure.in.in -nt configure ]
	then
		# prepare and read package-specific options
		base_name=`basename $1`
		clean_name=`echo $base_name | sed 's/-/_/g'`
		options=`eval echo '$opts_'$clean_name`

		echo "Additional arguments for configure: $options"

		if [ -x waf -a -f wscript ]
		then
			./waf configure --prefix=$prefix $options >>$log 2>>$elog
		else
			if [ ! -x configure -o configure.ac -nt configure -o configure.ac.in -nt configure \
				-o configure.in -nt configure -o configure.in.in -nt configure ]
			then
				./autogen.sh --prefix=$prefix $global_options $options >>$log 2>>$elog
			else [ configure.ac -nt configure ]
				./configure --prefix=$prefix $global_options $options >>$log 2>>$elog
			fi
		fi
	fi
	if [ ! "x$?" = "x0" ]
	then
		exit 1;
	fi

	# building
	run_make

	# installing
	run_make install $SUDO_CMD

	cd $BASE_DIR
}

function clean()
{
	echo "====================cleaning in $1===================="
	cd "$1"
	if [ -f Makefile -o -f wscript ]
	then
		run_make clean
	fi
	cd $BASE_DIR
}

function uninstall()
{
	#~ echo "====================uninstalling in $1===================="
	cd "$1"
	if [ -f Makefile -o -f wscript ]
	then
		run_make uninstall
	fi
	cd $BASE_DIR
}

function distclean()
{
	echo "====================cleaning in $1===================="
	cd "$1"
	if [ -f Makefile -o -f wscript ]
	then
		run_make distclean
	fi
	cd $BASE_DIR
}

function update()
{
	echo "====================updating in $1===================="
	cd "$1"
	# do not pull the history, we are not interested in, we just need a checkout
	git pull --depth=1
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
		git clone --depth=1 git://git.xfce.org/$1 $1
	fi
}

# main()  ;-)

if [ "x$1" = "x" ]
then
	echo "You should enter a command. Here is a list of possible commands:"
	echo
	echo "syntax: $0 command [packages...]"
	echo
	echo "commands:"
	echo "init      - download all needed packages from the GIT server"
	echo "update    - runs 'git pull' on all package subdirectories"
	echo "clean     - runs 'make clean' on all package subdirectories"
	echo "distclean - runs 'make distclean' on all package subdirectories"
	echo "build     - runs 'configure', 'make' and 'make install' on all package subdirectories"
	echo "echo      - just prints all package modules"
	echo
	echo "The commands update, clean, build and echo takes as second argument a comma separated list of package names, e.g."
	echo "$0 build apps/midori apps/gigolo"
	echo "(this is useful if you updated all packages and there were only changes in some packages, so you don't have to rebuild all packages)"
	echo "If the second argument is omitted, the command takes all packages."
	echo
	exit 1
else
	check_for_sudo

	cmd="$1"
	shift
	if [ "$1" = "--start" ]
	then
		START_AT="$2"
		shift 2
	fi
	shift
	if [ $# -gt 0 ]
	then
		xfce4_modules="$@"
	fi
	for i in $xfce4_modules
	do
		if [ -n "$START_AT" -a "$i" != "$START_AT" ]
		then
			continue
		fi
		START_AT=""
		"$cmd" $i
	done
fi
