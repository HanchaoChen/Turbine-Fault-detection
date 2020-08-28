function fcn_writeTurbineTables(TurbineData, savePath, varargin)

%writes Turbine table to csv files

%INPUT

% TurbineData - Table with all turbine data to write to file
% savePath - the path in which to put the file
% varargin - option specifiers

% varargin options
% should come in pairs
%  'multiFile'  followed by a true or false (default false)
%               if true each instacne is given its own file, if false then all written
%               to one file.  Exception is if more than one farm present in table, this
%               will always be written to seperate files but hasn't been coded yet
%
% 'StatusData'  if this is present is should be followed by a table of the
%               status data.  this will be written to a seperate file suffixed with the
%               word status
% 'fileType'    if this is present it should be followed by a string with
%               either 'csv' or 'mat', this defines if the file is written
%               to csv or mat file format


%set defaults
multiFile = false; %default value
StatusData = table; %default value
writeStatus = false; %default value
fileType = 'csv'; %default value

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
            case 'multiFile'
                if islogical(v2)
                    multiFile = v2;
                else
                    error('Expected Data type logical for multFile');
                end
            case 'StatusData'
                if istable(v2)
                    StatusData = v2;
                    writeStatus = true;
                else
                    error('Expected Data type is table for StatusTable')
                end
            case 'fileType'
                if ischar(v2)
                    fileType = v2;
                else
                    error('Expected Data type string for fileType');
                end
            otherwise
                error(['unexpected input, found : ' v1]);
        end
    end
end

%set the current date for file writing
dateFormat = 'yyyy_mm_dd';
currentDate = datestr(datetime('today'), dateFormat);


%set the file prefix
fPre = 'GECExport_';

%check for number of farms
instanceIDs = categories(TurbineData.instanceID);
farmNames = unique(cellfun(@(x) x(1:3), instanceIDs, 'UniformOutput', false));
if length(farmNames) == 1
    %just one wind farm
    multiFarm = false;
elseif length(farmNames) > 1
    %more than one wind farm
    multiFarm = true;
else
    error('no farm names found');
end

if ~multiFarm
    farmName = farmNames{1};
    if ~multiFile
        %one file one wind farm
        switch fileType
            case 'csv'
                fileName = [fPre farmName '_' datestr(min(TurbineData.ts), dateFormat) '_TO_' datestr(max(TurbineData.ts), dateFormat) '.csv'];
                fullFilePath = [savePath '\' fileName];
                writetable(TurbineData, fullFilePath, 'FileType', 'text', 'Delimiter', ',');
                %if write status then do so
                if writeStatus
                    fileNameStatus = [fPre farmName '_Status_' datestr(min(TurbineData.ts), dateFormat) '_TO_' datestr(max(TurbineData.ts), dateFormat) '.csv']; %keep TurbineData to create the filename so it is consistent
                    fullFilePathStatus = [savePath '\' fileNameStatus];
                    writetable(StatusData, fullFilePathStatus, 'FileType', 'text', 'Delimiter', ',');
                end
            case 'mat'
                fileName = [fPre farmName '_' datestr(min(TurbineData.ts), dateFormat) '_TO_' datestr(max(TurbineData.ts), dateFormat) '.mat'];
                fullFilePath = [savePath '\' fileName];
                if ~writeStatus
                    save(fullFilePath, 'TurbineData');
                else
                    save(fullFilePath, 'TurbineData', 'StatusData');
                end
        end
    else
        %one wind farm multiple files
        for nInstance=1:length(instanceIDs)
            switch fileType
                case 'csv'
                    fileName = [fPre instanceIDs{nInstance} '_' datestr(min(TurbineData(strcmp(TurbineData.instanceID, instanceIDs{nInstance}), :).ts), dateFormat) '_TO_' datestr(max(TurbineData(strcmp(TurbineData.instanceID, instanceIDs{nInstance}), :).ts), dateFormat) '.csv'];
                    fullFilePath = [savePath '\' fileName];
                    writetable(TurbineData(strcmp(TurbineData.instanceID, instanceIDs{nInstance}), :), fullFilePath, 'FileType', 'text', 'Delimiter', ',');
                    %if write status then do so
                    if writeStatus
                        fileNameStatus = [fPre instanceIDs{nInstance} '_Status_' datestr(min(TurbineData(strcmp(TurbineData.instanceID, instanceIDs{nInstance}), :).ts), dateFormat) '_TO_' datestr(max(TurbineData(strcmp(TurbineData.instanceID, instanceIDs{nInstance}), :).ts), dateFormat) '.csv']; %keep using TurbineData for the name so the dates are consistent
                        fullFilePathStatus = [savePath '\' fileNameStatus];
                        writetable(StatusData(strcmp(StatusData.instanceID, instanceIDs{nInstance}), :), fullFilePathStatus, 'FileType', 'text', 'Delimiter', ',');
                    end
                case 'mat'
                    error('Cannot do multifile for matlab file format, well would need to do more coding to make it work');
                    
            end
        end
        
    end
    
else
    error('need to code this');
end


