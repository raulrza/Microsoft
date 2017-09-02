<#
	Author: Raul Bringas <rbring01@gmail.com>
    Date: 8/31/2017
    Version: 1.0	
	
	.SYNOPSIS
	Windows pre-configuration script used to collect paramters to automatically configure the 
	server during post-configuration.
	
	.DESCRIPTION
    Pre-configuration script to be used for Windows Server provisioning.  Will either take input
    from the console in Interactive mode, or directly from a text file for automated
    multi-server runs.  The SVR-Preconf.txt file will be populated with the following fields,
    "ServerName, IP".  These values will be used to create a CSV file named after the server name
    in "C:\Postconf".  The CSV file will contain all of the following values needed
    by postconf: "ServerName, IP" NM, GW, DNS1, DNS2, Description".

    Preconf Task List:
    1) Get a list of Server Names and IPs
    2) Create computer account & admin account in AD using Server Name 
    3) Create folder with Server Name in "C:\Postconf\ServerName"
    4) Create ServerName-Postconf.txt file with postconf variables in "C:\Postconf\ServerName-Postconf.txt"
	
	.NOTES
	Input: 
    Interactive - Directly from the user in interactive mode: ServerName and IP will be collected one at a time.
    Automated -   Will pull the values directly from "C:\Postconf\SVR-Preconf.txt" CSV file.

    Ex. "C:\Postconf\SVR-Preconf.txt"
    (Server Names, and IP one per line)
    Server Name,IP
    "SQLServer01","10.10.1.2"
    "AppServer01","10.10.1.3"
    "ServerName","x.x.x.x"

    Output:
    This script will create a folder named after the Server Name that will contain a
    postconf.txt file in CSV format will all the pertinent variables for Postconf.	
	
#>

Function ScriptMode($Run_Mode) {
<#    
	.SYNOPSIS – Determine whether the user wants to run Interactive or Automated mode.

	.DESCRIPTION – Prompt the user for Interactive mode (collect input), or Automated mode (use C:\Postconf\SVR-Preconf.txt) 
					as input.
					
	.PARAMETER $Run_Mode - Either 'A' - Automated, or 'I' (any other key) - Interactive decides script run mode.
#>

	# Check if the script will be run interactively
    

    If ($Run_Mode -like "A"){         
            
        Try {$global:ServerOBJ = Import-Csv $global:PreconfTextFile}
        Catch {Write-Host -ForegroundColor Red "ERROR: There was an error accessing $global:PreconfTextFile";Exit 1}
        Write-Host -ForegroundColor Cyan "Running the script in automated mode using the values in SVR-Preconf.txt"                   

    } Else {
                
                Write-Host -ForegroundColor Yellow "`nThe script will run interactively, please enter Server Name and IP then press ENTER.`n"
                CollectPreconfInfo

            }   
             
}

Function ValidateIP ($IP_Addr){
<#    
	.SYNOPSIS – Validate an IP address.

	.DESCRIPTION – Compare the IP address entered by the user using regular expression $IPRegEx and return a valid IP.
	
	.PARAMETER $IP_Addr - IP Address provided by the user or SVR-Preconf.txt file.
#>

    # Message for ValidateIP function
    $InvalidIP = "Invalid IP address format!"

    # Regular expression used to determine a valid IP address
    $IPRegEx = "^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$"
        
    If ($IP_Addr -match $IPRegEx) {
			
        # Return the user supplied IP address if it is valid
        Return $IP_Addr
         
    } Else {
				
            # If the IP is invalid, log the error and exit the program
            Write-Host -ForegroundColor Red "$InvalidIP $IP_Addr"
            Write-Host -ForegroundColor Red "ERROR: Provide a valid IP and run the script again...`n"
            $IP_Addr = Read-Host "Enter a valid IP address"
            ValidateIP $IP_Addr

         }
}

Function CreateADAccounts ($PDC, $ServerName, $ServerOU, $AdminOU) {
<#    
	.SYNOPSIS – Create accounts in Active Directory

	.DESCRIPTION – Create a computer account for a server and a security group for local administrators.
	
	.PARAMETER $PDC - Primary Domain Controller where accounts will be created.
	.PARAMETER $ServerName - The name of the Server being provisioned.
	.PARAMETER $ServerOU - Organizatinal Unit where the computer account will reside.
	.PARAMETER $AdminOU - Organizatinal Unit where the security group for administrators will reside.
#>
	# This is the name of a group you create in Active Directory and add to the server's "Administrators" group
	$AdminGroup = "$ServerName Administrators"
    $AdminDescription = "Members have local Administrator privileges to the $ServerName"
	    
    "Server Name: $ServerName"
	"Server Admins Group Name: $AdminGroup"
    "Desc.: $AdminDescription`n"


	# Create a computer account for the specified server in the $ServerOU 
    "Creating Computer account..."
    "New-ADComputer -Name $ServerName -SamAccountName $ServerName -Path $ServerOU`n"
    Try {New-ADComputer -Name $ServerName -SamAccountName $ServerName -Path $ServerOU -Enabled $true}
    Catch {Write-Host -ForegroundColor Red "ERROR: Creation of computer account failed!"}

	# Create an admin account for the specified server in the $AdminOU
    "Creating Server Admin account..."
	"New-ADGroup -GroupScope Global -Name $AdminGroup -Description $AdminDescription  -GroupCategory Security -Path $AdminOU -Server $PDC`n"
    Try {New-ADGroup -GroupScope Global -Name $AdminGroup -Description $AdminDescription  -GroupCategory Security -Path $AdminOU -Server $PDC}
    Catch {Write-Host -ForegroundColor Red "ERROR: Creation of Server Admin account failed!"}

}

