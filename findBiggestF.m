%% --- Break-away Force vs Force Rate Automation ---
model_name = 'LuGre_model_A';

% Physical Parameters
m = 1.0;    % Mass /kg
k = 2;      % Spring Constant /(N/m)

% Range of Force Rate to test /(N/s)
% Force Rate = k * v_pull. So we vary v_pull to get different rates.
target_force_rates = [0.1, 0.5, 1, 2, 5, 10, 15, 20, 30, 40, 50];

%Result storage
results_force_rate = zeros(size(target_force_rates));
results_breakaway = zeros(size(target_force_rates));

fprintf('Starting Break-away Force Analysis...\n');

for i = 1:length(target_force_rates)
    % 1. Calculate the necessary ramp velocity for this Force Rate
    current_fr = target_force_rates(i);
    v_pull = current_fr / k;    % Slope for the Ramp block

    % 2. Run the simulation
    % We use 'sim' command and pass 'v_pull' to the workspace
    simOut = sim(model_name, 'StopTime', '10', 'SrcWorkspace', 'current'):

    % 3. Extract the Friction Force data
    % Assuming you used Signal Logging or a 'To Workspace' block
    % If using a 'To Workspace' block:
    F_data = simOut.F_out;

    % 4. Find the MAXIMAM friction force (the Break-away point)
    % max(F) occurs when z is at its limit
    break_away_force = max(F_data);

    % Store the results
    results_force_rate(i) = current_fr;
    results_breakaway(i) = break_away_force;

    fprintf('Rate: %4. 1f N/s | Break-away Force: %6. 4f N\n', current_fr, break_away_force);
end

%% --- Plotting the Result ---
figure;
plot(result_force_rate, results_breakaway, 'bo-', 'LineWidth', 1.5, 'MarkerSize', 8);
grid on;
xlabel('Force Rate /(N/m)');
ylabel('Break-away Force /N');
title('Break-away Force vs. Force Rate');
ylim([0.9, 1.6]);   % To match the paper