#!/bin/bash

# This script uses swiftDialog to present the end-user
# a prompt for their password in effort to reissue a 
# FileVault recovery key. The key is then escrowed to
# Jamf Pro. This script calls for a Jamf recon, so no need
# to add it as a maintenance payload on your policy. 
#
# Downloads and installs swiftDialog if it doesn't already
# exist on the computer.
#
# Created 02.06.2023 @robjschroeder
# Script Version: 1.0.0
# Last Modified: 02.06.2023

##################################################
# Variables -- edit as needed

# Script Version
scriptVersion="1.0.0"
# Banner image for message
banner="${4:-"https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcTRgKEFxRXAMU_VCzaaGvHKkckwfjmgGncVjA&usqp=CAU"}"
# More Information Button shown in message
infotext="${5:-"More Information"}"
infolink="${6:-"https://support.apple.com/guide/deployment/use-secure-and-bootstrap-tokens-dep24dbdcf9e/web"}"
# Swift Dialog icon to be displayed in message
icon="${7:-"/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/LockedIcon.icns"}"
supportInformation="${8:-"support@organization.com"}"
## SwiftDialog
dialogApp="/usr/local/bin/dialog"

# Messages shown to the user in the dialog when prompting for password
message="## Bootstrap token\n\nYour Bootstrap token is currently not being stored. This token is used to help keep your Mac account secure.\n\n Please enter your Mac password to store your Bootstrap token."
forgotMessage="## Bootstrap token\n\nYour Bootstrap token is currently not being stored. This token is used to help keep your Mac account secure.\n\n ### Password Incorrect please try again:"

# The body of the message that will be displayed if a failure occurs.
FAIL_MESSAGE="## Please check your password and try again.\n\nIf issue persists, please contact support: $supportInformation."

# Main dialog
dialogCMD="$dialogApp \
--title \"none\" \
--bannerimage \"$banner\" \
--message \"$message\" \
--button1text \"Submit\" \
--icon "${icon}" \
--infobuttontext \"${infotext}\" \
--infobuttonaction "${infolink}" \
--messagefont 'size=14' \
--position 'centre' \
--ontop \
--moveable \
--textfield \"Enter Password\",secure,required"

# Forgot password dialog
dialogForgotCMD="$dialogApp \
--title \"none\" \
--bannerimage \"$banner\" \
--message \"$forgotMessage\" \
--button1text \"Submit\" \
--icon "${icon}" \
--infobuttontext \"${infotext}\" \
--infobuttonaction "${infolink}" \
--messagefont 'size=14' \
--position 'centre' \
--ontop \
--moveable \
--textfield \"Enter Password\",secure,required"

# Error dialog
dialogError="$dialogApp \
--title \"none\" \
--bannerimage \"$banner\" \
--message \"$FAIL_MESSAGE\" \
--button1text \"Close\" \
--infotext \"$scriptVersion\" \
--messagefont 'size=14' \
--position 'centre' \
--ontop \
--moveable \ "

# Success Dialog
dialogSuccess="$dialogApp \
--title \"none\" \
--image \"https://github.com/unfo33/venturewell-image/blob/main/a-hand-drawn-illustration-of-thank-you-letter-simple-doodle-icon-illustration-in-for-decorating-any-design-free-vector.jpeg?raw=true\" \
--imagecaption \"Your Bootstrap token was successfully stored!\" \
--bannerimage \"$banner\" \
--button1text \"Close\" \
--infotext \"$scriptVersion\" \
--messagefont 'size=14' \
--position 'centre' \
--ontop \
--moveable \ "

#
##################################################
# Script work -- do not edit below here

# Validate swiftDialog is installed
if [ ! -e "/Library/Application Support/Dialog/Dialog.app" ]; then
	echo "Dialog not found, installing..."
	dialogURL=$(curl --silent --fail "https://api.github.com/repos/bartreardon/swiftDialog/releases/latest" | awk -F '"' "/browser_download_url/ && /pkg\"/ { print \$4; exit }")
	expectedDialogTeamID="PWA5E9TQ59"
	# Create a temp directory
	workDir=$(/usr/bin/basename "$0")
	tempDir=$(/usr/bin/mktemp -d "/private/tmp/$workDir.XXXXXX")
	# Download latest version of swiftDialog
	/usr/bin/curl --location --silent "$dialogURL" -o "$tempDir/Dialog.pkg"
	# Verify download
	teamID=$(/usr/sbin/spctl -a -vv -t install "$tempDir/Dialog.pkg" 2>&1 | awk '/origin=/ {print $NF }' | tr -d '()')
	if [ "$expectedDialogTeamID" = "$teamID" ] || [ "$expectedDialogTeamID" = "" ]; then
		/usr/sbin/installer -pkg "$tempDir/Dialog.pkg" -target /
	else
		echo "Team ID verification failed, could not continue..."
		exit 6
	fi
	/bin/rm -Rf "$tempDir"
