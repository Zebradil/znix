import Gio from "gi://Gio?version=2.0"

export type Theme = {
    radius: number
    margin: number
    barHeight: number
    font: {
        name: string
        size: number
    }
    colors: Record<string, string>
}

export function loadTheme(): Theme {
    const file = Gio.File.new_for_path(`${SRC}/theme.json`)
    const [, bytes] = file.load_contents(null)
    return JSON.parse(new TextDecoder().decode(bytes)) as Theme
}

export const theme = loadTheme()
