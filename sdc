#!/bin/bash

# Ensure locale-independent output.
LANG=C

get_dist()
{
	if [ -f /etc/os-release ]; then
		. /etc/os-release
		echo "$ID" ; return
	fi

	if [ -f /etc/system-release ]; then
		if grep -q ^Fedora /etc/system-release ; then
			echo fedora ; return
		fi
	fi

	if [ -f /etc/SuSE-release ]; then
		if grep -q ^openSUSE /etc/SuSE-release ; then
			echo opensuse
			return
		fi
	fi

	echo unknown
}

get_dist_version_id()
{
	if [ -f /etc/os-release ]; then
		. /etc/os-release
		echo "$VERSION_ID"
	fi
}

gather_x11_info()
{
	local X11D="${TMPDIR}/x11"
	mkdir "$X11D"

	cp /var/log/Xorg.0.log "$X11D" 2> /dev/null

	# Ensure the X server is reachable
	if [ -z "$DISPLAY" ]; then
		return
	fi

	xdpyinfo           > "$X11D"/xdpyinfo.txt           2>&1
	xmodmap -pm        > "$X11D"/xmodmap-pm.txt         2>&1
	xmodmap -pk        > "$X11D"/xmodmap-pk.txt         2>&1
	xinput list --long > "$X11D"/xinput_list--long.txt  2>&1
	xlsfonts -l        > "$X11D"/xlsfonts-l.txt         2>&1
	xlsfonts -ll       > "$X11D"/xlsfonts-ll.txt        2>&1
	glxinfo            > "$X11D"/glxinfo.txt            2>&1
	xdriinfo           > "$X11D"/xdriinfo.txt           2>&1
	xvinfo             > "$X11D"/xvinfo.txt             2>&1
}

gather_hw_info()
{
	local HWD="${TMPDIR}/hw"
	mkdir "$HWD"

	cp /proc/cpuinfo    "$HWD"/cpuinfo.txt
	cp /proc/interrupts "$HWD"/interrupts.txt
	cp /proc/iomem      "$HWD"/iomem.txt
	cp /proc/ioports    "$HWD"/ioports.txt
	cp /proc/meminfo    "$HWD"/meminfo.txt
	cp /proc/mtrr       "$HWD"/mtrr.txt

	lspci -vmm > "$HWD"/lspci-vmm.txt  2>&1
	dmidecode  > "$HWD"/dmidecode.txt  2>&1
	lsusb      > "$HWD"/lsusb.txt      2>&1
	lsusb -v   > "$HWD"/lsusb-v.txt    2>&1
	blkid      > "$HWD"/blkid.txt      2>&1
}

gather_nw_info()
{
	local NWD="${TMPDIR}/nw"
	mkdir "$NWD"

	ifconfig -a > "$NWD"/ifconfig-a.txt
	netstat -nr > "$NWD"/netstat-nr.txt
	iptables -L > "$NWD"/iptables-L.txt
}

gather_sw_info()
{
	local SWD="${TMPDIR}/sw"
	mkdir "$SWD"

	if [ -f /etc/os-release ]; then
		cp /etc/os-release "$SWD"
	fi

	case $(get_dist) in
		debian|ubuntu)
			apt-get check   > "$SWD"/apt-get_check.txt
			dpkg -l         > "$SWD"/dpkg-l.txt
			;;
		fedora)
			local -i _FEDORA_RELEASE
			local _PKGMGR

			_FEDORA_RELEASE=$(get_dist_version_id)
			if [ "$_FEDORA_RELEASE" -ge 22 ] ; then
				_PKGMGR="dnf"
			else
				_PKGMGR="yum"
			fi

			cp /etc/system-release "$SWD"

			rpm -qa         > "$SWD"/rpm-qa.txt
			$_PKGMGR repolist -v > "${SWD}/${_PKGMGR}_repolist-v.txt"
			$_PKGMGR history     > "${SWD}/${_PKGMGR}_history.txt"
			;;
		opensuse)
			cp /etc/SuSE-release "$SWD"

			rpm -qa		> "$SWD"/rpm-qa.txt
			zypper lr -d	> "$SWD"/zypper_repositories.txt
			;;
	esac
}

gather_kernel_info()
{
	local KD="${TMPDIR}/kernel"
	mkdir "$KD"

	cp /proc/cmdline  "$KD"
	cp /proc/slabinfo "$KD"

	uname -a  > "$KD"/uname-a.txt
	lsmod     > "$KD"/lsmod.txt
	sysctl -a > "$KD"/sysctl-a.txt
	dmesg     > "$KD"/dmesg.txt
}

collect_and_package()
{
	TMPDIR=$(mktemp -d)

	echo "Gathering system information; please wait..."
	echo
	echo -n "  Kernel:   " ; gather_kernel_info ; echo "done."
	echo -n "  Hardware: " ; gather_hw_info     ; echo "done."
	echo -n "  Software: " ; gather_sw_info     ; echo "done."
	echo -n "  Network:  " ; gather_nw_info     ; echo "done."
	echo -n "  X11:      " ; gather_x11_info    ; echo "done."

	cd "$TMPDIR"
	FILENAME="/tmp/sdc-$(hostname -s)-$(date "+%Y-%m-%d_%H:%M").tar.bz2"

	cd "$TMPDIR"

	tar cjf "$FILENAME" .
	echo
	echo "Diagnose stored in $FILENAME"

	cd - > /dev/null
	rm -rf "$TMPDIR"
}

if [[ $(id -u) != 0 ]]; then
	echo "This script must be run as root!"
	exit 1
fi

collect_and_package
