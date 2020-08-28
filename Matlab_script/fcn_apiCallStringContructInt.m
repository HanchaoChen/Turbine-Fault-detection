function callString = fcn_apiCallStringContructInt(intArray, preFix)

%construct a call string from an array of integers and provided prefix

if length(intArray) > 1
    callString = [preFix sprintf('%d,', intArray(1:end-1)) sprintf('%d', intArray(end))];
else
    callString= [preFix sprintf('%d', intArray)];
end