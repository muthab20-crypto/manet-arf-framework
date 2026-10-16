function generate_figures()
% GENERATE_FIGURES
% Creates 9 figures from results/matlab/summary.mat
% Saves as PNG files in figures/ directory.

clc;
fprintf('==============================================\n');
fprintf('  Generating Figures\n');
fprintf('==============================================\n\n');

% Load summary
summary_file = fullfile(pwd, 'results', 'matlab', 'summary.mat');
if ~exist(summary_file, 'file')
    error('summary.mat not found at: %s\nRun analyze_results first.', summary_file);
end
load(summary_file, 'summary');
fprintf('Loaded: %s\n', summary_file);

% Create output directory (absolute path)
out_dir = fullfile(pwd, 'figures');
if ~exist(out_dir, 'dir'), mkdir(out_dir); end
fprintf('Output directory: %s\n\n', out_dir);

% Configuration
fieldnames  = {'AODV', 'DSR', 'DSDV', 'ARFMANET'};
display_names = {'AODV', 'DSR', 'DSDV', 'ARF-MANET'};
node_counts = [150, 200, 250, 300];

colors   = {[0 0 1], [0 0.6 0], [1 0 0], [0 0 0]};
markers  = {'o', '^', 's', 'd'};
lines    = {'-', '-', '-', '--'};

% Figures specification
fig_list = {
    'PDR',            'fig1_pdr.png',         'Packet Delivery Ratio',     'PDR';
    'throughput_kbps','fig2_throughput.png',  'Average Throughput',        'Throughput (kbps)';
    'delay_ms',       'fig3_delay.png',       'End-to-End Delay',          'Delay (ms)';
    'NRL',            'fig4_nrl.png',         'Normalized Routing Load',   'NRL';
    'loss',           'fig5_loss.png',        'Packet Loss',               'Packets lost';
    'energy_J',       'fig6_energy.png',      'Energy Consumption',        'Energy (J)';
    'RO',             'fig7_ro.png',          'Routing Overhead Ratio',    'RO';
    'lifetime_s',     'fig8_lifetime.png',    'Network Lifetime',          'Lifetime (s)';
};

% Generate figures 1-8
for f = 1:size(fig_list, 1)
    metric = fig_list{f, 1};
    fname  = fig_list{f, 2};
    ttl    = fig_list{f, 3};
    ylab   = fig_list{f, 4};

    fig = figure('Position', [100 100 620 460], 'Visible', 'off');
    hold on;
    for p = 1:numel(fieldnames)
        fn = fieldnames{p};
        mu = zeros(1, 4);
        ci = zeros(1, 4);
        for n = 1:4
            s = summary.(fn).(sprintf('N%d', node_counts(n))).(metric);
            mu(n) = s.mean;
            ci(n) = s.ci;
        end
        errorbar(node_counts, mu, ci, ...
            'Color', colors{p}, 'Marker', markers{p}, ...
            'LineStyle', lines{p}, 'LineWidth', 1.5, ...
            'MarkerSize', 8, 'MarkerFaceColor', colors{p}, ...
            'CapSize', 5);
    end
    grid on; box on;
    xlabel('Number of Nodes', 'FontSize', 11);
    ylabel(ylab, 'FontSize', 11);
    title(ttl, 'FontSize', 12);
    xlim([140 310]);
    legend(display_names, 'Location', 'best', 'FontSize', 10);
    set(gca, 'FontSize', 10, 'XTick', node_counts);

    print(fig, fullfile(out_dir, fname), '-dpng', '-r300');
    close(fig);
    fprintf('Saved: %s\n', fname);
end

% ---- Figure 9: ARF-MANET composite utility ----
w = [0.20, 0.20, 0.20, 0.15, 0.25];
U = zeros(numel(fieldnames), numel(node_counts));
for p = 1:numel(fieldnames)
    fn = fieldnames{p};
    for n = 1:numel(node_counts)
        key = sprintf('N%d', node_counts(n));
        pdr  = summary.(fn).(key).PDR.mean;
        th   = summary.(fn).(key).throughput_kbps.mean;
        dly  = summary.(fn).(key).delay_ms.mean;
        nrl  = summary.(fn).(key).NRL.mean;
        life = summary.(fn).(key).lifetime_s.mean;
        U(p, n) = w(1)*pdr + w(2)*(th/700) ...
                - w(3)*(dly/600) - w(4)*(nrl/35) ...
                + w(5)*(life/900);
    end
end

fig = figure('Position', [100 100 620 460], 'Visible', 'off');
hold on;
for p = 1:numel(fieldnames)
    plot(node_counts, U(p, :), ...
        'Color', colors{p}, 'Marker', markers{p}, ...
        'LineStyle', lines{p}, 'LineWidth', 2.0, ...
        'MarkerSize', 9, 'MarkerFaceColor', colors{p});
end
grid on; box on;
xlabel('Number of Nodes', 'FontSize', 11);
ylabel('Composite Utility U', 'FontSize', 11);
title('Composite Utility: ARF-MANET vs Static Protocols', 'FontSize', 12);
xlim([140 310]);
legend(display_names, 'Location', 'best', 'FontSize', 10);
set(gca, 'FontSize', 10, 'XTick', node_counts);
print(fig, fullfile(out_dir, 'fig9_apsf.png'), '-dpng', '-r300');
close(fig);
fprintf('Saved: fig9_apsf.png\n');

% ---- Print utility table ----
fprintf('\n===== Composite Utility U =====\n');
fprintf('Nodes & AODV & DSR & DSDV & ARF-MANET \\\\\n\\midrule\n');
for n = 1:4
    fprintf('%d', node_counts(n));
    for p = 1:4
        fprintf(' & %.4f', U(p, n));
    end
    fprintf(' \\\\\n');
end

fprintf('\n==============================================\n');
fprintf('  All figures generated in figures/\n');
fprintf('==============================================\n');
end