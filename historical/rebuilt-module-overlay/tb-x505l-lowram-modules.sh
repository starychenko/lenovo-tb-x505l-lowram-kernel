#!/system/bin/sh

case "$(cat /proc/version 2>/dev/null)" in
    *codex-lowram@tb-x505l*) ;;
    *) exit 0 ;;
esac

module_source=/system/lib/modules-lowram
module_target=/vendor/lib/modules

if grep -q '^q6_dlkm ' /proc/modules &&
        grep -q '^platform_dlkm ' /proc/modules &&
        grep -q '^machine_dlkm ' /proc/modules; then
    echo "codex-lowram: Lenovo early-init modules already active" > /dev/kmsg
    exit 0
fi

if grep -Eq '^(q6_dlkm|platform_dlkm|machine_dlkm) ' /proc/modules; then
    echo "codex-lowram: partial Lenovo module set; refusing mixed ABI" > /dev/kmsg
    exit 1
fi

if [ ! -r "$module_source/modules.dep" ] || [ ! -r "$module_source/pronto_wlan.ko" ]; then
    echo "codex-lowram: replacement module set is incomplete" > /dev/kmsg
    exit 1
fi

if ! grep -q " $module_target " /proc/mounts; then
    mount "$module_source" "$module_target" || exit 1
fi

/vendor/bin/modprobe -a -d "$module_target" \
    audio_apr audio_adsp_loader audio_q6_notifier audio_q6 audio_usf \
    audio_native audio_pinctrl_wcd audio_swr audio_platform \
    audio_swr_ctrl audio_hdmi audio_wcd9xxx audio_wcd_core \
    audio_wsa881x_analog audio_wsa881x audio_mbhc audio_stub \
    audio_digital_cdc audio_analog_cdc audio_wcd_cpe audio_cpe_lsm \
    audio_wcd9335 audio_machine_sdm450 audio_machine_ext_sdm450 || exit 1

/vendor/bin/modprobe -d "$module_target" pronto_wlan || exit 1
echo "codex-lowram: replacement modules loaded" > /dev/kmsg