else
	echo "Dialog v$(dialog --version) installed, continuing..."
fi

# Get the logged in user's name
userName=$(/bin/echo "show State:/Users/ConsoleUser" | /usr/sbin/scutil | /usr/bin/awk '/Name :/&&!/loginwindow/{print $3}')

## Grab the UUID of the User
userNameUUID=$(dscl . -read /Users/$userName/ GeneratedUID | awk '{print $2}')

## Get the OS build
BUILD=$(/usr/bin/sw_vers -buildVersion | awk {'print substr ($0,0,2)'})

# Exits if root is the currently logged-in user, or no logged-in user is detected.
function check_logged_in_user {
	if [ "$userName" = "root" ] || [ -z "$currentuser" ]; then
		echo "Nobody is logged in."
		exit 0
	fi
}

## This first user check sees if the logged in account is already authorized with FileVault 2
userCheck=$(fdesetup list | awk -v usrN="$userNameUUID" -F, 'match($0, usrN) {print $1}')
if [ "${userCheck}" != "${userName}" ]; then
	echo "This user is not a FileVault 2 enabled user."
	eval "$dialogError"
    exit 3
fi

## Counter for Attempts
try=0
maxTry=2

## Check to see if the bootstrap token is already escrowed
tokenCheck=$(profiles status -type bootstraptoken)
statusCheck=$(echo "${encryptCheck}" | grep "profiles: Bootstrap Token supported on server: YES
profiles: Bootstrap Token escrowed to server: YES")
expectedStatus="profiles: Bootstrap Token supported on server: YES
profiles: Bootstrap Token escrowed to server: NO"
if [ "${tokenCheck}" != "${expectedStatus}" ]; then
	echo "The bootstrap token is already escrowed."
	echo "${tokenCheck}"
	eval "$dialogSuccess"
	exit 4
fi

# Display a branded prompt explaining the password prompt.
echo "Alerting user $userName about incoming password prompt..."
userPass=$(eval "$dialogCMD" | grep "Enter Password" | awk -F " : " '{print $NF}')

# Thanks to James Barclay (@futureimperfect) for this password validation loop.
TRY=1
until /usr/bin/dscl /Search -authonly "$userName" "${userPass}" &>/dev/null; do
	(( TRY++ ))
	echo "Prompting $userName for their Mac password (attempt $TRY)..."
	userPass=$(eval "$dialogForgotCMD" | grep "Enter Password" | awk -F " : " '{print $NF}')
	if (( TRY >= 5 )); then
		echo "[ERROR] Password prompt unsuccessful after 5 attempts. Displaying \"forgot password\" message..."
		eval "$dialogError"
		exit 1
	fi
done
echo "Successfully prompted for Mac password."
echo "Escrowing bootstrap token"


result=$(expect -c "
log_user 0
spawn profiles install -type bootstraptoken
expect \"Enter the admin user name:\"
send {${userName}}
send \r
expect \"Enter the password for user '${userName}':\"
send {${userPass}}
send \r
log_user 1
expect eof
" >> /dev/null)

# Check to ensure token was escrowed
tokenCheck=$(profiles status -type bootstraptoken)
statusCheck=$(echo "${encryptCheck}" | grep "profiles: Bootstrap Token supported on server: YES
profiles: Bootstrap Token escrowed to server: YES")
expectedStatus="profiles: Bootstrap Token supported on server: YES
profiles: Bootstrap Token escrowed to server: YES"
if [ "${tokenCheck}" = "${expectedStatus}" ]; then
	echo "Bootstrap token escrowed for $userName"
	eval "$dialogSuccess"
	exit 0
fi
eval "$dialogError"
exit 4
