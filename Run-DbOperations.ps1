<#
.DESCRIPTION
    This script executes any number of tsql scripts in a given directory against a given database. 
    Only scripts versioned higher than the current database version will be executed

.Example
    .\Run-DbOperations.ps1 C:\sql\ScriptDir root ecs_test_db password 

.PARAMETER ScriptDirectory
    The Script directory where our tsql scripts are located

.PARAMETER DbUser
    The username we will be using to authenticate to the database

.PARAMETER DbHost
    The Database server hostname

.PARAMETER DbName
    The Database Name

.PARAMETER DbPassword
    The Database Password used for authentication
#>
param(
    [Parameter(Mandatory = $true, Position = 1)]
    [ValidateScript({Test-Path $_ })]
    [string]
    $ScriptDirectory,

    [Parameter(Mandatory = $true, Position = 2)]
    [string]
    $DbUser,

    [Parameter(Mandatory = $true, Position = 3)]
    [string]
    $DbHost,

    [Parameter(Mandatory = $true, Position = 4)]
    [string]
    $DbName,

    [Parameter(Mandatory = $true, Position = 5)]
    [string]
    $DbPassword,

    [Parameter()]
    [string]
    $WarningActionPreference = "SilentlyContinue"
)

#Validate we have the SimplySql Module installed, install and import it if not
if (!(Get-InstalledModule SimplySql)) { Install-Module SimplySql -Force }
Import-Module SimplySql

#Attempt to establish connection to Database

$securePassword = ConvertTo-SecureString $DbPassword -AsPlainText -Force
$credentialObject = New-Object System.Management.Automation.PSCredential ($DbUser, $securePassword)

$mysqlConnectionParams = @{
    Server   = $DbHost
    Database = $DbName
    Credential = $credentialObject
}

try { Open-MySqlConnection @mysqlConnectionParams }
catch { return  "Error - Establishing connection to Database $DbName on Server $DbHost" }

#Get Script files information from the Script directory
$orderedTsqlScripts = (Get-ChildItem $ScriptDirectory | ?{($_ -like "*.sql") -and ($_ -match "\d+")} | Sort Name).Name

$filesExecuted = 0
foreach ($individualScript in $orderedTSqlScripts){

    #We retrieve the Db version in this loop as the tsql scripts may update the Db, hence the need to refresh the variable with each iteration
    $dbVersion = (Invoke-SqlQuery -query "SELECT version FROM versionTable").version
    if ($null -eq $dbVersion) { return "Error - Unable to retrieve Database version"}

    #Using a regular expression to remove any non digits from the file name, so we can retrieve the version from the filename
    $individualScriptVersion = $individualScript -replace "[^0-9]" ,""


    #We will only run the tsql scripts if the filename version is higher than the current db version
    if ($individualScriptVersion -gt $dbVersion){

        #retrieve TSql script content
        $tsqlScriptContent =  Get-Content "$ScriptDirectory\$individualScript"
        #Execute script against database

        Write-Host "[Tsql Script] " -ForegroundColor Yellow -NoNewLine
        Write-Host "Executing $individualScript..." 
        $filesExecuted++
        Invoke-SqlQuery -Query $tsqlScriptContent | Out-Null

        #Update the version row with the higher filename version that was just executed
        Invoke-SqlUpdate -Query "UPDATE versionTable SET version = '$individualScriptVersion'" | Out-Null
        Write-Host "[Database Version] " -ForegroundColor Yellow -NoNewLine
        Write-Host "Updated to $individualScriptVersion" 
    }
}

Write-Host "`n[Operation Complete] - $filesExecuted scripts executed on Database $dbName." -ForegroundColor Yellow 





