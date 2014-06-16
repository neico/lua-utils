-- ToDo: Branch out into seperate files

_R = debug.getregistry();

function hasmeta( pObject, szMeta )
	local tMeta = getmetatable( pObject );
	if tMeta and type( tMeta ) == "table" and tMeta[szMeta] then return true end

	return false;
end

function callmeta( pObject, szMeta, ... )
	if hasmeta( pObject, szMeta ) then
		local tMeta = getmetatable( pObject );

		return tMeta[szMeta]( ... );
	end

	return nil;
end

function hasarg( pFunction, szLocal, iIndex )
	if iIndex then
		local szName, Value = debug.getlocal( pFunction, iIndex );

		if szName == szLocal then return true end
	else
		for i = 1, 10 do
			local szName, Value = debug.getlocal( pFunction, i );

			if szName == szLocal then return true end
		end
	end

	return false;
end

function printtable( tTable, iIndent, tDone )
	tDone = tDone or { [_G] = true, [_R] = true };
	iIndent = iIndent or 0;

	for Key, Value in pairs( tTable ) do
		local szMsg = string.rep( "\t", iIndent ) .. tostring( Key );
		if type( Value ) == "table" and not tDone[Value] then
			tDone[Value] = true;
			if #Value > 0 then
				print( szMsg .. ":" );
			else
				print( szMsg .. ":\n" );
			end
			printtable( Value, iIndent + 2, tDone );
		else
			print( szMsg .. "\t=\t" .. tostring( Value ) );
		end
	end
end

local tStringMeta = getmetatable( "" );

function tStringMeta.__index( szString, Key )
	if type( Key ) == "number" then
		return string.sub( szString, Key, Key );
	end

	return string[Key];
end

function string.escape( szString )
	return szString:gsub( "[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%1" );
end

function string.ucfirst( szString )
	return string.upper( szString:sub( 1, 1 ) ) .. szString:sub( 2 );
end

function string.startswith( szString, szPrefix )
	return szString:sub( 1, szPrefix:len() ) == szPrefix;
end

function string.endsswith( szString, szSuffix )
	return szString:sub( 1, -szSuffix:len() ) == szSuffix;
end

function string.split( szString, szSeperator, bSeperatorPattern )
	if not bSeperatorPattern then szSeperator = szSeperator:escape() end

	local tString = {};
	local iIndex, iPos = 1, 1;

	for iStart, iEnd in szString:gmatch( "()" .. szSeperator .. "()" ) do
		tString[iIndex] = szString:sub( iPos, iStart - 1 );
		iIndex = iIndex + 1;
		iPos = iEnd;
	end

	tString[iIndex] = szString:sub( iPos );

	return tString;
end

function table.clone( tDest, tSrc, bMeta )
	local bMeta = bMeta;
	if bMeta == nil then bMeta = true end

	for Key, Value in pairs( tSrc ) do
		if Key ~= "_G" and type( Value ) == "table" then
			tDest[Key] = {};
			table.clone( tDest[Key], Value, false );
		else
			tDest[Key] = Value;
		end
	end

	if bMeta then setmetatable( tDest, getmetatable( tSrc ) ) end

	return tDest;
end

package.settings = {};
package.settings.dirsep,
package.settings.pathsep,
package.settings.file_mark,
package.settings.execdir_mark,
package.settings.ignore_mark = table.unpack( package.config:split( "\n" ) );

if not io.workingdir then
	local tPaths = package.path:split( package.settings.pathsep );

	if #tPaths ~= 5 then print( "package.path was modified, make sure that there are only 5 paths and that the 3rd one looks like '<working dir>?<file extension>' and try it again...\nSet io.workingdir manually otherwise..." ) end

	io.workingdir = tPaths[3]:split( package.settings.file_mark )[1];
end

function io.fixdirsep( szFileName, szSeperator )
	if not szSeperator then szSeperator = package.settings.dirsep end

	return szFileName:gsub( "[\\/]", szSeperator );
end

function io.exists( szFileName )
	if type( szFileName ) ~= "string" then return false end

	return os.rename( szFileName, szFileName ) and true or false;
end

function io.isfile( szFileName )
	if type( szFileName ) ~= "string" then return false end
	if not io.exist( szFileName ) then return false end

	local pFile = io.open( szFileName );
	if pFile then
		pFile:close();
		return true;
	end

	return false;
