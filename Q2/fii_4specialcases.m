%% 专门分析四位选手：Jerry Rice, Billy Ray Cyrus, Bristol Palin, Bobby Bones
clear; clc; close all;
cd('C:\Users\LCY\Desktop\学习\课余\比赛\美赛\正式比赛\Data')
%% 读取数据
filename = 'weekly_data_with_all_predictions_final.csv';
opts = detectImportOptions(filename);
% 设置变量类型
opts = setvartype(opts, {'rank_predicted', 'percent_predicted'}, 'string');
% 读取数据
data = readtable(filename, opts);
fan_vote_pct = data.fan_vote_pct_combined;
%% 定义目标选手
target_names = {'Jerry Rice', 'Billy Ray Cyrus', 'Bristol Palin', 'Bobby Bones'};

% 检查哪些选手在数据中
fprintf('=== 查找目标选手 ===\n');
found_names = {};
found_indices = [];

for i = 1:length(target_names)
    idx = find(strcmp(data.x__elebrity_name, target_names{i}));
    if ~isempty(idx)
        % 确保只取第一个匹配（如果有多个）
        if length(idx) > 1
            fprintf('找到多个匹配: %s，取第一个 (索引: %d)\n', target_names{i}, idx(1));
            idx = idx(1);
        end
        
        found_names{end+1} = target_names{i};
        % 修复这里：使用 concatenation 而不是 end+1
        found_indices = [found_indices, idx];
        fprintf('找到: %s (索引: %d)\n', target_names{i}, idx);
    else
        fprintf('未找到: %s\n', target_names{i});
    end
end

% 检查是否找到Bobby Bones，如果没找到，输出所有选手名字帮助调试
if ~any(strcmp(found_names, 'Bobby Bones'))
    fprintf('\n注意: 数据中没有找到Bobby Bones\n');
    fprintf('数据中的选手有:\n');
    unique_names = unique(data.x__elebrity_name);
    for i = 1:min(20, length(unique_names))  % 只显示前20个
        fprintf('  %s\n', unique_names{i});
    end
    if length(unique_names) > 20
        fprintf('  ... 还有更多\n');
    end
end

if isempty(found_indices)
    error('未找到任何目标选手！');
end

fprintf('\n=== 找到的选手 ===\n');
for i = 1:length(found_names)
    fprintf('%d. %s (索引: %d)\n', i, found_names{i}, found_indices(i));
end

%% 提取基础数据
numJudges = 3;  % 假设每周有3位裁判
max_week = 11;  % 最大周数

% 提取裁判分数 - 修复cell转换问题
score_cols = {};
for w = 1:max_week
    for j = 1:numJudges
        score_cols{end+1} = sprintf('week%d_judge%d_score', w, j);
    end
end

scores = zeros(height(data), length(score_cols));
for i = 1:length(score_cols)
    if ismember(score_cols{i}, data.Properties.VariableNames)
        col_data = data.(score_cols{i});
        % 处理cell类型数据
        if iscell(col_data)
            % 将cell转换为double，处理非数值
            temp_data = zeros(size(col_data));
            for k = 1:length(col_data)
                if isnumeric(col_data{k})
                    temp_data(k) = col_data{k};
                elseif ischar(col_data{k})
                    % 尝试转换字符为数字
                    temp_val = str2double(col_data{k});
                    if ~isnan(temp_val)
                        temp_data(k) = temp_val;
                    else
                        temp_data(k) = NaN;
                    end
                else
                    temp_data(k) = NaN;
                end
            end
            scores(:, i) = temp_data;
        else
            scores(:, i) = col_data;
        end
    else
        fprintf('警告: 列 %s 不存在于数据中\n', score_cols{i});
    end
end

% 提取每周排名和百分比
weeklyRanks = zeros(height(data), max_week);
weeklyPercents = zeros(height(data), max_week);

