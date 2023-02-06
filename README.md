# Bootstrap Token Escrow
Need picture here

This script will provide a user interface for escrowing a Bootstrap Token. This is helpful if a computer is already enrolled into an MDM but the bootstrap token is not escrowed within Jamf Pro. The script uses swiftDialog to present the dialog to the user: [https://github.com/bartreardon/swiftDialog](https://github.com/bartreardon/swiftDialog)
Need screenshot here

## Why build this
I started working with Bart's swiftDialog tool recently and saw the opportunity for this when I noticed several computers in my environment without Bootstrap Tokens escrowed into Jamf Pro. I used the same framework as my FileVault PRK Reissue script, but am now applying a workflow to escrow the bootstrap token.

Then began my task of creating a user friendly dialog for the purpose of escrowing a bootstrap token using swiftDialog...

## How to use
1. Add the Bootstrap-Token-Escrow.sh script into your Jamf Pro
2. Create a new policy in Jamf Pro, scoped to computers that need the token escrowed
3. Add the script to your policy and fill out the following parameters:
- Parameter 4: Link to a banner image
- Parameter 5: "More Information" button text
- Parameter 6: "More Information" button link
- Parameter 7: Link to icon shown in dialog
- Parameter 8: Support's contact info, in case of failure.

If the target computer doesn't have swiftDialog, the script will curl the latest version and install it before continuing. 

The policy can then be ran on the computers that need it, preferably in Self Service so they will be expecting it...

### Validated on:
- Apple Intel Mac: macOS 13.1 Ventura, macOS 12.6.2 Monterey, macOS 12.1 Monterey

Always test in your own environment before pushing to production.
