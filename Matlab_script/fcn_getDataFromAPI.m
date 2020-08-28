function varargout = fcn_getDataFromAPI(ApiSettings)

%get data from an api using the provided settings

% varargout - ig one variable requested, just retrieve turbine data, if 2
% requested then also get status data.

% get the latest mapping tables
instanceMappingTable = fcn_getInstanceMapping(ApiSettings.apiAddress, ApiSettings.apiToken);
signalMappingTable = fcn_getSignalMapping(ApiSettings.apiAddress, ApiSettings.apiToken);

%decide if the data needs to be split into multiple calls
singleLim = 6*24*365*30*10; %numbe of data points that can be retiredved in a single call
%estimate the number of data points asked for
%define the format of the date string, makes assumptions about how the date
%is presented with year then month then day

%decide if the status data needs to be split into multiple calls as it gets
%very slow asking for many turbines at the same time
instancesPerCall = 8;

dateFormat = 'yyyy-MM-dd';
dataDuration = datetime(ApiSettings.tEnd(1:length(dateFormat)), 'InputFormat', dateFormat)-datetime(ApiSettings.tStart(1:length(dateFormat)), 'InputFormat', dateFormat);
if dataDuration < 0
    error('End date cannot be before start date')
end
sSPoints = minutes(dataDuration)/10; %number of data points for a single signal

if ~isfield(ApiSettings, 'instanceIDGECs') %no GEC IDs so need to convert from text
    ApiSettings.instanceIDGECs = instanceMappingTable.instanceIDGEC(cellfun(@(x) find(strcmp(instanceMappingTable.instanceID, x)), ApiSettings.instanceIDGECsText));
end

%work out total number of data points
instanceIDGECs = ApiSettings.instanceIDGECs;
instancesN = length(instanceIDGECs);


if ~isfield(ApiSettings, 'signalIDGECs') %no GEC IDs so need to convert from text
    ApiSettings.signalIDGECs = signalMappingTable.signalID(cellfun(@(x) find(strcmp(signalMappingTable.name, x)), ApiSettings.signalIDText));
    
end
signalIDGECs = ApiSettings.signalIDGECs;
%work out how many signals can be in each call
signalsPerCall = floor(singleLim/(sSPoints*length(instanceIDGECs)));

%conduct each call and join tables
keyVariables = {'ts', 'instanceID', 'instanceIDGEC'};

%the callType, aggregate and calcualtion are fixed for this type of data
%read, so asign these into the api settings.  historically this may be
%present in the api setting file and this will overright what is already
%there (without affecting the original file).
ApiSettings.callType = 'data.json?';
ApiSettings.aggregate = 'device';
ApiSettings.calculation = 'average';

%the instance ID call sring is common no matter how many calls
instanceIDsCallString = fcn_apiCallStringContructInt(instanceIDGECs, 'deviceIds=');
%web options are common to all webread
opts = weboptions('Timeout', inf);


turbineReadComplete = false;
singleSignalCall = false;

