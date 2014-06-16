local bSuccess, szError = pcall( dofile, "lua/includes/util/init.lua" );
if not bSuccess then
	local szTmp = szError;
	bSuccess, szError = pcall( dofile, "includes/util/init.lua" );

	if not bSuccess then error( szTmp .. "\n" .. szError ) end
end

include( "oop.lua" );
