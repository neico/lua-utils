if not _R["_CLASSES"] then _R["_CLASSES"] = {} end

package.classpath = io.fixdirsep(
	io.workingdir .. "lua/classes/?.lua;" ..
	io.workingdir .. "lua/classes/?/init.lua;" ..
	io.workingdir .. "classes/?.lua;" ..
	io.workingdir .. "classes/?/init.lua;" ..
	"./?.lua"
);

local pSearcher = function( szModule )
	local tClass = _R["_CLASSES"][szModule];
	if tClass then
		return function( tClass )
			return tClass
		end, tClass;
	else
		return function( szModule )
			assert( pcall( include, szModule, package.classpath ) );

			return _R["_CLASSES"][szModule];
		end, szModule;
	end
end

if #package.searchers > 5 then
	package.searchers[2] = pSearcher;
else
	table.insert( package.searchers, 2, pSearcher );
end

-- Note: new <Class>( ... ) is not possible due to the syntax getting confused with that (new would need to be a reserved word to fix that)
local tGlobalMeta = getmetatable( _G );
local tNewGlobalMeta =
{
	["__index"] = function( tTable, Key )
		if _R["_CLASSES"][Key] then return _R["_CLASSES"][Key] end
		
		if tGlobalMeta ~= nil and not tGlobalMeta.bNew then
			if tGlobalMeta.__index ~= nil and type( tGlobalMeta.__index ) == "function" then return tGlobalMeta.__index( tTable, Key ) end

			return tGlobalMeta.__index;
		end

		return rawget( tTable, Key );
	end,

	["__newindex"] = function( tTable, Key, Value )
		if _R["_CLASSES"][Key] then error( "tried to create global class variable" ) end

		if tGlobalMeta ~= nil and not tGlobalMeta.bNew and tGlobalMeta.__newindex ~= nil and type( tGlobalMeta.__newindex ) == "function" then tGlobalMeta.__newindex( tTable, Key, Value ) end

		rawset( tTable, Key, Value );
	end,

	["bNew"] = true
};

if tGlobalMeta == nil then tGlobalMeta = tNewGlobalMeta end
setmetatable( _G, tGlobalMeta );

-- ToDo: method -> alias for function <Method>( self, ... )
-- Note: Not possible, would require method to be a reserved word

function class( szClass, ... )
	local tClass = {};
	
	local tClassMeta =
	{
		["__call"] = function( tTable, ... )
			if type( tTable ) == "table" then return new( tTable, ... ) end
		end
	};

	local tParents = { ... };
	for iParent, szParent in ipairs( tParents ) do
		local bSuccess, szError = pcall( require, szParent );

		if not bSuccess then error( "failed to find parent class \"" .. szParent .. "\"" ) end

		tClassMeta[szParent] = _R["_CLASSES"][szParent]();

		if iParent == 1 then tClass["parent"] = tClassMeta[szParent] end
		tClass["parent_" .. szParent] = tClassMeta[szParent];
	end

	_R["_CLASSES"][szClass] = tClass;

	setmetatable( tClass, tClassMeta );

	debug.setupvalue( debug.getinfo( 2, "f" ).func, 1, setmetatable( { [szClass] = tClass },
	{
		["__index"] = function( tTable, Key )
			local pResult = rawget( tClass, Key );
			if pResult then return pResult end

			return rawget( _G, Key );
		end,

		["__newindex"] = function( tTable, Key, Value )
			rawset( tClass, Key, Value );
		end
	} ) );
end

function new( Class, ... )
	local tClassBase = Class;
	if type( Class ) == "string" then
		tClassBase = _R["_CLASSES"][Class];
	elseif type( Class ) == "table" then
		local bFound = false;

		for Key, Value in pairs( _R["_CLASSES"] ) do
			if tClassBase == Value then
				bFound = true;
				break;
			end
		end

		if not bFound then error( "tried to initialize non-class table" ) end
	end

	if tClassBase == nil then error( "tried to create unkown class" ) end

	local tClass = {};
	table.clone( tClass, tClassBase, false );

	local tClassMeta = {};
	table.clone( tClassMeta, getmetatable( tClassBase ), false );

	function tClassMeta.__index( tTable, Key )
		local pReturn = rawget( tTable, Key );
		if pReturn == nil then
			for _, szParent in ipairs( tClassMeta["tParents"] ) do
				local tParent = tClassMeta[szParent];
				if tParent then
					pReturn = rawget( tParent, Key );

					if pReturn then return pReturn end
				end
			end
		end

		return pReturn;
	end

	function tClassMeta.__call( tTable, ... )
		local pResult = rawget( tTable, "__construct" );
		if pResult then pResult( ... ) end

		return tTable;
	end

	function tClassMeta.__gc( tTable )
		local pResult = rawget( tTable, "__destruct" );
		if pResult then pResult( tTable ) end
	end

	setmetatable( tClass, tClassMeta );

	return tClass( ... );
end

function delete( pClass )
	if pClass["__destruct"] then pClass["__destruct"]( pClass ) end
end
