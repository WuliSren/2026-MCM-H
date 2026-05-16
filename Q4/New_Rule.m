%% 动态公平性投票系统验证分析 - 修复版本
% 针对特定选手：Jerry Rice, Billy Ray Cyrus, Bristol Palin, Bobby Bones
% 验证新方法是否会让他们提前淘汰

clear; clc; close all;

%% 1. 加载数据并检查数据类型
filename = 'weekly_percentages_ranks_with_votes_combined.csv';
data = readtable(filename);

% 显示列信息
fprintf('=== 数据列信息 ===\n');
disp(data.Properties.VariableNames');

% 检查season列的数据类型
if iscell(data.season)
    fprintf('season列是cell类型，转换为数值...\n');
    season_numeric = zeros(height(data), 1);
    for i = 1:height(data)
        if isnumeric(data.season{i})
            season_numeric(i) = data.season{i};
        else
            season_numeric(i) = str2double(data.season{i});
        end
    end
    data.season_numeric = season_numeric;
else
    fprintf('season列是数值类型\n');
    data.season_numeric = data.season;
end

% 检查其他关键列
if iscell(data.placement)
    fprintf('placement列是cell类型，转换为数值...\n');
    placement_numeric = zeros(height(data), 1);
    for i = 1:height(data)
        if isnumeric(data.placement{i})
            placement_numeric(i) = data.placement{i};
        else
            placement_numeric(i) = str2double(data.placement{i});
        end
    end
    data.placement_numeric = placement_numeric;
else
    data.placement_numeric = data.placement;
end

if iscell(data.elimination_week)
    fprintf('elimination_week列是cell类型，转换为数值...\n');
    elim_numeric = zeros(height(data), 1);
    for i = 1:height(data)
        if ischar(data.elimination_week{i})
            if strcmpi(data.elimination_week{i}, 'Inf')
                elim_numeric(i) = Inf;
            else
                elim_numeric(i) = str2double(data.elimination_week{i});
            end
        elseif isnumeric(data.elimination_week{i})
            elim_numeric(i) = data.elimination_week{i};
        end
    end
    data.elimination_week_numeric = elim_numeric;
else
    data.elimination_week_numeric = data.elimination_week;
end

if iscell(data.is_withdrew)
    fprintf('is_withdrew列是cell类型，转换为数值...\n');
    withdrew_numeric = zeros(height(data), 1);
    for i = 1:height(data)
        if isnumeric(data.is_withdrew{i})
            withdrew_numeric(i) = data.is_withdrew{i};
        else
            withdrew_numeric(i) = str2double(data.is_withdrew{i});
        end
    end
    data.is_withdrew_numeric = withdrew_numeric;
else
    data.is_withdrew_numeric = data.is_withdrew;
end

% 定义要分析的选手（注意：Bobby Bones不在数据集中，我们需要找到其他类似选手）
target_celebrities = {
    'Jerry Rice',       % Season 2, runner up despite low judge scores
    'Billy Ray Cyrus',  % Season 4, 5th despite last place judge scores
    'Bristol Palin',    % Season 11, 3rd with lowest judge scores 12 times
    % 查找第27季或其他类似情况的选手
    'Bobby Bones'       % Season 27, winner despite low judge scores (可能不在数据中)
};

fprintf('\n=== 动态公平性投票系统验证分析 ===\n');
fprintf('目标选手:\n');
for i = 1:length(target_celebrities)
    fprintf('%d. %s\n', i, target_celebrities{i});
end

%% 2. 为每个选手进行分析
results_table = table();

for celeb_idx = 1:length(target_celebrities)
    target_name = target_celebrities{celeb_idx};
    
    % 找到选手数据（不区分大小写）
    name_matches = zeros(height(data), 1);
    for i = 1:height(data)
        if ischar(data.x__elebrity_name{i})
            name_matches(i) = contains(lower(data.x__elebrity_name{i}), lower(target_name));
        end
    end
    
    celeb_mask = logical(name_matches);
    
    if ~any(celeb_mask)
        fprintf('\n警告：未找到选手 %s 的数据，尝试查找类似选手...\n', target_name);
        
        % 尝试查找类似情况的选手
        if strcmp(target_name, 'Bobby Bones')
            % 查找其他"评委评分低但排名高"的选手
            fprintf('查找类似Bobby Bones的选手（评委评分低但排名高）...\n');
            
            % 先显示所有选手
            fprintf('数据集中的选手列表（前20名）:\n');
            unique_names = unique(data.x__elebrity_name);
            for i = 1:min(20, length(unique_names))
                fprintf('%d. %s\n', i, unique_names{i});
            end
            
            % 手动选择一个类似选手，比如"Master P"（第2季，评委评分低但观众投票支持）
            target_name = 'Master P';
            name_matches = zeros(height(data), 1);
            for i = 1:height(data)
                if ischar(data.x__elebrity_name{i})
                    name_matches(i) = contains(lower(data.x__elebrity_name{i}), lower(target_name));
                end
            end
            celeb_mask = logical(name_matches);
        end
    end
    
    if ~any(celeb_mask)
        fprintf('仍然未找到选手 %s，跳过\n', target_name);
        continue;
    end
    
    celeb_data = data(celeb_mask, :);
    
    % 可能有多个匹配，取第一个
    if height(celeb_data) > 1
        fprintf('找到多个匹配，取第一个...\n');
        celeb_data = celeb_data(1, :);
        % 修复这里：重新创建celeb_mask，只包含第一个匹配
        celeb_mask = false(height(data), 1);
        first_match_idx = find(name_matches, 1);  % 找到第一个匹配的索引
        celeb_mask(first_match_idx) = true;  % 只标记第一个匹配
    end
    
    season_num = celeb_data.season_numeric;
    
    fprintf('\n\n=================================================\n');
    fprintf('分析选手: %s (第 %d 季)\n', celeb_data.x__elebrity_name{1}, season_num);
    fprintf('实际结果: %s\n', celeb_data.results{1});
    fprintf('实际排名: %d\n', celeb_data.placement_numeric);
    fprintf('实际淘汰周: ');
    if isinf(celeb_data.elimination_week_numeric)
        fprintf('进入决赛 (Inf)\n');
    else
        fprintf('%d\n', celeb_data.elimination_week_numeric);
    end
    fprintf('=================================================\n');
    
    % 提取该季度的所有选手
    season_mask = (data.season_numeric == season_num);
    season_data = data(season_mask, :);
    
    % 获取该选手在赛季中的索引
    celeb_name = celeb_data.x__elebrity_name{1};
    celeb_index_in_season = 0;
    for i = 1:height(season_data)
        if strcmp(season_data.x__elebrity_name{i}, celeb_name)
            celeb_index_in_season = i;
            break;
        end
    end
    
    if celeb_index_in_season == 0
        fprintf('错误：未在赛季数据中找到选手\n');
        continue;
    end
    
    % 提取百分比数据
    num_weeks = 11;
    week_pct_data = zeros(height(season_data), num_weeks);
    
    for w = 1:num_weeks
        col_name = sprintf('week%d_pct', w);
        if ismember(col_name, season_data.Properties.VariableNames)
            col_data = season_data.(col_name);
            % 处理可能的数据类型问题
            if iscell(col_data)
                week_pct_data(:, w) = cell2mat(col_data);
            else
                week_pct_data(:, w) = col_data;
            end
        else
            week_pct_data(:, w) = NaN(height(season_data), 1);
        end
    end
    
    % 提取观众投票百分比
    fan_vote_col = 'fan_vote_pct_combined';
    if ismember(fan_vote_col, season_data.Properties.VariableNames)
        fan_vote_data = season_data.(fan_vote_col);
        if iscell(fan_vote_data)
            fan_vote_pct = cell2mat(fan_vote_data);
        else
            fan_vote_pct = fan_vote_data;
        end
    else
        fprintf('警告：未找到观众投票数据，使用默认值\n');
        fan_vote_pct = ones(height(season_data), 1) * 10; % 默认10%
    end
    
    % 获取淘汰信息
    if iscell(season_data.elimination_week_numeric)
        elimination_week = cell2mat(season_data.elimination_week_numeric);
    else
        elimination_week = season_data.elimination_week_numeric;
    end
    
    if iscell(season_data.is_withdrew_numeric)
        is_withdrew = cell2mat(season_data.is_withdrew_numeric);
    else
        is_withdrew = season_data.is_withdrew_numeric;
    end
    
    % 数据预处理
    for w = 1:num_weeks
        col_data = week_pct_data(:, w);
        nan_indices = isnan(col_data);
        if any(nan_indices)
            mean_val = nanmean(col_data);
            week_pct_data(nan_indices, w) = mean_val;
        end
    end
    
    fan_vote_pct(isnan(fan_vote_pct)) = nanmean(fan_vote_pct);
    week_pct_data = max(week_pct_data, 0);
    fan_vote_pct = max(fan_vote_pct, 0);
    
    % 模拟动态投票系统
    fprintf('\n动态公平性投票系统模拟结果:\n');
    
    % 存储每周结果
    active_players = true(height(season_data), 1);
    withdrawn_players = (is_withdrew == 1);
    active_players(withdrawn_players) = false;
    
    elimination_week_new = 0;
    final_rank_new = 0;
    weekly_status = cell(num_weeks, 1);
    
    % 每周模拟
    for week = 1:num_weeks
        active_indices = find(active_players);
        
        if length(active_indices) <= 1 || ~active_players(celeb_index_in_season)
            break;
        end
        
        % 获取当前周的评委评分
        current_judge_scores = week_pct_data(active_indices, week);
        current_fan_scores = fan_vote_pct(active_indices);
        
        % 检查数据有效性
        if all(current_judge_scores == 0) || all(isnan(current_judge_scores))
            current_judge_scores = ones(size(current_judge_scores)) * 10;
        end
        
        % 计算动态权重
        try
            [w_judges, w_fan] = calculate_dynamic_weights(current_judge_scores, current_fan_scores);
            
            % 计算TOPSIS排名
            [topsis_scores, ranks] = calculate_topsis(current_judge_scores, current_fan_scores, w_judges, w_fan);
        catch ME
            fprintf('第%d周计算错误: %s，使用简单排名\n', week, ME.message);
            % 使用简单平均作为后备
            combined_scores = current_judge_scores * 0.5 + current_fan_scores * 0.5;
            [~, sort_idx] = sort(combined_scores, 'descend');
            topsis_scores = combined_scores;
            ranks = zeros(size(combined_scores));
            for i = 1:length(sort_idx)
                ranks(sort_idx(i)) = i;
            end
            w_judges = 0.5;
            w_fan = 0.5;
        end
        
        % 找出该选手在当前活跃选手中的位置
        celeb_pos_in_active = find(active_indices == celeb_index_in_season);
        
        celeb_topsis_score = topsis_scores(celeb_pos_in_active);
        celeb_rank_in_week = ranks(celeb_pos_in_active);
        
        % 检查是否被淘汰
        [min_score, min_idx] = min(topsis_scores);
        eliminated_idx = active_indices(min_idx);
        
        % 如果有并列最后，使用评委评分决定
        tied_players = find(abs(topsis_scores - min_score) < 1e-10);
        if length(tied_players) > 1
            judge_scores_tied = current_judge_scores(tied_players);
            [~, highest_judge_idx] = max(judge_scores_tied);
            eliminated_idx = active_indices(tied_players(highest_judge_idx));
        end
        
        if eliminated_idx == celeb_index_in_season
            elimination_week_new = week;
            final_rank_new = sum(active_players);
            weekly_status{week} = sprintf('第%d周: 被淘汰 (排名第%d)', week, final_rank_new);
            fprintf('  第%d周: 被淘汰 (排名第%d)\n', week, final_rank_new);
            break;
        else
            % 淘汰其他选手
            active_players(eliminated_idx) = false;
            weekly_status{week} = sprintf('第%d周: 安全 (排名: %d/%d, 得分: %.4f)', ...
                week, celeb_rank_in_week, length(active_indices), celeb_topsis_score);
            fprintf('  第%d周: 安全 (本周排名: %d/%d, TOPSIS得分: %.4f)\n', ...
                week, celeb_rank_in_week, length(active_indices), celeb_topsis_score);
        end
    end
    
    % 如果选手进入决赛
    if elimination_week_new == 0 && active_players(celeb_index_in_season)
        % 计算最终排名
        active_indices = find(active_players);
        current_judge_scores = week_pct_data(active_indices, week);
        current_fan_scores = fan_vote_pct(active_indices);
        
        try
            [w_judges, w_fan] = calculate_dynamic_weights(current_judge_scores, current_fan_scores);
            [topsis_scores, ranks] = calculate_topsis(current_judge_scores, current_fan_scores, w_judges, w_fan);
        catch
            % 使用简单平均
            combined_scores = current_judge_scores * 0.5 + current_fan_scores * 0.5;
            [~, sort_idx] = sort(combined_scores, 'descend');
            ranks = zeros(size(combined_scores));
            for i = 1:length(sort_idx)
                ranks(sort_idx(i)) = i;
            end
        end
        
        celeb_pos_in_active = find(active_indices == celeb_index_in_season);
        final_rank_new = ranks(celeb_pos_in_active);
        
        fprintf('  进入决赛，最终排名: %d\n', final_rank_new);
        elimination_week_new = Inf;
        weekly_status{week} = sprintf('进入决赛，最终排名: %d', final_rank_new);
    end
    
    % 对比分析
    fprintf('\n对比分析:\n');
    fprintf('  实际淘汰周: ');
    if isinf(celeb_data.elimination_week_numeric)
        fprintf('进入决赛 (Inf)\n');
    else
        fprintf('%d\n', celeb_data.elimination_week_numeric);
    end
    
    fprintf('  新方法淘汰周: ');
    if isinf(elimination_week_new)
        fprintf('进入决赛\n');
    else
        fprintf('%d\n', elimination_week_new);
    end
    
    fprintf('  实际排名: %d\n', celeb_data.placement_numeric);
    fprintf('  新方法排名: %d\n', final_rank_new);
    
    % 分析淘汰是否提前
    actual_elim = celeb_data.elimination_week_numeric;
    new_elim = elimination_week_new;
    
    if isinf(actual_elim) && ~isinf(new_elim)
        fprintf('  ? 淘汰提前: 原进入决赛，新方法在第%d周淘汰\n', new_elim);
    elseif ~isinf(actual_elim) && ~isinf(new_elim)
        if new_elim < actual_elim
            fprintf('  ? 淘汰提前: 提前%d周\n', actual_elim - new_elim);
        elseif new_elim > actual_elim
            fprintf('  ? 淘汰延后: 延后%d周\n', new_elim - actual_elim);
        else
            fprintf('  = 淘汰周数相同\n');
        end
    elseif isinf(actual_elim) && isinf(new_elim)
        if final_rank_new > celeb_data.placement_numeric
            fprintf('  ? 排名下降: 从第%d名降至第%d名\n', celeb_data.placement_numeric, final_rank_new);
        elseif final_rank_new < celeb_data.placement_numeric
            fprintf('  ? 排名提升: 从第%d名升至第%d名\n', celeb_data.placement_numeric, final_rank_new);
        else
            fprintf('  = 排名相同\n');
        end
    end
    
    % 显示评委评分和观众投票对比
    fprintf('\n评委评分 vs 观众投票分析:\n');
    
    % 计算平均评委评分和观众投票
    judge_scores_target = [];
    max_week = min([celeb_data.elimination_week_numeric, num_weeks]);
    if isinf(max_week)
        max_week = num_weeks;
    end
    
    for w = 1:max_week
        if w <= size(week_pct_data, 2) && ~isnan(week_pct_data(celeb_index_in_season, w))
            judge_scores_target = [judge_scores_target; week_pct_data(celeb_index_in_season, w)];
        end
    end
    
    if ~isempty(judge_scores_target)
        avg_judge_score = mean(judge_scores_target);
        fan_vote_target = fan_vote_pct(celeb_index_in_season);
        
        % 计算在赛季中的相对位置
        avg_judge_season = nanmean(nanmean(week_pct_data(:, 1:max_week), 2));
        avg_fan_season = nanmean(fan_vote_pct);
        
        fprintf('  平均评委评分: %.2f%% (赛季平均: %.2f%%)\n', avg_judge_score, avg_judge_season);
        fprintf('  观众投票比例: %.2f%% (赛季平均: %.2f%%)\n', fan_vote_target, avg_fan_season);
        
      % 正确的方法：每周独立计算百分位，然后取平均
weekly_percentiles = zeros(max_week, 1);
count = 0;

for w = 1:max_week
    % 获取该周所有选手的评分
    weekly_scores = week_pct_data(:, w);
    
    % 该选手在该周的评分
    player_score = week_pct_data(celeb_index_in_season, w);
    
    if ~isnan(player_score)
        % 计算该选手在该周的百分位
        better_players = sum(weekly_scores > player_score);
        total_players = sum(~isnan(weekly_scores));
        
        if total_players > 1
            weekly_percentiles(w) = (total_players - better_players - 1) / (total_players - 1) * 100;
            count = count + 1;
        end
    end
end

% 取平均值
if count > 0
    judge_percentile = sum(weekly_percentiles) / count;
else
    judge_percentile = NaN;
end
        fan_percentile = sum(fan_vote_pct < fan_vote_target) / length(fan_vote_pct) * 100;
        
        fprintf('  评委评分百分位: %.1f%%\n', judge_percentile);
        fprintf('  观众投票百分位: %.1f%%\n', fan_percentile);
        
        if fan_percentile > judge_percentile + 20
            fprintf('  → 观众支持率显著高于评委评分\n');
        elseif judge_percentile > fan_percentile + 20
            fprintf('  → 评委评分显著高于观众支持率\n');
        end
    else
        avg_judge_score = NaN;
        fan_vote_target = fan_vote_pct(celeb_index_in_season);
        judge_percentile = NaN;
        fan_percentile = NaN;
    end
    
    % 添加到结果表
    new_row = table();
    new_row.Name = {celeb_name};
    new_row.Season = season_num;
    new_row.Actual_Rank = celeb_data.placement_numeric;
    new_row.Actual_Elimination_Week = actual_elim;
    new_row.New_Rank = final_rank_new;
    new_row.New_Elimination_Week = new_elim;
    
    if ~isempty(judge_scores_target)
        new_row.Average_Judge_Score = avg_judge_score;
    else
        new_row.Average_Judge_Score = NaN;
    end
    
    new_row.Fan_Vote_Pct = fan_vote_target;
    new_row.Judge_Percentile = judge_percentile;
    new_row.Fan_Percentile = fan_percentile;
    
    results_table = [results_table; new_row];
end

%% 3. 显示综合结果
if ~isempty(results_table)
    fprintf('\n\n=================================================\n');
    fprintf('综合结果对比\n');
    fprintf('=================================================\n');
    
    fprintf('\n综合结果对比:\n');
    fprintf('%-20s %-6s %-12s %-12s %-10s %-10s %-12s %-12s %-12s %-12s\n', ...
        '选手', '赛季', '实际排名', '新排名', '实际淘汰周', '新淘汰周', '均评委分', '观众票', '评委%位', '观众%位');
    fprintf('%-20s %-6s %-12s %-12s %-10s %-10s %-12s %-12s %-12s %-12s\n', ...
        '---', '---', '---', '---', '---', '---', '---', '---', '---', '---');
    
    for i = 1:height(results_table)
        actual_elim = results_table.Actual_Elimination_Week(i);
        new_elim = results_table.New_Elimination_Week(i);
        
        if isinf(actual_elim)
            actual_elim_str = '决赛';
        else
            actual_elim_str = num2str(actual_elim);
        end
        
        if isinf(new_elim)
            new_elim_str = '决赛';
        else
            new_elim_str = num2str(new_elim);
        end
        
        fprintf('%-20s %-6d %-12d %-12d %-10s %-10s %-12.1f %-12.1f %-12.1f %-12.1f\n', ...
            results_table.Name{i}, results_table.Season(i), ...
            results_table.Actual_Rank(i), results_table.New_Rank(i), ...
            actual_elim_str, new_elim_str, ...
            results_table.Average_Judge_Score(i), results_table.Fan_Vote_Pct(i), ...
            results_table.Judge_Percentile(i), results_table.Fan_Percentile(i));
    end
    
    % 统计提前淘汰的情况
    early_elim_count = 0;
    for i = 1:height(results_table)
        if isinf(results_table.Actual_Elimination_Week(i)) && ~isinf(results_table.New_Elimination_Week(i))
            early_elim_count = early_elim_count + 1;
        elseif ~isinf(results_table.Actual_Elimination_Week(i)) && ~isinf(results_table.New_Elimination_Week(i))
            if results_table.New_Elimination_Week(i) < results_table.Actual_Elimination_Week(i)
                early_elim_count = early_elim_count + 1;
            end
        end
    end
    
    fprintf('\n统计结果:\n');
    fprintf('  总分析选手数: %d\n', height(results_table));
    fprintf('  提前淘汰选手数: %d (%.1f%%)\n', early_elim_count, early_elim_count/height(results_table)*100);
    
    % 计算平均排名变化
    rank_changes = results_table.New_Rank - results_table.Actual_Rank;
    fprintf('  平均排名变化: %.2f (正数表示排名下降)\n', mean(rank_changes));
    
    % 计算评委评分和观众投票的相关系数
    valid_idx = ~isnan(results_table.Average_Judge_Score);
    if sum(valid_idx) > 1
        corr_coeff = corr(results_table.Average_Judge_Score(valid_idx), results_table.Fan_Vote_Pct(valid_idx));
        fprintf('  评委评分与观众投票相关系数: %.3f\n', corr_coeff);
    end
    
%% 4. Visualization Analysis
if height(results_table) >= 2  % Show charts only if at least 2 contestants
    figure('Position', [100, 100, 1200, 800]);
    
    % Subplot 1: Elimination Week Comparison
    subplot(2, 2, 1);
    actual_elims = results_table.Actual_Elimination_Week;
    new_elims = results_table.New_Elimination_Week;
    
    % Handle Inf values (contestants who reached the finals)
    max_week = 11;
    actual_elims_plot = actual_elims;
    new_elims_plot = new_elims;
    actual_elims_plot(isinf(actual_elims_plot)) = max_week + 1;
    new_elims_plot(isinf(new_elims_plot)) = max_week + 1;
    
    bar_data = [actual_elims_plot, new_elims_plot];
    h = bar(bar_data);
    set(h(1), 'FaceColor', [0.2, 0.6, 0.8]);  % Blue for Actual
    set(h(2), 'FaceColor', [0.8, 0.4, 0.2]);  % Orange for New Method
    
    xlabel('Contestant');
    ylabel('Elimination Week');
    title('Elimination Week Comparison');
    legend({'Actual', 'New Method'}, 'Location', 'best');
    grid on;
    
    % Set x-axis labels
    ax = gca;
    ax.XTick = 1:height(results_table);
    ax.XTickLabel = results_table.Name;
    ax.XTickLabelRotation = 0;
    
    % Mark early eliminations
    for i = 1:height(results_table)
        if new_elims_plot(i) < actual_elims_plot(i)
            text(i, new_elims_plot(i) - 0.5, '↓Earlier', ...
                'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'Color', 'red');
        end
    end
    
    ylim([0, max_week + 2]);
    
    % Subplot 2: Final Ranking Comparison
    subplot(2, 2, 2);
    actual_ranks = results_table.Actual_Rank;
    new_ranks = results_table.New_Rank;
    
    bar_data2 = [actual_ranks, new_ranks];
    h2 = bar(bar_data2);
    set(h2(1), 'FaceColor', [0.2, 0.6, 0.8]);  % Blue for Actual
    set(h2(2), 'FaceColor', [0.8, 0.4, 0.2]);  % Orange for New Method
    
    xlabel('Contestant');
    ylabel('Final Ranking');
    title('Final Ranking Comparison');
    legend({'Actual', 'New Method'}, 'Location', 'best');
    grid on;
    
    ax2 = gca;
    ax2.XTick = 1:height(results_table);
    ax2.XTickLabel = results_table.Name;
    ax2.XTickLabelRotation = 45;
    
    % Mark ranking changes
    for i = 1:height(results_table)
        if new_ranks(i) > actual_ranks(i)
            text(i, new_ranks(i) + 0.5, '↓Worse', ...
                'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'Color', 'red');
        elseif new_ranks(i) < actual_ranks(i)
            text(i, new_ranks(i) - 0.5, '↑Better', ...
                'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'Color', 'green');
        end
    end
    
    % Subplot 3: Judge Scores vs Audience Votes
    subplot(2, 2, 3);
    judge_scores = results_table.Average_Judge_Score;
    fan_votes = results_table.Fan_Vote_Pct;
    
    scatter(judge_scores, fan_votes, 100, 'filled');
    xlabel('Average Judge Score (%)');
    ylabel('Fan Vote Percentage (%)');
    title('Judge Scores vs Fan Votes');
    grid on;
    
    % Add labels
    for i = 1:length(judge_scores)
        if ~isnan(judge_scores(i)) && ~isnan(fan_votes(i))
            text(judge_scores(i)+0.5, fan_votes(i)+0.5, results_table.Name{i}, ...
                'FontSize', 8, 'HorizontalAlignment', 'left');
        end
    end
    
    % Add diagonal line (indicating judge-audience agreement)
    hold on;
    valid_points = ~isnan(judge_scores) & ~isnan(fan_votes);
    if any(valid_points)
        min_val = min([judge_scores(valid_points); fan_votes(valid_points)]);
        max_val = max([judge_scores(valid_points); fan_votes(valid_points)]);
        plot([min_val, max_val], [min_val, max_val], 'k--', 'LineWidth', 1);
        text(max_val-2, max_val-2, 'Judge=Fan', 'HorizontalAlignment', 'right');
    end
    hold off;
    
    % Subplot 4: Elimination Timing Change Analysis
    subplot(2, 2, 4);
    elimination_change = zeros(height(results_table), 1);
    
    for i = 1:height(results_table)
        if isinf(actual_elims(i)) && isinf(new_elims(i))
            % Both reached finals, compare rankings
            if new_ranks(i) > actual_ranks(i)
                elimination_change(i) = -1; % Ranking decreased
            elseif new_ranks(i) < actual_ranks(i)
                elimination_change(i) = 1; % Ranking improved
            else
                elimination_change(i) = 0; % No change
            end
        elseif isinf(actual_elims(i)) && ~isinf(new_elims(i))
            elimination_change(i) = -2; % From finals to early elimination
        elseif ~isinf(actual_elims(i)) && isinf(new_elims(i))
            elimination_change(i) = 2; % From elimination to finals
        else
            elimination_change(i) = actual_elims(i) - new_elims(i);
        end
    end
    
    bar(elimination_change);
    xlabel('Contestant');
    ylabel('Change Value');
    title('Elimination Timing Change Analysis');
    grid on;
    
    ax4 = gca;
    ax4.XTick = 1:height(results_table);
    ax4.XTickLabel = results_table.Name;
    ax4.XTickLabelRotation = 45;
    
    % Add value labels
    hold on;
    for i = 1:height(results_table)
        if elimination_change(i) > 0
            text(i, elimination_change(i) + 0.1, sprintf('+%d', elimination_change(i)), ...
                'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'Color', 'green');
        elseif elimination_change(i) < 0
            text(i, elimination_change(i) - 0.1, sprintf('%d', elimination_change(i)), ...
                'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'Color', 'red');
        else
            text(i, 0.1, '0', ...
                'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'Color', 'blue');
        end
    end
    hold off;
    
    % Add legend explanation
    y_lim = get(gca, 'YLim');
    text(0.5, y_lim(2)*0.9, 'Positive: Elimination Delayed / Ranking Improved', ...
        'FontSize', 8, 'Color', 'green', 'FontWeight', 'bold');
    text(0.5, y_lim(2)*0.85, 'Negative: Elimination Earlier / Ranking Worsened', ...
        'FontSize', 8, 'Color', 'red', 'FontWeight', 'bold');
    text(0.5, y_lim(2)*0.8, 'Zero: No Change', ...
        'FontSize', 8, 'Color', 'blue', 'FontWeight', 'bold');
    
    % Remove the title that was created with axes
    % The original code created a title using axes() - this has been removed
    
    % Optional: If you still want a main title, use suptitle (if available)
    % try
    %     suptitle('Dynamic Fairness Voting System Validation Analysis');
    % catch
    %     % suptitle not available
    % end
end
end



%% 辅助函数定义
function [weights_judges, weights_fan] = calculate_dynamic_weights(judge_scores, fan_scores)
    % 动态权重计算函数
    % 基于熵权法计算评委评分和观众投票的权重
    
    n = size(judge_scores, 1);
    m = size(judge_scores, 2);
    
    % 检查数据有效性
    if n == 0 || m == 0
        weights_judges = 0.5;
        weights_fan = 0.5;
        return;
    end
    
    % 计算评委评分的熵值
    judge_entropy = zeros(1, m);
    for j = 1:m
        col = judge_scores(:, j);
        if sum(col) == 0
            col = ones(size(col)) * 0.0001; % 避免除以0
        end
        p = col / sum(col);
        p(p == 0) = realmin; % 避免log(0)
        judge_entropy(j) = -sum(p .* log(p)) / log(n);
    end
    
    % 计算评委平均熵
    judge_avg_entropy = mean(judge_entropy);
    
    % 计算观众投票的熵
    if sum(fan_scores) == 0
        fan_scores = ones(size(fan_scores)) * 0.0001;
    end
    p_fan = fan_scores / sum(fan_scores);
    p_fan(p_fan == 0) = realmin;
    fan_entropy = -sum(p_fan .* log(p_fan)) / log(n);
    
    % 基于熵的权重计算
    weight_judge_raw = max(0, 1 - judge_avg_entropy);
    weight_fan_raw = max(0, 1 - fan_entropy);
    
    % 归一化权重
    total_weight = weight_judge_raw + weight_fan_raw;
    if total_weight == 0
        weights_judges = 0.5;
        weights_fan = 0.5;
    else
        weights_judges = weight_judge_raw / total_weight;
        weights_fan = weight_fan_raw / total_weight;
    end
    
    % 确保权重不为0
    min_weight = 0.1;
    if weights_judges < min_weight
        weights_judges = min_weight;
        weights_fan = 1 - min_weight;
    end
    if weights_fan < min_weight
        weights_fan = min_weight;
        weights_judges = 1 - min_weight;
    end
    
    % 调试信息
    % fprintf('评委平均熵: %.4f, 观众熵: %.4f\n', judge_avg_entropy, fan_entropy);
    % fprintf('原始权重 - 评委: %.4f, 观众: %.4f\n', weight_judge_raw, weight_fan_raw);
    % fprintf('最终权重 - 评委: %.4f, 观众: %.4f\n', weights_judges, weights_fan);
end

function [topsis_scores, ranks] = calculate_topsis(judge_scores, fan_scores, weight_judges, weight_fan)
    % TOPSIS排名函数
    % 基于TOPSIS方法计算综合得分和排名
    
    n = size(judge_scores, 1);
    m = size(judge_scores, 2);
    
    if n == 0
        topsis_scores = [];
        ranks = [];
        return;
    end
    
    % 构建决策矩阵
    decision_matrix = [judge_scores, fan_scores];
    
    % 归一化决策矩阵
    norm_matrix = zeros(size(decision_matrix));
    for j = 1:size(decision_matrix, 2)
        col = decision_matrix(:, j);
        col_norm = sqrt(sum(col.^2));
        if col_norm == 0
            col_norm = 1; % 避免除以0
        end
        norm_matrix(:, j) = col / col_norm;
    end
    
    % 构建加权归一化矩阵
    weights = [ones(1, m) * weight_judges/m, weight_fan];
    weighted_matrix = norm_matrix .* weights;
    
    % 确定理想解和负理想解
    ideal_solution = max(weighted_matrix);
    negative_ideal_solution = min(weighted_matrix);
    
    % 计算距离
    distance_ideal = zeros(n, 1);
    distance_negative = zeros(n, 1);
    
    for i = 1:n
        distance_ideal(i) = sqrt(sum((weighted_matrix(i, :) - ideal_solution).^2));
        distance_negative(i) = sqrt(sum((weighted_matrix(i, :) - negative_ideal_solution).^2));
    end
    
    % 计算相对接近度
    topsis_scores = distance_negative ./ (distance_ideal + distance_negative);
    
    % 处理可能的NaN
    topsis_scores(isnan(topsis_scores)) = 0;
    
    % 排名（得分越高越好）
    [~, sorted_indices] = sort(topsis_scores, 'descend');
    ranks = zeros(n, 1);
    for i = 1:n
        ranks(sorted_indices(i)) = i;
    end
end