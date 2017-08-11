<#

Author: Raul Bringas

Purpose: This script will check Windows hosts for Uptime, ICMP, and RDP connectivity.
         In addition, OS uptime, description, last patch installed, and last patch date
         information will be collected and displayed in the spreadsheet for patch verification.
         The hostnames will be collected from a text file in the "C:\Windows Update" folder.
         Test-Connection will be used to ping the hosts twice, and check RDP port 3389.
         The result of the host check will be displayed on screen, and will also be logged to CSV.
        
        Input:
        This script requires a "C:\Windows_Patching_Hostcheck" directory with text files for input.
        Make sure the directory exists before running the script. The directory should contain
        text files that have the names of all servers for each respective patching phase.
        The script will prompt you for a Phase number/name and will use the appropriate text file.     

        Output format:
        Host: hostname
        Uptime: x Days x Hours x Minutes x Seconds
        Operating System: Microsoft Windows X X
        ICMP (Up = Responding to ICMP, Down = Not Responding to ICMP)
        RDP (Up = Accessible via RDP, Down = Not accessible via RDP)

        CSV File Format:
        "$Host_Name,$OSVerCSV,$DescriptionCSV,$HostUptimeCSVD,$HostUptimeCSVH,$HostUptimeCSVM,$ICMPState,$RDPState,$DateTime,$HotFixIDCSV,$PatchDate"
        Host Name, Operating System, Description, Uptime Days, Hours, Minutes, ICMP (Up|Down), RDP (Up|Down), Script Run Time, Last HotFix Installed, Last Successful Patch Date

        Output files:
        "c:\RDP_ICMP_Uptime_Log.txt" - Formatted with the same output from the console.
        "c:\RDP_ICMP_Uptime_Log.csv" - CSV format used to sort by uptime and RDP/ICMP status.

        Examples:
        "Enter the Windows Update Phase (1,2,3,4, etc.): 1"
            -Entering "1" will kick off the script with the following text file "C:\Windows_Patching_Hostcheck\Phase1.txt"

        "Enter the Windows Update Phase (1,2,3,4, etc.): 1"
            -Entering "3Manual" will kick off the script with the following text file "C:\Windows_Patching_Hostcheck\Phase3Manual.txt"
        

Date: 7/20/2017

#>

$DateTime = Get-Date

# Working directory that contains text files with hostnames
$WorkingDir = "C:\Windows_Patching_Hostcheck"

# Check if the working directory exists, exit and prompt the user if it does not exist
If (!(Test-Path $WorkingDir)){
    
    Write-Host -ForegroundColor Red "$WorkingDir does not exist, create the directory with the appropriate text files!`n"
    Write-Host -ForegroundColor Yellow "Create $WorkingDir and place text files with hostnames in the directory ex. $WorkingDir\Phase1.txt`n"
    Exit 1
}

# Set the log paths
$LogPath = "$WorkingDir\Windows_Patching_Hostcheck"
$UptimeLog = "$LogPath.txt"


# Set the timer to pause for a specified number of time in seconds
$SleepTimer = 10800

Function ScriptMode($Run_Mode, $Hosts_Text_File) {
    # Check if the script will be run interactively
    If ($Run_Mode -like "A"){         

        
        # Remove any duplicated host names
        $HostNames = Get-Content $Hosts_Text_File | Select -uniq
        
        # Call the function to check the collected hostnames for ICMP and RDP connectivity
        CheckWindowsHosts $HostNames
                                          
    } Else {
                
                Write-Host -ForegroundColor Yellow "`nThe script will run interactively, please enter host names one at a time and press ENTER."
                CollectHostNames

            }   
             
}

Function CollectHostNames () {

    Param(     
     [parameter(Mandatory=$true,ValueFromPipeline=$true)][string[]]$HostNames
     )
     
     # Remove any duplicated host names
     $HostNames = $HostNames | Select -uniq

     # Call the function to check the collected hostnames for ICMP and RDP connectivity
     CheckWindowsHosts $HostNames
}

