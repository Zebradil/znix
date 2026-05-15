import { bind } from "astal"
import Bluetooth from "gi://AstalBluetooth"

const bluetooth = Bluetooth.get_default()

function connectedSummary(devices: any[]) {
    const connected = devices.filter((device) => device.connected)
    if (connected.length === 0) {
        return "Bluetooth on"
    }

    return connected.map((device) => device.name ?? device.alias ?? "device").join(", ")
}

export default function BluetoothWidget() {
    const adapters = bind(bluetooth, "adapters")
    const devices = bind(bluetooth, "devices")

    return (
        <box className="bluetooth">
            <button onClicked="blueman-manager">
                <label label={adapters.as((list: any[]) => {
                    const adapter = list[0]
                    if (!adapter) return "󰂲"
                    if (!adapter.powered) return "󰂲"
                    return "󰂯"
                })} />
            </button>
            <label
                maxWidthChars={24}
                truncate
                label={devices.as((list: any[]) => connectedSummary(list))}
            />
        </box>
    )
}
