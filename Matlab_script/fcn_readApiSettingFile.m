function ApiSettings = fcn_readApiSettingFile(fullFilePath)

delim = ',';
qChar = '"';
lct = '...'; % line ocntinue text

%defaults if missing

ApiSettings.apiAddress = 'https://ventient.greenbyte.cloud/api/2.0';
ApiSettings.apiToken = 'e9073eb6579a4e6882071cd4aada02d8';
ApiSettings.callType = 'data.json?';
ApiSettings.aggregate = 'device';
ApiSettings.calculation = 'average';
ApiSettings.resolution = '10minute';

fileID = fopen(fullFilePath);
readText = textscan(fileID, '%s','Delimiter','\n');
fclose(fileID);
readText = readText{1, 1};

settingIDNamePossible = {'apiAddress', 'apiToken', 'callType', 'aggregate', 'calculation', 'resolution', 'tStart', 'tEnd', 'instanceIDGECs', 'signalIDGECs', 'multiFile'};

settingIDNameValidI = cellfun(@(y) any(cellfun(@(x) contains(y, x), settingIDNamePossible)), readText);

[settingIDs, ~] = strtok(readText, delim);

[~, inputText] = strtok(readText(settingIDNameValidI), delim);

inputText(settingIDNameValidI) = inputText;
inputText(~settingIDNameValidI) = readText(~settingIDNameValidI);


for settingID =1:length(settingIDs)
    settingIDName = settingIDs{settingID};
    switch  settingIDName
        case 'apiAddress'
            %take the next entry on line
            ApiSettings.apiAddress = strtrim(strtok(inputText{settingID}, delim));
        case 'apiToken'
            %take the next entry on line
            ApiSettings.apiToken = strtrim(strtok(inputText{settingID}, delim));
        case 'callType'
            %take the next entry on line
            ApiSettings.callType = strtrim(strtok(inputText{settingID}, delim));
        case 'aggregate'
            %take the next entry on line
            ApiSettings.aggregate = strtrim(strtok(inputText{settingID}, delim));
        case 'calculation'
            %take the next entry on line
            ApiSettings.calculation = strtrim(strtok(inputText{settingID}, delim));
        case 'resolution'
            %take the next entry on line
            ApiSettings.resolution = strtrim(strtok(inputText{settingID}, delim));
        case 'tStart'
            %take the next entry on line
            ApiSettings.tStart = strtrim(strtok(inputText{settingID}, delim));
        case 'tEnd'
            %take the next entry on line
            ApiSettings.tEnd = strtrim(strtok(inputText{settingID}, delim));
        case 'instanceIDGECs'
            instSeek = true;
            ii = 0;
            instanceIDGECs = {};
            while instSeek 
                %split at the delimter and remove empty cells (caused by extra
                %occurences of delimter
                instanceIDGECsConst = strsplit(inputText{settingID+ii}, delim);
                instanceIDGECsConst(cellfun(@isempty, instanceIDGECsConst)) = [];
                %append
                instanceIDGECs = [instanceIDGECs, instanceIDGECsConst]; %#ok
                %if the last entry is the line continue text then append
                %continue in loop, otherwise break
                if strcmp(instanceIDGECs{end}, lct)
                    instanceIDGECs(end) = [];
                    ii=ii+1;
                    continue
                else
                    break
                end
            end
            instanceIDGECs = strtrim(instanceIDGECs); % remove whitspace
            if all(cellfun(@(x) all(isstrprop(x,'digit')), instanceIDGECs))
                instanceIDGECs = cellfun(@str2num, instanceIDGECs);  % convert to numbers
                ApiSettings.instanceIDGECs = instanceIDGECs;
            elseif ischar(instanceIDGECs{1})
                ApiSettings.instanceIDGECsText = strtrim(instanceIDGECs); %leave as text, trim leading and trailing whitespace
            end
            
        case 'signalIDGECs'
            sigSeek = true;
            ii = 0;
            signalIDGECs = {};
            while sigSeek
                %split at the delimter and remove empty cells (caused by extra
                %occurences of delimter.  Ignot any delimters that are between
                %the quotation character
                qChars = reshape(regexp(inputText{settingID+ii}, qChar), 2, length(regexp(inputText{settingID+ii}, qChar))/2)'; %fid any quote characters
                delims = regexp(inputText{settingID+ii}, delim); %find the delimters
                ignorsDelims = arrayfun(@(x) any(x > qChars(:, 1) & x < qChars(:, 2)), delims); %delimters to ignore
                delims = delims(~ignorsDelims); %select only relevent delimiters
                if ~isempty(delims)
                    if delims(end) == length(inputText{settingID+ii})
                        delimRange = num2cell([delims+1; [delims(2:end) length(inputText{settingID+ii})]-1]', 2); %change to cell array of ranges
                    else
                        delimRange = num2cell([delims+1; [delims(2:end) length(inputText{settingID+ii})+1]-1]', 2); %change to cell array of ranges
                    end
                    if delims(1) ~= 1
                        delimRange = [[1, delims(1)-1];delimRange]; %#ok
                    end
                    signalIDGECsConst = cellfun(@(x) inputText{settingID+ii}(x(1):x(2)), delimRange, 'UniformOutput', false)'; %split into these ranges
                else
                    signalIDGECsConst = inputText(settingID+ii);
                end
                signalIDGECsConst = cellfun(@(x) strrep(x, qChar, ''), signalIDGECsConst, 'UniformOutput', false); %remove quote character
                signalIDGECsConst(cellfun(@isempty, signalIDGECsConst)) = [];
                
                signalIDGECs = [signalIDGECs,  signalIDGECsConst]; %#ok
                if strcmp(signalIDGECs{end}, lct)
                    signalIDGECs(end) = [];
                    ii=ii+1;
                    continue
                else
                    break
                end
                
            end
            signalIDGECs = strtrim(signalIDGECs);
            if all(cellfun(@(x) all(isstrprop(x,'digit')), signalIDGECs))
                signalIDGECs = cellfun(@str2num, signalIDGECs); % convert to numbers
                ApiSettings.signalIDGECs = signalIDGECs;
            elseif ischar(signalIDGECs{1})
                ApiSettings.signalIDText = strtrim(signalIDGECs); %leave as text, trim leading and trailing whitespace
            end
            
        case 'multiFile'
            %look for true, text, if not true then assumes false
            if strcmpi(strtrim(strtok(inputText{settingID}, delim)), 'true')
                ApiSettings.multiFile = true;
            else
                ApiSettings.multiFile = false;
            end
        otherwise
    end
end
