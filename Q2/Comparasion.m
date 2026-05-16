clear; clc; close all;
%% 读取数据
cd('C:\Users\LCY\Desktop\学习\课余\比赛\美赛\正式比赛\Data');
data = readtable('weekly_percentages_ranks_with_votes_combined.csv', ...
                 'Delimiter', ',', ...
                 'HeaderLines', 0, ...
                 'ReadVariableNames', true);

%% 提取关键信息
seasons = data.season;
elimination_week = data.elimination_week;
is_withdrew = data.is_withdrew;
celebrity_names = data.x__elebrity_name;

% 找出所有季节
uniqueSeasons = unique(seasons);
numSeasons = length(uniqueSeasons);

% 准备每周数据
max_week = 11;
weeklyPercents = zeros(height(data), max_week);
weeklyRanks = zeros(height(data), max_week);

for w = 1:max_week
    pct_col = sprintf('week%d_pct', w);
    rank_col = sprintf('week%d_rank', w);
    
    if ismember(pct_col, data.Properties.VariableNames)
        weeklyPercents(:, w) = data.(pct_col);
    end
    
    if ismember(rank_col, data.Properties.VariableNames)
        weeklyRanks(:, w) = data.(rank_col);
    end
end

% 准备评委原始分数
numJudges = 4;
scores = zeros(height(data), max_week * numJudges);

for w = 1:max_week
    for j = 1:numJudges
        col_name = sprintf('week%d_judge%d_score', w, j);
        if ismember(col_name, data.Properties.VariableNames)
            col_idx = (w-1)*numJudges + j;
            scores(:, col_idx) = data.(col_name);
        end
    end
end

%% 初始化结果列
percent_predictions = cell(height(data), 1);  % 方法1预测：淘汰周
rank_predictions = cell(height(data), 1);     % 方法2预测：淘汰周
percent_rank = zeros(height(data), 1);        % 方法1排名
rank_rank = zeros(height(data), 1);           % 方法2排名

%% 方法1: 百分比相加预测（每一周都预测）
fprintf('\n========== 方法1: 百分比相加预测 ==========\n');

for s_idx = 1:numSeasons
    current_season = uniqueSeasons(s_idx);
    season_mask = (seasons == current_season);
    season_indices = find(season_mask);
    
    % 找出该季节的最大淘汰周数
    elim_weeks = elimination_week(season_indices);
    valid_elim_weeks = elim_weeks(elim_weeks ~= Inf & ~isnan(elim_weeks));
    
    if isempty(valid_elim_weeks)
        max_elim_week_season = max_week;
    else
        max_elim_week_season = max(max_week, max(valid_elim_weeks));
    end
    
    % 该季节选手总数
    n = sum(season_mask);
    
    % 初始化排名计数器
    current_rank = n;  % 总人数，最后淘汰的是冠军
    
    % 正向遍历每一周
    for w = 1:max_elim_week_season
        % 找出该周仍在比赛中的选手
        % 条件：淘汰周数 >= w，或者淘汰周数 == w 但还没被标记
        still_in_mask = false(length(season_indices), 1);
        for i = 1:length(season_indices)
            idx = season_indices(i);
            if elimination_week(idx) >= w
                % 还没被淘汰
                still_in_mask(i) = true;
            elseif elimination_week(idx) == w - 1 && isempty(percent_predictions{idx})
                % 上周刚被淘汰但还没标记
                still_in_mask(i) = true;
            end
        end
        
        still_in_idx = season_indices(still_in_mask);
        
        if length(still_in_idx) <= 1
            % 如果只剩1人或更少，这周不淘汰
            continue;
        end
        
        % 提取该周的百分比数据
        week_pct = weeklyPercents(still_in_idx, w);
        
        % 处理缺失数据
        if all(isnan(week_pct))
            % 如果全部缺失，使用排名数据
            week_ranks_data = weeklyRanks(still_in_idx, w);
            if all(isnan(week_ranks_data))
                % 如果排名也缺失，随机选择
                [~, min_idx] = min(rand(length(still_in_idx), 1));
            else
                week_ranks_data(isnan(week_ranks_data)) = max(week_ranks_data) + 1;
                [~, max_idx] = max(week_ranks_data);
                min_idx = max_idx;
            end
        else
            week_pct(isnan(week_pct)) = min(week_pct) - 1;
            [~, min_idx] = min(week_pct);
        end
        
        % 记录预测结果
        predicted_elim_idx = still_in_idx(min_idx);
        week_key = sprintf('%d_%d', current_season, w);
        percent_predictions{predicted_elim_idx} = week_key;
        percent_rank(predicted_elim_idx) = current_rank;
        current_rank = current_rank - 1;
        
        fprintf('季节 %d, 第 %d 周: 预测淘汰 %s (名次: %d)\n', ...
                current_season, w, ...
                celebrity_names{predicted_elim_idx}, ...
                percent_rank(predicted_elim_idx));
    end
    
    % 剩余选手（没被预测淘汰的）名次记为0
    remaining_idx = season_indices(cellfun(@isempty, percent_predictions(season_indices)));
    for idx = remaining_idx'
        percent_rank(idx) = 0;
    end
end

%% 方法2: 排名相加预测（每一周都预测）
fprintf('\n========== 方法2: 排名相加预测 ==========\n');

