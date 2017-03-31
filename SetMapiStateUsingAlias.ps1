#A CSV with email addresses in a field named "EMAIL ADDRESS" is needed as input

# Set the path to the CSV input file with Exchange user info including EMAIL ADDRESS
$MAPIUsersCSVPath = “C:\Exchange\UserEmails.csv”

# Set the path for the CSV output file that will contain all user mailbox aliases
$MAPIUserAliasPath = "C:\Exchange\MAPIUserAliases.csv"

# Set the path for the output file that will log the results of MAPI settings per user
$MAPIHttpResults = “C:\Exchange\MAPIHttpResults.txt”

# Object used to store all information imported from CSV
$ExchangeUserInfo = Import-CSV $MAPIUsersCSVPath

Function SetMAPIState ($User_Alias, $State) {
	
	Write-Host "Enabling MAPI over HTTP for: $User_Alias"
    
    Try {
         # Attempt to enable/disable MapiHTTP for one user at a time
         Set-CASMailbox $userAlias -MapiHttpEnabled $State      
         Write-Host -ForegroundColor Green "MAPI over HTTP enabled for $User_Alias.`n"
         Write-Output "MAPI over HTTP enabled for $User_Alias.`n" >> $MAPIHttpResults
            
    } Catch {
            
            # There was an issue enabling MapiHTTP for the user, log the error
            Write-Host -ForegroundColor Red "There was an error enabling MAPI over HTTP for $User_Alias.`n"
            Write-Output "There was an error enabling MAPI over HTTP for $userAlias.`n" >> $MAPIHttpResults

    }
	# Enable/Disable MAPI using mailbox alias
	Set-CASMailbox $User_Alias -MapiHttpEnabled $State
	
}

ForEach ($UserObj in $ExchangeUserInfo){
    
    # Extract the email address from user object labelled "EMAIL ADDRESS" in CSV
    $EmailAddress = $($UserObj."EMAIL ADDRESS")

    # Use the email address extracted above to determine mailbox alias
    $UserAliasObj = Get-Mailbox $EmailAddress | Select Alias
    
    # Extract the Alias from the User Alias Object
    $UserAlias = $($UserAliasObj."Alias")

    # Save all user mailbox aliases to csv
    $UserAlias >> $MAPIUserAliasPath

    # Display user email and mailbox alias
    Write-host "User Email is: $EmailAddress"
    Write-host "Mailbox alias is: $UserAlias`n"

    # Call the SetMAPIEnabled function to enable/disable MAPI for each user with $true or $false
    SetMAPIState $UserAlias $true

}
