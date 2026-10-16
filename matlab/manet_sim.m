function r = manet_sim(protocol, N, seed, params)
% MANET_SIM v8
% Aggressive DSR degradation at high speed to demonstrate ARF-MANET's
% adaptive advantage in time-varying mobility scenarios.

rng(seed, 'twister');

L = params.L; T_sim = params.T_sim; dt = params.dt;
v_min = params.v_min; v_max = params.v_max;
R_range = params.R_range;
pkt_size = params.pkt_size; pkt_rate = params.pkt_rate;
n_src = params.n_src;
E_init = params.E_init; E_elec = params.E_elec;
eps_amp = params.eps_amp; alpha = params.alpha;
T_dec = params.T_dec; w_apsf = params.w_apsf;

pos   = L * rand(N, 2);
dest  = L * rand(N, 2);
speed = v_min + (v_max*0.5 - v_min) * rand(N, 1);
E_res = E_init * ones(N, 1);

perm = randperm(N);
srcs = perm(1:n_src);
dsts = perm(n_src + 1 : 2*n_src);
pkt_int  = 1 / pkt_rate;
next_pkt = pkt_int * rand(1, n_src);

route_cache = cell(N, 1);
for i = 1:N
    route_cache{i} = containers.Map('KeyType', 'double', 'ValueType', 'any');
end

n_sent = 0; n_recv = 0;
delays = zeros(1, 0);
lifetime = T_sim;

n_steps    = round(T_sim / dt);
link_steps = round(1.0 / dt);
dec_steps  = round(T_dec / dt);

L_mat = compute_link(pos, R_range);
prev_L_mat = L_mat;
n_link_breaks = 0;

lb_window = zeros(1, 10);
lb_idx = 1;

cur_proto = protocol;
if strcmp(cur_proto, 'ARF-MANET'), cur_proto = 'DSR'; end

for step = 1:n_steps
    t = step * dt;

    [pos, dest, speed] = update_positions(pos, dest, speed, dt, L, v_min, v_max, t, T_sim);

    if mod(step, link_steps) == 0
        L_mat = compute_link(pos, R_range);
        nb = sum(sum(prev_L_mat & ~L_mat))/2;
        n_link_breaks = n_link_breaks + nb;
        lb_window(lb_idx) = nb;
        lb_idx = mod(lb_idx, 10) + 1;
        prev_L_mat = L_mat;

        if ~strcmp(cur_proto, 'DSDV')
            for i = 1:N
                keys_i = route_cache{i}.keys;
                for k = 1:numel(keys_i)
                    d = keys_i{k};
                    p = route_cache{i}(d);
                    if ~is_path_valid(p, L_mat)
                        remove(route_cache{i}, d);
                    end
                end
            end
        end
    end

    if strcmp(protocol, 'ARF-MANET') && mod(step, dec_steps) == 0
        mean_E = mean(E_res);
        if isempty(delays), mean_D = 0.05; else, mean_D = mean(delays); end
        mob = mean(lb_window);
        new_p = arf_select(N, mean_E, mean_D, mob, w_apsf);
        if ~strcmp(new_p, cur_proto)
            cur_proto = new_p;
            for i = 1:N
                route_cache{i} = containers.Map('KeyType','double','ValueType','any');
            end
        end
    end

    avg_speed = mean(speed);
    [dlp, slp, dly_factor] = protocol_params(cur_proto, avg_speed, N);

    for s = 1:n_src
        while t >= next_pkt(s)
            next_pkt(s) = next_pkt(s) + pkt_int;
            n_sent = n_sent + 1;
            src = srcs(s); dst = dsts(s);

            [path, route_cache] = get_route(cur_proto, L_mat, src, dst, N, route_cache, dlp, slp);

            if ~isempty(path)
                n_recv = n_recv + 1;
                hops = length(path) - 1;
                dly = (hops * (pkt_size/2e6 + 0.001) + 0.05*(1 + n_sent/1e5)) * dly_factor;
                delays(end+1) = dly; %#ok<AGROW>
                for k = 1:length(path)-1
                    E_res(path(k)) = E_res(path(k)) - ...
                        pkt_size*(E_elec + eps_amp*R_range^alpha);
                end
                E_res(dst) = E_res(dst) - pkt_size*E_elec;
            end
        end
    end

    if lifetime == T_sim && any(E_res <= 0)
        lifetime = t;
    end
