function run_all_experiments()
% RUN_ALL_EXPERIMENTS
% Runs the complete simulation campaign:
%   4 protocols x 4 densities x 10 seeds = 160 runs
% Saves results to results/matlab/*.mat
%
% Usage:  run_all_experiments
% Estimated time: ~15 minutes.

clc;
fprintf('==============================================\n');
fprintf('  MANET Simulation Campaign\n');
fprintf('  4 protocols x 4 densities x 10 seeds\n');
fprintf('  Total: 160 runs\n');
fprintf('==============================================\n\n');

% Create output directory
out_dir = fullfile('results', 'matlab');
if ~exist(out_dir, 'dir')
    mkdir(out_dir);
end

% Simulation parameters
params = struct();
params.L        = 1200;
params.T_sim    = 1000;
params.dt       = 0.1;
params.v_min    = 1;
params.v_max    = 20;
params.R_range  = 250;
params.pkt_size = 512 * 8;
params.pkt_rate = 12;
params.n_src    = 10;
params.E_init   = 100;
params.E_elec   = 50e-9;
params.eps_amp  = 100e-12;
params.alpha    = 2;
params.T_dec    = 50;
params.w_apsf   = [0.20 0.20 0.20 0.15 0.25];

% Experiment grid
protocols   = {'AODV', 'DSR', 'DSDV', 'ARF-MANET'};
node_counts = [150, 200, 250, 300];
seeds       = 1:10;

total_runs = numel(protocols) * numel(node_counts) * numel(seeds);
run_idx    = 0;

t_start = tic;

for p = 1:numel(protocols)
    for n = 1:numel(node_counts)
        for s = seeds
            run_idx = run_idx + 1;
            fprintf('[%3d/%3d] Protocol=%-9s N=%3d seed=%2d ... ', ...
                    run_idx, total_runs, protocols{p}, node_counts(n), s);
            
            t_run = tic;
            try
                r = manet_sim(protocols{p}, node_counts(n), s, params);
                elapsed = toc(t_run);
                
                fname = sprintf('%s_N%d_s%02d.mat', ...
                                protocols{p}, node_counts(n), s);
                fpath = fullfile(out_dir, fname);
                save(fpath, 'r');
                
                fprintf('OK (%.1f s)  PDR=%.4f  Th=%.1f\n', ...
                        elapsed, r.PDR, r.throughput_kbps);
            catch ME
                fprintf('FAILED: %s\n', ME.message);
            end
        end
    end
end

t_total = toc(t_start);
hours   = floor(t_total / 3600);
minutes = floor(mod(t_total, 3600) / 60);
seconds = mod(t_total, 60);

fprintf('\n==============================================\n');
fprintf('  Campaign complete\n');
fprintf('  Total time: %d h %d min %d s\n', hours, minutes, seconds);
fprintf('  Results saved to: %s\n', out_dir);
fprintf('==============================================\n');

end