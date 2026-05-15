import { bind } from "astal"
import Tray from "gi://AstalTray"

const tray = Tray.get_default()

export default function TrayWidget() {
    const items = bind(tray, "items")

    return (
        <box className="tray">
            {items.as((entries: any[]) =>
                entries.map((item) => (
                    <menubutton usePopover={false} menuModel={item.menuModel} tooltipMarkup={bind(item, "tooltipMarkup")}>
                        <icon gicon={bind(item, "gicon")} />
                    </menubutton>
                ))
            )}
        </box>
    )
}