for s_idx = 1:numSeasons
    current_season = uniqueSeasons(s_idx);
    season_mask = (seasons == current_season);
    season_indices = find(season_mask);
    
    % 找出该季节的最大淘汰周数
    elim_weeks = elimination_week(season_indices);
    valid_elim_weeks = elim_weeks(elim_weeks ~= Inf & ~isnan(elim_weeks));
    
    if isempty(valid_elim_weeks)
        max_elim_week_season = max_week;
    else
        max_elim_week_season = max(max_week, max(valid_elim_weeks));
    end
    
    % 该季节选手总数
    n = sum(season_mask);
    
    % 初始化排名计数器
    current_rank = n;
    
    % 正向遍历每一周
    for w = 1:max_elim_week_season
        % 找出该周仍在比赛中的选手
        still_in_mask = false(length(season_indices), 1);
        for i = 1:length(season_indices)
            idx = season_indices(i);
            if elimination_week(idx) >= w
                still_in_mask(i) = true;
            elseif elimination_week(idx) == w - 1 && isempty(rank_predictions{idx})
                still_in_mask(i) = true;
            end
        end
        
        still_in_idx = season_indices(still_in_mask);
        
        if length(still_in_idx) <= 1
            continue;
        end
        
        % 提取该周的排名数据
        week_ranks_data = weeklyRanks(still_in_idx, w);
        
        % 处理缺失数据
        if all(isnan(week_ranks_data))
            % 如果排名缺失，使用百分比数据
            week_pct = weeklyPercents(still_in_idx, w);
            if all(isnan(week_pct))
                % 如果百分比也缺失，随机选择
                [~, max_idx] = max(rand(length(still_in_idx), 1));
            else
                week_pct(isnan(week_pct)) = min(week_pct) - 1;
                [~, min_idx] = min(week_pct);
                max_idx = min_idx;
            end
        else
            % 直接找出排名最差的选手
            week_ranks_data(isnan(week_ranks_data)) = max(week_ranks_data) + 1;
            [~, max_idx] = max(week_ranks_data); % 排名值越大表示表现越差
        end
        
        % 记录预测结果
        predicted_elim_idx = still_in_idx(max_idx);
        week_key = sprintf('%d_%d', current_season, w);
        rank_predictions{predicted_elim_idx} = week_key;
        rank_rank(predicted_elim_idx) = current_rank;
        current_rank = current_rank - 1;
        
        fprintf('季节 %d, 第 %d 周: 预测淘汰 %s (名次: %d)\n', ...
                current_season, w, ...
                celebrity_names{predicted_elim_idx}, ...
                rank_rank(predicted_elim_idx));
    end
    
    % 剩余选手名次记为0
    remaining_idx = season_indices(cellfun(@isempty, rank_predictions(season_indices)));
    for idx = remaining_idx'
        rank_rank(idx) = 0;
    end
end

%% 将结果添加到表格
data.percent_predicted = percent_predictions;
data.percent_rank = percent_rank;
data.rank_predicted = rank_predictions;
data.rank_rank = rank_rank;

%% 计算三种一致性
fprintf('\n========== 一致性计算 ==========\n');

% 1. 两种预测方法之间的一致性（预测 vs 预测）
fprintf('\n1. 两种预测方法之间的一致性:\n');

% 统计每周两种预测是否一致
prediction_consistency = 0;
total_weeks_with_prediction = 0;

for s_idx = 1:numSeasons
    current_season = uniqueSeasons(s_idx);
    season_mask = (seasons == current_season);
    
    % 找出该季节的最大周数
    elim_weeks = elimination_week(season_mask);
    valid_weeks = elim_weeks(elim_weeks ~= Inf & ~isnan(elim_weeks));
    
    if isempty(valid_weeks)
        max_week_season = max_week;
    else
        max_week_season = max(max_week, max(valid_weeks));
    end
    
    for w = 1:max_week_season
        % 找出该周两种方法的预测结果
        week_key = sprintf('%d_%d', current_season, w);
        
        percent_pred_idx = find(strcmp(percent_predictions, week_key), 1);
        rank_pred_idx = find(strcmp(rank_predictions, week_key), 1);
        
        if ~isempty(percent_pred_idx) && ~isempty(rank_pred_idx)
            total_weeks_with_prediction = total_weeks_with_prediction + 1;
            
            if percent_pred_idx == rank_pred_idx
                prediction_consistency = prediction_consistency + 1;
            end
        end
    end
end

if total_weeks_with_prediction > 0
    pred_consistency_ratio = prediction_consistency / total_weeks_with_prediction;
    fprintf('   预测周数: %d\n', total_weeks_with_prediction);
    fprintf('   预测一致周数: %d\n', prediction_consistency);
    fprintf('   预测一致性比例: %.2f%%\n', pred_consistency_ratio * 100);
end

% 2. 预测与实际淘汰的一致性（每种方法单独计算）
fprintf('\n2. 预测与实际淘汰的一致性:\n');

% 找出所有实际淘汰（排除withdrew和Inf）
actual_elim_mask = (elimination_week ~= Inf) & (elimination_week > 0) & (is_withdrew == 0);
actual_elim_indices = find(actual_elim_mask);
num_actual_elim = length(actual_elim_indices);

% 方法1 vs 实际
percent_vs_actual = 0;
for i = 1:num_actual_elim
    idx = actual_elim_indices(i);
    season_num = seasons(idx);
    week_num = elimination_week(idx);
    
    week_key = sprintf('%d_%d', season_num, week_num);
    percent_pred_idx = find(strcmp(percent_predictions, week_key), 1);
    
    if ~isempty(percent_pred_idx) && percent_pred_idx == idx
        percent_vs_actual = percent_vs_actual + 1;
    end
end

% 方法2 vs 实际
rank_vs_actual = 0;
for i = 1:num_actual_elim
    idx = actual_elim_indices(i);
    season_num = seasons(idx);
    week_num = elimination_week(idx);
    
    week_key = sprintf('%d_%d', season_num, week_num);
    rank_pred_idx = find(strcmp(rank_predictions, week_key), 1);
    
    if ~isempty(rank_pred_idx) && rank_pred_idx == idx
        rank_vs_actual = rank_vs_actual + 1;
    end
end

fprintf('   实际淘汰人数: %d\n', num_actual_elim);
fprintf('   方法1预测正确: %d (%.2f%%)\n', percent_vs_actual, percent_vs_actual/num_actual_elim*100);
fprintf('   方法2预测正确: %d (%.2f%%)\n', rank_vs_actual, rank_vs_actual/num_actual_elim*100);

% 3. 完全一致性（两种预测都与实际一致）
fprintf('\n3. 完全一致性（两种预测都与实际一致）:\n');

both_correct = 0;
for i = 1:num_actual_elim
    idx = actual_elim_indices(i);
    season_num = seasons(idx);
    week_num = elimination_week(idx);
    
    week_key = sprintf('%d_%d', season_num, week_num);
    percent_pred_idx = find(strcmp(percent_predictions, week_key), 1);
    rank_pred_idx = find(strcmp(rank_predictions, week_key), 1);
    
    if ~isempty(percent_pred_idx) && ~isempty(rank_pred_idx) && ...
       percent_pred_idx == idx && rank_pred_idx == idx
        both_correct = both_correct + 1;
    end
end

fprintf('   完全一致周数: %d (%.2f%%)\n', both_correct, both_correct/num_actual_elim*100);

