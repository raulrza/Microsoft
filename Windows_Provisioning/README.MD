-== Windows Provisioning Automation ==-

Author: Raul Bringas <rbring01@gmail.com>
Version: 1.0

######################
## File Description ##
######################
Preconf.ps1 - This script will run before imaging a Windows server to collect the necessary information
              for post-configuation.  This script requires Server Name, and IP address to run.  It can either
              run interactively to prepare one server at a time, or automated using a list of server names and
              ip addresses.  These values will be stored in the SVR-Preconf.txt file.
              
Postconf.ps1 - After a Windows server has been imaged and the Preconf script has been run, you can use this script
               to finish the configuration.  The values needed to run this script are collected during Preconf.
               This script is fully automated and requires administrative credentials.

SVR-Preconf.txt - CSV format file that contains a list of Server Names, and IP addresses.  Used by the preconf
		              script to obtain a list of servers that are being provisioned.  This text file is written to
		              by the user or can be manually edited.  Server names and IPs will be removed after running 
		              the preconf script.

######################
## Server Folders   ##
######################
There will be several folders in the C:\Postconf directory named after servers that have been created during the
preconf phase.  Inside of these directories there will be a single CSV format file that contains all
of the variables used during server postconf ex. "ServerName,IP,Netmask,Gateway,DNS1,DNS2,Description".  There
will also be logs and QA text files showing server information and any errors during the script run.
