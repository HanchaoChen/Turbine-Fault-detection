function varargout = fcn_readApi(varargin)

thisFilePath = mfilename('fullpath');
thisFilePath = thisFilePath(1:max(regexp(thisFilePath, '\', 'end')));
cd(thisFilePath);

TurbineData = table();
StatusData = table();

%%
%depnding on input, either set or ask user for input
if mod(length(varargin), 2) ~= 0
    error('Unexpected number of input value pairs');
elseif isempty(varargin)
    %do nothing as defaults are used
else
    pairsN = length(varargin) / 2;
    for nPair = 1:pairsN
        v1 = varargin{nPair*2 - 1};
        v2 = varargin{nPair*2};
        switch lower(v1)
            case 'includestatus'
                if islogical(v2)
                    includeStatus = v2;
                else
                    error('Expected Data type boolean for includeStatus');
                end
            case 'writefile'
                if isnumeric(v2)
                    writeFile = v2;
                else
                    error('Expected Data type numeric for writeFile');
                end
            case 'apisettingfullfilename'
                if ischar(v2)
                    apiSettingFullFileName = v2;
                else
                    error('Expected Data type string for apiSettingFullFileName');
                end
            otherwise
                error(['unexpected input, found : ' v1]);
        end
    end
end
%%
%%
if exist('includeStatus', 'var') == 0
    if nargout == 2 % no choice givren if two outputs required
        includeStatus = true;
    else
        includeStatus = true;
        uSel = input('Include Status File? Y/N [Y] : ', 's');
        if ~isempty(uSel) && strcmpi(uSel, 'N')
            includeStatus = false;
        end
    end
end

if exist('writeFile', 'var') == 0
    writeFile = 3;
    uSel = input('Save none / .csv / .mat / both? 0/1/2/3 [3] : ');
    if ~isempty(uSel)
        if isnumeric(uSel)
            switch uSel
                case 0
                    writeFile = 0;
                case 1
                    writeFile = 1;
                case 2
                    writeFile = 2;
                case 3
                    writeFile = 3;
            end
        end
    end
end

if exist('apiSettingFullFileName', 'var') == 0
    %select file and read api settig file
    %look for tmp file if it exists
    dirTmpF = 'dirTmpF.mat';
    startDir = pwd;
    fsl = strfind(startDir, filesep);
    dirTempD = [startDir(1:fsl(1)) 'tmp'];
    
    if exist([dirTempD filesep dirTmpF],'file') == 2
        S = load([dirTempD filesep dirTmpF], 'lastPathName');
        startDir = S.lastPathName;
        clear 'S';
    else
        startDir = startDir(1:fsl(1));
    end
    
    [apiSettingFileName, apiSettingPathName] = uigetfile('*.txt', 'Pick Api read input file', startDir);
    if isequal(apiSettingFileName,0) || isequal(apiSettingPathName,0)
        %assign output and quit
        if nargout > 0
            varargout{1} = TurbineData;
            if nargout > 1
                varargout{2} = StatusData;
            end
        end
        return
    else
        if exist(dirTempD,'dir') == 7
            %folder exists, do nothing
        else
            %create directory
            mkdir(dirTempD);
        end
        %save the pathname to the temp file
        lastPathName = apiSettingPathName;
        save([dirTempD filesep dirTmpF], 'lastPathName')
    end
    
    apiSettingFullFileName = [apiSettingPathName apiSettingFileName];
else
    fsl = strfind(apiSettingFullFileName, filesep);
    apiSettingPathName = apiSettingFullFileName(1:fsl(end));
end
%%

%%
if nargout == 2
    % if two outputs requested, then ensure includeStatus is true
    % regardless of what has been selected
    includeStatus = true;
end
%%

%%
%read the settings file
ApiSettings = fcn_readApiSettingFile(apiSettingFullFileName);
%%

%%
%set defaults
Defaults.multiFile = false;
Defaults.outputSavePath = apiSettingPathName;

%check for settings in the api file, if not present then set to defaults
defaultFields = fieldnames(Defaults);
for nDef=1:length(defaultFields)
    if ~isfield(ApiSettings, defaultFields{nDef})
        ApiSettings.(defaultFields{nDef}) = Defaults.(defaultFields{nDef});
    end
end
%%

%%
%get the data from the api
if includeStatus
    [TurbineData, StatusData] = fcn_getDataFromAPI(ApiSettings);    
else
    [TurbineData] = fcn_getDataFromAPI(ApiSettings);
end
%assign output
if nargout > 0
    varargout{1} = TurbineData;
    if nargout > 1
        varargout{2} = StatusData;
    end
end
%%

%%
if writeFile == 1 || writeFile == 3
    % write the file to csv
    if includeStatus
        fcn_writeTurbineTables(TurbineData, ApiSettings.outputSavePath, 'StatusData', StatusData, 'multiFile', ApiSettings.multiFile, 'fileType', 'csv');
    else
        fcn_writeTurbineTables(TurbineData, ApiSettings.outputSavePath, 'multiFile', ApiSettings.multiFile, 'fileType', 'csv');
    end
end
if writeFile == 2 || writeFile == 3
    %write to a .mat file
    if includeStatus
        fcn_writeTurbineTables(TurbineData, ApiSettings.outputSavePath, 'StatusData', StatusData, 'multiFile', ApiSettings.multiFile, 'fileType', 'mat');
    else
        fcn_writeTurbineTables(TurbineData, ApiSettings.outputSavePath, 'multiFile', ApiSettings.multiFile, 'fileType', 'mat');
    end
end
%%