for w = 1:max_week
    rank_col = sprintf('week%d_rank', w);
    pct_col = sprintf('week%d_pct', w);
    
    if ismember(rank_col, data.Properties.VariableNames)
        col_data = data.(rank_col);
        if iscell(col_data)
            temp_data = zeros(size(col_data));
            for k = 1:length(col_data)
                if isnumeric(col_data{k})
                    temp_data(k) = col_data{k};
                elseif ischar(col_data{k})
                    temp_val = str2double(col_data{k});
                    temp_data(k) = temp_val;
                else
                    temp_data(k) = NaN;
                end
            end
            weeklyRanks(:, w) = temp_data;
        else
            weeklyRanks(:, w) = col_data;
        end
    else
        fprintf('警告: 列 %s 不存在于数据中\n', rank_col);
    end
    
    if ismember(pct_col, data.Properties.VariableNames)
        col_data = data.(pct_col);
        if iscell(col_data)
            temp_data = zeros(size(col_data));
            for k = 1:length(col_data)
                if isnumeric(col_data{k})
                    temp_data(k) = col_data{k};
                elseif ischar(col_data{k})
                    temp_val = str2double(col_data{k});
                    temp_data(k) = temp_val;
                else
                    temp_data(k) = NaN;
                end
            end
            weeklyPercents(:, w) = temp_data;
        else
            weeklyPercents(:, w) = col_data;
        end
    else
        fprintf('警告: 列 %s 不存在于数据中\n', pct_col);
    end
end

% 提取淘汰周数
elimination_week = data.elimination_week;
seasons = data.season;

% 初始化FII存储
fii_rank_individual = cell(length(found_indices), 1);
fii_percent_individual = cell(length(found_indices), 1);
fii_judge_individual = cell(length(found_indices), 1);
week_info_individual = cell(length(found_indices), 1);