tryLim = 10; %number of times to try reading api before throwing error
while ~turbineReadComplete
    
    if singleSignalCall
        signalsPerCall = 1;
    end
    
    if signalsPerCall >=1
        if length(signalIDGECs) > 1
            signalCallIndex = [(1:signalsPerCall:length(signalIDGECs)); (signalsPerCall:signalsPerCall:length(signalIDGECs)-1), length(signalIDGECs)]';
        else
            signalCallIndex = [1, 1];
        end
    else
        error('not enough signals to split down, need to split by instance also, havent codes this yet')
    end
    
    
    for nCall = 1:size(signalCallIndex, 1)
        turbineReadComplete = false; % set false at the start of every loop
        
        signalIDsCallString = fcn_apiCallStringContructInt(signalIDGECs(signalCallIndex(nCall, 1):signalCallIndex(nCall, 2)), 'dataSignalIds=');
        
        %construct api call string
        ApiCallString = [ApiSettings.apiAddress '/' ApiSettings.callType instanceIDsCallString '&' signalIDsCallString '&aggregate=' ApiSettings.aggregate '&calculation=' ApiSettings.calculation '&apiToken=' ApiSettings.apiToken '&timestampStart=' ApiSettings.tStart '&timestampEnd=' ApiSettings.tEnd '&resolution=' ApiSettings.resolution];
        
        tstart = tic();
        disp(' ')
        disp('-------------------------------------------------------------------')
        disp(['Started Reading from api at  : ' datestr(now())]);
        disp(' ')
        disp(instanceIDsCallString);
        disp(signalIDsCallString);
        disp(['From : ' ApiSettings.tStart ' To : ' ApiSettings.tEnd]);
        disp(' ')
        %read api
        %try to read tryLim number of times before resorting to throwing warning
        %and errors        
        dBr = false;
        for ii=1:tryLim            
            try
                Data = webread(ApiCallString, opts);
            catch e
                if ii == tryLim
                    %if already a single signal call, then re-throw the error as
                    %nothing i can do at the moment
                    if singleSignalCall || length(signalIDGECs) == 1
                        throw(e)
                    else
                        if strcmp(e.message, 'Format error in gzip content: "Error while processing content unencoding: incorrect data check"')
                            %problems possibly asking for too much from the api, so have to
                            %split call into one for every signal
                            warning('Issue with reading Turbine data from API for this site, splitting into single call per signal which will take longer');
                            singleSignalCall = true;
                            dBr = true;
                            break %break out of the loop so that the instances per call can be re-set
                        else
                            throw(e)
                        end
                    end
                else
                    continue % failed to read api, but havent tried enough times yet, so try again
                end
            end
            break % succesfully read from api, so no need to do another iteration
        end
        if dBr
            break
        end
        toc(tstart)
        disp(' ')
        disp(['Finished Reading from api at : ' datestr(now())]);
        disp('-------------------------------------------------------------------')
        
        
        %convert into table format, join if further calls are made
        if nCall == 1
            TurbineData = fcn_apiCalltoTable(Data, instanceMappingTable, signalMappingTable);
        else
            TurbineData = innerjoin(TurbineData, fcn_apiCalltoTable(Data, instanceMappingTable, signalMappingTable), 'key', keyVariables);
        end
        turbineReadComplete = true; % only set to true if this point is reached
    end
end

%re order call to be the same as signal call
[sSel, sSelO] = ismember(signalMappingTable.signalID, signalIDGECs);
signalIDs = signalMappingTable.nameMatlab(sSel);
signalIDs(sSelO(sSel)) = signalIDs;

