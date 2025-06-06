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

#JobEntityType = FILE

#region Settings
#Valid values: Model, Layout, none
$excludeModelOrLayout = "Model"

#Hides PDF
$hidePDF = $false
#endRegion

if (-not $IAmRunningInJobProcessor){
    Import-Module powerJobs
    OpenVaultConnection -server "localhost" -Vault "PDMC-Sample" -User "Administrator" -password ""
    $file = Get-VaultFile -Properties @{"Name" = "ISO A2 Layout ISO_TITLEA.dwg"} 
}


$localPDFfileLocation = "$workingDirectory\$($file._Name).pdf"
$vaultPDFfileLocation = $file._EntityPath +"/"+ (Split-Path -Leaf $localPDFfileLocation)
$fastOpen = $file._Extension -eq "idw" -or $file._Extension -eq "dwg" -and $file._ReleasedRevision

Write-Host "Starting job '$($job.Name)' for file '$($file._Name)' ..."

if( @("idw","dwg") -notcontains $file._Extension ) {
    Write-Host "Files with extension: '$($file._Extension)' are not supported"
    return
}

$downloadedFiles = Save-VaultFile -File $file._FullPath -DownloadDirectory $workingDirectory -ExcludeChildren:$fastOpen -ExcludeLibraryContents:$fastOpen
$file = $downloadedFiles | Select-Object -First 1
$openResult = Open-Document -LocalFile $file.LocalPath -Options @{ FastOpen = $fastOpen } 

if($openResult) {
    if($openResult.Application.Name -eq 'Inventor') {
        $configFile = "$($env:POWERJOBS_MODULESDIR)Export\PDF_2D.ini"
		$exportResult = Export-Document -Format 'PDF' -To $localPDFfileLocation -Options $configFile
    } else {
        $configFile = "$($env:POWERJOBS_MODULESDIR)Export\PDF.dwg"
		$exportResult = Export-Document -Format 'PDF' -To $localPDFfileLocation -Options $configFile -OnExport {
            param($export)
            $models = $export.DSDFile.Sheets | Where-Object { $_["Layout"].StartsWith($excludeModelOrLayout) }
            $models | ForEach-Object { $export.DSDFile.Sheets.Remove($_) }
        }
    }                  
    
    if($exportResult) {       
        $PDFfile = Add-VaultFile -From $localPDFfileLocation -To $vaultPDFfileLocation -FileClassification DesignVisualization -Hidden $hidePDF
        $file = Update-VaultFile -File $file._FullPath -AddAttachments @($PDFfile._FullPath) -Comment "PDF file added"    
    }
    $closeResult = Close-Document
}

Clean-Up -folder $workingDirectory

if(-not $openResult) {
    throw("Failed to open document $($file.LocalPath)! Reason: $($openResult.ErrorMessage)")
}
if(-not $exportResult) {
    throw("Failed to export document $($file.LocalPath) to $localPDFfileLocation! Reason: $($exportResult.ErrorMessage)")
}
if(-not $closeResult) {
    throw("Failed to close document $($file.LocalPath)! Reason: $($closeResult.ErrorMessage))")
}
Write-Host "Completed job '$($job.Name)'"