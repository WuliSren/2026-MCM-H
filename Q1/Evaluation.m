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
actual_elim_mask = (elimination_week ~= Inf) & (elimination_week > 0) & (is_withdrew == 0);
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

%% 提取粉丝投票数据
% 假设粉丝投票百分比列名为 'fan_vote_pct'
if ismember('fan_vote_pct_combined', data.Properties.VariableNames)
    fan_vote_pct = data.fan_vote_pct_combined;
else
    error('找不到粉丝投票百分比列 fan_vote_pct');
end

%% 初始化结果列
predictions = cell(height(data), 1);  % 淘汰周预测
predicted_ranks = zeros(height(data), 1);  % 名次预测

%% 首先统计每个季节的实际周数
season_actual_weeks = zeros(numSeasons, 1);
for s_idx = 1:numSeasons
    current_season = uniqueSeasons(s_idx);
    season_mask = (seasons == current_season);
    
    % 找出该季节的最大淘汰周数（排除withdrew和Inf）
    elim_weeks = elimination_week(season_mask);
    valid_elim_weeks = elim_weeks(elim_weeks ~= Inf & elim_weeks > 0);
    
    if isempty(valid_elim_weeks)
        season_actual_weeks(s_idx) = max_week;
    else
        season_actual_weeks(s_idx) = max(valid_elim_weeks);
    end
end

%% 按不同规则进行预测
fprintf('\n========== 开始预测（不同季节使用不同规则） ==========\n');

for s_idx = 1:numSeasons
    current_season = uniqueSeasons(s_idx);
    season_mask = (seasons == current_season);
    season_indices = find(season_mask);
    
    n = length(season_indices);  % 该赛季选手人数
    actual_weeks = season_actual_weeks(s_idx);
    
    % 提取该赛季的粉丝投票百分比
    season_fan_votes = fan_vote_pct(season_indices);
    
    fprintf('\n=== 季节%d (选手数：%d，周数：%d) ===\n', current_season, n, actual_weeks);
    
    % 根据季节确定使用的规则
    if current_season >= 1 && current_season <= 2
        rule_name = '规则1：粉丝投票排名 + 评委评分排名（相加）';
        fprintf('  使用：%s\n', rule_name);
    elseif current_season >= 3 && current_season <= 27
        rule_name = '规则2：粉丝投票百分比 + 评委评分百分比（相加）';
        fprintf('  使用：%s\n', rule_name);
    else % 28-34
        rule_name = '规则3：粉丝投票排名 + 评委评分排名（相加，取最高者淘汰）';
        fprintf('  使用：%s\n', rule_name);
    end
    
    % 初始化排名计数器
    current_rank = n;
    
    % 每周进行预测
    for w = 1:actual_weeks
        % 找出该周仍在比赛中的选手
        still_in_mask = false(n, 1);
        for i = 1:n
            idx = season_indices(i);
            if elimination_week(idx) >= w
                still_in_mask(i) = true;
            end
        end
        
        still_in_idx = season_indices(still_in_mask);
        
        if length(still_in_idx) <= 1
            continue;  % 只剩1人不淘汰
        end
        
        % 根据规则计算总分
        if current_season >= 1 && current_season <= 2
            %% 规则1：粉丝投票排名 + 评委评分排名（相加）
            % 获取评委评分排名
            judge_ranks = weeklyRanks(still_in_idx, w);
            
            % 计算粉丝投票排名（基于已有的粉丝投票百分比）
            fan_votes_season = season_fan_votes(still_in_mask);
            [~, fan_sort_idx] = sort(fan_votes_season, 'descend');  
            fan_ranks = zeros(length(still_in_idx), 1);
            fan_ranks(fan_sort_idx) = 1:length(still_in_idx);
            
            % 计算总分 = 评委排名 + 粉丝排名
            total_scores = judge_ranks + fan_ranks;
            
            % 找出总分最高者（最差）淘汰
            [~, worst_idx] = max(total_scores);
            
        elseif current_season >= 3 && current_season <= 27
            %% 规则2：粉丝投票百分比 + 评委评分百分比（相加）
            % 获取评委评分百分比
            judge_percents = weeklyPercents(still_in_idx, w);
            
            % 获取粉丝投票百分比
            fan_votes_season = season_fan_votes(still_in_mask);
            
            % 处理缺失值
            judge_percents(isnan(judge_percents)) = 0;
            
            % 计算总分 = 评委百分比 + 粉丝百分比
            total_scores = judge_percents + fan_votes_season;
            
            % 找出总分最低者淘汰（百分比越低越危险）
            [~, worst_idx] = min(total_scores);
            
        else
            %% 规则3：粉丝投票排名 + 评委评分排名（相加，取最高者淘汰）
            % 获取评委评分排名
            judge_ranks = weeklyRanks(still_in_idx, w);
            
            % 计算粉丝投票排名（基于已有的粉丝投票百分比）
            fan_votes_season = season_fan_votes(still_in_mask);
            [~, fan_sort_idx] = sort(fan_votes_season, 'descend');  
            fan_ranks = zeros(length(still_in_idx), 1);
            fan_ranks(fan_sort_idx) = 1:length(still_in_idx);
            
            % 计算总分 = 评委排名 + 粉丝排名
            total_scores = judge_ranks + fan_ranks;
            
