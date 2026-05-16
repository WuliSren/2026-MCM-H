clear; clc; close all;
%% 读取数据
cd('C:\Users\LCY\Desktop\学习\课余\比赛\美赛\正式比赛\Data')
filename = '2026_MCM_Problem_C_Data.csv';
data = readtable(filename, 'Delimiter', ',');

%% 将评委分数列转换为 double 类型
judge_cols = contains(data.Properties.VariableNames, 'judge') & ...
             contains(data.Properties.VariableNames, 'score');
for col = find(judge_cols)
    if iscell(data.(col))
        data.(col) = str2double(data.(col));
    end
end

%% 1. 处理缺失的第四位评委分数（每周只有一个N/A则删除该列）
for i = 1:size(data, 1)
    for j = 1:11 % 假设最多11周
        week_cols = judge_cols & contains(data.Properties.VariableNames, sprintf('week%d', j));
        if sum(week_cols) == 4 % 如果有4个评委列
            scores = table2array(data(i, week_cols));
            if sum(isnan(scores)) == 1 % 如果只有一个NaN
                % 找到NaN的位置并设为0
                nan_idx = isnan(scores);
                scores(nan_idx) = NaN;
                data{i, week_cols} = scores;
            elseif sum(isnan(scores)) >= 2 % 如果有两个及以上NaN
                data{i, week_cols} = NaN(1, 4); % 整周设为NaN
            end
        end
    end
end

%% 2. 处理缺失的州信息（用国家/地区填充）
if iscell(data.celebrity_homestate)
    missing_state = cellfun(@isempty, data.celebrity_homestate);
else
    missing_state = isnumeric(data.celebrity_homestate) & isnan(data.celebrity_homestate);
end

% 确保数据是cell类型
if isnumeric(data.celebrity_homecountry_region)
    country_data = num2cell(data.celebrity_homecountry_region);
else
    country_data = data.celebrity_homecountry_region;
end

data.celebrity_homestate(missing_state) = country_data(missing_state);

%% 3. 删除淘汰后的周次（选手淘汰后所有后续周次分数设为NaN）

% 只处理评委分数列
for col = find(judge_cols)
    % 获取当前列数据
    col_data = data{:, col};
    
    % 将0值替换为NaN
    if isnumeric(col_data)
        col_data(col_data == 0) = NaN;
        data{:, col} = col_data;
    end
end

%% 显示处理后的数据信息
fprintf('处理后的数据行数：%d\n', size(data, 1));
fprintf('赛季数：%d\n', max(season_groups));

%% 保存处理后的数据
writetable(data, 'processed_data.csv');

