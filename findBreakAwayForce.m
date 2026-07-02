%% --- Break-away Force vs Force Rate Automation ---
model_name = 'LuGre_model_A';

% Physical Parameters
m = 1.0;    % Mass /kg
k = 2;      % Spring Constant /(N/m)

% LuGre Model Parameters
sigma0 = 1e5;
sigma1 = sqrt(sigma0);
sigma2 = 0.4;
Fc = 1.0;
Fs = 1.5;
vs = 0.001;

% Range of Force Rate to test /(N/s)
% Force Rate = k * v_pull. So we vary v_pull to get different rates.
target_force_rates = [0.1, 0.5, 1, 2, 5, 10, 15, 20, 30, 40, 50];

%Result storage
results_force_rate = zeros(size(target_force_rates));
results_breakaway = zeros(size(target_force_rates));

fprintf('Starting Break-away Force Analysis...\n');

for i = 1:length(target_force_rates)
    current_fr = target_force_rates(i);
    v_pull = current_fr / k;

    simOut = sim(model_name, 'StopTime', '20');

    z_data = simOut.z_out;
    v_data = simOut.v_out;
    F_data = simOut.F_out;

    z_ss_dynamic = (Fc + (Fs - Fc) * exp(-(abs(v_data) ./ vs).^2)) / sigma0;

    break_idx = find(abs(z_data) >= 0.999 * z_ss_dynamic, 1);

    if isempty(break_idx)
        break_away_force = max(F_data);
    else
        break_away_force = F_data(break_idx);
    end

    results_force_rate(i) = current_fr;
    results_breakaway(i) = break_away_force;

    fprintf('Rate: %4.1f N/s | Break-away Force: %6.4f N\n', current_fr, break_away_force);
end

%% --- Plotting the Result ---
figure;
plot(results_force_rate, results_breakaway, 'bo-', 'LineWidth', 1.5, 'MarkerSize', 8);
grid on;
xlabel('Force Rate /(N/m)');
ylabel('Break-away Force /N');
title('Break-away Force vs. Force Rate');
ylim([0.9, 1.6]);   % To match the paper