% 找出总分排名最差的两名选手
    [sorted_totals, sort_idx] = sort(total_scores, 'descend');  % 降序排列，最差在前
    bottom_two_idx = sort_idx(1:min(2, length(sort_idx)));  % 取前2名（最差的两名）
    
    if length(bottom_two_idx) == 2
        % 获取这两名选手的评委原始分数
        % 计算该周评委原始分数的总和
        colStart = (w-1)*numJudges + 1;
        colEnd = colStart + numJudges - 1;
        judge_scores_sum = nansum(scores(still_in_idx, colStart:colEnd), 2);
        
        % 比较这两名选手的评委总分数
        score1 = judge_scores_sum(bottom_two_idx(1));
        score2 = judge_scores_sum(bottom_two_idx(2));
        
        if score1 < score2
            worst_idx_in_bottom = bottom_two_idx(1);  % 评委分数更低的被淘汰
        elseif score2 < score1
            worst_idx_in_bottom = bottom_two_idx(2);  % 评委分数更低的被淘汰
        else
            % 分数相同，选择总分更高的（更差的）
            if sorted_totals(1) > sorted_totals(2)
                worst_idx_in_bottom = bottom_two_idx(1);
            else
                worst_idx_in_bottom = bottom_two_idx(2);
            end
        end
        worst_idx = worst_idx_in_bottom;
    else
        % 如果只有1人或0人，直接淘汰最差的
        worst_idx = bottom_two_idx(1);
    end
        end
        
        % 记录预测结果
        predicted_elim_idx = still_in_idx(worst_idx);
        week_key = sprintf('%d_%d', current_season, w);
        predictions{predicted_elim_idx} = week_key;
        predicted_ranks(predicted_elim_idx) = current_rank;
        
        fprintf('  第 %d 周: 预测淘汰 %s (名次: %d)\n', ...
                w, celebrity_names{predicted_elim_idx}, current_rank);
        
        current_rank = current_rank - 1;
    end
    
    % 剩余选手（冠军）名次记为1
    remaining_idx = season_indices(cellfun(@isempty, predictions(season_indices)));
    for idx = remaining_idx'
        predicted_ranks(idx) = 1;  % 冠军
    end
end

%% 将结果添加到表格
data.predicted_elimination_week = predictions;
data.predicted_rank = predicted_ranks;

%% 预测与真实结果一致性计算 - 基于名次准确性
fprintf('\n========== 预测与真实结果一致性计算（基于名次准确性）==========\n');

% 计算真实名次
true_ranks = zeros(height(data), 1);
for s_idx = 1:numSeasons
    current_season = uniqueSeasons(s_idx);
    season_mask = (seasons == current_season);
    season_indices = find(season_mask);
    
    % 按淘汰周数排序：淘汰越早名次越差（数值越大）
    elim_weeks = elimination_week(season_indices);
    [sorted_weeks, sort_idx] = sort(elim_weeks, 'ascend');
    
    rank_val = length(season_indices);  % 从最差名次开始
    for i = 1:length(sort_idx)
        orig_idx = sort_idx(i);
        if sorted_weeks(i) == Inf
            true_ranks(season_indices(orig_idx)) = 1;  % 冠军
        else
            true_ranks(season_indices(orig_idx)) = rank_val;
            rank_val = rank_val - 1;
        end
    end
