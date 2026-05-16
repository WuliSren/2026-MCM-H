clear; clc; close all;

%% 读取数据
cd('C:\Users\LCY\Desktop\学习\课余\比赛\美赛\正式比赛\Data')
% 读取数据
data = readtable('processed_data.csv');
scores = table2array(data(:, 9:end));
seasons = data.season;
results = data.results;

% 计算实际周数（确保是整数）
numJudges = 4;
numWeeks = floor(size(scores, 2) / numJudges);

% 先统计每个赛季的实际周数
uniqueSeasons = unique(seasons);
season_actual_weeks = zeros(length(uniqueSeasons), 1);

for s_idx = 1:length(uniqueSeasons)
    s = uniqueSeasons(s_idx);
    idx = find(seasons == s);
    seasonScores = scores(idx, :);
    
    % 找出该赛季实际有数据的最大周数
    max_week_with_data = 0;
    for w = 1:numWeeks
        colStart = (w-1)*numJudges + 1;
        colEnd = colStart + numJudges - 1;
        week_scores = seasonScores(:, colStart:colEnd);
        
        % 如果这一周有任何选手有分数，说明这一周存在
        if any(~isnan(week_scores(:)))
            max_week_with_data = w;
        else
            break; % 遇到全NaN的周，说明之后都没有数据了
        end
    end
    
    season_actual_weeks(s_idx) = max_week_with_data;
end

% 创建赛季周数映射
season_weeks_map = containers.Map(uniqueSeasons, season_actual_weeks);

weeklyPercents = NaN(size(scores, 1), numWeeks);
weeklyRanks = NaN(size(scores, 1), numWeeks);

% 按season计算每周百分比和排名
for s_idx = 1:length(uniqueSeasons)
    s = uniqueSeasons(s_idx);
    actual_weeks = season_actual_weeks(s_idx);
    idx = find(seasons == s);
    seasonScores = scores(idx, :);
    
    for w = 1:actual_weeks
        colStart = (w-1)*numJudges + 1;
        colEnd = colStart + numJudges - 1;
        
        % 每周选手总分
        weeklyTotals = nansum(seasonScores(:, colStart:colEnd), 2);
        weekTotal = nansum(weeklyTotals);
        
        % 计算百分比
        if weekTotal > 0
            percents = (weeklyTotals / weekTotal) * 100;
            weeklyPercents(idx, w) = percents;
        end
        
        % 计算排名（总分越高排名越前，从1开始）
        [~, sortedIdx] = sort(weeklyTotals, 'descend');
        ranks = zeros(length(weeklyTotals), 1);
        ranks(sortedIdx) = 1:length(weeklyTotals);
        weeklyRanks(idx, w) = ranks;
    end
end

% 添加百分比列和排名列
for w = 1:numWeeks
    data.(sprintf('week%d_pct', w)) = weeklyPercents(:, w);
    data.(sprintf('week%d_rank', w)) = weeklyRanks(:, w);
end

% 保存中间结果
writetable(data, 'weekly_percentages_ranks.csv');
fprintf('计算完成，共%d周数据，添加了百分比和排名\n', numWeeks);

% 显示每个赛季的实际周数
fprintf('\n各赛季实际周数统计：\n');
for s_idx = 1:length(uniqueSeasons)
    fprintf('赛季%d：实际周数 = %d\n', uniqueSeasons(s_idx), season_actual_weeks(s_idx));
end

%% 根据results列计算淘汰周数
% 初始化淘汰周数列
elimination_week = NaN(height(data), 1);
is_withdrew = false(height(data), 1);