%% 为每位选手计算FII
for target_idx = 1:length(found_indices)
    idx = found_indices(target_idx);
    name = found_names{target_idx};
    
    % 确保索引有效
    if idx < 1 || idx > height(data)
        fprintf('错误: 选手 %s 的索引 %d 无效\n', name, idx);
        continue;
    end
    
    season = data.season(idx);
    
    fprintf('\n=== 处理选手: %s (索引: %d, 赛季: %d) ===\n', name, idx, season);
    
    % 找出同赛季的所有选手
    season_mask = (seasons == season);
    season_indices = find(season_mask);
    
    if isempty(season_indices)
        fprintf('  警告: 没有找到赛季 %d 的选手\n', season);
        continue;
    end
    
    % 找出最大淘汰周数
    elim_weeks = elimination_week(season_indices);
    % 处理Inf值
    elim_weeks(elim_weeks == Inf) = max_week;
    valid_elim_weeks = elim_weeks(~isnan(elim_weeks));
    
    if isempty(valid_elim_weeks)
        max_elim_week_season = max_week;
    else
        max_elim_week_season = min(max_week, max(valid_elim_weeks));
    end
    
    fprintf('  最大淘汰周数: %d\n', max_elim_week_season);
    
    % 初始化该选手的FII存储
    fii_rank_personal = [];
    fii_percent_personal = [];
    fii_judge_personal = [];
    weeks_personal = [];
    
    % 每周计算FII
    for w = 1:max_elim_week_season
        % 检查选手本周是否仍在比赛中
        if elimination_week(idx) < w
            fprintf('  第%d周: 选手已被淘汰 (淘汰周: %d)\n', w, elimination_week(idx));
            break;
        end
        
        % 找出该周仍在比赛中的所有选手
        still_in_mask = false(length(season_indices), 1);
        for i = 1:length(season_indices)
            s_idx = season_indices(i);
            if elimination_week(s_idx) >= w
                still_in_mask(i) = true;
            end
        end
        
        still_in_idx = season_indices(still_in_mask);
        
        if length(still_in_idx) <= 1
            fprintf('  第%d周: 只有%d位选手在比赛中\n', w, length(still_in_idx));
            continue;
        end
        
        % 检查目标选手是否在其中
        if ~ismember(idx, still_in_idx)
            fprintf('  第%d周: 选手不在比赛中\n', w);
            continue;
        end
        
        % 获取本周数据
        week_ranks_data = weeklyRanks(still_in_idx, w);
        week_pct_data = weeklyPercents(still_in_idx, w);
        
        % 获取裁判原始分数
        colStart = (w-1)*numJudges + 1;
        colEnd = colStart + numJudges - 1;
        
        % 确保索引在范围内
        if colEnd > size(scores, 2)
            colEnd = size(scores, 2);
        end
        
        week_scores = nansum(scores(still_in_idx, colStart:colEnd), 2);
        
        % 处理NaN值 - 如果没有有效分数，跳过本周
        if all(isnan(week_scores))
            fprintf('  第%d周: 所有选手分数均为NaN\n', w);
            continue;
        end
        
        % 将NaN替换为最小分数-1，确保它们排名最后
        week_scores_filled = week_scores;
        valid_scores = week_scores_filled(~isnan(week_scores_filled));
        if isempty(valid_scores)
            min_score = 0;
        else
            min_score = min(valid_scores);
        end
        week_scores_filled(isnan(week_scores_filled)) = min_score - 10;
        
        % 计算裁判排名（分数越高排名越好）
        [~, judge_rank_idx] = sort(week_scores_filled, 'descend');
        judge_rank = zeros(length(still_in_idx), 1);
        for i = 1:length(judge_rank_idx)
            judge_rank(judge_rank_idx(i)) = i;
        end
        
        % 计算粉丝排名（排名法）
        if ~all(isnan(week_ranks_data))
            week_ranks_filled = week_ranks_data;
            % 找出最大的有效排名
            max_valid_rank = max(week_ranks_filled(~isnan(week_ranks_filled)));
            if isempty(max_valid_rank)
                max_valid_rank = length(still_in_idx);
            end
            week_ranks_filled(isnan(week_ranks_filled)) = max_valid_rank + 1;
            [~, fan_rank_rank_idx] = sort(week_ranks_filled, 'descend');
            fan_rank_rank = zeros(length(still_in_idx), 1);
            for i = 1:length(fan_rank_rank_idx)
                fan_rank_rank(fan_rank_rank_idx(i)) = i;
            end
        else
            % 如果排名数据缺失，使用百分比数据
            fan_rank_rank = ones(length(still_in_idx), 1) * length(still_in_idx);
        end
        
        % 计算粉丝排名（百分比法）
        if ~all(isnan(week_pct_data))
            week_pct_data_filled = week_pct_data;
            % 找出最小的有效百分比
            min_valid_pct = min(week_pct_data_filled(~isnan(week_pct_data_filled)));
            if isempty(min_valid_pct)
                min_valid_pct = 0;
            end
            week_pct_data_filled(isnan(week_pct_data_filled)) = min_valid_pct - 1;
            [~, fan_rank_pct_idx] = sort(week_pct_data_filled, 'descend');
            fan_rank_pct = zeros(length(still_in_idx), 1);
            for i = 1:length(fan_rank_pct_idx)
                fan_rank_pct(fan_rank_pct_idx(i)) = i;
            end
        else
            % 如果百分比数据缺失，使用排名数据
            fan_rank_pct = fan_rank_rank;
        end
        
        % 找到目标选手在still_in_idx中的位置
        target_in_local = find(still_in_idx == idx);
        
        if isempty(target_in_local)
            fprintf('  第%d周: 未找到选手位置\n', w);
            continue;
        end
        
        % 计算三种方法的最终排名
        % 1. 排名法最终排名
        total_rank_score = judge_rank + fan_rank_rank;
        [~, final_rank_rank_idx] = sort(total_rank_score, 'ascend');
        final_rank_rank = zeros(length(still_in_idx), 1);
        for i = 1:length(final_rank_rank_idx)
            final_rank_rank(final_rank_rank_idx(i)) = i;
        end
        
        % 2. 百分比法最终排名
        % 简化处理：使用加权平均
        total_pct_score = zeros(length(still_in_idx), 1);
        total_score = sum(week_scores_filled);
        if total_score > 0
            for i = 1:length(still_in_idx)
                judge_pct = week_scores_filled(i) / total_score;
                fan_pct_normalized = 1 - (fan_rank_pct(i) - 1) / (length(still_in_idx) - 1);
                if isnan(fan_pct_normalized) || isinf(fan_pct_normalized)
                    fan_pct_normalized = 0.5;
                end
                total_pct_score(i) = judge_pct + fan_pct_normalized;
            end
        else
            total_pct_score = zeros(length(still_in_idx), 1);
        end
        [~, final_rank_pct_idx] = sort(total_pct_score, 'descend');
        final_rank_pct = zeros(length(still_in_idx), 1);
        for i = 1:length(final_rank_pct_idx)
            final_rank_pct(final_rank_pct_idx(i)) = i;
        end
        
        % 3. 裁判选择法最终排名
        combined_rank = (judge_rank + fan_rank_rank) / 2;
        [~, sorted_idx] = sort(combined_rank, 'descend');
        bottom_two_idx = sorted_idx(1:min(2, length(sorted_idx)));
        
        if length(bottom_two_idx) == 2
            if week_scores_filled(bottom_two_idx(1)) < week_scores_filled(bottom_two_idx(2))
                eliminated_idx_judge = bottom_two_idx(1);
            else
                eliminated_idx_judge = bottom_two_idx(2);
            end
        else
            eliminated_idx_judge = bottom_two_idx(1);
        end
        
        final_rank_judge = zeros(length(still_in_idx), 1);
        for i = 1:length(still_in_idx)
            if i == eliminated_idx_judge
                final_rank_judge(i) = length(still_in_idx);
            else
                final_rank_judge(i) = find(sorted_idx == i);
            end
        end
        
        % 计算该选手的FII值
        % 排名法FII
        Dj_rank = abs(judge_rank(target_in_local) - final_rank_rank(target_in_local));
        Df_rank = abs(fan_rank_rank(target_in_local) - final_rank_rank(target_in_local));
        denominator_rank = Dj_rank + Df_rank;
        if denominator_rank > 0
            fii_rank_val = Dj_rank / denominator_rank;
        else
            fii_rank_val = 0.5;
        end
        
        % 百分比法FII
        Dj_percent = abs(judge_rank(target_in_local) - final_rank_pct(target_in_local));
        Df_percent = abs(fan_rank_pct(target_in_local) - final_rank_pct(target_in_local));
        denominator_percent = Dj_percent + Df_percent;
        if denominator_percent > 0
            fii_percent_val = Dj_percent / denominator_percent;
        else
            fii_percent_val = 0.5;
        end
        
        % 裁判选择法FII
        Dj_judge = abs(judge_rank(target_in_local) - final_rank_judge(target_in_local));
        Df_judge = abs(fan_rank_rank(target_in_local) - final_rank_judge(target_in_local));
        denominator_judge = Dj_judge + Df_judge;
        if denominator_judge > 0
            fii_judge_val = Dj_judge / denominator_judge;
        else
            fii_judge_val = 0.5;
        end
        
        % 存储结果
        fii_rank_personal = [fii_rank_personal; fii_rank_val];
        fii_percent_personal = [fii_percent_personal; fii_percent_val];
        fii_judge_personal = [fii_judge_personal; fii_judge_val];
        weeks_personal = [weeks_personal; w];
        
        fprintf('  第%d周: 排名法FII=%.3f, 百分比法FII=%.3f, 裁判选择法FII=%.3f\n', ...
                w, fii_rank_val, fii_percent_val, fii_judge_val);
    end
    
    % 存储该选手的所有FII数据
    fii_rank_individual{target_idx} = fii_rank_personal;
    fii_percent_individual{target_idx} = fii_percent_personal;
    fii_judge_individual{target_idx} = fii_judge_personal;
    week_info_individual{target_idx} = weeks_personal;
    
    if isempty(weeks_personal)
        fprintf('  警告: 选手 %s 没有有效的FII数据\n', name);
    else
        fprintf('  选手 %s 有 %d 周的FII数据\n', name, length(weeks_personal));
    end
