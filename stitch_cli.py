import os
import sys
import subprocess
from pathlib import Path

# The internal mount point for videos (must match docker-compose)
INTERNAL_VIDEO_ROOT = Path("/output_videos")


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


def get_target_directory(user_arg):
    """
    Determines the directory to process based on user input.
    Accepts full paths like '/home/user/videos/2025-12-18' or just '2025-12-18'.
    """
    # 1. Clean up the input (remove trailing slashes)
    clean_arg = user_arg.rstrip("/\\")

    # 2. Extract the folder name (e.g., "2025-12-18")
    folder_name = os.path.basename(clean_arg)

    # 3. Construct the internal path
    target_path = INTERNAL_VIDEO_ROOT / folder_name

    if not target_path.exists():
        print(f"Error: Directory not found inside container: {target_path}")
        print(f"Checked for folder '{folder_name}' in '{INTERNAL_VIDEO_ROOT}'")
        sys.exit(1)

    return target_path


def stitch_camera_videos(date_dir):
    date_string = date_dir.name
    print(f"--- Processing Date: {date_string} ---")

    # Iterate over every item in the date directory
    for cam_dir in date_dir.iterdir():
        if not cam_dir.is_dir():
            continue

        camera_id = cam_dir.name
        print(f"\nFound Camera: {camera_id}")

        # specific video extensions to look for
        video_files = sorted(
            [
                f
                for f in cam_dir.iterdir()
                if f.is_file() and f.suffix.lower() in [".mp4", ".mkv"]
            ]
        )

        if not video_files:
            print("  No video files found, skipping.")
            continue

        # 1. Create files.txt for ffmpeg
        list_file_path = cam_dir / "files.txt"
        with open(list_file_path, "w") as f:
            for video in video_files:
                # ffmpeg requires 'file ' prefix and safe escaping
                # We use just the filename since files.txt is in the same dir
                f.write(f"file '{video.name}'\n")

        # 2. Define Output Filename: <camera_id>-<date>.mp4
        # Saved in the Date directory (parent of camera dir)
        output_filename = f"{camera_id}-{date_string}.mp4"
        output_path = date_dir / output_filename

        print(f"  Stitching {len(video_files)} clips into: {output_filename}")

        # 3. Run FFmpeg
        cmd = [
            "ffmpeg",
            "-hide_banner",
            "-loglevel",
            "warning",
            "-y",  # Overwrite output
            "-f",
            "concat",
            "-safe",
            "0",
            "-i",
            str(list_file_path),
            "-c",
            "copy",
            str(output_path),
        ]

        try:
            subprocess.run(cmd, check=True)
            print("  [SUCCESS]")

            chown_to_parent(output_path)
        except subprocess.CalledProcessError as e:
            print(f"  [FAILED] FFmpeg error: {e}")

        # Optional: cleanup files.txt
        if list_file_path.exists():
            os.remove(list_file_path)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python stitch_cli.py <path_to_date_folder_or_date_string>")
        sys.exit(1)

    target_dir = get_target_directory(sys.argv[1])
    stitch_camera_videos(target_dir)
