# Cache structure

The cache manager stores cached files in directory specified in property "cacheDirectory".
Every cache directory there are a file called "mapping.xml".
This file is the cache manager database and is used to store many data, including a mapping between a local cached file and the the respective remote.

Inside the cache directory there are a subdirectory for each file extension cached. For example, if one or more ".sql" file is cached, then this file will be placed on cacheDirectory/sql/LocalFileName. This help find a file easily.

Inside this subdirectories, the cached files will be stored.
The filename follow this standard:

    BaseName + guid + extension

Where:
*   **BaseName**: Is the base filename of the original name. The basename dont include the file extensions.
*   **Guid**: A uniqueidentifier generated for the remote file.
*   **extension**: The file extension. Keeping the extension, allows the file be parse like the original file (some tools, like powershell, requires specific extensions to execute or load files)


Note that files in cache are just normal files. It are just a copy of remotes files with a different file name.
Any user or software can access the file in the cache. The cache manager dont enforce any locking. It just acts copying remote files to local and retuning appopriate paths.

We dont encourage your change the cached files or any structure used by the cache manager manually.
If this occurs, unexcpected behavior can occurs. Just do it with correct support.