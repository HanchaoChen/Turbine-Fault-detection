function instanceMappingTable = fcn_getInstanceMapping(apiAddress, apiToken)


opts = weboptions('Timeout', inf);
pageSize = 1000;

WebData = webread([apiAddress '/devices.json?deviceTypeIds=1&pageSize=' int2str(pageSize) '&apiToken=' apiToken], opts);

%assume returned structure has the fields:
%deviceID
%title

instanceIDGECs = [WebData.deviceId]';
instanceIDs = {WebData.title}';
longitude = cellfun(@(x) str2double(x), {WebData.longitude}');
latitude = cellfun(@(x) str2double(x), {WebData.latitude}');
elevation = cellfun(@(x) str2double(x), {WebData.elevation}');

%syntax to strip out farm name and turbine number
windFarms = cellfun(@(x) x(1, 1:3), instanceIDs, 'UniformOutput', false);
%instanceIDWTG = cellfun(@(x) str2double(x(regexp(x, '\d'))), instanceIDs);

instanceMappingTable = table();
instanceMappingTable.instanceIDGEC = instanceIDGECs;
instanceMappingTable.instanceID = categorical(instanceIDs);
instanceMappingTable.windFarm = categorical(windFarms);
instanceMappingTable.longitude = longitude;
instanceMappingTable.latitude = latitude;
instanceMappingTable.elevation = elevation;



