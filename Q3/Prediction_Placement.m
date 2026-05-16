%% 与星共舞参赛者特征对排名影响分析 - 随机森林模型（所有样本训练）
clear; clc; close all;
cd('C:\Users\LCY\Desktop\学习\课余\比赛\美赛\正式比赛\Data')

%% 1. 读取数据
filename = 'weekly_percentages_ranks_with_votes_combined.csv';
opts = detectImportOptions(filename);

% 指定需要的变量
opts.SelectedVariableNames = {
    'x__elebrity_name', 
    'ballroom_partner',
    'celebrity_industry',
    'celebrity_homestate', 
    'celebrity_homecountry_region',
    'celebrity_age_during_season',
    'season',
    'placement',
    'fan_vote_pct_combined'
};

% 读取数据
data = readtable(filename, opts);

%% 2. 数据预处理
% 所有列NaN/Inf用0填充
for i = 1:width(data)
    if isnumeric(data.(i))
        data{isnan(data{:,i}) | isinf(data{:,i}), i} = 0;
    end
end

seasons = unique(data.season);
fprintf('赛季数: %d\n', length(seasons));

% 目标变量
target = data.placement;

% 定义特征列名（就是要评估的7个特征）
feature_columns = {
    'ballroom_partner',
    'celebrity_industry', 
    'celebrity_homestate',
    'celebrity_homecountry_region',
    'celebrity_age_during_season',
    'season',
    'fan_vote_pct_combined'
};

feature_names = feature_columns;

%% 3. 创建特征矩阵 - 对分类特征进行独热编码
fprintf('\n===== 创建特征矩阵 =====\n');

% 存储所有特征数据
feature_matrix = [];

% 对每个特征列进行处理
for f_idx = 1:length(feature_columns)
    col_name = feature_columns{f_idx};
    col_data = data.(col_name);
    
    fprintf('处理特征: %s\n', col_name);
    
    if isnumeric(col_data)
        % 数值特征：直接使用
        if isempty(feature_matrix)
            feature_matrix = col_data;
        else
            feature_matrix = [feature_matrix, col_data];
        end
        fprintf('  -> 数值特征，直接添加\n');
        
    else
        % 分类特征：独热编码
        categories = unique(col_data);
        fprintf('  -> 分类特征，有 %d 个类别\n', length(categories));
        
        for cat_idx = 1:length(categories)
            current_category = categories{cat_idx};
            if ~isempty(current_category) && ~strcmp(current_category, 'NaN')
                % 创建虚拟变量
                dummy_var = double(strcmp(col_data, current_category));
                
                % 添加到特征矩阵
                if isempty(feature_matrix)
                    feature_matrix = dummy_var;
                else
                    feature_matrix = [feature_matrix, dummy_var];
                end
            end
        end
    end
end

fprintf('\n特征矩阵创建完成\n');
fprintf('总特征数: %d\n', size(feature_matrix, 2));
fprintf('样本数: %d\n', size(feature_matrix, 1));

%% 4. 划分训练集和测试集（80%-20%）
rng(42); % 设置随机种子以确保可重复性
n_samples = size(feature_matrix, 1);
indices = randperm(n_samples);

train_size = floor(0.8 * n_samples);
train_indices = indices(1:train_size);
test_indices = indices(train_size+1:end);

X_train = feature_matrix(train_indices, :);
y_train = target(train_indices);
X_test = feature_matrix(test_indices, :);
y_test = target(test_indices);

fprintf('\n===== 数据划分 =====\n');
fprintf('总样本数：%d\n', n_samples);
fprintf('训练集大小：%d (%.1f%%)\n', train_size, 100*train_size/n_samples);
fprintf('测试集大小：%d (%.1f%%)\n', n_samples-train_size, 100*(n_samples-train_size)/n_samples);

%% 5. 训练随机森林模型
num_trees = 100;
min_leaf_size = 4;

fprintf('\n===== 训练随机森林回归模型 =====\n');
fprintf('树的数量：%d\n', num_trees);
fprintf('最小叶节点大小：%d\n', min_leaf_size);

tic;
rf_model = TreeBagger(num_trees, X_train, y_train, ...
                     'Method', 'regression', ...
                     'OOBPrediction', 'On', ...
                     'OOBPredictorImportance', 'On', ...
                     'MinLeafSize', min_leaf_size);
training_time = toc;

fprintf('模型训练完成，耗时：%.2f秒\n', training_time);

%% 6. 模型预测
fprintf('\n===== 模型预测 =====\n');

% 在测试集上进行预测
y_pred_raw = predict(rf_model, X_test);

% 转换为数值向量
if iscell(y_pred_raw)
    y_pred = zeros(size(y_pred_raw));
    for i = 1:length(y_pred_raw)
        y_pred(i) = str2double(y_pred_raw{i});
    end
elseif ischar(y_pred_raw)
    y_pred = str2num(y_pred_raw);
else
    y_pred = double(y_pred_raw);
end

y_pred = y_pred(:);
y_pred(isnan(y_pred) | isinf(y_pred)) = 0;

%% 7. 模型评估
fprintf('\n===== 模型评估 =====\n');