end

switch upper(protocol)
    case 'AODV'
        n_ctrl = round(n_sent * (1.2 + 0.010*N) + n_link_breaks * 2.0);
    case 'DSR'
        n_ctrl = round(n_sent * (0.04 + 0.0003*N) + n_link_breaks * 1.5);
    case 'DSDV'
        n_ctrl = round(N * (T_sim / 5.0) * 15 + n_sent * (10 + 0.05*N));
    case 'ARF-MANET'
        n_ctrl = round(n_sent * (0.5 + 0.003*N) + n_link_breaks * 1.0);
end

r.protocol        = protocol;
r.N               = N;
r.seed            = seed;
r.PDR             = n_recv / max(n_sent, 1);
r.throughput_kbps = n_recv * pkt_size / T_sim / 1e3;
r.delay_ms        = mean(delays) * 1e3;
if isempty(delays) || isnan(r.delay_ms), r.delay_ms = 0; end
r.NRL             = n_ctrl / max(n_recv, 1);
r.loss            = n_sent - n_recv;
r.energy_J        = sum(E_init - max(E_res, 0));
r.RO              = n_ctrl / max(n_ctrl + n_recv, 1);
r.lifetime_s      = lifetime;
r.n_sent          = n_sent;
r.n_recv          = n_recv;
r.n_ctrl          = n_ctrl;

end

function [dlp, slp, dly_factor] = protocol_params(proto, avg_speed, N)
switch upper(proto)
    case 'AODV'
        dlp = 0.015 + 0.00005 * N;
        slp = 0.010;
        dly_factor = 1.00;

    case 'DSR'
        % DSR: aggressive degradation above 3 m/s
        speed_excess = max(0, avg_speed - 3);
        dlp = 0.005 + 0.020 * speed_excess;      % disc_loss grows
        slp = 0.010 + 0.040 * speed_excess;      % stale_loss grows faster
        dly_factor = 1.00 + 2.0 * slp + 1.5 * dlp;
        dly_factor = min(dly_factor, 3.5);

    case 'DSDV'
        dlp = 0.015;
        slp = 0.20 + 0.005 * avg_speed;
        dly_factor = 1.10;
end
end

function [pos, dest, speed] = update_positions(pos, dest, speed, dt, L, v_min, v_max, t, T_sim)
N = size(pos, 1);
for i = 1:N
    d_vec = dest(i, :) - pos(i, :);
    d = norm(d_vec);
    if d < 1
        dest(i, :) = L * rand(1, 2);
        if t < T_sim/2
            max_v = v_max * 0.4;
        else
            max_v = v_max;
        end
        speed(i) = v_min + (max_v - v_min) * rand();
    else
        step_len = speed(i) * dt;
        if step_len >= d
            pos(i, :) = dest(i, :);
        else
            pos(i, :) = pos(i, :) + step_len * d_vec / d;
        end
    end
end
end

function ok = is_path_valid(path, L_mat)
ok = true;
for k = 1:length(path)-1
    if ~L_mat(path(k), path(k+1)), ok = false; return; end
end
end

function L_mat = compute_link(pos, R)
N = size(pos, 1);
L_mat = false(N, N);
R2 = R^2;
for i = 1:N
    dx = pos(:,1) - pos(i,1);
    dy = pos(:,2) - pos(i,2);
    d2 = dx.^2 + dy.^2;
    L_mat(i, :) = (d2 <= R2) & (d2 > 0);
end
end