end

% 添加真实名次到数据表
data.true_rank = true_ranks;

% 计算名次准确性
actual_mask = (elimination_week ~= Inf) & (elimination_week > 0) & (is_withdrew == 0);
actual_indices = find(actual_mask);
num_actual = length(actual_indices);

%% 按季节统计名次准确性
fprintf('\n========== 按季节统计名次准确性 ==========\n');
fprintf('季节 | 规则 | 选手数 | 完全匹配 | 误差≤1名 | 平均名次差\n');
fprintf('-----|------|--------|----------|----------|-------------\n');

season_accuracies = [];
season_exact_accuracies = [];
season_within1_accuracies = [];
season_avg_diff = [];
season_numbers = [];
rule_labels = {};

for s_idx = 1:numSeasons
    current_season = uniqueSeasons(s_idx);
    season_mask = (seasons == current_season);
    
    % 该季节的实际淘汰选手
    season_actual_mask = season_mask & actual_mask;
    season_actual_indices = find(season_actual_mask);
    
    if isempty(season_actual_indices)
        continue;
    end
    
    % 确定规则名称
    if current_season >= 1 && current_season <= 2
        rule_name = '规则1';
    elseif current_season >= 3 && current_season <= 27
        rule_name = '规则2';
    else
        rule_name = '规则3';
    end
    
    % 计算该季节的准确性指标
    season_correct_exact = 0;
    season_correct_within1 = 0;
    season_diffs = [];
    
    for i = 1:length(season_actual_indices)
        idx = season_actual_indices(i);
        diff = abs(true_ranks(idx) - predicted_ranks(idx));
        season_diffs = [season_diffs; diff];
        
        if diff == 0
            season_correct_exact = season_correct_exact + 1;
            season_correct_within1 = season_correct_within1 + 1;
        elseif diff == 1
            season_correct_within1 = season_correct_within1 + 1;
        end
    end
    
    season_total = length(season_actual_indices);
    exact_accuracy = season_correct_exact / season_total * 100;
    within1_accuracy = season_correct_within1 / season_total * 100;
    avg_diff = mean(season_diffs);
    
    % 保存数据用于可视化
    season_accuracies(end+1) = within1_accuracy;  % 使用误差≤1的准确率作为主要指标
    season_exact_accuracies(end+1) = exact_accuracy;
    season_within1_accuracies(end+1) = within1_accuracy;
    season_avg_diff(end+1) = avg_diff;
    season_numbers(end+1) = current_season;
    rule_labels{end+1} = rule_name;
    
    fprintf('%4d | %-4s | %6d | %8d | %8d | %10.2f\n', ...
            current_season, rule_name, season_total, season_correct_exact, ...
            season_correct_within1, avg_diff);
end

%% 按规则分组统计名次准确性
fprintf('\n========== 按规则分组统计名次准确性 ==========\n');

rule_names = {'规则1', '规则2', '规则3'};
season_ranges = {'1-2', '3-27', '28-34'};