for i = 1:height(data)
    result_str = results{i};
    season_idx = data.season(i);
    
    % 处理各种结果情况
    if contains(result_str, 'Eliminated Week')
        % 提取淘汰周数
        tokens = regexp(result_str, 'Eliminated Week (\d+)', 'tokens');
        if ~isempty(tokens)
            elimination_week(i) = str2double(tokens{1}{1});
        end
    elseif contains(result_str, 'Withdrew')
        % 标记为withdrew选手
        is_withdrew(i) = true;
        % 中途退出，找到最后一个有分数的周
        scores_row = scores(i, :);
        last_week = 0;
        actual_weeks = season_actual_weeks(uniqueSeasons == season_idx);
        for w = 1:actual_weeks
            colStart = (w-1)*numJudges + 1;
            colEnd = colStart + numJudges - 1;
            if any(~isnan(scores_row(colStart:colEnd)))
                last_week = w;
            else
                break;
            end
        end
        % Withdrew选手的淘汰周数设为last_week（他们最后参与的周数）
        elimination_week(i) = last_week;
        
    elseif contains(result_str, 'Place')
        % 决赛选手：1st Place, 2nd Place, 3rd Place等
        season_data = data(data.season == season_idx, :);
        season_results = season_data.results;
        actual_weeks = season_actual_weeks(uniqueSeasons == season_idx);
        
        % 找到该赛季所有被淘汰的选手
        eliminated_weeks = [];
        for j = 1:height(season_data)
            result_j = season_results{j};
            if contains(result_j, 'Eliminated Week')
                tokens = regexp(result_j, 'Eliminated Week (\d+)', 'tokens');
                if ~isempty(tokens)
                    eliminated_weeks = [eliminated_weeks, str2double(tokens{1}{1})];
                end
            end
        end
        
        if ~isempty(eliminated_weeks)
            max_elim_week = max(eliminated_weeks);
            
            % 找到该赛季最大的名次数字
            max_place_num = 0;
            for j = 1:height(season_data)
                result_j = season_results{j};
                if contains(result_j, 'Place')
                    tokens = regexp(result_j, '(\d+).*Place', 'tokens');
                    if ~isempty(tokens)
                        place_num = str2double(tokens{1}{1});
                        if place_num > max_place_num
                            max_place_num = place_num;
                        end
                    end
                end
            end
            
            % 根据名次确定淘汰周数
            if contains(result_str, '1st Place')
                % 冠军：不会被淘汰
                elimination_week(i) = Inf;
            else
                % 提取当前选手的名次数字
                tokens = regexp(result_str, '(\d+).*Place', 'tokens');
                if ~isempty(tokens)
                    place_num = str2double(tokens{1}{1});
                    % 淘汰周数 = 最大淘汰周数 + (最大名次 - 当前名次)
                    % 但需要确保不超过实际周数
                    calculated_week = max_elim_week + (max_place_num - place_num);
                    if calculated_week <= actual_weeks
                        elimination_week(i) = calculated_week;
                    else
                        elimination_week(i) = actual_weeks; % 如果超过实际周数，设为最后一周
                    end
                end
            end
        end
    end
end

% 添加淘汰周数列
data.elimination_week = elimination_week;
data.is_withdrew = is_withdrew;

%% 初始化最终投票百分比列（合并所有规则结果）
all_season_votes_combined = NaN(height(data), 1);

%% ============================================================
%% 对第1-2季：使用贝叶斯方法（来自Untitled.m）
%% 规则1（评委排名+粉丝排名之和最低者存活，最高者淘汰）
%% ============================================================
fprintf('\n=== 第1-2季使用贝叶斯方法 ===\n');

% 定义贝叶斯模型参数
num_particles = 5000;  % 粒子数（近似后验分布）
rng(42);  % 设置随机种子