end

%% 检查哪些选手有数据
valid_players = [];
for target_idx = 1:length(found_indices)
    if ~isempty(week_info_individual{target_idx})
        valid_players = [valid_players, target_idx];
    end
end

if isempty(valid_players)
    error('没有选手有有效的FII数据！');
end

fprintf('\n=== 有效的选手 ===\n');
for i = 1:length(valid_players)
    target_idx = valid_players(i);
    fprintf('%d. %s (%d周数据)\n', i, found_names{target_idx}, ...
            length(week_info_individual{target_idx}));
end

%% 可视化：有数据选手的FII对比
figure('Position', [100, 100, 1400, 800], 'Name', '选手FII分析', 'NumberTitle', 'off');

colors = [0.2 0.6 0.8; 0.8 0.4 0.2; 0.4 0.8 0.4; 0.8 0.6 0.2; 0.6 0.2 0.8; 0.2 0.8 0.6];
markers = {'o', 's', '^', 'd', 'v', '>'};

% 只使用有效的选手
use_names = found_names(valid_players);
use_fii_rank = fii_rank_individual(valid_players);
use_fii_percent = fii_percent_individual(valid_players);
use_fii_judge = fii_judge_individual(valid_players);
use_week_info = week_info_individual(valid_players);

% 子图1：三种方法的FII对比
for method_idx = 1:3
    subplot(2, 3, method_idx);
    hold on;
    grid on;
    
    for target_idx = 1:length(valid_players)
        weeks = use_week_info{target_idx};
        
        switch method_idx
            case 1
                fii_data = use_fii_rank{target_idx};
                method_name = '排名法FII';
            case 2
                fii_data = use_fii_percent{target_idx};
                method_name = '百分比法FII';
            case 3
                fii_data = use_fii_judge{target_idx};
                method_name = '裁判选择法FII';
        end
        
        if ~isempty(weeks) && ~isempty(fii_data)
            plot(weeks, fii_data, markers{target_idx}, ...
                 'LineWidth', 2, 'MarkerSize', 8, ...
                 'MarkerFaceColor', colors(target_idx, :), ...
                 'MarkerEdgeColor', 'k', ...
                 'DisplayName', use_names{target_idx});
        end
    end
    
    % 添加0.5参考线
