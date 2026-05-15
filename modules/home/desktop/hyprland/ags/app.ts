import { App, Gdk } from "astal/gtk3"
import style from "./style.scss"
import Bar from "./widgets/bar"

App.start({
    css: style,
    instanceName: "znix-shell",
    main() {
        App.get_monitors().forEach((monitor: Gdk.Monitor) => {
            Bar(monitor)
        })
    },
})
