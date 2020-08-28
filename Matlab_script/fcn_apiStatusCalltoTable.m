function StatusData = fcn_apiStatusCalltoTable(Data, instanceMappingTable)

%convert api structure into table structure


if isempty(Data)
    %no status to read so return empty table
    StatusData = table();
    return
end
%remove invalid fields i.e. where ther is no entry, but and entry is
%required
Data = Data(~cellfun(@isempty, {Data.timestampStart}'), :);
Data = Data(~cellfun(@isempty, {Data.code}'), :);


tEnd = '0000-00-00T00:00:00';
tEndDTime = datetime([0, 0, 0, 0, 0, 0]);
noEndDate = find(cellfun(@isempty, {Data.timestampEnd}'));
for n=1:length(noEndDate)
    Data(noEndDate(n)).timestampEnd = tEnd;
end

%count the number of instances
instanceIDGECs_all = [Data.deviceId]'; % the GEC suffic means that the instance ID is the Greenbyte instance in their system

%find the instance ID rather tha  the GEC code
%add in the the actual instance IDs rather than just the greenbyte ones
[~, instanceIDIndex] = ismember(instanceIDGECs_all, instanceMappingTable.instanceIDGEC);
%assign into the TurbineData and make the second column
instanceID = categorical(instanceMappingTable.instanceID(instanceIDIndex));

%define start and end times
timeStartString = cell2mat({Data.timestampStart}'); % get the time stamps
%convert into date vector elements
dVector = [str2num(timeStartString(:, 1:4)), str2num(timeStartString(:, 6:7)), str2num(timeStartString(:, 9:10)),...
    str2num(timeStartString(:, 12:13)), str2num(timeStartString(:, 15:16)), str2num(timeStartString(:, 18:19))]; %#ok
%convert into date time
ts_start = datetime(dVector);

timeEndString = cell2mat({Data.timestampEnd}'); % get the time stamps
%convert into date vector elements
dVector = [str2num(timeEndString(:, 1:4)), str2num(timeEndString(:, 6:7)), str2num(timeEndString(:, 9:10)),...
    str2num(timeEndString(:, 12:13)), str2num(timeEndString(:, 15:16)), str2num(timeEndString(:, 18:19))]; %#ok
%convert into date time
ts_end = datetime(dVector);

%change empmpy end time (represented by tEnd) to not a time
ts_end(ts_end == tEndDTime) = NaT;

%find the duration of the event
ts_duration = ts_end - ts_start;

%status
status = {Data.category}';
status(cellfun(@isempty, status)) = {''}; % replace empty cells with blank so it can be transformed into categorical
%check for any numeirc values and change to string
status(cellfun(@isnumeric, status)) = cellfun(@num2str, status(cellfun(@isnumeric, status)), 'UniformOutput', false);

%code
code = [Data.code]';

%message
message = {Data.message}';

%comment
comment = {Data.comment}';

%contract category
contractCategory = {Data.categoryContract}';
contractCategory(cellfun(@isempty, contractCategory)) = {''}; % replace empty cells with blank so it can be transformed into categorical
%check for any numeirc values and change to string
contractCategory(cellfun(@isnumeric, contractCategory)) = cellfun(@num2str, contractCategory(cellfun(@isnumeric, contractCategory)), 'UniformOutput', false);

%IEC category
iecCategory = {Data.categoryIec}';
iecCategory(cellfun(@isempty, iecCategory)) = {''}; % replace empty cells with blank so it can be transformed into categorical
%check for any numeirc values and change to string
iecCategory(cellfun(@isnumeric, iecCategory)) = cellfun(@num2str, iecCategory(cellfun(@isnumeric, iecCategory)), 'UniformOutput', false);

%assign into table
StatusData = table(instanceID);
StatusData.ts_start = ts_start;
StatusData.ts_end = ts_end;
StatusData.duration = ts_duration;
StatusData.status = categorical(status);
StatusData.code = code;
StatusData.message = message;
StatusData.comment = comment;
StatusData.contractCategory = categorical(contractCategory);
StatusData.iecCategory = categorical(iecCategory);


%sort by start time and then instance ID
StatusData = sortrows(StatusData,{'ts_start', 'instanceID'});

%correct for daylight saving
StatusData = fcn_correctDSStatus(StatusData);

%for Senvion andNOrdex sites, then staus codes are not always cleared.
% look for status code which indicates turbine is ok - or the next status of the same type
% any non cleared status code is given this start time as its finish time.
releventSites = {'ACH'; 'NST'; 'SEA'; 'LSP'; 'SIS'; 'DAL'; 'FFY';...
    'LIS';'WNT';'WST';'TED';'GOR';'BLD';'TOW'};

siteName = char(StatusData.instanceID(1));
siteName = siteName(1:3);
if any(contains(releventSites, siteName))
    instanceIDs = categories(StatusData.instanceID);
    for ii=1:length(instanceIDs)
        instanceID = instanceIDs{ii};
        switch siteName
            case {'ACH'; 'NST'; 'SEA'; 'LSP'; 'SIS'; 'DAL'; 'FFY'}
                okStatusCode = 0;
            case {'LIS';'WNT';'WST';'TED';'GOR';'BLD';'TOW'}
                okStatusCode = 0;
        end
        ThisInstance = StatusData(StatusData.instanceID == instanceID, :);
        
        %find oks
        okI = find(ThisInstance.code == okStatusCode);
        
        %find any status which is a stop and doesn't have an end time
        stopI = find(ThisInstance.status == 'stop' & isnat(ThisInstance.ts_end));
        if ~isempty(stopI)
            
            clearingCodes = okI;
            if ~isempty(clearingCodes)
                %if there are stops that start after the last clearing code then these are not
                %changed as they are assumed to still be active
                stopI(stopI >= max(clearingCodes)) = [];
                if ~isempty(stopI)
                    %for each non cleared stop find the next clearing code
                    nextClearingCode = clearingCodes(arrayfun(@(x) find(clearingCodes > x, 1, 'first'), stopI));
                    %now assign the end time to the stop as the start of the next ok
                    ThisInstance.ts_end(stopI) = ThisInstance.ts_start(nextClearingCode);
                    %assign a duration for these indexes
                    ThisInstance.duration(stopI) = ThisInstance.ts_end(stopI) - ThisInstance.ts_start(stopI);
                end
            end
        end
                     
        StatusData(StatusData.instanceID == instanceID, :) = ThisInstance; %assign back into table
        
    end
else
    %do nothing
end

%for some sites, the stop status might not clear.  In case this happens,
%look for the next stop status and stop the previous one when this one
%starts.
instanceIDs = categories(StatusData.instanceID);
for ii=1:length(instanceIDs)
    instanceID = instanceIDs{ii};
    ThisInstance = StatusData(StatusData.instanceID == instanceID, :);
    %find stops
    stopI = find(ThisInstance.status == 'stop' & ~isnat(ThisInstance.ts_end));
    %find stops that don't have an end time
    stopINoE = find(ThisInstance.status == 'stop' & isnat(ThisInstance.ts_end));
    %if either is empty, then continue
    if isempty(stopI) || isempty(stopINoE)
        continue
    end
    %find the next closest stop with an end time after those without
    nextClosest = stopI - repmat(stopINoE', length(stopI), 1);
    %chnage negative values to nan
    nextClosest(nextClosest <= 0) = nan;
    [~, nextI] = min(nextClosest, [], 1);
    %remove indexes where there is no end time to replace with
    nextI(all(isnan(nextClosest))) = [];
    stopINoE(all(isnan(nextClosest))) = [];
    %assign into the table
    ThisInstance.ts_end(stopINoE) = ThisInstance.ts_start(stopI(nextI));
    %assign a duration for these indexes
    ThisInstance.duration(stopINoE) = ThisInstance.ts_end(stopINoE) - ThisInstance.ts_start(stopINoE);
    StatusData(StatusData.instanceID == instanceID, :) = ThisInstance;
end