line(xlim, [0.5 0.5], 'Color', 'k', 'LineStyle', '--', 'LineWidth', 1.5, 'DisplayName', '平衡线');
    
    xlabel('周数', 'FontSize', 12);
    ylabel('FII值', 'FontSize', 12);
    title(method_name, 'FontSize', 14, 'FontWeight', 'bold');
    legend('Location', 'best');
    ylim([0 1]);
    
    % 添加解释文本
    text(0.5, 0.1, 'FII<0.5: 粉丝影响更大', 'Units', 'normalized', ...
         'FontSize', 10, 'Color', 'b');
    text(0.5, 0.05, 'FII>0.5: 裁判影响更大', 'Units', 'normalized', ...
         'FontSize', 10, 'Color', 'r');
end

% 子图4：平均FII对比
subplot(2, 3, 4);
hold on;
grid on;

avg_fii_rank = zeros(length(valid_players), 1);
avg_fii_percent = zeros(length(valid_players), 1);
avg_fii_judge = zeros(length(valid_players), 1);

for i = 1:length(valid_players)
    target_idx = valid_players(i);
    
    if ~isempty(use_fii_rank{i})
        avg_fii_rank(i) = mean(use_fii_rank{i});
    else
        avg_fii_rank(i) = NaN;
    end
    
    if ~isempty(use_fii_percent{i})
        avg_fii_percent(i) = mean(use_fii_percent{i});
    else
        avg_fii_percent(i) = NaN;
    end
    
    if ~isempty(use_fii_judge{i})
        avg_fii_judge(i) = mean(use_fii_judge{i});
    else
        avg_fii_judge(i) = NaN;
    end
