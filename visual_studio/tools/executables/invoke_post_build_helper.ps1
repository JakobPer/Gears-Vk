$exeName = "cgb_post_build_helper.exe"
$postBuildExePath = Join-Path -Path $PSScriptRoot -ChildPath $exeName
$taskbarDllName = "Hardcodet.Wpf.TaskbarNotification.dll"
$taskbarDllPath = Join-Path -Path $PSScriptRoot -ChildPath $taskbarDllName

# Check if the tool is available:
if ((-Not (Test-Path $postBuildExePath)) -or (-Not (Test-Path $taskbarDllPath)))
{
	if ($args[0].ToLower() -eq "-msbuild" -and $args.Length -gt 2) 
	{
		try 
		{
			$msbuildPath = Join-Path -Path $args[1] -ChildPath "MSBuild.exe" 
			$nugetPath = Join-Path -Path $PSScriptRoot -ChildPath "nuget.exe"
			$postBuildSlnPath = Join-Path -Path $PSScriptRoot -ChildPath "..\sources\cgb_post_build_helper\cgb_post_build_helper.sln"
			Write-Output "$exeName or $taskbarDllName not found => going to build Post Build Helper it from $postBuildSlnPath ..."
			Write-Output ""
			Write-Output "Note 1: If the build takes too long (more than 10 sec.), please cancel it (Build -> Cancel) and build again."
			Write-Output "Note 2: If the build fails, please open '$postBuildSlnPath' and build the C# project manually (just select the 'Release' configuration and build)."
			Write-Output ""
			Write-Output "First, restoring NuGet packages ... (Please allow nuget.exe to run if prompted)"
			Start-Process -Wait -WindowStyle Hidden -FilePath $nugetPath -ArgumentList "restore", $postBuildSlnPath
			Write-Output "Going to invoke: ""$msbuildPath"" ""$postBuildSlnPath"" /property:Configuration=Release"
			Start-Process -Wait -WindowStyle Hidden -FilePath $msbuildPath -ArgumentList $postBuildSlnPath, '/property:Configuration=Release'
		}
		catch 
		{
			Write-Output "Building the Post Build Helper caused an exception."
			$_
		}
	}
	else 
	{
		Write-Output "Incomplete parameters or wrong order of parameters! The '-msbuild' parameter followed by the path to MSBuild.exe must be passed first!"
	}
	if ((-Not (Test-Path $postBuildExePath)) -or (-Not (Test-Path $taskbarDllPath)))
	{
		try 
		{
			$srcExe = Join-Path -Path $PSScriptRoot -ChildPath "fallback_cgb_post_build_helper.exe"
			Write-Output "Building $exeName failed => going to copy it from $srcExe ..."
			Copy-Item $srcExe -Destination $postBuildExePath

			$srcDll = Join-Path -Path $PSScriptRoot -ChildPath "fallback.Hardcodet.Wpf.TaskbarNotification.dll"
			Write-Output "Also going to copy Hardcodet.Wpf.TaskbarNotification.dll from $srcDll ..."
			Copy-Item $srcDll -Destination $taskbarDllPath
		}
		catch 
		{
			Write-Output "Copying the files caused an exception"
			$_
		}
	}
}

# Print args to console:
#$outPath = Join-Path -Path $PSScriptRoot -ChildPath "args.txt"
#Write-Output $outPath
#$args | Out-File -FilePath $outPath

# Invoke the Post Build Helper tool:
Start-Process -FilePath $postBuildExePath -ArgumentList $args -WorkingDirectory $PSScriptRoot

Write-Output "Post Build Helper has been invoked. Now waiting for the deployment of assets and shaders..."
$maxLoop = 10
$readSomethingAtLeastOnce = $false;
for ($i=0; $i -le $maxLoop; $i++)
{
	try 
	{
		$pipe = new-object System.IO.Pipes.NamedPipeClientStream '.','Gears-Vk Application Status Pipe','In'
		$pipe.Connect()
		$sr = new-object System.IO.StreamReader $pipe
		$messageReceived = $sr.ReadLine();
		$sr.Dispose()
		$pipe.Dispose()
	}
	catch 
	{
		Write-Output "Failed to connect to Post Build Helper"
		$_
	}

	$readSomethingAtLeastOnce = $readSomethingAtLeastOnce -or ($null -ne $messageReceived)
	if ($readSomethingAtLeastOnce -and $null -ne $messageReceived -and "" -eq $messageReceived)
	{
		break
	}

	Write-Output "After $i sec.: $messageReceived"
	Start-Sleep -s 1

	if ($i -eq $maxLoop) 
	{
		Write-Output "The Post Build Helper is still busy, but we're not going to wait any longer."
	}
}
Write-Output ""
