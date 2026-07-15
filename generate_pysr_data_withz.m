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

csv_name = '26-07-15_script-generatepysrdatawithz_refine-velocity-params-and-filter-conditions_ode23tbf_maxstepsize-1en4_relativetolerance-1en7_absolutetolerance-1en10';
fig_name = '26-07-15_script-generatepysrdatawithz_refine-velocity-params-and-filter-conditions_ode23tbf_maxstepsize-1en4_relativetolerance-1en7_absolutetolerance-1en10';
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
% Balancing: Keep transients, downsample steady-state
fprintf('Balancing and Filtering Data...\n');
% "Interesting" if velocity is high OR internal state is changing fast
% Since velocity model is so smooth, most of all red points would not reach z=0.1
is_interesting = (abs(master_table.v) > 1e-4) | (abs(master_table.dzdt_norm) > 0.1) | (master_table.Source == 1);
boring_indices = find(~is_interesting);
keep_boring = boring_indices(1:100:end); % Keep only 1 out of 100 boring points
final_indices = sort([find(is_interesting); keep_boring]);

final_table = master_table(final_indices, :);

% Shuffling (Prevents bias from time-order)
final_table = final_table(randperm(size(final_table, 1)), :);

% Export to CSV for PySR
csv_path = fullfile(save_csv_dir, [csv_name, '.csv']);
writetable(final_table, csv_path);

fprintf('--- Success! ---\n');
fprintf('Final dataset contains %d rows.\n', size(final_table, 1));
fprintf('Saved as: %s.csv\n', csv_name);

%% --- Verification Plot ---
% 1. Define Regime Thresholds
% vs = 0.001, we use 1e-3 as the micro boundary.
micro_data = final_table(abs(final_table.v) < 1e-3, :); % Micro (Pre-Sliding)
meso_data = final_table(abs(final_table.v) >= 1e-3 & abs(final_table.v) < 0.1, :); % Meso (Stribeck)
macro_data = final_table(abs(final_table.v) >= 0.1, :); % Macro (Viscous)

% 2. Extract 5000 points for the plot to avoid slowing down the PC
idx_micro = randperm(size(micro_data, 1), min(5000, size(micro_data, 1)));
idx_meso = randperm(size(meso_data, 1), min(5000, size(meso_data, 1)));
idx_macro = randperm(size(macro_data, 1), min(5000, size(macro_data, 1)));

% 3. Initialize Figure
fig_final = figure('Name', 'LuGre 3-Regime Analysis', 'Position', [50, 50, 1600, 500]);

% 4. Plot Micro Regime (Pre-Sliding)
subplot(1, 3, 1); hold on;
mi_spMa = micro_data.Source == 0; mi_vel = micro_data.Source == 1;
scatter3(micro_data.v(idx_micro(mi_spMa(idx_micro))), micro_data.z_norm(idx_micro(mi_spMa(idx_micro))), ...
    micro_data.F(idx_micro(mi_spMa(idx_micro))), 5, 'Blue', 'filled');
scatter3(micro_data.v(idx_micro(mi_vel(idx_micro))), micro_data.z_norm(idx_micro(mi_vel(idx_micro))), ...
    micro_data.F(idx_micro(mi_vel(idx_micro))), 5, 'Red', 'filled');
title('Micro (Pre-Sliding)');
xlabel('v /(m/s)'); ylabel('z (normalized)'); zlabel('F /N');
grid on;
legend('Spring Mass Model: Blue', 'Velocity Model: Red', 'Location', 'north');

% 5. Plot Meso Regime (Stribeck)
subplot(1, 3, 2); hold on;
me_spMa = meso_data.Source == 0; me_vel = meso_data.Source == 1;
scatter3(meso_data.v(idx_meso(me_spMa(idx_meso))), meso_data.z_norm(idx_meso(me_spMa(idx_meso))), ...
    meso_data.F(idx_meso(me_spMa(idx_meso))), 5, 'Blue', 'filled');
scatter3(meso_data.v(idx_meso(me_vel(idx_meso))), meso_data.z_norm(idx_meso(me_vel(idx_meso))), ...
    meso_data.F(idx_meso(me_vel(idx_meso))), 5, 'Red', 'filled');
title('Meso (Stribeck)');
xlabel('v /(m/s)'); ylabel('z (normalized)'); zlabel('F /N');
grid on;
legend('Spring Mass Model: Blue', 'Velocity Model: Red', 'Location', 'north');

% 6. Plot Macro Regime (Viscous)
subplot(1, 3, 3); hold on;
ma_spMa = macro_data.Source == 0; ma_vel = macro_data.Source == 1;
scatter3(macro_data.v(idx_macro(ma_spMa(idx_macro))), macro_data.z_norm(idx_macro(ma_spMa(idx_macro))), ...
    macro_data.F(idx_macro(ma_spMa(idx_macro))), 5, 'Blue', 'filled');
scatter3(macro_data.v(idx_macro(ma_vel(idx_macro))), macro_data.z_norm(idx_macro(ma_vel(idx_macro))), ...
    macro_data.F(idx_macro(ma_vel(idx_macro))), 5, 'Red', 'filled');
title('Macro (Viscous)');
xlabel('v /(m/s)'); ylabel('z (normalized)'); zlabel('F /N');
grid on;
legend('Spring Mass Model: Blue', 'Velocity Model: Red', 'Location', 'north');

% 7. Saving Figure
fig_path = fullfile(save_fig_dir, [fig_name, '.fig']);
savefig(fig_final, fig_path);

fprintf('--- Success! ---\n');
fprintf('Figure saved as: %s.fig\n', fig_name);