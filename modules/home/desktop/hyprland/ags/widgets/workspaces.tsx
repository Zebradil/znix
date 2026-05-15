import { bind } from "astal"
import Hyprland from "gi://AstalHyprland"

const hyprland = Hyprland.get_default()

export default function Workspaces() {
    const workspaces = bind(hyprland, "workspaces")
    const focused = bind(hyprland, "focusedWorkspace")

    return (
        <box>
            {workspaces.as((items: any[]) =>
                items
                    .filter((ws) => ws.id > 0)
                    .sort((a, b) => a.id - b.id)
                    .map((ws) => (
                        <button
                            className={focused.as((current: any) => current?.id === ws.id ? "active" : "")}
                            onClicked={() => hyprland.dispatch("workspace", `${ws.id}`)}
                            label={`${ws.id}`}
                        />
                    ))
            )}
        </box>
    )
}
