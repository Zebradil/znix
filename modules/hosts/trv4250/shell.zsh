# vim: ft=zsh ts=2 sw=2 sts=2 et

ulimit -n 65536

INTERNAL_DISPLAY="37D8832A-2D66-02CA-B9F7-8F30A301B230"
MAIN_OFFICE_DISPLAY="904A995C-F1BF-4FC7-924D-629759BBA296"
SIDE_OFFICE_DISPLAY="71AB5EEF-B5C2-41AC-B0F7-81805E3BCB11"
MAIN_HOME_DISPLAY="625F7E94-0A87-4C4E-8805-47EC3E575FB0"

function z:display:office:one {
  displayplacer \
    "id:$MAIN_OFFICE_DISPLAY+$INTERNAL_DISPLAY res:2560x1440 hz:60 color_depth:8 enabled:true scaling:on origin:(0,0) degree:0"
  brightness 0
}

function z:display:office:two {
  displayplacer \
    "id:$MAIN_OFFICE_DISPLAY+$INTERNAL_DISPLAY res:2560x1440 hz:60 color_depth:8 enabled:true scaling:on origin:(0,0) degree:0" \
    "id:$SIDE_OFFICE_DISPLAY res:1080x1920 hz:60 color_depth:8 enabled:true scaling:on origin:(-1080,-194) degree:270"
  brightness 0
}

function z:display:office:three {
  displayplacer \
    "id:$MAIN_OFFICE_DISPLAY res:2560x1440 hz:60 color_depth:8 enabled:true scaling:on origin:(0,0) degree:0" \
    "id:$INTERNAL_DISPLAY res:1512x982 hz:120 color_depth:8 enabled:true scaling:on origin:(506,1440) degree:0" \
    "id:$SIDE_OFFICE_DISPLAY res:1080x1920 hz:60 color_depth:8 enabled:true scaling:on origin:(-1080,-194) degree:270"
  brightness 0.5
}

function z:display:home:one {
  displayplacer \
    "id:$MAIN_HOME_DISPLAY+$INTERNAL_DISPLAY res:2560x1440 hz:144 color_depth:8 enabled:true scaling:on origin:(0,0) degree:0"
  brightness 0
}

function z:display:home:two {
  displayplacer \
    "id:$MAIN_HOME_DISPLAY res:2560x1440 hz:144 color_depth:8 enabled:true scaling:on origin:(0,0) degree:0" \
    "id:$INTERNAL_DISPLAY res:1512x982 hz:120 color_depth:8 enabled:true scaling:on origin:(2560,1039) degree:0"
  brightness 0.5
}

# Remote Docker Host in GCP
GCPD_ZONE=europe-west4-b
GCPD_PROJECT=trv-shared-github-runners
GCPD_INSTANCE=glashevich-docker-builder-150
GCPD_HOST="$GCPD_INSTANCE.$GCPD_ZONE.$GCPD_PROJECT"

function z:docker:remote:up {
  export DOCKER_HOST="ssh://$GCPD_HOST"
  if ! ssh -o ConnectTimeout=2 "$GCPD_HOST" exit; then
    gcloud compute instances start \
      --zone "$GCPD_ZONE" \
      --project "$GCPD_PROJECT" \
      "$GCPD_INSTANCE"
  fi
  ssh "$GCPD_HOST" 'sudo usermod -a -G docker $USER'
}

function z:docker:remote:down {
  unset DOCKER_HOST
  gcloud compute instances stop \
    --zone "$GCPD_ZONE" \
    --project "$GCPD_PROJECT" \
    "$GCPD_INSTANCE"
}

function trv-claude {
  ANTHROPIC_API_KEY=$(op read 'op://Employee/Anthropic API key/credential') \
  CLAUDE_CONFIG_DIR=~/.config/trv-claude \
  claude "$@"
}
