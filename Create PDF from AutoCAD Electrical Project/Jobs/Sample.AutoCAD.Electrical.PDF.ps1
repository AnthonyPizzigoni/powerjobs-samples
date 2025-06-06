#=============================================================================#
# PowerShell script sample for coolOrange powerJobs                           #
# Creates a single multipage PDF file from an AutoCAD Electrical Project and  #
# add it to Autodesk Vault as Design Vizualization                            #
#                                                                             #
# Copyright (c) coolOrange s.r.l. - All rights reserved.                      #
#                                                                             #
# THIS SCRIPT/CODE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER   #
# EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES #
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT.  #
#=============================================================================#

#JobEntityType = FILE

#region Settings

#Setting a new Working Directory
$workingDirectory = "C:\Temp\coolOrange"

#Hides PDF
$hidePDF = $false

#endRegion

if(-not $IAmRunningInJobProcessor) {
    Import-Module powerJobs
    OpenVaultConnection -server "localhost" -Vault "PDMC-Sample" -User "Administrator" -password ""
    $file = Get-VaultFile -Properties @{ "Name" = "AutoCADElectricalProject.aepx" }
}

$localPDFfileLocation = "$workingDirectory\$($file._Name).pdf"
$vaultPDFfileLocation = $file._EntityPath +"/"+ (Split-Path -Leaf $localPDFfileLocation)

Write-Host "Starting job 'Create PDF as attachment' for file '$($file._Name)' ..."

if( @("aepx") -notcontains $file._Extension ) {
    Write-Host "Files with extension: '$($file._Extension)' are not supported"
    return
}

$downloadedFiles = Save-VaultFile -File $file._FullPath -DownloadDirectory $workingDirectory 
$file = $downloadedFiles | select -First 1

[xml]$xml = Get-Content -Path $file.LocalPath

foreach($drawing in $xml.ProjectConfiguration.Drawings.Drawing) {

    $fullFilePath = $file._FolderPath + "/" + $drawing.FilePath

    $downloadedDwg = Save-VaultFile -File $fullFilePath -DownloadDirectory $workingDirectory 
    $fileDwg = $downloadedDwg | select -First 1

    $openResult = Open-Document -LocalFile $fileDwg.LocalPath
    if($openResult) {
        $configFile = "$($env:POWERJOBS_MODULESDIR)Export\PDF.dwg" 
        $dwgPDFFullPath = "$workingDirectory\$($fileDwg._Name).pdf"

        $exportResult = Export-Document -Format 'PDF' -To $dwgPDFFullPath -Options $configFile -OnExport {
            param($export)
            $models = $export.DSDFile.Sheets | Where-Object { $_["Layout"].StartsWith("Layout") } #Sheets to EXCLUDE (valid values: Model, Layout, none)
            $models | ForEach-Object { $export.DSDFile.Sheets.Remove($_) }
        }
        
        $closeResult = Close-Document
    }

    if(-not $openResult) {
        throw("Failed to open document $($file.LocalPath)! Reason: $($openResult.Error.Message)")
    }
    if(-not $exportResult) {
        throw("Failed to export document $($file.LocalPath) to $localPDFfileLocation! Reason: $($exportResult.Error.Message)")
    }
    if(-not $closeResult) {
        throw("Failed to close document $($file.LocalPath)! Reason: $($closeResult.Error.Message))")
    }
}

$pdfFiles = Get-ChildItem $workingDirectory  -Filter "*.pdf"
MergePdf -Files $pdfFiles -DestinationFile $localPDFfileLocation -PdfSharpPath 'C:\ProgramData\coolOrange\powerJobs\Modules\PdfSharp-gdi.dll' -Force

$PDFfile = Add-VaultFile -From $localPDFfileLocation -To $vaultPDFfileLocation -FileClassification DesignVisualization -Hidden $hidePDF
$file = Update-VaultFile -File $file._FullPath -AddAttachments @($PDFfile._FullPath)

Clean-Up -folder $workingDirectory

Write-Host "Completed job 'Create PDF as attachment'"