for season_num = 1:2
    idx = find(seasons == season_num);
    if isempty(idx)
        continue; % 跳过不存在的赛季
    end
    
    n = length(idx);  % 该赛季选手人数
    actual_weeks = season_actual_weeks(uniqueSeasons == season_num);
    
    fprintf('\n=== 贝叶斯推断：赛季%d (规则1，实际周数：%d，选手数：%d) ===\n', season_num, actual_weeks, n);
    
    % 提取该赛季数据
    elim_weeks = elimination_week(idx);
    is_withdrew_season = is_withdrew(idx);
    
    % 狄利克雷先验参数（对称先验，倾向于均匀分布）
    alpha_prior = ones(n, 1) * 1;  % 较小的值表示弱先验
    
    % 初始化粒子（每个粒子是一个可能的投票分布）
    particles = zeros(n, num_particles);
    for p = 1:num_particles
        % 从狄利克雷分布采样
        particles(:, p) = gamrnd(alpha_prior, 1);
        particles(:, p) = particles(:, p) / sum(particles(:, p)) * 100;
    end
    
    % 为每个粒子计算权重
    weights = ones(1, num_particles) / num_particles;
    
    % 迭代更新（重要性重采样）
    for w = 1:actual_weeks
        % 获取该周的评委评分排名
        week_ranks = weeklyRanks(idx, w);
        
        % 找出该周应被淘汰的选手
        eliminated_idx = find(elim_weeks == w & ~is_withdrew_season);
        
        if isempty(eliminated_idx)
            continue;
        end
        
        % 找出仍在比赛中的选手
        still_in_competition = [];
        for k = 1:n
            if is_withdrew_season(k)
                if elim_weeks(k) >= w
                    still_in_competition = [still_in_competition, k];
                end
            else
                if elim_weeks(k) > w
                    still_in_competition = [still_in_competition, k];
                end
            end
        end
        
        % 为每个粒子计算权重（基于规则1的似然）
        new_weights = weights;
        for p = 1:num_particles
            theta = particles(:, p);  % 固定人气参数
            
            % === 修正：根据当周仍在场的选手重归一化 ===
            if ~isempty(still_in_competition)
                total_theta_week = sum(theta(still_in_competition));
                if total_theta_week > 0
                    fan_pct_week = theta(still_in_competition) / total_theta_week * 100;
                    % 构建完整的百分比向量（淘汰选手为0）
                    fan_pct_full = zeros(n, 1);
                    fan_pct_full(still_in_competition) = fan_pct_week;
                else
                    fan_pct_full = zeros(n, 1);
                end
            else
                fan_pct_full = theta;  % 无人淘汰，保持原样
            end
            % ============================================
            
            % 根据当前投票百分比计算投票排名
            [~, vote_sort_idx] = sort(fan_pct_full, 'descend');
            vote_ranks = zeros(n, 1);
            vote_ranks(vote_sort_idx) = 1:n;
            
            % 计算总分排名
            total_ranks = week_ranks + vote_ranks;
            
            % 计算规则1的似然
            likelihood = 1;
            for j = 1:length(eliminated_idx)
                elim_j = eliminated_idx(j);
                
                if ~isempty(still_in_competition)
                    % 被淘汰选手的总分排名应比所有仍在比赛中的选手都差
                    % 使用软约束（高斯似然）
                    max_still_rank = max(total_ranks(still_in_competition));
                    
                    % 如果被淘汰选手排名更好，给予低似然
                    if total_ranks(elim_j) < max_still_rank
                        % 惩罚：排名差越大，惩罚越小
                        rank_diff = max_still_rank - total_ranks(elim_j);
                        likelihood = likelihood * exp(-rank_diff^2 / (2 * 10^2));
                    else
                        likelihood = likelihood * 1;  % 无惩罚
                    end
                end
            end
            
            new_weights(p) = weights(p) * likelihood;
        end
        
        % 归一化权重
        if sum(new_weights) > 0
            weights = new_weights / sum(new_weights);
        else
            % 防止权重为0
            weights = ones(1, num_particles) / num_particles;
        end
        
        % 重采样（如果有效样本数太小）
        effective_sample_size = 1 / sum(weights.^2);
        if effective_sample_size < num_particles / 2
            % 系统重采样
            cumulative_weights = cumsum(weights);
            new_particles = zeros(n, num_particles);
            
            r = rand() / num_particles;
            i = 1;
            for p = 1:num_particles
                u = r + (p-1) / num_particles;
                while u > cumulative_weights(i) && i < num_particles
                    i = i + 1;
                end
                new_particles(:, p) = particles(:, i);
            end
            
            particles = new_particles;
            weights = ones(1, num_particles) / num_particles;
        end
        
        % 随机扰动（防止粒子退化）
        for p = 1:num_particles
            if rand() < 0.1  % 10%的概率扰动
                perturbation = randn(n, 1) * 0.01;
                particles(:, p) = max(particles(:, p) + perturbation, 0);
                particles(:, p) = particles(:, p) / sum(particles(:, p)) * 100;
            end
        end
    end
    
    % 计算后验期望（加权平均）
    posterior_votes = zeros(n, 1);
    for p = 1:num_particles
        posterior_votes = posterior_votes + particles(:, p) * weights(p);
    end
    
    % 归一化
    posterior_votes = posterior_votes / sum(posterior_votes) * 100;
    
    % 保存结果
    all_season_votes_combined(idx) = posterior_votes;
    
    % 显示统计信息
    fprintf('  投票百分比统计：\n');
    fprintf('    总和：%.6f%%，最小值：%.2f%%，最大值：%.2f%%，平均值：%.2f%%，标准差：%.2f\n', ...
        sum(posterior_votes), min(posterior_votes), max(posterior_votes), ...
        mean(posterior_votes), std(posterior_votes));