end

% 过滤掉NaN值
valid_avg_idx = ~isnan(avg_fii_rank) & ~isnan(avg_fii_percent) & ~isnan(avg_fii_judge);
if any(valid_avg_idx)
    bar_data = [avg_fii_rank(valid_avg_idx), avg_fii_percent(valid_avg_idx), avg_fii_judge(valid_avg_idx)];
    bar_handle = bar(1:sum(valid_avg_idx), bar_data, 'grouped');
    
    for i = 1:3
        bar_handle(i).FaceColor = colors(i, :);
    end
    
    % 添加数值标签
    for i = 1:sum(valid_avg_idx)
        for j = 1:3
            if ~isnan(bar_data(i, j))
                text(i + (j-2)*0.25, bar_data(i, j) + 0.02, ...
                     sprintf('%.3f', bar_data(i, j)), ...
                     'HorizontalAlignment', 'center', 'FontSize', 9);
            end
        end
    end
    
    xlabel('选手', 'FontSize', 12);
    ylabel('平均FII值', 'FontSize', 12);
    title('平均FII值对比', 'FontSize', 14, 'FontWeight', 'bold');
    set(gca, 'XTick', 1:sum(valid_avg_idx), 'XTickLabel', use_names(valid_avg_idx));
    legend({'排名法', '百分比法', '裁判选择法'}, 'Location', 'best');
    ylim([0 1]);
    line(xlim, [0.5 0.5], 'Color', 'k', 'LineStyle', '--', 'LineWidth', 1.5);
else
    text(0.5, 0.5, '没有有效数据', 'HorizontalAlignment', 'center', 'FontSize', 14);
    title('平均FII值对比', 'FontSize', 14, 'FontWeight', 'bold');
end

% 子图5：简化版的FII对比图
subplot(2, 3, 5);
hold on;
grid on;

% 准备数据
n_players = length(valid_players);
player_indices = 1:n_players;

% 绘制条形图
bar_width = 0.25;
offset = bar_width * 0.5;

% 排名法
bar(player_indices - bar_width, avg_fii_rank, bar_width, 'FaceColor', 'r', 'EdgeColor', 'k');

% 百分比法
bar(player_indices, avg_fii_percent, bar_width, 'FaceColor', 'b', 'EdgeColor', 'k');

% 裁判选择法
bar(player_indices + bar_width, avg_fii_judge, bar_width, 'FaceColor', 'g', 'EdgeColor', 'k');

% 添加0.5参考线
plot([0.5, n_players + 0.5], [0.5, 0.5], 'k--', 'LineWidth', 1.5);

% 设置坐标轴
xlabel('选手', 'FontSize', 12);
ylabel('平均FII值', 'FontSize', 12);
title('平均FII对比', 'FontSize', 14, 'FontWeight', 'bold');
set(gca, 'XTick', player_indices, 'XTickLabel', use_names);
legend({'排名法', '百分比法', '裁判选择法'}, 'Location', 'best');
ylim([0 1]);

% 添加数值标签
for i = 1:n_players
    text(i - bar_width, avg_fii_rank(i) + 0.02, sprintf('%.2f', avg_fii_rank(i)), ...
         'HorizontalAlignment', 'center', 'FontSize', 8);
    text(i, avg_fii_percent(i) + 0.02, sprintf('%.2f', avg_fii_percent(i)), ...
         'HorizontalAlignment', 'center', 'FontSize', 8);
    text(i + bar_width, avg_fii_judge(i) + 0.02, sprintf('%.2f', avg_fii_judge(i)), ...
         'HorizontalAlignment', 'center', 'FontSize', 8);
end

% 子图6：影响力类型总结
subplot(2, 3, 6);
axis off;

summary_text = cell(0, 1);
summary_text{end+1} = '=== 选手FII分析总结 ===';
summary_text{end+1} = '';

