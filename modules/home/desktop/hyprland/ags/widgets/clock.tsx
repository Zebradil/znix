import { Variable } from "astal"

const time = Variable("").poll(1000, `date +"%H:%M %d/%m"`)

export default function ClockWidget() {
    return <label label={time()} />
}
