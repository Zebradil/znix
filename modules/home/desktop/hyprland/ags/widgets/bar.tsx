import { App, Astal, Gdk, Gtk } from "astal/gtk3"
import Workspaces from "./workspaces"
import TrayWidget from "./tray"
import AudioWidget from "./audio"
import NetworkWidget from "./network"
import BatteryWidget from "./battery"
import BluetoothWidget from "./bluetooth"
import ClockWidget from "./clock"
import NotificationsWidget from "./notifications"

export default function Bar(gdkmonitor: Gdk.Monitor) {
    const { TOP, LEFT, RIGHT } = Astal.WindowAnchor

    return (
        <window
            className="Bar"
            name={`Bar-${gdkmonitor.get_model() ?? "monitor"}`}
            gdkmonitor={gdkmonitor}
            exclusivity={Astal.Exclusivity.EXCLUSIVE}
            anchor={TOP | LEFT | RIGHT}
            application={App}
            visible
        >
            <centerbox>
                <box className="segment workspaces" hexpand halign={Gtk.Align.START}>
                    <Workspaces />
                </box>

                <box className="segment" hexpand halign={Gtk.Align.CENTER} />

                <box className="segment" halign={Gtk.Align.END}>
                    <TrayWidget />
                    <NetworkWidget />
                    <BluetoothWidget />
                    <BatteryWidget />
                    <AudioWidget />
                    <ClockWidget />
                    <NotificationsWidget />
                </box>
            </centerbox>
        </window>
    )
}
