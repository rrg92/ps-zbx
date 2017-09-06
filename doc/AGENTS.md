# About pszbx agents

A pszbx agent is a powershell script delivired with pszbx source.
It is the thing that you run when using some feature pszbx!

Here, some examples of actions that a agent can do:

* Setup logging
* Check and handle parameters and configurations (like resolve directories paths, dynamic hostname, etc.)
* Handle erros and correct reporting to calling application
* Receive user data and prepare it to Send-Sql2Zabbix
* Calls the cmdlet Send-SQl2Zabbix (cmdlet that is part of CustomMSSQL module, responsbile to execute scripts and map to zabbix keys, and send it to zabbix server)


# Agent files location

The agents files are placed under /core/agents
In this directory, there are, also, default configuration files for agents. This file contains all possible configurations and serve as a documentation for possible configurations options for a agent.

# Running a agent

For run a gent, simply runs a agent in /core/agents and passes parameters:

```powershell
powershell -File C:\Zabbix\pszbx\core\agents\DEFAULT.ps1 -Param1 -Param2 ...
```

# Getting help about agent

Pszbx facilities your help. Utilize powershell help system to get all details about a agent:

```powershell  
get-help C:\Zabbix\pszbx\core\agents\DEFAULT.ps1
```

You must always use this in order to take updated information about an agent, including how configure it.
Between releases, new features, bugfixes, improvements, can be added. The helpis better way to get it!