end

%% ============================================================
%% 对第3-27季：使用启发式迭代方法（来自Fans_Scores.m）
%% 规则2（评分百分比+投票百分比之和最低被淘汰）
%% ============================================================
fprintf('\n=== 第3-27季使用启发式迭代方法 ===\n');

for season_num = 3:27
    idx = find(seasons == season_num);
    if isempty(idx)
        continue; % 跳过不存在的赛季
    end
    
    n = length(idx);  % 该赛季选手人数
    actual_weeks = season_actual_weeks(uniqueSeasons == season_num);
    
    fprintf('\n=== 开始计算赛季%d (规则2，实际周数：%d，选手数：%d) ===\n', season_num, actual_weeks, n);
    
    % 提取该赛季数据
    elim_weeks = elimination_week(idx);
    is_withdrew_season = is_withdrew(idx);
    theta = ones(n, 1);  % 初始化固定人气参数为均等分配
    theta = theta / sum(theta) * 100;  % 归一化为百分比
    
    % 检查每周条件并调整人气参数
    max_iter = 1000;
    converged = false;
    
    for iter = 1:max_iter
        violation_found = false;
        
        % 每周淘汰一人，但只到实际周数
        for w = 1:actual_weeks
            % 获取该周的评分百分比
            week_pct = weeklyPercents(idx, w);
            
            % 找出仍在比赛中的选手：
            % 1. 未被淘汰的选手（淘汰周数 > w）
            % 2. Withdrew选手如果还在比赛中（elim_weeks >= w）
            still_in_competition = [];
            for k = 1:n
                if is_withdrew_season(k)
                    % Withdrew选手：只要还有得分就视为在比赛中
                    if elim_weeks(k) >= w
                        still_in_competition = [still_in_competition, k];
                    end
                else
                    % 普通选手：淘汰周数 > w 表示仍在比赛中
                    if elim_weeks(k) > w
                        still_in_competition = [still_in_competition, k];
                    end
                end
            end
            
            % === 修正：计算当周的粉丝百分比 ===
            if ~isempty(still_in_competition)
                total_theta_week = sum(theta(still_in_competition));
                if total_theta_week > 0
                    fan_pct_week = theta(still_in_competition) / total_theta_week * 100;
                    % 构建完整的百分比向量
                    fan_pct_full = zeros(n, 1);
                    fan_pct_full(still_in_competition) = fan_pct_week;
                else
                    fan_pct_full = zeros(n, 1);
                end
            else
                fan_pct_full = theta;  % 无人淘汰，保持原样
            end
            % ============================================
            
            % 计算总分 = 评分百分比 + 粉丝百分比（当周重归一化后的）
            total_score = week_pct + fan_pct_full;
            
            % 找出该周应被淘汰的选手（淘汰周数等于w的选手，且不是withdrew）
            eliminated_idx = find(elim_weeks == w & ~is_withdrew_season);
            
            if isempty(eliminated_idx)
                % 如果没有人在第w周被淘汰（可能是withdrew或决赛周）
                continue;
            end
            
            if ~isempty(still_in_competition)
                % 规则2：被淘汰选手的总分应该小于所有仍在比赛中的选手
                
                % 找出所有仍在比赛中的选手的最小总分
                min_still_score = min(total_score(still_in_competition));
                
                % 检查每个被淘汰的选手
                for j = 1:length(eliminated_idx)
                    elim_j = eliminated_idx(j);
                    
                    if total_score(elim_j) > min_still_score
                        violation_found = true;
                        adjustment = 0.01;
                        
                        % 减少被淘汰选手的人气参数
                        theta(elim_j) = theta(elim_j) * (1 - adjustment);
                        
                        % 计算需要重新分配的人气参数总量
                        redistributed_votes = theta(elim_j) * adjustment;
                        
                        if redistributed_votes > 0 && ~isempty(still_in_competition)
                            % 将减少的人气参数平均分配给仍在比赛中的选手
                            share_per_still = redistributed_votes / length(still_in_competition);
                            for k = 1:length(still_in_competition)
                                still_k = still_in_competition(k);
                                theta(still_k) = theta(still_k) + share_per_still;
                            end
                        end
                        break;
                    end
                end
            end
            
            if violation_found, break; end
        end
        
        % 归一化保持总和为100
        theta = theta / sum(theta) * 100;
        
        % 检查是否收敛
        if ~violation_found
            fprintf('  第%d次迭代后找到解\n', iter);
            converged = true;
            break;
        end
    end
    
    if ~converged
        fprintf('  达到最大迭代次数%d，可能未完全收敛\n', max_iter);
    end
    
    % 检查人气参数总和并强制归一化
    theta_sum = sum(theta);
    if abs(theta_sum - 100) > 0.01
        theta = theta / theta_sum * 100;
    end
    
    % 保存到合并结果列（这是固定的人气参数）
    all_season_votes_combined(idx) = theta;
    
    % 显示该赛季人气参数结果摘要
    fprintf('  人气参数统计：\n');
    fprintf('    总和：%.6f%%，最小值：%.2f%%，最大值：%.2f%%，平均值：%.2f%%，标准差：%.2f\n', ...
        sum(theta), min(theta), max(theta), mean(theta), std(theta));
