import { bind } from "astal"
import Network from "gi://AstalNetwork"

const network = Network.get_default()

export default function NetworkWidget() {
    const primary = bind(network, "primary")
    const wifi = bind(network, "wifi")
    const wired = bind(network, "wired")

    return (
        <box>
            <label label={primary.as((kind: string) => {
                if (kind === "wifi") {
                    const accessPoint = wifi.get()?.accessPoint
                    const strength = accessPoint?.strength ?? 0
                    return `󰖩 ${strength}%`
                }
                if (kind === "wired") {
                    return wired.get()?.internet === "connected" ? "󰈀" : "󰈀 down"
                }
                return "󰖪"
            })} />
        </box>
    )
}