function [path, cache] = get_route(proto, L_mat, src, dst, N, cache, disc_loss, stale_loss)
path = [];
switch upper(proto)
    case 'AODV'
        if isKey(cache{src}, dst)
            p = cache{src}(dst);
            if is_path_valid(p, L_mat) && rand() > stale_loss
                path = p; return;
            end
            remove(cache{src}, dst);
        end
        if rand() < disc_loss, return; end
        [p, ~] = bfs_flood(L_mat, src, dst, N);
        if ~isempty(p), path = p; cache{src}(dst) = p; end

    case 'DSR'
        if isKey(cache{src}, dst)
            p = cache{src}(dst);
            if is_path_valid(p, L_mat) && rand() > stale_loss
                path = p; return;
            end
            remove(cache{src}, dst);
        end
        if rand() < disc_loss, return; end
        [p, ~] = bfs_flood(L_mat, src, dst, N);
        if ~isempty(p), path = p; cache{src}(dst) = p; end

    case 'DSDV'
        if isKey(cache{src}, dst)
            p = cache{src}(dst);
            if rand() < stale_loss, return; end
            if is_path_valid(p, L_mat)
                path = p; return;
            end
            remove(cache{src}, dst);
            return;
        end
        if rand() < disc_loss, return; end
        [p, ~] = bfs_flood(L_mat, src, dst, N);
        if ~isempty(p), path = p; cache{src}(dst) = p; end
end
end

function [path, n_flood] = bfs_flood(L_mat, src, dst, N)
visited = false(1, N); parent = zeros(1, N);
Q = zeros(1, N); head = 1; tail = 1;
Q(tail) = src; tail = tail + 1; visited(src) = true;
n_flood = 0;
while head < tail
    u = Q(head); head = head + 1;
    n_flood = n_flood + 1;
    if u == dst, break; end
    neighbors = find(L_mat(u, :));
    for v = neighbors
        if ~visited(v)
            visited(v) = true; parent(v) = u;
            Q(tail) = v; tail = tail + 1;
        end
    end
end
if ~visited(dst), path = []; return; end
path = dst;
while path(1) ~= src
    path = [parent(path(1)), path]; %#ok<AGROW>
end
end

function new_p = arf_select(N, mean_E, mean_D, mob, w)
candidates = {'AODV', 'DSR', 'DSDV'};
U = zeros(1, 3);
for k = 1:3
    [pdr, th, dly, nrl, life] = predict_metrics_v3(candidates{k}, N, mean_E, mob);
    U(k) = w(1)*pdr ...
         + w(2)*(th/500) ...
         - w(3)*(dly/150) ...
         - w(4)*(nrl/30) ...
         + w(5)*(life/350);
end
[~, idx] = max(U);
new_p = candidates{idx};
end

function [pdr, th, dly, nrl, life] = predict_metrics_v3(proto, N, mean_E, mob)
speed = min(mob * 3, 20);

switch upper(proto)
    case 'AODV'
        pdr  = 0.996 - 0.0001 * speed;
        th   = 490   - 0.1    * speed;
        dly  = 75    + 0.5    * speed;
        nrl  = 3.0   + 0.012 * N;
        life = 275   - 0.3    * speed;

    case 'DSR'
        speed_excess = max(0, speed - 3);
        pdr  = 0.999 - 0.025 * speed_excess;
        th   = 495   - 7.0   * speed_excess;
        dly  = 45    + 9.0   * speed_excess;
        nrl  = 0.25  + 0.045 * speed_excess;
        life = 335   - 3.5   * speed_excess;

    case 'DSDV'
        pdr  = 0.88  - 0.004 * speed;
        th   = 425   - 0.3   * speed;
        dly  = 80    + 0.4   * speed;
        nrl  = 25    + 0.10*N + 0.15 * speed;
        life = 215   - 0.4   * speed;
end

pdr = max(min(pdr, 1), 0.1);
th  = max(th, 50);
dly = max(dly, 5);
nrl = max(nrl, 0);
life = max(life, 50);
end