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


def chown_to_parent(target_path):
    """
    Changes ownership of the target_path (file or folder) to match
    the owner of its parent directory.
    """
    try:
        # 1. Get the path to the parent directory
        path_obj = Path(target_path)
        parent = path_obj.parent

        # 2. Read the UID/GID of the parent folder (which is the mounted host folder)
        stat_info = os.stat(parent)
        parent_uid = stat_info.st_uid
        parent_gid = stat_info.st_gid

        # 3. Apply that UID/GID to the target
        if path_obj.is_dir():
            os.chown(path_obj, parent_uid, parent_gid)
            for root, dirs, files in os.walk(path_obj):
                for d in dirs:
                    os.chown(os.path.join(root, d), parent_uid, parent_gid)
                for f in files:
                    os.chown(os.path.join(root, f), parent_uid, parent_gid)
        else:
            os.chown(path_obj, parent_uid, parent_gid)

        print(f"Ownership fixed to match parent folder (UID {parent_uid})")

    except Exception as e:
        print(f"Warning: Could not change file ownership: {e}")


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

        # Change ownership of recorded files
        chown_to_parent(output_dir)
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
