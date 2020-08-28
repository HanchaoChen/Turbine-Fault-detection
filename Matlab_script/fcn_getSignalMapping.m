function [signalMappingTable, varargout] = fcn_getSignalMapping(apiAddress, apiToken, varargin)

%get the breeze signal mapping

% set varagin parameters
deviceIds = []; %default value

if mod(length(varargin), 2) ~= 0
    error('Unexpected number of input value pairs');
elseif isempty(varargin)
    %do nothing as defaults are used
else 
    pairsN = length(varargin) / 2;
    for nPair = 1:pairsN
        v1 = varargin{nPair*2 - 1};
        v2 = varargin{nPair*2};
        switch v1
            case 'deviceIds'
                if isnumeric(v2)
                    deviceIds = v2;
                else
                    error('Expected Data type logical for multFile');
                end
            otherwise
                error(['unexpected input, found : ' v1]);
        end        
    end    
end


opts = weboptions('Timeout', inf);

%if there are any device IDs, then make the call specifc to those
if isempty(deviceIds)
    %no device IDs specified
    WebData = webread([apiAddress '/datasignals.json?apiToken=' apiToken], opts);
else
    %there are device IDs
    instanceIDsCallString = fcn_apiCallStringContructInt(deviceIds, 'deviceIds=');
    WebData = webread([apiAddress '/datasignals.json?' instanceIDsCallString '&apiToken=' apiToken], opts);    
end

%assume returned structure has the fields:
% dataSignalId
% title
% type
% unit

signalIDs = [WebData.dataSignalId]';
%set the original signal order
originalOrder = signalIDs;

signalNames = {WebData.title}';

signalTypes = {WebData.type}';

signalUnits = {WebData.unit}';

signalMappingTable = table();
signalMappingTable.signalID = signalIDs;
signalMappingTable.name = signalNames;
signalMappingTable.type = signalTypes;
signalMappingTable.unit = signalUnits;

%create a suitable matlab variable name for each signal
signalNamesMatlab = regexprep(signalNames, '[()]', '_'); % replace brackets with _
signalNamesMatlab = strtrim(signalNamesMatlab); % remove leading and trialing whitspace
signalNamesMatlab = regexprep(signalNamesMatlab, '\s', '_'); % replace whitspace with _
signalNamesMatlab = regexprep(signalNamesMatlab, '\W', ''); % remove non string or numerical characters

signalMappingTable.nameMatlab = signalNamesMatlab;

signalMappingTable = sortrows(signalMappingTable, 1);

%there is an issue with the api producing duplicates so get rid of these
signalMappingTable = unique(signalMappingTable, 'stable');

if nargout == 2
    varargout{1} = originalOrder;
end

