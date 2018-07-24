Import-Module 'C:\Program Files\Microsoft Dynamics NAV\110\Service\NavAdminTool.ps1' -WarningAction SilentlyContinue | Out-Null
import-module 'C:\Program Files (x86)\Microsoft Dynamics NAV\110\RoleTailored Client\NavModelTools.ps1' -WarningAction SilentlyContinue | Out-Null
Import-Module 'C:\Program Files (x86)\Microsoft Dynamics NAV\110\RoleTailored Client\Microsoft.Dynamics.Nav.Model.Tools.psd1'  -WarningAction SilentlyContinue | Out-Null


# Script Options
$UnpublishAppBefore = $true;                 #allows to unpublish app before deployment new one
$PublishApp = $true;                           #allows to build app from VSC
$GenerateApp = $true;                         #allows to publish and install app in NAV
$ChangeAppVersion = $false,$false,$false,$true #allows to change the version of app in schema X.X.X.X only one should be true (if more then one update from left and set 0 to next parameters)
$PullMasterBranch = $true

# NAV Setup
$ServerInstance = 'DynamicsNAV110';          #defines NAV service instance
$AppName = 'ALProject1'                            #defines NAV App Name

# Folders Setup
$ProjectName  ='ALProject1'; 
$FolderForRepository = 'C:\MyALProjects\'      #defines folder where is placed the project (without project name)
$OutputPathForApp = 'C:\MyALProjects\'     #defines where the app should be exported


# Git Setup
$GitRepositoryPath = 'https://github.com/mynavblog/ALProject1'
$BranchName = 'master'
$CommitDescription = 'Version change to '

#Constants
$PackageCachePath = $ProjectPath + '.alpackages\'           #defines project alpackages folder (do not change)
$SetupFileName = $ProjectPath + 'app.json'
$ProjectPath = $FolderForRepository + $ProjectName + '\'       #defines project folder
$OutputPath = $OutputPathForApp  + $ProjectName + '.app'

#Pull Master Branch from Git
if ($PullMasterBranch) {
    cd $FolderForRepository
    Get-ChildItem -path $ProjectPath | Remove-Item -Recurse -Confirm:$false -Force -erroraction 'silentlycontinue' 
    Get-ChildItem -path $FolderForRepository -Directory -Filter $ProjectName | Remove-Item -Recurse -Confirm:$false -Force -erroraction 'silentlycontinue'
    git clone $GitRepositoryPath -b $BranchName -q
    cd $ProjectPath
    git add app.json   
}

#Change version of app (use only for development)
if ($ChangeAppVersion.Contains($true)) {
    if ($PublishApp) {
        $NewAppVersion = ChangeAppVersion
    }
}

#Unpublish app to the server
if ($UnpublishAppBefore) {
    if (Get-NAVAppInfo -ServerInstance $ServerInstance -Name $AppName) {
        Uninstall-NAVApp -ServerInstance $ServerInstance -Name $AppName   
        Unpublish-NAVApp -ServerInstance $ServerInstance -Name $AppName 
    }
}

#generanietes the app with AL compiler
if ($GenerateApp) {
    #AL Compiler Path Setup
    F:\ALLang\bin\alc.exe /project:$ProjectPath /out:$OutputPath /packagecachepath:$PackageCachePath
}

#Publish app to the server
if ($PublishApp) {
    if ($UnpublishAppBefore) {
        Publish-NAVApp -ServerInstance $ServerInstance -Path $OutputPath -SkipVerificatio -PassThru
    }
    $error.Clear()
    try {
        Install-NAVApp -ServerInstance $ServerInstance -Name $AppName -Force -erroraction 'silentlycontinue' 
    }
    catch {'not installed'}
    if ($error) {           
        Sync-NAVTenant  -ServerInstance $ServerInstance -Force
        Sync-NAVApp -ServerInstance $ServerInstance -Name $AppName
        Start-NAVAppDataUpgrade -ServerInstance $ServerInstance -Name $AppName

    }  
    if ($PullMasterBranch) {
        if ($ChangeAppVersion.Contains($true)) {
            $CommitDescriptionValue = $CommitDescription + $NewAppVersion 
            git commit -q -m $CommitDescriptionValue -- $SetupFileName 
            git push $GitRepositoryPath $BranchName -q
        }
    }
}


#function to change Version of app
function ChangeAppVersion {
    $appfile = Get-Content $SetupFileName  -raw | ConvertFrom-Json
    $ver1,$ver2,$ver3,$ver4 = $appfile.version.Split('.')
    if ($ChangeAppVersion[0]) {
        $newversionint = [int]$ver1 + 1;
        $ver1 = [string]$newversionint;
        $ver2 = '0'
        $ver3 = '0'
        $ver4 = '0'      
    } 
    else {
        if ($ChangeAppVersion[1]) {
            $newversionint = [int]$ver2 + 1;
            $ver2 = [string]$newversionint
            $ver3 = '0'
            $ver4 = '0'   
        } 
        else {
            if ($ChangeAppVersion[2]) {
                $newversionint = [int]$ver3 + 1;
                $ver3 = [string]$newversionint
                $ver4 = '0' 
            } 
            else {
                if ($ChangeAppVersion[3]) {
                    $newversionint = [int]$ver4 + 1;
                    $ver4 = [string]$newversionint
                } 
            }
        }
    }

    $newversion = $ver1 + '.' + $ver2 + '.' + $ver3 + '.' + $ver4
    $appfile.version = $newversion
    $appfile | ConvertTo-Json  | set-content $SetupFileName 
    $NewAppVersion = $newversion
    return $NewAppVersion
}
