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
            m = m_val; k = k_val; v_pull = vp_vall; % Push variables to Workspace
            fprintf('Simulating Spring-Mass model: m=%.1f, k=%d, v_pull=%.2f\n', m, k, v_pull);

            simOut = sim(model_sys, 'StopTime', '20');

            % Sync to 1 ms grid
            ts = synchronize(simOut.v_out, simOut.z_out, simOut.dzdt_out, simOut.F_out, ...
                'Uniform', 'Interval', 0.0001);

            % Create Capsule
            capsule = table(ts.v_out.Data, ts.z_out.Data*z_scale, ts.dzdt_out.Data*z_scale, ts.F_out.Data, ...
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

        simOut = sim(model_vel, 'StopTime', '10');

        ts = synchronize(simOut.v_out, simOut.z_out, simOut.dzdt_out, simOut.F_out, ...
            'Uniform', 'Interval', 0.0001);

        capsule = table(ts.v_out.Data, ts.z_out.Data*z_scale, ts.dzdt_out.Data*z_scale, ts.F_out.Data, ...
            'VariableNames', {'v', 'z_norm', 'dzdt_norm', 'F'});
        master_table = [master_table; capsule];
    end
end

%% --- Part 3: Post-Processing (Data Science Specs) ---
% Balancing: Keep transients, downsample steady-state
fprintf('Balancing and Filtering Data...\n');
% "Interesting" if velocity is high OR internal state is changing fast
is_interesting = (abs(master_table.v) > 1e-4) | (abs(master_table.szdt_norm) > 0.1);
boring_indices = find(~is_interesting);
keep_boring = boring_indices(1:30:end); % Keep only 1 out of 30 boring points
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
figure;
scatter3(final_table.v, final_table.z_norm, final_table.F, 2, final_table.dzdt_norm, 'filled');
colormap("jet"); colorbar;
xlabel('Velocity /(m/s)'); ylabel('Internal State z (normalized)'); zlabel('Friction Force /N');
title('Visualizing the State-Space Surface for PySR');
grid on;