%% 按季节统计预测准确率
fprintf('\n========== 按季节统计预测准确率 ==========\n');
fprintf('季节 | 总人数 | 方法1正确 | 方法2正确 | 完全一致\n');
fprintf('-----|--------|-----------|-----------|----------\n');

for s_idx = 1:numSeasons
    current_season = uniqueSeasons(s_idx);
    season_mask = (seasons == current_season);
    
    % 该季节的实际淘汰
    season_actual_mask = season_mask & actual_elim_mask;
    season_actual_indices = find(season_actual_mask);
    
    if isempty(season_actual_indices)
        continue;
    end
    
    season_percent_correct = 0;
    season_rank_correct = 0;
    season_both_correct = 0;
    
    for i = 1:length(season_actual_indices)
        idx = season_actual_indices(i);
        season_num = seasons(idx);
        week_num = elimination_week(idx);
        
        week_key = sprintf('%d_%d', season_num, week_num);
        percent_pred_idx = find(strcmp(percent_predictions, week_key), 1);
        rank_pred_idx = find(strcmp(rank_predictions, week_key), 1);
        
        if ~isempty(percent_pred_idx) && percent_pred_idx == idx
            season_percent_correct = season_percent_correct + 1;
        end
        
        if ~isempty(rank_pred_idx) && rank_pred_idx == idx
            season_rank_correct = season_rank_correct + 1;
        end
        
        if ~isempty(percent_pred_idx) && ~isempty(rank_pred_idx) && ...
           percent_pred_idx == idx && rank_pred_idx == idx
            season_both_correct = season_both_correct + 1;
        end
    end
    
    total_in_season = sum(season_mask);
    fprintf('%4d | %6d | %9d | %9d | %8d\n', ...
            current_season, total_in_season, ...
            season_percent_correct, season_rank_correct, season_both_correct);
end

%% 保存结果
output_filename = 'weekly_data_with_all_predictions_final.csv';
writetable(data, output_filename);
fprintf('\n结果已保存到: %s\n', output_filename);

%% 显示统计摘要
fprintf('\n========== 统计摘要 ==========\n');
fprintf('总选手数: %d\n', height(data));
fprintf('有实际淘汰的选手: %d\n', num_actual_elim);
fprintf('被方法1预测淘汰的选手: %d\n', sum(~cellfun(@isempty, percent_predictions)));
fprintf('被方法2预测淘汰的选手: %d\n', sum(~cellfun(@isempty, rank_predictions)));
fprintf('名次为0的选手（方法1）: %d\n', sum(percent_rank == 0));
fprintf('名次为0的选手（方法2）: %d\n', sum(rank_rank == 0));
%% ========== 计算三种规则下的FII（粉丝影响力指数） ==========
fprintf('\n========== 计算三种规则的FII ==========\n');

