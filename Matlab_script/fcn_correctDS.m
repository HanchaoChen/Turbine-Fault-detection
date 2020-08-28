function Data = fcn_correctDS(Data)

%correct GEC data to UTC from daylight saving

load('daylightSaving.mat', 'DS');

ts_possibleFields = {'ts'};
keyVariables = {'ts', 'instanceID', 'instanceIDGEC'};

for ii=1:length(ts_possibleFields)
    ts_field = ts_possibleFields{ii};
    if ismember(ts_field, Data.Properties.VariableNames)
        dataYears = unique(year(Data.(ts_field)));
        dataYears(isnan(dataYears)) = [];
        for y=1:length(dataYears)
            %get the hour of nan values when the clocks go forward
            forwardHour = Data.(ts_field) >= DS{DS.year == dataYears(y), 'ds_start'} & Data.(ts_field) < DS{DS.year == dataYears(y), 'ds_start'} + hours(1);            
            %remove the hour of nan values
            Data(forwardHour, :) = [];
            %get the index of daylight saving hours
            dsHours = Data.(ts_field) >= DS{DS.year == dataYears(y), 'ds_start'} & Data.(ts_field) < DS{DS.year == dataYears(y), 'ds_end'};
            %set these back to UTC
            Data.(ts_field)(dsHours) = Data.(ts_field)(dsHours) - hours(1);
            
            unKnownHour = Data.(ts_field) >= DS{DS.year == dataYears(y), 'ds_end'} - hours(2) & Data.(ts_field) < DS{DS.year == dataYears(y), 'ds_end'} - hours(1);
            if any(unKnownHour) %only correct if there is an unknown hour
                nonKeyCols = ~cellfun(@(x) any(strcmp(x, keyVariables)), Data.Properties.VariableNames);
                %replace values with nan in new hour midnight to 1 am as we
                %don't know if this is UTC or GMT
                Data{unKnownHour, nonKeyCols} = nan;
                %add in an hours of nan values for between 1-2am where we don't
                %have any data
                extraHour = Data(unKnownHour, :);
                extraHour.(ts_field) = extraHour.(ts_field) + hours(1);
                Data = [Data(1:find(unKnownHour, 1, 'last'), :);extraHour;Data(find(unKnownHour, 1, 'last')+1:end, :)];
            end
        end
    end
end