end

%% ============================================================
%% 对第28-34季：使用贝叶斯方法（来自Untitled.m）
%% 规则3（排名和最低的两人中，淘汰评委评分更低的）
%% ============================================================
fprintf('\n=== 第28-34季使用贝叶斯方法 ===\n');

for season_num = 28:34
    idx = find(seasons == season_num);
    if isempty(idx)
        continue; % 跳过不存在的赛季
    end
    
    n = length(idx);  % 该赛季选手人数
    actual_weeks = season_actual_weeks(uniqueSeasons == season_num);
    
    fprintf('\n=== 贝叶斯推断：赛季%d (规则3，实际周数：%d，选手数：%d) ===\n', season_num, actual_weeks, n);
    
    % 提取该赛季数据
    elim_weeks = elimination_week(idx);
    is_withdrew_season = is_withdrew(idx);
    
    % 初始化粒子
    particles = zeros(n, num_particles);
    weights = ones(1, num_particles) / num_particles;
    
    for p = 1:num_particles
        % 从狄利克雷分布采样
        particles(:, p) = gamrnd(ones(n, 1), 1);
        particles(:, p) = particles(:, p) / sum(particles(:, p)) * 100;
    end
    
    % 逐周更新
    for w = 1:actual_weeks
        % 获取该周数据
        week_ranks = weeklyRanks(idx, w);
        colStart = (w-1)*numJudges + 1;
        colEnd = colStart + numJudges - 1;
        week_scores = nansum(scores(idx, colStart:colEnd), 2);
        
        % 找出该周应被淘汰的选手
        eliminated_idx = find(elim_weeks == w & ~is_withdrew_season);
        
        % 找出仍在比赛中的选手
        still_in_competition = [];
        for k = 1:n
            if is_withdrew_season(k)
                if elim_weeks(k) >= w
                    still_in_competition = [still_in_competition, k];
                end
            else
                if elim_weeks(k) > w
                    still_in_competition = [still_in_competition, k];
                end
            end
        end
        
        % 更新粒子权重
        for p = 1:num_particles
            theta = particles(:, p);
            
            % === 修正：根据当周仍在场的选手重归一化 ===
            if ~isempty(still_in_competition)
                total_theta_week = sum(theta(still_in_competition));
                if total_theta_week > 0
                    fan_pct_week = theta(still_in_competition) / total_theta_week * 100;
                    % 构建完整的百分比向量（淘汰选手为0）
                    fan_pct_full = zeros(n, 1);
                    fan_pct_full(still_in_competition) = fan_pct_week;
                else
                    fan_pct_full = zeros(n, 1);
                end
            else
                fan_pct_full = theta;  % 无人淘汰，保持原样
            end
            % ============================================
            
            % 计算投票排名（使用重归一化后的百分比）
            [~, vote_sort_idx] = sort(fan_pct_full, 'descend');
            vote_ranks = zeros(n, 1);
            vote_ranks(vote_sort_idx) = 1:n;
            
            % 计算总分排名
            total_ranks = week_ranks + vote_ranks;
            
            % 找出总分排名最高的两名
            [~, sorted_idx] = sort(total_ranks, 'descend');
            bottom_two_idx = sorted_idx(1:min(2, n));
            
            % 在这两名中找出评委评分最低的
            [~, min_score_idx] = min(week_scores(bottom_two_idx));
            expected_elim_idx = bottom_two_idx(min_score_idx);
            
            % 计算似然
            if ~isempty(eliminated_idx)
                % 检查实际淘汰的选手是否在底部两名中
                actual_elim = eliminated_idx(1);  % 假设每周只淘汰一人
                
                if ismember(actual_elim, bottom_two_idx)
                    % 检查是否是正确的选手（评委评分最低）
                    if actual_elim == expected_elim_idx
                        likelihood = 1.0;  % 完全符合规则
                    else
                        % 在底部两名中但不是评分最低的
                        score_diff = abs(week_scores(actual_elim) - week_scores(expected_elim_idx));
                        likelihood = exp(-score_diff^2 / (2 * 100^2));  % 软约束
                    end
                else
                    % 不在底部两名中，给予惩罚
                    likelihood = 0.1;
                end
            else
                likelihood = 1.0;  % 无人被淘汰
            end
            
            weights(p) = weights(p) * likelihood;
        end
        
        % 归一化权重
        if sum(weights) > 0
            weights = weights / sum(weights);
        else
            weights = ones(1, num_particles) / num_particles;
        end
        
        % 重采样
        effective_sample_size = 1 / sum(weights.^2);
        if effective_sample_size < num_particles / 3
            cumulative_weights = cumsum(weights);
            new_particles = zeros(n, num_particles);
            
            r = rand() / num_particles;
            i = 1;
            for p = 1:num_particles
                u = r + (p-1) / num_particles;
                while u > cumulative_weights(i) && i < num_particles
                    i = i + 1;
                end
                new_particles(:, p) = particles(:, i);
            end
            
            particles = new_particles;
            weights = ones(1, num_particles) / num_particles;
        end
        
        % 随机扰动
        for p = 1:num_particles
            if rand() < 0.15
                perturbation = randn(n, 1) * 0.02;
                particles(:, p) = max(particles(:, p) + perturbation, 0.01);
                particles(:, p) = particles(:, p) / sum(particles(:, p)) * 100;
            end
        end
    end
    
    % 计算后验期望
    posterior_votes = zeros(n, 1);
    for p = 1:num_particles
        posterior_votes = posterior_votes + particles(:, p) * weights(p);
    end
    
    % 归一化
    posterior_votes = posterior_votes / sum(posterior_votes) * 100;
    
    % 保存结果
    all_season_votes_combined(idx) = posterior_votes;
    
    % 显示统计信息
    fprintf('  投票百分比统计：\n');
    fprintf('    总和：%.6f%%，最小值：%.2f%%，最大值：%.2f%%，平均值：%.2f%%，标准差：%.2f\n', ...
        sum(posterior_votes), min(posterior_votes), max(posterior_votes), ...
        mean(posterior_votes), std(posterior_votes));