Function CollectPreconfInfo () {
 <#    
	.SYNOPSIS – Collects Server information from the user interactively.

	.DESCRIPTION – When a user chooses Interactive mode, ServerName and IP are collected from the console.
#>
   
    # Prompt the user to enter a single server name and IP        
    $ServerName = Read-Host "Enter the Server Name (Ex. SVRXX01)"
    $IP = Read-Host "Enter a valid IP address"
    $IP = ValidateIP $IP
    
    Try {Write-Output "$ServerName,$IP" >> $global:PreconfTextFile}
    Catch {Write-Host -ForegroundColor Red "ERROR: There was an error accessing $global:PreconfTextFile";Exit 1}

    $global:ServerOBJ = Import-Csv $global:PreconfTextFile

}

Function CreatePostconfFile ($Netmask, $DNS1, $DNS2, $PDC, $ServerOU, $AdminOU) {
<#    
	.SYNOPSIS – Create accounts in Active Directory

	.DESCRIPTION – Create a computer account for a server and a security group for local administrators.
	
	.PARAMETER $PDC - Primary Domain Controller where accounts will be created.
	.PARAMETER $ServerName - The name of the Server being provisioned.
	.PARAMETER $ServerOU - Organizatinal Unit where the computer account will reside.
	.PARAMETER $AdminOU - Organizatinal Unit where the security group for administrators will reside.
#>

    ForEach ($Server in $global:ServerOBJ) {
                
        # Server Object contains ServerName,IP
        $ServerName = $Server.ServerName
        $IP = $Server.IP      

        # Pre\Post conf directory, file location in SDIS
        $PreconfDir = "C:\Postconf\$ServerName"
        New-Item $PreconfDir -ItemType Directory | Out-Null


        # CSV file for each server with postconf info
        $PostConfFile = "$PreconfDir\$ServerName-Postconf.txt"

        # Add CSV columns to postconf file
        Write-Output "ServerName,IP,Netmask,Gateway,DNS1,DNS2,Description" > $PostConfFile
        
        # Set the Gateway address using the IP address from ServerOBJ
        # Split the IP address using "." as delimiter, grab the first three octets
        $IPSPlit = $IP.lastindexof(".") 
        $Network = $IP.substring(0,$IPSplit)

        # Set the gateway using the network address by appending ".1"
        # NOTE: Assumes /24
        $GW = "$Network.1"
        
        Write-Host -ForeGroundColor Green "Server Name: $ServerName"
        "IP: $IP"
        "Netmask: /$Netmask"
        "GW: $GW"
        "DNS1: $DNS1"
        "DNS2: $DNS2"
        "Description: $Description"
            
        Write-Host -ForegroundColor Cyan "Creating Text File: $ServerName-Postconf.txt...`n"

        Write-Output "$ServerName,$IP,$Netmask,$GW,$DNS1,$DNS2,$Description" >> $PostConfFile

    }


}

Function ClearPreconfFile () {
<#    
	.SYNOPSIS – Resets the Preconf file.

	.DESCRIPTION – Removes all ServerNames and IPs from SVR-Preconf.txt file for subsequent runs.
#>   
    "ServerName,IP" > $global:PreconfTextFile

}

##################################
# Variable Declarations          #
##################################

# This will allow automated runs using the SVR-Preconf.txt file or interactive runs where input gets appended from console
$global:PreconfTextFile = "C:\Postconf\SVR-Preconf.txt"

# Netmask in CIDR notation /24
$Netmask = "24"

# DNS servers
# CHANGE TO YOUR PREFERRED DNS SERVERS
$DNS1 = "4.4.4.4"
$DNS2 = "8.8.8.8"

# AD Variables
# Get the primary Domain Controller
$PDC = Get-ADDomain | Select-Object -ExpandProperty PDCEmulator

# Set path to OU in AD for each account
# CHANGE TO YOUR ACTIVE DIRECTORY PATHS BELOW
$ServerOU = "OU=YOURSERVEROU,DC=YOURDOMAIN,DC=COM"
$AdminOU = "OU=YOURADMINOU,DC=YOURDOMAIN,DC=COM"

# Create server account and server admin account for each server
CreateADAccounts $PDC $ServerName $ServerOU $AdminOU

# Set the computer description
# CHANGE TO THE DESIRED SERVER DESCRIPTION
$Description = "ENTER SERVER DESCRIPTION HERE"


##################################
# Main                           #
##################################

# Welcome message and prompt user for script run-mode
Write-Host -ForegroundColor Yellow "-== Welcome to the Windows Preconf Script ==-`n"
$RunMode = Read-Host "How would you like to run the script? `nA - Automated (Using $global:PreconfTextFile)`nI - Interactive (Input Server Name, IP manually)`n" 

# Make a call to script mode with the run mode to determine automated or interactive runs.
ScriptMode $RunMode

# Call Create postconf to create configuration files for each server in the preconf text file
CreatePostconfFile $Netmask $DNS1 $DNS2 $PDC $ServerOU $AdminOU

#Remove sever names from SVR-Preconf.txt for subsequent script runs
ClearPreconfFile