Function GetHostUptime ($Computer_Name){
    
    Try {
            $WMIQuery = GWMI Win32_OperatingSystem -Computer $Computer_Name
            $LBTime = $WMIQuery.ConvertToDateTime($WMIQuery.Lastbootuptime) 
            [TimeSpan]$HostUptime = New-TimeSpan $LBTime $(get-date) 

    }
    
    Catch {
    
            $HostUptime = "NA"
    }

    
    Return $HostUptime

}

Function GetHostOS ($Computer_Name){
    
    Try {
            $WMIQuery = GWMI Win32_OperatingSystem -Computer $Computer_Name
            $OSVer = $WMIQuery.Caption

            # Trim the additional ', enterprise' added from Windows caption that creates a new CSV field
            $OSVer = $OSVer.Substring(0,35)

    }
    
    Catch {
    
            $OSVer = "NA"
    }

    
    Return $OSVer

}

Function GetComputerDescription ($Computer_Name){
    
    Try {
            # Use WMI to grab the Win32 OS object, and extract computer description from the Object
            $ComputerOBJ = Get-WmiObject -Class Win32_OperatingSystem -ComputerName $Computer_Name
            $ComputerDescription = $ComputerOBJ.Description
    }

    Catch {
    
            $ComputerDescription = "NA"
    }

    Return $ComputerDescription
}

Function GetHotfixDate ($Computer_Name){
    
    Try {
            # Use Get-HotFix to grab the latest install date of Security patches
            $HotFixOBJ = Get-Hotfix -Description Security* -Computername $Computer_Name | Sort-Object
            $HotFixDate = $HotFixOBJ[($HotFixOBJ.Length - 1)].InstalledOn
            $global:HotFixID = $HotFixOBJ[($HotFixOBJ.Length - 1)].HotFixID
    }

    Catch {
    
            $HotFixDate = "NA"
            $global:HotFixID = "NA"
    }

    Return $HotFixDate
}

Function CheckWindowsHosts ($HostNames){
    
    ForEach($Host_Name in $HostNames){
        
        Write-Output "Host: $Host_Name" | Tee-Object -File $UptimeLog -append

            # Check if the host is responding to ICMP requests
            If (Test-Connection -ComputerName $Host_Name -Count 2 -Quiet){
                
                $ICMPState = "Up"
                $Host_Uptime = GetHostUptime $Host_Name
                $PatchDate = GetHotfixDate $Host_Name
                $OSVer = GetHostOS $Host_Name
                $Description = GetComputerDescription $Host_Name

                If ($Host_Uptime -eq "NA"){
                    
                    $HostUptimeCSVD = $Host_Uptime
                    $HostUptimeCSVH = $Host_Uptime
                    $HostUptimeCSVM = $Host_Uptime
                    $OSVerCSV = $Host_Uptime
                    $DescriptionCSV = $Host_Uptime
                    #$PatchDateCSV = $Host_Uptime
                    #$HotFixIDCSV = $Host_Uptime
                    Write-Output "Uptime: $Host_Uptime"
                    Write-Output "Operating System: $Host_Uptime"

                    
                } Else {
                        
                        Write-Output "Uptime: $($Host_Uptime.days) Days $($Host_Uptime.hours) Hours $($Host_Uptime.minutes) Minutes $($Host_Uptime.seconds) Seconds" | Tee-Object -File $UptimeLog -append                       
                        Write-Output "Operating System: $OSVer"
                        $HostUptimeCSVD = $Host_Uptime.days
                        $HostUptimeCSVH = $Host_Uptime.hours
                        $HostUptimeCSVM = $Host_Uptime.minutes
                        $OSVerCSV = $OSVer
                        $DescriptionCSV = $Description
                        $PatchDateCSV = $PatchDate
                        $HotFixIDCSV = $global:HotFixID

                }

                    
            } Else {
                
                    $ICMPState = "Down"
                    $HostUptimeCSVD = "NA"
                    $HostUptimeCSVH = "NA"
                    $HostUptimeCSVM = "NA"
                    $OSVerCSV = "NA"
                    $DescriptionCSV = "NA"
                    $PatchDateCSV = "NA"
                    $HotFixIDCSV = "NA"
                   
                    Write-Host -BackgroundColor Black -ForegroundColor Red "ICMP - $ICMPState"
            }    

        Write-Output "ICMP - $ICMPState" | Tee-Object -File $UptimeLog -append

    # Create a new TCP object to test for RDP connectivity
    Try {
            # Create a new socket and attempt to connect to the host via RDP default port
            $RDP_Socket = New-Object System.Net.Sockets.TCPClient($Host_Name,3389)

		    If ($RDP_Socket -eq $null){

            # This indicates that the RDP connection failed, and will be caught by the catch statement

            } Else {
                
                # RDP connection is successful set output color to green
                $RDPState = "Up"

                # Close the socket used to test RDP
                $RDP_Socket.Close()

            }
        }

    Catch {
    
        # RDP connection to the host failed, output the RDP status as Red
        $RDPState = "Down"
        Write-Host -BackgroundColor Black -ForegroundColor Red "RDP - $RDPState" 
    
        }
    
    Write-Output "RDP - $RDPState`n" | Tee-Object -File $UptimeLog -append
    Write-Output "" | Tee-Object -File $UptimeLog -append

    # Output variables in CSV friendly format
    Write-Output "$Host_Name,$OSVerCSV,$DescriptionCSV,$HostUptimeCSVD,$HostUptimeCSVH,$HostUptimeCSVM,$ICMPState,$RDPState,$DateTime,$HotFixIDCSV,$PatchDate" >> $UptimeLogCSV

    }

}

