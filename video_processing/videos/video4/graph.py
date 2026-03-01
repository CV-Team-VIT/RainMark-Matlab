import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from scipy.signal import savgol_filter

df = pd.read_csv("rainmark_results.csv")

time = df["frame_name"].str.extract(r'(\d+)').astype(int).values.flatten()

alpha = 17.14
beta  = 0.13
gamma = 0.89

e1 = df["e1"].values
eta_sat = df["ns1"].values
eta_streak = df["percentage_streak_area"].values / 100.0

severity = alpha*e1 + beta*eta_sat + gamma*eta_streak
severity_norm = (severity - severity.min()) / (severity.max() - severity.min())

# ---------------------
# Smooth the curve
# ---------------------
window = 21  # must be odd
poly = 3
severity_smooth = savgol_filter(severity_norm, window, poly)

# ---------------------
# Thresholds
# ---------------------
T_start = 0.65
T_stop  = T_start

derain_active = np.zeros_like(severity_smooth, dtype=int)
active = False

for i in range(len(severity_smooth)):
    if not active and severity_smooth[i] >= T_start:
        active = True
    elif active and severity_smooth[i] <= T_stop:
        active = False
    derain_active[i] = int(active)

# ---------------------
# Plot
# ---------------------
plt.figure(figsize=(8,4))
plt.rcParams.update({
    "font.size": 12,
    "axes.linewidth": 1.2
})

plt.plot(time, severity_smooth, linewidth=2)

plt.axhline(T_start, linestyle="--", linewidth=1.5)
plt.axhline(T_stop, linestyle="--", linewidth=1.5)

for i in range(len(time)-1):
    if derain_active[i] == 1:
        plt.axvspan(time[i], time[i+1], alpha=0.08)

plt.xlabel("Frame Index")
plt.ylabel("RainMark Severity $S_\\eta$")
plt.xlim(time.min(), time.max())
plt.ylim(0, 1.05)

plt.tight_layout()
plt.savefig("adaptive_deraining_plot.pdf", dpi=300, bbox_inches="tight")
plt.show()