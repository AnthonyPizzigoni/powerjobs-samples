# ============================================================================#
# PowerShell script sample for coolOrange powerJobs                           #
# Creates a Excel spreadsheet with all properties of a Vault-File             #
#                                                                             #
# Copyright (c) coolOrange s.r.l. - All rights reserved.                      #
#                                                                             #
# THIS SCRIPT/CODE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER   #
# EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES #
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT.  #
# ============================================================================#

#JobEntityType = FILE

#region Settings

#Setting a new Working Directory
$workingDirectory = "C:\temp\coolOrange"

#endRegion

if (-not $IAmRunningInJobProcessor){
    Import-Module powerJobs
    OpenVaultConnection -server "localhost" -Vault "PDMC-Sample" -User "Administrator" -password ""
    $file = Get-VaultFile -Properties @{"Name" = "ISO A2 Layout ISO_TITLEA.dwg"} 
}

if (!(Test-Path $workingDirectory)) {
    New-Item -Path $workingDirectory -ItemType Directory
}

Write-Host "Starting job '$($job.Name)' for file '$($file._Name)' ..."

$excel = New-Object -ComObject excel.application 
$excel.visible = $false
$workbook = $excel.Workbooks.Add(1)
$worksheet = $workbook.Worksheets.Item(1)

if(Test-Path -Path "$workingDirectory\$($file._Name).xlsx"){
    Write-Host "Updating Excel file"
    Remove-Item -Path "$workingDirectory\$($file._Name).xlsx"
}

$file = Get-VaultFile -File $file._FullPath

$worksheet.Cells.Item(1, 1) = "Property"
$worksheet.Cells.Item(1, 2) = "Value"

$i = 2
$j = 1

foreach ($prop in $file.PSObject.Properties) {
    $worksheet.Cells.Item($i, $j) = $prop.Name
    $worksheet.Cells.Item($i, $j + 1) = $prop.Value
    $i = $i + 1
}

$workbook.SaveAs("$workingDirectory\$($file._Name).xlsx")
$workbook.Close()

Write-Host "Completed job '$($job.Name)'"