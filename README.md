# Battery driver for ESP32 Tasmota

The driver and supporring utilities are located in voltdrv.be.

Not plug'n'play, IPs are hardcoded.

Not for external usage, but an inspiring example.

## The solution

A grid power inverter draws power from a battery until voltage drops to 10.5V, this setting is fixed. The driver provides few types of voltage telemetry. Use the telemetry to turn off an inverter output (Tasmota plug or relay) when voltage drops below threshold.

A grid voltage stabilizer is sensitive to AC frequency fluctuations. When grid is unstable during coming online, the stabilizer won't start. The "GridCheck" command is intended to be issued by a stab input (Tasmota plug or relay) at regular intervals. If the driver doesn't sense charging, that means the stab is off, and the driver will command the stab input to go off and then on after the cooldown period.

## Schematics

<img width="70%" height="auto" alt="Visual" src="https://github.com/user-attachments/assets/dd9d72f6-04bb-4de9-88ef-733e09f67be5" />
