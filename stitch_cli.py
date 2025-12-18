import os
import sys
import argparse
import subprocess
import shutil
from pathlib import Path

# The internal mount point for videos
INTERNAL_VIDEO_ROOT = Path("/output_videos")


def make_writable_by_all(target_path):
    """
    Sets permissions to 777 for directories and 666 for files.
    """
    try:
        path_obj = Path(target_path)

        def set_perms(p):
            if p.is_dir():
                os.chmod(p, 0o777)
            else:
                os.chmod(p, 0o666)

        set_perms(path_obj)
        if path_obj.is_dir():
            for root, dirs, files in os.walk(path_obj):
                for d in dirs:
                    set_perms(Path(root) / d)
                for f in files:
                    set_perms(Path(root) / f)
    except Exception as e:
        print(f"Warning: Could not change permissions: {e}")


def get_target_directory(user_arg):
    clean_arg = user_arg.rstrip("/\\")
    folder_name = os.path.basename(clean_arg)
    target_path = INTERNAL_VIDEO_ROOT / folder_name

    if not target_path.exists():
        print(f"Error: Directory not found inside container: {target_path}")
        sys.exit(1)

    return target_path


def stitch_camera_videos(date_dir, delete_source=True):
    date_string = date_dir.name
    print(f"--- Processing Date: {date_string} ---")
    if delete_source:
        print("--- Mode: Source files will be DELETED after success ---")
    else:
        print("--- Mode: Source files will be KEPT ---")

    # Iterate over every camera folder in the date directory
    for cam_dir in date_dir.iterdir():
        if not cam_dir.is_dir():
            continue

        camera_id = cam_dir.name
        print(f"\nFound Camera: {camera_id}")

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
                f.write(f"file '{video.name}'\n")

        # 2. Define Output Filename: <camera_id>-<date>.mp4
        output_filename = f"{camera_id}-{date_string}.mp4"
        output_path = date_dir / output_filename

        print(f"  Stitching {len(video_files)} clips into: {output_filename}")

        # 3. Run FFmpeg
        cmd = [
            "ffmpeg",
            "-hide_banner",
            "-loglevel",
            "warning",
            "-y",
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
            print("  [SUCCESS] Stitching complete.")

            # Make the output file usable by host user
            make_writable_by_all(date_dir)

            # 4. Handle Deletion (Only on success)
            if delete_source:
                print(f"  [CLEANUP] Deleting source directory: {cam_dir.name}")
                try:
                    shutil.rmtree(cam_dir)
                except OSError as e:
                    print(f"  [ERROR] Failed to delete directory: {e}")

        except subprocess.CalledProcessError as e:
            print(f"  [FAILED] FFmpeg error: {e}")
            print("  [SAFETY] Source files kept due to error.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Stitch camera clips into single videos."
    )

    # Positional argument: The date or path
    parser.add_argument(
        "target", help="The date string (YYYY-MM-DD) or full path to process"
    )

    # Optional flag: If present, DISABLES deletion
    parser.add_argument(
        "--keep-source",
        action="store_true",
        help="Do not delete source files after stitching",
    )

    args = parser.parse_args()

    target_dir = get_target_directory(args.target)

    # Pass the inverse of the flag (flag=True means Keep=True means Delete=False)
    stitch_camera_videos(target_dir, delete_source=not args.keep_source)