# Script run-mode
$RunMode = "A"

# Uncomment for Manual runs...
# $RunMode = Read-Host "How would you like to run the script? `nA - Automated (Using a text file with host names)`nI - Interactive (Input host name manually)`n" 

If ($RunMode -like "A") { $UpdatePhase = Read-Host "Enter the Windows Update Phase (1,2,3,4,etc.)" }

# This is the test file used for host checks based on the user's input
$HostsTextFile = "$WorkingDir\Phase$UpdatePhase.txt"

# Check if the text file the user entered exists, otherwise exit and prompt the user
If (!(Test-Path $HostsTextFile)){
    
    Write-Host -ForegroundColor Red "$HostsTextFile does not exist, create or verify the text filename!" 
    Exit 1
}

# Output the CSV data to a text file for CSV conversion
$UptimeLogCSV = "$LogPath-CSV.txt"
Write-Output "Host,OS Version,Description,Uptime: Days,Hours,Minutes,ICMP,RDP,Script Last Runtime,Latest HotFix,Last Patch Date" > $UptimeLogCSV

# Convert sleep time from seconds to minutes
$SleepMinutes = [int] $SleepTimer / 60

# Main loop will continue to run the script until terminated, and will sleep $SleepMinutes
While ($true){
    
    $DateTime = Get-Date

    Write-Output "`n##############################################################################################" | Tee-Object -File $UptimeLog -append
    Write-Output "Start Date and Time: $DateTime" | Tee-Object -File $UptimeLog -append
    Write-Output "##############################################################################################" | Tee-Object -File $UptimeLog -append
    
    ScriptMode $RunMode $HostsTextFile
    
    $EndDateTime = Get-Date    
    Write-Output "##############################################################################################" | Tee-Object -File $UptimeLog -append
    Write-Output "End Date and Time: $EndDateTime" | Tee-Object -File $UptimeLog -append
    Write-Output "##############################################################################################`n" | Tee-Object -File $UptimeLog -append
    
    Write-Host -ForegroundColor Yellow "Scan results have been saved to $LogPath-$UpdatePhase.csv in CSV format..."
    Write-Output "Waiting $SleepMinutes Minutes before checking the hosts again!`n"   

    Import-Csv $UptimeLogCSV | Export-CSV "$LogPath-$UpdatePhase.csv" -NoTypeInformation
    Sleep $SleepTimer

}
