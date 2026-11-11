import { useEffect, useState } from 'react'
import { Icon } from './ui'
import { formatDuration } from '../data'

const MAX_SECONDS = 600
// Heights and tones copied from the Figma waveform (21 bars)
const bars: [number, boolean][] = [
  [16, true], [28, false], [48, false], [24, true], [64, false], [80, false], [44, true], [72, false], [96, false], [60, true], [36, false],
  [68, false], [84, true], [48, false], [24, false], [56, true], [40, false], [72, false], [32, true], [16, false], [40, false],
]

export function RecordingScreen({ onCancel, onFinish }: { onCancel: () => void; onFinish: (seconds: number) => void }) {
  const [seconds, setSeconds] = useState(0)

  useEffect(() => {
    const id = setInterval(() => setSeconds((s) => s + 1), 1000)
    return () => clearInterval(id)
  }, [])

  useEffect(() => {
    if (seconds >= MAX_SECONDS) onFinish(seconds)
  }, [seconds, onFinish])

  return (
    <div className="flex h-full flex-col">
      <header className="shrink-0 px-4 pt-6">
        <h1 className="text-lg font-semibold leading-7 text-ink">Rekaman baru</h1>
      </header>

      <main className="flex flex-1 flex-col items-center justify-center gap-4 px-12">
        <div className="flex items-center gap-3">
          <span className="animate-pulse-dot size-3 rounded-md bg-rec" />
          <span className="text-base font-medium leading-6 text-[#b91c1c]">Merekam</span>
        </div>
        <p className="text-5xl font-semibold leading-[64px] tabular-nums text-ink" role="timer" aria-live="off">
          {formatDuration(seconds)}
        </p>
        <div className="mt-6 flex h-24 w-full max-w-[294px] items-center justify-between" aria-hidden>
          {bars.map(([h, light], i) => (
            <span
              key={i}
              className="animate-wave w-1.5 rounded-[3px]"
              style={{ height: h, background: light ? '#f4a3a6' : '#e5484d', animationDelay: `${(i % 7) * -0.15}s` }}
            />
          ))}
        </div>
        <p className="text-[13px] font-medium leading-[18px] text-muted">Maks 10 menit</p>
      </main>

      <footer className="shrink-0 px-6 pb-12 pt-4">
        <p className="mb-[62px] text-center text-[13px] font-medium leading-[18px] text-muted">Jaga layar tetap menyala saat merekam</p>
        <div className="flex gap-3">
          <button
            type="button"
            onClick={onCancel}
            className="h-14 w-[108px] shrink-0 rounded-xl border border-line bg-white text-base font-semibold text-ink active:bg-slate-50"
          >
            Batal
          </button>
          <button
            type="button"
            onClick={() => onFinish(seconds)}
            className="flex h-14 flex-1 items-center justify-center gap-2.5 rounded-xl bg-[#dc2626] text-base font-semibold text-white active:bg-[#b91c1c]"
          >
            <Icon name="8808d" size={20} />
            Selesai
          </button>
        </div>
      </footer>
    </div>
  )
}
