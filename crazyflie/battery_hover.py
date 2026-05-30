import csv
import time
from datetime import datetime
from pathlib import Path

import cflib.crtp
from cflib.crazyflie import Crazyflie
from cflib.crazyflie.log import LogConfig
from cflib.crazyflie.syncCrazyflie import SyncCrazyflie
from cflib.positioning.motion_commander import MotionCommander

URI = "radio://0/80/2M/E7E7E7E7E7"

TRIAL_LABEL = "balloon_assisted"  # change to "baseline" for assisted trials
HOVER_HEIGHT_M = 0.30

BATTERY_IGNORE_TIME_S = 10.0
LOW_VOLTAGE_THRESHOLD = 3.25
LOW_VOLTAGE_DURATION_S = 5.0

MAX_ROLL_PITCH_DEG = 35.0
MIN_HEIGHT_M = 0.08
MAX_HEIGHT_M = 0.80

LOG_PERIOD_MS = 500

latest = {
    "vbat": None,
    "z": None,
    "roll": None,
    "pitch": None,
    "yaw": None,
}

rows = []


def log_callback(timestamp, data, logconf):
    latest["vbat"] = data.get("pm.vbat")
    latest["z"] = data.get("stateEstimate.z")
    latest["roll"] = data.get("stabilizer.roll")
    latest["pitch"] = data.get("stabilizer.pitch")
    latest["yaw"] = data.get("stabilizer.yaw")


def safe_float(value):
    return "" if value is None else f"{value:.4f}"


def main():
    cflib.crtp.init_drivers()

    output_dir = Path(r"C:\crazyflie\trial_results")
    output_dir.mkdir(exist_ok=True)

    start_stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    csv_path = output_dir / f"{start_stamp}_{TRIAL_LABEL}_hover_trial.csv"
    summary_path = output_dir / f"{start_stamp}_{TRIAL_LABEL}_summary.txt"

    end_reason = "unknown"
    low_voltage_started = None
    takeoff_voltage = None
    loaded_voltage_10s = None
    end_voltage = None
    recovered_voltage = None

    print("Connecting...")

    with SyncCrazyflie(URI, cf=Crazyflie(rw_cache="./cache")) as scf:
        cf = scf.cf

        cf.param.set_value("stabilizer.estimator", "2")
        cf.param.set_value("stabilizer.controller", "1")
        time.sleep(2)

        logconf = LogConfig(name="EnduranceLog", period_in_ms=LOG_PERIOD_MS)
        logconf.add_variable("pm.vbat", "float")
        logconf.add_variable("stateEstimate.z", "float")
        logconf.add_variable("stabilizer.roll", "float")
        logconf.add_variable("stabilizer.pitch", "float")
        logconf.add_variable("stabilizer.yaw", "float")

        cf.log.add_config(logconf)
        logconf.data_received_cb.add_callback(log_callback)
        logconf.start()

        print("Waiting for first log sample...")
        while latest["vbat"] is None:
            time.sleep(0.1)

        takeoff_voltage = latest["vbat"]
        print(f"Takeoff voltage: {takeoff_voltage:.2f} V")
        print("Taking off...")

        flight_start = time.time()

        try:
            with MotionCommander(scf, default_height=HOVER_HEIGHT_M) as mc:
                while True:
                    now = time.time()
                    elapsed = now - flight_start

                    vbat = latest["vbat"]
                    z = latest["z"]
                    roll = latest["roll"]
                    pitch = latest["pitch"]
                    yaw = latest["yaw"]

                    rows.append({
                        "time_s": f"{elapsed:.3f}",
                        "vbat": safe_float(vbat),
                        "z_m": safe_float(z),
                        "roll_deg": safe_float(roll),
                        "pitch_deg": safe_float(pitch),
                        "yaw_deg": safe_float(yaw),
                    })

                    if loaded_voltage_10s is None and elapsed >= 10.0 and vbat is not None:
                        loaded_voltage_10s = vbat
                        print(f"Loaded voltage at 10 s: {loaded_voltage_10s:.2f} V")

                    if elapsed > 3.0:
                        if roll is not None and abs(roll) > MAX_ROLL_PITCH_DEG:
                            end_reason = f"unsafe roll angle: {roll:.1f} deg"
                            break

                        if pitch is not None and abs(pitch) > MAX_ROLL_PITCH_DEG:
                            end_reason = f"unsafe pitch angle: {pitch:.1f} deg"
                            break

                        if z is not None and elapsed > 8.0:
                            if z < MIN_HEIGHT_M:
                                end_reason = f"height below safe threshold: {z:.2f} m"
                                break

                            if z > MAX_HEIGHT_M:
                                end_reason = f"height above safe threshold: {z:.2f} m"
                                break

                    if elapsed >= BATTERY_IGNORE_TIME_S and vbat is not None:
                        if vbat <= LOW_VOLTAGE_THRESHOLD:
                            if low_voltage_started is None:
                                low_voltage_started = now
                                print(f"Low voltage detected: {vbat:.2f} V")
                            elif now - low_voltage_started >= LOW_VOLTAGE_DURATION_S:
                                end_reason = (
                                    f"voltage <= {LOW_VOLTAGE_THRESHOLD:.2f} V "
                                    f"for {LOW_VOLTAGE_DURATION_S:.1f} s"
                                )
                                break
                        else:
                            low_voltage_started = None

                    time.sleep(LOG_PERIOD_MS / 1000.0)

                end_voltage = latest["vbat"]
                flight_duration = time.time() - flight_start

                print(f"Ending trial: {end_reason}")
                print("Landing...")
                mc.land()

        finally:
            logconf.stop()

        print("Waiting 60 s for recovered voltage...")
        time.sleep(60)
        recovered_voltage = latest["vbat"]

    with open(csv_path, "w", newline="") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=[
                "time_s",
                "vbat",
                "z_m",
                "roll_deg",
                "pitch_deg",
                "yaw_deg",
            ],
        )
        writer.writeheader()
        writer.writerows(rows)

    with open(summary_path, "w") as f:
        f.write(f"Trial label: {TRIAL_LABEL}\n")
        f.write(f"Hover height target: {HOVER_HEIGHT_M:.2f} m\n")
        f.write(f"Takeoff voltage: {takeoff_voltage:.3f} V\n")
        f.write(f"Loaded voltage at 10 s: {loaded_voltage_10s:.3f} V\n")
        f.write(f"End voltage: {end_voltage:.3f} V\n")
        f.write(f"Recovered voltage after 60 s: {recovered_voltage:.3f} V\n")
        f.write(f"Flight duration: {flight_duration:.2f} s\n")
        f.write(f"End reason: {end_reason}\n")

    print(f"CSV saved to: {csv_path}")
    print(f"Summary saved to: {summary_path}")
    print("Done.")


if __name__ == "__main__":
    main()