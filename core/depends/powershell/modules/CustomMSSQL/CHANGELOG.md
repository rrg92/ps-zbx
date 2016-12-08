# Change Log
All important changes to this project will be added to this file!
This changelog will be based on [Keep a change log](http://keepachangelog.com/)

## [0.6.5] - 2016-12-08
### Changed
- (Send-SQL2Zabbix) Fixed issue #14 on caching mechanism.

## [0.6.4] - 2016-12-06
### Added
- (Send-SQL2Zabbix) Added cache mechanism support via paramter -CacheFolder

## [0.6.3] - 2016-12-05
### Added
- (Send-SQL2Zabbix) Added AppName parameter!

## [0.6.2] - 2016-07-27
### Added
- (Invoke-NewQuery) Added beta versions of Invoke-NewQuery (Invoke-NewQueryBeta) that now can process messages and multiple resultsets! 
- (Invoke-NewQuery) Created the NewDataReaderParser for manage reader operations...
### Changed
- (Invoke-NewQuery) Improve perfomance on reading results from sql server. 

## [0.6.1] - 2016-05-16
### Added
- (Copy-SQLDatabase) Before restoring the database, ALTER DATABASE SET OFFLINE/ONLINE will be raised in order to guarantee that all connections will be removed.

## [0.6.0] - 2016-05-03
### Added
- (Invoke-NewQuery) MaxVersion parameter was added. Now, a maximum version can be specified. Check parameter help using Get-Help for more information.
- (Invoke-NewQuery) ForceSpecialOutput parameter was added. Check help for more details.
- (Invoke-NewQuery) Notifications engine was added. Now, the cmdlet can generate some notifications stored in internal connection info cmdlet. ForceSpecialOutput can be used to get access to notifications text.
- (Invoke-NewQuery) Added supported properties of special output.
- (Invoke-NewQuery) Added support for pipe server name via string array. 

### Changed
- (Invoke-NewQuery) Description updated. The definitions of special output and notifications was added.

## [0.5.2] - 2016-04-20
### Added
- (Copy-SQLDatabase) ExportPermissionsFile parameter was added. It allows specified a file to export permissions collected!

## [0.5.1] - 2016-04-20
### Added
- This CHANGELOG file was added (Issue #4)
- The CHANGELOGFILE entry was added to GMV hashtable (Issue #4)
- The Changelog.aux.ps1 was added to helpers functions and new functions to read changelog added to it! (Issue #4)
- The Changelog.cmdlet.ps1 was added to cmdlets list (Issue #4)
- The cmdlets following cmdlets are available: Get-CustomMSSQLVersionChangeLog and Get-CustomMSSQLVersions (Issue #4)
- (Copy-SQLDatabase) Parameter -FindBlockLeaders added

### Changed
- The module psd1 file was updated to correct version!

[0.6.5]: https://github.com/rrg92/CustomMSSQL/releases/tag/0.6.5
[0.6.4]: https://github.com/rrg92/CustomMSSQL/releases/tag/0.6.4
[0.6.3]: https://github.com/rrg92/CustomMSSQL/releases/tag/0.6.3
[0.6.2]: https://github.com/rrg92/CustomMSSQL/releases/tag/0.6.2
[0.6.1]: https://github.com/rrg92/CustomMSSQL/releases/tag/0.6.1
[0.6.0]: https://github.com/rrg92/CustomMSSQL/releases/tag/0.6.0
[0.5.2]: https://github.com/rrg92/CustomMSSQL/releases/tag/0.5.2
[0.5.1]: https://github.com/rrg92/CustomMSSQL/releases/tag/0.5.1