end

%% 将合并的投票百分比添加到表格
data.fan_vote_pct_combined = all_season_votes_combined;

% 添加方法标识列
method_identifier = cell(height(data), 1);
for i = 1:height(data)
    season_num = data.season(i);
    if season_num >= 1 && season_num <= 2
        method_identifier{i} = 'Bayesian-Rule1';
    elseif season_num >= 3 && season_num <= 27
        method_identifier{i} = 'Heuristic-Rule2';
    elseif season_num >= 28 && season_num <= 34
        method_identifier{i} = 'Bayesian-Rule3';
    else
        method_identifier{i} = 'Unknown';
    end
end
data.prediction_method = method_identifier;

% 保存更新后的表格
output_filename = 'weekly_percentages_ranks_with_votes_combined_fixed.csv';
writetable(data, output_filename);
fprintf('\n混合方法结果已保存到 %s\n', output_filename);

%% 显示方法应用总结
fprintf('\n=== 混合方法应用总结 ===\n');
fprintf('赛季1-2：贝叶斯方法 + 规则1（评委排名 + 粉丝排名之和最低被淘汰）\n');
fprintf('赛季3-27：启发式迭代方法 + 规则2（评分百分比 + 投票百分比之和最低被淘汰）\n');
fprintf('赛季28-34：贝叶斯方法 + 规则3（排名和最低的两人中，评委评分更低的被淘汰）\n');
fprintf('已修正硬伤2：每周根据仍在场选手对粉丝支持率进行重归一化\n');
fprintf('所有结果已合并到 fan_vote_pct_combined 列，方法标识在 prediction_method 列\n');

