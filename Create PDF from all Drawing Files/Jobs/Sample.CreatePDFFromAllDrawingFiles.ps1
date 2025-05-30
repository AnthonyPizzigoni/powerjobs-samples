#=============================================================================#
# PowerShell script sample for coolOrange powerJobs                           #
# Creates a PDF file and add it to Autodesk Vault as Design Vizualization     #
#                                                                             #
# Copyright (c) coolOrange s.r.l. - All rights reserved.                      #
#                                                                             #
# THIS SCRIPT/CODE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER   #
# EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES #
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT.  #
#=============================================================================#

#JobEntityType = FLDR

#region Settings

#Setting a new Working Directory
$workingDirectory = "C:\temp\coolOrange\PDF of an Item"

#endRegion
 

if (-not $IAmRunningInJobProcessor){
    Import-Module powerJobs
    OpenVaultConnection -server "localhost" -Vault "PDMC-Sample" -User "Administrator" -password ""
}

Write-Host "Starting job '$($job.Name)' ..."

if(!(Test-Path "$workingDirectory\Export")){
	New-Item -Path "$workingDirectory\Export" -ItemType Directory | Out-Null
}

$files = Get-VaultFiles -Properties  @{"File Extension"="dwg"} 
$files += Get-VaultFiles -Properties    @{"File Extension"="idw"} 
$files = $files | Where-Object { $_.'File Extension' -Match "^(idw|dwg)" } #| Select-Object -First 10

foreach ($file in $files){
	$fastOpen = $file._Extension -eq "idw" -or $file._Extension -eq "dwg" -and $files._ReleasedRevision

	$downloadedFiles = Save-VaultFile -File $file._FullPath -DownloadDirectory "$workingDirectory\Import" -ExcludeChildren:$fastOpen -ExcludeLibraryContents:$fastOpen
	$file = $downloadedFiles | Select-Object -First 1

	$localPDFfileLocation = "$workingDirectory\Export\$($file._Name).pdf"

	$openResult = Open-Document -LocalFile $file.LocalPath -Options @{ FastOpen = $fastOpen } 
	if($openResult) {
		if($openResult.Application.Name -like 'Inventor*') {
			$configFile = "$($env:POWERJOBS_MODULESDIR)Export\PDF_2D.ini"
		} else {
			$configFile = "$($env:POWERJOBS_MODULESDIR)Export\PDF.dwg" 
		}                  
		$exportResult = Export-Document -Format 'PDF' -To $localPDFfileLocation -Options $configFile

		Add-VaultFile -From $localPDFfileLocation -To $($files[0]._EntityPath + "/PDFs/" + (Split-Path -Leaf $localPDFfileLocation)) -FileClassification DesignVisualization -Hidden $false

		$closeResult = Close-Document
	}

}
	
Clean-Up -folder $workingDirectory

if(-not $openResult) {
	throw("Failed to open document $($file.LocalPath)! Reason: $($openResult.Error.Message)")
}
if(-not $exportResult) {
	throw("Failed to export document $($file.LocalPath) to $localPDFfileLocation! Reason: $($exportResult.Error.Message)")
}
if(-not $closeResult) {
	throw("Failed to close document $($file.LocalPath)! Reason: $($closeResult.Error.Message))")
}
Write-Host "Completed job '$($job.Name)'"

