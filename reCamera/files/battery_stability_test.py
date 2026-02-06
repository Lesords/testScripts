import time
import os
import sys
import statistics

# Configuration
GPIO_EXPORT = "/sys/class/gpio/export"
GPIO_PIN = "430"
GPIO_PATH = f"/sys/class/gpio/gpio{GPIO_PIN}"
GPIO_VALUE = f"{GPIO_PATH}/value"
GPIO_DIR = f"{GPIO_PATH}/direction"
ADC_RAW = "/sys/bus/iio/devices/iio:device0/in_voltage0_raw"
ADC_SCALE = "/sys/bus/iio/devices/iio:device0/in_voltage0_scale"

def setup_gpio():
    """Ensure GPIO 430 is exported and set to output."""
    if not os.path.exists(GPIO_PATH):
        print(f"Exporting GPIO {GPIO_PIN}...")
        try:
            with open(GPIO_EXPORT, 'w') as f:
                f.write(GPIO_PIN)
        except OSError as e:
            print(f"Error exporting GPIO: {e}")
            return False

    # Allow some time for sysfs entry to appear
    time.sleep(0.1)

    print(f"Setting GPIO {GPIO_PIN} direction to out...")
    try:
        with open(GPIO_DIR, 'w') as f:
            f.write("out")
    except OSError as e:
        print(f"Error setting direction: {e}")
        return False

    return True

def read_adc_scale():
    """Read the ADC scale factor."""
    try:
        with open(ADC_SCALE, 'r') as f:
            return float(f.read().strip())
    except Exception as e:
        print(f"Error reading scale: {e}")
        return 1.0

def measure_voltage(delay_ms, scale):
    """
    Enable ADC (GPIO High), wait delay_ms, read value, disable ADC (GPIO Low).
    Returns voltage in mV.
    """
    # 1. Enable ADC (Set GPIO High)
    with open(GPIO_VALUE, 'w') as f:
        f.write("1")

    # 2. Wait for stabilization
    time.sleep(delay_ms / 1000.0)

    # 3. Read raw value
    raw_val = 0
    try:
        with open(ADC_RAW, 'r') as f:
            raw_val = int(f.read().strip())
    except Exception as e:
        pass # Ignore read errors for stability test, or return 0

    # 4. Disable ADC (Set GPIO Low)
    with open(GPIO_VALUE, 'w') as f:
        f.write("0")

    # Calculate voltage: raw * scale * 2.0 (divider)
    # Matches api_device.cpp logic
    voltage_mv = raw_val * scale * 2.0
    return voltage_mv, raw_val

def run_test():
    if not setup_gpio():
        print("Failed to setup GPIO. Exiting.")
        sys.exit(1)

    scale = read_adc_scale()
    print("\nStarting Battery Voltage Stability Test")
    print("=======================================")
    print(f"ADC Scale Factor: {scale}")
    print(f"Calculation: Raw * {scale} * 2.0")

    # Pre-calculate baseline at 100ms for relative comparison
    print("Calibrating baseline at 100ms...", end='', flush=True)
    baseline_samples = []
    for _ in range(10):
        mv, _ = measure_voltage(100, scale)
        baseline_samples.append(mv)
        time.sleep(0.05)
    ref_val = statistics.mean(baseline_samples)
    print(f" Done. Baseline: {ref_val:.2f} mV")

    print("-" * 120)
    print(f"{'Delay':<6} | {'Avg(mV)':<8} | {'Std':<6} | {'Min/Max':<10} | {'Diff':<8} | {'Status':<8} | {'Voltage Samples (mV)'}")
    print("-" * 120)

    # Test delays: 0 to 100 ms
    delays = [0, 5, 10, 15, 20, 25, 30, 40, 50, 75, 100]

    for delay in delays:
        samples = []
        raw_samples = []

        # Take 10 samples for better statistics
        for _ in range(10):
            mv, raw = measure_voltage(delay, scale)
            samples.append(mv)
            raw_samples.append(raw)
            # Cool-down to ensure independent tests
            time.sleep(0.05) 

        avg_mv = statistics.mean(samples)
        std_dev = statistics.stdev(samples) if len(samples) > 1 else 0
        min_mv = min(samples)
        max_mv = max(samples)

        # Calculate difference percentage from the reference (100ms) value
        if ref_val > 0:
            diff_pct = (avg_mv - ref_val) / ref_val * 100
        else:
            diff_pct = 0.0

        # Determine status
        is_stable_jitter = std_dev < 20.0 
        is_converged = abs(diff_pct) < 1.0

        status = ""
        if not is_stable_jitter:
            status += "Jittery "
        if not is_converged:
            status += "Rising "
        if status == "":
            status = "STABLE"

        samples_str = ",".join([f"{int(v)}" for v in samples])
        print(f"{delay:<6} | {avg_mv:<8.1f} | {std_dev:<6.1f} | {int(min_mv)}/{int(max_mv):<8} | {diff_pct:>+7.2f}% | {status:<8} | {samples_str}", flush=True)

    print("-" * 120)

    print("-" * 100)
    print("Recommendation:")
    print("1. Look for 'STABLE' status where Diff is near 0.00% and StdDev is low.")
    print("2. Current C++ code uses 30000us (30ms). Verify if that row is marked STABLE.")

if __name__ == "__main__":
    run_test()
