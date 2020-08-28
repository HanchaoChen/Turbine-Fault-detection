function TurbineData = fcn_apiCalltoTable(Data, instanceMappingTable, signalMappingTable)

% take the structure created from a breeze api call and convert it into a
% matlab table format

tstart = tic();
disp(' ');
disp('------------------------------------------------------------------');
disp(['Started converting api format to table : ' datestr(now())]);

%count the number of instances
instanceIDGECs_all = [Data.deviceIds]'; % the GEC suffic means that the instance ID is the Greenbyte instance in their system
instanceIDGECs = unique(instanceIDGECs_all); 
instancesN = length(instanceIDGECs);
% count the number of signals
signalsN = length(instanceIDGECs_all)/instancesN;

%check that signalsN is a round number
if mod(signalsN, 1) ~= 0
    error('not all signals present for all instances');
end

%got through each instance and create a table for it with signals
for instance = 1:length(instanceIDGECs)
    instanceIDGEC = instanceIDGECs(instance);
    instanceIndex = find((instanceIDGECs_all == instanceIDGEC));
    %there should be the same number of these as signals
    if length(instanceIndex) ~= signalsN
        error('unexpected number of matched instances');
    end
    
    for signal=1:signalsN
        signalID = Data(instanceIndex(signal)).dataSignal.dataSignalId; 
        signalNameGEC = Data(instanceIndex(signal)).dataSignal.title;
        signalName = signalMappingTable.nameMatlab{signalMappingTable.signalID == signalID}; %select signal name that is valid matlab name        
        signalUnit = Data(instanceIndex(signal)).dataSignal.unit;
        
        timeString = cell2mat(fieldnames(Data(instanceIndex(signal)).data)); % get the time stamps
        %convert into date vector elements
        dVector = [str2num(timeString(:, 2:5)), str2num(timeString(:, 7:8)), str2num(timeString(:, 10:11)),...
            str2num(timeString(:, 13:14)), str2num(timeString(:, 16:17)), str2num(timeString(:, 19:20))]; %#ok
        ts = datetime(dVector);
        
        %extract the signal values
        signalValues = struct2cell(Data(instanceIndex(signal)).data);
        signalValues(cellfun(@isempty, signalValues)) = {nan};
        signalValues = [signalValues{:}]';
        
        TempTable = table(ts);
        TempTable.(signalName) = signalValues;
        
        %join table or create if it is the first iteration
        if signal == 1
            InstanceTable = TempTable;
        else
            InstanceTable = innerjoin(InstanceTable,TempTable,'key','ts');
        end
    end
    % add the instance ID and move it to the second column
    InstanceTable.instanceIDGEC = repmat(instanceIDGEC, height(InstanceTable), 1);
    InstanceTable = [InstanceTable(:, 1),  InstanceTable(:, end), InstanceTable(:, 2:end-1)];
                
    %join table or create if it is the first iteration
    if instance == 1
        TurbineData = InstanceTable;
    else
        %this will throw an error if variable don't match. I think!
        TurbineData = [TurbineData; InstanceTable];
    end
    
end

%sort the table based on timestamp and then instance ID
TurbineData = sortrows(TurbineData, [1, 2]);

%correct for daylight saving
TurbineData = fcn_correctDS(TurbineData);



%add in the the actual instance IDs rather than just the greenbyte ones
[~, instanceIDIndex] = ismember(TurbineData.instanceIDGEC, instanceMappingTable.instanceIDGEC);
%assign into the TurbineData and make the second column
TurbineData.instanceID = categorical(instanceMappingTable.instanceID(instanceIDIndex));
TurbineData = [TurbineData(:, 1),  TurbineData(:, end), TurbineData(:, 2:end-1)];



disp(' ');
toc(tstart)
disp(' ');
disp(['Finished converting api format to table : ' datestr(now())]);
disp('------------------------------------------------------------------');
