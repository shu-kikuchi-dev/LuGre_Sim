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

%% --- Case 1: Spring-Mass System (LuGre_Spring_Mass_Model) ---
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
                'Uniform', 'Interval', 0.001);

            % Create Capsule
            capsule = table(ts.v_out.Data, ts.z_out.Data*z_scale, ts.dzdt_out.Data*z_scale, ts.F_out.Data, ...
                'VariableNames', {'v', 'z_norm', 'dzdt_norm', 'F'});
            master_table = [master_table; capsule];
        end
    end
end

%% --- Case 2: Direct Velocity (LuGre_Velocity_Model) ---
% Captures: Clean Hysteresis Loops (Pre-sliding & Sliding) and Stribeck Curve.
omega_list = [1, 10, 25];
amp_list = [5e-6, 1e-3, 5e-3];

for om_val = omega_list
    for amp_val = amp_list
    end
end