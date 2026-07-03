%% --- Observing Stick-Slip Phenomenon Automation ---
model_name = 'LuGre_model_StickSlip';

% Physical Parameters
m = 1.0;
k = 2;
v_pull = 0.1;

% LuGre Model Parameters
sigma0 = 1e5;
sigma1 = sqrt(sigma0);
sigma2 = 0.4;
Fc = 1.0;
Fs = 1.5;
vs = 0.001;

% Simulation
simOut = sim(model_name, 'StopTime', '40');

t = simOut.tout;
v_data = simOut.v_out;
F_data = simOut.F_out;
x_data = simOut.x_out;
y_data = simOut.y_out;

idx = find(t>0);

%% --- Plotting the Result ---
figure;
hold on;
plot(t(idx), y_data(idx));
plot(t(idx), x_data(idx));
legend('Driver Position (y)', 'Mass Position (x)', 'Location', 'best');
grid on;
xlabel('Time /s');
ylabel('Position /m');
title('Position vs. Time, Stick-Slip Motion');

figure;
hold on;
plot(t(idx), F_data(idx));
plot(t(idx), v_data(idx));
legend('Friction Force', 'Velocity (dx/dt)', 'Location', 'best');
grid on;
xlabel('Time /s');
ylabel('Friction Force /N, Velocity /(m/s)');
title('Friction, Velocity vs. Time, Stick-Slip Motion');