<#Applys a TFS Patch created using Export-TFSPatch. Uses TF.exe to checkout the files and 7Zip to extract the files to the specified location
Requires 7zip and Visual Studio 2010 or greater to be installed
Examples:
#Apply patch
C:\PATHTO\Apply-TFSPatch.ps1 -Path d:\code\mynewworkspace
#>

[CmdletBinding()]
Param(
	[string]$PatchFile,
	[string]$Path,
	[switch]$StopAfterReadingZip
)

#Variables
$tfexe  ="C:\Program Files (x86)\Microsoft Visual Studio 10.0\Common7\IDE\TF.exe" #Should match Visual Studio version used to setup workspace
$7zip   ="C:\Program Files\7-Zip\7z.exe"

if([string]::IsNullOrEmpty($PatchFile) -or -not (Test-Path $PatchFile)){
	Throw "Error: PatchFile '$PatchFile' is invalid."
}

if([string]::IsNullOrEmpty($Path) -or -not (Test-Path $Path)){
	Throw "Error: Path '$Path' is invalid."
}elseif ($Path.EndsWith('\')){
	$Path = $Path.TrimEnd('\');
}

#Get TFS details. See http://msdn.microsoft.com/en-us/library/9s5ae285.aspx for details
Write-Host "`r`nGetting TFS status for current workspace"  -ForegroundColor Green
Write-Host "WorkingDirectory: $pwd"
Write-Host "Executing: tf.exe status /format:brief /recursive`r`n"
$TFSStatus = @(& $tfexe status $Path /format:detailed /recursive)
if($LASTEXITCODE -ne 0){
	Write-Host ""
	Write-Error "Invalid workspace '$Path'. Path must be a valid TFS workspace."
	Write-Host "Result of tf.exe status command:"
	Write-Host $TFSStatus
	Write-Host ""
	#popd
	exit -1
}

#Extract Zip File. See http://www.dotnetperls.com/7-zip-examples for options
Write-Host "Reading patch file at: $PatchFile" -ForegroundColor Green
$ZipDetails = @(& "$7zip" l -slt $PatchFile)
if($LASTEXITCODE -ne 0){
	Write-Host ""
	throw "Error reading zip file. 7Zip failed with exit code $LASTEXITCODE and output:`r`n$ZipDetails"
}
$ZipFileNames = $ZipDetails | Select-String 'Path = (.*)' -AllMatches | %{$_.Matches.Groups[1].Value}
if($ZipFileNames.Length -lt 1){
	Write-Host ""
	throw "Error reading zip file names. 7Zip output was:`r`n$ZipDetails"
}
#Remove first entry which is the path to the zip file
#$FullFileNames = $ZipFileNames[1..$ZipFileNames.Length] | %{"$path\$_"}
$ZipFileNames = $ZipFileNames[1..$ZipFileNames.Length]

if($StopAfterReadingZip){
	throw "StopAfterReadingZip"
}

Write-Host ""
Write-Host "Checkout any required files in workspace" -ForegroundColor Green
$FilesToCheckout = @()
$FilesToAdd = @()
ForEach($item in $ZipFileNames){
	$fullname = "$path\$item"
	if([System.IO.File]::Exists($fullname)){
		if([System.IO.File]::GetAttributes($fullname) -band [System.IO.FileAttributes]::ReadOnly){
			Write-Host "      Checkout: $item"
			$FilesToCheckout += $fullname
		} else {
			Write-Host "  Add Existing: $item"
			$FilesToCheckout += $fullname
			$FilesToAdd += $fullname
		}
	} else {
		#Write-Host "  Add New File: $item" #These will be displayed below
		$FilesToAdd += $fullname
	}
}
if($FilesToCheckout.Count -gt 0){
	Write-Verbose "Starting tf.exe checkout /lock:none FILESTOCHECKOUT 2>&1"
	$TFSResult = @(& $tfexe checkout /lock:none $FilesToCheckout 2>&1) #See http://msdn.microsoft.com/en-us/library/1yft8zkw(v=vs.100).aspx
	if($LASTEXITCODE -ne 0){
		Write-Host ""
		Write-Error "Error occured during checkout. Exit code $LASTEXITCODE"
		Write-Host "`r`nResult of tf.exe checkout command:"
		Write-Host $TFSResult
		Write-Host ""
		exit -2
	}
	Write-Verbose "TF.exe Result:`r`n$TFSResult"
}

Write-Host ""
Write-Host "Extracting patch files into workspace" -ForegroundColor Green
& "$7zip" x $PatchFile "-o$Path" -y #Use x no e to include full paths
if($LASTEXITCODE -ne 0){
	Write-Host ""
	throw "Error extracting zip file. 7Zip failed with exit code $LASTEXITCODE"
}

if($FilesToAdd.Count -gt 0){
	Write-Host ""
	Write-Host "Adding new files into workspace" -ForegroundColor Green
	Write-Verbose "Starting tf.exe add /lock:none FILESTOADD /noprompt 2>&1"
	$TFSResult = @(& $tfexe add /lock:none $FilesToAdd /noprompt 2>&1) #See http://msdn.microsoft.com/en-us/library/f9yw4ea0(v=vs.100).aspx
	if($LASTEXITCODE -ne 0){
		Write-Host ""
		Write-Error "Error occured while adding files. Exit code $LASTEXITCODE"
		Write-Host "`r`nResult of tf.exe add command:"
		Write-Host $TFSResult
		Write-Host ""
		exit -2
	} else {
		Write-Verbose "TF.exe Result:`r`n$TFSResult"	
	}
}
Write-Host ""
Write-Host "Finished applying patch file. Confirm files are correct and then checking pending changes to TFS.`r`n" -ForegroundColor Green
