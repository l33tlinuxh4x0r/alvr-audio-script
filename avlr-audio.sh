#!/usr/bin/env bash

# Backup the default audio devices
function backup() {
  # Backup the default output device
  dsink=$(pactl get-default-sink)
  # Backup the default input device
  dsource=$(pactl get-default-source)
}
# Create virtual devices and set them as default
function create () {
  echo "Creating Audio Output and Routing ALVR to it"
  # Create the virtual audio device
  pactl load-module module-null-sink media.class=Audio/Sink sink_name="ALVR-Sound" channel_map=stereo
  pactl load-module module-combine-sink sink_name="ALVR/default-Dual-Audio" slaves="${dsink}","ALVR-Sound" channels=2
  pactl set-default-sink "ALVR/default-Dual-Audio"
  # Create the virtual audio device
  pactl load-module module-null-sink media.class=Audio/Source/Virtual sink_name=ALVR-Mic channel_map=stereo
}
# Disconnect existing default connections to the stream audio
function purge () {
  echo "Creating Microphone Input and Routing ALVR to it"
  # Grab node IDs for default connections of input
  oiL=$(pw-link -lIi | grep alsa_playback.vrserver:output_FL | cut -d'|' -f1)
  oiR=$(pw-link -lIi | grep alsa_playback.vrserver:output_FR | cut -d'|' -f1)
  siL=$(pw-link -lIo | grep alsa_playback.vrserver:output_FL | cut -d'a' -f1)
  siR=$(pw-link -lIo | grep alsa_playback.vrserver:output_FR | cut -d'a' -f1)
  # Use those IDs to break the conections
  pw-link -d "${oiL} ${siL}"
  pw-link -d "${oiR} ${siR}"
  # Grab node IDs for default connections of output
  ooL=$(pw-link -lIo | grep alsa_capture.vrserver:input_FL | cut -d'|' -f1)
  ooR=$(pw-link -lIo | grep alsa_capture.vrserver:input_FR | cut -d'|' -f1)
  soL=$(pw-link -lIi | grep alsa_capture.vrserver:input_FL | cut -d'a' -f1)
  soR=$(pw-link -lIi | grep alsa_capture.vrserver:input_FR | cut -d'a' -f1)
  # Use those IDs to break the conections
  pw-link -d "${ooL} ${soL}"
  pw-link -d "${ooR} ${soR}"
}
# Tying the virtual devices together with the stream audio
function connect () {
  # Link the virtual device to the ALVR output
  pw-link ALVR:monitor_FL alsa_capture.vrserver:input_FL
  pw-link ALVR:monitor_FR alsa_capture.vrserver:input_FR
  # Link ALVR's input to the virtual device
  pw-link alsa_playback.vrserver:output_FL ALVR-Mic:input_FL
  pw-link alsa_playback.vrserver:output_FR ALVR-Mic:input_FR
  # Switch to VR headset mic when headset is put on.
  pactl set-default-source ALVR-Mic
}
# Restores default settings when disconnecting.
function restore () {
  # Restore the default output device
  pactl set-default-sink ${dsink}
  # Restore the default input device
  pactl set-default-source ${dsource}
}
# Remove created devices.
function aud_off () {
  pactl unload-module module-null-sink
  pactl unload-module module-combine-sink
}

case $ACTION in
connect)
  sleep 0.1
  backup
  sleep 0.1
  create
  purge
  sleep 0.1
  connect
  ;;
disconnect)
  sleep 0.1
  restore
  sleep 0.1
  aud_off
  ;;
esac
