DEFAULT_PROJECT=deployment-scripts
CURRENT_PROJECT=$(docker compose ls --all --quiet | head -1)
CURRENT_PROJECT=${CURRENT_PROJECT:-$DEFAULT_PROJECT}
PROJECT_NAME=${PROJECT_NAME:-$CURRENT_PROJECT}

# Docker Compose only accepts project names made up of lowercase letters,
# digits, dashes and underscores that begin with a letter or digit. Anything
# else (for example a name containing spaces or uppercase letters) either makes
# the `docker compose --project-name $PROJECT_NAME ...` calls fail outright or
# splits into broken arguments. Reject invalid names here so we never generate a
# broken deployment later on.
project_name_is_valid() {
  [[ "$1" =~ ^[a-z0-9][a-z0-9_-]*$ ]]
}

warn_invalid_project_name() {
  echo >&2 "Invalid project name: '$1'"
  echo >&2 "Project names must consist only of lowercase letters (a-z), digits (0-9),"
  echo >&2 "dashes (-) and underscores (_), and must start with a letter or digit"
  echo >&2 "(no spaces or other characters)."
}

if [[ -z $QUIET_MODE ]];
then
  # Re-prompt until a valid name is entered. Using `while read` means the loop
  # also terminates on EOF (e.g. Ctrl-D) instead of spinning forever, and the
  # final guard below catches any still-invalid value.
  while read -r -p "Confirm project name [${PROJECT_NAME}]: "; do
    # An empty reply keeps the currently proposed name.
    candidate="${REPLY:-$PROJECT_NAME}"
    if project_name_is_valid "$candidate"; then
      PROJECT_NAME="$candidate"
      break
    fi
    warn_invalid_project_name "$candidate"
  done
fi

# Final guard covering every source of the name: quiet mode, a value supplied
# via -n/--name, a value restored from .settings, and the interactive prompt
# hitting EOF. Never proceed with a name Docker Compose will reject.
if ! project_name_is_valid "$PROJECT_NAME"; then
  warn_invalid_project_name "$PROJECT_NAME"
  exit 1
fi

echo "Project name: '$PROJECT_NAME'"
echo ""