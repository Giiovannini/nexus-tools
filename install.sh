#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

#!/bin/bash

DIR="$HOME/.nexustools"
UDEV="/etc/udev/rules.d/51-android.rules"
OS=$(uname)
ARCH=$(uname -m)
XCODE=0
BASEURL="https://github.com/corbindavenport/nexus-tools/raw/master"

# Nexus Tools can check if a package for ADB or Fastboot is installed, and uninstall the package if needed.
_smart_remove() {
	if [ -x "$(command -v dpkg)" ]; then # Linux systems with dpkg
		PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $1|grep "install ok installed")
		if [ "" == "$PKG_OK" ]; then # Check if relevant package is installed
			echo "[ OK ] The package '$1' is not installed, install can continue."
		else
			echo "[WARN] An outdated version of ADB or Fastboot is already installed, as part of the '$1' system package. Press ENTER to remove it or X to cancel."
			read -sn1 input
			[ "$input" = "" ] && sudo apt-get --assume-yes remove $1 && echo "[ OK ] The '$1' package was removed." || exit 1
		fi
	fi
}

# Function for copying udex.txt to proper location
_install_udev() {
	if [ -n "$UDEV" ] && [ "$OS" == "Linux" ]; then
		if [ ! -d /etc/udev/rules.d/ ]; then
			sudo mkdir -p /etc/udev/rules.d/
		fi

		local install=1

		if [ -f "$UDEV" ]; then
			sudo rm "$UDEV"
			echo "[ OK ] Udev rules are being overwritten."
		fi

		if [ $install -eq 1 ]; then

			echo "[INFO] Downloading udev list..."
			sudo curl -Lfks -o "$UDEV" "$BASEURL/udev.txt"

			output=$(sudo chmod 644 $UDEV 2>&1) && echo "[ OK ] UDEV permissions fixed." || { echo "[EROR] $output"; XCODE=1; }

			output=$(sudo chown root: $UDEV 2>&1) && echo "[ OK ] UDEV ownership fixed." || { echo "[EROR] $output"; XCODE=1; }

			sudo service udev restart 2>/dev/null >&2
			sudo killall adb 2>/dev/null >&2
		else
			echo "[INFO] Skipping UDEV..."
		fi

	fi
}

# Function for adding Nexus Tools directory to $PATH
_add_path() {
	if [ "$OS" == "Darwin" ]; then # macOS
		if [[ ":$PATH:" == *":$DIR:"* ]]; then
			# Nexus Tools directory already in $PATH
			echo "[ OK ] $DIR/ is already in PATH."
		else
			# Nexus Tools directory needs to be added to $PATH
			echo 'export PATH=$PATH:~/.nexustools' >> ~/.bash_profile
			# Refresh path
			source $HOME/.bash_profile
			echo "[ OK ] Added $DIR/ to PATH."
		fi
	elif [ "$OS" == "Linux" ]; then # Generic Linux
		if [[ ":$PATH:" == *":$DIR:"* ]]; then
			# Nexus Tools directory already in $PATH
			echo "[ OK ] $DIR/ is already in PATH."
		else
			# Nexus Tools directory needs to be added to $PATH
			PATH="$PATH:$DIR"
			echo "[ OK ] Added $DIR/ to PATH."
		fi
	fi
}

# Get sudo
echo "[INFO] Nexus Tools 4.0"
if [ "$OS" == "Linux" ]; then
	DIST=`grep DISTRIB_ID /etc/*-release | awk -F '=' '{print $2}'`
	if [ -z "${DIST##*Ubuntu*}" ] || [ -z "${DIST##*Debian*}" ]; then
		echo "[ OK ] You are running Nexus Tools on a supported platform."
	else
		echo "[WARN] Nexus Tools is only tested to work on Ubuntu Linux, but it should work on other distributions."
	fi
fi
echo "[INFO] Please enter sudo password for install."
sudo echo "[ OK ] Sudo access granted." || { echo "[ERROR] No sudo access."; exit 1; }

# Delete existing Nexus Tools installation if it exists
if [ -d $DIR ]; then
	echo "[WARN] Platform tools already installed in $DIR. press ENTER to overwrite or X to cancel."
	read -sn1 input
	[ "$input" = "" ] && rm -rf $DIR || exit 1
fi

# Make the new directory
mkdir -p $DIR

# Check if ADB or Fastboot is already installed
if [ "$OS" == "Linux" ]; then
	DIST=`grep DISTRIB_ID /etc/*-release | awk -F '=' '{print $2}'`
	# If someone wants to add support, this should work with any distro using dpkg for package management. Just change the paramteter to whatever package installs ADB/Fastboot binaries.
	if [ -z "${DIST##*Ubuntu*}" ]; then
		_smart_remove "android-tools-adb"
		_smart_remove "android-tools-fastboot"
	elif [ -z "${DIST##*Debian*}" ]; then
		_smart_remove "android-tools-adb"
		_smart_remove "android-tools-fastboot"
	else
		# For other distros, check if either adb or fastboot is installed using command
		command -v adb >/dev/null 2>&1 || { echo "[EROR] ADB is already installed and Nexus Tools cannot remove it automatically. Please manually uninstall ADB and try again." >&2; exit 1; }
		command -v fastboot >/dev/null 2>&1 || { echo "[EROR] Fastboot is already installed and Nexus Tools cannot remove it automatically. Please manually uninstall Fastboot and try again." >&2; exit 1; }
	fi
