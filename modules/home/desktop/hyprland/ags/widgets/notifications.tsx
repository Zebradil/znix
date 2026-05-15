import { bind } from "astal"
import Gtk from "gi://Gtk?version=3.0"
import Notifd from "gi://AstalNotifd"

const notifd = Notifd.get_default()

function NotificationItem(item: any) {
    return (
        <box className="notification-item" vertical>
            <box>
                <label
                    className="notification-title"
                    hexpand
                    xalign={0}
                    wrap
                    label={item.summary ?? item.appName ?? "Notification"}
                />
                <button className="notification-dismiss" onClicked={() => item.dismiss()} label="󰅖" />
            </box>
            {item.body ? (
                <label
                    className="notification-body"
                    xalign={0}
                    wrap
                    label={item.body}
                />
            ) : null}
        </box>
    )
}

export default function NotificationsWidget() {
    const notifications = bind(notifd, "notifications")
    const popover = new Gtk.Popover({
        position: Gtk.PositionType.BOTTOM,
    })

    popover.add(
        <box className="notifications-popover" vertical>
            <box className="notifications-popover-header">
                <label hexpand xalign={0} label="Notifications" />
                <button
                    className="notification-clear"
                    onClicked={() => notifications.get().forEach((item: any) => item.dismiss())}
                    label="Clear"
                />
            </box>
            <box className="notifications-list" vertical>
                {notifications.as((items: any[]) =>
                    items.length > 0
                        ? items.map((item) => NotificationItem(item))
                        : [<label className="notifications-empty" xalign={0} label="No notifications" />]
                )}
            </box>
        </box>
    )
    popover.show_all()

    return (
        <box className="notifications">
            <menubutton
                popover={popover}
                tooltipMarkup={notifications.as((items: any[]) => {
                    if (items.length === 0) return "No notifications"
                    return items.map((item) => item.summary ?? "Notification").join("\n")
                })}
            >
                <label label={notifications.as((items: any[]) => items.length > 0 ? `󰂚 ${items.length}` : "󰂜") } />
            </menubutton>
        </box>
    )
}