TurbineData = TurbineData(:, [keyVariables'; signalIDs]);

TurbineData = sortrows(TurbineData, {'ts', 'instanceID'}); %sort by time stamp then instance ID

%check if all of the first or last entries for all entries is nan, if this
%is the case the remove fom table as it means data requested is out of the
%available range most likely.
invalidVals = isnan(TurbineData{:, 4:end});
if all(invalidVals(1:instancesN, :), 'all')
    %find the first valid    
    firstValid = find(any(~invalidVals, 2), 1);
    if isempty(firstValid)
        %no valid entries so return blank table
        TurbineData = table();        
    else
        %select from the first turbine, as first valid might not be the first
        %turbine
        firstValid = find(TurbineData.ts == TurbineData.ts(firstValid) & TurbineData.instanceIDGEC == instanceIDGECs(1), 1);
        TurbineData = TurbineData(firstValid:end, :);
    end
end
if ~isempty(TurbineData)
    invalidVals = isnan(TurbineData{:, 4:end});
    if all(invalidVals(end-instancesN+1:end, :), 'all')
        %find the last valid
        lastValid = height(TurbineData) - find(flip(any(~invalidVals, 2)), 1)+ 1;
        %select from the last turbine, as the last valid might not be the last
        %turbine
        lastValid = find(TurbineData.ts == TurbineData.ts(lastValid) & TurbineData.instanceIDGEC == instanceIDGECs(end));
        TurbineData = TurbineData(1:lastValid, :);
    end
    %remove any unused categories from Turbine Data
    TurbineData.instanceID = removecats(TurbineData.instanceID);
end

varargout{1} = TurbineData;

if nargout > 1
    
    statusReadComplete = false;
    singleInstanceCall = false;
    while ~statusReadComplete
        
        if singleInstanceCall
            instancesPerCall = 1;
        end
        
        if length(instanceIDGECs) > 1
            instanceCallIndex = [(1:instancesPerCall:length(instanceIDGECs)); (instancesPerCall:instancesPerCall:length(instanceIDGECs)-1), length(instanceIDGECs)]';
        else
            instanceCallIndex = [1, 1];
        end
        
        for nCall=1:size(instanceCallIndex, 1)
            statusReadComplete = false; %set to false at the start of every loop
            instanceIDsCallString = fcn_apiCallStringContructInt(instanceIDGECs(instanceCallIndex(nCall, 1):instanceCallIndex(nCall, 2)), 'deviceIds=');
            
            %read the status information
            pageSize = 1e7;
            ApiSettings.callType = 'status.json?'; %change the call type to status
            ApiCallString = [ApiSettings.apiAddress '/' ApiSettings.callType instanceIDsCallString '&pageSize=' int2str(pageSize) '&apiToken=' ApiSettings.apiToken '&timestampStart=' ApiSettings.tStart '&timestampEnd=' ApiSettings.tEnd];
            tstart = tic();
            disp(' ')
            disp('-------------------------------------------------------------------')
            disp(['Started Reading Status from api at  : ' datestr(now())]);
            disp(' ')
            disp(instanceIDsCallString);
            disp(['From : ' ApiSettings.tStart ' To : ' ApiSettings.tEnd]);
            disp(' ')
            %need put in a try loop in case of api read error
            dBr = false;
            for ii=1:tryLim
                try
                    Data = webread(ApiCallString, opts);
                catch e
                    if ii == tryLim
                        %if already a single instance call, then re-throw the error as
                        %nothing i can do at the moment
                        if singleInstanceCall || length(instanceIDGECs) == 1
                            throw(e)
                        else
                            if strcmp(e.message, 'Format error in gzip content: "Error while processing content unencoding: incorrect data check"')
                                %problems possibly asking for too much from the api, so have to
                                %split call into one for every instance
                                warning('Issue with reading Status from API for this site, splitting into single call per instance which will take longer');
                                singleInstanceCall = true;
                                dBr = true; %boolean to break out of second loop
                                break %break out of the loop so that the instances per call can be re-set
                            else
                                throw(e)
                            end
                        end
                    else
                        continue %try again untill try limit reached
                    end
                end
                break
            end
            if dBr
                break
            end
            toc(tstart)
            disp(' ')
            disp(['Finished Reading Status from api at : ' datestr(now())]);
            disp('-------------------------------------------------------------------')
            if length(Data) >= pageSize
                error('number of status point returned is greater than the requested page length')
            end
            
            %convert into table format, join if further calls are made
            if nCall == 1
                StatusData = fcn_apiStatusCalltoTable(Data, instanceMappingTable);
            else
                StatusData = [StatusData; fcn_apiStatusCalltoTable(Data, instanceMappingTable)];%#ok
            end
            statusReadComplete = true; % only becomes true is this line of code reached
        end
    end
    if ~isempty(StatusData)
        StatusData = sortrows(StatusData, {'ts_start', 'instanceID'}); %sort the staus by start date and then instance
        StatusData.instanceID = removecats(StatusData.instanceID);
    end
    
    varargout{2} = StatusData;
    
    
end


