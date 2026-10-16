function analyze_results()
% ANALYZE_RESULTS
% Reads all .mat files from results/matlab/ and computes:
%   - Mean and 95% CI for each metric, protocol, density
%   - Kruskal-Wallis test for statistical significance
%   - Prints LaTeX-formatted tables

clc;
fprintf('==============================================\n');
fprintf('  MANET Results Analysis\n');
fprintf('==============================================\n\n');

% Configuration
protocols   = {'AODV', 'DSR', 'DSDV', 'ARF-MANET'};   % display names
fieldnames  = {'AODV', 'DSR', 'DSDV', 'ARFMANET'};    % struct-safe names
node_counts = [150, 200, 250, 300];
seeds       = 1:10;
metrics     = {'PDR', 'throughput_kbps', 'delay_ms', 'NRL', ...
               'loss', 'energy_J', 'RO', 'lifetime_s'};

% Container for all results
R = struct();

% ---- Load all .mat files ----
fprintf('Loading files...\n');

for p = 1:numel(protocols)
    fn = fieldnames{p};
    for n = 1:numel(node_counts)
        vals = struct();
        for m = 1:numel(metrics)
            vals.(metrics{m}) = [];
        end
        for s = seeds
            fname = sprintf('results/matlab/%s_N%d_s%02d.mat', ...
                            protocols{p}, node_counts(n), s);
            if ~exist(fname, 'file')
                warning('Missing file: %s', fname);
                continue;
            end
            data = load(fname, 'r');
            for m = 1:numel(metrics)
                vals.(metrics{m})(end+1) = data.r.(metrics{m}); %#ok<AGROW>
            end
        end
        R.(fn).(sprintf('N%d', node_counts(n))) = vals;
    end
end

fprintf('Loading complete.\n\n');

% ---- Compute mean and 95% CI ----
summary = struct();
for p = 1:numel(protocols)
    fn = fieldnames{p};
    for n = 1:numel(node_counts)
        key = sprintf('N%d', node_counts(n));
        for m = 1:numel(metrics)
            v = R.(fn).(key).(metrics{m});
            if isempty(v)
                summary.(fn).(key).(metrics{m}) = struct( ...
                    'mean', NaN, 'std', NaN, 'ci', NaN, 'raw', []);
            else
                mu = mean(v);
                sd = std(v);
                se = sd / sqrt(numel(v));
                ci = 1.96 * se;
                summary.(fn).(key).(metrics{m}) = struct( ...
                    'mean', mu, 'std', sd, 'ci', ci, 'raw', v);
            end
        end
    end
end

save('results/matlab/summary.mat', 'summary', 'R');
fprintf('Summary saved to results/matlab/summary.mat\n\n');

% ---- Print LaTeX tables ----
fprintf('==============================================\n');
fprintf('  LaTeX Tables\n');
fprintf('==============================================\n\n');

for m = 1:numel(metrics)
    metric = metrics{m};
    fprintf('\n%% ---- Metric: %s ----\n', metric);
    fprintf('\\begin{table}[!t]\n');
    fprintf('\\caption{%s (Mean $\\pm$ 95\\%% CI)}\n', metric);
    fprintf('\\centering\n\\small\n');
    fprintf('\\begin{tabular}{lcccc}\n');
    fprintf('\\toprule\n');
    fprintf('Nodes & AODV & DSDV & DSR & ARF-MANET \\\\\n');
    fprintf('\\midrule\n');
    for n = 1:numel(node_counts)
        fprintf('%d', node_counts(n));
        order = [1 3 2 4];   % AODV, DSDV, DSR, ARF-MANET
        for pp = order
            fn = fieldnames{pp};
            s = summary.(fn).(sprintf('N%d', node_counts(n))).(metric);
            fprintf(' & %.4f$\\pm$%.4f', s.mean, s.ci);
        end
        fprintf(' \\\\\n');
    end
    fprintf('\\bottomrule\n');
    fprintf('\\end{tabular}\n');
    fprintf('\\end{table}\n');
end

% ---- Kruskal-Wallis tests ----
fprintf('\n==============================================\n');
fprintf('  Kruskal-Wallis Tests (p-values)\n');
fprintf('==============================================\n\n');

for n = 1:numel(node_counts)
    fprintf('\n--- N = %d ---\n', node_counts(n));
    for m = 1:numel(metrics)
        metric = metrics{m};
        G = [];   % 10 x K matrix, each column is a group
        for p = 1:numel(protocols)
            fn = fieldnames{p};
            key = sprintf('N%d', node_counts(n));
            v = R.(fn).(key).(metric);
            if ~isempty(v)
                G = [G, v(:)];   %#ok<AGROW> % force column
            end
        end
        if size(G, 2) < 2, continue; end
        
        try
            [pval, ~] = kruskalwallis(G, [], 'off');
            if pval < 0.05
                fprintf('  %-16s : p = %.4g  **SIGNIFICANT**\n', metric, pval);
            else
                fprintf('  %-16s : p = %.4g  (not significant)\n', metric, pval);
            end
        catch ME
            fprintf('  %-16s : ERROR (%s)\n', metric, ME.message);
        end
    end
end