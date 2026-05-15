import { bind } from "astal"
import Wp from "gi://AstalWp"

const wp = Wp.get_default()

export default function AudioWidget() {
    const speaker = bind(wp, "defaultSpeaker")

    return (
        <box className="audio">
            <button onClicked="pavucontrol">
                <label label={speaker.as((sp: any) => {
                    if (!sp) return "󰖁"
                    if (sp.mute) return "󰸈 muted"
                    return `󰕾 ${Math.round((sp.volume ?? 0) * 100)}%`
                })} />
            </button>
        </box>
    )
}
