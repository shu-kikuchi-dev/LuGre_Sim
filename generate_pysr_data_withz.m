%% --- LuGre Master Data Factory (version 1.0, 2026-07-07) ---
% Coverage: Stick-Slip, Hysteresis, rate-Dependency, Pre-sliding, and Damping.
clearvars; clc; close all;

% Model Configurations
vel_model = 'LuGre_Velocity_Model';    % Direct Velocity Input
sys_model = 'LuGre_Spring_Mass_Model'; % Spring-Mass System

% Constant LuGre Parameters
sigma0 = 1e5; sigma1 = sqrt(sigma0); sigma2 = 0.4;
Fc = 1.0; Fs = 1.5; vs = 0.001;
z_scale = 1e5; % Normalization factor for z and dz/dt

master_table = table(); % Storage for all simulations

fprintf('--- Starting Master Data Collection ---\n');

%% --- Part 1: Spring-Mass System (LuGre_Spring_Mass_Model) ---
% Captures: Stick-Slip, Rate-Dependency, Damping, and Mass variation.
m_list = [0.5, 1.0, 5.0];
k_list = [2, 20, 100];
v_pull_list = [0.01, 0.1];

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

            % Create Capsule
            capsule = table(v_col, z_col*z_scale, dzdt_col*z_scale, F_col, ...
                'VariableNames', {'v', 'z_norm', 'dzdt_norm', 'F'});
            master_table = [master_table; capsule];
        end
    end
end

%% --- Part 2: Direct Velocity (LuGre_Velocity_Model) ---
% Captures: Clean Hysteresis Loops (Pre-sliding & Sliding) and Stribeck Curve.
omega_list = [1, 10, 25];
amp_list = [5e-6, 1e-3, 5e-3];

for om_val = omega_list
    for amp_val = amp_list
        omega = om_val; amp = amp_val; % Push variables to Workspace
        fprintf('Simulating Direct Velocity Input Model: omega=%d, amp=%.2e\n', omega, amp);

        simOut = sim(vel_model, 'StopTime', '10');

        ttV = timeseries2timetable(simOut.v_out);
        ttZ = timeseries2timetable(simOut.z_out);
        ttDZ = timeseries2timetable(simOut.dzdt_out);
        ttF = timeseries2timetable(simOut.F_out);

        ts = synchronize(ttV, ttZ, ttDZ, ttF, 'regular', 'linear', 'TimeStep', seconds(0.0001));

        v_col = ts{:, 1};
        z_col = ts{:, 2};
        dzdt_col = ts{:, 3};
        F_col = ts{:, 4};

        capsule = table(v_col, z_col*z_scale, dzdt_col*z_scale, F_col, ...
                'VariableNames', {'v', 'z_norm', 'dzdt_norm', 'F'});
            master_table = [master_table; capsule];
    end
end

%% --- Part 3: Post-Processing (Data Science Specs) ---
% Balancing: Keep transients, downsample steady-state
fprintf('Balancing and Filtering Data...\n');
% "Interesting" if velocity is high OR internal state is changing fast
is_interesting = (abs(master_table.v) > 1e-4) | (abs(master_table.dzdt_norm) > 0.1);
boring_indices = find(~is_interesting);
keep_boring = boring_indices(1:100:end); % Keep only 1 out of 100 boring points
final_indices = sort([find(is_interesting); keep_boring]);

final_table = master_table(final_indices, :);

% Shuffling (Prevents bias from time-order)
final_table = final_table(randperm(size(final_table, 1)), :);

% Export to CSV for PySR
writetable(final_table, 'pysr_master_friction_data.csv');

fprintf('--- Success! ---\n');
fprintf('Final dataset contains %d rows.\n', size(final_table, 1));
fprintf('Saved as: pysr_master_friction_data.csv\n');

%% --- Verification Plot ---
% Dividing the data to see the details
% 1. Macro Regime (High Speed Sliding)
macro_data = final_table(abs(final_table.v) > 0.01, :);
% Sample 5000 points for the plot to avoid slowing down the PC
idx_macro = randperm(size(macro_data, 1), min(5000, size(macro_data, 1)));

% 2. Micro Regime (Stiction and Pre-Sliding)
micro_data = final_table(abs(final_table.v) <= 0.01, :);
% Sample 5000 points for the plot to avoid slowing down the PC
idx_micro = randperm(size(micro_data, 1), min(5000, size(micro_data, 1)));

% Plot them separately
figure;
subplot(1, 2, 1);
scatter3(macro_data.v(idx_macro), macro_data.z_norm(idx_macro), macro_data.F(idx_macro), 5, 'red', 'filled');
title('Macro: Kinetic Regime (The Needle)');
xlabel('v /(m/s)'); ylabel('z (normalized)'); zlabel('F /N');

subplot(1, 2, 2);
scatter3(micro_data.v(idx_micro), micro_data.z_norm(idx_micro), micro_data.F(idx_micro), 5, 'blue', 'filled');
title('Micro: Static Regime (The Wall)');
xlabel('v /(m/s)'); ylabel('z (normalized)'); zlabel('F /N');

title('Visualizing the State-Space Surface for PySR');
grid on;

figure;
% Sample 5000 points for the plot to avoid slowing down the PC
plot_idx = randperm(size(final_table, 1), min(5000, size(final_table, 1)));
scatter3(final_table.v(plot_idx), final_table.z_norm(plot_idx), final_table.F(plot_idx), ...
    5, final_table.dzdt_norm(plot_idx), 'filled');
colormap("jet"); colorbar;
xlabel('Velocity /(m/s)'); ylabel('Internal State z (normalized)'); zlabel('Friction Force /N');
title('Visualizing the State-Space Surface for PySR');
grid on;