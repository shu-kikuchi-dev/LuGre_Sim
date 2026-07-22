%% --- LuGre Master Data Factory (version 1.0, 2026-07-07) ---
% Coverage: Stick-Slip, Hysteresis, rate-Dependency, Pre-sliding, and Damping.
clearvars; clc; close all;

% ====================================================================================
% USER SETTINGS (Directory and Naming)
% ====================================================================================
% FOR MY DESKTOP 
save_csv_dir = 'D:\shu-kikuchi-projects\MATLAB_project\LuGre_Sim\tmp_csv_files';
% FOR MY DESKTOP 
save_fig_dir = 'D:\shu-kikuchi-projects\MATLAB_project\LuGre_Sim\tmp_figs\MasterData';

% FOR MY LAPTOP save_csv_dir = 'C:\Users\shuki\Projects\work\kosen_graduate_study\MATLAB_project\LuGre_Sim\tmp_csv_files';
% FOR MY LAPTOP save_fig_dir = 'C:\Users\shuki\Projects\work\kosen_graduate_study\MATLAB_project\LuGre_Sim\tmp_figs\MasterData';

csv_name = '26-07-22_script-generatepysrdatawithz_refine-to-have-35-35-30-ratio_ode23tbf_maxstepsize-1en4_relativetolerance-1en7_absolutetolerance-1en10';
fig_name = '26-07-22_script-generatepysrdatawithz_refine-to-have-35-35-30-ratio_ode23tbf_maxstepsize-1en4_relativetolerance-1en7_absolutetolerance-1en10';
% ====================================================================================

% Model Configurations
vel_model = 'LuGre_Velocity_Model';    % Direct Velocity Input
sys_model = 'LuGre_Spring_Mass_Model'; % Spring-Mass System

% Constant LuGre Parameters
sigma0 = 1e5; sigma1 = sqrt(sigma0); sigma2 = 0.4;
Fc = 1.0; Fs = 1.5; vs = 0.001;
z_scale = 1e5; % Normalization factor for z and dz/dt

master_table = table(); % Storage for all simulations

if ~exist(save_csv_dir, 'dir'), mkdir(save_csv_dir); end
if ~exist(save_fig_dir, 'dir'), mkdir(save_fig_dir); end

fprintf('--- Starting Master Data Collection ---\n');

%% --- Part 1: Spring-Mass System (LuGre_Spring_Mass_Model, Source ID: 0, Plot Color: Blue) ---
% Captures: Stick-Slip, Rate-Dependency, Damping, and Mass variation.
m_list = [0.5, 1.0, 10.0, 20.0];
k_list = [2, 20, 200];
v_pull_list = [-0.1, -0.01, 0.01, 0.1];

for m_val = m_list
    for k_val = k_list
        for vp_val = v_pull_list
            m = m_val; k = k_val; v_pull = vp_val; % Push variables to Workspace
            fprintf('Simulating Spring-Mass model: m=%.1f, k=%d, v_pull=%.2f\n', m, k, v_pull);

            simOut = sim(sys_model, 'StopTime', '20');

            % Convert Timeseries to Timetable for its superior synch
            % function
            ttV = timeseries2timetable(simOut.v_out);
            ttZ = timeseries2timetable(simOut.z_out);
            ttDZ = timeseries2timetable(simOut.dzdt_out);
            ttF = timeseries2timetable(simOut.F_out);

            % Sync to 0.1 ms grid
            % This process is essential since the solver(ode23tb) tries to
            % get many points during transient and few points during
            % stable.
            ts = synchronize(ttV, ttZ, ttDZ, ttF, 'regular', 'linear', 'TimeStep', seconds(0.0001));

            % Column 1: v, Column 2: z, Column3: dzdt, Column 4: F
            v_col = ts{:, 1};
            z_col = ts{:, 2};
            dzdt_col = ts{:, 3};
            F_col = ts{:, 4};
            Source = zeros(size(v_col)); % Source ID: 0

            % Create Capsule
            capsule = table(v_col, z_col*z_scale, dzdt_col*z_scale, F_col, Source, ...
                'VariableNames', {'v', 'z_norm', 'dzdt_norm', 'F', 'Source'});
            master_table = [master_table; capsule];
        end
    end
end

%% --- Part 2: Direct Velocity (LuGre_Velocity_Model, Source ID: 1, Plot Color: Red) ---
% Captures: Clean Hysteresis Loops (Pre-sliding & Sliding) and Stribeck Curve.
omega_list = [0.1 0.5, 1, 10, 25, 50];
amp_list = [1e-6, 1e-3, 1e-2, 1e-1];

for om_val = omega_list
    for amp_val = amp_list
        omega = om_val; amp = amp_val; % Push variables to Workspace

        % Dynamic Stop Time: Ensure at least 3 full cycles for z to reach steady state
        stop_time = max(30, (2*pi/omega)*3);
        fprintf('Simulating Direct Velocity Input Model: omega=%.1f, amp=%.2e, Duration=%.1f\n', omega, amp, stop_time);

        simOut = sim(vel_model, 'StopTime', num2str(stop_time));

        ttV = timeseries2timetable(simOut.v_out);
        ttZ = timeseries2timetable(simOut.z_out);
        ttDZ = timeseries2timetable(simOut.dzdt_out);
        ttF = timeseries2timetable(simOut.F_out);

        ts = synchronize(ttV, ttZ, ttDZ, ttF, 'regular', 'linear', 'TimeStep', seconds(0.0001));

        v_col = ts{:, 1};
        z_col = ts{:, 2};
        dzdt_col = ts{:, 3};
        F_col = ts{:, 4};
        Source = ones(size(v_col)); % Source ID: 1

        capsule = table(v_col, z_col*z_scale, dzdt_col*z_scale, F_col, Source, ...
                'VariableNames', {'v', 'z_norm', 'dzdt_norm', 'F', 'Source'});
            master_table = [master_table; capsule];
    end