end

function io.isdir( szFileName )
	return io.exist( szFileName ) and not io.isfile( szFileName );
end

local function writelog( szFileName, tMsgs )
	if not io.exists( "logs" ) then os.execute( "mkdir logs" ) end

	local pFile, szError = io.open( io.fixdirsep( szFileName ), "a" );
	assert( pFile, "Failed to create " .. tostring( szError ) );

	for _, szMsg in ipairs( tMsgs ) do
		pFile:write( szMsg );
	end

	pFile:close();
end

package.path = io.fixdirsep(
	io.workingdir .. "lua/includes/?.lua;" ..
	io.workingdir .. "lua/includes/?/init.lua;" ..
	package.path
);

function include( szFileName, szPaths )
	szPaths = szPaths or package.path;
	if szFileName:sub( -4 ) == ".lua" then szFileName = szFileName:sub( 1, szFileName:len() - 4 ) end

	-- ToDo: search path that include is currently executed in

	for _, szPath in ipairs( szPaths:split( package.settings.pathsep ) ) do
		szPath = szPath:gsub( package.settings.execdir_mark, io.workingdir, 1 ):gsub( package.settings.file_mark, szFileName, 1 );

		local bSuccess, szError = pcall( dofile, szPath );
		if not bSuccess then
			szPath = szPath:lower();

			local szTmp = szError;
			bSuccess, szError =  pcall( dofile, szPath );

			if not bSuccess then error( szTmp .. "\n" .. szError ) end
		end

		if bSuccess then break end
	end
end

LOG_NORMAL	= 1
LOG_INFO	= 2
LOG_DEBUG	= 3
LOG_WARNING	= 4
LOG_ASSERT	= 5
LOG_ERROR	= 6
LOG_VERBOSE	= 7

log = {};

function log.tag2str( eTag )
	if eTag == LOG_NORMAL then return "normal" end
	if eTag == LOG_INFO then return "info" end
	if eTag == LOG_DEBUG then return "debug" end
	if eTag == LOG_WARNING then return "warning" end
	if eTag == LOG_ASSERT then return "assert" end
	if eTag == LOG_ERROR then return "error" end
	if eTag == LOG_VERBOSE then return "verbose" end
end

function log.write( eTag, szTag, ... )
	local tMsgs = { ... };

	for Key, szMsg in ipairs( tMsgs ) do
		tMsgs[Key] = os.date( "[%d.%m.%Y %H:%M:%S]" ) .. " [" .. szTag .. "] " .. szMsg .. "\n";
	end

	writelog( "logs/" .. log.tag2str( eTag ) .. "_" .. os.date( "%d.%m.%Y" ) .. ".log", tMsgs );
end

function log.log( szTag, ... )
	log.write( LOG_NORMAL, szTag, ... );
end

function log.info( szTag, ... )
	log.write( LOG_INFO, szTag, ... );
end

function log.debug( szTag, ... )
	log.write( LOG_DEBUG, szTag, ... );
end

function log.warning( szTag, ... )
	log.write( LOG_WARNING, szTag, ... );
end

function log.assert( szTag, ... )
	log.write( LOG_ASSERT, szTag, ... );
end

function log.error( szTag, ... )
	log.write( LOG_ERROR, szTag, ... );
end

function log.verbose( szTag, ... )
	log.write( LOG_VERBOSE, szTag, ... );
end

function log.table( tTable, iIndent, tDone, tMsgs )
	iIndent = iIndent or 0;
	tDone = tDone or { [_G] = true, [_R] = true };
	tMsgs = tMsgs or {};

	for Key, Value in pairs( tTable ) do
		tMsgs[#tMsgs + 1] = string.rep( "\t", iIndent ) .. tostring( Key );
		if type( Value ) == "table" and not tDone[Value] then
			tDone[Value] = true;
			tMsgs[#tMsgs] = tMsgs[#tMsgs] .. ":\n";
			if #Value <= 0 then tMsgs[#tMsgs] = tMsgs[#tMsgs] .. "\n" end
			log.table( Value, iIndent + 2, tDone, tMsgs );
		else
			tMsgs[#tMsgs] = tMsgs[#tMsgs] .. "\t=\t" .. tostring( Value ) .. "\n";
		end
	end

	if iIndent == 0 then
		log.info( "Table", "\n" .. table.concat( tMsgs ) );
	end
end