%% 显示各赛季投票统计
fprintf('\n=== 各赛季粉丝支持率统计（固定人气参数θ_i） ===\n');
fprintf('赛季\t选手数\t方法\t\t支持率最小值\t支持率最大值\t支持率平均值\t支持率标准差\n');
fprintf('----\t------\t--------\t------------\t------------\t------------\t------------\n');

for season_num = 1:34
    idx = find(seasons == season_num);
    if ~isempty(idx)
        votes = all_season_votes_combined(idx);
        valid_votes = votes(~isnan(votes));
        if ~isempty(valid_votes)
            % 确定方法标识
            if season_num <= 2
                method = 'Bayesian1';
            elseif season_num <= 27
                method = 'Heuristic2';
            else
                method = 'Bayesian3';
            end
            
            fprintf('%2d\t%6d\t%-10s\t%12.2f\t%12.2f\t%12.2f\t%12.2f\n', ...
                season_num, length(valid_votes), method, ...
                min(valid_votes), max(valid_votes), ...
                mean(valid_votes), std(valid_votes));
        end
    end
end

%% 生成可视化（可选）
fprintf('\n=== 生成可视化分析 ===\n');

% 选择几个代表性的赛季进行可视化
example_seasons = [1, 10, 30];  % 分别代表三种方法

for season_num = example_seasons
    idx = find(seasons == season_num);
    if ~isempty(idx)
        votes = all_season_votes_combined(idx);
        
        figure('Position', [100, 100, 1200, 500]);
        
        % 子图1：投票分布
        subplot(1, 2, 1);
        bar(votes);
        xlabel('选手编号');
        ylabel('粉丝支持率 θ_i (%)');
        
        % 根据赛季确定标题
        if season_num <= 2
            method_name = '贝叶斯方法 (规则1)';
        elseif season_num <= 27
            method_name = '启发式方法 (规则2)';
        else
            method_name = '贝叶斯方法 (规则3)';
        end
        title(sprintf('赛季%d - %s - 固定人气参数', season_num, method_name));
        grid on;
        
        % 子图2：投票vs评委评分百分比（第一周）
        subplot(1, 2, 2);
        week_pct = weeklyPercents(idx, 1);
        scatter(week_pct, votes, 50, 'filled');
        xlabel('第一周评委评分百分比 (%)');
        ylabel('固定人气参数 θ_i (%)');
        title('人气参数vs评委评分（第一周）');
        grid on;
        
        % 添加选手编号标签
        for i = 1:length(idx)
            text(week_pct(i), votes(i), sprintf('%d', i), ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 8);
        end
        
        % 添加相关系数
        valid_idx = ~isnan(week_pct) & ~isnan(votes);
        if sum(valid_idx) > 1
            correlation = corr(week_pct(valid_idx), votes(valid_idx));
            text(0.05, 0.95, sprintf('相关系数: %.3f', correlation), ...
                'Units', 'normalized', 'FontSize', 10, 'FontWeight', 'bold');
        end
        
        % 保存图像
        saveas(gcf, sprintf('season_%d_hybrid_analysis_fixed.png', season_num));
        fprintf('  已保存赛季%d的修正后分析图像\n', season_num);
    end
end

fprintf('\n修正后的混合方法计算完成！\n');
fprintf('结果文件：%s\n', output_filename);
fprintf('已修正：每周根据仍在场选手对粉丝支持率进行重归一化\n');