end

%% --- Part 3: Post-Processing (Data Science Specs) ---
% Blue: Spring Mass Model, Red: Velocity Model
fprintf('Refining data to exactly 200 000 rows (Ratio 35:35:30 = Red:Blue-int:Blue-bor)...\n');

% Define Target Row Counts
target_total = 200000;
n_red_target = round(target_total * 0.35);
n_blue_int_target = round(target_total * 0.35);
n_blue_bor_target = round(target_total * 0.30);

% Separate Row Indices
idx_B = find(master_table.Source == 0); % Spring Mass
idx_R = find(master_table.Source == 1); % Velocity

% Sub-Divide Blue Model
is_int_B = (abs(master_table.v(idx_B)) > 1e-4) | (abs(master_table.dzdt_norm(idx_B)) > 0.1);
blue_int_pool = idx_B(is_int_B);
blue_bor_pool = idx_B(~is_int_B);

% Extraction
fprintf('   - Extracting Red (Velocity) data...\n');
keep_red = idx_R(round(linspace(1, length(idx_R), n_red_target)));

fprintf('   - Extracting Blue (Spring Mass, Interesting) dara...\n');
keep_blue_int = blue_int_pool(round(linspace(1, length(blue_int_pool), n_blue_int_target)));

fprintf('   - Extracting Blue (Spring Mass, Boring) data...\n');
keep_blue_bor = blue_bor_pool(round(linspace(1, length(blue_bor_pool), n_blue_bor_target)));

% Combine and Sort
final_idx = sort([keep_red; keep_blue_int; keep_blue_bor]);
final_table = master_table(final_idx, :);

% Shuffle for the CSV Export
csv_path = fullfile(save_csv_dir, [csv_name, '.csv']);
shuffled_table = final_table(randperm(size(final_table, 1)), :);
writetable(shuffled_table, csv_path);

fprintf('--- Success! ---\n');
fprintf('Final Dataset Composition:\n');
fprintf('   - Velocity Model (Red): %d rows\n', length(keep_red));
fprintf('   - Spring-Mass Model Interesting (Blue): %d rows\n', length(keep_blue_int));
fprintf('   - Spring-Mass Model Boring (Blue): %d rows\n', length(keep_blue_bor));
fprintf('   - Total: %d rows', size(final_table, 1));
fprintf('Saved as: %s.csv\n', csv_name);

%% --- Part 4: Verification Plot ---
% Initialize Figure
fig_final = figure('Name', 'Physics-Prioritized Analysis', 'Position', [50, 50, 1600, 500]);

% Define 3 Regimes
regime_names = {'Micro (Pre-Sliding)', 'Meso (Stribeck)', 'Macro (Viscous)'};
regime_limits = [0, 1e-3; 1e-3, 0.1; 0.1, inf];

% Condition for Spring Mass Model
is_int_spMa = (abs(final_table.v) > 1e-4) | (abs(final_table.dzdt_norm) > 0.1);

for r = 1:3
    subplot(1, 3, r); hold on;
    v_min = regime_limits(r, 1);
    v_max = regime_limits(r, 2);

    % Spring Mas Model
    in_reg_spMa = abs(final_table.v) >= v_min & abs(final_table.v) < v_max & final_table.Source == 0;

    idx_int_spMa = find(in_reg_spMa & is_int_spMa);
    idx_bor_spMa = find(in_reg_spMa & ~is_int_spMa);
    idx_bor_spMa_sample = idx_bor_spMa(randperm(length(idx_bor_spMa), min(1000, length(idx_bor_spMa))));

    if ~isempty(idx_bor_spMa_sample)
        scatter3(final_table.v(idx_bor_spMa_sample), final_table.z_norm(idx_bor_spMa_sample), ...
            final_table.F(idx_bor_spMa_sample), 2, [0 0.4 0.8], 'MarkerEdgeAlpha', 0.1);
    end
    if ~isempty(idx_int_spMa)
        h(1) = scatter3(final_table.v(idx_int_spMa), final_table.z_norm(idx_int_spMa), ...
            final_table.F(idx_int_spMa), 5, [0 0.4 0.8], 'filled');
    end

    % Velocity Model
    idx_reg_vel = find(abs(final_table.v) >= v_min & abs(final_table.v) < v_max & final_table.Source == 1);
    idx_vel_sample = idx_reg_vel(randperm(length(idx_reg_vel), min(50000, length(idx_reg_vel))));

    if ~isempty(idx_vel_sample)
        h(2) = scatter3(final_table.v(idx_vel_sample), final_table.z_norm(idx_vel_sample), ...
            final_table.F(idx_vel_sample), 5, [0.8 0 0], 'filled');
    end

    title(regime_names{r}); xlabel('velocity /(m/s)'); ylabel('z (normalized)'); zlabel('F'); grid on;
    if r == 1, view(0, 0); else, view(45, 30); end
end

legend([h(1), h(2)], {'Spring-Mass Model (Blue)', 'Velocity Model (Red)'}, ...
    'Location', 'southoutside', 'Orientation', 'horizontal');

% Saving Figure
fig_path = fullfile(save_fig_dir, [fig_name, '.fig']);
savefig(fig_final, fig_path);

fprintf('--- Success! ---\n');
fprintf('Figure saved as: %s.fig\n', fig_name);