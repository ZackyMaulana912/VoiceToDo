import { useState } from 'react'
import { CategoryChip, FailedCard, ProcessingCard, ResultCard, StatusChip } from './ui'
import type { Rec, Todo } from '../data'

export function HistoryScreen({ recs, onOpen }: { recs: Rec[]; onOpen: (id: string) => void }) {
  return (
    <div className="flex h-full flex-col">
      <header className="shrink-0 px-4 pt-6">
        <h1 className="text-2xl font-semibold leading-8 text-ink">Voice-to-Todo</h1>
        <h2 className="mt-10 text-2xl font-semibold leading-8 text-ink">Riwayat</h2>
        <p className="text-base leading-6 text-muted">Rekamanmu, sudah dirapikan.</p>
      </header>
      <ul className="mt-6 flex flex-1 flex-col gap-3 overflow-y-auto px-4 pb-4">
        {recs.map((r) => (
          <li key={r.id} className="animate-fade-up">
            <button
              type="button"
              onClick={() => onOpen(r.id)}
              className="block w-full rounded-xl border border-line bg-white px-[15px] pb-[7px] pt-[11px] text-left transition-colors hover:border-[#cbd5e1] active:bg-slate-50"
            >
              <p className="text-[13px] font-medium leading-[18px] text-muted">{r.date}</p>
              <p className="mt-1.5 text-base font-semibold leading-6 text-ink">{r.title}</p>
              <p className="mt-1 truncate text-[13px] font-medium leading-[18px] text-muted">
                {r.status === 'memproses' ? `Merangkum rekaman ${r.duration}...` : r.status === 'gagal' ? 'Rekamanmu aman tersimpan.' : r.summary.split('. ')[0]}
              </p>
              <div className="mt-2.5 flex items-center gap-2">
                <CategoryChip cat={r.cat} />
                <StatusChip status={r.status} />
                <span className="ml-auto text-[13px] font-medium leading-[18px] text-muted">
                  {r.status === 'selesai' ? `${r.todoIds.length} to-do · ${r.duration}` : r.duration}
                </span>
              </div>
            </button>
          </li>
        ))}
      </ul>
    </div>
  )
}

export function DetailScreen({
  rec,
  todos,
  onBack,
  onToggle,
  onSummary,
  onRetry,
}: {
  rec: Rec
  todos: Todo[]
  onBack: () => void
  onToggle: (id: string) => void
  onSummary: (text: string) => void
  onRetry: () => void
}) {
  const [open, setOpen] = useState(false)
  return (
    <div className="flex h-full flex-col">
      <header className="shrink-0 px-4 pt-3">
        <button type="button" onClick={onBack} className="-ml-1 flex h-12 items-center px-1 text-base font-medium text-brand">
          <span aria-hidden className="whitespace-pre">{'‹  '}</span>Riwayat
        </button>
        <h1 className="mt-5 text-2xl font-semibold leading-8 text-ink">{rec.title}</h1>
        <p className="mt-2 text-[13px] font-medium leading-[18px] text-muted">
          {rec.date} · {rec.duration}
        </p>
      </header>
      <div className="mt-5 flex-1 space-y-4 overflow-y-auto px-4 pb-6">
        {rec.status === 'selesai' && (
          <>
            <ResultCard rec={rec} todos={todos} onToggle={onToggle} onSummary={onSummary} />
            <div className="rounded-xl border border-line bg-white">
              <button
                type="button"
                aria-expanded={open}
                onClick={() => setOpen((v) => !v)}
                className="flex h-14 w-full items-center justify-between px-[15px] text-base font-medium text-ink"
              >
                Transkrip lengkap
                <span aria-hidden className={`pr-2 text-muted transition-transform ${open ? 'rotate-180' : ''}`}>⌄</span>
              </button>
              {open && <p className="animate-fade-up border-t border-line px-[15px] py-3 text-base leading-6 text-ink">{rec.transcript}</p>}
            </div>
          </>
        )}
        {rec.status === 'memproses' && <ProcessingCard duration={rec.duration} />}
        {rec.status === 'gagal' && <FailedCard onRetry={onRetry} />}
      </div>
    </div>
  )
}