elif [ "$OS" == "Darwin" ]; then # macOS
	# For macOS, check if either adb or fastboot is installed using command
	command -v adb >/dev/null 2>&1 || { echo "[EROR] ADB is already installed and Nexus Tools cannot remove it automatically. Please manually uninstall ADB and try again." >&2; exit 1; }
	command -v fastboot >/dev/null 2>&1 || { echo "[EROR] Fastboot is already installed and Nexus Tools cannot remove it automatically. Please manually uninstall Fastboot and try again." >&2; exit 1; }
fi

# Detect operating system and install
if [ -d "/mnt/c/Windows" ]; then # Windows 10 Bash
	echo "[EROR] Bash on Windows 10 does not yet support USB devices."
	exit $XCODE
elif [ "$OS" == "Darwin" ]; then # macOS
	ZIP="https://dl.google.com/android/repository/platform-tools-latest-darwin.zip"
	# Download the ZIP file
	echo "[ .. ] Downloading platform tools for x86 Linux..."
	curl -Lfks -o "$DIR/temp.zip" "$ZIP" && echo "[ OK ] Download succeeded."|| { echo "[EROR] Download failed."; XCODE=1; }
	# Unzip it
	unzip -q -o "$DIR/temp.zip" -d "$DIR"
	# Move all files from the zip to $DIR
	mv -f -v $DIR/platform-tools/* $DIR > /dev/null
	# Delete the zip file and original folder
	rm "$DIR/temp.zip"
	rmdir "$DIR/platform-tools"
	echo "[ OK ] Platform tools now installed in $DIR."
elif [ "$OS" == "Linux" ]; then # Generic Linux
	if [ "$ARCH" == "i386" ] || [ "$ARCH" == "i486" ] || [ "$ARCH" == "i586" ] || [ "$ARCH" == "amd64" ] || [ "$ARCH" == "x86_64" ] || [ "$ARCH" == "i686" ]; then # Linux on Intel x86/x86_64 CPU
		ZIP="https://dl.google.com/android/repository/platform-tools-latest-linux.zip"
		# Download the ZIP file
		echo "[ .. ] Downloading platform tools for x86 Linux..."
		curl -Lfks -o "$DIR/temp.zip" "$ZIP" && echo "[ OK ] Download succeeded."|| { echo "[EROR] Download failed."; XCODE=1; }
		# Unzip it
		unzip -q -o "$DIR/temp.zip" -d "$DIR"
		# Move all files from the zip to $DIR
		mv -f -v $DIR/platform-tools/* $DIR > /dev/null
		# Delete the zip file and original folder
		rm "$DIR/temp.zip"
		rmdir "$DIR/platform-tools"
		echo "[ OK ] Platform tools now installed in $DIR."
	elif [ "$ARCH" == "arm" ] || [ "$ARCH" == "armv6l" ] || [ "$ARCH" == "armv7l" ]; then # Linux on ARM CPU
		echo "[EROR] Your platform does not have up-to-date binaries available. Cannot continue with installation."
		echo " "
		exit 1
	else
		echo "[EROR] Your CPU architecture could not be detected."
		echo "[EROR] Report bugs at: github.com/corbindavenport/nexus-tools/issues"
		echo "[EROR] Report the following information in the bug report:"
		echo "[EROR] OS: $OS"
		echo "[EROR] ARCH: $ARCH"
		echo " "
		exit 1
	fi
	# Download udev list
	_install_udev
	# Mark binaries in directory as executable
	chmod -f +x $DIR/*
	# Add Nexus Tools directory to path
	_add_path
	# All done!
	if [ $XCODE -eq 0 ]; then
		echo "[ OK ] Type adb or fastboot to run, you may need to open a new Terminal window for it to work."
		echo "[INFO] If you found Nexus Tools helpful, please consider donating to support development: bit.ly/donatenexustools"
	else
		echo "[EROR] Install failed."
		echo "[EROR] Report bugs at: github.com/corbindavenport/nexus-tools/issues"
		echo "[EROR] Report the following information in the bug report:"
		echo "[EROR] OS: $OS"
		echo "[EROR] ARCH: $ARCH"
	fi
	echo " "
	exit $XCODE
else
	echo "[EROR] Your operating system or architecture could not be detected."
	echo "[EROR] Report bugs at: github.com/corbindavenport/nexus-tools/issues"
	echo "[EROR] Report the following information in the bug report:"echo "[EROR] OS: $OS"
	echo "[EROR] ARCH: $ARCH"
	echo " "
	exit 1
fi
