<#

Author: Raul Bringas <rbring01@gmail.com>
Date: 8/31/2017
Version: 1.0	

.SYNOPSIS
Windows post-configuration script to finalize the configuration of a Windows Server after imaging.

.DESCRIPTION
This script is to be run after a Windows server has been imaged, and after Preconf.ps1 has been run.
Preconf.ps1 will collect the necessary values to configure the server.  The following tasks will be 
performed by this script.

1) Identify a primary network adapter
2) Set the IP address and DNS addresses on the primary adapter
3) Set Computer Description
4) Check that remote desktop is enabled
5) Add a Domain account to local "Administrators" group
6) Update group policy Gpudate
7) Windows QA and email results

.NOTES
The variables below need to be set before running the script!

.PARAMETER $Domain
This variable needs to be set before running the script!
Example: $Domain = "domain.example.com"

.PARAMETER $NICRegEx
This variable needs to be set before running the script!
Use Get-NetAdapter to find the name of the network adapter and set the variable below accordingly.
https://technet.microsoft.com/en-us/library/jj130867(v=wps.630).aspx
Example: $NICRegEx = "Intel*"

#>

##################################
# Function Definitions           #
##################################

Function LogOutput ($FG_Color,$Log_Data){
<#
.SYNOPSIS
Function to output text to the console and log

.DESCRIPTION
Used to output information with color to the console, and also send the text to a log file with a timestamp.

.PARAMETER $FG_Color - ForeGround Text color for the console.
.PARAMETER $Log_Data - The text that is going to be logged in the log file.

#>
    # This function performs two tasks: output to console with color, output to log with timestamp
    
    $LogDate = Get-Date -Format g
    Write-Host -ForegroundColor $FG_Color $Log_Data
    
    # Populate the postconf log with current date and log message for easy troubleshooting
    Add-Content $PostconfLog "[$LogDate] $Log_Data"


}

Function OutputPostconfVars (){
<#
.SYNOPSIS
Output postconf variables.

.DESCRIPTION
Display all of the variables that will be used to configure the server.
#>
    # Output and log postconf information
    $DateTime = Get-Date -Format g
    LogOutput Yellow "--==Starting Windows Postconf script==--"
    "[$DateTime]`n"
    LogOutput Cyan "Postconf Directory: $PostconfDir"
    LogOutput Cyan "Postconf Variables: $PostconfVars"
    LogOutput Cyan "Postconf Log: $PostconfLog`n"
    LogOutput Cyan "SVR Admin Group: $SVRAdmin`n"
    LogOutput Yellow "##IP Information##"
    LogOutput Cyan "IP Address: $IP"
    LogOutput Cyan "Prefix: $Prefix"
    LogOutput Cyan "Gateway: $Gateway"
    LogOutput Cyan "Primary DNS: $DNS1"
    LogOutput Cyan "Secondary DNS: $DNS2"
    LogOutput Cyan "Computer Description: $Description`n"

}

Function SetNetIP ($IFIndex, $IP, $Prefix, $Gateway){
<#
.SYNOPSIS
Set IP address on the selected NIC.

.DESCRIPTION
Set the IP,Netmask,Gateway on a specific NIC identified by the Interface Index.

.PARAMETER $IFIndex - The interface index for the NIC
.PARAMETER $IP - IP address
.PARAMETER $Prefix - Network prefix, currently set to /24
.PARAMETER $Gateway - Gateway addres
#>
    # Set the IP address using the postconf variables
    LogOutput Cyan "Setting IP address..."
    LogOutput White "New-NetIPAddress -InterfaceIndex $IFIndex -IPAddress $IP -PrefixLength $Prefix -DefaultGateway $Gateway`n"
    
    Try {New-NetIPAddress -InterfaceIndex $IFIndex -IPAddress $IP -PrefixLength $Prefix -DefaultGateway $Gateway}
    Catch {LogOutput Red "ERROR: Unable to set IP address: IP:$IP NM:/$Prefix GW:$Gateway"}

}

Function SetNetDNS ($IFIndex, $DNS1, $DNS2){
<#
.SYNOPSIS
Set DNS addresses on the selected NIC.

.DESCRIPTION
Set the primary and secondary DNS addresses on a specific NIC identified by the Interface Index.

.PARAMETER $IFIndex - The interface index for the NIC
.PARAMETER $DNS1 - Primary DNS address
.PARAMETER $DNS2 - Secondary DNS address

#>
    # This function will set the DNS addresses on the vmxnet adapter
    LogOutput Cyan "Setting DNS addresses..."
    LogOutput White "Set-DnsClientServerAddress -InterfaceIndex $IFIndex -ServerAddresses ($DNS1, $DNS2)`n"
    
    Try {Set-DnsClientServerAddress -InterfaceIndex $IFIndex -ServerAddresses ($DNS1, $DNS2)}
    Catch {LogOutput Red "ERROR: Unable to set DNS addresses: $DNS1,$DNS2"}
	
}

Function ValidateIP ($IP_Addr){
<#    
	.SYNOPSIS – Validate an IP address.

	.DESCRIPTION – Compare the IP address entered by the user using regular expression $IPRegEx and return a valid IP.
	
	.PARAMETER $IP_Addr - IP Address provided by the user or SVR-Preconf.txt file.
#>

       If ($IP_Addr -match $IPRegEx) {
			
			# Return the user supplied IP address if it is valid
            Return $IP_Addr
         
         } Else {
				
                # If the IP is invalid, log the error and exit the program
                LogOutput Red "$InvalidIP : $IP_Addr"
                LogOutput Red "ERROR: Provide a valid IP and run the script again..."
                Exit 1

         }
}

