import { bind } from "astal"
import Battery from "gi://AstalBattery"

const battery = Battery.get_default()

export default function BatteryWidget() {
    const percentage = bind(battery, "percentage")
    const charging = bind(battery, "charging")

    return (
        <box>
            <label label={percentage.as((value: number) => {
                const pct = Math.round((value ?? 0) * 100)
                return `${charging.get() ? "󰂄" : "󰁹"} ${pct}%`
            })} />
        </box>
    )
}