for i = 1:length(valid_players)
    target_idx = valid_players(i);
    name = use_names{i};
    idx = found_indices(target_idx);
    
    if idx >= 1 && idx <= height(data)
        season = data.season(idx);
        final_rank = data.placement(idx);
        
        summary_text{end+1} = sprintf('选手: %s', name);
        summary_text{end+1} = sprintf('  赛季: %d', season);
        summary_text{end+1} = sprintf('  最终排名: %d', final_rank);
        
        % 检查是否有数据
        if isempty(use_fii_rank{i})
            summary_text{end+1} = '  无有效FII数据';
            summary_text{end+1} = '';
            continue;
        end
        
        % 判断主要影响力
        avg_rank = avg_fii_rank(i);
        avg_percent = avg_fii_percent(i);
        avg_judge = avg_fii_judge(i);
        
        summary_text{end+1} = sprintf('  平均FII值:');
        summary_text{end+1} = sprintf('    排名法: %.3f', avg_rank);
        summary_text{end+1} = sprintf('    百分比法: %.3f', avg_percent);
        summary_text{end+1} = sprintf('    裁判选择法: %.3f', avg_judge);
        
        % 判断主要影响类型
        if avg_rank < 0.5
            influence_rank = '粉丝影响更大';
        else
            influence_rank = '裁判影响更大';
        end
        
        if avg_percent < 0.5
            influence_percent = '粉丝影响更大';
        else
            influence_percent = '裁判影响更大';
        end
        
        if avg_judge < 0.5
            influence_judge = '粉丝影响更大';
        else
            influence_judge = '裁判影响更大';
        end
        
        summary_text{end+1} = sprintf('  主要影响类型:');
        summary_text{end+1} = sprintf('    排名法: %s', influence_rank);
        summary_text{end+1} = sprintf('    百分比法: %s', influence_percent);
        summary_text{end+1} = sprintf('    裁判选择法: %s', influence_judge);
        summary_text{end+1} = '';
    end
end

text(0.1, 0.95, summary_text, 'VerticalAlignment', 'top', ...
     'FontSize', 9, 'FontName', 'Monospaced', 'Interpreter', 'none');

%% 保存图表
saveas(gcf, 'Players_FII_Analysis.png');
fprintf('\n图表已保存为: Players_FII_Analysis.png\n');

%% 输出详细报告
fprintf('\n=== 选手详细FII报告 ===\n');
fprintf('%-20s %-8s %-10s %-12s %-12s %-12s %-12s\n', ...
        '选手', '赛季', '最终排名', '平均周数', 'FII_rank', 'FII_percent', 'FII_judge');
fprintf('%-20s %-8s %-10s %-12s %-12s %-12s %-12s\n', ...
        repmat('-',1,20), '---', '-----', '-----', '---------', '------------', '------------');

for i = 1:length(valid_players)
    target_idx = valid_players(i);
    name = use_names{i};
    idx = found_indices(target_idx);
    
    if idx >= 1 && idx <= height(data)
        season = data.season(idx);
        final_rank = data.placement(idx);
        
        if ~isempty(use_week_info{i})
            avg_weeks = length(use_week_info{i});
            avg_fii_r = avg_fii_rank(i);
            avg_fii_p = avg_fii_percent(i);
            avg_fii_j = avg_fii_judge(i);
            
            fprintf('%-20s %-8d %-10d %-12d %-12.3f %-12.3f %-12.3f\n', ...
                    name, season, final_rank, avg_weeks, avg_fii_r, avg_fii_p, avg_fii_j);
        else
            fprintf('%-20s %-8d %-10d %-12s %-12s %-12s %-12s\n', ...
                    name, season, final_rank, '无数据', 'NaN', 'NaN', 'NaN');
        end
    end
end

