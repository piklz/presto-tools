#!/usr/bin/env python3
import subprocess
import sys
import os
from datetime import datetime

# --- Configuration ---
LOG_DIR = f"/home/{os.environ['USER']}/presto/logs/"
RETRY_LIMIT = 3
BAR_LENGTH = 40

# Task steps with messages and emojis
TASKS = [
    {"command": "docker compose down", "message": "Stopping containers... ⏹️"},
    {"command": "docker compose pull", "message": "Pulling Docker images... ⬇️"},
    {"command": "docker compose build", "message": "Building Docker images... 🛠️"},
    {"command": "docker compose up -d --remove-orphans", "message": "Starting containers... 🟢"},
    {"command": "docker image prune -a -f", "message": "Pruning unused images... 🗑️"}
]

# Create logs directory
os.makedirs(LOG_DIR, exist_ok=True)
log_file = os.path.join(LOG_DIR, f"docker_update_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log")

# --- Utility Functions ---
def log_and_print(message, color_code=None):
    """Log messages to both console and log file."""
    if color_code:
        message = f"\033[{color_code}m{message}\033[0m"
    print(message)
    with open(log_file, "a") as log:
        log.write(message + "\n")

def progress_bar(current, total):
    progress = int(BAR_LENGTH * current / total)
    bar = "█" * progress + "-" * (BAR_LENGTH - progress)
    sys.stdout.write(f"\r|{bar}| {current}/{total} tasks completed")
    sys.stdout.flush()

# --- Change Directory and Check User ---
try:
    current_user = os.environ['USER']
    log_and_print(f"Current user: {current_user}")
    os.chdir(f"/home/{current_user}/presto/scripts/")
except KeyError:
    log_and_print("Error: USER environment variable not set.")
    sys.exit(1)
except FileNotFoundError:
    log_and_print("Error: Directory '/home/{current_user}/presto/scripts/' does not exist.")
    sys.exit(1)

def run_command_with_retries(cmd, capture_output=False):
    """Run a shell command with retries."""
    for attempt in range(1, RETRY_LIMIT + 1):
        log_and_print(f"\nAttempt {attempt}/{RETRY_LIMIT}: {cmd}", color_code="36")
        process = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, universal_newlines=True)

        captured_output = [] if capture_output else None
        while True:
            output = process.stdout.readline()
            if not output and process.poll() is not None:
                break
            if output.strip():
                log_and_print(output.strip())
                if capture_output:
                    captured_output.append(output.strip())

        if process.returncode == 0:
            log_and_print(f"✅ Command succeeded", color_code="32")
            return True, "\n".join(captured_output) if capture_output else True
        log_and_print("⚠️ Command failed. Retrying...", color_code="33")

    log_and_print("❌ Command failed after all retries", color_code="31")
    return False, None if capture_output else False

# --- Main Execution ---
try:
    log_and_print("\n[PRESTO] Starting Docker update tasks...\n", color_code="34")
    log_and_print("=" * 50, color_code="34")

    total_tasks = len(TASKS)
    completed_tasks = 0
    prune_output = ""

    for i, task in enumerate(TASKS, start=1):
        log_and_print(f"\nTask {i}/{total_tasks}: {task['message']}", color_code="36")
        progress_bar(i - 1, total_tasks)  # Update progress bar for the previous step

        if "docker image prune" in task["command"]:
            success, output = run_command_with_retries(task["command"], capture_output=True)
            if success:
                prune_output = output
        else:
            if not run_command_with_retries(task["command"]):
                sys.exit(1)

        completed_tasks += 1
        progress_bar(completed_tasks, total_tasks)  # Update progress bar for the current step

    log_and_print("\n\n✅ All Docker tasks completed successfully!", color_code="32")
    log_and_print("=" * 50, color_code="34")

finally:
    pass

# --- Final Log and Summary ---
log_and_print(f"\nLogs saved to: {log_file}", color_code="36")
log_and_print("\nSummary:", color_code="34")
if prune_output:
    log_and_print(f"✅ {prune_output}", color_code="33")
else:
    log_and_print("✅ Total reclaimed space: 0B", color_code="33")

log_and_print("\nScript finished. 🚀", color_code="32")