Function SetLocalAdmin ($User){
<#
.SYNOPSIS
Add a domain user to local Administrators.

.DESCRIPTION
Adds a specific user to the local Administrators group for administrative access.

.PARAMETER $User - The domain user that will be added to local Administrators group.
#>    
    $Group = "Administrators"
    Try { net localgroup $Group "$Domain\$User" /add  }
    Catch { LogOutput Red "There was an error adding $Domain\$User to the local $Group Group!" }


}

Function SetComputerDescription ($Computer_Name){
<#
.SYNOPSIS
Set the computer description

.DESCRIPTION
Use a specific computer description to describe the server

.PARAMETER $Computer_Name - The Server Name extracted from the environment variable $ENV:COMPUTERNAME
#>        
    Try {
        
            # Use WMI to grab the Win32 OS object
            $ComputerOBJ = Get-WmiObject -Class Win32_OperatingSystem -ComputerName $Computer_Name

            # Set Computer Description
            $ComputerOBJ.Description = $Description
            $ComputerOBJ.Put() | Out-Null
            LogOutput Green "Computer Description has been set to: $ComputerDescription`n"
    }

    Catch {
            
            LogOutput Red "ERROR: There was an error setting the computer description, please set it manually!`n"
    }

}

Function CheckRDP($Host_Name){       
<#
.SYNOPSIS
Ensure RDP is enabled on the server.

.DESCRIPTION
Check to ensure RDP is enabled, if necessary make registry entries to enable RDP on the server.

.PARAMETER $Host_Name - The host name to check for RDP access
#>        
    # Registry key to enable RDP
    $RDPRegKey = reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 0 /f
    $RDPRegKey64 = "$RDPRegKey /reg:64"

    # Create a new TCP object to test for RDP connectivity
    Try {
            # Create a new socket and attempt to connect to the host via RDP default port
            $RDP_Socket = New-Object System.Net.Sockets.TCPClient($Host_Name,3389)

		    If ($RDP_Socket -eq $null){

                # This indicates that the RDP connection failed, and will be caught by the catch statement

            } Else {
                
                    # RDP connection is sucessful set output color to green
                    LogOutput Green "RDP is enabled`n"

                    # Close the socket used to test RDP
                    $RDP_Socket.Close()

            }
        }

    Catch {
    
            # RDP connection to the host failed, output the RDP status as Red
            LogOutput Red "ERROR: RDP is disabled`n"
            LogOutput Yellow "Enabling RDP...`n"
            
            # Add the registry keys to enable RDP
            $RDPRegKey
            $RDPRegKey64
            
            # Check RDP status once again after applying registry keys
            CheckRDP $Host_Name

        }

}

##################################
# Variable Declarations          #
##################################

# Computer Name using the environment variable
$ComputerName = $env:COMPUTERNAME

# CHANGE THIS TO MATCH YOUR DOMAIN!
$Domain = "YOURDOMAIN"
	
# Message for ValidateIP function
$InvalidIP = "Invalid IP address format!"

# Regular expression used to determine a valid IP address
$IPRegEx = "^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$"

# CHANGE THIS TO MATCH THE NIC IN YOUR SYSTEM USING GET-NETADAPTER!
$NICRegEx = "YOUR_NIC_NAME"

# This RegEx will match any Intel-based NIC adjust to match your environment
#$NICRegEx = "Intel*"

# This RegEx can be used on VMWare to match VMXNET3 NICs
#$NICRegEx = "vmxnet3*"

# Postconf directory, file location, and log location
$PostconfDir = "C:\Postconf\$ComputerName"
$PostconfVars = Import-Csv "$PostconfDir\$ComputerName-Postconf.txt"
$PostconfLog = "$PostconfDir\$ComputerName-Postconf_Log.txt"

# Values are populated using the $PostconfVars object created by Import-Csv
$IP = $PostconfVars.IP
$Prefix = $PostconfVars.Netmask
$Gateway = $PostconfVars.Gateway
$DNS1 = $PostconfVars.DNS1
$DNS2 = $PostconfVars.DNS2
$Description = $PostconfVars.Description

# Identify Network adapter
$Nic = Get-NetAdapter | where-object {($_.InterfaceDescription -like $NICRegEx)}

##################################
# Output postconf variables      #
##################################

# Function call to output welcome message and postconf vars
OutputPostconfVars

##################################
# Set static IP on VMXnet NIC    #
##################################

# Set the interface index for the NIC
$IFIndex = $Nic.ifIndex

# Check to ensure that IP and Gateway are in a valid. otherwise exit
$IP = ValidateIP $PostconfVars.IP
$Gateway = ValidateIP $PostconfVars.Gateway

# Check to ensure that the DNS IPs are in a valid. otherwise exit
$DNS1 = ValidateIP $PostconfVars.DNS1
$DNS2 = ValidateIP $PostconfVars.DNS2

# Call the SetNetIP function to set the IP address on the VMXnet NIC
SetNetIP $IFIndex $IP $Prefix $Gateway

# Call the SetNetDNS function to set the IP address on the VMXnet NIC
SetNetDNS $IFIndex $DNS1 $DNS2

##################################
# Set Computer Description       #
##################################
SetComputerDescription $ComputerName

##################################
# Ensure RDP is enabled          #
##################################

LogOutput Cyan "Checking to ensure RDP is enabled..."
CheckRDP $ComputerName

##################################
# Add ADMINS to Administrators   #
##################################

# Add the $ComputerName Admins group to Administrators
SetLocalAdmin "$ComputerName Admins"

##################################
# Group Policy Update            #
##################################

Gpupdate /Force