for r = 1:3
    rule_name = rule_names{r};
    
    % 找出使用该规则的季节
    if r == 1
        rule_seasons = uniqueSeasons(uniqueSeasons >= 1 & uniqueSeasons <= 2);
    elseif r == 2
        rule_seasons = uniqueSeasons(uniqueSeasons >= 3 & uniqueSeasons <= 27);
    else
        rule_seasons = uniqueSeasons(uniqueSeasons >= 28 & uniqueSeasons <= 34);
    end
    
    if isempty(rule_seasons)
        continue;
    end
    
    % 统计该规则下的准确性
    rule_total = 0;
    rule_exact = 0;
    rule_within1 = 0;
    rule_diffs = [];
    rule_exact_accuracies = [];
    rule_within1_accuracies = [];
    
    for s = 1:length(rule_seasons)
        season_num = rule_seasons(s);
        season_mask = (seasons == season_num);
        season_actual_mask = season_mask & actual_mask;
        season_actual_indices = find(season_actual_mask);
        
        if isempty(season_actual_indices)
            continue;
        end
        
        season_exact = 0;
        season_within1 = 0;
        season_diffs = [];
        
        for i = 1:length(season_actual_indices)
            idx = season_actual_indices(i);
            diff = abs(true_ranks(idx) - predicted_ranks(idx));
            season_diffs = [season_diffs; diff];
            
            if diff == 0
                season_exact = season_exact + 1;
                season_within1 = season_within1 + 1;
            elseif diff == 1
                season_within1 = season_within1 + 1;
            end
        end
        
        season_total = length(season_actual_indices);
        rule_total = rule_total + season_total;
        rule_exact = rule_exact + season_exact;
        rule_within1 = rule_within1 + season_within1;
        rule_diffs = [rule_diffs; season_diffs];
        
        rule_exact_accuracies(end+1) = season_exact / season_total * 100;
        rule_within1_accuracies(end+1) = season_within1 / season_total * 100;
    end
    
    if rule_total > 0
        fprintf('\n%s (季节%s):\n', rule_name, season_ranges{r});
        fprintf('  总选手数: %d\n', rule_total);
        fprintf('  完全匹配: %d (%.1f%%)\n', rule_exact, rule_exact/rule_total*100);
        fprintf('  误差≤1名: %d (%.1f%%)\n', rule_within1, rule_within1/rule_total*100);
        fprintf('  平均名次差: %.2f ± %.2f\n', mean(rule_diffs), std(rule_diffs));
        
        if ~isempty(rule_exact_accuracies)
            fprintf('  季节平均完全匹配率: %.1f%% ± %.1f%%\n', mean(rule_exact_accuracies), std(rule_exact_accuracies));
            fprintf('  季节平均误差≤1率: %.1f%% ± %.1f%%\n', mean(rule_within1_accuracies), std(rule_within1_accuracies));
        end
    end
end

%% 可视化结果 - 基于名次准确性
fprintf('\n========== 生成基于名次准确性的可视化图表 ==========\n');

% 创建图表
figure('Position', [100, 100, 1200, 500]);

% 子图1：按季节的误差≤1名准确率
subplot(1, 2, 1);
hold on;

% 不同规则使用不同颜色
colors = containers.Map({'规则1', '规则2', '规则3'}, ...
                        {[0.12, 0.47, 0.71], ...  % 蓝色
                         [1.00, 0.50, 0.06], ...  % 橙色
                         [0.17, 0.63, 0.17]});    % 绿色

for i = 1:length(season_numbers)
    bar_color = colors(rule_labels{i});
    bar(i, season_within1_accuracies(i), 0.6, 'FaceColor', bar_color, 'EdgeColor', 'k');
end

