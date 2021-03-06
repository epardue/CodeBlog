<#Creates a zip file containing the requested pending changes for the given ItemSpec from TFS
Requires 7zip and Visual Studio 2010 or greater to be installed
Examples:
#Set working directory
cd d:\code\myworkspace
#All pending changes
C:\PATHTO\Export-TFSPatch.ps1 
#Single Branch
C:\PATHTO\Export-TFSPatch.ps1 branches\ga2.8.0 -OutputFile .\TFSPatch_GA2.8.0_2014SEP01.zip
#>

[CmdletBinding()]
Param(
	[string]$ItemSpec="*", 	#See http://msdn.microsoft.com/en-us/library/56f7w6be(v=vs.100).aspx for details
	[string]$OutputFile 	#See default below
)

#Variables
$tfexe  ="C:\Program Files (x86)\Microsoft Visual Studio 10.0\Common7\IDE\TF.exe"  #Should match Visual Studio version used to setup workspace
$7zip   ="C:\Program Files\7-Zip\7z.exe"
$StripFromPath = $pwd.Path.ToLower().TrimEnd('\')+'\' 

if([string]::IsNullOrEmpty($OutputFile)){
	$OutputFile = "{0}TFSPatch_{1}.zip" -f $StripFromPath,(get-date -format 'yyyy-MM-dd_HHmmss') #default file name if not provided
}

#Get TFS details. See http://msdn.microsoft.com/en-us/library/9s5ae285.aspx for details
Write-Host "`r`nGetting list of pending changes in current workspace"  -ForegroundColor Green
Write-Host "WorkingDirectory: $StripFromPath"
Write-Host "Executing: tf.exe status $ItemSpec /format:detailed /recursive`r`n"
$TFSStatus = @(& $tfexe status $ItemSpec /format:detailed /recursive)
if($LASTEXITCODE -ne 0 -or $TFSStatus[0] -eq 'There are no pending changes.'){
	Write-Host ""
	Write-Error "Invalid workspace '$StripFromPath' or ItemSpec '$ItemSpec'. May need to update tfexe to point to 11.0 or 12.0"
	Write-Host "Result of tf.exe status command:"
	Write-Host $TFSStatus
	Write-Host ""
	exit -1
}
$LocalItems = $TFSStatus | Select-String 'Local item : \[.*\] (.*)' -AllMatches | %{$_.Matches.Groups[1].Value}
$RelativePaths = $LocalItems | %{$_.ToLower().Replace($StripFromPath,'')}

#Create Zip File. See http://www.dotnetperls.com/7-zip-examples for options
Write-Host "Creating patch file at: $OutputFile" -ForegroundColor Green
& "$7zip" a -mx3 -tzip "$OutputFile" $RelativePaths | Write-Host
if($LASTEXITCODE -ne 0){
	Write-Host ""
	throw "Error creating $OutputFile. 7Zip failed with exit code $LASTEXITCODE"
} else {
	Write-Host ""
	Write-Host "Finished creating patch file at: $OutputFile`r`n" -ForegroundColor Green
}