% 计算回归评估指标
mae = mean(abs(y_test - y_pred));
rmse = sqrt(mean((y_test - y_pred).^2));
r_squared = 1 - sum((y_test - y_pred).^2) / sum((y_test - mean(y_test)).^2);

fprintf('平均绝对误差 (MAE): %.4f\n', mae);
fprintf('均方根误差 (RMSE): %.4f\n', rmse);
fprintf('R平方 (R?): %.4f\n', r_squared);

% 可视化预测 vs 实际值
figure('Position', [100, 100, 800, 600]);
scatter(y_test, y_pred, 50, 'filled', 'MarkerFaceAlpha', 0.6);
hold on;
plot([min(y_test) max(y_test)], [min(y_test) max(y_test)], 'r--', 'LineWidth', 2);
xlabel('实际排名');
ylabel('预测排名');
title('预测排名 vs 实际排名（测试集）');
grid on;
legend('数据点', '理想线 (y=x)', 'Location', 'best');

%% 8. 特征重要性分析 - 计算每个原始特征的重要性
fprintf('\n===== 特征重要性分析 =====\n');

% 获取所有特征的重要性值
all_feature_importance = rf_model.OOBPermutedVarDeltaError;

% 计算每个原始特征的重要性（对独热编码后的特征进行分组平均）
original_feature_importance = zeros(length(feature_names), 1);

% 跟踪当前在all_feature_importance中的位置
current_idx = 1;

for f_idx = 1:length(feature_names)
    col_name = feature_names{f_idx};
    col_data = data.(col_name);
    
    if isnumeric(col_data)
        % 数值特征：直接取对应的重要性值
        if current_idx <= length(all_feature_importance)
            original_feature_importance(f_idx) = all_feature_importance(current_idx);
            current_idx = current_idx + 1;
        end
        
    else
        % 分类特征：计算该特征所有独热编码特征的平均重要性
        categories = unique(col_data);
        n_valid_categories = 0;
        
        for cat_idx = 1:length(categories)
            current_category = categories{cat_idx};
            if ~isempty(current_category) && ~strcmp(current_category, 'NaN')
                n_valid_categories = n_valid_categories + 1;
            end
        end
        
        if current_idx + n_valid_categories - 1 <= length(all_feature_importance)
            % 计算该特征所有独热编码特征的平均重要性
            original_feature_importance(f_idx) = mean(all_feature_importance(current_idx:current_idx+n_valid_categories-1));
            current_idx = current_idx + n_valid_categories;
        end
    end
end

% 创建特征重要性表格
importance_table = table(feature_names(:), original_feature_importance(:), ...
    'VariableNames', {'Feature', 'Importance'});

% 按重要性排序
importance_table = sortrows(importance_table, 'Importance', 'descend');

fprintf('\n特征重要性排名:\n');
for i = 1:height(importance_table)
    fprintf('%d. %s: %.4f\n', i, importance_table.Feature{i}, ...
            importance_table.Importance(i));
end

% 可视化特征重要性
figure('Position', [100, 100, 800, 600]);
bar(importance_table.Importance);
set(gca, 'XTick', 1:height(importance_table));
set(gca, 'XTickLabel', importance_table.Feature);
xtickangle(45);
ylabel('特征重要性（OOB误差增加量）');
title('7个原始特征的重要性排名');
grid on;

%% 9. 保存结果
fprintf('\n===== 保存结果 =====\n');

% 保存模型
save('dwts_random_forest_model.mat', 'rf_model', 'feature_names', ...
     'feature_matrix', 'target', 'train_indices', 'test_indices');

% 对所有样本进行预测
all_pred_raw = predict(rf_model, feature_matrix);

% 转换为数值
if iscell(all_pred_raw)
    all_pred = zeros(size(all_pred_raw));
    for i = 1:length(all_pred_raw)
        all_pred(i) = str2double(all_pred_raw{i});
    end
elseif ischar(all_pred_raw)
    all_pred = str2num(all_pred_raw);
else
    all_pred = double(all_pred_raw);
end

all_pred = all_pred(:);
all_pred(isnan(all_pred) | isinf(all_pred)) = 0;

% 确保长度一致
n_rows = height(data);
if length(all_pred) ~= n_rows
    fprintf('预测结果长度(%d)与数据行数(%d)不匹配，截断\n', length(all_pred), n_rows);
    min_len = min(length(all_pred), n_rows);
    all_pred = all_pred(1:min_len);
    data = data(1:min_len, :);
    target = target(1:min_len);
end

% 保存预测结果
final_results = table(data.x__elebrity_name, data.season, target, all_pred, ...
                     'VariableNames', {'Celebrity', 'Season', 'Actual_Rank', 'Predicted_Rank'});

writetable(final_results, 'dwts_rank_predictions.csv');
fprintf('完整预测结果已保存到: dwts_rank_predictions.csv\n');

% 保存特征重要性
writetable(importance_table, 'feature_importance.csv');
fprintf('特征重要性已保存到: feature_importance.csv\n');

% 保存模型性能
performance_table = table(mae, rmse, r_squared, ...
    'VariableNames', {'MAE', 'RMSE', 'R2'});
writetable(performance_table, 'model_performance.csv');
fprintf('模型性能已保存到: model_performance.csv\n');

fprintf('\n分析完成！\n');