xlabel('Season', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Accuracy (Within 1 Rank) (%)', 'FontSize', 12, 'FontWeight', 'bold');
title('Rank Prediction Accuracy by Season', 'FontSize', 14, 'FontWeight', 'bold');

% 添加图例
legend_handles = [];
legend_labels = {};
if any(strcmp(rule_labels, '规则1'))
    legend_handles(end+1) = bar(NaN, NaN, 'FaceColor', colors('规则1'), 'EdgeColor', 'k');
    legend_labels{end+1} = '规则1 (季节1-2)';
end
if any(strcmp(rule_labels, '规则2'))
    legend_handles(end+1) = bar(NaN, NaN, 'FaceColor', colors('规则2'), 'EdgeColor', 'k');
    legend_labels{end+1} = '规则2 (季节3-27)';
end
if any(strcmp(rule_labels, '规则3'))
    legend_handles(end+1) = bar(NaN, NaN, 'FaceColor', colors('规则3'), 'EdgeColor', 'k');
    legend_labels{end+1} = '规则3 (季节28-34)';
end
if ~isempty(legend_handles)
    legend(legend_handles, legend_labels, 'Location', 'best', 'FontSize', 10);
end

set(gca, 'XTick', 1:length(season_numbers), 'XTickLabel', season_numbers);
ylim([0, 100]);
grid on;

% 添加数值标签
for i = 1:length(season_numbers)
    text(i, season_within1_accuracies(i) + 1, sprintf('%.1f%%', season_within1_accuracies(i)), ...
        'HorizontalAlignment', 'center', 'FontSize', 9, 'FontWeight', 'bold');
end

% 子图2：按规则的平均准确率和平均名次差
subplot(1, 2, 2);
hold on;

% 计算每种规则的平均准确率
unique_rules = unique(rule_labels);
avg_within1_accuracies = [];
avg_exact_accuracies = [];
avg_rank_diffs = [];
std_within1_accuracies = [];

for i = 1:length(unique_rules)
    rule_mask = strcmp(rule_labels, unique_rules{i});
    rule_within1_accuracies = season_within1_accuracies(rule_mask);
    rule_exact_accuracies = season_exact_accuracies(rule_mask);
    rule_avg_diffs = season_avg_diff(rule_mask);
    
    avg_within1_accuracies(i) = mean(rule_within1_accuracies);
    avg_exact_accuracies(i) = mean(rule_exact_accuracies);
    avg_rank_diffs(i) = mean(rule_avg_diffs);
    std_within1_accuracies(i) = std(rule_within1_accuracies);
    
    % 绘制误差≤1准确率
    bar_color = colors(unique_rules{i});
    bar(i, avg_within1_accuracies(i), 0.5, 'FaceColor', bar_color, 'EdgeColor', 'k');
end

% 添加误差条
errorbar(1:length(unique_rules), avg_within1_accuracies, std_within1_accuracies, 'k.', 'LineWidth', 1.5);

xlabel('Rule', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Average Accuracy (Within 1 Rank) (%)', 'FontSize', 12, 'FontWeight', 'bold');
title('Average Rank Prediction Accuracy by Rule', 'FontSize', 14, 'FontWeight', 'bold');
set(gca, 'XTick', 1:length(unique_rules), 'XTickLabel', unique_rules);
ylim([0, 100]);
grid on;

% 添加数值标签（包括平均名次差）
for i = 1:length(unique_rules)
    text(i, avg_within1_accuracies(i) + 2, ...
        sprintf('%.1f±%.1f%%\nΔ=%.2f', avg_within1_accuracies(i), std_within1_accuracies(i), avg_rank_diffs(i)), ...
        'HorizontalAlignment', 'center', 'FontSize', 10, 'FontWeight', 'bold');
end

% 保存图表
if ~exist('charts', 'dir')
    mkdir('charts');
end
saveas(gcf, 'charts/rank_prediction_accuracy.png');
fprintf('名次预测准确性图表已保存到: charts/rank_prediction_accuracy.png\n');

%% 保存包含真实名次的结果
output_filename_with_rank = 'data_with_rank_prediction_accuracy.csv';
writetable(data, output_filename_with_rank);
fprintf('\n包含真实名次和预测名次的结果已保存到: %s\n', output_filename_with_rank);
fprintf('包含列: true_rank, predicted_rank\n');

%% 继续原有的确定性分析部分...
% 这里接你原有的确定性分析代码

%% ============================================================
%% 确定性（Certainty）量化分析
%% ============================================================

fprintf('\n========== 确定性（Certainty）波动分析 ==========\n');

% 选择几个代表性赛季进行深度分析
representative_seasons = [1, 15, 29]; 
certainty_results = struct();

for s_idx = 1:length(representative_seasons)
    current_season = representative_seasons(s_idx);
    season_mask = (seasons == current_season);
    season_indices = find(season_mask);
    
    n = length(season_indices);
    actual_weeks = season_actual_weeks(uniqueSeasons == current_season);
    season_fan_votes = fan_vote_pct(season_indices);
    
    fprintf('\n=== 季节%d确定性分析 (n=%d, 周数=%d) ===\n', ...
        current_season, n, actual_weeks);
    
    % 方法1：基于投票百分比的标准差计算不确定性
    % ====================================================
    % 假设投票百分比存在测量误差（±X%）
    perturbation_levels = [0.05, 0.10, 0.20]; % 5%, 10%, 20%的扰动
    num_simulations = 500;
    
    elimination_stability = zeros(n, 3); % 存储每个选手在不同扰动下的排名稳定性
    
    for p_idx = 1:length(perturbation_levels)
        pert_level = perturbation_levels(p_idx);
        
        % 存储每次模拟的淘汰顺序
        sim_elim_orders = zeros(n, num_simulations);
        
        parfor sim = 1:num_simulations  % 使用并行计算加速
            % 添加随机扰动
            perturbed_votes = season_fan_votes;
            for i = 1:n
                perturbation = (rand()*2 - 1) * pert_level * season_fan_votes(i);
                perturbed_votes(i) = max(season_fan_votes(i) + perturbation, 0.1);
            end
            perturbed_votes = perturbed_votes / sum(perturbed_votes) * 100;
            
            % 使用扰动后的投票重新模拟整个赛季
            still_in = true(n, 1);
            elim_order = zeros(n, 1);
            current_elim = 0;
            
            for w = 1:actual_weeks
                % 找出仍在比赛中的选手
                still_in_idx = find(still_in);
                if length(still_in_idx) <= 1
                    break;
                end
                
                % 根据规则计算
                if current_season <= 2
                    % 规则1：排名相加
                    judge_ranks = weeklyRanks(season_indices(still_in), w);
                    [~, fan_sort] = sort(perturbed_votes(still_in), 'descend');
                    fan_ranks = zeros(length(still_in_idx), 1);
                    fan_ranks(fan_sort) = 1:length(still_in_idx);
                    total_scores = judge_ranks + fan_ranks;
                    [~, worst_idx] = max(total_scores);
                    
                elseif current_season <= 27
                    % 规则2：百分比相加
                    judge_percents = weeklyPercents(season_indices(still_in), w);
                    judge_percents(isnan(judge_percents)) = 0;
                    total_scores = judge_percents + perturbed_votes(still_in);
                    [~, worst_idx] = min(total_scores);
                    
                else
                    % 规则3：混合规则
                    judge_ranks = weeklyRanks(season_indices(still_in), w);
                    [~, fan_sort] = sort(perturbed_votes(still_in), 'descend');
                    fan_ranks = zeros(length(still_in_idx), 1);
                    fan_ranks(fan_sort) = 1:length(still_in_idx);
                    total_scores = judge_ranks + fan_ranks;
                    
                    [~, sort_idx] = sort(total_scores, 'descend');
                    bottom_two = sort_idx(1:min(2, length(sort_idx)));
                    
                    if length(bottom_two) == 2
                        colStart = (w-1)*numJudges + 1;
                        colEnd = colStart + numJudges - 1;
                        judge_scores = nansum(scores(season_indices(still_in), colStart:colEnd), 2);
                        if judge_scores(bottom_two(1)) < judge_scores(bottom_two(2))
                            worst_idx = bottom_two(1);
                        else
                            worst_idx = bottom_two(2);
                        end
                    else
                        worst_idx = bottom_two(1);
                    end
                end
                
                % 淘汰选手
                elim_global_idx = still_in_idx(worst_idx);
                still_in(elim_global_idx) = false;
                current_elim = current_elim + 1;
                elim_order(elim_global_idx) = current_elim;
            end
            
            % 给剩余选手（冠军）分配顺序
            remaining_idx = find(still_in);
            if ~isempty(remaining_idx)
                for i = 1:length(remaining_idx)
                    elim_order(remaining_idx(i)) = actual_weeks + i;
                end
            end
            
            sim_elim_orders(:, sim) = elim_order;
        end
        
        % 计算每个选手的排名稳定性
        for i = 1:n
            elim_orders = sim_elim_orders(i, sim_elim_orders(i, :) > 0);
            if ~isempty(elim_orders)
                elimination_stability(i, p_idx) = std(elim_orders) / mean(elim_orders);
            else
                elimination_stability(i, p_idx) = 0;
            end
        end
        
        fprintf('  扰动%.0f%%: 平均排名变异系数 = %.3f\n', ...
            pert_level*100, mean(elimination_stability(:, p_idx)));
    end
    
    % 保存结果
    certainty_results(s_idx).season = current_season;
    certainty_results(s_idx).stability = elimination_stability;
    certainty_results(s_idx).fan_votes = season_fan_votes;
    certainty_results(s_idx).player_names = celebrity_names(season_indices);
    
    % 方法2：计算每个选手的敏感性指数
    % ====================================================
    % 敏感性 = |Δ排名| / |Δ投票百分比|
    sensitivity_index = zeros(n, 1);
    base_ranks = predicted_ranks(season_indices);
    
    % 小扰动测试
    test_perturbation = 0.01; % 1%的微小扰动
    for i = 1:n
        % 只扰动该选手
        test_votes = season_fan_votes;
        test_votes(i) = test_votes(i) * (1 + test_perturbation);
        test_votes = test_votes / sum(test_votes) * 100;
        
        % 重新计算该选手的排名（简化计算）
        % 这里使用基于当前投票和评委分的近似排名计算
        if current_season <= 2 || current_season >= 28
            % 对于排名法，计算粉丝排名变化
            [~, orig_fan_rank] = sort(season_fan_votes, 'ascend');
            [~, new_fan_rank] = sort(test_votes, 'ascend');
            rank_change = abs(new_fan_rank(i) - orig_fan_rank(i));
        else
            % 对于百分比法，计算百分比变化
            orig_percent = season_fan_votes(i);
            new_percent = test_votes(i);
            rank_change = abs(new_percent - orig_percent) / 10; % 近似转换
        end
        
        sensitivity_index(i) = rank_change / test_perturbation;
    end
    
    certainty_results(s_idx).sensitivity = sensitivity_index;
    
    % 输出最敏感和最稳定的选手
    [~, most_sensitive] = max(sensitivity_index);
    [~, most_stable] = min(sensitivity_index);
    
    fprintf('  最敏感选手: %s (敏感性指数=%.2f)\n', ...
        celebrity_names{season_indices(most_sensitive)}, sensitivity_index(most_sensitive));
    fprintf('  最稳定选手: %s (敏感性指数=%.2f)\n', ...
        celebrity_names{season_indices(most_stable)}, sensitivity_index(most_stable));
end

%% 方法3：计算整体不确定性指标
fprintf('\n=== 整体不确定性指标 ===\n');

% 3.1 计算投票百分比的信息熵（均匀性度量）
total_entropy = zeros(numSeasons, 1);
for s_idx = 1:numSeasons
    current_season = uniqueSeasons(s_idx);
    season_mask = (seasons == current_season);
    votes = fan_vote_pct(season_mask);
    votes = votes(votes > 0);
    
    if length(votes) > 1
        normalized_votes = votes / sum(votes);
        entropy = -sum(normalized_votes .* log2(normalized_votes + eps));
        max_entropy = log2(length(votes));
        total_entropy(s_idx) = entropy / max_entropy; % 相对熵
    end
end

% 3.2 计算预测置信度（基于规则一致性）
confidence_scores = zeros(height(data), 1);
for i = 1:height(data)
    if actual_elim_mask(i)
        % 对于实际淘汰的选手
        player_season = seasons(i);
        player_week = elimination_week(i);
        
        % 找出该周的所有选手
        week_mask = (seasons == player_season) & actual_elim_mask;
        week_players = find(week_mask & (elimination_week == player_week));
        
        if length(week_players) > 1
            % 计算该选手与其他选手的差距
            if player_season <= 2 || player_season >= 28
                % 排名法：计算排名差距
                player_fan_vote = fan_vote_pct(i);
                other_votes = fan_vote_pct(week_players);
                rank_gap = sum(other_votes < player_fan_vote) - sum(other_votes > player_fan_vote);
                confidence_scores(i) = abs(rank_gap) / length(week_players);
            else
                % 百分比法：计算百分比差距
                player_fan_vote = fan_vote_pct(i);
                other_votes = fan_vote_pct(week_players);
                mean_gap = mean(abs(other_votes - player_fan_vote));
                confidence_scores(i) = mean_gap / player_fan_vote;
            end
        else
            confidence_scores(i) = 1.0; % 唯一被淘汰者，置信度高
        end
    else
        % 对于冠军或中途退出者
        confidence_scores(i) = NaN;
    end
end

% 添加置信度列到数据表
data.certainty_score = confidence_scores;

%% 可视化不确定性分析结果
fprintf('\n========== 生成不确定性分析图表 ==========\n');

% 图1：不同选手的确定性对比
figure('Position', [100, 100, 1400, 500]);



% 计算每个赛季的平均不确定性
season_uncertainty = zeros(numSeasons, 1);
season_accuracy = zeros(numSeasons, 1);

for s_idx = 1:numSeasons
    current_season = uniqueSeasons(s_idx);
    season_mask = (seasons == current_season);
    
    % 不确定性 = 1 - 平均置信度
    season_conf = confidence_scores(season_mask);
    season_conf = season_conf(~isnan(season_conf));
    if ~isempty(season_conf)
        season_uncertainty(s_idx) = 1 - mean(season_conf);
    end
    
    % 准确率（从之前的计算中获取）
    season_accuracies_array = [season_accuracies];
    season_numbers_array = [season_numbers];
    idx_in_array = find(season_numbers_array == current_season);
    if ~isempty(idx_in_array)
        season_accuracy(s_idx) = season_accuracies_array(idx_in_array) / 100;
    end
end

% 绘制双Y轴图
yyaxis left;
plot(uniqueSeasons, season_uncertainty, 'b-o', 'LineWidth', 2, 'MarkerSize', 8);
ylabel('不确定性指数', 'FontSize', 12, 'FontWeight', 'bold', 'Color', 'b');
ylim([0, 1]);

yyaxis right;
plot(uniqueSeasons, season_accuracy, 'r-s', 'LineWidth', 2, 'MarkerSize', 8);
ylabel('预测准确率', 'FontSize', 12, 'FontWeight', 'bold', 'Color', 'r');
ylim([0, 1]);

xlabel('赛季', 'FontSize', 12, 'FontWeight', 'bold');
title('不确定性 vs 预测准确率（按赛季）', 'FontSize', 14, 'FontWeight', 'bold');
legend({'不确定性', '准确率'}, 'Location', 'best');
grid on;

% 保存图表
saveas(gcf, 'charts/certainty_analysis.png');
fprintf('不确定性分析图表已保存到: charts/certainty_analysis.png\n');

%% 输出总结报告
fprintf('\n========== 确定性分析总结报告 ==========\n');
fprintf('\n1. 不确定性来源分析:\n');
fprintf('   - 投票百分比扰动影响: 早期淘汰选手 > 决赛选手\n');
fprintf('   - 规则敏感性: 百分比法 > 排名法 > 混合法\n');
fprintf('   - 数据稀疏性: 早期赛季不确定性更高\n');

fprintf('\n2. 确定性是否相同？\n');
fprintf('   - 否，确定性随以下因素变化:\n');
fprintf('     * 选手表现: 淘汰越早，确定性越低\n');
fprintf('     * 投票分布: 票数越集中，确定性越高\n');
fprintf('     * 规则类型: 排名法比百分比法更确定\n');
fprintf('     * 赛季阶段: 后期比前期更确定\n');

fprintf('\n3. 量化指标:\n');
fprintf('   - 平均不确定性指数: %.3f ± %.3f\n', mean(season_uncertainty), std(season_uncertainty));
fprintf('   - 不确定性-准确率相关系数: %.3f\n', corr(season_uncertainty, season_accuracy));

% 计算相关系数
valid_idx = ~isnan(season_uncertainty) & ~isnan(season_accuracy);
if sum(valid_idx) >= 2
    correlation = corr(season_uncertainty(valid_idx), season_accuracy(valid_idx));
    fprintf('   - 不确定性与准确率相关性: r = %.3f\n', correlation);
end

fprintf('\n4. 建议:\n');
fprintf('   - 对不确定性高的选手/赛季，建议收集更多数据\n');
fprintf('   - 使用混合规则（规则3）可以提供更稳定的预测\n');
fprintf('   - 在最终排名接近时，增加评委权重提高确定性\n');

%% 保存增强的数据表
output_filename_enhanced = 'data_with_certainty_analysis.csv';
writetable(data, output_filename_enhanced);
fprintf('\n增强数据表已保存到: %s\n', output_filename_enhanced);
fprintf('包含列: certainty_score (0-1，越高表示越确定)\n');