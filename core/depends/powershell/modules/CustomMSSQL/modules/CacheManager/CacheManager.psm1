#Get a new cache manager object!
$ErrorActionPreference = "Stop";

Function New-CacheManager {

	#PROPERTIES
	
		#This properties can be changed by the user!
		$PublicProperties = @{
			cacheDirectory 		= $null
			enabled				= $false #Controls the cache operation. 
			internal			= $null #Will contains the internal object. IOnly cache manager can change this!
			
			#Specify log destinations! This module uses XLogging module for implement logging!
			logTo				= @("#")
			
			#Controls de log level of script!
			logLevel			= $null
		}

		#Internals properties to be used only by cache manager!
		$internalProps	= @{
			cachemanager = $null #cache manager object associted with this internal object!
				#Represent the cache database.
				#The database is persited on a file!
				database = @{
						file  		= $null  #Path to current cache database file.
						loaded		= $false #Indicates that database was loaded!
						content		= @{}	 #The database contents.
					}
			
				ready 		= $false #indicates that cache was configured.
				logObject	= $null
			}

	#OBJECT DEFINITIONS!
		#tHE internal object represent internal operations in the cahce!
		$CacheObject = New-Object PSObject -Prop $PublicProperties
		$internal = New-Object PSObject -Prop $internalProps
		$internal.cachemanager = $CacheObject
		$CacheObject.internal = $internal;
	
	#METHODS 
	
		#publics methods! 
			$publicMethods = @{
					#Initialize caches internals values.
					#User must call this after setting cachedirectory!
					init = {
						$Internal = $this.internal;
						
						if($Internal.ready){
								return;
						}
					
						$Internal.configureLogging();
						
						$Internal.log("A cache manager is initializing", "PROGRESS");
						$Internal.determineDatabaseFile();
						$Internal.loadDatabaseFile();
						$internal.ready = $true;
						$this.enabled = $true;
						$Internal.log("A new instance of cache manager was sucessfully configured", "PROGRESS");
						$Internal.log("	The cache directory is: $($this.cacheDirectory)", "PROGRESS");
					}
				
				
					#Get a filename from the cache!
					#If file isn't cached, it will be.
					#If cache not enabled or file is local, then the same filename will be returned!
					getFile = {
						param($RemoteName, $RecheckFrequency = $null)
						
						$Internal = $this.internal;
						
						if(!$this.enabled){
							return $RemoteName;
						}
						
						$FileURI = New-Object Uri($RemoteName);
						if(!$FileURI.IsUnc){
							return $RemoteName;
						}
						
						$FileMap = $Internal.getDatabaseItem('FILE_MAP');
						
						#Check if file map already in database...
						if($FileMap.Contains($RemoteName)){
							#Get the remote name slot!
							$FileMapEntry 	= $FileMap[$RemoteName];
							#Check last download time!
							$LastDownloadTime = $FileMapEntry.LastDownloadTime

							#Get the path to local file cache!
							$FullLocalPath	= $Internal.getFileCachePath($FileMapEntry.FileName);
							
							#Logging...
							$Internal.log("Remote $RemoteName cached: $($FullLocalPath) lastDownloadTime: $lastDownloadTime", "VERBOSE");

							#If file not exists, attempts bring the file from the remote cache!
							if(![Io.File]::Exists($FullLocalPath)){
								try {
									$Internal.log("CacheManager: The local path $FullLocalPath (original: $( $RemoteName)) was not found. Trying re-copy!", "DETAILED");
									copy -Path $RemoteName -Destination $FullLocalPath -force;
									$FileMapEntry.LastDownloadTime = (Get-Date);
									$Internal.log("Sucess!","DETAILED")
									$Internal.updateDatabase('FILE_MAP',$FileMap);
								} catch {
									$Internal.log("	Cannot recopy! Error: $_","DETAILED")
									return $RemoteName;
								}
							}
							
							#Try update file!
							#Will try update if file recheck time passed!
							if($RecheckFrequency){
								if(!$FileMapEntry["LastCheck"]){
									$FileMapEntry["LastCheck"] = [datetime]"1900-01-01"
								}
								$NextRecheck = $FileMapEntry.LastCheck.addSeconds($RecheckFrequency);
							} else {
								$NextRecheck = [datetime]"1900-01-01"
							}
							
							if( (Get-Date) -ge $NextRecheck ){
								try {
									$FileMapEntry["LastCheck"] = (Get-Date);
									$RemoteFile = Get-Item $RemoteName;
									
									$Internal.log("Remote last modification time: $($RemoteFile.LastWriteTime)","VERBOSE")
									if($RemoteFile.LastWriteTime -ge $FileMapEntry.LastDownloadTime){
										$Internal.log("Updating local copy!","VERBOSE")
										copy -Path $RemoteName -Destination $FullLocalPath -force;
										$FileMapEntry.LastDownloadTime = (Get-Date);
									}
									
									$Internal.updateDatabase('FILE_MAP',$FileMap);
								} catch {
									$Internal.log("	Cannot make update check process on remote file $RemoteName. Error: $_","DETAILED")
								}
							} else {
								$Internal.log("	Ignoring recheck due to rechecktime. Next:$NextRecheck","VERBOSE")
							}
						
							$CacheFilePath = $FullLocalPath
						} 
						else {
							#Check if remote file is acessblie
							if(![IO.File]::Exists($RemoteName)){
								$Internal.log("Remote $RemoteName dont exists.");
								return $RemoteName;
							}

							#Generate a new file name!
							$NewFileName = $Internal.getNewFileCacheName($RemoteName);
							$FullLocalPath = $Internal.getFileCachePath($NewFileName);
							
							$Internal.log("Remote $RemoteName not cached: creating a new on $FullLocalPath","VERBOSE")
							
							#Copy remote file to filename!
							try {
								copy -Path $RemoteName -Destination $FullLocalPath -force;
								$FileMap.add($RemoteName,@{FileName=$NewFileName; LastDownloadTime=(Get-Date);LastCheck=$null});
								$Internal.updateDatabase('FILE_MAP',$FileMap);
							} catch {
								$Internal.log("	Cannot cache $RemoteName into $FileName. Error: $_","DETAILED")
								return $RemoteName;
							}

							$CacheFilePath = $FullLocalPath
						}
					
						return $CacheFilePath;
					}
				
				}
		
		#internal methods!
			$internalMethods = @{
				
				#Setups logging 
				configureLogging = {
					$LogObject = (New-LogObject);
					
					if(!$this.cachemanager.LogLevel){
						$this.cachemanager.LogLevel = "PROGRESS";
					}
					
					$this.logObject			= $LogObject;		
				}
				
				
				log = {
					param($message,$level = "VERBOSE")
					
					$this.LogObject.LogTo = $this.cachemanager.logTo;
					$this.LogObject.LogLevel = $this.cachemanager.loglevel;
					$this.LogObject | Invoke-Log -Message $message -Level $Level
				}
				
				
				#Validates the cache directory!
				#If valid, creates it!
				validateCacheDirectory = {
					$CacheDir = $this.cachemanager.cacheDirectory;
					
					if(!$CacheDir){
						throw "CACHEDIR_VALIDATION: Invalid cache directory!"
					}
					
					#Remove invalid paths from cache!
					@([IO.Path]::GetInvalidPathChars()) | %{
						$CacheDir  = $CacheDir.replace($_.toString(),'');
					}
					$this.cachemanager.cacheDirectory = $CacheDir;
					
					if(![IO.Directory]::Exists($CacheDir)){
						try {
							$CreatedDirectory = New-Item -ItemType Directory -Path $CacheDir;
						} catch{
							throw "CACHEDIR_VALIDATION_CANNOT_CREATE: $_";
						}
					}
					
					return;
				}
				
				#Determine the database file!
				determineDatabaseFile = {
						#Validates the cache dir!
						$this.validateCacheDirectory();
						
						#Determine file path!;
						$this.database.file = $this.cachemanager.cacheDirectory + '\' + 'mapping.xml';
					}
			
				#Loads database file!
				loadDatabaseFile = {
						if($this.database.loaded){
							return;
						}
						
						try {
							$FileToLoad = $this.database.file;
							if([IO.File]::Exists($FileToLoad)){
								$this.log("LoadDatabaseFile: File $FileToLoad exists. Loading existent...")
								$this.database.content = Import-CliXML $FileToLoad;
							}
							else {
								$this.log("LoadDatabaseFile: File $FileToLoad not exists. Setting up a new database!")
								$this.setupNewDatabaseContent();
							}
							
							$this.database.loaded = $true;
						} catch {
							throw "DATABASE_FILELOAD_ERROR: $_";
						}
						
						return;
					}
			
				#Update the database file!
				updateDatabaseFile = {
					$DatabaseFile = $this.database.file;
					try {
						$this.database.content | Export-CliXML $DatabaseFile;
					} catch {
						throw "DATABASE_FILEUPDATE_ERROR: $_";
					}
					
				}
			
				#update a content in the database!
				#Database is a simple hashtable.
				#You can update top levels keys!
				#The function will update file!
				updateDatabase  = {
					param($Key, $Value)
					
					$DatabaseContent = $this.database.content;
					
					try {
						#If key exists..
						if($DatabaseContent.Contains($Key)){
							$DatabaseContent[$Key] = $Value;
						} else {
							$DatabaseContent.add($Key,$Value);
						}
						
						$this.updateDatabaseFile()
					} catch {
						throw "DATABASE_UPDATE_ERROR: $_";
					}
				}
			
				#Gets a value from the database!
				getDatabaseItem = {
					param($Key)
					
					if($this.database.content.contains($Key)){
						return $this.database.content[$key];
					}
				}
			
				#Creates a new database content!
				setupNewDatabaseContent = {
					$this.database.content = @{
						#Contains all mappings of remote files to local files!
						FILE_MAP = @{}
					}
				}
			
				#Get the complete path to a file on cache!
				getFileCachePath = {
					param($FileName)
					
					$FileExt =  [Io.Path]::GetExtension($FileName);
					$BaseFileTypeDir =  $this.cachemanager.cacheDirectory +'\'+ $FileExt.replace('.','');
					
					if(![Io.Directory]::Exists($BaseFileTypeDir)){
						$NewBaseDir = New-Item -ItemType Directory -Path $BaseFileTypeDir -force;
					}
					
					$FullLocalPath = $BaseFileTypeDir +'\'+ $FileName;
					return $FullLocalPath;
				}
			
				#Generates a new name for a file on cache!
				getNewFileCacheName = {
					param($RemoteName)
		
					[string]$NewFileGuid =  ([Guid]::NewGuid()).Guid.replace('-','');
					$FileExt = [Io.Path]::GetExtension($RemoteName);
					$BaseName = [Io.Path]::GetFileNameWithoutExtension($RemoteName);
					$FileName = $BaseName +'.'+$NewFileGuid.replace("-","") + $FileExt;
					return $Filename;
				}
			}
		
		
	#Create all internal methods
		$internalMethods.GetEnumerator() | %{
				$MethodName 	= $_.Key;
				$MethodScript	= $_.Value;
				$internal | Add-Member -Name $MethodName -Type ScriptMethod -Value $MethodScript;
			}
		
		#Create all public methods
		$publicMethods.GetEnumerator() | %{
				$MethodName 	= $_.Key;
				$MethodScript	= $_.Value;
				$CacheObject | Add-Member -Name $MethodName -Type ScriptMethod -Value $MethodScript;
			}
		

	return $CacheObject;
}



