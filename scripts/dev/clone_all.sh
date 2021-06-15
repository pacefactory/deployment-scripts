#!/bin/bash

# -------------------------------------------------------------------------
# Prompt to clone all
echo ""
echo "Clone all SCV2 development repositories?"
read -p "([Y]/n) " user_response
case "$user_response" in
  n|N ) echo "  --> Will prompt to clone single repos" ;;
  * ) echo "  --> Cloning all repos"; pull_all=yes ;;
esac

# -------------------------------------------------------------------------
# Prompt to pull scv2_realtime, if not pulling all
scv2_realtime_remote="git@github.com:pacefactory/scv2_realtime.git"
if [ -z ${pull_all+x} ]; then
  echo ""
  echo "Clone scv2_realtime?"
  read -p "(y/[N]) " user_response
  case "$user_response" in
    y|Y ) echo "  --> Will clone scv2_realtime"; clone_scv2_realtime=yes ;;
    * ) clone_scv2_realtime=no ;;
  esac
fi
if [ "$pull_all" = "yes" ] || [ "$clone_scv2_realtime" = "yes" ]; then
  git clone $scv2_realtime_remote
fi

# -------------------------------------------------------------------------
# Prompt to pull scv2_dbserver, if not pulling all
scv2_dbserver_remote="git@github.com:pacefactory/scv2_dbserver.git"
if [ -z ${pull_all+x} ]; then
  echo ""
  echo "Clone scv2_dbserver?"
  read -p "(y/[N]) " user_response
  case "$user_response" in
    y|Y ) echo "  --> Will clone scv2_dbserver"; clone_scv2_dbserver=yes ;;
    * ) clone_scv2_dbserver=no ;;
  esac
fi
if [ "$pull_all" = "yes" ] || [ "$clone_scv2_dbserver" = "yes" ]; then
  git clone $scv2_dbserver_remote
fi

# -------------------------------------------------------------------------
# Prompt to pull scv2_webgui, if not pulling all
scv2_webgui_remote="git@github.com:pacefactory/scv2_webgui.git"
if [ -z ${pull_all+x} ]; then
  echo ""
  echo "Clone scv2_webgui?"
  read -p "(y/[N]) " user_response
  case "$user_response" in
    y|Y ) echo "  --> Will clone scv2_webgui"; clone_scv2_webgui=yes ;;
    * ) clone_scv2_webgui=no ;;
  esac
fi
if [ "$pull_all" = "yes" ] || [ "$clone_scv2_webgui" = "yes" ]; then
  git clone $scv2_webgui_remote
fi

# -------------------------------------------------------------------------
# Prompt to pull scv2_services_dtreeserver, if not pulling all
scv2_services_dtreeserver_remote="git@github.com:pacefactory/scv2_services_dtreeserver.git"
if [ -z ${pull_all+x} ]; then
  echo ""
  echo "Clone scv2_services_dtreeserver?"
  read -p "(y/[N]) " user_response
  case "$user_response" in
    y|Y ) echo "  --> Will clone scv2_services_dtreeserver"; clone_scv2_services_dtreeserver=yes ;;
    * ) clone_scv2_services_dtreeserver=no ;;
  esac
fi
if [ "$pull_all" = "yes" ] || [ "$clone_scv2_services_dtreeserver" = "yes" ]; then
  git clone $scv2_services_dtreeserver_remote
fi

# -------------------------------------------------------------------------
# Prompt to pull scv2_services_gifwrapper, if not pulling all
scv2_services_gifwrapper_remote="git@github.com:pacefactory/scv2_services_gifwrapper.git"
if [ -z ${pull_all+x} ]; then
  echo ""
  echo "Clone scv2_services_gifwrapper?"
  read -p "(y/[N]) " user_response
  case "$user_response" in
    y|Y ) echo "  --> Will clone scv2_services_gifwrapper"; clone_scv2_services_gifwrapper=yes ;;
    * ) clone_scv2_services_gifwrapper=no ;;
  esac
fi
if [ "$pull_all" = "yes" ] || [ "$clone_scv2_services_gifwrapper" = "yes" ]; then
  git clone $scv2_services_gifwrapper_remote
fi

# -------------------------------------------------------------------------
# Prompt to pull social_web_app, if not pulling all
social_web_app_remote="git@github.com:pacefactory/social_web_app.git"
if [ -z ${pull_all+x} ]; then
  echo ""
  echo "Clone social_web_app?"
  read -p "(y/[N]) " user_response
  case "$user_response" in
    y|Y ) echo "  --> Will clone social_web_app"; clone_social_web_app=yes ;;
    * ) clone_social_web_app=no ;;
  esac
fi
if [ "$pull_all" = "yes" ] || [ "$clone_social_web_app" = "yes" ]; then
  git clone $social_web_app_remote
fi

# -------------------------------------------------------------------------
# Prompt to pull social_video_server, if not pulling all
social_video_server_remote="git@github.com:pacefactory/social_video_server.git"
if [ -z ${pull_all+x} ]; then
  echo ""
  echo "Clone social_video_server?"
  read -p "(y/[N]) " user_response
  case "$user_response" in
    y|Y ) echo "  --> Will clone social_video_server"; clone_social_video_server=yes ;;
    * ) clone_social_video_server=no ;;
  esac
fi
if [ "$pull_all" = "yes" ] || [ "$clone_social_video_server" = "yes" ]; then
  git clone $social_video_server_remote
fi

