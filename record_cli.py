import os
from pathlib import Path
import sys
import re
import subprocess
import datetime

# Import your existing library functions
# We assume the container WORKDIR allows these imports, or we append path
sys.path.append(
    "/home/scv2/realtime"
)  # Adjust if your container source root is different
sys.path.append(os.getcwd())

from local.lib.file_access_utils.rtsp import load_rtsp_config

LOCATIONS_ROOT = "/home/scv2/locations"
OUTPUT_ROOT = "/output_videos"


def make_writable_by_all(target_path):
    """
    Sets permissions to 777 for directories and 666 for files.
    This ensures the host user can delete/edit them, even if owned by root.
    """
    try:
        path_obj = Path(target_path)

        # Helper to set permissions safely
        def set_perms(p):
            if p.is_dir():
                # 0o777 = rwxrwxrwx (Execute is required to open a folder)
                os.chmod(p, 0o777)
            else:
                # 0o666 = rw-rw-rw- (Read/Write for everyone)
                os.chmod(p, 0o666)

        # 1. Apply to the target itself
        set_perms(path_obj)

        # 2. If it's a directory, apply recursively to everything inside
        if path_obj.is_dir():
            for root, dirs, files in os.walk(path_obj):
                for d in dirs:
                    set_perms(Path(root) / d)
                for f in files:
                    set_perms(Path(root) / f)

        print(f"Permissions set to world-writable for: {target_path}")

    except Exception as e:
        print(f"Warning: Could not change permissions: {e}")


def parse_duration(duration_str):
    """Parses shorthands like '1m', '24h', '2.5d' into seconds."""
    if str(duration_str).isdigit():
        return int(duration_str)

    units = {"s": 1, "m": 60, "h": 3600, "d": 86400}
    pattern = re.compile(r"^(\d*\.?\d+)([smhd])$")
    match = pattern.match(duration_str)

    if match:
        value, unit = match.groups()
        return int(float(value) * units[unit])

    raise ValueError(f"Invalid duration format: {duration_str}")


def find_camera_location(camera_id):
    """
    Searches the realtime-data volume for the camera ID to determine
    its location parent folder.
    """
    for root, dirs, files in os.walk(LOCATIONS_ROOT):
        if camera_id in dirs:
            return root
    return None


def run_recording(camera_id, duration_str):
    print(f"--- Starting Record Tool for Camera: {camera_id} ---")

    # 1. Resolve Pathing
    location_path = find_camera_location(camera_id)
    if not location_path:
        print(f"Error: Camera '{camera_id}' not found in {LOCATIONS_ROOT}")
        sys.exit(1)

    print(f"Found camera in location: {location_path}")

    # 2. Load RTSP Config (using your existing functions)
    try:
        # load_rtsp_config returns (config_dict, rtsp_string)
        _, rtsp_url = load_rtsp_config(location_path, camera_id)
        if not rtsp_url or "rtsp://" not in rtsp_url:
            print("Error: Could not construct valid RTSP URL (Missing config?)")
            sys.exit(1)
    except Exception as e:
        print(f"Error loading RTSP config: {e}")
        sys.exit(1)

    # 3. Calculate Duration
    try:
        duration_sec = parse_duration(duration_str)
        print(f"Recording duration: {duration_sec} seconds")
    except ValueError as e:
        print(str(e))
        sys.exit(1)

    # 4. Setup Output Directory
    # Schema: ~/scv2/videos/<current_date>/<camera_id>/
    today_str = datetime.date.today().strftime("%Y-%m-%d")
    output_dir = os.path.join(OUTPUT_ROOT, today_str, camera_id)
    os.makedirs(output_dir, exist_ok=True)

    file_prefix = f"{camera_id}-%Y-%m-%d_%H-%M-%S.mkv"
    output_pattern = os.path.join(output_dir, file_prefix)

    # 5. Build FFmpeg Command
    # Note: We run ffmpeg DIRECTLY here, not via docker run, because
    # we are already inside a container.
    cmd = [
        "ffmpeg",
        "-y",  # Overwrite if exists (though segmenting usually prevents this)
        "-stats",
        "-rtsp_transport",
        "tcp",
        "-fflags",
        "+genpts+igndts",
        "-i",
        rtsp_url,
        "-codec",
        "copy",
        "-an",  # No audio
        "-map",
        "0:v",
        "-f",
        "segment",
        "-segment_time",
        "900",
        "-segment_format",
        "mkv",
        "-segment_atclocktime",
        "1",
        "-reset_timestamps",
        "1",
        "-strftime",
        "1",
        "-t",
        str(duration_sec),
        output_pattern,
    ]

    print(f"Executing: {' '.join(cmd)}")
    print("--- Recording Started (Press Ctrl+C to stop early) ---")

    try:
        subprocess.run(cmd, check=True)
        print("\nRecording Complete.")

        # Change permissions of recorded files
        make_writable_by_all(output_dir)
    except subprocess.CalledProcessError:
        print("\nFFmpeg encountered an error.")
        sys.exit(1)
    except KeyboardInterrupt:
        print("\nRecording stopped by user.")
        sys.exit(0)


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python record_cli.py <camera_id> <duration>")
        sys.exit(1)

    run_recording(sys.argv[1], sys.argv[2])