%% 为每位选手生成个人图表
for i = 1:length(valid_players)
    target_idx = valid_players(i);
    name = use_names{i};
    weeks = use_week_info{i};
    fii_r = use_fii_rank{i};
    fii_p = use_fii_percent{i};
    fii_j = use_fii_judge{i};
    
    if isempty(weeks) || isempty(fii_r)
        fprintf('\n选手 %s 没有有效的周数据\n', name);
        continue;
    end
    
    figure('Position', [100, 100, 1000, 400], ...
           'Name', sprintf('%s - 个人FII分析', name), ...
           'NumberTitle', 'off');
    
    % 子图1：FII趋势图
    subplot(1, 2, 1);
    hold on;
    grid on;
    
    plot(weeks, fii_r, 'r-o', 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', 'r', ...
         'DisplayName', '排名法');
    plot(weeks, fii_p, 'b-s', 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', 'b', ...
         'DisplayName', '百分比法');
    plot(weeks, fii_j, 'g-^', 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', 'g', ...
         'DisplayName', '裁判选择法');
    
    line(xlim, [0.5 0.5], 'Color', 'k', 'LineStyle', '--', 'LineWidth', 1.5, 'DisplayName', '平衡线');
    
    xlabel('周数', 'FontSize', 12);
    ylabel('FII值', 'FontSize', 12);
    title(sprintf('%s: FII变化趋势', name), 'FontSize', 14, 'FontWeight', 'bold');
    legend('Location', 'best');
    ylim([0 1]);
    
    % 添加淘汰周标记
    idx = found_indices(target_idx);
if idx >= 1 && idx <= height(data)
    elim_week = data.elimination_week(idx);
    if ~isinf(elim_week) && elim_week <= max(weeks) && ~isnan(elim_week)
        line([elim_week elim_week], ylim, 'Color', 'm', 'LineStyle', '--', ...
             'LineWidth', 2, 'DisplayName', '淘汰周');
    end
end
    
    % 子图2：平均FII仪表盘
    subplot(1, 2, 2);
    
    avg_values = [mean(fii_r), mean(fii_p), mean(fii_j)];
    methods = {'排名法', '百分比法', '裁判选择法'};
    
    % 创建堆叠条形图显示影响比例
    fan_influence = 1 - avg_values;
    judge_influence = avg_values;
    
    bar_data = [fan_influence', judge_influence'];
    bar_handle = bar(1:3, bar_data, 'stacked');
    bar_handle(1).FaceColor = [0.2 0.6 0.8];  % 粉丝影响
    bar_handle(2).FaceColor = [0.8 0.2 0.2];  % 裁判影响
    
    % 添加百分比标签
    for j = 1:3
        if fan_influence(j) > 0
            text(j, fan_influence(j)/2, sprintf('粉丝: %.1f%%', 100*fan_influence(j)), ...
                 'HorizontalAlignment', 'center', 'FontSize', 10, 'FontWeight', 'bold', 'Color', 'w');
        end
        if judge_influence(j) > 0
            text(j, fan_influence(j) + judge_influence(j)/2, sprintf('裁判: %.1f%%', 100*judge_influence(j)), ...
                 'HorizontalAlignment', 'center', 'FontSize', 10, 'FontWeight', 'bold', 'Color', 'w');
        end
    end
    
    xlabel('计算方法', 'FontSize', 12);
    ylabel('影响比例', 'FontSize', 12);
    title(sprintf('%s: 影响力构成', name), 'FontSize', 14, 'FontWeight', 'bold');
    set(gca, 'XTick', 1:3, 'XTickLabel', methods);
    legend({'粉丝影响', '裁判影响'}, 'Location', 'best');
    ylim([0 1]);
    grid on;
    
    % 保存个人图表
    safe_name = strrep(name, ' ', '_');
    safe_name = strrep(safe_name, '.', '');
    safe_name = strrep(safe_name, '''', '');
    saveas(gcf, sprintf('%s_FII_Analysis.png', safe_name));
    fprintf('个人图表已保存: %s_FII_Analysis.png\n', safe_name);
end

fprintf('\n=== 分析完成 ===\n');