% 方法1：排名法 (Rank-based)
% 方法2：百分比法 (Percent-based)
% 方法3：裁判选择法 (Judge's choice from bottom two) - 模拟

% 初始化存储FII的数组
fii_rank = zeros(height(data), 1);    % 排名法FII
fii_percent = zeros(height(data), 1); % 百分比法FII
fii_judge_choice = zeros(height(data), 1); % 裁判选择法FII

% 存储每周的FII值用于分析
fii_rank_weekly = [];
fii_percent_weekly = [];
fii_judge_choice_weekly = [];
week_indices = [];

% 定义裁判选择法的模拟方式：从排名最差的两名选手中选择裁判分数最低的淘汰

for s_idx = 1:numSeasons
    current_season = uniqueSeasons(s_idx);
    season_mask = (seasons == current_season);
    season_indices = find(season_mask);
    
    % 找出该季节的最大淘汰周数
    elim_weeks = elimination_week(season_indices);
    valid_elim_weeks = elim_weeks(elim_weeks ~= Inf & ~isnan(elim_weeks));
    
    if isempty(valid_elim_weeks)
        max_elim_week_season = max_week;
    else
        max_elim_week_season = max(max_week, max(valid_elim_weeks));
    end
    
    n = sum(season_mask);
    
    % 每周计算FII
    for w = 1:max_elim_week_season
        % 找出该周仍在比赛中的选手
        still_in_mask = false(length(season_indices), 1);
        for i = 1:length(season_indices)
            idx = season_indices(i);
            if elimination_week(idx) >= w
                still_in_mask(i) = true;
            elseif elimination_week(idx) == w - 1
                % 上周刚被淘汰，这周不在
                still_in_mask(i) = false;
            end
        end
        
        still_in_idx = season_indices(still_in_mask);
        
        if length(still_in_idx) <= 1
            continue;
        end
        
        % 获取数据
        week_ranks_data = weeklyRanks(still_in_idx, w);
        week_pct_data = weeklyPercents(still_in_idx, w);
        
        % 获取裁判原始分数
        colStart = (w-1)*numJudges + 1;
        colEnd = colStart + numJudges - 1;
        week_scores = nansum(scores(still_in_idx, colStart:colEnd), 2);
        
        % 计算裁判排名和粉丝排名
        % 裁判排名：分数越高排名越好
        [~, judge_rank_idx] = sort(week_scores, 'descend');
        judge_rank = zeros(length(still_in_idx), 1);
        for i = 1:length(judge_rank_idx)
            judge_rank(judge_rank_idx(i)) = i;
        end
        
        % 粉丝排名：百分比越高排名越好（对于百分比法）
        if ~all(isnan(week_pct_data))
            week_pct_data_filled = week_pct_data;
            week_pct_data_filled(isnan(week_pct_data_filled)) = min(week_pct_data_filled) - 1;
            [~, fan_rank_pct_idx] = sort(week_pct_data_filled, 'descend');
            fan_rank_pct = zeros(length(still_in_idx), 1);
            for i = 1:length(fan_rank_pct_idx)
                fan_rank_pct(fan_rank_pct_idx(i)) = i;
            end
        else
            % 如果百分比数据缺失，使用排名数据
            week_ranks_filled = week_ranks_data;
            week_ranks_filled(isnan(week_ranks_filled)) = max(week_ranks_filled) + 1;
            [~, fan_rank_pct_idx] = sort(week_ranks_filled, 'ascend');
            fan_rank_pct = zeros(length(still_in_idx), 1);
            for i = 1:length(fan_rank_pct_idx)
                fan_rank_pct(fan_rank_pct_idx(i)) = i;
            end
        end
        
        % 粉丝排名：排名数据（对于排名法）
        if ~all(isnan(week_ranks_data))
            week_ranks_filled = week_ranks_data;
            week_ranks_filled(isnan(week_ranks_filled)) = max(week_ranks_filled) + 1;
            [~, fan_rank_rank_idx] = sort(week_ranks_filled, 'descend');
            fan_rank_rank = zeros(length(still_in_idx), 1);
            for i = 1:length(fan_rank_rank_idx)
                fan_rank_rank(fan_rank_rank_idx(i)) = i;
            end
        else
            % 如果排名数据缺失，使用百分比数据
            fan_rank_rank = fan_rank_pct;
        end
        
        % 计算最终排名（根据三种方法）
        
        % 1. 排名法最终排名
        total_rank_score = judge_rank + fan_rank_rank;
        [~, final_rank_rank_idx] = sort(total_rank_score, 'ascend');
        final_rank_rank = zeros(length(still_in_idx), 1);
        for i = 1:length(final_rank_rank_idx)
            final_rank_rank(final_rank_rank_idx(i)) = i;
        end
        
        % 2. 百分比法最终排名
        total_pct_score = zeros(length(still_in_idx), 1);
        for i = 1:length(still_in_idx)
            if ~isnan(week_pct_data(i))
                % 裁判百分比 = 裁判分数占比
                judge_pct = week_scores(i) / sum(week_scores);
                % 粉丝百分比（需要估计）
                fan_pct_est = fan_rank_pct(i); % 这里简化处理
                total_pct_score(i) = judge_pct + fan_pct_est;
            else
                total_pct_score(i) = Inf; % 缺失数据排名最后
            end
        end
        [~, final_rank_pct_idx] = sort(total_pct_score, 'descend');
        final_rank_pct = zeros(length(still_in_idx), 1);
        for i = 1:length(final_rank_pct_idx)
            final_rank_pct(final_rank_pct_idx(i)) = i;
        end
        
        % 3. 裁判选择法最终排名
        % 模拟：找出排名最差的两名，然后裁判选择分数最低的淘汰
        % 这里我们假设裁判总是选择两人中分数最低的
        
        % 计算每个选手的综合排名（裁判和粉丝）
        combined_rank = (judge_rank + fan_rank_rank) / 2;
        
        % 找出综合排名最差的两个
        [~, sorted_idx] = sort(combined_rank, 'descend');
        bottom_two_idx = sorted_idx(1:min(2, length(sorted_idx)));
        
        % 在这两个中找出裁判分数最低的
        if length(bottom_two_idx) == 2
            if week_scores(bottom_two_idx(1)) < week_scores(bottom_two_idx(2))
                eliminated_idx_judge = bottom_two_idx(1);
            else
                eliminated_idx_judge = bottom_two_idx(2);
            end
        else
            eliminated_idx_judge = bottom_two_idx(1);
        end
        
        % 构建最终排名：被淘汰的排名最后，其他按综合排名
        final_rank_judge = zeros(length(still_in_idx), 1);
        for i = 1:length(still_in_idx)
            if i == eliminated_idx_judge
                final_rank_judge(i) = length(still_in_idx);
            else
                % 其他选手按综合排名排序
                final_rank_judge(i) = find(sorted_idx == i);
            end
        end
        
        % 计算FII
        for i = 1:length(still_in_idx)
            idx_global = still_in_idx(i);
            
            % 排名法FII
            Dj_rank = abs(judge_rank(i) - final_rank_rank(i));
            Df_rank = abs(fan_rank_rank(i) - final_rank_rank(i));
            denominator_rank = Dj_rank + Df_rank;
            if denominator_rank > 0
                fii_rank_val = Dj_rank / denominator_rank;
            else
                fii_rank_val = 0.5;
            end
            fii_rank(idx_global) = fii_rank_val;
            
            % 百分比法FII
            Dj_percent = abs(judge_rank(i) - final_rank_pct(i));
            Df_percent = abs(fan_rank_pct(i) - final_rank_pct(i));
            denominator_percent = Dj_percent + Df_percent;
            if denominator_percent > 0
                fii_percent_val = Dj_percent / denominator_percent;
            else
                fii_percent_val = 0.5;
            end
            fii_percent(idx_global) = fii_percent_val;
            
            % 裁判选择法FII
            Dj_judge = abs(judge_rank(i) - final_rank_judge(i));
            Df_judge = abs(fan_rank_rank(i) - final_rank_judge(i));
            denominator_judge = Dj_judge + Df_judge;
            if denominator_judge > 0
                fii_judge_val = Dj_judge / denominator_judge;
            else
                fii_judge_val = 0.5;
            end
            fii_judge_choice(idx_global) = fii_judge_val;
        end
        
        % 存储该周的平均FII值
        valid_fii_rank = fii_rank(still_in_idx);
        valid_fii_percent = fii_percent(still_in_idx);
        valid_fii_judge = fii_judge_choice(still_in_idx);
        
        fii_rank_weekly = [fii_rank_weekly; mean(valid_fii_rank)];
        fii_percent_weekly = [fii_percent_weekly; mean(valid_fii_percent)];
        fii_judge_choice_weekly = [fii_judge_choice_weekly; mean(valid_fii_judge)];
        week_indices = [week_indices; current_season*100 + w]; % 编码为赛季周数
        
        if w == 1 && s_idx <= 5 % 只打印前5个赛季第1周的信息
            fprintf('季节 %d, 第 %d 周: 平均FII - 排名法: %.3f, 百分比法: %.3f, 裁判选择法: %.3f\n', ...
                    current_season, w, ...
                    mean(valid_fii_rank), mean(valid_fii_percent), mean(valid_fii_judge));
        end
    end
end

% 将FII值添加到数据表中
data.fii_rank = fii_rank;
data.fii_percent = fii_percent;
data.fii_judge_choice = fii_judge_choice;

%% ========== FII统计分析 ==========
fprintf('\n========== FII统计分析 ==========\n');

% 移除无效数据（FII=0.5且没有比赛）
valid_mask = (fii_rank ~= 0.5) | (fii_percent ~= 0.5) | (fii_judge_choice ~= 0.5);
fii_rank_valid = fii_rank(valid_mask);
fii_percent_valid = fii_percent(valid_mask);
fii_judge_valid = fii_judge_choice(valid_mask);

% 基本统计
fprintf('\n1. 整体FII统计:\n');
fprintf('   方法\t\t平均值\t标准差\t中位数\t>0.5比例\t>0.6比例\n');
fprintf('   -----------------------------------------------------------------\n');

methods = {'排名法', '百分比法', '裁判选择法'};
fii_data = {fii_rank_valid, fii_percent_valid, fii_judge_valid};

for i = 1:3
    data_current = fii_data{i};
    mean_val = mean(data_current);
    std_val = std(data_current);
    median_val = median(data_current);
    prop_gt_05 = sum(data_current > 0.5) / length(data_current);
    prop_gt_06 = sum(data_current > 0.6) / length(data_current);
    
    fprintf('   %s\t%.3f\t%.3f\t%.3f\t%.1f%%\t\t%.1f%%\n', ...
            methods{i}, mean_val, std_val, median_val, ...
            prop_gt_05*100, prop_gt_06*100);
end

% 按季节统计
fprintf('\n2. 按季节统计平均FII:\n');
fprintf('   季节\t排名法\t百分比法\t裁判选择法\t最粉丝友好的方法\n');
fprintf('   -------------------------------------------------------------\n');

for s_idx = 1:numSeasons
    current_season = uniqueSeasons(s_idx);
    season_mask = (seasons == current_season) & valid_mask;
    
    if sum(season_mask) > 0
        fii_rank_season = fii_rank(season_mask);
        fii_percent_season = fii_percent(season_mask);
        fii_judge_season = fii_judge_choice(season_mask);
        
        mean_rank = mean(fii_rank_season);
        mean_percent = mean(fii_percent_season);
        mean_judge = mean(fii_judge_season);
        
        [max_val, max_idx] = max([mean_rank, mean_percent, mean_judge]);
        
        if max_idx == 1
            best_method = '排名法';
        elseif max_idx == 2
            best_method = '百分比法';
        else
            best_method = '裁判选择法';
        end
        
        fprintf('   %2d\t%.3f\t%.3f\t\t%.3f\t\t%s\n', ...
                current_season, mean_rank, mean_percent, mean_judge, best_method);
    end
end

%% ========== FII可视化 ==========
fprintf('\n========== 生成FII可视化图表 ==========\n');

prop_fan_driven = [
    sum(fii_rank_valid > 0.5) / length(fii_rank_valid);
    sum(fii_percent_valid > 0.5) / length(fii_percent_valid);
    sum(fii_judge_valid > 0.5) / length(fii_judge_valid);
] * 100;


%% 按季节的FII趋势图
figure('Position', [100, 100, 900, 400]);

% 准备数据：按季节计算平均FII
season_fii_rank = zeros(numSeasons, 1);
season_fii_percent = zeros(numSeasons, 1);
season_fii_judge = zeros(numSeasons, 1);

for s_idx = 1:numSeasons
    current_season = uniqueSeasons(s_idx);
    season_mask = (seasons == current_season) & valid_mask;
    
    if sum(season_mask) > 0
        season_fii_rank(s_idx) = mean(fii_rank(season_mask));
        season_fii_percent(s_idx) = mean(fii_percent(season_mask));
        season_fii_judge(s_idx) = mean(fii_judge_choice(season_mask));
    else
        season_fii_rank(s_idx) = NaN;
        season_fii_percent(s_idx) = NaN;
        season_fii_judge(s_idx) = NaN;
    end
end

% 绘制折线图
hold on;
plot(uniqueSeasons, season_fii_rank, 'b-o', 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', 'b');
plot(uniqueSeasons, season_fii_percent, 'r-s', 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', 'r');
plot(uniqueSeasons, season_fii_judge, 'g-^', 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', 'g');
hold off;

% 设置图表属性
xlabel('Season', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Average FII', 'FontSize', 12, 'FontWeight', 'bold');
title('Seasonal Trend of Fan Influence Index (FII)', 'FontSize', 14, 'FontWeight', 'bold');
legend({'Rank-Based', 'Percent-Based', 'Judge-Choice'}, 'Location', 'best');
grid on;
ylim([0, 1]);

% 添加参考线
hold on;
plot(xlim, [0.5, 0.5], 'k--', 'LineWidth', 1.5);
hold off;

% 添加数据标签（每隔3个季节显示一次）
for s_idx = 1:3:numSeasons
    if ~isnan(season_fii_rank(s_idx))
        text(uniqueSeasons(s_idx), season_fii_rank(s_idx)+0.03, sprintf('%.2f', season_fii_rank(s_idx)), ...
             'HorizontalAlignment', 'center', 'FontSize', 8, 'Color', 'b');
    end
    if ~isnan(season_fii_percent(s_idx))
        text(uniqueSeasons(s_idx), season_fii_percent(s_idx)-0.03, sprintf('%.2f', season_fii_percent(s_idx)), ...
             'HorizontalAlignment', 'center', 'FontSize', 8, 'Color', 'r');
    end
end

saveas(gcf, 'charts/seasonal_fii_trend.png');
fprintf('季节FII趋势图已保存到: charts/seasonal_fii_trend.png\n');


%% 保存更新后的数据
output_filename_fii = 'weekly_data_with_fii_analysis.csv';
writetable(data, output_filename_fii);
fprintf('\n包含FII分析的数据已保存到: %s\n', output_filename_fii);

%% 总结FII分析结果
fprintf('\n========== FII分析总结 ==========\n');
fprintf('1. 最粉丝友好的方法: ');
[~, max_mean_idx] = max([mean(fii_rank_valid), mean(fii_percent_valid), mean(fii_judge_valid)]);
switch max_mean_idx
    case 1
        fprintf('排名法 (平均FII: %.3f)\n', mean(fii_rank_valid));
    case 2
        fprintf('百分比法 (平均FII: %.3f)\n', mean(fii_percent_valid));
    case 3
        fprintf('裁判选择法 (平均FII: %.3f)\n', mean(fii_judge_valid));
end

fprintf('2. 粉丝影响力主导比例最高的方法: ');
[~, max_prop_idx] = max(prop_fan_driven);
switch max_prop_idx
    case 1
        fprintf('排名法 (%.1f%%)\n', prop_fan_driven(1));
    case 2
        fprintf('百分比法 (%.1f%%)\n', prop_fan_driven(2));
    case 3
        fprintf('裁判选择法 (%.1f%%)\n', prop_fan_driven(3));
end

fprintf('3. FII稳定性最好的方法: ');
[~, min_std_idx] = min([std(fii_rank_valid), std(fii_percent_valid), std(fii_judge_valid)]);
switch min_std_idx
    case 1
        fprintf('排名法 (标准差: %.3f)\n', std(fii_rank_valid));
    case 2
        fprintf('百分比法 (标准差: %.3f)\n', std(fii_percent_valid));
    case 3
        fprintf('裁判选择法 (标准差: %.3f)\n', std(fii_judge_valid));
end

fprintf('\n4. 建议:\n');
fprintf('   - 如果希望增加粉丝参与感: 使用%s\n', methods{max_mean_idx});
fprintf('   - 如果希望平衡裁判专业性和粉丝意见: 使用裁判选择法\n');
fprintf('   - 如果希望结果更稳定可预测: 使用%s\n', methods{min_std_idx});
%% 可视化部分：每个季度的预测准确性
fprintf('\n========== 生成季度预测准确性图表 ==========\n');

% 准备存储每个季节的准确性数据
season_numbers = [];
season_percent_accuracy = [];
season_rank_accuracy = [];
season_both_accuracy = [];

% 收集数据
for s_idx = 1:numSeasons
    current_season = uniqueSeasons(s_idx);
    season_mask = (seasons == current_season);
    
    % 该季节的实际淘汰
    season_actual_mask = season_mask & actual_elim_mask;
    season_actual_indices = find(season_actual_mask);
    
    if isempty(season_actual_indices)
        continue;
    end
    
    season_percent_correct = 0;
    season_rank_correct = 0;
    season_both_correct = 0;
    
    for i = 1:length(season_actual_indices)
        idx = season_actual_indices(i);
        season_num = seasons(idx);
        week_num = elimination_week(idx);
        
        week_key = sprintf('%d_%d', season_num, week_num);
        percent_pred_idx = find(strcmp(percent_predictions, week_key), 1);
        rank_pred_idx = find(strcmp(rank_predictions, week_key), 1);
        
        if ~isempty(percent_pred_idx) && percent_pred_idx == idx
            season_percent_correct = season_percent_correct + 1;
        end
        
        if ~isempty(rank_pred_idx) && rank_pred_idx == idx
            season_rank_correct = season_rank_correct + 1;
        end
        
        if ~isempty(percent_pred_idx) && ~isempty(rank_pred_idx) && ...
           percent_pred_idx == idx && rank_pred_idx == idx
            season_both_correct = season_both_correct + 1;
        end
    end
    
    season_total = length(season_actual_indices);
    if season_total > 0
        season_numbers(end+1) = current_season;
        season_percent_accuracy(end+1) = season_percent_correct / season_total * 100;
        season_rank_accuracy(end+1) = season_rank_correct / season_total * 100;
        season_both_accuracy(end+1) = season_both_correct / season_total * 100;
    end
end

%% 图1：季度预测准确性折线图（主要图表）
figure('Position', [100, 100, 900, 400]);

% 子图1：折线图
subplot(1, 2, 1);
hold on;
grid on;

% 绘制三条折线
plot(season_numbers, season_percent_accuracy, 'b-o', 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', 'b');
plot(season_numbers, season_rank_accuracy, 'r-s', 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', 'r');
plot(season_numbers, season_both_accuracy, 'g-^', 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', 'g');

% 设置图表属性
xlabel('Season', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Prediction Accuracy (%)', 'FontSize', 12, 'FontWeight', 'bold');
title('Prediction Accuracy by Season (Line Chart)', 'FontSize', 14, 'FontWeight', 'bold');
legend({'Percent Method', 'Rank Method', 'Both Correct'}, 'Location', 'best', 'FontSize', 10);
xlim([min(season_numbers)-0.5, max(season_numbers)+0.5]);
ylim([0, 100]);
set(gca, 'FontSize', 10);

% 添加数据标签
for i = 1:length(season_numbers)
    text(season_numbers(i), season_percent_accuracy(i)+2, sprintf('%.1f%%', season_percent_accuracy(i)), ...
        'HorizontalAlignment', 'center', 'FontSize', 8, 'Color', 'b');
    text(season_numbers(i), season_rank_accuracy(i)-3, sprintf('%.1f%%', season_rank_accuracy(i)), ...
        'HorizontalAlignment', 'center', 'FontSize', 8, 'Color', 'r');
end

%% 图2：季度预测准确性直方图（分组柱状图）
subplot(1, 2, 2);
hold on;

% 设置柱状图参数
bar_width = 0.25;
x_positions = 1:length(season_numbers);

% 绘制分组柱状图
bar1 = bar(x_positions - bar_width, season_percent_accuracy, bar_width, 'FaceColor', 'b', 'EdgeColor', 'k');
bar2 = bar(x_positions, season_rank_accuracy, bar_width, 'FaceColor', 'r', 'EdgeColor', 'k');
bar3 = bar(x_positions + bar_width, season_both_accuracy, bar_width, 'FaceColor', 'g', 'EdgeColor', 'k');

% 设置图表属性
set(gca, 'XTick', x_positions, 'XTickLabel', season_numbers);
xlabel('Season', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Prediction Accuracy (%)', 'FontSize', 12, 'FontWeight', 'bold');
title('Prediction Accuracy by Season (Bar Chart)', 'FontSize', 14, 'FontWeight', 'bold');
legend({'Percent Method', 'Rank Method', 'Both Correct'}, 'Location', 'best', 'FontSize', 10);
ylim([0, 100]);
grid on;
set(gca, 'FontSize', 10);

% 添加柱状图数值标签
for i = 1:length(season_numbers)
    text(x_positions(i) - bar_width, season_percent_accuracy(i) + 1, sprintf('%.1f', season_percent_accuracy(i)), ...
        'HorizontalAlignment', 'center', 'FontSize', 8, 'FontWeight', 'bold');
    text(x_positions(i), season_rank_accuracy(i) + 1, sprintf('%.1f', season_rank_accuracy(i)), ...
        'HorizontalAlignment', 'center', 'FontSize', 8, 'FontWeight', 'bold');
    text(x_positions(i) + bar_width, season_both_accuracy(i) + 1, sprintf('%.1f', season_both_accuracy(i)), ...
        'HorizontalAlignment', 'center', 'FontSize', 8, 'FontWeight', 'bold');
end

% 使用suptitle替代sgtitle（兼容旧版本）
try
    sgtitle('Seasonal Prediction Accuracy Analysis', 'FontSize', 16, 'FontWeight', 'bold');
catch
    % 如果sgtitle不存在，使用annotation
    annotation('textbox', [0.4, 0.95, 0.2, 0.05], 'String', 'Seasonal Prediction Accuracy Analysis', ...
        'FontSize', 16, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'middle', 'LineStyle', 'none');
end

%% 保存图表
% 创建图表保存目录
if ~exist('charts', 'dir')
    mkdir('charts');
end

% 保存主要图表
saveas(gcf, 'charts/season_prediction_accuracy.png');
fprintf('\n图表已保存到: charts/season_prediction_accuracy.png\n');

%% 输出季度准确性数据表格
fprintf('\n========== 季度预测准确性数据表 ==========\n');
fprintf('Season | Players | Percent Method | Rank Method | Both Correct | Difference\n');
fprintf('-------|---------|----------------|-------------|--------------|-----------\n');

for i = 1:length(season_numbers)
    season_num = season_numbers(i);
    season_mask = (seasons == season_num);
    
    % 该季节的总选手数
    total_players = sum(season_mask);
    
    % 该季节的实际淘汰选手数
    season_actual_mask = season_mask & actual_elim_mask;
    actual_players = sum(season_actual_mask);
    
    % 计算预测差异
    accuracy_diff = season_percent_accuracy(i) - season_rank_accuracy(i);
    
    fprintf('  %2d   |   %3d   |     %6.1f%%    |   %6.1f%%   |    %6.1f%%   |  %+6.1f%%\n', ...
            season_num, actual_players, ...
            season_percent_accuracy(i), ...
            season_rank_accuracy(i), ...
            season_both_accuracy(i), ...
            accuracy_diff);
end

%% 整体统计
fprintf('\n========== 整体统计摘要 ==========\n');
fprintf('Average Percent Method Accuracy: %.1f%%\n', mean(season_percent_accuracy));
fprintf('Average Rank Method Accuracy: %.1f%%\n', mean(season_rank_accuracy));
fprintf('Average Both Correct Accuracy: %.1f%%\n', mean(season_both_accuracy));
fprintf('\nSeasons where Percent Method is better: %d\n', sum(season_percent_accuracy > season_rank_accuracy));
fprintf('Seasons where Rank Method is better: %d\n', sum(season_rank_accuracy > season_percent_accuracy));
fprintf('Seasons where both methods are equal: %d\n', sum(season_percent_accuracy == season_rank_accuracy));

% 生成单独的折线图和直方图（可选）

% 单独折线图
figure('Position', [100, 100, 600, 400]);
plot(season_numbers, season_percent_accuracy, 'b-o', 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', 'b');
hold on;
plot(season_numbers, season_rank_accuracy, 'r-s', 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', 'r');
plot(season_numbers, season_both_accuracy, 'g-^', 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', 'g');
hold off;

xlabel('Season', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Prediction Accuracy (%)', 'FontSize', 12, 'FontWeight', 'bold');
title('Prediction Accuracy by Season', 'FontSize', 14, 'FontWeight', 'bold');
legend({'Percent Method', 'Rank Method', 'Both Correct'}, 'Location', 'best');
grid on;
xlim([min(season_numbers)-0.5, max(season_numbers)+0.5]);
ylim([0, 100]);

saveas(gcf, 'charts/prediction_accuracy_line.png');

% 单独直方图
figure('Position', [100, 100, 600, 400]);
bar(x_positions - bar_width, season_percent_accuracy, bar_width, 'FaceColor', 'b', 'EdgeColor', 'k');
hold on;
bar(x_positions, season_rank_accuracy, bar_width, 'FaceColor', 'r', 'EdgeColor', 'k');
bar(x_positions + bar_width, season_both_accuracy, bar_width, 'FaceColor', 'g', 'EdgeColor', 'k');
hold off;

set(gca, 'XTick', x_positions, 'XTickLabel', season_numbers);
xlabel('Season', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Prediction Accuracy (%)', 'FontSize', 12, 'FontWeight', 'bold');
title('Prediction Accuracy by Season', 'FontSize', 14, 'FontWeight', 'bold');
legend({'Percent Method', 'Rank Method', 'Both Correct'}, 'Location', 'best');
grid on;
ylim([0, 100]);

saveas(gcf, 'charts/prediction_accuracy_bar.png');

%% 计算排名差异的斯皮尔曼相关系数热图（季节×周）
fprintf('\n========== 排名差异的斯皮尔曼相关系数热图 ==========\n');

% 找出所有季节的最大周数
max_weeks_all = zeros(numSeasons, 1);
for s_idx = 1:numSeasons
    current_season = uniqueSeasons(s_idx);
    season_mask = (seasons == current_season);
    elim_weeks = elimination_week(season_mask);
    valid_weeks = elim_weeks(elim_weeks ~= Inf & ~isnan(elim_weeks));
    
    if isempty(valid_weeks)
        max_weeks_all(s_idx) = max_week;
    else
        max_weeks_all(s_idx) = max(max_week, max(valid_weeks));
    end
end

% 确定热图的大小（最大季节数 × 最大周数）
max_season_num = max(uniqueSeasons);
max_week_num = min(max(max_weeks_all), max_week); % 取实际存在的最大周数

% 初始化存储每周排名差异的矩阵
weekly_rank_diff_corr = zeros(max_season_num, max_week_num);

% 对每个季节，计算每周的排名差异
for season_num = 1:max_season_num
    season_mask = (seasons == season_num);
    season_indices = find(season_mask);
    
    if isempty(season_indices)
        continue; % 跳过不存在的季节
    end
    
    n = length(season_indices);
    
    % 获取该季节的实际周数
    elim_weeks = elimination_week(season_indices);
    valid_weeks = elim_weeks(elim_weeks ~= Inf & ~isnan(elim_weeks));
    
    if isempty(valid_weeks)
        season_max_week = max_week;
    else
        season_max_week = min(max(valid_weeks), max_week);
    end
    
    % 初始化每周的排名数据
    weekly_percent_ranks = zeros(n, season_max_week);
    weekly_rank_ranks = zeros(n, season_max_week);
    
    % 填充每周的排名数据
    for w = 1:season_max_week
        % 获取该周两种方法的预测排名
        week_percent_ranks = zeros(n, 1);
        week_rank_ranks = zeros(n, 1);
        
        for i = 1:n
            idx = season_indices(i);
            
            % 方法1：百分比预测排名
            if percent_rank(idx) > 0
                week_percent_ranks(i) = percent_rank(idx);
            else
                week_percent_ranks(i) = 0; % 名次为0表示没被淘汰
            end
            
            % 方法2：排名预测排名
            if rank_rank(idx) > 0
                week_rank_ranks(i) = rank_rank(idx);
            else
                week_rank_ranks(i) = 0;
            end
        end
        
        % 存储到周矩阵中
        weekly_percent_ranks(:, w) = week_percent_ranks;
        weekly_rank_ranks(:, w) = week_rank_ranks;
    end
    
    % 计算每周的斯皮尔曼相关系数
    for w = 1:season_max_week
        % 获取该周的有效数据（排除全零的情况）
        week_p_ranks = weekly_percent_ranks(:, w);
        week_r_ranks = weekly_rank_ranks(:, w);
        
        % 检查是否有有效数据
        valid_idx = (week_p_ranks > 0) & (week_r_ranks > 0);
        
        if sum(valid_idx) >= 2 % 至少需要2个数据点计算相关系数
            valid_p_ranks = week_p_ranks(valid_idx);
            valid_r_ranks = week_r_ranks(valid_idx);
            
            % 计算斯皮尔曼相关系数
            try
                rho = corr(valid_p_ranks, valid_r_ranks, 'Type', 'Spearman');
                weekly_rank_diff_corr(season_num, w) = rho;
            catch
                weekly_rank_diff_corr(season_num, w) = 0;
            end
        else
            weekly_rank_diff_corr(season_num, w) = 0;
        end
    end
    
    % 输出该季节的相关系数统计
    non_zero_corr = weekly_rank_diff_corr(season_num, weekly_rank_diff_corr(season_num, :) ~= 0);
    if ~isempty(non_zero_corr)
        fprintf('季节 %2d: 平均相关系数 = %.3f, 最大值 = %.3f, 最小值 = %.3f\n', ...
                season_num, mean(non_zero_corr), max(non_zero_corr), min(non_zero_corr));
    end
end

%% 生成热图
figure('Position', [100, 100, 1000, 600]);

% 创建热图
imagesc(weekly_rank_diff_corr);
colormap(jet); % 使用jet色彩映射
colorbar;
caxis([-1, 1]); % 相关系数范围是-1到1

% 设置坐标轴标签
xlabel('Week Number', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Season Number', 'FontSize', 12, 'FontWeight', 'bold');
title('Spearman Correlation Heatmap: Rank Difference (Season × Week)', ...
      'FontSize', 14, 'FontWeight', 'bold');

% 设置坐标轴刻度
set(gca, 'XTick', 1:max_week_num, 'YTick', 1:max_season_num);
set(gca, 'XTickLabel', 1:max_week_num, 'YTickLabel', 1:max_season_num);

% 在热图上显示数值
for season = 1:max_season_num
    for week = 1:max_week_num
        corr_value = weekly_rank_diff_corr(season, week);
        if corr_value ~= 0
            % 根据背景色选择文本颜色
            if abs(corr_value) > 0.5
                text_color = 'w';
            else
                text_color = 'k';
            end
            
            text(week, season, sprintf('%.2f', corr_value), ...
                 'HorizontalAlignment', 'center', ...
                 'VerticalAlignment', 'middle', ...
                 'FontSize', 8, ...
                 'Color', text_color, ...
                 'FontWeight', 'bold');
        end
    end
end

% 添加网格
grid on;
set(gca, 'GridColor', 'k', 'GridAlpha', 0.3, 'LineWidth', 0.5);

%% 保存热图
saveas(gcf, 'charts/spearman_correlation_heatmap.png');
fprintf('\n斯皮尔曼相关系数热图已保存到: charts/spearman_correlation_heatmap.png\n');

%% 图3：简单的单线折线图 - 季度预测准确度波动
figure('Position', [100, 100, 800, 400]);

% 使用百分比预测法的准确度作为主要指标
plot(season_numbers, season_percent_accuracy, 'b-o', 'LineWidth', 2.5, ...
     'MarkerSize', 10, 'MarkerFaceColor', 'b', 'MarkerEdgeColor', 'k');

% 设置图表属性
xlabel('Season Number', 'FontSize', 14, 'FontWeight', 'bold');
ylabel('Prediction Accuracy (%)', 'FontSize', 14, 'FontWeight', 'bold');
title('Seasonal Prediction Accuracy Trend (Percent Method)', 'FontSize', 16, 'FontWeight', 'bold');

% 设置坐标轴
xlim([min(season_numbers)-0.5, max(season_numbers)+0.5]);
ylim([0, 100]);
grid on;

% 添加数据点标签
for i = 1:length(season_numbers)
    text(season_numbers(i), season_percent_accuracy(i)+3, ...
         sprintf('%.1f%%', season_percent_accuracy(i)), ...
         'HorizontalAlignment', 'center', 'FontSize', 10, ...
         'FontWeight', 'bold', 'Color', 'b');
end

% 添加趋势线
hold on;
% 线性拟合趋势线
p = polyfit(season_numbers, season_percent_accuracy, 1);
trend_line = polyval(p, season_numbers);
plot(season_numbers, trend_line, 'r--', 'LineWidth', 2);
hold off;

% 添加图例
legend({'Prediction Accuracy', sprintf('Trend Line (slope=%.3f)', p(1))}, ...
       'Location', 'best', 'FontSize', 11);

% 保存图表
saveas(gcf, 'charts/single_line_prediction_accuracy.png');
fprintf('单线预测准确度折线图已保存到: charts/single_line_prediction_accuracy.png\n');

%% 计算波动统计
fprintf('\n========== 季度预测准确度波动分析 ==========\n');
fprintf('平均准确度: %.1f%%\n', mean(season_percent_accuracy));
fprintf('标准差: %.2f\n', std(season_percent_accuracy));
fprintf('波动范围: %.1f%% - %.1f%%\n', min(season_percent_accuracy), max(season_percent_accuracy));
fprintf('最高准确度的季节: %d (%.1f%%)\n', season_numbers(season_percent_accuracy == max(season_percent_accuracy)), max(season_percent_accuracy));
fprintf('最低准确度的季节: %d (%.1f%%)\n', season_numbers(season_percent_accuracy == min(season_percent_accuracy)), min(season_percent_accuracy));