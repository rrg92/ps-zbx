# About caches

The "cache" directory in root is used by DEFAULT agent to store remote files (from shares)
This maintain agent running whenver remote file is unavaliable.

# How cache works

Agent check if elegible files are remote files (by its fullname).
If file is local file, it will not be cached.

The DEFAULT agent only try caches the configuration file, if it remote and passed by -ConfigurationFile parameter.
All other caching files, like key definitions and scripts used by it, are handled by Send-SQL2Zabbix.

The caching engine is provided by "CacheManager" module. You can check it to more internals information.
Basically, the caching engine used modified date of file to determine if file must be updated.

The "/cache" directory is subdivided into two other directories:

	- agentcache
		In this directory is where the default agent will store your cached files.
		When agents starts, it will try create a subdirectory inside this where the name is the AgentID.

		The AgentId is value parameters -Instance  and -KeysGroups (and a .DEBUG string, if in debug mode).
		That it, if you start agent with same combination of this parameters, it will use same cache folder.
		If this directory is always preserved, the agent can always used cached files to do your work.
		
		The agent updates and check the files in this cache, only when it starts.
	

	- send2zabbix
		This directory stores the Send-SQL2Zabbix cached files.
		This stores cached files of keys definitions and scripts files.

		The subdirectory name of cache is handled by Send-SQL2Zabbix.
		In the actual relase of it, it is the -ExecutionID parameter the DEFAULT agent passes the value of AgentID.
		The, it will contains same name as "agentcache".
		The files in the cache, are updated same frequency of -Reloadtime parameter of Send-SQL2Zabbix, that is same of -Reloadtime of DEFAULT agent.



# Cache structure

Check "CacheManager" module to all about your organization




	
