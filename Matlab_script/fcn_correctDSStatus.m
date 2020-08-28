function Data = fcn_correctDSStatus(Data)

%correct GEC data to UTC from daylight saving

load('daylightSaving.mat', 'DS');

ts_possibleFields = {'ts_start', 'ts_end'};
keyVariables = {'ts', 'instanceID', 'instanceIDGEC'};

for ii=1:length(ts_possibleFields)
    ts_field = ts_possibleFields{ii};    
    if ismember(ts_field, Data.Properties.VariableNames)
        dataYears = unique(year(Data.(ts_field)));
        dataYears(isnan(dataYears)) = [];
        for y=1:length(dataYears)
            %
            dsHours = Data.(ts_field) >= DS{DS.year == dataYears(y), 'ds_start'} & Data.(ts_field) < DS{DS.year == dataYears(y), 'ds_end'};
            Data.(ts_field)(dsHours) = Data.(ts_field)(dsHours) - hours(1);            
        end
    end
end
